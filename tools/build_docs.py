#!/usr/bin/env python3
"""Build a source-derived vhyl library reference and its documentation site.

The scanner understands declarations, not Zebulon execution.  It never imports
the compiler; the pinned compiler's CLI remains the source-check authority.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import html
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ("vhyl.h", "vhyl.t", "vhyl-en.t", "vhyl-dialogue.t")
STAGE = ROOT / "build" / "docs-src"
SITE = ROOT / "build" / "site"
SUPPORTED_SYMBOLS = {
    "Thing", "Room", "DarkRoom", "OutdoorRoom", "Container", "Door", "Action",
    "Command", "Verb", "Message", "Actor", "ActorState", "AccompanyingState",
    "TopicEntry", "Event", "Fuse", "Daemon", "Conversation", "DialogueChoice",
    "InternalSpeaker", "Doer", "gameMain", "player", "vhylStart", "vhylTurn",
    "vhylAct", "here", "contains", "exits", "vocab", "connects", "presentIn",
    "knows", "attachedTo", "dialogueVoice",
}
SUPPORTED_MEMBERS = {
    "Thing": {"name", "desc", "presentation", "rank", "refuses", "preCond",
              "setKnowsAbout", "forget", "bulk", "bulkCapacity", "isOpen",
              "isOpenable", "isContainer", "isFixed", "isDecoration"},
    "Action": {"needsDobj", "needsIobj", "rank", "preCond", "exec", "report"},
    "Verb": {"code", "action", "dir", "label"},
    "Message": {"id", "text", "say", "priority", "isActive"},
    "Actor": {"curState", "setCurState", "canAccompanyTravel", "idleTurn"},
    "ActorState": {"actor", "isInitState", "takeTurn", "activateState",
                   "deactivateState", "beforeAction", "afterAction"},
    "AccompanyingState": {"accompanyingActor"},
    "TopicEntry": {"actor", "matchObj", "inState", "id", "reply", "once", "used"},
    "Event": {"owner", "prop", "turnsLeft", "interval", "isActive", "isDue"},
    "Conversation": {"id", "target", "choices", "isActive", "availableTo",
                     "opening", "closing", "canContinue"},
    "DialogueChoice": {"id", "labelId", "subject", "requiresKnowledge", "once",
                       "isActive", "available", "selected", "voice"},
    "Doer": {"forAction", "forDobj", "forIobj", "instead"},
}


@dataclass
class Member:
    name: str
    kind: str
    signature: str
    source: str
    line: int
    description: str = ""
    audience: str = "internal"


@dataclass
class Symbol:
    name: str
    kind: str
    source: str
    line: int
    signature: str
    parent: str = ""
    description: str = ""
    audience: str = "internal"
    members: list[Member] = field(default_factory=list)


def masked(text: str) -> str:
    """Hide strings and comments while retaining offsets and line endings."""
    out = list(text)
    i = 0
    while i < len(text):
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = len(text) if end < 0 else end
        elif text.startswith("/*", i):
            close = text.find("*/", i + 2)
            if close < 0:
                raise ValueError("unterminated block comment")
            end = close + 2
        elif text[i] in "'\"":
            quote = text[i]
            end = i + 1
            while end < len(text):
                if text[end] == "\\":
                    end += 2
                elif text[end] == quote:
                    end += 1
                    break
                else:
                    end += 1
            else:
                raise ValueError("unterminated string")
        else:
            i += 1
            continue
        for j in range(i, min(end, len(text))):
            if text[j] != "\n":
                out[j] = " "
        i = end
    return "".join(out)


def matching(mask: str, start: int, opening: str, closing: str) -> int:
    depth = 0
    for i in range(start, len(mask)):
        if mask[i] == opening:
            depth += 1
        elif mask[i] == closing:
            depth -= 1
            if depth == 0:
                return i + 1
    raise ValueError(f"unclosed {opening} at offset {start}")


def semicolon(mask: str, start: int) -> int:
    brace = bracket = paren = 0
    for i in range(start, len(mask)):
        c = mask[i]
        if c == "{":
            brace += 1
        elif c == "}":
            brace -= 1
        elif c == "[":
            bracket += 1
        elif c == "]":
            bracket -= 1
        elif c == "(":
            paren += 1
        elif c == ")":
            paren -= 1
        elif c == ";" and brace == bracket == paren == 0:
            return i + 1
    raise ValueError(f"declaration without semicolon at offset {start}")


def documentation(text: str, start: int) -> tuple[str, str]:
    """Read an adjacent comment; /** blocks can mark supported APIs."""
    before = text[:start]
    end = before.rfind("*/")
    if end < 0 or before[end + 2:].strip():
        return "", "internal"
    begin = before.rfind("/*", 0, end)
    if begin < 0:
        return "", "internal"
    prefix = 3 if before.startswith("/**", begin) else 2
    lines = [re.sub(r"^\s*\*\s?", "", line).strip() for line in before[begin + prefix:end].splitlines()]
    audience = "internal"
    kept = []
    for line in lines:
        if line.startswith("@api "):
            audience = line[5:].strip()
        elif line:
            kept.append(line)
    return " ".join(kept), audience


def source_line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def without_comments(fragment: str) -> str:
    """Remove comments from displayed declarations without stripping strings."""
    result = []
    i = 0
    while i < len(fragment):
        if fragment.startswith("/*", i):
            close = fragment.find("*/", i + 2)
            i = len(fragment) if close < 0 else close + 2
            result.append(" ")
        elif fragment.startswith("//", i):
            close = fragment.find("\n", i + 2)
            i = len(fragment) if close < 0 else close
            result.append(" ")
        elif fragment[i] in "'\"":
            quote = fragment[i]
            start = i
            i += 1
            while i < len(fragment):
                if fragment[i] == "\\":
                    i += 2
                elif fragment[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            result.append(fragment[start:i])
        else:
            result.append(fragment[i])
            i += 1
    return "".join(result)


def members(text: str, mask: str, start: int, end: int, source: str) -> list[Member]:
    found: list[Member] = []
    i = start
    while i < end:
        m = re.search(r"[A-Za-z_]\w*", mask[i:end])
        if not m:
            break
        at = i + m.start()
        name = m.group()
        after = at + len(name)
        while after < end and mask[after].isspace():
            after += 1
        if after >= end:
            break
        kind = ""
        finish = after
        if mask[after] == "(":
            args_end = matching(mask, after, "(", ")")
            body = args_end
            while body < end and mask[body].isspace():
                body += 1
            if body < end and mask[body] == "{":
                finish = matching(mask, body, "{", "}")
                kind = "method"
                signature = re.sub(r"\s+", " ", text[at:args_end]).strip()
        elif mask[after] == "{":
            finish = matching(mask, after, "{", "}")
            kind = "property"
            signature = name + " { ... }"
        elif mask[after] == "=" and (after + 1 >= end or mask[after + 1] != "="):
            kind = "property"
            finish = after + 1
            brace = bracket = paren = 0
            while finish < end:
                c = mask[finish]
                if c == "{":
                    brace += 1
                elif c == "}":
                    brace -= 1
                elif c == "[":
                    bracket += 1
                elif c == "]":
                    bracket -= 1
                elif c == "(":
                    paren += 1
                elif c == ")":
                    paren -= 1
                if brace == bracket == paren == 0 and c.isspace():
                    nxt = re.match(r"\s+([A-Za-z_]\w*)\s*(=|\(|\{)", mask[finish:end])
                    if nxt:
                        next_at = finish + len(nxt.group(0)) - len(nxt.group(0).lstrip())
                        if nxt.group(2) == "(":
                            opening = finish + len(nxt.group(0)) - 1
                            close = matching(mask, opening, "(", ")")
                            next_body = close
                            while next_body < end and mask[next_body].isspace():
                                next_body += 1
                            if next_body < end and mask[next_body] == "{":
                                finish = next_at
                                break
                        else:
                            finish = next_at
                            break
                    if "\n" in mask[finish:finish + 1] and re.match(r"\s*[A-Za-z_]\w*\s*(?:=|\(|\{)", mask[finish:end]):
                        break
                finish += 1
            signature = re.sub(r"\s+", " ", without_comments(text[at:finish])).strip()
            signature = signature.rstrip(";")
        if kind:
            desc, audience = documentation(text, at)
            found.append(Member(name, kind, signature, source, source_line(text, at), desc, audience))
            i = max(finish, after + 1)
        else:
            i = after + 1
    return found


def parse_source(source: str, text: str) -> list[Symbol]:
    mask = masked(text)
    out: list[Symbol] = []
    i = 0
    while i < len(mask):
        while i < len(mask) and mask[i].isspace():
            i += 1
        if i >= len(mask):
            break
        rest = mask[i:]
        m = re.match(r"(class\s+)?([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)", rest)
        mod = re.match(r"modify\s+([A-Za-z_]\w*)\b", rest)
        func = re.match(r"([A-Za-z_]\w*)\s*\(", rest)
        direct = re.match(r"(relation|enum|property|dictionary|grammar)\b", rest)
        template = re.match(r"[A-Za-z_]\w*\s+template\b", rest)
        define = re.match(r"#(?:define|include|if|endif|else)\b", rest)
        plus = re.match(r"\+\s*property\b", rest)
        if m or mod:
            header = m or mod
            finish = semicolon(mask, i)
            name = m.group(2) if m else mod.group(1)
            kind = "class" if m and m.group(1) else "object" if m else "modify"
            parent = m.group(3) if m else ""
            body_start = i + header.end()
            desc, audience = documentation(text, i)
            signature = re.sub(r"\s+", " ", text[i:body_start]).strip()
            sym = Symbol(name, kind, source, source_line(text, i), signature, parent, desc, audience)
            sym.members = members(text, mask, body_start, finish - 1, source)
            out.append(sym)
            i = finish
        elif func:
            args = i + func.end() - 1
            args_end = matching(mask, args, "(", ")")
            body = args_end
            while body < len(mask) and mask[body].isspace():
                body += 1
            if body < len(mask) and mask[body] == "{":
                finish = matching(mask, body, "{", "}")
                desc, audience = documentation(text, i)
                out.append(Symbol(func.group(1), "function", source, source_line(text, i),
                                  re.sub(r"\s+", " ", text[i:args_end]).strip(),
                                  description=desc, audience=audience))
                i = finish
            else:
                i = args_end
        elif direct or template or define or plus:
            kind = "template" if template else "macro" if define else "property" if plus else direct.group(1)
            finish = mask.find("\n", i) if define else semicolon(mask, i)
            if finish < 0:
                finish = len(mask)
            signature = re.sub(r"\s+", " ", text[i:finish]).strip().rstrip(";")
            if kind == "grammar":
                name_match = re.match(r"grammar\s+(\w+)\s*\(\s*(\w+)\s*\)", signature)
                name = f"{name_match.group(1)}({name_match.group(2)})" if name_match else signature[:50]
            elif kind == "template":
                name = signature.split()[0]
            elif kind == "macro":
                name_match = re.match(r"#\w+\s+(\w+)", signature)
                name = name_match.group(1) if name_match else signature
            else:
                name_match = re.match(r"\+?\s*\w+\s+(\w+)", signature)
                name = name_match.group(1) if name_match else signature
            desc, audience = documentation(text, i)
            out.append(Symbol(name, kind, source, source_line(text, i), signature,
                              description=desc, audience=audience))
            i = finish
        else:
            snippet = text[i:i + 70].splitlines()[0]
            raise ValueError(f"unrecognised declaration in {source}:{source_line(text, i)}: {snippet}")
    return out


def merge_symbols(all_symbols: list[Symbol]) -> list[Symbol]:
    merged: dict[str, Symbol] = {}
    output = []
    for sym in all_symbols:
        if sym.kind == "modify":
            if sym.name not in merged:
                raise ValueError(f"modify before declaration: {sym.name}")
            merged[sym.name].members.extend(sym.members)
        else:
            if sym.kind == "object" and sym.parent in ("Message", "Verb") and not sym.description:
                key = "id" if sym.parent == "Message" else "code"
                member = next((m for m in sym.members if m.name == key), None)
                value = member.signature.partition("=")[2].strip() if member else "unknown"
                sym.description = f"Built-in {sym.parent.lower()} {key} `{value}`."
                sym.audience = "host"
            output.append(sym)
            if sym.kind in ("class", "object"):
                merged[sym.name] = sym
    for sym in output:
        if sym.audience in ("author", "host") and not sym.description:
            raise ValueError(f"supported {sym.kind} lacks description: {sym.name}")
        for member in sym.members:
            if member.audience in ("author", "host") and not member.description:
                raise ValueError(f"supported member lacks description: {sym.name}.{member.name}")
    return output


def verify_supported(output: list[Symbol]) -> None:
    named = {sym.name: sym for sym in output if sym.kind != "template"}
    for name in SUPPORTED_SYMBOLS:
        sym = named.get(name)
        if sym is None or sym.audience == "internal" or not sym.description:
            raise ValueError(f"supported symbol lacks documentation: {name}")
    for owner, names in SUPPORTED_MEMBERS.items():
        documented = {m.name for m in named[owner].members
                      if m.audience in ("author", "host") and m.description}
        for name in names - documented:
            raise ValueError(f"supported member lacks documentation: {owner}.{name}")


def model() -> list[Symbol]:
    all_symbols = []
    for source in SOURCES:
        all_symbols.extend(parse_source(source, (ROOT / "lib" / source).read_text(encoding="utf-8")))
    output = merge_symbols(all_symbols)
    verify_supported(output)
    return output


def slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "-", value).strip("-")


def source_link(source: str, line: int) -> str:
    return f"source/{slug(source)}.md#L{line}"


def source_page(source: str) -> str:
    lines = (ROOT / "lib" / source).read_text(encoding="utf-8").splitlines()
    body = [f"# {source}", "", f"[Back to reference](../README.md)", "", '<pre class="source">']
    for number, line in enumerate(lines, 1):
        body.append(f'<span id="L{number}"><a href="#L{number}">{number:4}</a>  {html.escape(line)}</span>')
    body += ["</pre>", ""]
    return "\n".join(body)


def object_page(sym: Symbol, by_name: dict[str, Symbol]) -> str:
    page = [f"# {sym.name}", "", f"**{sym.kind.title()}** · `{sym.signature}` · ",
            f"[Source]({source_link(sym.source, sym.line)})", ""]
    page.append(sym.description or "Internal implementation detail; no supported authoring contract is documented.")
    page += ["", f"**Audience:** {sym.audience}", ""]
    if sym.parent:
        parent = by_name.get(sym.parent)
        parent_link = f"[{sym.parent}]({slug(sym.parent)}.md)" if parent and parent.kind in ("class", "object") else f"`{sym.parent}`"
        page += [f"**Superclass:** {parent_link}", ""]
    children = sorted(x.name for x in by_name.values() if x.kind == "class" and x.parent == sym.name)
    if children:
        page += ["**Subclasses:** " + ", ".join(f"[{name}]({slug(name)}.md)" for name in children), ""]
    grouped: dict[str, list[Member]] = {}
    for member in sym.members:
        grouped.setdefault(member.name, []).append(member)
    page += ["## Declared members", ""]
    if grouped:
        for name in sorted(grouped, key=str.lower):
            entry = grouped[name][-1]
            page.append(f"- [{name}](#member-{slug(name)}) — {entry.kind}; {entry.description or entry.audience}")
    else:
        page.append("No members declared here.")
    page.append("")
    inherited: dict[str, str] = {}
    parent_name = sym.parent
    seen = set(grouped)
    ancestors = set()
    while parent_name in by_name and parent_name not in ancestors:
        ancestors.add(parent_name)
        parent = by_name[parent_name]
        for member in parent.members:
            if member.name not in seen:
                inherited[member.name] = parent_name
                seen.add(member.name)
        parent_name = parent.parent
    if inherited:
        page += ["## Inherited members", ""]
        for name in sorted(inherited, key=str.lower):
            owner = inherited[name]
            page.append(f"- [{name}]({slug(owner)}.md#member-{slug(name)}) from [{owner}]({slug(owner)}.md)")
        page.append("")
    page += ["## Member details", ""]
    for name in sorted(grouped, key=str.lower):
        page += [f'<a id="member-{slug(name)}"></a>', f"### {name}", ""]
        for member in grouped[name]:
            page += [f"`{member.signature}` · [Source]({source_link(member.source, member.line)})", "",
                     member.description or "Internal implementation detail; no supported authoring contract is documented.", ""]
    return "\n".join(page)


def render(symbols: list[Symbol], stage: Path) -> None:
    shutil.copytree(ROOT / "docs", stage, dirs_exist_ok=True)
    shutil.copytree(ROOT / "examples", stage / "examples", dirs_exist_ok=True)
    shutil.copy2(ROOT / "compiler.json", stage / "compiler.json")
    for page in stage.rglob("*.md"):
        if page.is_relative_to(stage / "examples"):
            continue
        original = page.read_text(encoding="utf-8")
        adjusted = original.replace("](../examples/", "](examples/")
        adjusted = adjusted.replace("](../compiler.json)", "](compiler.json)")
        if adjusted != original:
            page.write_text(adjusted, encoding="utf-8")
    reference = stage / "reference"
    reference.mkdir(exist_ok=True)
    source_dir = reference / "source"
    source_dir.mkdir(exist_ok=True)
    for source in SOURCES:
        (source_dir / f"{slug(source)}.md").write_text(source_page(source), encoding="utf-8")
    by_name = {s.name: s for s in symbols if s.kind in ("class", "object")}
    if len(by_name) != sum(s.kind in ("class", "object") for s in symbols):
        raise ValueError("duplicate class or object name")
    for sym in by_name.values():
        anchors = [slug(m.name) for m in sym.members]
        if len(set(anchors)) != len({m.name for m in sym.members}):
            raise ValueError(f"duplicate member anchor in {sym.name}")
        (reference / f"{slug(sym.name)}.md").write_text(object_page(sym, by_name), encoding="utf-8")
    def category(sym: Symbol) -> str:
        if sym.kind == "object" and sym.parent in ("Action", "Message", "Verb"):
            return sym.parent.lower()
        return sym.kind

    plurals = {"class": "classes", "property": "properties", "dictionary": "dictionaries",
               "grammar": "grammar", "macro": "macros"}

    def category_page(kind: str) -> str:
        return plurals.get(kind, kind + "s") + ".md"

    def symbol_link(sym: Symbol) -> str:
        if sym.kind in ("class", "object"):
            return f"{slug(sym.name)}.md"
        return f"{category_page(category(sym))}#symbol-{slug(sym.name)}"

    categories: dict[str, list[Symbol]] = {}
    for sym in symbols:
        categories.setdefault(category(sym), []).append(sym)
    index = ["# Library reference", "", "Source-derived reference for the library declarations. All entries show their source location; supported author and host interfaces have reviewed descriptions.", "",
             "[Alphabetical symbols](symbols.md) · [Alphabetical members](members.md)", ""]
    for kind in sorted(categories):
        title = category_page(kind)[:-3].title()
        index += [f"## [{title}]({category_page(kind)})", ""]
        detail = [f"# {title}", "", "[Reference index](README.md)", ""]
        anchors = [slug(sym.name) for sym in categories[kind]]
        if len(anchors) != len(set(anchors)):
            raise ValueError(f"duplicate {kind} anchor")
        for sym in sorted(categories[kind], key=lambda s: s.name.lower()):
            index.append(f"- [`{sym.name}`]({symbol_link(sym)}) — {sym.description or sym.audience}")
            detail += [f'<a id="symbol-{slug(sym.name)}"></a>', f"## {sym.name}", "",
                       f"`{sym.signature}` · [Source]({source_link(sym.source, sym.line)})", "",
                       sym.description or "Internal implementation detail; no supported authoring contract is documented.", ""]
        index.append("")
        (reference / category_page(kind)).write_text("\n".join(detail), encoding="utf-8")
    (reference / "README.md").write_text("\n".join(index), encoding="utf-8")
    alphabet = ["# Alphabetical symbols", "", "[Reference index](README.md)", ""]
    for sym in sorted(symbols, key=lambda s: (s.name.lower(), s.kind)):
        alphabet.append(f"- [`{sym.name}`]({symbol_link(sym)}) — {category(sym)}")
    (reference / "symbols.md").write_text("\n".join(alphabet) + "\n", encoding="utf-8")
    member_index = ["# Alphabetical members", "", "[Reference index](README.md)", ""]
    for owner in sorted(by_name.values(), key=lambda s: s.name.lower()):
        for name in sorted({m.name for m in owner.members}, key=str.lower):
            member_index.append(f"- [`{name}`]({slug(owner.name)}.md#member-{slug(name)}) — {owner.name}")
    member_index[4:] = sorted(member_index[4:], key=lambda row: row.split("`")[1].lower())
    (reference / "members.md").write_text("\n".join(member_index) + "\n", encoding="utf-8")


def check_links(stage: Path) -> None:
    """Check staged Markdown targets and explicit reference/source anchors."""
    errors = []
    for page in stage.rglob("*.md"):
        content = page.read_text(encoding="utf-8")
        for href in re.findall(r"\[[^]]*\]\(([^)]+)\)", content):
            if "://" in href or href.startswith("mailto:"):
                continue
            path, _, fragment = unquote(href).partition("#")
            target = page.parent / path if path else page
            if not target.exists():
                errors.append(f"{page.relative_to(stage)}: missing {href}")
                continue
            if fragment and target.suffix == ".md":
                target_text = target.read_text(encoding="utf-8")
                ids = set(re.findall(r'<(?:a|span) id="([^"]+)"', target_text))
                ids.update(slug(h) for h in re.findall(r"^#{1,6}\s+(.+)$", target_text, re.M))
                if fragment not in ids:
                    errors.append(f"{page.relative_to(stage)}: missing anchor {href}")
    if errors:
        raise ValueError("broken documentation links:\n" + "\n".join(errors[:30]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate and build without updating tracked files")
    args = parser.parse_args()
    symbols = model()
    if args.check:
        with tempfile.TemporaryDirectory(prefix="vhyl docs ") as folder:
            temp = Path(folder)
            stage = temp / "docs-src"
            site = temp / "site"
            config = temp / "mkdocs.yml"
            content = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
            content = content.replace("docs_dir: build/docs-src", f"docs_dir: {stage}")
            content = content.replace("site_dir: build/site", f"site_dir: {site}")
            config.write_text(content, encoding="utf-8")
            return build(symbols, stage, site, config, checked=True)
    return build(symbols, STAGE, SITE, ROOT / "mkdocs.yml", checked=False)


def build(symbols: list[Symbol], stage: Path, site: Path, config: Path, *, checked: bool) -> int:
    if stage.exists():
        shutil.rmtree(stage)
    render(symbols, stage)
    check_links(stage)
    result = subprocess.run([sys.executable, "-m", "mkdocs", "build", "--strict", "--clean",
                             "--quiet", "--config-file", str(config), "--site-dir", str(site)],
                            cwd=ROOT, check=False)
    if result.returncode:
        return result.returncode
    if checked:
        print(f"{len(symbols)} declarations indexed; documentation check passed")
    else:
        print(f"{len(symbols)} declarations indexed; site built at {site.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"vhyl docs: {exc}", file=sys.stderr)
        raise SystemExit(1)

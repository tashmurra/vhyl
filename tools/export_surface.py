#!/usr/bin/env python3
"""Generate the public message and verb catalogues; --check refuses drift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "lib"

MESSAGE = re.compile(
    r"^\s*\w+:\s*Message\s+id\s*=\s*'([^']*)'\s*(text\s*=\s*'((?:[^'\\]|\\.)*)'|say\s*\()",
    re.M,
)
VERB = re.compile(
    r"^(v[A-Za-z]+):\s*Verb\s+code\s*=\s*(\d+)\s+action\s*=\s*(\w+)"
    r"(?:\s+dir\s*=\s*\w+)?\s+label\s*=\s*'([^']*)'"
    r"(?:\s+verbPhrase\s*=\s*'([^']*)')?",
    re.M,
)
NEEDS = re.compile(r"^(\w+):\s*Action\b(.*?)^;", re.M | re.S)


def messages() -> list[dict]:
    """Every message id the library can say, in declaration order."""
    seen: dict[str, dict] = {}
    order: list[str] = []
    # The library's own modules only: application messages belong to their game, and
    # a host binds to what vhyl guarantees rather than to what a test declares.
    for source in [LIBRARY / "vhyl.t", LIBRARY / "vhyl-en.t"]:
        for id_, body, text in MESSAGE.findall(source.read_text(encoding='utf-8')):
            if id_ not in seen:
                order.append(id_)
            entry: dict = {"id": id_}
            if body.startswith("text"):
                entry["kind"] = "text"
                entry["default"] = text.replace("\\'", "'")
            else:
                entry["kind"] = "computed"
            # A later declaration of the same id is an override; the first one
            # that carries text is the default a translator replaces.
            if id_ in seen and seen[id_].get("kind") == "text":
                continue
            seen[id_] = entry
    return [seen[id_] for id_ in order]


def verbs(text: str) -> list[dict]:
    """Every verb code, with how many entities its action takes."""
    subjects = {}
    for name, body in NEEDS.findall(text):
        subjects[name] = ("needsDobj = true" in body) + ("needsIobj = true" in body)
    out = []
    for _, code, action, label, phrase in VERB.findall(text):
        entry = {"code": int(code), "label": label, "subjects": subjects.get(action, 0)}
        if phrase:
            entry["phrase"] = phrase
        out.append(entry)
    out.sort(key=lambda v: v["code"])
    return out


def write(path: Path, key: str, rows: list[dict]) -> bool:
    """Write one table, one row per line, and say whether it changed."""
    lines = [f'  "{key}": [']
    lines += [
        "    " + json.dumps(row) + ("," if index + 1 < len(rows) else "")
        for index, row in enumerate(rows)
    ]
    body = "{\n" + "\n".join(lines) + "\n  ]\n}\n"
    before = path.read_text(encoding='utf-8') if path.exists() else ""
    if before == body:
        return False
    if "--check" in sys.argv:
        raise ValueError(f"stale catalogue: {path.relative_to(ROOT)}; run python3 tools/export_surface.py")
    path.write_text(body, encoding='utf-8')
    return True


def main() -> int:
    ids = messages()
    codes = verbs((LIBRARY / "vhyl.t").read_text(encoding='utf-8'))
    duplicates = {v["code"] for v in codes if [c["code"] for c in codes].count(v["code"]) > 1}
    if duplicates:
        print(f"export: duplicate verb codes {sorted(duplicates)}", file=sys.stderr)
        return 1
    changed = write(ROOT / "docs" / "api" / "messages.json", "messages", ids)
    changed |= write(ROOT / "docs" / "api" / "verbs.json", "verbs", codes)
    print(f"{len(ids)} message ids, {len(codes)} verb codes"
          + (" — written" if changed else " — unchanged"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

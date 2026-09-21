#!/usr/bin/env python3
"""Review public source paths, documentation links and include dependencies."""
from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
IGNORED = {'.git', 'build', '.tools', '__pycache__'}


def main():
    paths = [p for p in ROOT.rglob('*') if not any(x in IGNORED for x in p.relative_to(ROOT).parts)]
    errors = []
    files = []
    private = re.compile(r'/(?:Users|home)/[^/\s]+|/opt/pkg|Z-(?:DEC|L|TD)\d+|github\.com/[^\s)]+/issues/\d+|users\.ox\.ac\.uk')
    for path in paths:
        rel = path.relative_to(ROOT)
        if path.is_symlink():
            errors.append(f'{rel}: symlink needs review')
            continue
        if not path.is_file():
            continue
        files.append(path)
        try:
            text = path.read_text(encoding='utf-8')
        except UnicodeError:
            errors.append(f'{rel}: binary file needs review')
            continue
        if path != Path(__file__).resolve() and private.search(text):
            errors.append(f'{rel}: historical or machine-specific reference')
        if path.suffix in ('.t', '.h'):
            for opening, name in re.findall(r'^\s*#include\s*([<"])([^>"\n]+)[>"]', text, re.M):
                candidates = [ROOT/'lib'/name]
                if opening == '"':
                    candidates.insert(0, path.parent/name)
                if not any(p.is_file() and p.resolve().is_relative_to(ROOT) for p in candidates):
                    errors.append(f'{rel}: unresolved/outside include {name}')
        if path.suffix == '.md':
            for link in re.findall(r'\[[^]]*\]\(([^)]+)\)', text):
                target = unquote(link.split('#', 1)[0])
                if not target or '://' in target or target.startswith('mailto:'):
                    continue
                if not (path.parent/target).exists():
                    errors.append(f'{rel}: missing documentation link {target}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'{len(files)} source files checked; includes and documentation links resolve')


if __name__ == '__main__':
    main()

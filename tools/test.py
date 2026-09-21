#!/usr/bin/env python3
"""Check sources and host utilities; --native also executes the native behaviour suite."""
import argparse
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tests'))
from support import Build, select_compiler, require_native_host, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zebc', help='compiler executable; otherwise ZEBC, then PATH')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--out', type=Path, help='new directory for logs, bundles and cache')
    args = parser.parse_args()
    compiler = select_compiler(args.zebc)
    if args.native:
        require_native_host()
    if args.out:
        out = args.out.resolve()
        out.mkdir(parents=True, exist_ok=False)
    else:
        out = Path(tempfile.mkdtemp(prefix='vhyl tests '))
    try:
        suite = unittest.defaultTestLoader.discover(str(ROOT/'tests'), pattern='test_*.py')
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        if not result.wasSuccessful():
            raise RuntimeError('host/tool unit tests failed')
        run([sys.executable, '-B', ROOT/'tools/export_surface.py', '--check'])
        build = Build(compiler, out)
        sources = sorted((ROOT/'examples').rglob('*.t')) + sorted((ROOT/'tests/fixtures').glob('*.t'))
        sources = [p for p in sources if not p.name.endswith('-en.t')]
        for source in sources:
            build.check(source)
        print(f'{len(sources)} complete source programs checked', flush=True)
        if args.native:
            import following, dialogue, scenarios
            scenarios.test(build)
            following.test(build)
            dialogue.test(build)
            print('Native suite passed on '+os.uname().machine, flush=True)
        print('All requested checks passed', flush=True)
    except BaseException:
        print(f'Check output retained at {out}', file=sys.stderr)
        raise
    else:
        if not args.out:
            shutil.rmtree(out)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError) as exc:
        print(f'vhyl tests: {exc}', file=sys.stderr)
        raise SystemExit(1)

"""Shared compiler selection, subprocess execution and isolated native builds."""
from pathlib import Path
import json
import os
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def executable(value, setting):
    if not value:
        raise ValueError(f'{setting} is empty')
    found = shutil.which(str(value))
    if found is None:
        raise ValueError(f'cannot execute {setting}: {value}')
    return str(Path(found).resolve())


def select_compiler(argument=None, environment=None):
    environment = os.environ if environment is None else environment
    if argument is not None:
        return executable(argument, '--zebc')
    if 'ZEBC' in environment:
        return executable(environment['ZEBC'], 'ZEBC')
    return executable('zebc', 'zebc on PATH')


def run(args, *, cwd=ROOT, timeout=300, **kwargs):
    result = subprocess.run([str(x) for x in args], cwd=cwd, capture_output=True,
                            text=True, encoding='utf-8', timeout=timeout, **kwargs)
    if result.returncode:
        raise RuntimeError(f'{args[0]} exited {result.returncode}:\n{result.stdout[-16000:]}\n{result.stderr[-16000:]}')
    return result


class Build:
    def __init__(self, compiler, out):
        self.compiler = compiler
        self.out = Path(out).resolve()
        self.cache = self.out / 'runtime-cache'

    def check(self, source):
        source = Path(source).resolve()
        return run([self.compiler, 'check', source, '--include-dir', ROOT/'lib',
                    '--include-dir', source.parent], cwd=self.out)

    def build(self, name, source):
        source = Path(source).resolve()
        bundle = self.out / name
        answer = run([self.compiler, 'build', source, '--include-dir', ROOT/'lib',
                      '--include-dir', source.parent, '--emit', 'shared', '--opt', 'O2',
                      '--out-dir', bundle, '--runtime-cache', self.cache], cwd=self.out)
        (self.out / (name + '.log')).write_text(answer.stdout + answer.stderr, encoding='utf-8')
        return bundle

    def compile_host(self, bundle, source, name):
        configured = os.environ.get('ZEB_LLVM_CONFIG', os.environ.get('LLVM_CONFIG', 'llvm-config'))
        config = executable(configured, 'LLVM configuration')
        binary = Path(run([config, '--bindir'], cwd=self.out).stdout.strip())
        if 'SDKROOT' in os.environ:
            sdk = os.environ['SDKROOT']
            if not sdk or not Path(sdk).is_dir():
                raise ValueError('SDKROOT must name an existing macOS SDK')
        else:
            sdk = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'], cwd=self.out).stdout.strip()
        manifest = json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))
        run([binary/'clang', '-Wall', '-Wextra', '-Werror', '-isysroot', sdk,
             '-mmacosx-version-min=14.0', source, bundle/manifest['bundle']['game'],
             '-Wl,-rpath,@loader_path', '-o', bundle/name], cwd=bundle)


def require_native_host():
    if platform.system() != 'Darwin' or platform.machine() not in ('x86_64', 'arm64'):
        raise ValueError('the native test harness currently requires Intel or Apple Silicon macOS; use source checks on other hosts')

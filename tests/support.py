"""Shared compiler selection, subprocess execution and isolated native builds."""
from pathlib import Path
from collections import deque
import json
import os
import platform
import queue
import shutil
import subprocess
import threading
import time

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


def native_executable(folder, name):
    return Path(folder) / (name + '.exe' if platform.system() == 'Windows' else name)


class LineProcess:
    """Read framed subprocess output with deadlines, including Windows pipes."""
    def __init__(self, args, *, cwd):
        self.proc = subprocess.Popen([str(x) for x in args], cwd=cwd,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', bufsize=1)
        self.lines = queue.Queue()
        self.recent = deque(maxlen=10)

        def read():
            try:
                for line in self.proc.stdout:
                    self.lines.put(line.rstrip('\n'))
            except (OSError, UnicodeError) as error:
                self.lines.put(error)
            finally:
                self.lines.put(None)

        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()

    def read_until(self, marker, timeout=30):
        deadline = time.monotonic() + timeout
        result = []
        while True:
            remaining = deadline-time.monotonic()
            if remaining <= 0:
                raise RuntimeError('native host timed out')
            try:
                line = self.lines.get(timeout=remaining)
            except queue.Empty:
                raise RuntimeError('native host timed out') from None
            if isinstance(line, Exception):
                raise RuntimeError('cannot read native host output') from line
            if line is None:
                raise RuntimeError('native host stopped: ' + '\n'.join(self.recent))
            self.recent.append(line)
            if line == marker:
                return result
            result.append(line)

    def send(self, line):
        self.proc.stdin.write(line + '\n')
        self.proc.stdin.flush()

    def close(self, *, terminate=False):
        try:
            if terminate and self.proc.poll() is None:
                self.proc.kill()
            try:
                self.proc.stdin.close()
            except BrokenPipeError:
                pass
            try:
                code = self.proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)
                raise
            if code and not terminate:
                raise RuntimeError(f'native host exited {code}: ' + '\n'.join(self.recent))
        finally:
            self.reader.join(timeout=5)
            self.proc.stdout.close()


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
        require_native_host()
        configured = os.environ.get('ZEB_LLVM_CONFIG', os.environ.get('LLVM_CONFIG', 'llvm-config'))
        config = executable(configured, 'LLVM configuration')
        binary = Path(run([config, '--bindir'], cwd=self.out).stdout.strip())
        system = platform.system()
        manifest = json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))['bundle']
        if system == 'Darwin':
            if 'SDKROOT' in os.environ:
                sdk = os.environ['SDKROOT']
                if not sdk or not Path(sdk).is_dir():
                    raise ValueError('SDKROOT must name an existing macOS SDK')
            else:
                sdk = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'], cwd=self.out).stdout.strip()
            flags = ['-isysroot', sdk, '-mmacosx-version-min=14.0',
                     '-Wl,-rpath,@loader_path', '-pthread']
        elif system == 'Linux':
            flags = ['--ld-path=' + str(binary/'ld.lld'), '-Wl,-rpath,$ORIGIN', '-pthread']
        else:
            flags = ['-fuse-ld=lld', '-B' + str(binary)]
        if system == 'Windows':
            libraries = manifest.get('import_libraries')
            if not libraries:
                raise ValueError('Windows bundle lacks import libraries')
        else:
            libraries = [manifest['game']]
        run([native_executable(binary, 'clang'), '-std=c11', '-Wall', '-Wextra', '-Werror',
             *flags, source, *(bundle/library for library in libraries),
             '-o', native_executable(bundle, name)], cwd=bundle)


def require_native_host():
    system, machine = platform.system(), platform.machine().lower()
    supported = {'Darwin': ('x86_64', 'arm64'),
                 'Linux': ('x86_64',), 'Windows': ('amd64', 'x86_64')}
    if machine not in supported.get(system, ()):
        raise ValueError('native tests require macOS Intel/Apple Silicon, Linux x86-64 '
                         'or Windows x86-64; use source checks on other hosts')

"""Tool selection and portable native-host execution contracts."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import support


class CompilerSelectionTests(unittest.TestCase):
    def test_precedence(self):
        with patch.object(support, 'executable', side_effect=lambda value, setting: value):
            self.assertEqual(support.select_compiler('argument', {'ZEBC': 'environment'}), 'argument')
            self.assertEqual(support.select_compiler(None, {'ZEBC': 'environment'}), 'environment')
            self.assertEqual(support.select_compiler(None, {}), 'zebc')

    def test_invalid_and_empty_explicit_settings(self):
        for value in ['', '/missing/vhyl-compiler']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                support.select_compiler(value, {'ZEBC': 'otherwise-valid'})
            with self.subTest(environment=value), self.assertRaises(ValueError):
                support.select_compiler(None, {'ZEBC': value})

    def test_paths_with_spaces_are_single_arguments(self):
        import sys
        with tempfile.TemporaryDirectory(prefix='vhyl tools ') as name:
            path = Path(name)/'script with spaces.py'
            path.write_text('import sys; print(sys.argv[1])', encoding='utf-8')
            result = support.run([sys.executable, path, 'one argument with spaces'], cwd=name)
            self.assertEqual(result.stdout.strip(), 'one argument with spaces')


class NativeHostTests(unittest.TestCase):
    def test_supported_host_architectures(self):
        for system, machine in [('Darwin', 'x86_64'), ('Darwin', 'arm64'),
                                ('Linux', 'x86_64'), ('Windows', 'AMD64')]:
            with self.subTest(system=system, machine=machine), \
                    patch.object(support.platform, 'system', return_value=system), \
                    patch.object(support.platform, 'machine', return_value=machine):
                support.require_native_host()
        for system, machine in [('Linux', 'aarch64'), ('Windows', 'ARM64'), ('FreeBSD', 'amd64')]:
            with self.subTest(system=system, machine=machine), \
                    patch.object(support.platform, 'system', return_value=system), \
                    patch.object(support.platform, 'machine', return_value=machine), \
                    self.assertRaises(ValueError):
                support.require_native_host()

    def test_non_apple_linking_uses_manifest_and_selected_llvm(self):
        with tempfile.TemporaryDirectory(prefix='vhyl native tools ') as directory:
            folder = Path(directory)
            binary = folder/'LLVM tools'
            manifest = {'bundle': {'game': 'story.dll',
                                   'import_libraries': ['story-custom.lib', 'runtime-custom.lib']}}
            (folder/'manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
            # An unrelated SDKROOT must not activate Apple SDK discovery.
            for system, machine in [('Linux', 'x86_64'), ('Windows', 'AMD64')]:
                with self.subTest(system=system), \
                        patch.object(support.platform, 'system', return_value=system), \
                        patch.object(support.platform, 'machine', return_value=machine), \
                        patch.dict(os.environ, {'SDKROOT': '/missing-sdk', 'ZEB_LLVM_CONFIG': 'selected-config'}), \
                        patch.object(support, 'executable', return_value='selected-config'), \
                        patch.object(support, 'run', return_value=subprocess.CompletedProcess([], 0, str(binary)+'\n', '')) as run:
                    support.Build('zebc', folder).compile_host(folder, folder/'host.c', 'host')
                    self.assertEqual(len(run.call_args_list), 2)
                    self.assertEqual(run.call_args_list[0].args[0], ['selected-config', '--bindir'])
                    args = run.call_args.args[0]
                    self.assertNotIn('-isysroot', args)
                    if system == 'Windows':
                        self.assertEqual(args[0], binary/'clang.exe')
                        self.assertIn(folder/'story-custom.lib', args)
                        self.assertIn(folder/'runtime-custom.lib', args)
                        self.assertNotIn(folder/'story.dll', args)
                        self.assertEqual(args[-1], folder/'host.exe')
                        self.assertNotIn('-pthread', args)
                    else:
                        self.assertEqual(args[0], binary/'clang')
                        self.assertIn(folder/'story.dll', args)
                        self.assertIn('-pthread', args)
                        self.assertIn('-Wl,-rpath,$ORIGIN', args)
                        self.assertIn('--ld-path='+str(binary/'ld.lld'), args)
                        self.assertEqual(args[-1], folder/'host')

    def test_windows_bundle_without_import_libraries_fails(self):
        with tempfile.TemporaryDirectory(prefix='vhyl missing imports ') as directory:
            folder = Path(directory)
            (folder/'manifest.json').write_text('{"bundle":{"game":"story.dll"}}', encoding='utf-8')
            with patch.object(support.platform, 'system', return_value='Windows'), \
                    patch.object(support.platform, 'machine', return_value='AMD64'), \
                    patch.object(support, 'executable', return_value='llvm-config'), \
                    patch.object(support, 'run', return_value=subprocess.CompletedProcess([], 0, directory, '')) as run, \
                    self.assertRaisesRegex(ValueError, 'lacks import libraries'):
                support.Build('zebc', folder).compile_host(folder, folder/'host.c', 'host')
            self.assertEqual(run.call_count, 1, 'must fail before invoking the linker')


class LineProcessTests(unittest.TestCase):
    def start(self, code):
        return support.LineProcess([sys.executable, '-u', '-c', code], cwd=support.ROOT)

    def test_crlf_fragmented_unicode_and_multiple_frames(self):
        process = self.start(
            "import os, sys\n"
            "os.write(sys.stdout.fileno(), b'first \\xce')\n"
            "os.write(sys.stdout.fileno(), b'\\xbb\\r\\nEND\\r\\nsecond\\nEND\\n')\n"
            "for line in sys.stdin:\n"
            " print(line.strip(), flush=True); print('END', flush=True)\n")
        try:
            self.assertEqual(process.read_until('END'), ['first λ'])
            self.assertEqual(process.read_until('END'), ['second'])
            process.send('reply with spaces')
            self.assertEqual(process.read_until('END'), ['reply with spaces'])
        finally:
            process.close()
        self.assertFalse(process.reader.is_alive())

    def test_eof_instead_of_frame_boundary_reports_diagnostics(self):
        process = self.start("import sys; print('incomplete'); print('failure detail', file=sys.stderr); sys.exit(7)")
        try:
            with self.assertRaisesRegex(RuntimeError, 'failure detail'):
                process.read_until('END')
        finally:
            with self.assertRaisesRegex(RuntimeError, 'exited 7'):
                process.close()

    def test_stalled_pipe_times_out_and_can_be_terminated(self):
        process = self.start("import sys; print('READY', flush=True); sys.stdin.readline()")
        try:
            process.read_until('READY')
            with self.assertRaisesRegex(RuntimeError, 'timed out'):
                process.read_until('END', timeout=0.05)
        finally:
            process.close(terminate=True)
        self.assertIsNotNone(process.proc.poll())
        self.assertFalse(process.reader.is_alive())

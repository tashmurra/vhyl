"""Compiler selection is explicit and never falls back after an invalid override."""
from pathlib import Path
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

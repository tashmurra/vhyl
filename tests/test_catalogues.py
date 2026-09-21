"""A stale public interface catalogue must fail checking without rewriting it."""
from pathlib import Path
import importlib.util
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('export_surface', ROOT/'tools/export_surface.py')
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)


class CatalogueTests(unittest.TestCase):
    def test_check_is_read_only_and_detects_drift(self):
        with tempfile.TemporaryDirectory(prefix='vhyl catalogue ') as name:
            root = Path(name)
            path = root/'messages.json'
            path.write_text('stale content\n', encoding='utf-8')
            with patch.object(exporter, 'ROOT', root), patch.object(sys, 'argv', ['export_surface.py', '--check']):
                with self.assertRaisesRegex(ValueError, 'stale catalogue'):
                    exporter.write(path, 'messages', [{'id': 'example'}])
                self.assertEqual(path.read_text(encoding='utf-8'), 'stale content\n')
            with patch.object(sys, 'argv', ['export_surface.py']):
                self.assertTrue(exporter.write(path, 'messages', [{'id': 'example'}]))
            with patch.object(sys, 'argv', ['export_surface.py', '--check']):
                self.assertFalse(exporter.write(path, 'messages', [{'id': 'example'}]))

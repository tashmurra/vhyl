"""Wire-boundary tests for the standard-library example host."""
import importlib.util
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location('dialogue_host', Path(__file__).resolve().parents[1] / 'examples' / 'dialogue' / 'host.py')
host = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(host)


def word(n):
    return struct.pack('<Q', n)


def record(tag, raw):
    # Independent small packet: ID 'x', one entity handle, one typed value.
    body = word(1) + b'x' + bytes(7) + word(1) + word(2**63 + 7)
    body += word(1) + word(tag) + word(len(raw)) + raw + bytes(-len(raw) % 8)
    return word(1 + len(body) // 8) + body


class DialogueHostTests(unittest.TestCase):
    def test_entity_only_record_and_exact_handles(self):
        packet = word(5) + word(1) + b'x' + bytes(7) + word(1) + word(2**63 + 7)
        self.assertEqual(host.decode_events(packet), [
            {'id': 'x', 'subjects': [str(2**63 + 7)], 'values': []}])
        self.assertEqual(host.decode_events(record(3, word(2**64 - 1)))[0]['values'],
                         [str(2**64 - 1)])

    def test_unicode_and_signed_values(self):
        self.assertEqual(host.decode_events(record(4, 'λ\n"'.encode()))[0]['values'], ['λ\n"'])
        self.assertEqual(host.decode_events(record(2, struct.pack('<q', -2**31)))[0]['values'], [-2**31])
        self.assertEqual(host.decode_events(record(0, b''))[0]['values'], [None])
        self.assertEqual(host.decode_events(record(1, b''))[0]['values'], [True])

    def test_every_truncated_prefix_is_rejected(self):
        packet = record(4, b'choice')
        for size in range(1, len(packet)):
            with self.subTest(size=size), self.assertRaises(ValueError):
                host.decode_events(packet[:size])

    def test_invalid_tags_sizes_text_and_integer_range(self):
        for tag, raw in [(5, b''), (0, b'x'), (3, b''), (4, b'\xff'), (2, word(2**31))]:
            with self.subTest(tag=tag, raw=raw), self.assertRaises(ValueError):
                host.decode_events(record(tag, raw))
        with self.assertRaises(ValueError):
            host.decode_events(bytes(65544))

    def test_action_text_cannot_become_protocol(self):
        self.assertEqual(host.action_line(81, ['a\n@90', -3]), '@81 s:610a403930 i:-3')
        for arg in [True, 2**31, 'x' * 512]:
            with self.subTest(arg=arg), self.assertRaises(ValueError):
                host.action_line(81, [arg])


if __name__ == '__main__':
    unittest.main()

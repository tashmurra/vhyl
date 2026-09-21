#!/usr/bin/env python3
"""Example client for the generated consumer's scalar/event transport."""
import json
import os
from pathlib import Path
import queue
import struct
import subprocess
import threading
import time
import uuid

PACKET_LIMIT = 65536


def decode_events(data):
    if len(data) > PACKET_LIMIT or len(data) % 8:
        raise ValueError('invalid event batch length')
    events = []
    at = 0
    while at < len(data):
        def word(offset):
            if offset + 8 > end:
                raise ValueError('truncated event')
            return struct.unpack_from('<Q', data, offset)[0]

        end = len(data)
        words = word(at)
        if words < 3 or at + words * 8 > len(data):
            raise ValueError('invalid event length')
        end = at + words * 8
        size = word(at + 8)
        pos = at + 16
        if pos + size > end:
            raise ValueError('truncated event ID')
        name = data[pos:pos + size].decode('utf-8')
        pos += (size + 7) // 8 * 8
        count = word(pos)
        pos += 8
        if count > (end - pos) // 8:
            raise ValueError('truncated subjects')
        subjects = [word(pos + i * 8) for i in range(count)]
        pos += count * 8
        values = []
        if pos < end:
            count = word(pos)
            pos += 8
            if count > (end - pos) // 16:
                raise ValueError('truncated scalar records')
            for _ in range(count):
                tag, size = word(pos), word(pos + 8)
                pos += 16
                if pos + size > end:
                    raise ValueError('truncated scalar')
                raw = data[pos:pos + size]
                if tag in (0, 1) and size == 0:
                    value = None if tag == 0 else True
                elif tag == 2 and size == 8:
                    value = struct.unpack('<q', raw)[0]
                    if not -(2**31) <= value < 2**31:
                        raise ValueError('integer out of range')
                elif tag == 3 and size == 8:
                    # Keep 64-bit handles exact when serialized for JavaScript.
                    value = str(struct.unpack('<Q', raw)[0])
                elif tag == 4:
                    value = raw.decode('utf-8')
                else:
                    raise ValueError('unknown scalar type or size')
                values.append(value)
                pos += (size + 7) // 8 * 8
        if pos != end:
            raise ValueError('invalid event tail')
        events.append({'id': name, 'subjects': [str(x) for x in subjects], 'values': values})
        at = end
    return events


def action_line(verb, args=()):
    fields = ['@' + str(int(verb))]
    for arg in args:
        if isinstance(arg, str):
            fields.append('s:' + arg.encode('utf-8').hex())
        elif type(arg) is int and -(2**31) <= arg < 2**31:
            fields.append('i:' + str(arg))
        else:
            raise ValueError('expected text or i32 action argument')
    line = ' '.join(fields)
    if len(line) >= 1024:
        raise ValueError('example consumer command exceeds its 1023-byte line limit')
    return line


class Session:
    def __init__(self, bundle, messages=None, quotas=None):
        self.bundle = Path(bundle).resolve()
        manifest = json.loads((self.bundle / 'manifest.json').read_text(encoding='utf-8'))
        if manifest.get('scalar_transport', {}).get('version') != 1:
            raise ValueError('bundle lacks scalar transport v1')
        self.id = str(uuid.uuid4())
        self.messages = messages or {}
        self.transcript = []
        self.choices = []
        self.conversation = None
        self.token = None
        self.reason = None
        self.log = []
        self.raw_lines = []
        self.lines = queue.Queue()
        self.proc = subprocess.Popen([str(self.bundle / ('consumer.exe' if os.name == 'nt' else 'consumer')), *(quotas or [])],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', bufsize=1,
            env={**os.environ, 'ZEB_EVENTS': '2'}, cwd=self.bundle)

        def read():
            for line in self.proc.stdout:
                self.lines.put(line.rstrip('\n'))
            self.lines.put(None)

        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()
        self.read_boundary()

    def text(self, key, fallback):
        return self.messages.get(key, fallback if fallback is not None else key)

    def read_boundary(self):
        batch = []
        self.reason = None
        deadline = time.monotonic() + 30
        while True:
            line = self.lines.get(timeout=max(0.01, deadline - time.monotonic()))
            if line is None:
                raise RuntimeError('consumer stopped: ' + '\n'.join(self.raw_lines[-10:]))
            self.raw_lines.append(line)
            if line == '@ready':
                break
            if line.startswith('@events '):
                batch.extend(decode_events(bytes.fromhex(line[8:])))
        resync = False
        for event in batch:
            self.log.append(event)
            name, v = event['id'], event['values']
            if name == 'world.resync':
                self.choices = []
                self.token = None
                # Provisional spoken lines cannot be unplayed. Reset the visible
                # transcript explicitly rather than implying it was restored.
                self.transcript = []
                resync = True
            elif name == 'dialogue.utterance':
                self.transcript.append({'conversation': v[0], 'speaker': v[1],
                    'key': v[2], 'text': self.text(v[2], v[3]), 'private': bool(v[4]),
                    'asker': v[5], 'name': v[6] if len(v) > 6 else None})
            elif name == 'dialogue.choices':
                if len(v) < 5 or type(v[4]) is not int or not 0 <= v[4] <= 64 or len(v) != 5 + v[4] * 4:
                    raise ValueError('invalid choice snapshot')
                self.conversation, self.token = v[0], v[1]
                self.choices = [{'id': v[i], 'key': v[i + 1],
                    'text': self.text(v[i + 1], v[i + 2]), 'private': bool(v[i + 3])}
                    for i in range(5, len(v), 4)]
            elif name == 'dialogue.end':
                self.conversation = None
                self.choices = []
                self.token = None
                self.reason = v[1]
            elif name == 'dialogue.refused':
                self.reason = v[0]
        return resync

    def command(self, line, refresh=True):
        self.proc.stdin.write(line + '\n')
        self.proc.stdin.flush()
        resync = self.read_boundary()
        if resync and refresh:
            self.command(action_line(82), refresh=False)
        # Bounded example-host diagnostics and transcript.
        self.log = self.log[-2048:]
        self.raw_lines = self.raw_lines[-256:]
        self.transcript = self.transcript[-256:]
        return self.view()

    def action(self, verb, *args):
        return self.command(action_line(verb, args))

    def select(self, choice, token=None, conversation=None):
        return self.action(81, conversation or self.conversation,
                           self.token if token is None else token, choice)

    def view(self):
        return {'session': self.id, 'conversation': self.conversation,
                'token': self.token, 'choices': self.choices,
                'transcript': self.transcript, 'reason': self.reason}

    def close(self):
        if self.proc.poll() is None:
            self.proc.stdin.close()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.terminate()
                self.proc.wait(timeout=5)
        self.proc.stdout.close()
        self.reader.join(timeout=1)



def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    args = parser.parse_args()
    session = Session(args.bundle)
    try:
        session.action(80, 'consultation')
        print('Choices:', ', '.join(c['id'] for c in session.choices))
        session.select('route')
        for line in session.transcript:
            print(line['text'])
        session.select('goodbye')
    finally:
        session.close()


if __name__ == '__main__':
    main()

"""Actor parties, travel, scope, rollback and inspection through the public ABI."""
import json
import struct
import time
from support import ROOT, LineProcess, native_executable

def records(words):
    assert words[:2] == [1, 0], words[:3]
    result = []
    at = 3
    while at < len(words):
        size = words[at]
        assert size > 0 and at + size <= len(words)
        result.append(words[at+1:at+size])
        at += size
    assert len(result) == words[2]
    return result


class Host:
    def __init__(self, folder):
        self.manifest = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
        self.props = self.manifest['properties']
        self.index = {e['name']: e['index'] for e in self.manifest['entities']}
        self.contains = next(r['index'] for r in self.manifest['relations'] if r['forward'] == 'contains')
        self.connected = next(r['index'] for r in self.manifest['relations'] if r['forward'] == 'connects')
        self.process = LineProcess([native_executable(folder, 'following-host')], cwd=folder)
        self.transcript = []
        try:
            first = self.read()
            self.handles = {row[0]: row[1] for row in records(first['result'])}
            self.named = {name: self.handles[index] for name, index in self.index.items()}
            self.names = {value: key for key, value in self.named.items()}
        except BaseException:
            self.process.close(terminate=True)
            raise

    def read(self):
        lines = self.process.read_until('END')
        result = [int(x) for x in next(l for l in lines if l.startswith('RESULT')).split()[1:]]
        words = [int(x) for x in next(l for l in lines if l.startswith('EVENT')).split()[1:]]
        events = []
        at = 0
        while at < len(words):
            size, length = words[at:at+2]
            n = (length+7)//8
            name = b''.join(struct.pack('<Q', w) for w in words[at+2:at+2+n])[:length].decode()
            count = words[at+2+n]
            subjects = words[at+3+n:at+size]
            assert len(subjects) == count
            events.append((name, subjects))
            at += size
        text = bytes.fromhex(next(l[5:] for l in lines if l.startswith('TEXT '))).decode()
        frame = {'result': result, 'events': events, 'text': text}
        self.transcript.append(frame)
        return frame

    def query(self, kind, a, b, command):
        self.process.send(f'{kind} {a} {b}|{command}')
        return self.read()

    def scene(self, command, room):
        descriptor = self.contains | (self.connected << 12) | (1 << 24) | (1 << 25)
        frame = self.query(6, (self.props['presentation'] << 32) | descriptor, self.named[room], command)
        state = {}
        for row in records(frame['result']):
            handle, parent, member, count = row[:4]
            assert len(row) == 4 + 3*count
            props = {row[i]: (row[i+1], row[i+2]) for i in range(4, len(row), 3)}
            state[self.names.get(handle, str(handle))] = (self.names.get(parent, parent), member, props)
        frame['scene'] = state
        frame['moves'] = [[self.names.get(h, h) for h in subjects]
                          for name, subjects in frame['events'] if name == 'actor.move']
        return frame

    def close(self):
        self.process.close()


def placed(frame, names, room):
    for name in names:
        assert frame['scene'][name][0] == room, (name, frame['scene'].get(name), room)


def moved(frame, names, dest):
    moves = frame['moves']
    assert sorted(m[0] for m in moves) == sorted(names), moves
    assert all(m[1] == dest for m in moves), moves


def verify(folder):
    evidence = {}
    party = ['bob','jane','ann','cal','dee']
    def session(label, scenario):
        h = Host(folder)
        try:
            start=time.monotonic()
            scenario(h)
            evidence[label] = {'elapsed_seconds':time.monotonic()-start, 'frames':h.transcript}
        finally:
            h.close()
    def independent(h):
        f = h.scene('route', 'dock'); placed(f, party, 'dock'); moved(f, party, 'dock')
        assert f['scene']['gate'][0:2] == (0,1)
        assert f['scene']['gate'][2][h.props['isOpen']] == (1,1)
        assert f['scene']['janeFollowing'][2][h.props['accompanyingActor']] == (3,h.named['bob'])
        f = h.scene('north', 'tower'); placed(f, party, 'tower')
        assert sorted(m[0] for m in f['moves']) == sorted(party+['player','companion'])
        assert [m for m in f['moves'] if m[0] == 'companion'][0][1] == 'garden'
        f = h.scene('wait', 'dock'); placed(f, party, 'dock'); moved(f, party, 'dock')
        f = h.scene('undo', 'tower'); placed(f, party, 'tower')
        assert not f['moves'] and any(n=='world.resync' for n,_ in f['events'])
        f = h.scene('!3', 'dock'); placed(f, party, 'dock')
        assert not f['moves']
        # Its own agenda still ran; its competing travel waited, in both orders.
        f = h.query(4,h.props['presentation'],h.named['janeAgenda'],'halt')
        # janeAgenda explicitly publishes runs below.
        assert f['result'] == [h.props['runs'],2,1], f['result']
    session('offscreen-and-independent-groups', independent)
    def switching(h):
        f=h.scene('switch','plaza'); placed(f,['jane'],'plaza')
        assert f['scene']['janeFollowing'][2][h.props['accompanyingActor']] == (3,h.named['player'])
        f=h.scene('north','garden');placed(f,['player','companion','jane'],'garden')
        moved(f,['player','companion','jane'],'garden')
        f=h.scene('stop','garden'); assert not f['moves']
        f=h.scene('south','garden');placed(f,['jane'],'garden');moved(f,['player','companion'],'plaza')
    session('switch-and-stop', switching)
    def leader_undo(h):
        h.scene('switch','plaza')
        f=h.scene('undo','bay'); placed(f,['jane'],'bay')
        assert f['scene']['janeFollowing'][2][h.props['accompanyingActor']] == (3,h.named['bob'])
        assert not f['moves']
        h.scene('switch','plaza'); h.scene('stop','plaza')
        f=h.scene('undo','plaza')
        assert f['scene']['janeFollowing'][2][h.props['accompanyingActor']] == (3,h.named['player'])
    session('leader-change-undo',leader_undo)
    def maximum(h):
        f=h.scene('large','dock')
        assert len(f['moves']) == 64 and len({m[0] for m in f['moves']}) == 64
        assert all(m[1:] == ['dock','bay'] for m in f['moves'])
        assert sum(parent=='dock' and member==1 for parent,member,_ in f['scene'].values()) == 64
    session('64-member-chain',maximum)
    def excess(h):
        f=h.scene('overflow','bay'); assert not f['moves']
        assert sum(parent=='bay' and member==1 for parent,member,_ in f['scene'].values()) == 66 # party + crate
    session('65-member-refusal',excess)
    def barrier(h):
        h.scene('barrier','bay')
        f=h.scene('march','bay'); placed(f,party,'bay'); assert not f['moves']
    session('connector-refusal',barrier)
    def tour(h):
        f=h.scene('tour','plaza')
        assert f['scene']['companionTour'][2][h.props['accompanyingActor']] == (0,0)
        assert f['scene']['companionTour'][2][h.props['escortActor']] == (3,h.named['player'])
        assert f['scene']['companionTour'][2][h.props['escortDest']] == (3,h.named['garden'])
        f=h.scene('north','garden'); moved(f,['player','companion'],'garden')
        assert f['scene']['companion'][2][h.props['curState']] == (3,h.named['pcFollowing'])
        assert f['scene']['pcFollowing'][2][h.props['accompanyingActor']] == (3,h.named['player'])
    session('guided-tour-role-and-advance',tour)
    def visible(h):
        h.scene('watch','bay')
        f=h.scene('march','dock'); placed(f,party,'dock'); moved(f,party,'dock')
        if 'no-language' not in folder.name:
            assert 'Jane' in f['text'] and 'Bob' in f['text'], f['text']
    session('visible-native-departures',visible)
    def twice(h):
        f=h.scene('double','dock'); placed(f,party,'dock'); moved(f,party,'dock')
    session('one-journey-per-command',twice)
    def cycles(h):
        h.scene('cycle','bay')
        f=h.scene('march','dock');placed(f,party,'dock');moved(f,party,'dock')
    session('two-cycle-and-four-chain', cycles)
    def self_cycle(h):
        h.scene('self','bay')
        f=h.scene('selfwalk','dock');placed(f,['jane','ann','dee'],'dock');moved(f,['jane','ann','dee'],'dock')
    session('self-cycle', self_cycle)
    def blocked(h):
        h.scene('blocked','bay')
        f=h.scene('march','bay');placed(f,party,'bay');assert not f['moves']
        assert f['scene']['gate'][2][h.props['isOpen']] == (0,0)
    session('follower-refusal',blocked)
    def locked(h):
        h.scene('locked','bay')
        f=h.scene('march','bay');placed(f,party,'bay');assert not f['moves']
        f=h.scene('force','dock');placed(f,party,'dock');moved(f,party,'dock')
    session('travel-policy',locked)
    def fiat(h):
        f=h.scene('fiat','bay');placed(f,party[1:],'bay');moved(f,['bob'],'dock')
    session('fiat-no-escort',fiat)
    def rollback(h):
        f=h.scene('rollback','bay');placed(f,party,'bay');assert not f['moves']
        assert any(n=='world.resync' for n,_ in f['events']),f['events']
        f=h.scene('march','dock');placed(f,party,'dock');moved(f,party,'dock')
    session('rollback-and-retry',rollback)
    def empty_undo(h):
        for _ in range(2):
            f=h.scene('undo','plaza'); placed(f,['player','companion'],'plaza')
            assert not f['moves']
            assert ('undo.none',[]) in f['events'] and not any(n=='world.resync' for n,_ in f['events'])
    session('empty-undo-does-not-create-history',empty_undo)
    def repeated(h):
        h.scene('route','dock')
        for i in range(40):
            dest='tower' if i%2==0 else 'dock'
            f=h.scene('wait',dest); placed(f,party,dest); moved(f,party,dest)
    session('repeated-turns-past-history-bound',repeated)
    def inspection(h):
        f=h.scene('noop','bay');assert not f['moves'];placed(f,['coin'],'crate')
        assert f['scene']['coin'][1] == 1
        f=h.scene('noop','emptyRoom');assert len(f['scene']) == 1
        f=h.query(6,(h.props['presentation']<<32)|h.contains,2**64-1,'noop');assert f['result']==[1,2,0]
        f=h.query(8,h.contains,(1<<32)|h.index['bay'],'noop')
        r=records(f['result']);assert len(r)==1
        assert sorted(r[0][2:]) == sorted(h.named[n] for n in party+['crate'])
        f=h.query(0,h.contains,h.named['bay'],'noop');assert sorted(f['result'])==sorted(r[0][2:])
    session('inspection-and-compatibility',inspection)
    return evidence


def test(build):
    count = 0
    for name in ['actor-following', 'actor-following-no-language', 'actor-following-reordered']:
        folder = build.build(name, ROOT/'tests/fixtures'/f'{name}.t')
        manifest = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
        indices = [e['index'] for e in manifest['entities']]
        first, last = min(indices), max(indices)
        text = (ROOT/'tests/support/following_host.c.in').read_text(encoding='utf-8')
        for key, value in {'symbol': manifest['bundle']['symbol'], 'abi': manifest['bundle']['abi'],
                           'presentation': manifest['properties']['presentation'],
                           'range': ((last-first+1)<<32)|first}.items():
            text = text.replace('@'+key+'@', str(value))
        source = folder/'following-host.c'
        source.write_text(text, encoding='utf-8')
        build.compile_host(folder, source, 'following-host')
        results = verify(folder)
        count += len(results)
        print(f'{name}: {len(results)} scenarios passed', flush=True)
    return count

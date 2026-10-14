"""Action contract assertions through the pinned compiler's public transport."""
import sys
from support import ROOT
sys.path.insert(0, str(ROOT/'examples/dialogue'))
from host import Session, action_line


def values(s, name):
    return next(e['values'] for e in reversed(s.log) if e['id'] == name)


def state(s):
    s.action(89)
    return values(s, 'test.state')


def entities(s):
    s.action(88)
    names = 'cabinet brass steel parcel attendant guarded fragile weight socket secret remote player room'.split()
    return dict(zip(names, values(s, 'test.entities')))


def act(s, verb, *handles):
    s.command(' '.join([f'@{verb}', *(f'h:{h}' for h in handles)]))


def preview(s, verb, *handles):
    before = len(s.log)
    s.command(' '.join(['@83', f'i:{verb}', *(f'h:{h}' if h else 'i:0' for h in handles)]))
    assert [e['id'] for e in s.log[before:]] == ['action.preview'], s.log[before:]
    return values(s, 'action.preview')


def test(build):
    bundle = build.build('action-preview', ROOT/'tests/fixtures/action-preview.t')
    s = Session(bundle)
    try:
        h = entities(s)
        baseline = state(s)
        assert baseline[:5] == [0, 0, 0, True, None]
        assert baseline[7] is None
        s.action(87)
        assert values(s, 'test.verify') == [90, True, None], 'rank must not deny an explicit attempt'
        # Keys are equally plausible; neither check nor rank is disclosed.
        brass = preview(s, 41, h['cabinet'], h['brass'])
        steel = preview(s, 41, h['cabinet'], h['steel'])
        assert brass[5:] == steel[5:] == [None, None, True, True, True, 'menu.unlock', None, None, 0]
        partial = preview(s, 41, h['cabinet'])
        assert partial[5:8] == [None, None, True]
        partial = preview(s, 58, None, h['attendant'])
        assert partial[3:8] == [None, h['attendant'], True, None, None]
        assert preview(s, 58, h['parcel'])[5:7] == [None, True]
        disabled = preview(s, 90, h['cabinet'], h['socket'])
        assert disabled[8:] == [True, None, 'menu.fit', 'test.fixed', None, 1, h['cabinet']]
        assert preview(s, 20, h['parcel'])[12] is True, 'default must come from author policy'
        hidden = preview(s, 20, h['secret'])
        assert hidden[8:] == [None, None, None, None, None, 0]
        assert preview(s, 999)[2] == 'unknown-verb'
        s.command('@83 i:41 ' + ' '.join(f'h:{h[k]}' for k in ('cabinet', 'brass', 'steel')))
        assert s.log[-1]['id'] == 'action.preview.invalid'
        s.command('@83 i:41 s:626164')
        assert values(s, 'action.preview')[2] == 'invalid'
        s.command('@83')
        assert s.log[-1]['id'] == 'action.preview.invalid'
        assert state(s) == baseline
        for _ in range(100):
            preview(s, 41, h['cabinet'], h['steel'])
            preview(s, 90, h['parcel'], h['socket'])
        assert state(s) == baseline, 'previews changed state, knowledge, history or hooks'

        # An explicit wrong key must not fall back to the carried correct key.
        act(s, 41, h['cabinet'], h['steel'])
        assert state(s)[:5] == [1, 1, 1, True, None]
        act(s, 41, h['cabinet'], h['brass'])
        assert state(s)[:5] == [2, 2, 2, None, None]
        for _ in range(5): preview(s, 41, h['cabinet'])
        s.action(3)
        assert state(s)[:5] == [1, 1, 1, True, None], 'preview consumed an undo interval'
        # Nested implicit unlock/open/take must preserve the outer command.
        act(s, 51, h['parcel'], h['cabinet'])
        assert state(s)[4:6] == [True, 2]
        save = build.out/'action-preview.zsave'
        saved = state(s)
        s.command(':save ' + str(save) + '\n' + action_line(89))
        assert any('[save ok code=0]' in line for line in s.raw_lines)
        before_failure = state(s)
        s.action(92)
        assert state(s) == before_failure, 'failed check did not roll back state and knowledge'
        preview(s, 41, h['cabinet'])
        assert state(s) == before_failure
    finally:
        s.close()

    s = Session(bundle)
    try:
        s.command(':restore ' + str(save) + '\n' + action_line(89))
        restored = state(s)
        assert restored[0] == saved[0] and restored[1] == 0 and restored[2:] == saved[2:]
        h = entities(s)
        for _ in range(10): preview(s, 41, h['cabinet'], h['steel'])
        assert state(s) == restored
    finally:
        s.close()

    # Independently execute equivalent text and structured command sequences.
    outcomes = []
    for typed in (True, False):
        s = Session(bundle)
        try:
            h = entities(s)
            s.command('unlock all with steel key')
            assert state(s)[:5] == [1, 1, 1, True, None], 'all ignored the explicit optional key'
            s.action(3)
            act(s, 93, h['parcel'])
            assert state(s)[5:11] == [0, True, None, 0, 0, 0], 'indirect role allowed implicit execution'
            s.action(3)
            commands = [
                ('unlock cabinet with steel key', 41, ['cabinet', 'steel']),
                ('unlock cabinet with brass key', 41, ['cabinet', 'brass']),
                ('lock cabinet with steel key', 42, ['cabinet', 'steel']),
                ('lock cabinet with brass key', 42, ['cabinet', 'brass']),
                ('take seal', 21, ['guarded']),
                ('take weight', 21, ['weight']),
                ('fit vial to attendant', 90, ['fragile', 'attendant']),
                ('take vial', 21, ['fragile']),
                ('fit vial to socket', 90, ['fragile', 'socket']),
                ('fit vial to attendant', 90, ['fragile', 'attendant']),
                ('fit steel key to socket', 90, ['steel', 'socket']),
                ('fit brass key to socket', 90, ['brass', 'socket']),
                ('fit parcel to socket', 90, ['parcel', 'socket']),
                ('fit cabinet to socket', 90, ['cabinet', 'socket']),
                ('think about marker', 48, ['remote']),
            ]
            rows = []
            for text, code, args in commands:
                if typed: s.command(text)
                else: act(s, code, *(h[name] for name in args))
                rows.append(state(s))
            assert [r[0] for r in rows] == list(range(1, len(commands)+1))
            assert [r[9] for r in rows] == [0]*9 + [1, 1, 1, 2, 2, 2], rows
            assert rows[-1][7] is True and rows[-1][10] == 2
            emitted = [e['id'] for e in s.log]
            for message in ('test.guarded', 'test.fragile', 'test.key', 'test.heavy'):
                assert message in emitted, message
            assert rows[5][11:13] == rows[4][11:13], 'legacy refusal reached actor/execution hooks'
            outcomes.append(rows)
            before = state(s)
            s.action(91)
            assert state(s)[9] == before[9], 'no-argument verification was bypassed'
        finally:
            s.close()
    # Histories contain parser temporaries differently, but intervals and world
    # observations, including report/hook counts, must agree exactly.
    assert outcomes[0] == outcomes[1], outcomes
    print('Action previews: observational queries, disclosure, optional keys, both roles, verification/checks, implicit actions, parity, undo and restore passed', flush=True)

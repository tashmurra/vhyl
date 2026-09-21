"""Independent dialogue and persistence assertions using the public host transport."""
import sys
from support import ROOT
sys.path.insert(0, str(ROOT/'examples/dialogue'))
from host import Session, action_line

def ids(s):
    return [x['id'] for x in s.choices]


def state(s):
    s.action(89)
    return next(e['values'] for e in reversed(s.log) if e['id'] == 'test.state')


def rejected(s):
    return any(e['id'] == 'dialogue.refused' for e in s.log[-3:])


def test(build):
    out = build.out
    for name, source in [('interview', 'dialogue-choices.t'), ('limits', 'dialogue-limits.t'),
                         ('event-only', 'dialogue-event-only.t')]:
        build.build(name, ROOT/'tests/fixtures'/source)
    s = Session(out / 'interview', quotas=['1500', '30000', '8388608'])
    try:
        assert state(s)[:2] == [0, 0]
        s.action(80, 'interview')
        assert ids(s) == ['goodbye']
        assert [x['key'] for x in s.transcript] == ['visitor.greeting', 'archivist.greeting']
        baseline = state(s)
        for _ in range(10): s.action(82)
        assert state(s) == baseline, 'refresh changed time/history'
        s.select('ask-signal')
        assert rejected(s) and state(s) == baseline
        s.action(90)
        assert ids(s) == ['ask-signal', 'goodbye']
        before_question = state(s)
        old_token = s.token
        s.select('ask-signal')
        assert ids(s) == ['follow-up', 'reflect', 'goodbye']
        assert state(s)[0] == before_question[0] + 1
        assert state(s)[2] is True, 'another asker inherited once-only consumption'
        baseline = state(s)
        for token, conv, choice in [(old_token, 'interview', 'ask-signal'),
                                    (s.token, 'wrong', 'follow-up'),
                                    (s.token, 'interview', 'other-private')]:
            s.select(choice, token=token, conversation=conv)
            assert rejected(s) and state(s) == baseline
        s.action(3)
        assert ids(s) == ['ask-signal', 'goodbye'], 'undo did not restore once-only option'
        s.select('ask-signal')
        s.action(91)
        assert ids(s) == ['follow-up', 'challenge', 'reflect', 'goodbye']
        s.action(92)
        assert ids(s) == ['follow-up', 'reflect', 'goodbye']
        s.action(3)
        assert 'challenge' in ids(s)
        s.action(95)
        assert 'follow-up' not in ids(s), 'authored availability was ignored'
        s.action(95)
        assert 'follow-up' in ids(s)
        s.select('reflect')
        assert 'consider' in ids(s) and s.transcript[-1]['private']
        assert 'other-private' not in ids(s)
        saved_choices = ids(s)
        saved_time = state(s)[0]
        save = out / 'interview.zsave'
        s.command(':save ' + str(save) + '\n' + action_line(82))
        assert any('[save ok code=0]' in x for x in s.raw_lines)
        s.action(97)
        before_fail = state(s)
        assert 'fail' in ids(s)
        s.select('fail')
        assert state(s) == before_fail, 'failed choice changed state or history'
        assert 'fail' in ids(s) and not state(s)[3]
        assert not s.transcript, 'provisional failed lines survived resync'
        # Timer closes the conversation after exactly two further exchanges.
        s.action(96)
        s.select('follow-up')
        assert s.conversation == 'interview'
        s.select('follow-up')
        assert s.conversation is None and not ids(s)
        s.action(3)
        assert 'follow-up' in ids(s), 'undo did not restore interrupted conversation'
        s.select('goodbye')
        assert s.conversation is None
        s.action(80, 'thoughts')
        assert ids(s) == ['consider', 'goodbye']
        s.select('consider')
        assert s.transcript[-1]['private']
    finally:
        s.close()

    s = Session(out / 'interview', quotas=['1500', '30000', '8388608'])
    try:
        s.command(':restore ' + str(save) + '\n' + action_line(82))
        assert any('[restore ok code=0]' in x for x in s.raw_lines)
        assert ids(s) == saved_choices and not s.transcript
        assert state(s)[:2] == [saved_time, 0], 'restore did not reset history'
        for _ in range(300):
            before = state(s)
            s.action(82)
            assert state(s) == before
            token = s.token
            s.select('follow-up')
            after = state(s)
            assert after[0] == before[0] + 1
            s.select('follow-up', token=token)
            assert state(s) == after
    finally:
        s.close()

    s = Session(out / 'limits')
    try:
        s.action(80, 'limit65')
        assert s.conversation is None and state(s)[:2] == [0, 0]
        s.action(80, 'duplicates')
        assert s.conversation is None and state(s)[:2] == [0, 0]
        s.action(80, 'limit64')
        assert ids(s) == [f'limit-{i}' for i in range(64)]
        s.select('limit-63')
        assert len(s.choices) == 64
    finally:
        s.close()

    s = Session(out / 'event-only', messages={'choice.signal': 'Une question', 'visitor.greeting': 'Bonjour'})
    try:
        s.action(80, 'interview')
        assert s.transcript[0]['text'] == 'Bonjour'
        s.action(90)
        assert s.choices[0]['text'] == 'Une question'
        s.select('ask-signal')
        assert ids(s) == ['follow-up', 'reflect', 'goodbye']
        # Missing text is represented as nil; fallback keys never affect identity.
        assert s.transcript[-1]['text'] == 'archivist.denial'
    finally:
        s.close()

    s = Session(out / 'interview')
    try:
        s.action(80, 'topic-interview')
        assert ids(s) == ['goodbye']
        s.action(90)
        assert ids(s) == ['topic-question', 'goodbye']
        s.select('topic-question')
        assert s.transcript[-1]['key'] == 'archivist.follow-up'
    finally:
        s.close()

    print('Dialogue: eligibility, rollback, persistence, limits, localisation and 300 exchanges passed', flush=True)

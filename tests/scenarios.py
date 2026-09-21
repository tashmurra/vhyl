"""Original compact worlds check observable library behaviour and published examples."""
from pathlib import Path
import re
import sys
from support import ROOT, run
sys.path.insert(0, str(ROOT/'examples/dialogue'))
from host import Session


def consumer(bundle, text):
    return run([bundle/'consumer'], cwd=bundle, input=text, timeout=60).stdout


def states(text):
    return re.findall(r'\[state ([^\]]+)\]', text)


def test(build):
    text = build.build('text-example', ROOT/'examples/text/main.t')
    output = consumer(text, 'look\ntake gauge\ninventory\nask attendant about route\n')
    assert 'brass gauge' in output and 'The gallery is north of here.' in output, output
    messages = build.build('messages', ROOT/'tests/fixtures/messages.t')
    output = consumer(messages, 'take gauge\n')
    assert 'Custom acquisition.' in output and 'Inactive text must not appear.' not in output, output
    actions = build.build('actions', ROOT/'tests/fixtures/actions.t')
    output = consumer(actions, 'take gauge\nput gauge in case\ntake weight\nwait\nundo\n')
    rows = states(output)
    assert len(rows) == 5, output
    assert 'held=1 boxed=0' in rows[0], rows
    assert 'held=0 boxed=1 open=1 weight=1' in rows[1], rows
    assert 'held=0 boxed=1 open=1 weight=1' in rows[2], rows
    assert 'The reference weight stays here.' in output
    assert rows[-1] == rows[-3], rows
    assert int(rows[-2].split('ticks=')[1]) == int(rows[-3].split('ticks=')[1])+1
    save = build.out/'actions.zsave'
    output = consumer(actions, f'take gauge\n:save {save}\ndrop gauge\n')
    assert '[save ok code=0]' in output, output
    output = consumer(actions, f':restore {save}\ninventory\n')
    assert '[restore ok code=0]' in output and 'held=1 boxed=0' in states(output)[-1], output
    output = consumer(actions, 'north\nsouth\n')
    assert 'room=Gallery' in states(output)[0] and 'room=Workshop' in states(output)[1], output
    structured = build.build('structured-example', ROOT/'examples/structured/main.t')
    output = consumer(structured, '!10\n!11\n')
    assert 'Platform' in output and 'Station' in output, output
    dialogue = build.build('dialogue-example', ROOT/'examples/dialogue/main.t')
    session = Session(dialogue)
    try:
        session.action(80, 'consultation')
        assert [c['id'] for c in session.choices] == ['route', 'goodbye']
        session.select('route')
        assert [c['id'] for c in session.choices] == ['goodbye']
        assert session.transcript[-1]['text'] == 'The reading room is upstairs.'
        session.select('goodbye')
        assert session.conversation is None
    finally:
        session.close()
    output = run([sys.executable, '-B', ROOT/'examples/dialogue/host.py', dialogue], cwd=build.out).stdout
    assert 'The reading room is upstairs.' in output, output
    print('Examples/actions: parser, structured input, implied opening, refusal, travel, scheduling, undo, save/restore and dialogue passed', flush=True)

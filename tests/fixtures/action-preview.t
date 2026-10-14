/* Independent world for preview purity, shared execution and disclosure tests. */
#define CUSTOM_ACTION_ENTRY 1
#include "../../examples/actions/main.t"
#include <vhyl-dialogue.t>

testState: object
    ticks = 0
    checks = 0
    executions = 0
    reports = 0
    before = 0
    after = 0
    tick() { ticks += 1; return nil; }
;
pulse: Daemon owner = testState prop = &tick interval = 1;
watching: ActorState
    beforeAction(c) { testState.before += 1; return nil; }
    afterAction(c) { testState.after += 1; return nil; }
;
modify attendant curState = watching;

guarded: Thing 'guarded seal' location(workshop) vocab = 'seal; guarded'
    verify(c)
    {
        if (c.action == takeAction) return verificationFailure('test.guarded', self, nil);
        return inherited(c);
    }
;
fragile: Thing 'fragile vial' location(workshop) vocab = 'vial; fragile'
    rank(a, role) { return a == takeAction ? rankDangerous : rankLogical; }
;
weight: Thing 'weight' location(workshop) vocab = 'weight'
    refuses(a, c) { return a == takeAction ? 'Legacy refusal.' : nil; }
;
socket: Thing 'socket' location(workshop) vocab = 'socket'
    verify(c)
    {
        if (c.action == fitAction && c.role == iobjRole && c.dobj == fragile)
            return verificationFailure('test.fragile', c.dobj, self);
        local r = inherited(c);
        if (c.action == fitAction && c.role == iobjRole) r.implicitAllowed = nil;
        return r;
    }
    check(c)
    {
        if (c.action == fitAction && c.role == iobjRole && c.dobj == brassKey)
            return verificationFailure('test.heavy', c.dobj, self);
        return nil;
    }
;
secret: Topic 'secret' vocab = 'secret' isFamiliar = nil;
outside: Room 'Outside';
remote: Thing 'remote marker' location(outside) vocab = 'marker; remote';

fitAction: Action
    needsDobj = true needsIobj = true
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    verify(c)
    {
        if (c.actor != player) return verificationFailure('test.actor', nil, nil);
        if (c.role == dobjRole && c.dobj == cabinet)
            return verificationFailure('test.cabinet', cabinet, nil);
        return inherited(c);
    }
    check(c)
    {
        testState.checks += 1;
        if (c.dobj == steelKey) return verificationFailure('test.key', c.dobj, c.iobj);
        return nil;
    }
    exec(c)
    {
        testState.executions += 1; player.setKnowsAbout(secret);
        noteDone(c, c.dobj); return nil;
    }
    report(c) { testState.reports += 1; return nil; }
    affordance(c)
    {
        local f = new ActionAffordance();
        f.visible = true; f.labelId = 'menu.fit';
        if (c.dobj == cabinet)
        {
            f.enabled = nil; f.reasonId = 'test.fixed'; f.reasonArgs = [cabinet];
        }
        return f;
    }
;
vFit: Verb code = 90 action = fitAction label = 'fit';
grammar command(fit): 'fit' nounPhrase->dobj_ 'to' nounPhrase->iobj_ : Command action = fitAction;

/* No-argument verification must run too. */
deniedAction: Action
    verify(c) { return verificationFailure('test.denied', nil, nil); }
    exec(c) { testState.executions += 100; return nil; }
;
vDenied: Verb code = 91 action = deniedAction label = 'deny';

failingAction: Action
    check(c)
    {
        testState.checks += 1; player.setKnowsAbout(secret);
        throw new ActionPreviewError();
    }
;
vFailing: Verb code = 92 action = failingAction label = 'fail-check';

needsFit: PreCondition
    met(item, a, c) { return testState.executions > 0; }
    impliedVerb(item, a, c) { return 90; }
    impliedDobj(item, a, c) { return parcel; }
    impliedIobj(item, a, c) { return socket; }
;
requireFitAction: Action
    needsDobj = true
    preCond(item, role) { return [needsFit]; }
    exec(c) { testState.executions += 100; return nil; }
;
vRequireFit: Verb code = 93 action = requireFitAction label = 'require-fit';

testGuarded: Message id = 'test.guarded' text = 'The seal must stay.';
testFragile: Message id = 'test.fragile' text = 'The vial would break.';
testHeavy: Message id = 'test.heavy' text = 'That key will not fit here.';
testKey: Message id = 'test.key' text = 'The steel key will not fit.';
testCabinet: Message id = 'test.cabinet' text = 'The cabinet will not fit.';
testFixed: Message id = 'test.fixed' text = 'The cabinet is fixed.';
testDenied: Message id = 'test.denied' text = 'Refused without arguments.';

/* Diagnostic queries allocate only Turn objects and emit dedicated test events. */
act(verb, args)
{
    if (verb == 89)
    {
        event('test.state');
        eventValue(turnCount.value); eventValue(undoDepth()); eventValue(testState.ticks);
        eventValue(cabinet.isLocked); eventValue(cabinet.isOpen);
        eventValue(contains.contains(cabinet, parcel) ? 2 : carried(parcel) ? 1 : 0);
        eventValue(carried(brassKey));
        eventValue(player.knowsAbout(secret));
        eventValue(testState.checks); eventValue(testState.executions); eventValue(testState.reports);
        eventValue(testState.before); eventValue(testState.after);
        eventValue(lastNamed.items == nil ? 0 : lastNamed.items.length());
        return nil;
    }
    if (verb == 88)
    {
        event('test.entities');
        foreach (local item in [cabinet, brassKey, steelKey, parcel, attendant,
                               guarded, fragile, weight, socket, secret, remote, player, workshop])
            eventValue(item);
        return nil;
    }
    if (verb == 87)
    {
        local c = new Command(); c.action = takeAction; c.dobj = fragile;
        local r = verifyAction(c);
        event('test.verify'); eventValue(r.rank); eventValue(r.allowed); eventValue(r.implicitAllowed);
        return nil;
    }
    return vhylAct(verb, args);
}

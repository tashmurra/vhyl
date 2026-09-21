#include <vhyl.h>
#include <vhyl.t>
#ifndef FOLLOWING_NO_LANGUAGE
#include <vhyl-en.t>
#endif

plaza: Room 'Plaza' exits(garden, north);
garden: Room 'Garden' exits(plaza, south);
bay: Room 'Bay' exits(gate, east);
dock: Room 'Dock' exits(gate, west) exits(tower, east);
tower: Room 'Tower' exits(dock, west);
gate: Door 'gate' connects(bay) connects(dock)
    isOpenable = true
    isOpen = nil
;
crate: Thing 'crate' location(bay) isContainer = true;
coin: Thing 'coin' location(crate);
emptyRoom: Room 'Empty';

#ifndef FOLLOWERS_FIRST
#include "actor-following-bob.h"
#endif
jane: Actor 'Jane' location(bay) vocab = 'Jane';
ann: Actor 'Ann' location(bay) vocab = 'Ann';
cal: Actor 'Cal' location(bay)
    vocab = 'Cal'
    willing = true
    canAccompanyTravel(leader, conn, dest) { return willing; }
;
dee: Actor 'Dee' location(bay) vocab = 'Dee';
#ifdef FOLLOWERS_FIRST
#include "actor-following-bob.h"
#endif
companion: Actor 'Companion' location(plaza) vocab = 'companion';
janeFollowing: AccompanyingState actor = jane accompanyingActor = bob;
annFollowing: AccompanyingState actor = ann accompanyingActor = jane;
calFollowing: AccompanyingState actor = cal accompanyingActor = bob;
deeFollowing: AccompanyingState actor = dee accompanyingActor = ann;
pcFollowing: AccompanyingState
    actor = companion
    getAccompanyingTravelState(leader, conn) { return companionWalking; }
;
companionWalking: AccompanyingInTravelState actor = companion;
companionTour: GuidedTourState
    actor = companion escortDest = garden stateAfterEscort = pcFollowing
;
bobIdle: ActorState actor = bob isInitState = true;
bobFollowing: AccompanyingState actor = bob accompanyingActor = jane;

janeAgenda: AgendaItem
    presentation = [&runs]
    actor = jane offstage = true isActive = nil interval = 1
    runs = 0
    invokeItem()
    {
        runs = runs + 1;
        jane.scriptedTravelTo(contains.outermost(jane) == bay ? dock : bay);
        return nil;
    }
;
routeAgenda: AgendaItem
    actor = bob offstage = true isActive = nil interval = 1
    invokeItem()
    {
        local room = contains.outermost(bob);
        bob.scriptedTravelTo(room == bay ? dock : room == dock ? tower : dock);
        return nil;
    }
;

routeAction: Action
    exec(c) { routeAgenda.isActive = true; janeAgenda.isActive = true; return nil; }
;
haltAction: Action
    exec(c) { routeAgenda.isActive = nil; janeAgenda.isActive = nil; return nil; }
;
marchAction: Action exec(c) { bob.scriptedTravelTo(dock); return nil; };
forceAction: Action exec(c) { bob.travelTo(dock, gate); return nil; };
fiatAction: Action exec(c) { bob.moveIntoForTravel(dock); return nil; };
blockedAction: Action exec(c) { cal.willing = nil; return nil; };
lockedAction: Action exec(c) { gate.isLocked = true; return nil; };
switchAction: Action
    exec(c)
    {
        janeFollowing.accompanyingActor = player;
        jane.moveIntoForTravel(plaza);
        return nil;
    }
;
stopAction: Action exec(c) { janeFollowing.accompanyingActor = nil; return nil; };
cycleAction: Action exec(c) { bob.setCurState(bobFollowing); return nil; };
selfAction: Action exec(c) { janeFollowing.accompanyingActor = jane; return nil; };
selfWalkAction: Action exec(c) { jane.travelTo(dock, gate); return nil; };
rollbackAction: Action
    exec(c)
    {
        bob.travelTo(dock, gate);
        local zero = turnCount.value - turnCount.value;
        return 1 / zero;
    }
;
noopAction: Action exec(c) { bob.travelTo(bay, nil); return nil; };

longParty(count)
{
    local lead = dee;
    for (local i = 0; i < count; i = i + 1)
    {
        local a = new Actor;
        local state = new AccompanyingState;
        state.accompanyingActor = lead;
        a.setCurState(state);
        contains.set(bay, a);
        lead = a;
    }
    return nil;
}
largeAction: Action exec(c) { longParty(59); bob.travelTo(dock, gate); return nil; };
overflowAction: Action exec(c) { longParty(60); bob.travelTo(dock, gate); return nil; };
barrierAction: Action exec(c) { gate.canPass = nil; return nil; };
grammar command(largeTest): 'large' : Command action = largeAction;
grammar command(overflowTest): 'overflow' : Command action = overflowAction;
grammar command(barrierTest): 'barrier' : Command action = barrierAction;

tourAction: Action exec(c) { companion.setCurState(companionTour); return nil; };
watchAction: Action exec(c) { contains.set(bay, player); return nil; };
doubleAction: Action
    exec(c) { bob.travelTo(dock, gate); bob.travelTo(tower, nil); return nil; }
;
grammar command(tourTest): 'tour' : Command action = tourAction;
grammar command(watchTest): 'watch' : Command action = watchAction;
grammar command(doubleTest): 'double' : Command action = doubleAction;

grammar command(routeTest): 'route' : Command action = routeAction;
grammar command(haltTest): 'halt' : Command action = haltAction;
grammar command(marchTest): 'march' : Command action = marchAction;
grammar command(forceTest): 'force' : Command action = forceAction;
grammar command(fiatTest): 'fiat' : Command action = fiatAction;
grammar command(blockedTest): 'blocked' : Command action = blockedAction;
grammar command(lockedTest): 'locked' : Command action = lockedAction;
grammar command(switchTest): 'switch' : Command action = switchAction;
grammar command(stopTest): 'stop' : Command action = stopAction;
grammar command(cycleTest): 'cycle' : Command action = cycleAction;
grammar command(selfTest): 'self' : Command action = selfAction;
grammar command(selfWalkTest): 'selfwalk' : Command action = selfWalkAction;
grammar command(rollbackTest): 'rollback' : Command action = rollbackAction;
grammar command(noopTest): 'noop' : Command action = noopAction;

modify gameMain initialRoom = plaza;
startup() { vhylStart(); return nil; }
turn(toks) { vhylTurn(toks); return nil; }
act(verb, subjects) { vhylAct(verb, subjects); return nil; }

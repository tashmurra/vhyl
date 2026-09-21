/* Adventure world policy: entities, actions, reports, actors and scheduling.
 * Copyright (c) 2026 John Cunningham. MIT License; see LICENSE. */

/*
 * vhyl core: things, rooms, scope, and the command cycle.
 *
 * What a world declares is an entity and its rows. What this file supplies is
 * what every world would otherwise write again: what is in scope, what is
 * visible, how a room is described, and the verbs that move things about.
 */

class Thing: object

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos]
    name = nil
/* A container holds things, and holds them shut when it can be closed. */
    isContainer = nil
    isOpenable = nil
    isOpen = true
/* Fixed things stay where they are: scenery, fittings, rooms. */
    isFixed = nil
/* Described in the room, or passed over as part of the furniture. */
    isDecoration = nil

    desc = nil
/* Gives light when it is lit. A candle is a light source unlit. */
    isLightSource = nil
    isLit = nil

    rank(a, role) { return isDecoration ? rankUnlikely : rankLogical; }

    cannotTakeMsg = nil
    cannotOpenMsg = nil

    bulk = 1
    bulkCapacity = 0
/* Whether what is inside is mentioned when the room is described. */
    contentsListed = true
/* The largest single thing that fits, whatever room is left. */
    maxSingleBulk = 0
/* Seen into while shut. */
    isTransparent = nil

    isAttachable = nil
    isLockable = nil
    isLocked = nil
/*
     * Being worn. On Thing rather than on Wearable for the same reason locking
     * is: a precondition has to be able to ask it of anything it is given.
     */
    isWorn = nil
/* What unlocks it. nil on a lockable thing means nothing does. */
    keyItem = nil

    isDistant = nil
/* Whether subjects may be looked up in it; see Consultable. */
    isConsultable = nil
/* Seen and never touched; see Intangible. */
    isIntangible = nil

    isOutOfReach = nil
    canObjReachSelf(who) { return nil; }

    specialDesc = nil
    hasSpecialDesc = nil

    allowedPostures = [standing]
    defaultPosture = standing

    roomBeforeAction(c) { return nil; }

    seen = nil

    isFamiliar = nil

    knowsAbout(obj)
    {
        if (obj == nil)
            return nil;

        if (dataType(obj) == TypeSString)
            return holds(informedOf, obj);
        return obj.isFamiliar || knows.contains(self, obj);
    }

    setKnowsAbout(obj)
    {
        if (obj == nil)
            return nil;
        if (dataType(obj) == TypeSString)
        {
            if (!holds(informedOf, obj))
                informedOf = informedOf + [obj];
        }
        else if (!knows.contains(self, obj))
            knows.set(self, obj);
        return nil;
    }
/* Forget a fact tag. Things are not forgotten; a fact can be superseded. */
    forget(tag)
    {
        local kept = [];
        foreach (local t in informedOf)
        {
            if (t != tag)
                kept = kept + [t];
        }
        informedOf = kept;
        return nil;
    }

    informedOf = []

    initiallyKnowsAbout = nil

    known = (player.knowsAbout(self))
/*
     * A name that takes no article: a person, a place, a ship. vhyl had no such
     * notion, so a library message about an actor said *the Zoé*, and one about
     * the player said *the you*. What an article is doing there is the language
     * module's business; **whether the name takes one** is the world's.
     */
    isProper = nil

    isPlural = nil
    isMassNoun = nil

    isHim = nil
    isHer = nil
    isGenderNeutral = nil

    isIt = (!(isHim || isHer || isGenderNeutral))

    pcReferralPerson = SecondPerson

    bulkLimit = 0

    isEdible = nil
    isDrinkable = nil
    fluidName = nil
/* Whether this will take something poured into it. */
    allowPourIntoMe = nil
/*
     * Where a thing put here comes to rest. An enumerator, not a preposition:
     * the word for it belongs to the language module.
     */
    objPos = posIn

    remapIn = nil
    remapOn = nil
    remapBehind = nil

    remapUnder = nil
/* Out of sight until someone finds it. */
    isHidden = nil

    notifyInsert(item) { return nil; }

    refuses(action, c) { return nil; }

    preCond(a, role) { return []; }

    beforeTravel(traveller, conn) { return nil; }
    afterTravel(traveller, conn) { return nil; }
;

class Room: Thing
    isFixed = true
/* Lit by itself. A DarkRoom is not, and needs something carried. */
    isLit = true
;

/* Somewhere the player cannot see without a light. */
class DarkRoom: Room
    isLit = nil
;

/* Outdoors: lit by the sky rather than by anything carried. */
class OutdoorRoom: Room
    isLit = true
;

/* Templates, so a declaration reads as a sentence. */
Thing template'name';
Room template'name';
DarkRoom template'name';
OutdoorRoom template'name';

/*
 * The player. `vocab` so they can be referred to at all: without it `X ME`
 * answered *I don't understand that* in every game ever written against vhyl,
 * and looking at yourself is the first thing a good many players do.
 */
player: Thing'you'
    travelCycle = -1
    vocab ='me; my; myself self you'
;

gameMain: object
    initialRoom = nil
/* Displayed once at the start. An emitting string, like desc. */
    intro =""

    usePastTense = nil
;

vhylStart()
{
/* An emitting property displays when it is read; interpolating it would
     * print it and then interpolate the nil it answers. */
    gameMain.intro;
"\n\n";
    if (gameMain.initialRoom == nil)
"vhyl: no initial room; set `modify gameMain initialRoom = ...`.\n";
    else
    {
        contains.set(gameMain.initialRoom, player);

        for (local a = firstObj(Actor); a != nil; a = nextObj(a, Actor))
        {
            if (a.curState != nil)
                continue;
            local first = nil;
            for (local st = firstObj(ActorState); st != nil; st = nextObj(st, ActorState))
            {
                if (st.actor != a)
                    continue;
                if (st.isInitState)
                {
                    first = st;
                    break;
                }
                if (first == nil)
                    first = st;
            }
            if (first != nil)
                a.setCurState(first);
        }

        for (local t = firstObj(Thing); t != nil; t = nextObj(t, Thing))
        {
            if (t.initiallyKnowsAbout == nil)
                continue;
            foreach (local subject in t.initiallyKnowsAbout)
                t.setKnowsAbout(subject);
        }

        for (local i = firstObj(InitObject); i != nil; i = nextObj(i, InitObject))
            i.execute();

        syncStates();
        describeRoom();
    }
    return nil;
}

/* ------------------------------------------------------------- directions */

allDirections: object
    ways = [north, south, east, west,
            northeast, northwest, southeast, southwest,
            up, down, inward, outward]
;

oppositeOf(way)
{
    if (way == north) return south;
    if (way == south) return north;
    if (way == east) return west;
    if (way == west) return east;
    if (way == northeast) return southwest;
    if (way == southwest) return northeast;
    if (way == northwest) return southeast;
    if (way == southeast) return northwest;
    if (way == up) return down;
    if (way == down) return up;
    if (way == inward) return outward;
    if (way == outward) return inward;
    return nil;
}

/* Where this exit ends up, following a connector if there is one. */
destinationOf(from, way)
{
    local target = exits.get(from, way);
    if (target == nil || target.isHidden)
        return nil;
    if (!target.ofKind(TravelConnector))
        return target;
    if (target.ofKind(Door))
        return doorDestination(target, from);
    return target.destination;
}

wayFrom(from, to)
{
    if (from == nil || to == nil)
        return nil;
    foreach (local way in allDirections.ways)
    {
        if (destinationOf(from, way) == to)
            return way;
    }
    return nil;
}

/* ---------------------------------------------------------------- queries */

here()
{
    return contains.outermost(player);
}

litBy(room)
{
    foreach (local item in contains.all(room))
    {
        if (item.isLightSource && item.isLit)
            return true;
/*
         * Light gets out of anything that is not shut: an open box, a pocket,
         * and the player, who is not a container but is carrying the torch.
         * Containment is one table, so the walk does not care which it is.
         */
        if (item.isContainer && item.isOpenable && !item.isOpen)
            continue;
        if (litBy(item))
            return true;
    }
    return nil;
}

/* A room you can see in: lit itself, or by something in it or carried. */
isDark()
{
    local room = here();
    if (room.isLit)
        return nil;
    return !litBy(room);
}

/*
 * Visible means reachable without opening anything: every container between the
 * item and the room has to be open. One walk up the containment table.
 */
visible(item)
{
    local room = here();
    foreach (local step in contains.ancestors(item))
    {
        if (step == room || step == player)
            return true;

        if (step.isContainer && step.isOpenable && !step.isOpen
            && !step.isTransparent)
            return nil;
    }
    return nil;
}

inScope(item)
{
/*
     * The player is in scope, and used not to be — which meant `X ME` answered
     * *I don't see that* in every game ever written against vhyl, and looking
     * at yourself is among the first things a good many players do.
     *
     * Being in scope is not the same as being a likely candidate: the player
     * ranks itself down for everything but examining (below), so a word that
     * names both you and something else still means the something else.
     */
    if (item == player)
        return true;

    if (item.isHidden)
        return nil;
/* In the dark you can still reach what you are carrying, and nothing else. */
    if (isDark())
        return carried(item);
/*
     * A nested space may confine you. Sitting in a booth whose reachOut is nil,
     * you can touch what is in the booth and what you are carrying and nothing
     * else — which is what nested rooms are for.
     */
    local nest = nestedIn();
    if (nest != nil && !nest.reachOut && item != nest)
        return carried(item) || holds(contains.all(nest), item);
/* A door stands in both the rooms it joins, so it is in scope from either. */
    if (item.ofKind(TravelConnector))
        return connectorHere(item) || visible(item);
/* A MultiLoc is in scope in any room it is present in. */
    if (item.isMultiLoc)
        return presentIn.contains(item, here());

    if (item.isDistant)
        return nil;
    return visible(item);
}

carried(item)
{
    return location.get(item) == player;
}

/* ------------------------------------------------------------ description */

/*
 * Whether what is inside can be seen. Open, or not shuttable, or shut but
 * transparent — a glass jar with the lid on shows what is in it.
 */
seeInto(item)
{
    if (!item.isOpenable)
        return true;
    return item.isOpen || item.isTransparent;
}

listContents(room)
{
    foreach (local item in contains.all(room))
    {
/*
         * Fixtures belong to the room's own description, not to the list of
         * what is lying about in it. A desk is part of the study; a trolley is
         * something someone left there.
         */

        if (item.isHidden)
            continue;

        item.seen = true;
        player.setKnowsAbout(item);
        if (item == player || item.isDecoration || item.isFixed)
            continue;
        sayFor('room.thereis', item, nil);
        if (item.isContainer && item.isOpenable && !item.isOpen && !item.isTransparent)
            sayFor('room.andclosed', item, nil);
        else if (item.isContainer && item.contentsListed && seeInto(item))
        {
            local inside = [for held in contains.all(item) : held if !held.isHidden];
            if (inside.length() > 0)
            {
                noteSeen(inside);
                sayAbout('room.andholding', item, inside, nil);
            }
        }
        sayMsg('room.endofitem', nil);
    }

    foreach (local item in roomSpecials(room))
    {
        local state = item.isActor ? item.curState : nil;
        if (state != nil && state.hasSpecialDesc)
        {
"\n";
            state.specialDesc;
        }
        else if (item.hasSpecialDesc)
        {
"\n";
            item.specialDesc;
        }
        else if (item.isActor)
        {
"\n";
            sayFor('room.actorhere', item, nil);
        }
    }
    return nil;
}

roomSpecials(room)
{
    local found = [];
    foreach (local item in contains.all(room))
    {
        if (item.isHidden || item == player)
            continue;
        if (item.isActor || item.hasSpecialDesc)
            found = found + [item];
/*
         * A glass booth, an open crate, a chain hanging off a gatepost: what
         * is inside is plainly there. `seeInto` is the whole test — a thing
         * that does not shut never hides what it holds — and descending only
         * matters for something that asked for a line, so nothing is listed
         * that did not opt in.
         */
        if (!seeInto(item))
            continue;
        foreach (local inside in contains.all(item))
        {
            if (inside.isHidden || inside == player)
                continue;
            if (inside.isActor || inside.hasSpecialDesc)
                found = found + [inside];
        }
    }
    return found;
}

describeRoom()
{
    local room = here();

    sayFor('room.enter', room, nil);
    if (isDark())
    {
        sayMsg('room.dark', nil);
"\n\n";
        return nil;
    }

    sayFor('room.name', room, nil);
"\n";
    room.seen = true;
    player.setKnowsAbout(room);
    room.desc;
"\n";
    listContents(room);
    listSensed(room);
"\n";
    return nil;
}

/* --------------------------------------------------------------- messages */

class Message: object
    id = nil

    text = nil
    say(c) { return nil; }
/* Higher wins. A game's overrides sit above vhyl's, which are all 0. */
    priority = 0
/* Answered nil to stand aside: a message set that only applies sometimes. */
    isActive = true
;

msgArgs: Command;

/* Say an id about one or two objects, with no command in hand. */
sayFor(id, a, b)
{
    msgArgs.dobj = a;
    msgArgs.iobj = b;
    msgArgs.list_ = nil;
    msgArgs.way_ = nil;
    return sayMsg(id, msgArgs);
}

account(id, c)
{
    return accountAbout(id, c, nil);
}

accountAbout(id, c, word)
{
    return accountAs(2, id, c, word);
}

accountDefault(id, c)
{
    return accountAs(4, id, c, nil);
}

/* One account, at a given place in the report order. */
accountAs(where, id, c, word)
{
    local done = c.done_;
    if (done == nil || done.length() == 0)
        return nil;

    if (done.length() > 1 && messageFor(id +'.several') != nil)
        id = id +'.several';
    local r = addReport(c, where, id, done[1], c.iobj);
    if (r != nil)
    {
        r.list = done;
        r.word = word;
    }
    return nil;
}

noteDone(c, item)
{
    c.done_ = c.done_ == nil ? [item] : c.done_ + [item];
    return nil;
}

/*
 * The text of a message about one or two objects, **read** rather than said.
 *
 * `refuses` answers a sentence for the turn to print, so it needs the words
 * rather than the side effect. A message with no text — one whose body emits —
 * has nothing to read, and answers nil so the caller falls back to whatever it
 * would have said anyway.
 */
msgFor(id, a, b)
{
    local m = messageFor(id);
    if (m == nil || m.text == nil)
        return nil;
    msgArgs.dobj = a;
    msgArgs.iobj = b;
    msgArgs.list_ = nil;
    msgArgs.way_ = nil;
    return language.expand(m.text, msgArgs);
}

/* Say an id about an object and a list of things, or a word. */
sayAbout(id, a, list, word)
{
    msgArgs.dobj = a;
    msgArgs.iobj = nil;
    msgArgs.list_ = list;
    msgArgs.way_ = word;
    return sayMsg(id, msgArgs);
}

/* The message that answers to this id, or nil. */
messageFor(id)
{
    local best = nil;
    for (local m = firstObj(Message); m != nil; m = nextObj(m, Message))
    {
        if (m.id != id || !m.isActive)
            continue;
        if (best == nil || m.priority > best.priority)
            best = m;
    }
    return best;
}

/*
 * Say what this id means. `c` is the command, so a message that wants the
 * objects has them; one that does not ignores it.
 *
 * An unknown id prints the id itself rather than nothing, because a message
 * that silently says nothing is the hardest kind to find.
 */
sayMsg(id, c)
{

    event(id);
    if (c != nil)
    {

        local named = [];
        if (c.dobj != nil)
            named = named + [c.dobj];
        if (c.iobj != nil && !holds(named, c.iobj))
            named = named + [c.iobj];
        if (c.list_ != nil)
        {
            foreach (local item in c.list_)
            {
                if (!holds(named, item))
                    named = named + [item];
            }
        }
        foreach (local item in named)
            eventSubject(item);
    }
    local m = messageFor(id);
    if (m == nil)
    {
"[no message: <<id>>]\n";
        return nil;
    }
    if (m.text != nil)
"<<language.expand(m.text, c)>>";
    else
        m.say(c);
    return nil;
}

language: object
    expand(text, c) { return text; }
;

/*
 * The player is the last thing a command means when it could mean anything
 * else, and is not something to be picked up. `isFixed` is what refuses TAKE ME
 * with a sentence rather than with a silence.
 */
modify player
    isFixed = true
    rank(a, role) { return a == examineAction ? rankLogical : rankSelf; }
;

/* ------------------------------------------------------------ verb codes */

class Verb: object
/* What the host sends. Stable; a code is never reused for something else. */
    code = 0
/* The action it runs. */
    action = nil
/* A direction, for the travel verbs. */
    dir = nil
/* For the export. Not shown to a player: it is a key, not a word. */
    label = nil

    verbPhrase = nil

    preposition()
    {
        local phrase = verbPhrase;
        if (phrase == nil)
            return nil;
        local open = phrase.find('(');
        if (open == nil)
            return nil;
        local rest = phrase.substr(open + 1);
/* The **first** group only, and not past its closing bracket: an
         * `unlock/unlocking (what) (with what)` has a preposition in its
         * second group and none in its first, and reading past the bracket
         * printed *(first unlocking what) the locker)*. */
        local close = rest.find(')');
        if (close != nil)
            rest = rest.substr(1, close - 1);
        local space = rest.find(' ');
        if (space == nil)
            return nil;
        local word = rest.substr(1, space - 1);
        return word is in ('what','whom') ? nil : word;
    }
/* The gerund alone: 'taking' from 'take/taking (what)'. */
    gerund()
    {
        local phrase = verbPhrase;
        if (phrase == nil)
            return label == nil ?'' : label +'ing';
        local slash = phrase.find('/');
        if (slash == nil)
            return phrase;
        local rest = phrase.substr(slash + 1);
        local space = rest.find(' ');
        return space == nil ? rest : rest.substr(1, space - 1);
    }
;

/* The verb this code names, or nil. */
verbFor(code)
{
    for (local v = firstObj(Verb); v != nil; v = nextObj(v, Verb))
    {
        if (v.code == code)
            return v;
    }
    return nil;
}

/* Nothing to say (1-9). */
vLook:       Verb code = 1  action = lookAction      label ='look' verbPhrase ='look/looking around';
vInventory:  Verb code = 2  action = inventoryAction label ='inventory' verbPhrase ='take/taking inventory';
vUndo:       Verb code = 3  action = undoAction      label ='undo' verbPhrase ='undo/undoing';
vScore:      Verb code = 4  action = scoreAction     label ='score' verbPhrase ='check/checking (the score)';
vGetOff:     Verb code = 5  action = getOffAction    label ='get-off' verbPhrase ='get/getting off';
vWait:       Verb code = 6  action = waitAction      label ='wait' verbPhrase ='wait/waiting';
vStand:      Verb code = 7  action = standAction     label ='stand' verbPhrase ='stand/standing up';
vSit:        Verb code = 8  action = sitAction       label ='sit' verbPhrase ='sit/sitting down';
vLie:        Verb code = 9  action = lieAction       label ='lie' verbPhrase ='lie/lying down';
vStandOn:    Verb code = 43 action = standOnAction   label ='stand-on' verbPhrase ='stand/standing (on what)';
vSitOn:      Verb code = 44 action = sitOnAction     label ='sit-on' verbPhrase ='sit/sitting (on what)';
vLieOn:      Verb code = 45 action = lieOnAction     label ='lie-on' verbPhrase ='lie/lying (on what)';
vSay:        Verb code = 46 action = sayAction        label ='say' verbPhrase ='say/saying (what)';
vWriteOn:    Verb code = 47 action = writeOnAction    label ='write-on' verbPhrase ='write/writing (what) (on what)';
vThinkAbout: Verb code = 48 action = thinkAboutAction label ='think-about' verbPhrase ='think/thinking (about what)';
vConsult:    Verb code = 49 action = consultAction    label ='consult' verbPhrase ='look/looking up (what) (in what)';
vGive:       Verb code = 58 action = giveAction      label ='give-to' verbPhrase ='give/giving (what) (to whom)';
vShow:       Verb code = 59 action = showAction      label ='show-to' verbPhrase ='show/showing (what) (to whom)';
vUnlock:     Verb code = 41 action = unlockAction    label ='unlock' verbPhrase ='unlock/unlocking (what) (with what)';
vLock:       Verb code = 42 action = lockAction      label ='lock' verbPhrase ='lock/locking (what) (with what)';

vNorth:      Verb code = 10 action = goAction dir = north     label ='go-north' verbPhrase ='go/going north';
vSouth:      Verb code = 11 action = goAction dir = south     label ='go-south' verbPhrase ='go/going south';
vEast:       Verb code = 12 action = goAction dir = east      label ='go-east' verbPhrase ='go/going east';
vWest:       Verb code = 13 action = goAction dir = west      label ='go-west' verbPhrase ='go/going west';
vUp:         Verb code = 14 action = goAction dir = up        label ='go-up' verbPhrase ='go/going up';
vDown:       Verb code = 15 action = goAction dir = down      label ='go-down' verbPhrase ='go/going down';
vIn:         Verb code = 16 action = goAction dir = inward    label ='go-in' verbPhrase ='go/going in';
vOut:        Verb code = 17 action = goAction dir = outward   label ='go-out' verbPhrase ='go/going out';

/* One subject (20-49). */
vExamine:    Verb code = 20 action = examineAction    label ='examine' verbPhrase ='examine/examining (what)';
vTake:       Verb code = 21 action = takeAction       label ='take' verbPhrase ='take/taking (what)';
vDrop:       Verb code = 22 action = dropAction       label ='drop' verbPhrase ='drop/dropping (what)';
vOpen:       Verb code = 23 action = openAction       label ='open' verbPhrase ='open/opening (what)';
vClose:      Verb code = 24 action = closeAction      label ='close' verbPhrase ='close/closing (what)';
vTurn:       Verb code = 25 action = turnAction       label ='turn' verbPhrase ='turn/turning (what)';
vTurnOn:     Verb code = 26 action = turnOnAction     label ='turn-on' verbPhrase ='turn on (what)';
vTurnOff:    Verb code = 27 action = turnOffAction    label ='turn-off' verbPhrase ='turn off (what)';
vFlip:       Verb code = 28 action = flipAction       label ='flip' verbPhrase ='flip/flipping (what)';
vPress:      Verb code = 29 action = pressAction      label ='press' verbPhrase ='press/pressing (what)';
vBoard:      Verb code = 30 action = boardAction      label ='board' verbPhrase ='board/boarding (what)';
vEnter:      Verb code = 31 action = enterAction      label ='enter' verbPhrase ='enter/entering (what)';
vWear:       Verb code = 32 action = wearAction       label ='wear' verbPhrase ='wear/wearing (what)';
vDoff:       Verb code = 33 action = doffAction       label ='doff' verbPhrase ='take off (what)';
vLookUnder:  Verb code = 34 action = lookUnderAction  label ='look-under' verbPhrase ='look/looking (under what)';
vLookBehind: Verb code = 35 action = lookBehindAction label ='look-behind' verbPhrase ='look/looking (behind what)';
vListen:     Verb code = 36 action = listenAction     label ='listen' verbPhrase ='listen/listening (to what)';
vSmell:      Verb code = 37 action = smellAction      label ='smell' verbPhrase ='smell/smelling (what)';

/* Two subjects (50-59). */
vPutOn:      Verb code = 50 action = putOnAction      label ='put-on' verbPhrase ='put/putting (what) (on what)';
vPutIn:      Verb code = 51 action = putInAction      label ='put-in' verbPhrase ='put/putting (what) (in what)';
vPutBehind:  Verb code = 52 action = putBehindAction  label ='put-behind' verbPhrase ='put/putting (what) (behind what)';
vAttach:     Verb code = 53 action = attachAction     label ='attach' verbPhrase ='attach/attaching (what) (to what)';
vDetach:     Verb code = 54 action = detachAction     label ='detach' verbPhrase ='detach/detaching (what) (from what)';
vAskAbout:   Verb code = 55 action = askAboutAction   label ='ask-about' verbPhrase ='ask/asking (whom) (about what)';
vTellAbout:  Verb code = 56 action = tellAboutAction  label ='tell-about' verbPhrase ='tell/telling (whom) (about what)';

/* A subject and a direction (60-69). */
vEat:        Verb code = 38 action = eatAction        label ='eat' verbPhrase ='eat/eating (what)';
vDrink:      Verb code = 39 action = drinkAction      label ='drink' verbPhrase ='drink/drinking (what)';
vDetachPart: Verb code = 40 action = detachPartAction label ='detach-part' verbPhrase ='detach/detaching (what)';
vPourInto:   Verb code = 57 action = pourIntoAction   label ='pour-into' verbPhrase ='pour/pouring (what) (into what)';

vPushNorth:  Verb code = 60 action = pushDirAction dir = north label ='push-north' verbPhrase ='push/pushing (what) north';
vPushSouth:  Verb code = 61 action = pushDirAction dir = south label ='push-south' verbPhrase ='push/pushing (what) south';
vPushEast:   Verb code = 62 action = pushDirAction dir = east  label ='push-east' verbPhrase ='push/pushing (what) east';
vPushWest:   Verb code = 63 action = pushDirAction dir = west  label ='push-west' verbPhrase ='push/pushing (what) west';

/* ---------------------------------------------------------------- actions */

class Action: object
/* Whether the turn resolves a direct and an indirect object first. */
    needsDobj = nil
    needsIobj = nil

    iobjIsTopic = nil

    dobjIsTopic = nil

    missingDobjMsg ='parse.noref'
    missingIobjMsg ='parse.noref'
/*
     * What the action does. `c` is the command, carrying the resolved dobj and
     * iobj and whatever else the rule captured, so an action that wants a
     * direction or a word reads it there.
     */
    exec(c) { sayMsg('action.nothing', c);"\n"; return nil; }

    rank(item, role) { return rankLogical; }

    needsReach = true

    preCond(item, role) { return []; }

    report(c) { return nil; }
;

/* The command a rule produces, and what the turn resolves into it. */
class Command: object
    action = nil

    set_ = nil

    dobj_ = nil
    iobj_ = nil
/* What the turn resolved them to. */
    dobj = nil
    iobj = nil

    way_ = nil

    dir_ = nil
/* Things a message has to name several of. */
    list_ = nil

    done_ = nil
/* What the command still has to say, in the order it will say it. */
    reports_ = nil

    failed_ = nil

    implied_ = nil

    actorPhrase_ = nil
    inner_ = nil
/* A literal phrase the rule captured, as words rather than a name. */
    literal_ = nil

    topicText_ = nil
;

/* ------------------------------------------------------------- reporting */

class Report: object

    place = 2
    id = nil
    dobj = nil
    iobj = nil
    list = nil

    reveals = nil
    word = nil
    construct(where, what, a, b) { place = where; id = what; dobj = a; iobj = b; }
;

/* A displayed discovery is world knowledge, including for a host using only
 * semantic events. Do not infer this from arbitrary message subjects. */
noteSeen(items)
{
    foreach (local item in items)
    {
        item.seen = true;
        player.setKnowsAbout(item);
    }
    return nil;
}

/* Put a report on the command's list. */
addReport(c, where, id, a, b)
{
    if (c == nil || id == nil)
        return nil;
    local r = new Report(where, id, a, b);
    c.reports_ = c.reports_ == nil ? [r] : c.reports_ + [r];
    return r;
}

/* The main result of the action. There may be several. */
mainReport(c, id, a, b) { return addReport(c, 2, id, a, b); }

reportBefore(c, id, a, b) { return addReport(c, 1, id, a, b); }
/* Moved after every main report, however early it is added. */
reportAfter(c, id, a, b) { return addReport(c, 3, id, a, b); }
/*
 * A main report that also marks the command a failure, so a caller that ran it
 * as an implied action knows not to go on.
 */
reportFailure(c, id, a, b)
{
    if (c != nil)
        c.failed_ = true;
    return addReport(c, 2, id, a, b);
}

defaultReport(c, id, a, b) { return addReport(c, 4, id, a, b); }
/*
 * The same, for a description: *You see nothing unusual.* Dropped when
 * anything else is said, but **kept** for an implied command, because a
 * description is an answer rather than an acknowledgement.
 */
defaultDescReport(c, id, a, b) { return addReport(c, 5, id, a, b); }
/* An extra line that does not suppress a default. */
extraReport(c, id, a, b) { return addReport(c, 6, id, a, b); }

sayReports(c)
{
    local list = c.reports_;
    c.reports_ = nil;
    if (list == nil || list.length() == 0)
        return nil;
    local real = nil;
    foreach (local r in list)
    {
        if (r.place <= 3)
            real = true;
    }
    foreach (local where in [1, 2, 4, 5, 3, 6])
    {
        if (real && (where == 4 || where == 5))
            continue;
        if (c.implied_ && where == 4)
            continue;
        foreach (local r in list)
        {
            if (r.place != where)
                continue;
            msgArgs.dobj = r.dobj;
            msgArgs.iobj = r.iobj;
            msgArgs.list_ = r.list;
            msgArgs.way_ = r.word;
            if (r.reveals != nil)
                noteSeen(r.reveals);
            sayMsg(r.id, msgArgs);
"\n";
        }
    }
    return nil;
}

lookAction: Action
    exec(c) { return describeRoom(); }
;

inventoryAction: Action
    exec(c) { return doInventory(); }
;

undoAction: Action
    exec(c)
    {
        if (undo())
            sayMsg('undo.ok', c);
        else
            sayMsg('undo.none', c);
"\n";
        return nil;
    }
;

goAction: Action
    exec(c) { return doGo(c.dir_); }
;

getOffAction: Action
    exec(c) { return doGetOff(); }
;

/*
 * WAIT. Nothing happens except a turn passing, which is the point: a game with
 * daemons, fuses and actors needs a way to let them act. vhyl had no such verb
 * at all, so every program that wanted one declared it — which is the sort of
 * thing a library exists to stop.
 */
/* ------------------------------------------------------------- postures */

takePosture(c, item, want)
{
    local where = item == nil ? nestedIn() : item;
/*
     * STAND with nothing named, while already standing: say so. Without this
     * a player standing on the table who typed STAND climbed the table again.
     */
    if (item == nil && player.posture == want)
    {
        sayMsg('posture.already', c);
"\n";
        return nil;
    }
/* STAND with nothing named, and nothing to stand on: get up. */
    if (where == nil)
    {
        if (want == standing && player.posture == standing)
        {
            sayMsg('posture.already', c);
"\n";
            return nil;
        }
        if (want != standing)
        {
            sayMsg('posture.nowhere', c);
"\n";
            return nil;
        }
        player.posture = standing;
        noteDone(c, player);
        return nil;
    }
    if (!inScope(where))
    {
        sayFor('posture.cannot', where, nil);
"\n";
        return nil;
    }
    if (!where.isEnterable && !where.isVehicle)
    {
        sayFor('posture.cannot', where, nil);
"\n";
        return nil;
    }
    if (!holds(where.allowedPostures, want))
    {
        sayFor('posture.wontallow', where, nil);
"\n";
        return nil;
    }
/* Get on it first, if we are not on it already. */
    if (location.get(player) != where)
        contains.set(where, player);
    player.posture = want;
    noteDone(c, where);
    return nil;
}

standAction: Action
    exec(c) { return takePosture(c, c.dobj, standing); }
    report(c) { return accountDefault('posture.stand', c); }
;
sitAction: Action
    exec(c) { return takePosture(c, c.dobj, sitting); }
    report(c) { return accountDefault('posture.sit', c); }
;
lieAction: Action
    exec(c) { return takePosture(c, c.dobj, lying); }
    report(c) { return accountDefault('posture.lie', c); }
;
standOnAction: Action
    needsDobj = true
    exec(c) { return takePosture(c, c.dobj, standing); }
    report(c) { return accountDefault('posture.stand', c); }
;
sitOnAction: Action
    needsDobj = true
    exec(c) { return takePosture(c, c.dobj, sitting); }
    report(c) { return accountDefault('posture.sit', c); }
;
lieOnAction: Action
    needsDobj = true
    exec(c) { return takePosture(c, c.dobj, lying); }
    report(c) { return accountDefault('posture.lie', c); }
;

/* -------------------------------------------- verbs with words for objects */

sayAction: Action
    exec(c)
    {
        local said = getLiteral(c);
        if (said == nil)
        {
            sayMsg('say.nothing', c);
"\n";
            return nil;
        }
        sayAbout('say.ok', nil, nil, said);
"\n";
        return nil;
    }
;

writeOnAction: Action
    needsDobj = true
    preCond(item, role) { return role == dobjRole ? [touchObj] : []; }
    exec(c)
    {
        sayFor('writeon.cannot', c.dobj, nil);
"\n";
        return nil;
    }
;

/* THINK ABOUT X: a mere reference to something, which need not be present. */
thinkAboutAction: Action
    needsDobj = true
    dobjIsTopic = true
    needsReach = nil
    exec(c)
    {
        sayFor('think.about', c.dobj, nil);
"\n";
        return nil;
    }
;

/*
 * LOOK UP X IN Y and CONSULT Y ABOUT X. The thing is the direct object and the
 * topic the indirect one, so a Consultable answers for itself.
 */
consultAction: Action
    needsDobj = true
    needsIobj = true
    iobjIsTopic = true
    preCond(item, role) { return role == dobjRole ? [touchObj] : []; }
    exec(c)
    {
        local book = c.dobj;
        if (!book.isConsultable)
        {
            sayFor('consult.cannot', book, nil);
"\n";
            return nil;
        }
        local entry = book.consult(c.iobj, getTopicText(c));
        if (entry == nil)
        {
            sayAbout('consult.nothing', book, nil, getTopicText(c));
"\n";
            return nil;
        }
"<<entry>>\n";
        return nil;
    }
;

waitAction: Action
    exec(c) { sayMsg('wait.ok', c);"\n"; return nil; }
;

examineAction: Action
    needsDobj = true
/* Looking at something needs no more than seeing it. */
    needsReach = nil
    exec(c)
    {
        local item = c.dobj;
        item.seen = true;
        player.setKnowsAbout(item);
/* Reading an emitting property displays it; there is nothing to test. */
        item.desc;
"\n";
/*
         * What is inside, when you can see inside. A glass jar shows its
         * contents with the lid on; a closed tin does not; and a RearContainer
         * says nothing, because what is behind it is out of sight until
         * someone looks there.
         */
        if (item.isContainer && item.contentsListed && seeInto(item))
        {
            local inside = [for held in contains.all(item) : held if !held.isHidden];
            if (inside.length() == 0)
                {
                    sayFor('examine.empty', item, nil);
"\n";
                }
            else
            {
                noteSeen(inside);
                sayAbout(item.objPos == posOn ?'examine.onit' :'examine.init',
                         item, inside, nil);
"\n";
            }
        }
        return nil;
    }
;

takeAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj] : []; }
    needsDobj = true
/* What you are already holding is the one you did not mean, and what is
     * bolted down is not a candidate for taking at all. */
    rank(item, role)
    {
        if (item.isFixed)
            return rankNever;
        if (carried(item))
            return rankAlready;
        return rankLogical;
    }
    exec(c)
    {
        local item = c.dobj;
        if (item == player)
        {
            sayMsg('take.self', c);
"\n";
        }
        else if (carried(item))
        {
            sayMsg('take.already', c);
"\n";
        }
        else if (item.isFixed)
        {
/* A thing may say why in its own words; otherwise the library's. */
            if (item.cannotTakeMsg != nil)
"<<item.cannotTakeMsg>>\n";
            else
            {
                sayMsg('take.fixed', c);
"\n";
            }
        }
        else
        {
            contains.set(player, item);
            noteDone(c, item);
        }
        return nil;
    }
    report(c) { return accountDefault('take.ok', c); }
;

dropAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
/* The mirror of take: only what you are holding can be dropped. */
    rank(item, role) { return carried(item) ? rankLogical : rankNotNow; }
    exec(c)
    {
        if (!carried(c.dobj))
        {
            sayMsg('drop.notheld', c);
"\n";
        }
        else
        {
            contains.set(here(), c.dobj);
            noteDone(c, c.dobj);
        }
        return nil;
    }
    report(c) { return accountDefault('drop.ok', c); }
;

openAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj, objUnlocked] : []; }
    needsDobj = true
    rank(item, role)
    {
        if (!item.isOpenable)
            return rankNever;
        return item.isOpen ? rankAlready : rankLogical;
    }
    exec(c)
    {
        local item = c.dobj;
        if (!item.isOpenable)
        {
            if (item.cannotOpenMsg != nil)
"<<item.cannotOpenMsg>>\n";
            else
            {
                sayMsg('open.cannot', c);
"\n";
            }
        }
        else if (item.isLocked)
        {
            sayMsg('open.locked', c);
"\n";
        }
        else if (item.isOpen)
        {
            sayMsg('open.already', c);
"\n";
        }
        else
        {
            item.isOpen = true;
            noteDone(c, item);

            if (item.isContainer && item.contentsListed)
            {
                local inside = [for held in contains.all(item) : held if !held.isHidden];
                if (inside.length() > 0)
                {
                    local r = mainReport(c,'open.reveals', item, nil);
                    if (r != nil)
                    {
                        r.list = inside;
                        r.reveals = inside;
                    }
                }
            }
        }
        return nil;
    }
    report(c) { return accountDefault('open.ok', c); }
;

closeAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj] : []; }
    needsDobj = true
    rank(item, role)
    {
        if (!item.isOpenable)
            return rankNever;
        return item.isOpen ? rankLogical : rankAlready;
    }
    exec(c)
    {
        local item = c.dobj;
        if (!item.isOpenable)
        {
            sayMsg('close.cannot', c);
"\n";
        }
        else if (!item.isOpen)
        {
            sayMsg('close.already', c);
"\n";
        }
        else
        {
            item.isOpen = nil;
            noteDone(c, item);
        }
        return nil;
    }
    report(c) { return accountDefault('close.ok', c); }
;

/* TURN X, which the pencil sharpener needs. */
turnAction: Action
    needsDobj = true
    exec(c) { sayMsg('turn.nothing', c);"\n"; return nil; }
;

turnOnAction: Action
    needsDobj = true
    rank(item, role)
    {
        if (!item.isLightSource && !item.ofKind(Switch))
            return rankNever;
        return item.isLit || item.isOn ? rankAlready : rankLogical;
    }
    exec(c)
    {
        local item = c.dobj;
        if (!item.isLightSource)
        {
            sayMsg('turnon.cannot', c);
"\n";
        }
        else if (item.isLit)
        {
            sayMsg('turnon.already', c);
"\n";
        }
        else
        {
            item.isLit = true;
            noteDone(c, item);
        }
        return nil;
    }
/* Seeing the room again is part of the account, not a second command. */
    report(c)
    {
        account('turnon.ok', c);
        if (!isDark())
            describeRoom();
        return nil;
    }
;

turnOffAction: Action
    needsDobj = true
    rank(item, role)
    {
        if (!item.isLightSource && !item.ofKind(Switch))
            return rankNever;
        return item.isLit || item.isOn ? rankLogical : rankAlready;
    }
    exec(c)
    {
        local item = c.dobj;
        if (!item.isLightSource)
        {
            sayMsg('turnoff.cannot', c);
"\n";
        }
        else if (!item.isLit)
        {
            sayMsg('turnoff.already', c);
"\n";
        }
        else
        {
            item.isLit = nil;
            noteDone(c, item);
        }
        return nil;
    }
    report(c)
    {
        local done = c.done_;
        sayAbout('turnoff.ok', done[1], done, nil);
        if (isDark())
            sayMsg('light.out', c);
"\n";
        return nil;
    }
;

/* ASK X ABOUT Y and TELL X ABOUT Y. */
converse(actor, about, asking)
{
    if (!actor.isActor)
    {
        sayFor('talk.notactor', actor, nil);"\n";
        return nil;
    }

    if (actor.curState != nil && actor.curState.ofKind(HermitActorState))
    {
        actor.talkedThisTurn = true;
        if (actor.curState.hasNoResponse)
        {
            actor.curState.noResponse;
"\n";
        }
        else
        {
            sayFor('talk.hermit', actor, nil);
"\n";
        }
        return nil;
    }
    actor.talkedThisTurn = true;
    local t = topicFor(actor, about, asking);
    if (t == nil)
        {
            sayFor('talk.notopic', actor, nil);
"\n";
        }
    else
    {
        deliverTopic(t, actor, about);
    }
    return nil;
}

/* Execute the exact selected entry; both ASK/TELL and menu adapters use it. */
deliverTopic(t, actor, about)
{
    if (t.id != nil) sayFor(t.id, actor, about);
    else t.reply;
"\n";
    if (t.waits) hostAction(0);
    t.used = true;
    return nil;
}

askAboutAction: Action
    needsDobj = true
    needsIobj = true
    iobjIsTopic = true
    missingIobjMsg ='talk.vaguetopic'
    exec(c) { return converse(c.dobj, c.iobj, true); }
;

tellAboutAction: Action
    needsDobj = true
    needsIobj = true
    iobjIsTopic = true
    missingIobjMsg ='talk.vaguetopic'
    exec(c) { return converse(c.dobj, c.iobj, nil); }
;

eatAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
    rank(item, role) { return item.isEdible ? rankLogical : rankIllogical; }
    exec(c)
    {
        if (!c.dobj.isEdible)
        {
            sayFor('eat.cannot', c.dobj, nil);
"\n";
            return nil;
        }

        contains.unset(location.get(c.dobj), c.dobj);
        noteDone(c, c.dobj);
        return nil;
    }
    report(c) { return account('eat.ok', c); }
;

drinkAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj] : []; }
    needsDobj = true
    rank(item, role)
    {
        return item.isDrinkable || item.fluidName != nil ? rankLogical : rankIllogical;
    }
    exec(c)
    {
        if (!c.dobj.isDrinkable)
        {
            sayFor('drink.cannot', c.dobj, nil);
"\n";
            return nil;
        }
        noteDone(c, c.dobj);
        return nil;
    }
    report(c) { return account('drink.ok', c); }
;

pourIntoAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : [touchObj, objOpen]; }
    needsDobj = true
    needsIobj = true
    rank(item, role)
    {
        if (role == dobjRole)
            return item.fluidName != nil ? rankLogical : rankIllogical;
        return item.allowPourIntoMe ? rankLogical : rankUnlikely;
    }
    exec(c)
    {
        local from = c.dobj;
        if (from.fluidName == nil)
        {
            sayFor('pour.nothing', from, nil);
"\n";
            return nil;
        }
        if (!c.iobj.allowPourIntoMe)
        {
            sayFor('pour.wontake', c.iobj, nil);
"\n";
            return nil;
        }
/* The fluid moves by being named somewhere else. */
        c.iobj.fluidName = from.fluidName;
        from.fluidName = nil;
        c.way_ = c.iobj.fluidName;
        noteDone(c, from);
        return nil;
    }
/* The fluid's word and the thing it went into, so the account can name both. */
    report(c) { return accountAbout('pour.ok', c, c.way_); }
;

detachPartAction: Action
    needsDobj = true
    rank(item, role) { return item.ofKind(Component) ? rankLogical : rankIllogical; }
    exec(c)
    {
        local part = c.dobj;
        if (!part.ofKind(Component) || !part.isDetachable)
        {
            sayFor('detach.fixed', part, nil);
"\n";
            return nil;
        }
/*
         * Detached, it is an ordinary thing: it stops being fixed and stops
         * being part of its owner's description, and it goes where the owner is
         * rather than staying inside it.
         */
        local owner = location.get(part);
        part.isFixed = nil;
        part.isDecoration = nil;
        part.isDetachable = nil;
        contains.set(owner == nil ? here() : location.get(owner), part);
        noteDone(c, part);
        return nil;
    }
    report(c) { return account('detach.part', c); }
;

/*
 * GIVE X TO Y, and SHOW X TO Y.
 *
 * A library with actors and no way to hand one of them anything is a library
 * that has not met a game: the author game's whole ending is Becky giving Zoé
 * the tape. The default is a refusal, because what an actor does with a thing
 * is the game's business and not vhyl's — but the **action exists**, so a Doer
 * can catch it and a topic can answer it.
 */
giveAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
    needsIobj = true
    rank(item, role) { return role == iobjRole && !item.isActor ? rankIllogical : rankLogical; }
    exec(c)
    {
        if (!c.iobj.isActor)
        {
            sayFor('give.notactor', c.iobj, nil);"\n";
            return nil;
        }
        if (!carried(c.dobj))
        {
            sayFor('drop.notheld', c.dobj, nil);"\n";
            return nil;
        }
        sayFor('give.refused', c.iobj, c.dobj);"\n";
        return nil;
    }
;

showAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
    needsIobj = true
    rank(item, role) { return role == iobjRole && !item.isActor ? rankIllogical : rankLogical; }
    exec(c)
    {
        if (!c.iobj.isActor)
        {
            sayFor('give.notactor', c.iobj, nil);"\n";
            return nil;
        }
        sayFor('show.nothing', c.iobj, c.dobj);"\n";
        return nil;
    }
;

unlockAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj] : [objHeld]; }
    needsDobj = true
    rank(item, role) { return item.isLockable ? rankLogical : rankIllogical; }
    exec(c)
    {
        local it = c.dobj;
        if (!it.isLockable)
        {
            sayFor('lock.cannot', it, nil);"\n";
            return nil;
        }
        if (!it.isLocked)
        {
            sayFor('unlock.already', it, nil);"\n";
            return nil;
        }
        local key = c.iobj != nil ? c.iobj : it.keyItem;
        if (it.keyItem == nil || key != it.keyItem || !carried(key))
        {
            sayFor('unlock.wrongkey', it, c.iobj);"\n";
            return nil;
        }
        it.isLocked = nil;
        c.iobj = key;
        noteDone(c, it);
        return nil;
    }
    report(c) { return accountDefault('unlock.ok', c); }
;

lockAction: Action
    preCond(item, role) { return role == dobjRole ? [touchObj, objClosed] : [objHeld]; }
    needsDobj = true
    rank(item, role) { return item.isLockable ? rankLogical : rankIllogical; }
    exec(c)
    {
        local it = c.dobj;
        if (!it.isLockable)
        {
            sayFor('lock.cannot', it, nil);"\n";
            return nil;
        }
        if (it.isLocked)
        {
            sayFor('lock.already', it, nil);"\n";
            return nil;
        }
        local key = c.iobj != nil ? c.iobj : it.keyItem;
        if (it.keyItem == nil || key != it.keyItem || !carried(key))
        {
            sayFor('unlock.wrongkey', it, c.iobj);"\n";
            return nil;
        }
        it.isOpen = nil;
        it.isLocked = true;
        c.iobj = key;
        noteDone(c, it);
        return nil;
    }
    report(c) { return accountDefault('lock.ok', c); }
;

attachAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : [touchObj]; }
    needsDobj = true
    needsIobj = true
    exec(c)
    {
        local a = c.dobj;
        local b = c.iobj;
        if (!a.isAttachable || !b.isAttachable)
            {
                sayMsg('attach.cannot', c);
"\n";
            }
        else if (a == b)
            {
                sayMsg('put.initself', nil);
"\n";
            }
        else if (a.attachesTo != nil && a.attachesTo != b)
            {
                sayFor('attach.wrongpair', a, b);
"\n";
            }
        else if (attachedTo.contains(a, b))
            {
                sayMsg('attach.already', c);
"\n";
            }
        else
        {
            attachedTo.set(a, b);
            noteDone(c, a);
        }
        return nil;
    }
    report(c) { return accountDefault('attach.ok', c); }
;

detachAction: Action
    needsDobj = true
    needsIobj = true
    exec(c)
    {
        if (!attachedTo.contains(c.dobj, c.iobj))
            {
                sayMsg('detach.notjoined', c);
"\n";
            }
        else
        {
            attachedTo.unset(c.dobj, c.iobj);
            noteDone(c, c.dobj);
        }
        return nil;
    }
    report(c) { return accountDefault('detach.ok', c); }
;

scoreAction: Action
    exec(c)
    {
        sayAbout('score.is', nil, nil, score.value);
"\n";
        foreach (local why in score.awards)
"  <<why>>\n";
        return nil;
    }
;

senseAction: Action
    needsDobj = true
/* Nor does listening to it, or smelling it. */
    needsReach = nil
    which = nil
    exec(c)
    {
        local it = c.dobj;
        if (it.ofKind(Sensed) && it.sense == which)
            it.desc;
        else if (which =='hear')
            sayMsg('listen.nothing', c);
        else
            sayMsg('smell.nothing', c);
"\n";
        return nil;
    }
;

listenAction: senseAction which ='hear';
smellAction: senseAction which ='smell';

flipAction: Action
    needsDobj = true
    exec(c)
    {
        local g = c.dobj;
        if (g.ofKind(Switch))
        {
            g.isOn = !g.isOn;
            c.way_ = g.isOn ?'flip.on' :'flip.off';
            noteDone(c, g);
        }
        else if (g.ofKind(Lever))
        {
            g.isUp = !g.isUp;
            c.way_ = g.isUp ?'pull.up' :'pull.down';
            noteDone(c, g);
        }
        else
            {
                sayFor('flip.cannot', g, nil);
"\n";
            }
        return nil;
    }
    report(c)
    {
        account(c.way_, c);
        c.dobj.activate();
        return nil;
    }
;

pressAction: Action
    needsDobj = true
    exec(c)
    {
        if (!c.dobj.ofKind(Button))
            {
                sayMsg('press.nothing', c);
"\n";
            }
        else
            noteDone(c, c.dobj);
        return nil;
    }
/*
     * The click, then whatever it set off. `activate` belongs here rather than
     * in `exec` because that is the order a player experiences it, and because
     * the account has to come first whatever the button does.
     */
    report(c)
    {
        account('press.ok', c);
        c.dobj.activate();
        return nil;
    }
;

/* SET DIAL TO <word>. The word is a token, not an entity, so the rule binds it
 * as a part of speech and the action reads the text. */
setToAction: Action
    needsDobj = true
    exec(c)
    {
        local d = c.dobj;
/* The rule may have named the setting outright or captured whatever the
         * player typed. A captured token binds the word itself. */
        if (c.way_ == nil && c.set_ != nil)
            c.way_ = c.set_;
        if (!d.ofKind(Dial))
            {
                sayFor('set.cannot', d, nil);
"\n";
            }
        else if (!holds(d.validSettings, c.way_))
            {
                sayFor('set.badvalue', d, nil);
"\n";
            }
        else
        {
            d.setting = c.way_;
            noteDone(c, d);
        }
        return nil;
    }
/*
     * The setting, then what setting it did. `way_` is the value here rather
     * than a message id, so this does not go through `account`.
     */
    report(c)
    {
        sayAbout('set.ok', c.dobj, nil, c.way_);
"\n";
        c.dobj.activate();
        return nil;
    }
;

boardAction: Action
    needsDobj = true
    exec(c) { return doBoard(c, c.dobj); }
/*
     * A vehicle may describe boarding it in its own words. Read, not tested: an
     * emitting property prints when it is read, so `hasBoardDesc` is the flag.
     */
    report(c)
    {
        local item = c.done_[1];
        if (item.hasBoardDesc)
        {
            item.boardDesc;
"\n";
            return nil;
        }
        return account('board.ok', c);
    }
;

enterAction: Action
    needsDobj = true
    exec(c) { return doEnter(c, c.dobj); }
/*
     * ENTER reaches BOARD when the thing is a vehicle, so it needs the same
     * account. Everything else about entering says its words as it happens: a
     * booth's `enterDesc` is the game's own prose and there is nothing to
     * summarise.
     */
    report(c) { return boardAction.report(c); }
;

wearAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
    rank(item, role)
    {
        if (!item.isWearable)
            return rankNever;
        return item.isWorn ? rankAlready : rankLogical;
    }
    exec(c)
    {
        local item = c.dobj;
        if (!item.isWearable)
        {
            sayMsg('wear.cannot', c);
"\n";
        }
        else if (item.isWorn)
        {
            sayMsg('wear.already', c);
"\n";
        }
        else
        {
            contains.set(player, item);
            item.isWorn = true;
            noteDone(c, item);
        }
        return nil;
    }
    report(c) { return accountDefault('wear.ok', c); }
;

doffAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : []; }
    needsDobj = true
    rank(item, role) { return item.isWorn ? rankLogical : rankNotNow; }
    exec(c)
    {
        if (!c.dobj.isWorn)
        {
            sayMsg('doff.notworn', c);
"\n";
        }
        else
        {
            c.dobj.isWorn = nil;
            noteDone(c, c.dobj);
        }
        return nil;
    }
    report(c) { return accountDefault('doff.ok', c); }
;

pushDirAction: Action
    needsDobj = true
    exec(c) { return doPush(c.dobj, c.dir_); }
;

putOnAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : [touchObj]; }
    needsDobj = true
    needsIobj = true
    exec(c) { return doPutOn(c, c.dobj, c.iobj); }

    report(c) { return accountDefault(c.way_, c); }
;

putInAction: Action
    preCond(item, role) { return role == dobjRole ? [objHeld] : [touchObj, objOpen]; }
    needsDobj = true
    needsIobj = true
    exec(c) { return doPutIn(c, c.dobj, c.iobj); }
    report(c) { return accountDefault(c.way_, c); }
;

putBehindAction: Action
    needsDobj = true
    needsIobj = true
    exec(c)
    {
        local behind = c.iobj;
        if (behind.remapBehind == nil)
        {
            sayFor('putbehind.cannot', behind, nil);"\n";
            return nil;
        }
        contains.set(behind.remapBehind, c.dobj);
        noteDone(c, c.dobj);
        return nil;
    }
    report(c) { return accountDefault('putbehind.ok', c); }
;

/*
 * LOOK BEHIND and LOOK UNDER. What is behind a thing is out of sight, so this
 * is how you find it — the leaflet behind the box and the note under the book.
 */
lookUnderAction: Action
    needsDobj = true
    exec(c)
    {
        local it = c.dobj;
        local space = it.remapUnder;
        if (space == nil)
        {
            sayFor('lookunder.nothing', it, nil);"\n";
            return nil;
        }
        local found = contains.all(space);
        if (found.length() == 0)
            {
                sayFor('lookunder.nothing', it, nil);
"\n";
            }
        else
        {
            noteSeen(found);
            sayAbout('lookunder.found', it, found, nil);
"\n";
            foreach (local held in contains.all(space))
                held.isHidden = nil;
        }
        return nil;
    }
;

lookBehindAction: Action
    needsDobj = true
    exec(c)
    {
        local it = c.dobj;
        local space = it.remapBehind != nil ? it.remapBehind : it;
        local found = contains.all(space);
        if (space == it && !it.isContainer)
            {
                sayFor('lookbehind.nothing', it, nil);
"\n";
            }
        else if (found.length() == 0)
            {
                sayFor('lookbehind.nothing', it, nil);
"\n";
            }
        else
        {
            noteSeen(found);
            sayAbout('lookbehind.found', it, found, nil);
"\n";
/* Found things stop being hidden. */
            foreach (local held in contains.all(space))
                held.isHidden = nil;
        }
        return nil;
    }
;

/* ------------------------------------------------------------- connectors */

class TravelConnector: Thing
    isFixed = true
/* Where it leads. A Door works out its own, from the side you are on. */
    destination = nil
/*
     * Said as you go through, if anything, and said as it is refused. These are
     * emitting properties: reading one prints it. So a game that supplies one
     * also sets the matching `has...` flag, because there is no way to ask
     * whether an emitting property is empty without printing it.
     */
    travelDesc = nil
    hasTravelDesc = nil

    canPass = true
    barrierDesc = nil
    hasBarrierDesc = nil

    onTravel = nil

    connectorStagingLocation = nil
/* And the posture they have to be in once they are there. */
    connectorStagingPosture = standing
;

/*
 * A way through that is not a door: an arch, a gap, a hole in a hedge. It is
 * `TravelConnector` with nothing added, which is the honest answer — a passage
 * differs from a door by not shutting, and a Door is the one that adds.
 */
class Passage: TravelConnector;

class PathPassage: Passage
    bulkLimit = 0
;
class StairwayUp: TravelConnector;
class StairwayDown: TravelConnector;

class Door: TravelConnector
    isOpenable = true
    isOpen = nil
;

class SecretDoor: Door
    isHidden = true
;

/*
 * Something you ride. Being in a vehicle is an ordinary containment row, so
 * travel carries whatever contains the player rather than the player alone —
 * no separate notion of a traveller is needed.
 */
class Vehicle: Thing
    isVehicle = true
/* You get **on** a bicycle, not in one. */
    objPos = posOn
    boardDesc = nil
    hasBoardDesc = nil
/*
     * Whether it may go to this room. A method rather than a field, because the
     * answer is about where you are heading: asking about where you are would
     * let a bicycle into the hall as long as it started outdoors.
     */
    canEnter(room) { return true; }
;

/* Too heavy to carry, but it can be shoved from room to room. */
class Heavy: Thing
    isFixed = true
    canPushTravel = nil
;

/*
 * Touchable, and not going anywhere. `Fixture` is scenery and belongs to the
 * room's description; an `Immovable` is a thing in its own right that simply
 * cannot be moved — a safe, an anvil, a fallen beam.
 */
class Immovable: Thing
    isFixed = true
    canPushTravel = nil
    refuses(action, c)
    {
        if (action == takeAction || action == pushDirAction)
            return msgFor('immovable.cannot', self, nil);
        return inherited(action, c);
    }
;

class Intangible: Thing
    isFixed = true
    isDecoration = true
    isIntangible = true
    refuses(action, c)
    {
        if (action == examineAction || action == listenAction
            || action == smellAction || action == thinkAboutAction)
            return nil;
        return msgFor('intangible.cannot', self, nil);
    }
;

class Unthing: Thing
    isFixed = true
    isDecoration = true
    refuses(action, c) { return msgFor('unthing.gone', self, nil); }
    rank(a, role) { return rankNever; }
;

/* Part of the furniture: mentioned in the room description, not listed. */
class Fixture: Thing
    isFixed = true
;

/* Scenery you can look at but need not be told about. */
class Decoration: Fixture
    isDecoration = true

    isImportant = nil
    refuses(action, c)
    {
        if (isImportant)
            return inherited(action, c);
        if (action == examineAction || action == listenAction
            || action == smellAction || action == thinkAboutAction
            || action == askAboutAction || action == tellAboutAction
            || action == consultAction)
            return inherited(action, c);
        return msgFor('decoration.notimportant', self, nil);
    }
;

class Component: Thing
    isFixed = true
/* Part of its owner's description, not a separate line in the room. */
    isDecoration = true
/* Whether it may be prised off. An AttachableComponent says yes. */
    isDetachable = nil
/*
     * Taking a part says **what it is part of**, rather than the room's stock
     * refusal, because *the handle is part of the lantern* is the answer a
     * player actually wanted. `refuses` answers text, so this reads the message
     * rather than saying it.
     */
    refuses(action, c)
    {
/* A detached part is an ordinary thing and refuses nothing. */
        if (action != takeAction || !isFixed)
            return nil;
        return msgFor('take.part', self, location.get(self));
    }
/* And it is the one you did not mean when something else could be taken. */
    rank(a, role) { return a == takeAction ? rankSelf : rankLogical; }
;

Component template'name';

class AttachableComponent: Component
    isDetachable = true
    isAttachable = true
;

AttachableComponent template'name';

class Distant: Decoration
    isDistant = true
;

Distant template'name';

/* Things rest on top of it rather than inside. */
class Surface: Fixture
    isContainer = true
    isOpenable = nil
/* What a thing is said to be, relative to this. */
    objPos = posOn
;

/* Holds things inside, and cannot be shut. */
class Container: Thing
    isContainer = true
    isOpenable = nil
    objPos = posIn
;

/* A container with a lid. */
class OpenableContainer: Container
    isOpenable = true
    isOpen = nil
;

/* One that can be locked shut, and needs the right key. */
class LockableContainer: OpenableContainer
    isLockable = true
    isLocked = true
;

/* Things go behind it rather than in it. */
class RearContainer: Thing
    isContainer = true
    isOpenable = nil
    objPos = posBehind
/* Behind is out of sight until you look there. */
    contentsListed = nil
;

class BagOfHolding: OpenableContainer
    isOpen = true
    bulkCapacity = 100
;

class SubComponent: Thing
    isFixed = true
    isContainer = true
/* Named as part of the thing it belongs to, not on its own. */
    isDecoration = true
;

SubComponent template'name';

class Platform: Surface
    isEnterable = true
    objPos = posOn
/* What you can reach from up here. nil means everything in the room. */
    reachOut = true
/* Said when you get on. An emitting string; a game overrides it. */
    enterDesc = nil
;

class Consultable: Thing
    isConsultable = true
    consult(about, words) { return nil; }
;

/* A space you sit inside rather than on: a booth, a cupboard, a cart. */
class Booth: Container
    isEnterable = true
    isFixed = true
    objPos = posIn
    reachOut = true
    enterDesc = nil
    allowedPostures = [sitting, standing]
    defaultPosture = sitting
;

class Chair: Platform
    allowedPostures = [sitting, standing]
    defaultPosture = sitting
;

class Bed: Platform
    allowedPostures = [lying, sitting, standing]
    defaultPosture = lying
;

/* ------------------------------------------------------- attachment, lists */

class Attachable: Thing
    isAttachable = true
/* What it will join to. nil means anything attachable. */
    attachesTo = nil
;

Attachable template'name';

class EventList: object
    items = []
    at = 0
/* 'cycle' starts again, 'stop' stays on the last, 'once' then silence. */
    kind ='cycle'
    next()
    {
        local count = items.length();
        if (count == 0)
            return nil;
        at = at + 1;
        if (at > count)
        {
            if (kind =='cycle')
                at = 1;
            else if (kind =='stop')
                at = count;
            else
                return nil;
        }
        return items[at];
    }
;

class Scene: object
    isHappening = nil
    hasHappened = nil
/* Answered true when it should start. */
    startsWhen = nil
/* Answered true when it should stop. */
    endsWhen = nil
    whenStarting() { return nil; }
    whenEnding() { return nil; }
;

score: object
    value = 0
    awards = []
;

/* Award points once for a named achievement. */
awardPoints(points, why)
{
    if (holds(score.awards, why))
        return nil;
    score.awards = score.awards + [why];
    score.value = score.value + points;
    sayAbout(points == 1 ?'score.gained1' :'score.gained', nil, nil, points);
"\n";
    return nil;
}

/* Run every turn: start and stop whatever scenes are due. */
runScenes()
{
    for (local sc = firstObj(Scene); sc != nil; sc = nextObj(sc, Scene))
    {
        if (!sc.isHappening && !sc.hasHappened && sc.startsWhen)
        {
            sc.isHappening = true;
            sc.whenStarting();
        }
        else if (sc.isHappening && sc.endsWhen)
        {
            sc.isHappening = nil;
            sc.hasHappened = true;
            sc.whenEnding();
        }
    }
    return nil;
}

/* --------------------------------------------------------------- sensory */

class Sensed: MultiLoc
/* Mentioned when the room is described, if it is worth mentioning. */
    isAmbient = true
    ambientDesc =""
;

class Noise: Sensed
    sense ='hear'
;

class Odour: Sensed
    sense ='smell'
;

Sensed template'name';
Noise template'name';
Odour template'name';

/* What can be sensed here, listed after the room. */
listSensed(room)
{
    for (local n = firstObj(Sensed); n != nil; n = nextObj(n, Sensed))
    {
        if (n.isAmbient && presentIn.contains(n, room))
        {
            n.ambientDesc;
" ";
        }
    }
    return nil;
}

/* ----------------------------------------------------------------- actors */

/* --------------------------------------------------------- actor travel */

travelActions: object
/* One command epoch; scalar stamps avoid retaining a fresh world list
     * every turn. Undo/rollback journal the epoch and actor stamps together. */
    cycle = 0
    backgroundActor = nil
/* The actor a `sayDeparting` is currently being asked about. */
    conn = nil
;

class Actor: Thing
    travelCycle = -1

    canAccompanyTravel(leader, conn, dest) { return true; }

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos,
                    &curState]
    isFixed = true
    isActor = true
/* The state it is in, which decides what it says and does. */
    curState = nil
/* Said instead of desc while in a state that has its own. */
    desc = nil
/* Whether this actor has spoken this turn, for a ConvAgendaItem. */
    talkedThisTurn = nil

    posture = standing

    setCurState(state)
    {
        if (state == curState)
            return nil;
        local old = curState;
        if (old != nil)
            old.deactivateState(self, state);
        curState = state;
        if (state != nil)
        {
            state.actor = self;
            state.activateState(self, old);
        }
        return nil;
    }

/* Background activity for an actor with no state of its own to run one. */
    idleTurn() { return nil; }

/* Whether this actor will do as it is told. The state decides. */
    obeyCommand(issuer, a)
    {
        return curState == nil ? nil : curState.obeyCommand(issuer, a);
    }

    moveIntoForTravel(room)
    {
        if (room != nil)
            relocateActor(self, room);
        return nil;
    }

    travelTo(dest, conn)
    {
        if (dest == nil || contains.outermost(self) == dest
            || !canStartJourney())
            return nil;
        local from = contains.outermost(self);
        local escort = accompanists(self, from, conn, dest);
        if (escort == nil)
            return nil;
        return travelParty(dest, conn, escort);
    }

/* A companion's own background agenda can still speak or do other work.
     * Its travel waits for its leader, independent of declaration order. */
    canStartJourney()
    {
        if (travelCycle == travelActions.cycle)
            return nil;
        if (travelActions.backgroundActor == self && curState != nil
            && (curState.accompanyingActor != nil || curState.escortActor != nil))
            return nil;
        return true;
    }

/* Internal: eligibility has been checked exactly once for this journey. */
    travelParty(dest, conn, escort)
    {

        travelCycle = travelActions.cycle;
        foreach (local a in escort)
            a.travelCycle = travelActions.cycle;
        foreach (local a in escort)
        {
            wearTravelState(a, conn);
            a.travelAlone(dest, conn);
        }
        travelAlone(dest, conn);
        finishAccompaniment(escort, true);
        return true;
    }

/* Internal: the party has already been gathered and admitted. */
    travelAlone(dest, conn)
    {
        local from = contains.outermost(self);
        local way = wayFrom(from, dest);
        foreach (local item in contains.all(from))
            item.beforeTravel(self, conn);
        if (curState != nil)
            curState.beforeTravel(self, conn);

        if (from == here() && from != dest)
            sayDeparting(way, conn);
        relocateActor(self, dest);
        if (conn != nil && conn.onTravel != nil)
            conn.onTravel;
        if (dest == here() && from != dest)
            sayArriving(way == nil ? nil : oppositeOf(way), conn);
        foreach (local item in contains.all(dest))
            item.afterTravel(self, conn);
        if (curState != nil)
            curState.afterTravel(self, conn);
        return nil;
    }

    scriptedTravelTo(dest)
    {
        if (dest == nil || !canStartJourney())
            return nil;
        local from = contains.outermost(self);
        local way = wayFrom(from, dest);
        if (way == nil)
            return nil;
        local conn = exits.get(from, way);
        if (conn != nil && conn.ofKind(TravelConnector) && !conn.canPass)
            return nil;
        local escort = accompanists(self, from, conn, dest);
        if (escort == nil)
            return nil;
        if (conn != nil && conn.ofKind(Door) && !conn.isOpen)
        {
            if (conn.isLocked)
                return nil;
            conn.isOpen = true;
/*
             * A door stands in both the rooms it joins, so the player sees it
             * open from either side — which is what `connectorHere` answers and
             * what plain visibility, which is about containment, does not.
             */
            if (connectorHere(conn) || visible(conn))
            {
                sayFor('travel.opens', self, conn);
"\n";
            }
        }
        if (conn != nil && conn.ofKind(TravelConnector) && !conn.canPass)
            return nil;
        return travelParty(dest, conn, escort);
    }

/* What the player sees when this actor leaves, and when one arrives. */
    sayDeparting(way, conn)
    {
/* A state may take the message over, which is how accompanying travel
         * says *the lead guard prods you on* instead of *the guard leaves*. */
        if (curState != nil && curState.saysDeparting)
            return curState.sayDeparting(self, way, conn);
        sayAbout(way == nil ?'travel.leaves' :'travel.leavesway',
                 self, nil, way);
"\n";
        return nil;
    }

    sayArriving(fromWay, conn)
    {
        sayAbout(fromWay == nil ?'travel.arrives' :'travel.arrivesway',
                 self, nil, fromWay);
"\n";
        return nil;
    }
;

class ActorState: object
    presentation = [&actor, &accompanyingActor, &escortActor, &escortDest]
    actor = nil
    accompanyingActor = nil
    escortActor = nil
    escortDest = nil
/* Mentioned when the actor is described. */
    stateDesc =""
/* Only these topics answer while in this state; nil means all of them. */
    only = nil

    isInitState = nil

    specialDesc = nil
/* Whether `specialDesc` says anything; an emitting property cannot be asked. */
    hasSpecialDesc = nil

    obeyCommand(issuer, a) { return nil; }
/* Reacting to what happens, with the state rather than with the actor. */
    beforeAction(c) { return nil; }
    afterAction(c) { return nil; }
    beforeTravel(traveller, conn) { return nil; }
    afterTravel(traveller, conn) { return nil; }
/* Called as this state becomes, and stops being, the actor's. */
    activateState(a, oldState) { return nil; }
    deactivateState(a, newState) { return nil; }

    takeTurn() { return nil; }
/* Whether this state takes the departure message over; see below. */
    saysDeparting = nil
    sayDeparting(a, way, conn) { return nil; }
/* Whether this state travels with somebody; see `AccompanyingState`. */
    accompanyTravel(leadActor, conn) { return nil; }
    getAccompanyingTravelState(leadActor, conn) { return nil; }
;

class HermitActorState: ActorState
    noResponse = nil

    hasNoResponse = nil
/* Nothing gets through, so no topic does either. */
    only = []
;

class AccompanyingState: ActorState
/* The stored leader is authoritative and inspectable. The hook may
     * decline a particular journey, but cannot choose a different leader. */
    accompanyingActor = player
    accompanyTravel(leadActor, conn) { return true; }
/* The state to wear for the journey itself. */
    getAccompanyingTravelState(leadActor, conn) { return nil; }
;

class AccompanyingInTravelState: ActorState
    saysDeparting = true
/* Where to go back to once the journey is over. */
    stateAfter = nil
    sayDeparting(a, way, conn)
    {
        sayFor('travel.comeswith', a, nil);
"\n";
        return nil;
    }
;

class GuidedTourState: AccompanyingState
    accompanyingActor = nil
    escortActor = player
/* The room this leg of the tour leads to. */
    escortDest = nil
/* The state for the next stop. */
    stateAfterEscort = nil
/* A tour leads rather than follows, so it does not wait to be taken. */
    accompanyTravel(leadActor, conn) { return nil; }
/* And it goes first, which is what the guide is for. */
    saysDeparting = true
    sayDeparting(a, way, conn)
    {
        sayFor('travel.leadsway', a, nil);
"\n";
        return nil;
    }
;

/*
 * One thing an actor will talk about. Matched by the entity the player named,
 * so ASK SAILOR ABOUT LIGHTHOUSE finds the entry whose matchObj is the
 * lighthouse — topics are entities, which the vocabulary already resolves.
 */

class Topic: Thing
    isFamiliar = true
    isDecoration = true
    isFixed = true
;

/* And a Distant says *too far off*, which the reach check answers first. */

class TopicEntry: object
    actor = nil
    matchObj = nil
/* Only offered while the actor is in this state; nil means always. */
    inState = nil
    isAsk = true

    id = nil
/* Or the words themselves, for a game that only ever runs in a terminal. */
    reply = nil

    waits = nil

    isActive = true
/* Said once, then this entry steps aside for the next. */
    once = nil
    used = nil
;

/* ----------------------------------------------------------------- states */

class State: object
/* Whose condition this is. */
    item = nil

    appliesTo = nil
/* And a further condition, for a class only some of whose instances have it. */
    applies(it) { return true; }
/* The property it watches, as an address: `&isSharpened`. */
    watches = nil
/* The adjective it answers to when that property is true, and when not.
     * Either may be nil, for a condition only one side of which has a word. */
    whenTrue = nil
    whenFalse = nil
/* What it last wrote, so a change takes the old word away again. */
    said = nil
/* The same, per thing, when the state covers a whole class. */
    saidFor = []
    saidItems = []
/* What this state last wrote for one thing. */
    wordFor(it)
    {
        local at = saidItems.indexOf(it);
        return at == nil ? nil : saidFor[at];
    }
    noteWord(it, word)
    {
        local at = saidItems.indexOf(it);
        if (at == nil)
        {
            saidItems = saidItems + [it];
            saidFor = saidFor + [word];
            return nil;
        }
        local rebuilt = [];
        for (local i = 1; i <= saidFor.length(); ++i)
            rebuilt = rebuilt + [i == at ? word : saidFor[i]];
        saidFor = rebuilt;
        return nil;
    }
/* The adjective this state gives that thing as it stands, or nil. */
    wordNow(it)
    {
        if (watches == nil)
            return nil;
        return it.(watches) ? whenTrue : whenFalse;
    }
;

/*
 * Bring every state's vocabulary into line with the world.
 *
 * Idempotent: a state whose word has not changed writes nothing, so this costs
 * one property read per state on a turn where nothing happened.
 */
syncStates()
{
    for (local s = firstObj(State); s != nil; s = nextObj(s, State))
    {
        if (s.watches == nil)
            continue;
/* One thing's own condition. */
        if (s.item != nil)
        {
            local wanted = s.wordNow(s.item);
            if (wanted == s.said)
                continue;
            if (s.said != nil)
                vocab.unset(s.item, s.said, &adjective);
            if (wanted != nil)
                vocab.set(s.item, wanted, &adjective);
            s.said = wanted;
            continue;
        }
/* Or every instance of a class that the state applies to. */
        if (s.appliesTo == nil)
            continue;
        for (local it = firstObj(s.appliesTo); it != nil;
             it = nextObj(it, s.appliesTo))
        {
            if (!s.applies(it))
                continue;
            local wanted = s.wordNow(it);
            local was = s.wordFor(it);
            if (wanted == was)
                continue;
            if (was != nil)
                vocab.unset(it, was, &adjective);
            if (wanted != nil)
                vocab.set(it, wanted, &adjective);
            s.noteWord(it, wanted);
        }
    }
    return nil;
}

class AgendaItem: Daemon
/* Only runs while the actor is in this state. */
    inState = nil
    actor = nil

    isReady = true
    isDone = nil

    invokeItem() { return nil; }

    offstage = nil
    isDue
    {
        if (isDone)
            return nil;
        if (!isReady)
            return nil;
        if (inState != nil && (actor == nil || actor.curState != inState))
            return nil;
        if (!offstage && (actor == nil || !visible(actor)))
            return nil;
        return true;
    }
;

class ConvAgendaItem: AgendaItem
    isReady = (actor != nil && !actor.talkedThisTurn)
;

addToAgenda(a, item)
{
    if (item == nil)
        return nil;
    item.actor = a;
    item.isActive = true;
    item.isDone = nil;
    return nil;
}

removeFromAgenda(a, item)
{
    if (item != nil)
        item.isActive = nil;
    return nil;
}

topicAvailableTo(t, asker)
{
    return t.isActive && asker.knowsAbout(t.matchObj)
        && (t.inState == nil || t.actor.curState == t.inState)
        && !(t.once && t.used);
}

topicFor(actor, about, asking)
{
    for (local t = firstObj(TopicEntry); t != nil; t = nextObj(t, TopicEntry))
    {
        if (t.actor != actor || t.matchObj != about)
            continue;
        if (!topicAvailableTo(t, player))
            continue;
        if (t.isAsk != asking)
            continue;
        if (t.inState != nil && actor.curState != t.inState)
            continue;
        if (t.once && t.used)
            continue;
        return t;
    }
    return nil;
}

/* ---------------------------------------------------------------- gadgets */

class Gadget: Thing
    isFixed = true
/* What turning, pushing or flipping it does. */
    activate() { return nil; }
;

/* On or off. */
class Switch: Gadget

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos,
                    &isOn]
    isOn = nil
    desc = nil
;

/* Up or down. */
class Lever: Gadget

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos,
                    &isUp]
    isUp = true
    desc = nil
;

/* Set to one of several positions. */
class Dial: Gadget

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos,
                    &setting]
    setting = nil
    validSettings = []
    desc = nil
;

/* Pressed, and does whatever it does. */
class Button: Gadget
    desc = nil
;

Actor template'name';
Gadget template'name';
Switch template'name';
Lever template'name';
Dial template'name';
Button template'name';

class Food: Thing
    isEdible = true
;

Food template'name';

/* Worn rather than merely carried. */
class Wearable: Thing

    presentation = [&name, &isOpen, &isOpenable, &isContainer, &isLit,
                    &isLightSource, &isFixed, &isDecoration, &isTransparent,
                    &isHidden, &bulk, &bulkCapacity, &objPos,
                    &isWorn]
    isWearable = true
    isWorn = nil
;

/*
 * Something you go into, which takes you somewhere. The oak you climb and the
 * chute you slide down are both this.
 */
class Enterable: Fixture
    isEnterable = true
    destination = nil
/* An emitting string, like desc. */
    enterDesc = nil
;

/*
 * In several rooms at once. Its rows are in presentIn rather than contains,
 * because containment answers one container and this thing has no one room.
 */
class MultiLoc: Fixture
    isMultiLoc = true

    locationList = []
;

TravelConnector template'name';
Passage template'name';
PathPassage template'name';
StairwayUp template'name';
StairwayDown template'name';
Door template'name';
SecretDoor template'name';
Vehicle template'name';
Heavy template'name';
Fixture template'name';
Decoration template'name';
Surface template'name';
Container template'name';
OpenableContainer template'name';
LockableContainer template'name';
RearContainer template'name';
BagOfHolding template'name';
Platform template'name';
Booth template'name';
Wearable template'name';
Enterable template'name';
MultiLoc template'name';

class PreinitObject: object execBeforeMe = [];

/*
 * A MultiLoc names the rooms it stands in and vhyl writes the rows, for the
 * same reason a door does: where a thing is belongs to the declaration, and
 * turning that into table rows is the library's job.
 */
multiLocPreinit: PreinitObject
    execute()
    {
        for (local m = firstObj(MultiLoc); m != nil; m = nextObj(m, MultiLoc))
        {
            foreach (local room in m.locationList)
                presentIn.set(m, room);
        }
        return nil;
    }
;

/* The room on a door's far side, from the one you are standing in. */
doorDestination(door, from)
{
    foreach (local side in connects.all(door))
    {
        if (side != from)
            return side;
    }
    return nil;
}

/* A connector is in scope from either of the rooms it joins. */
connectorHere(item)
{
    if (!connects.contains(item, here()))
        return nil;
    return !item.isHidden;
}

/* ---------------------------------------------------------- action helpers */

doInventory()
{
    local held = [for item in contains.all(player) : item.name];
    if (held.length() == 0)
        {
            sayMsg('inventory.none', nil);
"\n";
        }
    else
    {
        sayMsg('inventory.some', nil);
        foreach (local item in contains.all(player))
            {
"\n  ";
                sayFor(item.isWorn ?'inventory.itemworn' :'inventory.item',
                       item, nil);
            }
"\n";
    }
    return nil;
}

doGo(way)
{

    if (way == outward && nestedIn() != nil)
        return doGetOff();
    local target = exits.get(here(), way);

    if (target != nil && target.isHidden)
        target = nil;
    if (target == nil)
    {
        sayMsg('go.nowhere', nil);
"\n";
        return nil;
    }
    local to = target;
    if (target.ofKind(TravelConnector))
    {

        local stage = target.connectorStagingLocation;
        if (stage != nil)
        {
            if (location.get(player) != stage)
            {
                if (!tryImplied(verbForPosture(target.connectorStagingPosture),
                                stage, nil, nil))
                {
                    sayFor('stage.notthere', stage, nil);
"\n";
                    return nil;
                }
            }
            else if (player.posture != target.connectorStagingPosture)
            {
                player.posture = target.connectorStagingPosture;
            }
        }

        if (target.isOutOfReach && !target.canObjReachSelf(player))
        {
            sayFor('reach.toohigh', target, nil);"\n";
            return nil;
        }
        if (target.ofKind(Door) && !target.isOpen)
        {

            if (!tryImplied(23, target, nil, nil))
            {
                sayFor('go.shut', target, nil);"\n";
                return nil;
            }
        }
        if (!target.canPass)
        {
            if (target.barrierDesc != nil)
"<<target.barrierDesc>>\n";
            else
                {
                    sayFor('go.barred', target, nil);
"\n";
                }
            return nil;
        }

        if (target.bulkLimit > 0 && carriedBulk() > target.bulkLimit)
        {
            sayFor('go.toobulky', target, nil);
"\n";
            return nil;
        }
        if (target.hasTravelDesc)
        {
            target.travelDesc;
"\n";
        }
        to = target.ofKind(Door) ? doorDestination(target, here()) : target.destination;
        if (to == nil)
        {
            sayFor('go.leadsnowhere', target, nil);"\n";
            return nil;
        }
    }

    local from = here();
    local riding = location.get(player);
    if (riding != nil && riding.isVehicle && !riding.canEnter(to))
    {
        sayFor('ride.wontgo', riding, nil);"\n";
        return nil;
    }
    if (to == from || player.travelCycle == travelActions.cycle)
        return nil;
    local escort = accompanists(player, from, target, to);
    if (escort == nil)
        return nil;
    player.travelCycle = travelActions.cycle;
    foreach (local a in escort)
        a.travelCycle = travelActions.cycle;
    foreach (local a in escort)
    {
        wearTravelState(a, target);
        a.sayDeparting(way, target);
        relocateActor(a, to);
    }

    foreach (local a in escort)
    {
        local worn = a.curState;
        if (worn != nil && worn.ofKind(GuidedTourState)
            && worn.stateAfterEscort != nil)
            a.setCurState(worn.stateAfterEscort);
    }
/*
     * Ride what you are in. The player's own container is a containment row
     * like any other, so a vehicle travels by moving the thing the player is
     * inside and leaving the player inside it.
     */
    if (riding != nil && riding.isVehicle)
        relocateActor(riding, to);
    else
        relocateActor(player, to);

    if (target.ofKind(TravelConnector) && target.onTravel != nil)
        target.onTravel;
    describeRoom();
    finishAccompaniment(escort, nil);
    return nil;
}

/*
 * The actors in this room travelling with this leader, breadth first.
 *
 * A state says whether it comes along, and a guided tour says so only for the
 * leg of the tour it is on — which is what stops a guide following the player
 * off the route.
 */
accompanists(leader, from, conn, dest)
{
    local going = [];
    local leaders = [leader];
    local candidates = contains.all(from);
    local at = 1;
    while (at <= leaders.length())
    {
        local lead = leaders[at];
        foreach (local a in candidates)
        {
            if (!a.isActor || a == leader || a.curState == nil
                || holds(leaders, a))
                continue;
            local state = a.curState;
            if (state.ofKind(GuidedTourState))
            {
                if (state.escortActor != lead
                    || (state.escortDest != conn && state.escortDest != dest))
                    continue;
            }
            else if (state.accompanyingActor != lead
                     || !state.accompanyTravel(lead, conn))
                continue;
            if (leaders.length() >= 64
                || a.travelCycle == travelActions.cycle
                || !a.canAccompanyTravel(lead, conn, dest))
                return nil;
            going = going + [a];
            leaders = leaders + [a];
        }
        at = at + 1;
    }
    return going;
}

/* A movement fact is independent of prose and visibility. Fiat relocation
 * uses this too, but deliberately gathers nobody and consumes no action. */
relocateActor(a, dest)
{
    local from = location.get(a);
    if (from == dest)
        return nil;
    contains.set(dest, a);
    event('actor.move');
    eventSubject(a);
    eventSubject(dest);
    if (from != nil)
        eventSubject(from);
    return true;
}

wearTravelState(a, conn)
{
    local state = a.curState;
    local lead = state.ofKind(GuidedTourState) ? state.escortActor : state.accompanyingActor;
    local worn = state.getAccompanyingTravelState(lead, conn);
    if (worn != nil)
    {
        worn.stateAfter = state;
        worn.accompanyingActor = state.accompanyingActor;
        worn.escortActor = state.escortActor;
        a.setCurState(worn);
    }
    return nil;
}

finishAccompaniment(escort, advanceTours)
{
    foreach (local a in escort)
    {
        local worn = a.curState;
        if (worn != nil && worn.ofKind(AccompanyingInTravelState))
        {
            local back = worn.stateAfter;
            if (back != nil && back.ofKind(GuidedTourState)
                && back.stateAfterEscort != nil)
                back = back.stateAfterEscort;
            a.setCurState(back);
        }
        else if (advanceTours && worn != nil && worn.ofKind(GuidedTourState)
                 && worn.stateAfterEscort != nil)
            a.setCurState(worn.stateAfterEscort);
    }
    return nil;
}

doBoard(c, item)
{
    if (!item.isVehicle)
        {
            sayFor('board.cannot', item, nil);
"\n";
        }
    else if (location.get(player) == item)
        {
            sayFor('board.already', item, nil);
"\n";
        }
    else
    {
        contains.set(item, player);
        noteDone(c, item);
    }
    return nil;
}

doGetOff()
{
    local on = location.get(player);
    if (on == nil || !(on.isVehicle || on.isEnterable))
        {
            sayFor('getoff.nothing', nil, nil);
"\n";
        }
    else
    {
/* Out to whatever held it, which may itself be a nested space. */
        local out = location.get(on);
        contains.set(out == nil ? here() : out, player);
        sayFor(on.objPos == posIn ?'getoff.outof' :'getoff.off', on, nil);"\n";
    }
    return nil;
}

/* The verb that puts somebody into a posture, for an implied command. */
verbForPosture(want)
{
    if (want == sitting)
        return 44;
    if (want == lying)
        return 45;
    return 43;
}

/* What the player is in or on, if anything short of the room. */
nestedIn()
{
    local where = location.get(player);
    if (where == nil || where.ofKind(Room))
        return nil;
    return where;
}

doEnter(c, item)
{
    if (item.isVehicle)
        return doBoard(c, item);
    if (!item.isEnterable)
    {
        sayFor('enter.cannot', item, nil);"\n";
        return nil;
    }

    if (item.isLockable && item.isLocked)
    {
        sayFor('enter.locked', item, nil);"\n";
        return nil;
    }
    if (item.isOpenable && !item.isOpen)
    {
        sayFor('enter.shut', item, nil);"\n";
        return nil;
    }
    if (item.destination != nil)
    {
        item.enterDesc;
        contains.set(item.destination, player);
        describeRoom();
        return nil;
    }
    contains.set(item, player);
/*
     * Just read it. An emitting property displays when read and answers nil, so
     * testing it for nil would print it and then print the default as well —
     * which is why the default lives on the class instead of here.
     */
    item.enterDesc;
"\n";
    return nil;
}

doPush(item, way)
{
    if (!item.canPushTravel)
        {
            sayFor('push.cannot', item, nil);
"\n";
        }
    else
    {
        local target = exits.get(here(), way);
        if (target == nil)
            {
                sayMsg('go.nowhere', nil);
"\n";
            }
        else if (target.ofKind(TravelConnector))
            {
                sayFor('push.throughconnector', item, target);
"\n";
            }
        else
        {
            contains.set(target, item);
            contains.set(target, player);
            sayFor('push.ok', item, nil);"\n";
            describeRoom();
        }
    }
    return nil;
}

doPutOn(c, item, onto)
{
/* PUT X ON COOKER means the hob, if the cooker says so. */
    local named = onto;
    if (onto.remapOn != nil)
        onto = onto.remapOn;
    if (!onto.isContainer)
        {
            sayFor('puton.cannot', onto, nil);
"\n";
        }
    else if (item.isFixed)
        {
            sayFor('put.wontmove', item, nil);
"\n";
        }
    else if (item == onto)
        {
            sayMsg('put.initself', nil);
"\n";
        }
    else if (!roomFor(onto, item))
        {
            sayFor('puton.noroom', onto, nil);
"\n";
        }
    else if (onto.notifyInsert(item) != nil)
"<<onto.notifyInsert(item)>>\n";
    else
    {
        contains.set(onto, item);
/* Where it came to rest decides which account is given, so the report
         * phase is told rather than left to work it out again. */
        c.way_ = onto.objPos == posOn ?'puton.ok' :'putin.ok';
        c.iobj = named;
        noteDone(c, item);
    }
    return nil;
}

/* How much the player has in their arms, for a passage with a limit. */
carriedBulk()
{
    local used = 0;
    foreach (local item in contains.all(player))
    {
        if (!item.isWorn)
            used = used + item.bulk;
    }
    return used;
}

/* How much is already inside something. */
bulkIn(container)
{
    local used = 0;
    foreach (local item in contains.all(container))
        used = used + item.bulk;
    return used;
}

/* Whether one more thing fits. A capacity of 0 means no limit is stated. */
roomFor(container, item)
{
/* A narrow neck refuses a big thing however empty it is. */
    if (container.maxSingleBulk != 0 && item.bulk > container.maxSingleBulk)
        return nil;
    if (container.bulkCapacity == 0)
        return true;
    return bulkIn(container) + item.bulk <= container.bulkCapacity;
}

doPutIn(c, item, into)
{
/*
     * PUT X IN COOKER means the oven, if the cooker says so. The message names
     * what the player named: "in the cooker", not "in the oven space of the
     * cooker", which is what leaks if the part answers for itself.
     */
    local named = into;
    if (into.remapIn != nil)
        into = into.remapIn;
    if (!into.isContainer)
        {
            sayFor('putin.cannot', into, nil);
"\n";
        }
    else if (into.isOpenable && !into.isOpen)
        {
            sayFor('putin.shut', into, nil);
"\n";
        }
    else if (item.isFixed)
        {
            sayFor('put.wontmove', item, nil);
"\n";
        }
    else if (item == into)
        {
            sayMsg('put.initself', nil);
"\n";
        }
    else if (!roomFor(into, item))
        {
            sayFor('putin.noroom', into, nil);
"\n";
        }
    else if (into.notifyInsert(item) != nil)
"<<into.notifyInsert(item)>>\n";
    else
    {
        contains.set(into, item);
        c.way_ = into.objPos == posOn ?'puton.ok'
            : into.objPos == posBehind ?'putbehind.ok' :'putin.ok';
        c.iobj = named;
        noteDone(c, item);
    }
    return nil;
}

/* ----------------------------------------------------------------- events */

class Event: object
/* Whose property is called when it fires, and which. */
    owner = nil
    prop = nil
/* Turns until it fires. */
    turnsLeft = 1
/* 0 fires once and stops; n fires every n turns. */
    interval = 0
    isActive = true
/* Answered nil to skip a firing without stopping the event. */
    isDue = true
;

/* Fires once. */
class Fuse: Event;

/* Fires again and again. */
class Daemon: Event
    interval = 1
;

class SenseEvent: Daemon
    where = nil
    isDue { return where == nil || where == here(); }
;

class InitObject: object
    execute() { return nil; }
;

/* The turn the game is on, counted from the first command. */
turnCount: object value = 0;

/* Set when the game is over, with what to say. */
gameOver: object done = nil;

/*
 * End the game. The turn that calls this finishes; nothing after it runs.
 */

finishGame(why)
{
    gameOver.done = true;
"\n";
    if (messageFor(why) != nil)
        sayMsg(why, nil);
    else
"<<why>>";
"\n";
    return nil;
}

/* Every event that is due, in declaration order. */

runActors()
{
    for (local a = firstObj(Actor); a != nil; a = nextObj(a, Actor))
    {
        if (a == player)
            continue;

        travelActions.backgroundActor = a;
        local acted = nil;
        for (local item = firstObj(AgendaItem); item != nil;
             item = nextObj(item, AgendaItem))
        {
            if (item.actor != a || !item.isActive)
                continue;

            if (item.isDone)
            {
                item.isActive = nil;
                continue;
            }
            if (!item.isDue)
                continue;
            item.turnsLeft = item.turnsLeft - 1;
            if (item.turnsLeft > 0)
                continue;
            if (item.interval > 0)
                item.turnsLeft = item.interval;
            else
                item.isActive = nil;
/* Due, and the actor has already spoken this turn: it has had its
             * countdown, and waits its turn rather than losing it. */
            if (acted)
            {
                item.turnsLeft = 1;
                item.isActive = true;
                continue;
            }
            if (item.owner != nil && item.prop != nil)
            {
                item.owner.(item.prop);
                acted = true;
            }
            else
            {
                item.invokeItem();
                acted = true;
            }
            if (gameOver.done)
            {
                travelActions.backgroundActor = nil;
                return nil;
            }
        }

        if (!acted)
        {
            if (a.curState != nil)
                a.curState.takeTurn();
            else
                a.idleTurn();
        }
        a.talkedThisTurn = nil;
        travelActions.backgroundActor = nil;
    }
    return nil;
}

runEvents()
{
    for (local e = firstObj(Event); e != nil; e = nextObj(e, Event))
    {
        if (!e.isActive)
            continue;

        if (e.ofKind(AgendaItem))
            continue;
        e.turnsLeft = e.turnsLeft - 1;
        if (e.turnsLeft > 0)
            continue;
        if (e.interval > 0)
            e.turnsLeft = e.interval;
        else
            e.isActive = nil;
/* A sense event fires only where it can be noticed. */
        if (e.isDue && e.owner != nil && e.prop != nil)
            e.owner.(e.prop);
        if (gameOver.done)
            return nil;
    }
    return nil;
}

/* ------------------------------------------------------------------ doers */

class Doer: object
/* The action this catches, and optionally the object it must be about. */
    forAction = nil
    forIobj = nil
    forDobj = nil
/* The action to run instead. Answer nil to leave the command alone. */
    instead = nil
/* Whether this Doer applies to the command in hand. */
    catches(c)
    {
        if (forAction != nil && c.action != forAction)
            return nil;
        if (forIobj != nil && c.iobj != forIobj)
            return nil;
        if (forDobj != nil && c.dobj != forDobj)
            return nil;
        return true;
    }
;

/* The Doer that catches this command, if any. */
findDoer(c)
{
    for (local d = firstObj(Doer); d != nil; d = nextObj(d, Doer))
    {
        if (d.catches(c))
            return d;
    }
    return nil;
}

/* ---------------------------------------------------------------- parsing */

grammar command(ordered):
    nounPhrase->actorPhrase_',' command->inner_ : Command
;

grammar command(look):'look' |'l' : Command action = lookAction;
grammar command(waitCmd):'wait' |'z' : Command action = waitAction;
grammar command(inventory):'inventory' |'i' : Command action = inventoryAction;
grammar command(undoCmd):'undo' : Command action = undoAction;
grammar command(getOff):'get''off' : Command action = getOffAction;
grammar command(standUp):'stand' |'stand''up' |'get''up' : Command action = standAction;
grammar command(sitDown):'sit' |'sit''down' : Command action = sitAction;
grammar command(lieDown):'lie' |'lie''down' : Command action = lieAction;
grammar command(standOn):
'stand' ('on' |'onto') nounPhrase->dobj_ : Command action = standOnAction;
grammar command(sitOn):
'sit' ('on' |'in' |'onto') nounPhrase->dobj_ : Command action = sitOnAction;
grammar command(lieOn):
'lie' ('on' |'in' |'onto') nounPhrase->dobj_ : Command action = lieOnAction;

grammar command(examine):'examine' nounPhrase->dobj_ : Command action = examineAction;
grammar command(x):'x' nounPhrase->dobj_ : Command action = examineAction;
/* LOOK AT X is what a good many players type, and vhyl had only X and
 * EXAMINE. Badness, because LOOK on its own is the room. */
grammar command(lookAt):    [badness 5]'look''at' nounPhrase->dobj_ : Command action = examineAction;

grammar command(take):      [badness 10]'take' nounPhrase->dobj_ : Command action = takeAction;
grammar command(get):'get' nounPhrase->dobj_ : Command action = takeAction;
grammar command(drop):'drop' nounPhrase->dobj_ : Command action = dropAction;
grammar command(openIt):'open' nounPhrase->dobj_ : Command action = openAction;
grammar command(closeIt):'close' nounPhrase->dobj_ : Command action = closeAction;
grammar command(turnOn):'turn''on' nounPhrase->dobj_ : Command action = turnOnAction;
grammar command(turnIt):'turn' nounPhrase->dobj_ : Command action = turnAction;
grammar command(lightIt):'light' nounPhrase->dobj_ : Command action = turnOnAction;
grammar command(turnOff):'turn''off' nounPhrase->dobj_ : Command action = turnOffAction;
grammar command(board):'board' nounPhrase->dobj_ : Command action = boardAction;
grammar command(rideIt):'ride' nounPhrase->dobj_ : Command action = boardAction;
grammar command(enterIt):'enter' nounPhrase->dobj_ : Command action = enterAction;
grammar command(climbIt):'climb' nounPhrase->dobj_ : Command action = enterAction;
grammar command(wearIt):'wear' nounPhrase->dobj_ : Command action = wearAction;
grammar command(removeIt):'remove' nounPhrase->dobj_ : Command action = doffAction;
grammar command(takeOff):'take''off' nounPhrase->dobj_ : Command action = doffAction;
grammar command(flipIt):'flip' nounPhrase->dobj_ : Command action = flipAction;
grammar command(pullIt):'pull' nounPhrase->dobj_ : Command action = flipAction;
grammar command(pressIt):'press' nounPhrase->dobj_ : Command action = pressAction;
grammar command(pushBtn):'push' nounPhrase->dobj_ : Command action = pressAction;

grammar command(eatIt):'eat' nounPhrase->dobj_ : Command action = eatAction;
grammar command(drinkIt):'drink' nounPhrase->dobj_ : Command action = drinkAction;
grammar command(pourInto):'pour' nounPhrase->dobj_'into' nounPhrase->iobj_ : Command action = pourIntoAction;
grammar command(pourIn):'pour' nounPhrase->dobj_'in' nounPhrase->iobj_ : Command action = pourIntoAction;
grammar command(detachPart):'detach' nounPhrase->dobj_ : Command action = detachPartAction;

grammar command(giveTo):'give' nounPhrase->dobj_'to' nounPhrase->iobj_ : Command action = giveAction;
grammar command(showTo):'show' nounPhrase->dobj_'to' nounPhrase->iobj_ : Command action = showAction;
grammar command(unlockWith):'unlock' nounPhrase->dobj_'with' nounPhrase->iobj_ : Command action = unlockAction;
grammar command(unlockIt):'unlock' nounPhrase->dobj_ : Command action = unlockAction;
grammar command(lockWith):'lock' nounPhrase->dobj_'with' nounPhrase->iobj_ : Command action = lockAction;
grammar command(lockIt):'lock' nounPhrase->dobj_ : Command action = lockAction;

grammar command(sayCmd):
'say' literalPhrase->literal_ : Command action = sayAction;
grammar command(writeOn):
'write' literalPhrase->literal_'on' nounPhrase->dobj_
    : Command action = writeOnAction;
grammar command(typeOn):
'type' literalPhrase->literal_'on' nounPhrase->dobj_
    : Command action = writeOnAction;
grammar command(thinkAbout):
    ('think''about' |'ponder') nounPhrase->dobj_
    : Command action = thinkAboutAction;
grammar command(lookUpIn):
'look''up' nounPhrase->iobj_'in' nounPhrase->dobj_
    : Command action = consultAction;
grammar command(consultCmd):
'consult' nounPhrase->dobj_'about' nounPhrase->iobj_
    : Command action = consultAction;

grammar command(setTo):'set' nounPhrase->dobj_'to' tokWord->set_ : Command action = setToAction;
grammar command(turnToo):'turn' nounPhrase->dobj_'to' tokWord->set_ : Command action = setToAction;
grammar command(attachTo):'attach' nounPhrase->dobj_'to' nounPhrase->iobj_ : Command action = attachAction;
grammar command(detachFrom):'detach' nounPhrase->dobj_'from' nounPhrase->iobj_ : Command action = detachAction;
grammar command(scoreCmd):'score' : Command action = scoreAction;
grammar command(listenTo):'listen''to' nounPhrase->dobj_ : Command action = listenAction;
grammar command(smellIt):'smell' nounPhrase->dobj_ : Command action = smellAction;
grammar command(askAbout):'ask' nounPhrase->dobj_'about' nounPhrase->iobj_ : Command action = askAboutAction;
grammar command(tellAbout):'tell' nounPhrase->dobj_'about' nounPhrase->iobj_ : Command action = tellAboutAction;
grammar command(putOn):'put' nounPhrase->dobj_'on' nounPhrase->iobj_ : Command action = putOnAction;
grammar command(putIn):'put' nounPhrase->dobj_'in' nounPhrase->iobj_ : Command action = putInAction;
grammar command(putBehind):'put' nounPhrase->dobj_'behind' nounPhrase->iobj_ : Command action = putBehindAction;
grammar command(lookBehind):'look''behind' nounPhrase->dobj_ : Command action = lookBehindAction;
grammar command(lookUnder):'look''under' nounPhrase->dobj_ : Command action = lookUnderAction;

grammar command(gNorth): ('go'|) ('north' |'n') : Command action = goAction dir_ = north;
grammar command(gSouth): ('go'|) ('south' |'s') : Command action = goAction dir_ = south;
grammar command(gEast):  ('go'|) ('east'  |'e') : Command action = goAction dir_ = east;
grammar command(gWest):  ('go'|) ('west'  |'w') : Command action = goAction dir_ = west;
grammar command(gNE):    ('go'|) ('northeast' |'ne') : Command action = goAction dir_ = northeast;
grammar command(gNW):    ('go'|) ('northwest' |'nw') : Command action = goAction dir_ = northwest;
grammar command(gSE):    ('go'|) ('southeast' |'se') : Command action = goAction dir_ = southeast;
grammar command(gSW):    ('go'|) ('southwest' |'sw') : Command action = goAction dir_ = southwest;
grammar command(gUp):    ('go'|) ('up'    |'u') : Command action = goAction dir_ = up;
grammar command(gDown):  ('go'|) ('down'  |'d') : Command action = goAction dir_ = down;
grammar command(gIn):    ('go'|) ('in' |'inside') : Command action = goAction dir_ = inward;
grammar command(gOut):   ('go'|) ('out' |'outside') : Command action = goAction dir_ = outward;

grammar command(pushN):'push' nounPhrase->dobj_'north' : Command action = pushDirAction dir_ = north;
grammar command(pushS):'push' nounPhrase->dobj_'south' : Command action = pushDirAction dir_ = south;
grammar command(pushE):'push' nounPhrase->dobj_'east'  : Command action = pushDirAction dir_ = east;
grammar command(pushW):'push' nounPhrase->dobj_'west'  : Command action = pushDirAction dir_ = west;

class NounPhrase: object
    n_ = nil
    a1_ = nil
    a2_ = nil

    adjs_ = nil
    of_ = nil
    left_ = nil
    trailing_ = nil
    also_ = nil
/*
     * What an article is in front of. A field of its own rather than `left_`,
     * because *the lead and the chart* is an article in front of a **list**,
     * and a wrapper that shared a field with the list's left half hid it.
     */
    under_ = nil

    pronoun_ = nil
;

grammar nounPhrase(itOne):
    [badness 5]'it' : NounPhrase pronoun_ ='it';
grammar nounPhrase(themOne):
    [badness 5]'them' : NounPhrase pronoun_ ='them';

grammar nounPhrase(himOne):
    [badness 5]'him' : NounPhrase pronoun_ ='him';
grammar nounPhrase(herOne):
    [badness 5]'her' : NounPhrase pronoun_ ='her';
grammar nounPhrase(allOf):
    [badness 5]'all' : NounPhrase pronoun_ ='all';
grammar nounPhrase(everything):
    [badness 5]'everything' : NounPhrase pronoun_ ='all';

/*
 * An article, which a player types without thinking about it and every parser
 * in the genre accepts. vhyl refused `TAKE THE TOKEN` and `ASK ZOÉ ABOUT THE
 * TAPE` until an author game tried to write a walkthrough in English.
 *
 * A production of its own rather than a word in each rule, so the three noun
 * phrase shapes stay three. Spelled `anArticle` because `article` is already
 * the language module's a/an chooser, and a production shares a namespace with
 * a function.
 */

class AdjWord: object w_ = nil;

grammar adjWord(fromVocab): vocab.adjective->w_ : AdjWord;

/* A run of them, so a phrase may carry as many as it likes. */
class AdjRun: object one_ = nil rest_ = nil;

grammar adjRun(last):  adjWord->one_ : AdjRun;
grammar adjRun(more):  adjWord->one_ adjRun->rest_ : AdjRun;

grammar anArticle(theOne):'the' : object;
grammar anArticle(aOne):'a' : object;
grammar anArticle(anOne):'an' : object;

grammar simpleNoun(bare):
    vocab.noun->n_ : NounPhrase;
grammar simpleNoun(adjs):
    adjRun->adjs_ vocab.noun->n_ : NounPhrase;

grammar simpleNoun(nounThen):
    vocab.noun->n_ adjWord->trailing_ : NounPhrase;
grammar simpleNoun(nounQuoted):
    vocab.noun->n_'"' adjWord->trailing_'"' : NounPhrase;
grammar simpleNoun(quotedNoun):
'"' adjWord->trailing_'"' vocab.noun->n_ : NounPhrase;

/*
 * `of` joins two simple names: *piece of paper*, *small pile of dry straw*.
 * The thing named is the one both halves name, which is what a game states by
 * giving it both words.
 */
grammar simpleNoun(ofLink):
    simpleNoun->left_'of' simpleNoun->of_ : NounPhrase;

/* One thing, with or without an article. */
grammar nounPhrase(one):
    simpleNoun->under_ : NounPhrase;
grammar nounPhrase(artOne):
    anArticle simpleNoun->under_ : NounPhrase;

grammar nounPhrase(andMore):
    simpleNoun->left_ ('and' |',') nounPhrase->also_ : NounPhrase;
grammar nounPhrase(artAndMore):
    anArticle simpleNoun->left_ ('and' |',') nounPhrase->also_ : NounPhrase;

/* ----------------------------------------------------- literals and topics */

class LiteralPhrase: object
    word_ = nil
    rest_ = nil
;

grammar literalPhrase(oneWord): tokWord->word_ : LiteralPhrase;
grammar literalPhrase(moreWords): tokWord->word_ literalPhrase->rest_ : LiteralPhrase;
grammar literalPhrase(quoted):'"' literalPhrase->rest_'"' : LiteralPhrase;

/* The words of a literal phrase, joined back into a line. */
literalText(phrase)
{
    if (phrase == nil)
        return'';

    local head = phrase.word_ == nil || phrase.word_ =='"' ?'' : phrase.word_;
    local tail = literalText(phrase.rest_);
    if (head =='')
        return tail;
    return tail =='' ? head : head +' ' + tail;
}

getLiteral(c)
{
    if (c == nil)
        return nil;
    if (c.literal_ != nil)
        return literalText(c.literal_);
    return c.set_;
}

getTopic(c)
{
    return c == nil ? nil : c.iobj;
}

getTopicText(c)
{
    if (c == nil)
        return nil;
    if (c.topicText_ != nil)
        return literalText(c.topicText_);
    local about = c.iobj;
    return about == nil ? nil : about.name;
}

holds(list, wanted)
{
    if (list == nil)
        return nil;
    return list.indexOf(wanted) != nil;
}

/* What is in both lists. */
bothOf(left, right)
{
    if (left == nil)
        return right;
    if (right == nil)
        return left;
    return [for item in left : item if holds(right, item)];
}

/* The entities a phrase names: every word in it has to name them. */
phraseCandidates(np)
{
    if (np == nil)
        return [];

    if (np.pronoun_ != nil)
    {
        if (np.pronoun_ =='all')
        {
/*
             * Everything to hand — what is in the room and what you are
             * carrying. Which of those a verb means is the verb's business:
             * TAKE ALL means the room's things and DROP ALL means yours, and
             * the ranking says so already, so ALL does not have to.
             */
            local about = [for item in contains.all(here())
                           : item if item != player && !item.isFixed && !item.isDecoration];
            foreach (local held in contains.all(player))
            {
                if (!held.isFixed && !held.isDecoration)
                    about = about + [held];
            }
            return about;
        }
        local named = lastNamed.items == nil ? [] : lastNamed.items;

        if (np.pronoun_ =='him' || np.pronoun_ =='her')
        {
            local wantHim = np.pronoun_ =='him';
            local fits = [for x in named : x if wantHim ? x.isHim : x.isHer];
            if (fits.length() > 0)
                return fits;
            local here_ = contains.all(here()) + contains.all(player);
            return [for x in here_ : x if (wantHim ? x.isHim : x.isHer)];
        }
        return named;
    }
/*
     * `piece of paper`: the things both halves name. A game says so by giving
     * the object both words, which is what its vocabulary is for.
     */
    if (np.of_ != nil)
        return bothOf(phraseCandidates(np.left_), phraseCandidates(np.of_));
/* A wrapper — an article, or the one-thing case — names what it wraps. */
    if (np.under_ != nil)
        return phraseCandidates(np.under_);

    if (np.also_ != nil)
    {
        local all = [];
        foreach (local part in listedPhrases(np))
        {
            foreach (local item in phraseCandidates(part))
            {
                if (!holds(all, item))
                    all = all + [item];
            }
        }
        return all;
    }
    local list = np.n_;
/* The old pair, kept because a game may still set them directly. */
    if (np.a1_ != nil)
        list = bothOf(list, np.a1_);
    if (np.a2_ != nil)
        list = bothOf(list, np.a2_);
/* However many adjectives the phrase carried, in the order written. */
    for (local run = np.adjs_; run != nil; run = run.rest_)
    {
        if (run.one_ != nil)
            list = bothOf(list, run.one_.w_);
    }
    if (np.trailing_ != nil)
        list = bothOf(list, np.trailing_.w_);
    return list == nil ? [] : list;
}

lastNamed: object items = nil;

listedPhrases(np)
{

    if (np == nil)
        return [];
/* An article in front of a list is still a list. */
    if (np.under_ != nil)
        return listedPhrases(np.under_);
    if (np.also_ == nil)
        return [np];
    return listedPhrases(np.left_) + listedPhrases(np.also_);
}

firstNamed(candidates)
{
    if (candidates == nil || candidates.length() == 0)
        return nil;
    foreach (local c in candidates)
    {
        if (player.knowsAbout(c))
            return c;
    }
    return candidates[1];
}

rankOf(item, a, role)
{
    local byAction = a.rank(item, role);
    local byThing = item.rank(a, role);
    return byAction < byThing ? byAction : byThing;
}

chooseOne(candidates, a, role)
{

    local reachable = [for c in candidates : c if inScope(c) || (c.isDistant && visible(c))];
    if (reachable.length() == 0)
        return nil;
    if (reachable.length() == 1)
        return reachable[1];
    local best = nil;
    foreach (local option in reachable)
    {
        local score = rankOf(option, a, role);
        if (best == nil || score > best)
            best = score;
    }
    local likely = [for c in reachable : c if rankOf(c, a, role) == best];
    if (likely.length() == 1)
        return likely[1];
    sayMsg('parse.which', nil);
    foreach (local option in likely)
        sayAbout('parse.whichone', option, nil, tellApart(option, likely));
"? ";
    local answer = inputLine();
    if (answer == nil)
        return nil;
    foreach (local option in likely)
    {
        local mark = tellApart(option, likely);
        if (option.name == answer
            || (mark != nil && (answer == mark
                                || answer == mark +' ' + option.name)))
            return option;
    }
    sayMsg('parse.notone', nil);"\n";
    return nil;
}

tellApart(item, others)
{
    for (local st = firstObj(State); st != nil; st = nextObj(st, State))
    {
        if (st.watches == nil)
            continue;
        if (st.item != nil && st.item != item)
            continue;
        if (st.item == nil
            && (st.appliesTo == nil || !item.ofKind(st.appliesTo)
                || !st.applies(item)))
            continue;
        local mine = st.wordNow(item);
        if (mine == nil)
            continue;
/* Only worth saying when another candidate it would be confused with
         * shares the name and differs in this condition. */
        foreach (local other in others)
        {
            if (other == item || other.name != item.name)
                continue;
            if (st.wordNow(other) != mine)
                return mine;
        }
    }
    return nil;
}

readingRank(m)
{
    local a = m.action;
    if (a == nil)
        return rankNever;
    if (!a.needsDobj)
        return rankLogical;
    local best = rankNever;
    foreach (local candidate in phraseCandidates(m.dobj_))
    {
        if (!inScope(candidate) && !candidate.isDistant)
            continue;
        local score = rankOf(candidate, a, dobjRole);
        if (score > best)
            best = score;
    }
    return best;
}

bestReading(matches)
{
    local best = matches[1];
    local bestSense = readingRank(best);
    local bestBad = best.badness;
    foreach (local m in matches)
    {
        local sense = readingRank(m);
        local bad = m.badness;
        if (sense > bestSense || (sense == bestSense && bad < bestBad))
        {
            best = m;
            bestSense = sense;
            bestBad = bad;
        }
    }
    return best;
}

endedCommand()
{
    sayMsg('game.ended', nil);
"\n";
    return nil;
}

vhylTurn(toks)
{
    if (!gameOver.done)
        travelActions.cycle = travelActions.cycle + 1;
    local m = command.parseTokens(toks, vhylDict);
    if (gameOver.done)
    {
/* Recognise history navigation without ranking, resolving, asking an
         * actor, or running any action hooks in an ended world. */
        foreach (local reading in m)
        {
            if (reading.action == undoAction && reading.actorPhrase_ == nil)
                return undoAction.exec(reading);
        }
        return endedCommand();
    }
    if (m.length() == 0)
    {
        sayMsg('parse.nomatch', nil);
"\n";
        return nil;
    }
    local c = bestReading(m);
/* Undo is history navigation, not another actor/event turn. */
    if (c.action == undoAction)
        return undoAction.exec(c);

    if (c.actorPhrase_ != nil)
    {
        local who = firstNamed(phraseCandidates(c.actorPhrase_));
        if (who == nil || !who.isActor || !inScope(who))
        {
            sayMsg('talk.notactor', nil);
"\n";
            return nil;
        }
        local inner = c.inner_;
        if (inner == nil || !who.obeyCommand(player, inner.action))
        {
            sayFor('order.refused', who, nil);
"\n";
            return nil;
        }
        c = inner;
        c.actorPhrase_ = nil;
    }
    local a = c.action;
    if (a == nil)
    {
        sayMsg('parse.nomatch', nil);
"\n";
        return nil;
    }
    if (a.needsDobj)
    {

        local listed = listedPhrases(c.dobj_);
        if (listed.length() > 1)
        {
            local named = [];
            foreach (local phrase in listed)
            {
                local one = a.dobjIsTopic ? firstNamed(phraseCandidates(phrase))
                    : chooseOne(phraseCandidates(phrase), a, dobjRole);
                if (one == nil)
                {
                    sayMsg(a.missingDobjMsg, c);
"\n";
                    return nil;
                }
                named = named + [one];
            }
            if (a.needsIobj)
            {
                c.iobj = a.iobjIsTopic ? firstNamed(phraseCandidates(c.iobj_))
                    : chooseOne(phraseCandidates(c.iobj_), a, iobjRole);
                if (c.iobj == nil)
                {
                    sayMsg(a.missingIobjMsg, c);
"\n";
                    return nil;
                }
            }
            return runCommandOver(c, named);
        }

        local several = c.dobj_ != nil && c.dobj_.pronoun_ =='all';
        local candidates = phraseCandidates(c.dobj_);
        if (several)
        {

            local best = rankNever;
            foreach (local item in candidates)
            {
                local score = inScope(item) ? rankOf(item, a, dobjRole) : rankNever;
                if (score > best)
                    best = score;
            }
            local wanted = best <= rankNever ? []
                : [for item in candidates
                   : item if inScope(item) && rankOf(item, a, dobjRole) == best];
            if (wanted.length() == 0)
            {
                sayMsg(a.missingDobjMsg, c);
"\n";
                return nil;
            }
            return runCommandOver(c, wanted);
        }
        c.dobj = a.dobjIsTopic ? firstNamed(candidates)
            : chooseOne(candidates, a, dobjRole);
        if (c.dobj == nil)
        {
            sayMsg(a.missingDobjMsg, c);
"\n";
            return nil;
        }
    }
    if (a.needsIobj)
    {
        c.iobj = a.iobjIsTopic
            ? firstNamed(phraseCandidates(c.iobj_))
            : chooseOne(phraseCandidates(c.iobj_), a, iobjRole);
        if (c.iobj == nil)
        {
            sayMsg(a.missingIobjMsg, c);
"\n";
            return nil;
        }
    }
    return runCommand(c);
}

runCommand(c)
{
    return runCommandOver(c, c.dobj == nil ? nil : [c.dobj]);
}

runCommandOver(c, items)
{
    local a = c.action;
    c.done_ = nil;
    c.reports_ = nil;
    c.failed_ = nil;
    if (items == nil)
        return finishCommand(c, actOnce(c, a, nil));
    foreach (local item in items)
    {
        c.dobj = item;
        actOnce(c, a, item);
        if (gameOver.done)
            break;
    }
    return finishCommand(c, a);
}

/* --------------------------------------------------------- preconditions */

class PreCondition: object
    met(item, a, c) { return true; }
    impliedVerb(item, a, c) { return nil; }
/* What the implied command acts on, when it is not the thing itself. */
    impliedDobj(item, a, c) { return item; }
    impliedIobj(item, a, c) { return nil; }
    failMsg ='precond.cannot'
;

/* The command an implied action runs in, so the outer one is not disturbed. */
impliedArgs: Command;

tryImplied(verb, item, into, outer)
{
    local v = verbFor(verb);
    if (v == nil)
        return 0;

    if (rankOf(item, v.action, dobjRole) < rankImplicit)
        return 0;
    local c = impliedArgs;
    c.action = v.action;
    c.dobj = item;
    c.iobj = into;
    c.dobj_ = nil;
    c.iobj_ = nil;
    c.set_ = nil;
    c.way_ = v.gerund();
    c.list_ = nil;
    c.dir_ = v.dir;
    c.done_ = nil;
    c.reports_ = nil;
    c.failed_ = nil;

    c.implied_ = true;
/*
     * `sayAbout` rather than `sayFor`, because the gerund is a **word** the
     * message needs and `sayFor` carries only entities.
     */
    local prep = v.preposition();
    sayAbout('precond.first', item, into == nil ? nil : [into],
             prep == nil ? v.gerund() : v.gerund() +' ' + prep);
"\n";
    actOnce(c, c.action, item);
    if (c.done_ != nil && c.done_.length() > 0)
        c.action.report(c);
    sayReports(c);
/* true when it worked, nil when it ran and refused, 0 when it never ran. */
    return !c.failed_ && c.done_ != nil && c.done_.length() > 0 ? true : nil;
}

meetPreConds(c, a, item, role)
{
    if (item == nil)
        return true;
    local conds = a.preCond(item, role) + item.preCond(a, role);
    if (conds.length() == 0)
        return true;
    for (local pass = 0; pass < 8; ++pass)
    {
        local unmet = nil;
        foreach (local p in conds)
        {
            if (!p.met(item, a, c))
            {
                unmet = p;
                break;
            }
        }
        if (unmet == nil)
            return true;
        local verb = unmet.impliedVerb(item, a, c);
        local tried = verb == nil ? 0
            : tryImplied(verb, unmet.impliedDobj(item, a, c),
                         unmet.impliedIobj(item, a, c), c);
        if (tried != true)
        {

            if (tried == 0)
            {
                sayFor(unmet.failMsg, item, c.iobj);
"\n";
            }
            return nil;
        }
    }
    sayFor('precond.cannot', item, nil);
"\n";
    return nil;
}

/* Held directly by the player. Implies TAKE. */
objHeld: PreCondition
    met(item, a, c) { return carried(item); }
    impliedVerb(item, a, c) { return 21; }
    failMsg ='precond.held'
;

/* Visible. Nothing implies being able to see. */
objVisible: PreCondition
    met(item, a, c) { return visible(item); }
    failMsg ='precond.visible'
;

/* Open, if it is the kind of thing that shuts. Implies OPEN. */
objOpen: PreCondition
    met(item, a, c) { return !item.isOpenable || item.isOpen; }
    impliedVerb(item, a, c) { return 23; }
    failMsg ='precond.open'
;

/* Shut. Implies CLOSE. */
objClosed: PreCondition
    met(item, a, c) { return !item.isOpenable || !item.isOpen; }
    impliedVerb(item, a, c) { return 24; }
    failMsg ='precond.closed'
;

/* Unlocked. Implies UNLOCK, with no key named — the action finds one. */
objUnlocked: PreCondition
    met(item, a, c) { return !item.isLockable || !item.isLocked; }
    impliedVerb(item, a, c) { return 41; }
    failMsg ='precond.unlocked'
;

/* Not being worn. Implies TAKE OFF. */
objNotWorn: PreCondition
    met(item, a, c) { return !item.isWorn; }
    impliedVerb(item, a, c) { return 33; }
    failMsg ='precond.worn'
;

/* Nothing inside. Implies taking one thing out, and the loop does the rest. */
objEmpty: PreCondition
    met(item, a, c) { return contains.all(item).length() == 0; }
    impliedVerb(item, a, c) { return 21; }
    impliedDobj(item, a, c)
    {
        local inside = contains.all(item);
        return inside.length() == 0 ? item : inside[1];
    }
    failMsg ='precond.empty'
;

touchObj: PreCondition
    met(item, a, c) { return blockingFor(item) == nil; }
    impliedVerb(item, a, c) { return 23; }
    impliedDobj(item, a, c)
    {
        local shut = blockingFor(item);
        return shut == nil ? item : shut;
    }
    failMsg ='precond.reach'
;

/*
 * The nearest shut container between the player and this thing, or nil.
 *
 * Nearest first, because opening the outer one is what lets you reach the
 * inner one, and the loop comes back for the rest.
 */
blockingFor(item)
{
    local shut = nil;
    foreach (local step in contains.ancestors(item))
    {

        if (step.isOpenable && !step.isOpen && !step.isTransparent)
            shut = step;
    }
    return shut;
}

replaceAction(verb, item, other)
{
    local v = verbFor(verb);
    if (v == nil)
        return nil;
    local c = impliedArgs;
    c.action = v.action;
    c.dobj = item;
    c.iobj = other;
    c.dobj_ = nil;
    c.iobj_ = nil;
    c.set_ = nil;
    c.way_ = nil;
    c.list_ = nil;
    c.dir_ = v.dir;
    c.done_ = nil;
    c.reports_ = nil;
    c.failed_ = nil;
    c.implied_ = nil;
    actOnce(c, c.action, item);
    if (c.done_ != nil && c.done_.length() > 0)
        c.action.report(c);
    sayReports(c);
    return true;
}

/* One object's worth of a command: redirect, refuse, act. */
actOnce(c, a, item)
{

    local doer = findDoer(c);
    if (doer != nil && doer.instead != nil)
    {
        a = doer.instead;
        c.action = a;
    }

    if (a.needsReach)
    {

        local far = c.dobj != nil && !a.dobjIsTopic && c.dobj.isDistant ? c.dobj
            : c.iobj != nil && !a.iobjIsTopic && c.iobj.isDistant ? c.iobj : nil;
        if (far != nil)
        {
            sayFor('reach.toofar', far, nil);
"\n";
            return a;
        }

        local high = c.dobj != nil && !a.dobjIsTopic && c.dobj.isOutOfReach
            && !c.dobj.canObjReachSelf(player) ? c.dobj
            : c.iobj != nil && !a.iobjIsTopic && c.iobj.isOutOfReach
            && !c.iobj.canObjReachSelf(player) ? c.iobj : nil;
        if (high != nil)
        {
            sayFor('reach.toohigh', high, nil);
"\n";
            return a;
        }
    }

    if (!meetPreConds(c, a, c.dobj, dobjRole))
        return a;
    if (!meetPreConds(c, a, a.iobjIsTopic ? nil : c.iobj, iobjRole))
        return a;
    if (c.dobj != nil)
    {
        local no = c.dobj.refuses(a, c);
        if (no != nil)
        {
"<<no>>\n";
            return a;
        }
    }
    if (c.iobj != nil)
    {
        local no = c.iobj.refuses(a, c);
        if (no != nil)
        {
"<<no>>\n";
            return a;
        }
    }

    local nest = nestedIn();
    if (nest != nil && nest.roomBeforeAction(c))
        return a;
    if (here().roomBeforeAction(c))
        return a;

    foreach (local watcher in contains.all(here()))
    {
        if (watcher.isActor && watcher.curState != nil)
            watcher.curState.beforeAction(c);
    }
    a.exec(c);
    foreach (local watcher in contains.all(here()))
    {
        if (watcher.isActor && watcher.curState != nil)
            watcher.curState.afterAction(c);
    }
    return a;
}

/*
 * The account and the turn, once, however many objects the command named.
 */
finishCommand(c, a)
{
    if (a == nil)
        return nil;

    if (c.done_ != nil && c.done_.length() > 0)
    {
        a.report(c);

        lastNamed.items = c.done_;
    }

    sayReports(c);

    if (!gameOver.done)
    {
        turnCount.value = turnCount.value + 1;

        runScenes();
        runActors();
        runEvents();
        syncStates();
    }
    dialogueUI.afterTurn();
    return nil;
}

/*
 * The command an action intent fills in. One command runs at a time, so this is
 * reused rather than allocated, for the same reason `msgArgs` is.
 */
actArgs: Command;

/* An optional library module may handle structured UI intents. */
dialogueUI: object
    accepts(verb) { return nil; }
    act(verb, args) { return nil; }
    afterTurn() { return nil; }
;

vhylAct(verb, subjects)
{
    if (dialogueUI.accepts(verb))
        return dialogueUI.act(verb, subjects);
    if (!gameOver.done)
        travelActions.cycle = travelActions.cycle + 1;
    local v = verbFor(verb);
    if (gameOver.done)
    {
        if (v != nil && v.action == undoAction)
            return undoAction.exec(nil);
        return endedCommand();
    }
    if (v == nil)
    {
        sayAbout('act.noverb', nil, nil, verb);
"\n";
        return nil;
    }
    local c = actArgs;
    local a = v.action;
    if (a == undoAction)
        return undoAction.exec(nil);
    c.action = a;
    c.dobj_ = nil;
    c.iobj_ = nil;
    c.dobj = nil;
    c.iobj = nil;
    c.way_ = nil;
    c.list_ = nil;
    c.dir_ = v.dir;
    local count = subjects == nil ? 0 : subjects.length();
    if (a.needsDobj)
    {
        if (count < 1)
        {
            sayMsg(a.missingDobjMsg, c);
"\n";
            return nil;
        }
        c.dobj = subjects[1];
    }
    if (a.needsIobj)
    {
        if (count < 2)
        {
            sayMsg(a.missingIobjMsg, c);
"\n";
            return nil;
        }
        c.iobj = subjects[2];
    }
/*
     * Scope is a world rule, so it is checked here too. A topic is deliberately
     * exempt: you can ask about a wreck on the shore below without it being to
     * hand, which is the same exemption the parser makes.
     */
    if (c.dobj != nil && !inScope(c.dobj))
    {
        sayFor('act.outofreach', c.dobj, nil);
"\n";
        return nil;
    }
    if (c.iobj != nil && !a.iobjIsTopic && !inScope(c.iobj))
    {
        sayFor('act.outofreach', c.iobj, nil);
"\n";
        return nil;
    }
    return runCommand(c);
}

recover(code)
{
    sayMsg('turn.failed', nil);
"\n> ";
    return nil;
}

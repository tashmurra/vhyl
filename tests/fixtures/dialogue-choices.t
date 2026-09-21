#include <vhyl.h>
#include <vhyl.t>
#ifndef DIALOGUE_EVENT_ONLY
#include <vhyl-en.t>
#include "dialogue-choices-en.t"
#endif
#include <vhyl-dialogue.t>

archive: Room 'Archive' desc = "A quiet office. ";
+ archivist: Actor 'Archivist' vocab = 'archivist';
+ clue: Thing 'observation log' vocab = 'log; observation; document';
outside: Room 'Outside';
other: Actor 'Other investigator' initiallyKnowsAbout = [signal, 'corroboration'];
signal: Topic 'signal' isFamiliar = nil;
inner: InternalSpeaker voiceOwner(player);
otherInner: InternalSpeaker voiceOwner(other);

interview: Conversation
    id = 'interview'
    target = archivist
    choices = [askMonster, followUp, challenge, reflect, privateChoice, otherPrivate, failedChoice, bye]
    opening(c)
    {
        dialogueSay(c.asker, 'visitor.greeting');
        dialogueSay(target, 'archivist.greeting');
        return nil;
    }
    closing(c) { return dialogueSay(c.asker, 'visitor.goodbye'); }
;
thoughts: Conversation
    id = 'thoughts'
    target = inner
    choices = [privateChoice, bye]
    opening(c) { return dialogueSay(inner, 'inner.opening'); }
;
askMonster: DialogueChoice
    id = 'ask-signal' labelId = 'choice.signal' subject = signal once = true
    selected(c)
    {
        dialogueSay(c.asker, 'visitor.signal');
        dialogueSay(archivist, 'archivist.denial');
        c.asker.setKnowsAbout('denial');
        return nil;
    }
;
followUp: DialogueChoice
    id = 'follow-up' labelId = 'choice.follow-up' requiresKnowledge = ['denial']
    available(c) { return !testState.suppressFollowUp; }
    selected(c) { return dialogueSay(archivist, 'archivist.follow-up'); }
;
challenge: DialogueChoice
    id = 'challenge' labelId = 'choice.challenge'
    requiresKnowledge = ['denial', 'corroboration']
    selected(c) { return dialogueSay(archivist, 'archivist.admits'); }
;
reflect: DialogueChoice
    id = 'reflect' labelId = 'choice.reflect' voice = inner
    requiresKnowledge = ['denial']
    selected(c)
    {
        dialogueSay(inner, 'inner.cue');
        c.asker.setKnowsAbout('noticed-hesitation');
        return nil;
    }
;
privateChoice: DialogueChoice
    id = 'consider' labelId = 'choice.consider' voice = inner
    requiresKnowledge = ['noticed-hesitation']
    selected(c) { return dialogueSay(inner, 'inner.consider'); }
;
otherPrivate: DialogueChoice
    id = 'other-private' labelId = 'choice.other' voice = otherInner
;
bye: GoodbyeChoice;

/* Diagnostic actions stand in for ordinary authored discoveries. */
learnAction: Action
    exec(c) { player.setKnowsAbout(signal); return nil; }
;
evidenceAction: Action
    exec(c) { player.setKnowsAbout('corroboration'); return nil; }
;
forgetAction: Action
    exec(c) { player.forget('corroboration'); return nil; }
;
leaveAction: Action
    exec(c) { contains.set(outside, archivist); return nil; }
;
failAction: Action
    exec(c) { player.setKnowsAbout('corroboration'); throw new DialogueError(); }
;
vLearn: Verb code = 90 action = learnAction;
vEvidence: Verb code = 91 action = evidenceAction;
vForget: Verb code = 92 action = forgetAction;
vLeave: Verb code = 93 action = leaveAction;
vFail: Verb code = 94 action = failAction;

modify gameMain initialRoom = archive;
startup() { return vhylStart(); }
act(verb, args)
{
    if (verb == 89) {
        event('test.state'); eventValue(turnCount.value); eventValue(undoDepth());
        local c = new DialogueContext(); c.asker = other; c.conversation = interview;
        eventValue(askMonster.eligible(c));
        eventValue(player.knowsAbout('failed-secret'));
        return nil;
    }
    return vhylAct(verb, args);
}

/* Acceptance controls: the UI above uses only discovery, forgetting and leaving. */
testState: object
    suppressFollowUp = nil
    offerFailure = nil
    untilLeave = 0
    tick()
    {
        if (untilLeave > 0) {
            untilLeave = untilLeave - 1;
            if (untilLeave == 0) contains.set(outside, archivist);
        }
        return nil;
    }
;
testTimer: Daemon owner = testState prop = &tick interval = 1;
suppressAction: Action exec(c) { testState.suppressFollowUp = !testState.suppressFollowUp; return nil; };
vSuppress: Verb code = 95 action = suppressAction;
timerAction: Action exec(c) { testState.untilLeave = 3; return nil; };
vTimer: Verb code = 96 action = timerAction;
failOfferAction: Action exec(c) { testState.offerFailure = true; return nil; };
vFailOffer: Verb code = 97 action = failOfferAction;
failedChoice: DialogueChoice
    id = 'fail' labelId = 'choice.fail' once = true
    available(c) { return testState.offerFailure; }
    selected(c) {
        c.asker.setKnowsAbout('failed-secret');
        dialogueSay(archivist, 'archivist.admits');
        throw new DialogueError();
    }
;

topicConversation: Conversation id = 'topic-interview' target = archivist choices = [topicChoice, bye];
topicEntry: TopicEntry actor = archivist matchObj = signal id = 'archivist.follow-up' waits = true;
topicChoice: TopicDialogueChoice id = 'topic-question' labelId = 'choice.signal' entry = topicEntry;

/* Optional host-driven conversations. Include after vhyl.t.
 * Copyright (c) 2026 John Cunningham. MIT License; see LICENSE. */

class DialogueError: object;

relation dialogueActive(controller: Entity, conversation: Entity) one_to_one;
relation dialogueAsker(controller: Entity, asker: Entity) one_to_one;
relation dialogueUsed(asker: Entity, choice: Entity) many_to_many;
/** @api author
 * Binds a private speaker to its owner; voiceOwner is the inverse. */
relation dialogueVoice(owner: Entity, voice: Entity) one_to_many reverse voiceOwner;

/* Not an Actor or Thing: never a physical or social target. */
/** @api author
 * A private conversational voice bound to its asker through voiceOwner. */
class InternalSpeaker: object
    knowsAbout(subject)
    {
        local owner = voiceOwner.get(self);
        return owner != nil && owner.knowsAbout(subject);
    }
;

/** @api author
 * The asker and active conversation passed to choice hooks. */
class DialogueContext: object
    asker = nil
    conversation = nil
;

/** @api author
 * A host-driven choice conversation with a stable id and target. */
class Conversation: object
    /** @api author
     * Stable nonempty identifier sent by a host to begin the conversation. */
    id = nil
    /** @api author
     * Actor or private speaker offering the conversation. */
    target = nil
    /** @api author
     * Authored DialogueChoice objects offered to the asker. */
    choices = []
    /** @api author
     * Whether this conversation can currently be opened or continued. */
    isActive = true
    /** @api author
     * Observational eligibility test for this asker. */
    availableTo(asker) { return true; }
    /** @api author
     * Run after an accepted begin request. */
    opening(c) { return nil; }
    /** @api author
     * Run when the goodbye choice closes this conversation. */
    closing(c) { return nil; }
/* Range is policy; a radio conversation may override this method. */
    /** @api author
     * Decide whether the active conversation remains available to an asker. */
    canContinue(asker)
    {
        if (target == nil || !isActive || !availableTo(asker)) return nil;
        if (target.ofKind(InternalSpeaker)) return voiceOwner.get(target) == asker;
        if (!target.isActor || !inScope(target)) return nil;
        return target.curState == nil || !target.curState.ofKind(HermitActorState);
    }
;

/** @api author
 * A selectable conversation option with stable identity and availability rules. */
class DialogueChoice: object
    /** @api author
     * Stable choice identifier sent by the host on selection. */
    id = nil
    /** @api author
     * Message id used to display the choice label. */
    labelId = nil
    /** @api author
     * Subject that the asker must know before this choice appears. */
    subject = nil
    /** @api author
     * Fact tags required in the asker's knowledge. */
    requiresKnowledge = []
    /** @api author
     * Consume this choice separately for each asker after selection. */
    once = nil
    /** @api author
     * Whether this choice is currently eligible. */
    isActive = true
/* A private option is available only to this voice's bound character. */
    /** @api author
     * Private speaker whose owner alone may see this choice. */
    voice = nil
    /** @api author
     * Observational condition evaluated while producing choices. */
    available(c) { return true; }
    /** @api author
     * Handle an accepted selection and any resulting world mutation. */
    selected(c) { return nil; }
    eligible(c)
    {
        if (!isActive || (once && dialogueUsed.contains(c.asker, self))) return nil;
        if (voice != nil && (!voice.ofKind(InternalSpeaker) || voiceOwner.get(voice) != c.asker)) return nil;
        if (subject != nil && !c.asker.knowsAbout(subject)) return nil;
        foreach (local fact in requiresKnowledge)
            if (!c.asker.knowsAbout(fact)) return nil;
        return available(c);
    }
;

/* Explicit opt-in adapter; the entry retains its existing once/used semantics.
 * Use DialogueChoice.once for per-asker consumption instead. */
/** @api author
 * Explicitly adapts a TopicEntry into a choice conversation. */
class TopicDialogueChoice: DialogueChoice
    /** @api author
     * TopicEntry adapted by this choice. */
    entry = nil
    eligible(c)
    {
        if (entry == nil || entry.id == nil) throw new DialogueError();
        return entry.actor == c.conversation.target
            && topicAvailableTo(entry, c.asker) && inherited(c);
    }
    selected(c)
    {
        dialogueSay(entry.actor, entry.id);
        if (entry.waits) hostAction(0);
        entry.used = true;
        return nil;
    }
;

/* Keys stay stable; optional literal Message.text is terminal/example fallback.
 * Fallback text and message activity must be observational, like availability. */
dialogueText(key)
{
    local m = messageFor(key);
    return m == nil ? nil : m.text;
}

dialogueContext()
{
    local c = new DialogueContext();
    c.asker = dialogueAsker.get(dialogueUI);
    c.conversation = dialogueActive.get(dialogueUI);
    return c;
}

dialogueSay(speaker, key)
{
    local c = dialogueContext();
    if (c.conversation == nil) return nil;
    local privateLine = speaker.ofKind(InternalSpeaker);
    if (privateLine && voiceOwner.get(speaker) != c.asker)
        throw new DialogueError();
    event('dialogue.utterance');
    eventValue(c.conversation.id);
    eventValue(speaker);
    eventValue(key);
    eventValue(dialogueText(key));
    eventValue(privateLine);
    eventValue(c.asker);
    eventValue(privateLine ? nil : speaker.name);
    local text = dialogueText(key);
    if (text != nil)"<<text>>\n";
    return nil;
}

dialogueEnd(reason)
{
    local conv = dialogueActive.get(dialogueUI);
    if (conv == nil) return nil;
    event('dialogue.end');
    eventValue(conv.id);
    eventValue(reason);
    dialogueActive.unset(dialogueUI, conv);
    local asker = dialogueAsker.get(dialogueUI);
    if (asker != nil) dialogueAsker.unset(dialogueUI, asker);
    return nil;
}

/** @api author
 * Standard choice that closes a conversation. */
class GoodbyeChoice: DialogueChoice
    id ='goodbye'
    labelId ='dialogue.goodbye'
    selected(c) { c.conversation.closing(c); return dialogueEnd('goodbye'); }
;

/* The integer codes are transport verbs, not speech-act categories. */
vDialogueBegin: Verb code = 80 action = dialogueTurn label ='begin-conversation';
vDialogueSelect: Verb code = 81 action = dialogueTurn label ='select-dialogue-choice';
vDialogueRefresh: Verb code = 82 action = dialogueTurn label ='refresh-dialogue';
dialogueTurn: Action;

modify dialogueUI
    accepts(verb) { return verb == 80 || verb == 81 || verb == 82; }
    act(verb, args)
    {
        local n = args == nil ? 0 : args.length();
        if (verb == 82) return publish();
        if (gameOver.done) return refuse('game-ended');
        if (verb == 80)
        {
            if (n != 1 || dataType(args[1]) != TypeSString) return refuse('invalid');
            if (dialogueActive.get(self) != nil) return refuse('already-active');
            local found = nil;
            for (local conv = firstObj(Conversation); conv != nil; conv = nextObj(conv, Conversation))
            {
                if (conv.id == args[1])
                {
                    if (found != nil) throw new DialogueError();
                    found = conv;
                }
            }
            if (found == nil || !found.canContinue(player)) return refuse('unavailable');
            dialogueActive.set(self, found);
            dialogueAsker.set(self, player);
            found.opening(dialogueContext());
            return finishExchange();
        }
/* Exact ID and token, never a label or list index. */
        if (n != 3 || dataType(args[1]) != TypeSString
            || dataType(args[2]) != TypeInt || dataType(args[3]) != TypeSString)
            return refuse('invalid');
        local c = dialogueContext();
        if (c.conversation == nil || c.conversation.id != args[1]
            || c.asker != player || args[2] <= 0 || !snapshotToken(args[2]))
            return refuse('stale');
        if (!c.conversation.canContinue(c.asker)) return refuse('unavailable');
        local selected = nil;
        foreach (local choice in c.conversation.choices)
        {
            if (choice.id == args[3] && choice.eligible(c))
            {
                if (selected != nil) throw new DialogueError();
                selected = choice;
            }
        }
        if (selected == nil) return refuse('unavailable');
        if (!c.conversation.target.ofKind(InternalSpeaker)) c.conversation.target.talkedThisTurn = true;
        if (selected.once) dialogueUsed.set(c.asker, selected);
        selected.selected(c);
        return finishExchange();
    }
    finishExchange()
    {
        local conv = dialogueActive.get(self);
        if (conv != nil && !conv.target.ofKind(InternalSpeaker)) conv.target.talkedThisTurn = true;
        return finishCommand(new Command(), dialogueTurn);
    }
    afterTurn()
    {
        local c = dialogueContext();
        if (c.conversation != nil)
        {
            if (gameOver.done || c.asker != player || !c.conversation.canContinue(c.asker))
                dialogueEnd(gameOver.done ?'game-ended' :'unavailable');
            else publish();
        }
        return nil;
    }
    refuse(reason)
    {
        event('dialogue.refused'); eventValue(reason);
        return publish();
    }
    publish()
    {
        local c = dialogueContext();
/* Refresh is observational: an invalid durable interaction is closed
         * by the next real turn, but the host immediately receives an ending. */
        if (c.conversation == nil || c.asker != player || gameOver.done
            || !c.conversation.canContinue(c.asker))
        {
            event('dialogue.end');
            eventValue(c.conversation == nil ? nil : c.conversation.id);
            eventValue('unavailable');
            return nil;
        }
        local eligible = new Vector(8);
        local ids = new Vector(8);
        foreach (local choice in c.conversation.choices)
        {
            if (dataType(choice.id) != TypeSString || choice.id ==''
                || dataType(choice.labelId) != TypeSString || choice.labelId ==''
                || ids.indexOf(choice.id) != nil)
                throw new DialogueError();
            ids.append(choice.id);
            if (choice.eligible(c)) {
                if (eligible.length() == 64) throw new DialogueError();
                eligible.append(choice);
            }
        }
        if (eligible.length() > 64) throw new DialogueError();
        event('dialogue.choices');
        eventValue(c.conversation.id);
        eventValue(snapshotToken(0));
        eventValue(c.asker);
        eventValue(c.conversation.target);
        eventValue(eligible.length());
        foreach (local choice in eligible)
        {
            eventValue(choice.id);
            eventValue(choice.labelId);
            eventValue(dialogueText(choice.labelId));
            eventValue(choice.voice != nil);
        }
        return nil;
    }
;

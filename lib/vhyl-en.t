/* Optional English messages and grammatical presentation for vhyl.
 * Copyright (c) 2026 John Cunningham. MIT License; see LICENSE. */

/* ---------------------------------------------------------- the expander */

inPast()
{
    if (expandCtx.forceTense != nil)
        return expandCtx.forceTense == 2;
    return gameMain.usePastTense;
}

/* The tense a `{...!}` parameter and quoted speech pin themselves to. */
withPast(on) { expandCtx.forceTense = on ? 2 : 1; return nil; }
withPresent() { return withPast(nil); }
withTense(past) { return withPast(past); }

tSel(now, then) { return inPast() ? then : now; }

expandCtx: object
    subject = nil
/* nil for a third-person singular subject, true for "you" or a plural. */
    plural = nil
/* What `{it}` refers to: whatever a parameter last named (antecedents). */
    antecedent = nil
/* The subject of the sentence being built, for reflexives. */
    sentenceSubject = nil
/* 1 present, 2 past, nil to follow the game. */
    forceTense = nil
;

messageParams: object names = [] items = [];

setMessageParam(name, item)
{
    local at = messageParams.names.indexOf(name);
    if (at != nil)
    {
        local rebuilt = [];
        for (local i = 1; i <= messageParams.items.length(); ++i)
            rebuilt = rebuilt + [i == at ? item : messageParams.items[i]];
        messageParams.items = rebuilt;
        return nil;
    }
    messageParams.names = messageParams.names + [name];
    messageParams.items = messageParams.items + [item];
    return nil;
}

clearMessageParams()
{
    messageParams.names = [];
    messageParams.items = [];
    return nil;
}

/* Note that a parameter named this entity, for the verb and the pronoun after it. */
noteSubject(item, isPlural)
{
    expandCtx.subject = item;
    expandCtx.plural = isPlural;
    if (item != nil)
        expandCtx.antecedent = item;
    return nil;
}

/*
 * The person the player character is written in, and whether that person takes
 * a plural verb. "I", "you", "we" and "they" all take the bare form; only a
 * third-person singular takes the -s.
 */
pcPerson() { return player.pcReferralPerson; }

/*
 * One verb, agreeing with whatever the last parameter named.
 *
 * English needs an -s on a third-person singular present verb and nothing
 * anywhere else, which is the whole of the agreement most library messages
 * need. A verb whose past is not "-ed" says so.
 */
conjugate(verb, past)
{
    if (inPast())
    {
        if (past != nil)
            return past;

        if (verb.substr(verb.length()) =='e')
            return verb +'d';
        return verb +'ed';
    }
    if (expandCtx.plural)
        return verb;
/* *go* becomes *goes*, *push* becomes *pushes*. */
    local last = verb.substr(verb.length());
    if (last is in ('s','x','z') || verb.substr(verb.length() - 1) is in ('sh','ch'))
        return verb +'es';
    if (last =='y' && verb.length() > 1
        && !(verb.substr(verb.length() - 1, 1) is in ('a','e','i','o','u')))
        return verb.substr(1, verb.length() - 1) +'ies';
    return verb +'s';
}

verbEnding(present, past)
{
    if (inPast())
        return past == nil ?'ed' : past;
    if (expandCtx.plural)
        return present =='ies' ?'y' :'';
    return present;
}

/* "is" or "are", and "was" or "were". */
beVerb()
{
    if (inPast())
        return expandCtx.plural ?'were' :'was';
    return expandCtx.plural ?'are' :'is';
}

irregularVerb(word)
{
    if (word =='is' || word =='are')
        return beVerb();
    if (word =='was' || word =='were')
    {

        return expandCtx.plural ?'were' :'was';
    }
    if (word =='has' || word =='have')
        return inPast() ?'had' : (expandCtx.plural ?'have' :'has');
    if (word =='do' || word =='does')
        return inPast() ?'did' : (expandCtx.plural ?'do' :'does');
    if (word =='go' || word =='goes')
        return inPast() ?'went' : (expandCtx.plural ?'go' :'goes');
    if (word =='come' || word =='comes')
        return inPast() ?'came' : (expandCtx.plural ?'come' :'comes');
    if (word =='leave' || word =='leaves')
        return inPast() ?'left' : (expandCtx.plural ?'leave' :'leaves');
    if (word =='see' || word =='sees')
        return inPast() ?'saw' : (expandCtx.plural ?'see' :'sees');
    if (word =='say' || word =='says')
        return inPast() ?'said' : (expandCtx.plural ?'say' :'says');

    if (word =='must')
        return inPast() ?'had to' :'must';
    if (word =='can')
        return inPast() ?'could' :'can';
    if (word =='cannot')
        return inPast() ?'could not' :'cannot';
    if (word =='can\'t')
        return inPast() ?'couldn\'t' :'can\'t';
    if (word =='will')
        return inPast() ?'would' :'will';
    if (word =='won\'t')
        return inPast() ?'wouldn\'t' :'won\'t';
    return nil;
}

/* The verb endings, by the string inside the braces. Answers nil for a word
 * that is not one. */
endingFor(word)
{
    if (word =='s')
        return verbEnding('s', nil);
    if (word =='es' || word =='es/ed')
        return verbEnding('es','ed');
    if (word =='ies' || word =='ies/ied')
        return verbEnding('ies','ied');
    if (word =='s/d')
        return verbEnding('s','d');
    if (word =='s/ed')
        return verbEnding('s','ed');
/*
     * `{s/?ed}` in the documentation, where the question mark stands for the
     * consonant the past doubles: a message writes `{s/ped}` for *dropped*.
     */
    if (word.length() >= 5 && word.substr(1, 2) =='s/' && word.substr(word.length() - 1) =='ed')
        return verbEnding('s', word.substr(3));
    return nil;
}

/* The entity a `{...}` parameter names, by the word the message used. */
paramOf(name, c)
{
    if (name =='actor')
        return player;
    if (name =='it')
        return expandCtx.antecedent;
    local at = messageParams.names.indexOf(name);
    if (at != nil)
        return messageParams.items[at];
    if (c == nil)
        return nil;
    if (name =='dobj')
        return c.dobj;
    if (name =='iobj')
        return c.iobj;
    return nil;
}

/* ------------------------------------------------------- the name shapes */

pronounSet(item)
{
    if (item == nil)
        return 3;
    if (item.isPlural || item.isGenderNeutral)
        return 4;
    if (item.isHim)
        return 1;
    if (item.isHer)
        return 2;
    return 3;
}

/* he/she/it/they, and him/her/it/them. */
proWord(item, nominative)
{
    local set = pronounSet(item);
    if (set == 1)
        return nominative ?'he' :'him';
    if (set == 2)
        return nominative ?'she' :'her';
    if (set == 4)
        return nominative ?'they' :'them';
    return'it';
}

/* his/her/its/their — the form that qualifies a noun. */
proPossAdj(item)
{
    local set = pronounSet(item);
    return set == 1 ?'his' : set == 2 ?'her' : set == 4 ?'their' :'its';
}

/* his/hers/its/theirs — the form that stands alone. */
proPossNoun(item)
{
    local set = pronounSet(item);
    return set == 1 ?'his' : set == 2 ?'hers' : set == 4 ?'theirs' :'its';
}

/* himself/herself/itself/themselves. */
proReflexive(item)
{
    local set = pronounSet(item);
    return set == 1 ?'himself' : set == 2 ?'herself'
        : set == 4 ?'themselves' :'itself';
}

/* Whether this thing takes a plural verb: *they are*, *it is*. */
proIsPlural(item)
{
    return pronounSet(item) == 4;
}

pcWord(nominative)
{
    local person = pcPerson();
    if (person == FirstPerson)
        return nominative ?'I' :'me';
    if (person == ThirdPerson)
        return proWord(player, nominative);
    return'you';
}

/* The subject form: *you*, *I*, *the keeper*. */
nomName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
        return pcWord(true);
    return theName(item);
}

/* The object form: *you*, *me*, *the keeper*. */
objName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
        return pcWord(nil);
    return theName(item);
}

/* *myself*, *yourself*, *himself*, *herself*, *itself*, *themselves*. */
reflexiveName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
    {
        local person = pcPerson();
        if (person == FirstPerson)
            return'myself';
        if (person == ThirdPerson)
            return proReflexive(player);
        return'yourself';
    }
    return proReflexive(item);
}

/* A pronoun for something that is not the player: *he*, *her*, *it*, *them*. */
itName(item, nominative)
{
    if (item == nil)
        return'[no antecedent]';
    if (item == player)
        return pcWord(nominative);
    return proWord(item, nominative);
}

possAdjName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
    {
        local person = pcPerson();
        if (person == FirstPerson)
            return'my';
        if (person == ThirdPerson)
            return proPossAdj(player);
        return'your';
    }
    return proPossAdj(item);
}

/* *mine*, *yours*, *his*, *hers*, *its*, *theirs* — the form that stands alone. */
possNounName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
    {
        local person = pcPerson();
        if (person == FirstPerson)
            return'mine';
        if (person == ThirdPerson)
            return proPossNoun(player);
        return'yours';
    }
    return proPossNoun(item);
}

/* *it's*, *you're*, *the keeper's* — the contraction of a name and "to be". */
contractionName(item)
{
    if (item == nil)
        return'nothing';
/*
     * The verb in a contraction agrees with the thing being contracted onto,
     * not with whatever the sentence named last: *you're late, and it's early*
     * has two subjects and two agreements.
     */
    local was = expandCtx.plural;

    expandCtx.plural = item == player
        ? pcPerson() != ThirdPerson || proIsPlural(player)
        : proIsPlural(item);
    if (inPast())
    {
        local past = nomName(item) +' ' + beVerb();
        expandCtx.plural = was;
        return past;
    }
    expandCtx.plural = was;
    if (item == player)
    {
        local person = pcPerson();
        if (person == FirstPerson)
            return'I\'m';
        if (person == ThirdPerson)
            return proIsPlural(player) ?'they\'re' : proWord(player, true) +'\'s';
        return'you\'re';
    }
    return proIsPlural(item) ?'they\'re' : proWord(item, true) +'\'s';
}

thatName(item)
{
    if (item == nil)
        return'that';
    if (item == player)
        return pcWord(true);

    return item.isPlural ?'those' :'that';
}

/* ---------------------------------------------------- one parameter body */

moveSlash: object head = nil tail = nil;

splitParam(body)
{
    local space = body.find(' ');
    if (space == nil)
    {
        moveSlash.head = body;
        moveSlash.tail = nil;
        return nil;
    }
    local head = body.substr(1, space - 1);
    local tail = body.substr(space + 1);
    local slash = tail.find('/');
    if (slash != nil)
    {
        head = head + tail.substr(slash);
        tail = tail.substr(1, slash - 1);
    }
    moveSlash.head = head;
    moveSlash.tail = tail;
    return nil;
}

applyCase(word, head)
{
    if (word == nil || word.length() == 0 || head.length() == 0)
        return word;
    local first = head.substr(1, 1);
    if (first != first.toUpper() || first == first.toLower())
        return word;
    if (head.length() > 1)
    {
        local second = head.substr(2, 1);
        if (second == second.toUpper() && second != second.toLower())
            return word.toUpper();
    }
    return capitalised(word);
}

formKind(head)
{
    local key = head.toLower();
    if (key is in ('a','an','a/he','an/he','a/she','an/she'))
        return 1;/* aName, subject */
    if (key is in ('a/him','a/her','an/him','an/her'))
        return 2;/* aName, object, reflexive */
    if (key is in ('the','the/he','the/she'))
        return 3;/* theName, subject */
    if (key is in ('the/him','the/her'))
        return 4;/* theName, object, reflexive */
    if (key is in ('that','that/he','that/she'))
        return 5;/* that, subject */
    if (key is in ('that/him','that/her'))
        return 6;/* that, object, reflexive */
    if (key is in ('it','it/he','it/she'))
        return 7;/* pronoun, subject */
    if (key is in ('it/him','it/her'))
        return 8;/* pronoun, object, reflexive */
    if (key is in ('its','its/her','its/his'))
        return 9;/* possessive adjective */
    if (key is in ('its/hers'))
        return 10;/* possessive noun */
    if (key is in ('itself','itself/himself','itself/herself'))
        return 11;/* reflexive */
    if (key is in ('you','you/he','you/she'))
        return 12;/* actor, subject */
    if (key is in ('you/him','you/her'))
        return 13;/* actor, object, reflexive */
    if (key is in ('your','your/his','your/her'))
        return 14;/* actor possessive adjective */
    if (key is in ('yours','yours/his','yours/hers'))
        return 15;/* actor possessive noun */
    if (key is in ('yourself','yourself/himself','yourself/herself'))
        return 16;/* actor reflexive */
    if (key is in ('it\'s','it\'s/he\'s','it\'s/she\'s'))
        return 17;/* contraction */
    if (key is in ('you\'re','you\'re/he\'s','you\'re/she\'s'))
        return 18;/* actor contraction */
    if (key =='subj')
        return 19;/* marks the subject, says nothing */
    if (key =='name')
        return 20;/* vhyl's own: the bare name */
    if (key =='way')
        return 21;/* vhyl's own: the captured word */
    if (key =='i')
        return 12;/* vhyl's own spelling of {you} */
    return 0;
}

/* Whether this kind implies the actor rather than taking a selector. */
kindMeansActor(kind)
{
    return kind >= 12 && kind <= 16 || kind == 18;
}

/* Whether this kind is the sentence's subject. */
kindIsSubject(kind)
{
    return kind is in (1, 3, 5, 7, 12, 17, 18, 19);
}

/* `{way}` names no object, so it must not disturb the antecedent. */
kindNamesNothing(kind) { return kind == 21; }

/* Whether this kind has a reflexive form to fall back on. */
kindReflexes(kind)
{
    return kind is in (2, 4, 6, 8);
}

kindIsPronoun(kind)
{
    return kind is in (7, 8, 11, 17);
}

/* The word a kind produces for a thing. */
wordFor(kind, item)
{
    if (kind == 1 || kind == 2)
        return aName(item);
    if (kind == 3)
        return nomName(item);
    if (kind == 4)
        return objName(item);
    if (kind == 5 || kind == 6)
        return thatName(item);
    if (kind == 7)
        return itName(item, true);
    if (kind == 8)
        return itName(item, nil);
    if (kind == 9 || kind == 14)
        return possAdjName(item);
    if (kind == 10 || kind == 15)
        return possNounName(item);
    if (kind == 11 || kind == 16)
        return reflexiveName(item);
    if (kind == 12)
        return nomName(item);
    if (kind == 13)
        return objName(item);
    if (kind == 17 || kind == 18)
        return contractionName(item);
    if (kind == 19)
        return'';
    return item == nil ?'nothing' : item.name;
}

wayWord(c)
{
    return c == nil || c.way_ == nil ?'' : c.way_;
}

/*
 * Expand one `{...}`, given what is inside it.
 *
 * The order matters: a tense choice, then a verb ending, then an irregular
 * verb, then the format table, and only then the fallback that treats an
 * unknown word as a regular verb — which is vhyl's own addition and is what
 * lets a message write `{take}` instead of `take{s}`.
 */
expandOne(body, c)
{
    if (body.length() == 0)
        return'';

    local fixed = nil;
    if (body.substr(body.length()) =='!')
    {
        body = body.substr(1, body.length() - 1);
        fixed = true;
        withPresent();
    }
    local out = expandBody(body, c);
    if (fixed)
        expandCtx.forceTense = nil;
    return out;
}

expandBody(body, c)
{
    local bar = body.find('|');
/* A bare choice with no parameter is a tense: present on the left. */
    if (bar != nil && body.find(' ') == nil)
    {
        local left = body.substr(1, bar - 1);
        local right = body.substr(bar + 1);
/* A verb and its irregular past, or a plain pair of words. */
        if (isVerbWord(left))
            return conjugate(left, right);

        return expandNested(inPast() ? right : left, c);
    }
    splitParam(body);
    local head = moveSlash.head;
    local kind = formKind(head);
    if (kind != 0)
    {
        local item = kindMeansActor(kind) ? player
            : moveSlash.tail != nil ? paramOf(moveSlash.tail, c)
            : expandCtx.antecedent;
/*
         * A reflexive when the sentence has already named this thing as its
         * subject — *Bob slapped himself with the herring*.
         */
        if (kindReflexes(kind) && item != nil && item == expandCtx.sentenceSubject)
            kind = 11;
        local word = kind == 21 ? wayWord(c) : wordFor(kind, item);
        if (kindIsSubject(kind))
        {
            expandCtx.sentenceSubject = item;
            noteSubject(item, item == player
                       ? pcPerson() != ThirdPerson || proIsPlural(player)
                       : item == nil ? nil
                       : kindIsPronoun(kind) ? proIsPlural(item) : item.isPlural);
        }
        else if (item != nil && !kindNamesNothing(kind))
            expandCtx.antecedent = item;
        return applyCase(word, head);
    }
/* A word on its own: a verb ending, an irregular verb, or a verb. */
    if (moveSlash.tail == nil)
    {
        local ending = endingFor(head);
        if (ending != nil)
            return ending;
        local irregular = irregularVerb(head.toLower());
        if (irregular != nil)
            return applyCase(irregular, head);
        return applyCase(conjugate(head.toLower(), nil), head);
    }
/* An unknown format type with a selector: name the thing and move on. */
    local item = paramOf(moveSlash.tail, c);
    noteSubject(item, item == player);
    return applyCase(theName(item), head);
}

/* A nested `[...]` inside a tense choice, which is a parameter in brackets. */
expandNested(text, c)
{
    local out ='';
    local rest = text;
    for (;;)
    {
        local open = rest.find('[');
        if (open == nil)
            return out + rest;
        local close = rest.find(']');
        if (close == nil || close < open)
            return out + rest;
        out = out + rest.substr(1, open - 1)
            + expandBody(rest.substr(open + 1, close - open - 1), c);
        rest = rest.substr(close + 1);
    }
}

/* Whether a word left of a `|` is a verb rather than one half of a choice. */
isVerbWord(word)
{
    return word =='is' || word =='are' || word =='has' || word =='have';
}

expandAll(text, c)
{
/*
     * The player is the subject until a parameter says otherwise, and the
     * player's person decides whether the verb agrees as a plural: *I*, *you*,
     * *we* and *they* all take the bare form, and only a third-person singular
     * takes the -s.
     */
    expandCtx.subject = player;
    expandCtx.plural = pcPerson() != ThirdPerson;
    expandCtx.antecedent = c == nil ? nil : c.dobj;
    expandCtx.sentenceSubject = nil;
    expandCtx.forceTense = nil;
    local out ='';
    local rest = text;
    for (;;)
    {
        local open = rest.find('{');
        if (open == nil)
            return out + noteSentenceEnd(rest);
        local close = rest.find('}');
        if (close == nil || close < open)
            return out + rest;
        local before = rest.substr(1, open - 1);
        noteSentenceEnd(before);
        out = out + before
            + expandOne(rest.substr(open + 1, close - open - 1), c);
        rest = rest.substr(close + 1);
    }
}

noteSentenceEnd(text)
{
    if (text.find('.') != nil || text.find('?') != nil || text.find('!') != nil)
        expandCtx.sentenceSubject = nil;
    return text;
}

/* English is where `{...}` means something, so the hook is filled in here. */
modify language
    expand(text, c)
    {
        return text.find('{') == nil ? text : expandAll(text, c);
    }
;

/* ------------------------------------------------------------- the words */

article(word)
{
    if (word == nil || word.length() == 0)
        return'a';
    local first = word.substr(1, 1);
    if (first is in ('a','e','i','o','u','A','E','I','O','U'))
        return'an';
    return'a';
}

nameList(items)
{
    local out ='';
    local count = items.length();
    for (local at = 1; at <= count; ++at)
    {
        if (at > 1)
            out = out + (at == count ?' and ' :', ');
        out = out + aName(items[at]);
    }
    return out;
}

/* ------------------------------------------------------- naming helpers */

theName(item)
{
    if (item == nil)
        return'nothing';
/* You are not *the you*, and Zoé is not *the Zoé*. */
    if (item == player)
        return'yourself';
    if (item.isProper)
        return item.name;
    return'the ' + item.name;
}

aName(item)
{
    if (item == nil)
        return'nothing';
    if (item == player)
        return pcWord(true);
    if (item.isProper)
        return item.name;
/* A mass noun takes none, and a plural takes *some*. */
    if (item.isMassNoun)
        return item.name;
    if (item.isPlural)
        return'some ' + item.name;
    return article(item.name) +' ' + item.name;
}

capitalised(text)
{
    if (text == nil || text.length() == 0)
        return text;
    return text.substr(1, 1).toUpper() + text.substr(2);
}

TheName(item) { return capitalised(theName(item)); }
AName(item)   { return capitalised(aName(item)); }

/* "is" or "are", for a count. Agreement, as far as vhyl needs it. */
isAre(count)
{
    return count == 1 ?'is' :'are';
}

/* The same, for one thing whose name is grammatically plural. */
isAreFor(item)
{
    return item != nil && item.isPlural ?'are' :'is';
}

/*
 * The English word for a spatial position. vhyl says a thing rests `posOn`
 * another; which preposition that is, and that English has one at all, is this
 * module's business.
 */
prepFor(pos)
{
    if (pos == posOn)
        return'on';
    if (pos == posUnder)
        return'under';
    if (pos == posBehind)
        return'behind';
    return'in';
}

/* ------------------------------------------------- vhyl's default messages */

/*
 * Every sentence vhyl says, with an id. A game overrides one by declaring its
 * own Message with the same id and a higher priority — it does not need to know
 * the name of the object below.
 */

msgTaken:        Message id ='take.ok'        text ='Taken. ';
msgAlreadyHave:  Message id ='take.already'   text ='{You/he} already {have} {the dobj}. ';
msgFixed:        Message id ='take.fixed'     say(c) {"<<TheName(c.dobj)>> is fixed in place. "; return nil; };
msgDropped:      Message id ='drop.ok'        text ='Dropped. ';
msgNotCarried:   Message id ='drop.notheld'   text ='{You/he} {is}n\'t holding {the dobj}. ';

msgOpened:       Message id ='open.ok'        text ='Opened. ';
enOpenReveals:   Message id ='open.reveals'   say(c) {"Opening <<theName(c.dobj)>> reveals <<nameList(c.list_)>>. "; return nil; };
msgAlreadyOpen:  Message id ='open.already'   text ='It is already open. ';
msgNotOpenable:  Message id ='open.cannot'    say(c) {"<<TheName(c.dobj)>> is not something you can open. "; return nil; };
msgClosed:       Message id ='close.ok'       text ='Closed. ';
msgAlreadyShut:  Message id ='close.already'  text ='It is already closed. ';
msgNotCloseable: Message id ='close.cannot'   say(c) {"<<TheName(c.dobj)>> is not something you can close. "; return nil; };

msgNothingOdd:   Message id ='examine.plain'  text ='{You/he} {see} nothing unusual about {the dobj/him}. ';
msgEmptyHanded:  Message id ='inventory.none' text ='You are empty-handed. ';
msgCarrying:     Message id ='inventory.some' text ='You are carrying:';

msgSwitchedOn:   Message id ='turnon.ok'      text ='{You/he} {turn} {the dobj} on. ';
msgSwitchedOff:  Message id ='turnoff.ok'     text ='{You/he} {turn} {the dobj} off. ';
msgNotLightable: Message id ='turnon.cannot'  say(c) {"<<TheName(c.dobj)>> is not something you can turn on. "; return nil; };
msgNotDousable:  Message id ='turnoff.cannot' say(c) {"<<TheName(c.dobj)>> is not something you can turn off. "; return nil; };
msgAlreadyLit:   Message id ='turnon.already' text ='It is already lit. ';
msgAlreadyOut:   Message id ='turnoff.already' text ='It is already off. ';
msgPitchBlack:   Message id ='light.out'      text ='It is pitch black. ';

msgCannotGo:     Message id ='go.nowhere'     text ='You cannot go that way. ';
msgDoorShut:     Message id ='go.shut'        say(c) {"<<TheName(c.dobj)>> is closed. "; return nil; };
msgLeadsNowhere: Message id ='go.leadsnowhere' say(c) {"<<TheName(c.dobj)>> leads nowhere. "; return nil; };

msgNoSuchThing:  Message id ='parse.noref'    text ='You see no such thing. ';
msgNotUnderstood: Message id ='parse.nomatch' text ='I don\'t understand that. ';
msgNotOne:       Message id ='parse.notone'   text ='That was not one of them. ';
msgWhichDoYouMean: Message id ='parse.which'  text ='Which do you mean';

msgDarkRoom:     Message id ='room.dark'      text ='In the dark\nIt is pitch black, and you cannot see a thing. ';
msgNothingToUndo: Message id ='undo.none'     text ='There is nothing to undo. ';
msgUndone:       Message id ='undo.ok'        text ='Undone. ';

msgWorn:         Message id ='wear.ok'        text ='{You/he} {put} {the dobj} on. ';
msgNotWearable:  Message id ='wear.cannot'    say(c) {"<<TheName(c.dobj)>> is not something you can wear. "; return nil; };
msgAlreadyWorn:  Message id ='wear.already'   text ='You are already wearing it. ';
msgTakenOff:     Message id ='doff.ok'        text ='{You/he} {take} {the dobj} off. ';
msgNotWorn:      Message id ='doff.notworn'   text ='{You/he} {is}n\'t wearing {the dobj}. ';

msgNothingHappens: Message id ='action.nothing' text ='Nothing happens. ';
msgRecovered:    Message id ='turn.failed'    text ='Something went wrong; nothing changed. ';

/* --------------------------------------------- English on vhyl's classes */

/*
 * vhyl declares these properties and gives them no words. The words are
 * English, so they are here. A game loading vhyl without a language module
 * gets a library that describes nothing, which is correct rather than broken:
 * it has not said what language it is in.
 */

msgGameEnded: Message id ='game.ended'
    text ='The game has ended. You can UNDO the ending or close the session. ';
msgPlayerDesc: Message id ='player.desc'
    text ='{You/he} {look} as well as can be expected. ';

/* Emitting properties are literal prose. Ask a Message for expanded text. */
modify player
    desc ="<<msgFor('player.desc', player, nil)>>"
;

modify Thing
    desc ="There is nothing unusual about <<theName(self)>>. "
;

modify Actor
    desc ="<<name>> is here. "
;

modify TopicEntry
    reply ="There is no answer. "
;

modify Switch
    desc ="A switch, currently <<isOn ? 'on' : 'off'>>. "
;

modify Lever
    desc ="A lever, currently <<isUp ? 'up' : 'down'>>. "
;

modify Dial
    desc ="A dial, set to <<setting>>. "
;

modify Button
    desc ="A button. "
;

modify Platform
    enterDesc ="<<language.expand('{You/he} {get} onto ', nil)>><<theName(self)>>. "
;

modify Booth
    enterDesc ="<<language.expand('{You/he} {get} into ', nil)>><<theName(self)>>. "
;

modify Enterable
    enterDesc ="<<language.expand('{You/he} {go} into ', nil)>><<theName(self)>>. "
;

/* ------------------------------------------- the rest of vhyl's messages */

/* Examining and describing */
enExamineEmpty:   Message id ='examine.empty'   say(c) {"<<TheName(c.dobj)>> is empty. "; return nil; };
enRoomThereIs:    Message id ='room.thereis'    say(c) {"There <<isAreFor(c.dobj)>> <<aName(c.dobj)>> here"; return nil; };

/* Putting things places */
enPutOnOk:        Message id ='puton.ok'        text ='{You/he} {put} {the dobj} on {the iobj}. ';
enPutInOk:        Message id ='putin.ok'        text ='{You/he} {put} {the dobj} in {the iobj}. ';
enPutBehindOk:    Message id ='putbehind.ok'    text ='{You/he} {put} {the dobj} behind {the iobj}. ';
enPutOnCannot:    Message id ='puton.cannot'    text ='{You/he} {can}not put anything on {the dobj}. ';
enPutInCannot:    Message id ='putin.cannot'    say(c) {"<<TheName(c.dobj)>> will not hold anything. "; return nil; };
enPutBehindNo:    Message id ='putbehind.cannot' text ='{You/he} {can}not put anything behind {the dobj}. ';
enPutInShut:      Message id ='putin.shut'      say(c) {"<<TheName(c.dobj)>> is closed. "; return nil; };
enPutOnNoRoom:    Message id ='puton.noroom'    say(c) {"There is no room on <<theName(c.dobj)>> for that. "; return nil; };
enPutInNoRoom:    Message id ='putin.noroom'    say(c) {"There is no room in <<theName(c.dobj)>> for that. "; return nil; };
enPutWontMove:    Message id ='put.wontmove'    say(c) {"<<TheName(c.dobj)>> will not move. "; return nil; };
enPutInItself:    Message id ='put.initself'    text ='That would be a neat trick. ';

/* Travel */
enGoBarred:       Message id ='go.barred'       text ='{You/he} {can}not get past {the dobj}. ';
enRideWontGo:     Message id ='ride.wontgo'     say(c) {"<<TheName(c.dobj)>> will not go that way. "; return nil; };

/* Riding and entering */
enBoardOk:        Message id ='board.ok'        text ='{You/he} {get} into {the dobj}. ';
enBoardCannot:    Message id ='board.cannot'    say(c) {"<<TheName(c.dobj)>> is not something you can ride. "; return nil; };
enBoardAlready:   Message id ='board.already'   text ='{You/he} {is} already in {the dobj}. ';
enEnterCannot:    Message id ='enter.cannot'    text ='That is not something you can get into. ';
enGetOffNothing:  Message id ='getoff.nothing'  text ='You are not on anything. ';
enGetOffOff:      Message id ='getoff.off'      text ='{You/he} {get} off {the dobj}. ';
enGetOffOutOf:    Message id ='getoff.outof'    text ='{You/he} {get} out of {the dobj}. ';

/* Pushing */
enPushOk:         Message id ='push.ok'         text ='{You/he} {push} {the dobj} ahead of {you/him}. ';
enPushCannot:     Message id ='push.cannot'     text ='{You/he} {can}not push {the dobj} around. ';
enPushThrough:    Message id ='push.throughconnector' text ='{You/he} {can}not push {the dobj} through {the iobj}. ';

/* Looking under and behind */
enUnderNothing:   Message id ='lookunder.nothing'  say(c) {"There is nothing under <<theName(c.dobj)>>. "; return nil; };
enBehindNothing:  Message id ='lookbehind.nothing' say(c) {"There is nothing behind <<theName(c.dobj)>>. "; return nil; };

/* Gadgets */
enFlipOn:         Message id ='flip.on'         text ='{You/he} {flip} {the dobj} on. ';
enFlipOff:        Message id ='flip.off'        text ='{You/he} {flip} {the dobj} off. ';
enFlipCannot:     Message id ='flip.cannot'     say(c) {"<<TheName(c.dobj)>> is not something you can flip. "; return nil; };
enPullUp:         Message id ='pull.up'         text ='{You/he} {pull} {the dobj} up. ';
enPullDown:       Message id ='pull.down'       text ='{You/he} {pull} {the dobj} down. ';
enPressOk:        Message id ='press.ok'        text ='Click. ';
enPressNothing:   Message id ='press.nothing'   say(c) {"Pressing <<theName(c.dobj)>> achieves nothing. "; return nil; };
enTurnNothing:    Message id ='turn.nothing'    say(c) {"Turning <<theName(c.dobj)>> achieves nothing. "; return nil; };
enSetCannot:      Message id ='set.cannot'      text ='{You/he} {can}not set {the dobj} to anything. ';
enSetBadValue:    Message id ='set.badvalue'    say(c) {"<<TheName(c.dobj)>> will not go to that. "; return nil; };

/* Attachment */
enAttachOk:       Message id ='attach.ok'       text ='{You/he} {attach} {the dobj} to {the iobj}. ';
enAttachCannot:   Message id ='attach.cannot'   text ='Those will not go together. ';
enAttachWrong:    Message id ='attach.wrongpair' say(c) {"<<TheName(c.dobj)>> will not join to <<theName(c.iobj)>>. "; return nil; };
enAttachAlready:  Message id ='attach.already'  text ='They are joined already. ';
enDetachOk:       Message id ='detach.ok'       text ='{You/he} {detach} {the dobj} from {the iobj}. ';
enDetachNot:      Message id ='detach.notjoined' text ='They are not joined. ';

/* Senses */
enListenNothing:  Message id ='listen.nothing'  text ='You hear nothing out of the ordinary.';
enSmellNothing:   Message id ='smell.nothing'   text ='You smell nothing out of the ordinary.';

/* Actors */
enTalkNotActor:   Message id ='talk.notactor'   say(c) {"<<TheName(c.dobj)>> says nothing. "; return nil; };
enTalkNoTopic:    Message id ='talk.notopic'    say(c) {"<<TheName(c.dobj)>> has nothing to say about that. "; return nil; };

/* Score */

/* Said when an action needs an object the player did not name. */
enVagueTopic:     Message id ='talk.vaguetopic' text ='You will have to be more specific. ';

/* ------------------------------------------- sentences, not fragments */

enRoomAndClosed:  Message id ='room.andclosed'  text =', closed';
enRoomAndHolding: Message id ='room.andholding' say(c) {", with <<aName(c.list_[1])>> <<prepFor(c.dobj.objPos)>> it"; return nil; };
enRoomEndOfItem:  Message id ='room.endofitem'  text ='. ';

enExamineOnIt:    Message id ='examine.onit'    say(c) {"On it you see <<nameList(c.list_)>>. "; return nil; };
enExamineInIt:    Message id ='examine.init'    say(c) {"In it you see <<nameList(c.list_)>>. "; return nil; };

enSetOk:          Message id ='set.ok'          text ='{You/he} {set} {the dobj} to {way}. ';

enUnderFound:     Message id ='lookunder.found'  say(c) {"Under <<theName(c.dobj)>> you find <<nameList(c.list_)>>. "; return nil; };
enBehindFound:    Message id ='lookbehind.found' say(c) {"Behind <<theName(c.dobj)>> you find <<nameList(c.list_)>>. "; return nil; };

enInventoryItem:  Message id ='inventory.item'     say(c) {"<<aName(c.dobj)>>"; return nil; };
enInventoryWorn:  Message id ='inventory.itemworn' say(c) {"<<aName(c.dobj)>> (being worn)"; return nil; };

enActNoVerb:      Message id ='act.noverb'    say(c) {"[no verb <<c.way_>>]"; return nil; };
enActOutOfReach:  Message id ='act.outofreach' say(c) {"<<TheName(c.dobj)>> is not within reach. "; return nil; };

enRoomEnter:      Message id ='room.enter'     text ='';
enRoomName:       Message id ='room.name'      say(c) {"<<c.dobj.name>>"; return nil; };

enTakeSeveral:    Message id ='take.ok.several'  say(c) {"Taken: <<nameList(c.list_)>>. "; return nil; };
enDropSeveral:    Message id ='drop.ok.several'  say(c) {"Dropped: <<nameList(c.list_)>>. "; return nil; };
enOpenSeveral:    Message id ='open.ok.several'  say(c) {"<<language.expand('{You/he} {open} ', c)>><<nameList(c.list_)>>. "; return nil; };
enCloseSeveral:   Message id ='close.ok.several' say(c) {"<<language.expand('{You/he} {close} ', c)>><<nameList(c.list_)>>. "; return nil; };

enEatOk:          Message id ='eat.ok'        text ='{You/he} {eat[s]|ate} {the dobj}. ';
enEatCannot:      Message id ='eat.cannot'    text ='{The dobj} {is} not something you can eat. ';
enDrinkOk:        Message id ='drink.ok'      text ='{You/he} {drink[s]|drank} {the dobj}. ';
enDrinkCannot:    Message id ='drink.cannot'  text ='{The dobj} {is} not something you can drink. ';
enPourOk:         Message id ='pour.ok'       text ='{You/he} {pour} the {way} into {the iobj}. ';
enPourNothing:    Message id ='pour.nothing'  text ='Nothing {will} pour out of {the dobj}. ';
enPourWontTake:   Message id ='pour.wontake'  text ='You {cannot|could not} pour anything into {the dobj}. ';

/* Handing something over, and holding it up. */
enGiveNotActor:   Message id ='give.notactor'   text ='{The dobj} {is} not going to take it. ';
enGiveRefused:    Message id ='give.refused'
    say(c) {"<<TheName(c.dobj)>> does not want <<theName(c.iobj)>>. "; return nil; };
enShowNothing:    Message id ='show.nothing'
    say(c) {"<<TheName(c.dobj)>> looks at <<theName(c.iobj)>> and says nothing. "; return nil; };

enGoTooBulky:     Message id ='go.toobulky'
    text ='{You/he} will not fit through {the dobj} carrying all that. ';

enOpenLocked:     Message id ='open.locked'      text ='{The dobj} {is} locked. ';
enUnlockOk:       Message id ='unlock.ok'
    text ='{You/he} {unlock} {the dobj} with {the iobj}. ';
enLockOk:         Message id ='lock.ok'
    text ='{You/he} {lock} {the dobj} with {the iobj}. ';
enUnlockAlready:  Message id ='unlock.already'   text ='{The dobj} {is} not locked. ';
enLockAlready:    Message id ='lock.already'     text ='{The dobj} {is} already locked. ';
enLockCannot:     Message id ='lock.cannot'      text ='{The dobj} {has} no lock. ';
enUnlockWrong:    Message id ='unlock.wrongkey'
    say(c)
    {
        if (c.iobj == nil)
"<<language.expand('{You/he} {do} not have the key for ', c)>><<theName(c.dobj)>>. ";
        else
"<<TheName(c.iobj)>> does not fit <<theName(c.dobj)>>. ";
        return nil;
    };

/* Picking yourself up. */
enTakeSelf:       Message id ='take.self'     text ='You are already carrying yourself around. ';

/* Letting a turn pass. */
enWaitOk:         Message id ='wait.ok'       text ='Time passes. ';

enReachTooFar:    Message id ='reach.toofar'  say(c) {"<<TheName(c.dobj)>> is too far away. "; return nil; };

dirName(way)
{
    if (way == north) return'north';
    if (way == south) return'south';
    if (way == east) return'east';
    if (way == west) return'west';
    if (way == northeast) return'northeast';
    if (way == northwest) return'northwest';
    if (way == southeast) return'southeast';
    if (way == southwest) return'southwest';
    if (way == up) return'up';
    if (way == down) return'down';
    if (way == inward) return'in';
    return'out';
}

enRoomActorHere:  Message id ='room.actorhere'  say(c) {"<<AName(c.dobj)>> is here. "; return nil; };
enTravelLeaves:   Message id ='travel.leaves'   say(c) {"<<TheName(c.dobj)>> leaves. "; return nil; };
enTravelLeavesWay: Message id ='travel.leavesway' say(c) {"<<TheName(c.dobj)>> leaves to the <<dirName(c.way_)>>. "; return nil; };
enTravelArrives:  Message id ='travel.arrives'  say(c) {"<<TheName(c.dobj)>> arrives. "; return nil; };
enTravelArrivesWay: Message id ='travel.arrivesway' say(c) {"<<TheName(c.dobj)>> arrives from the <<dirName(c.way_)>>. "; return nil; };
enTravelOpens:    Message id ='travel.opens'    say(c) {"<<TheName(c.dobj)>> opens <<theName(c.iobj)>>. "; return nil; };
enTravelComesWith: Message id ='travel.comeswith' say(c) {"<<TheName(c.dobj)>> comes with you. "; return nil; };
enTravelLeadsWay: Message id ='travel.leadsway'  say(c) {"<<TheName(c.dobj)>> leads the way. "; return nil; };

postureName(p)
{
    if (p == sitting) return'sitting';
    if (p == lying) return'lying down';
    return'standing';
}

enPostureStand:   Message id ='posture.stand'   say(c) {"<<c.dobj == player ? 'You stand up. ' : 'You stand on ' + theName(c.dobj) + '. '>>"; return nil; };
enPostureSit:     Message id ='posture.sit'     text ='{You/he} {sit} on {the dobj}. ';
enPostureLie:     Message id ='posture.lie'     text ='{You/he} {lie|lay} on {the dobj}. ';
enPostureAlready: Message id ='posture.already' text ='You are already standing. ';
enPostureNowhere: Message id ='posture.nowhere' text ='There is nothing here to do that on. ';
enPostureCannot:  Message id ='posture.cannot'  text ='{You/he} {can}not get on {the dobj}. ';
enPostureWont:    Message id ='posture.wontallow' text ='{You/he} {can}not do that on {the dobj}. ';
enReachTooHigh:   Message id ='reach.toohigh'   say(c) {"<<TheName(c.dobj)>> is out of reach from here. "; return nil; };
enEnterShut:      Message id ='enter.shut'     text ='{The dobj} {is} shut. ';
enEnterLocked:    Message id ='enter.locked'   text ='{The dobj} {is} locked. ';
enStageNotThere:  Message id ='stage.notthere'  text ='{You/he} would have to be on {the dobj} first. ';

enSayOk:          Message id ='say.ok'          say(c) {"Okay: <q><<c.way_>></q>"; return nil; };
enSayNothing:     Message id ='say.nothing'     text ='Say what? ';
enWriteOnCannot:  Message id ='writeon.cannot'  text ='There\'s no way to write anything on {the dobj}. ';
enThinkAbout:     Message id ='think.about'     text ='{You/he} {think} about {the dobj}, and {is} none the wiser. ';
enConsultCannot:  Message id ='consult.cannot'  text ='{You/he} {can}not look things up in {the dobj}. ';
enConsultNothing: Message id ='consult.nothing' text ='{You/he} {find} nothing about <q>{way}</q> in {the dobj}. ';

enOpenClosed: State
    appliesTo = Thing
    applies(it) { return it.isOpenable; }
    watches = &isOpen
    whenTrue ='open'
    whenFalse ='closed'
;

enDecoration:     Message id ='decoration.notimportant' text ='{The dobj} {is}n\'t important. ';
enImmovable:      Message id ='immovable.cannot' text ='{The dobj} {is} far too heavy to move. ';
enIntangible:     Message id ='intangible.cannot' text ='{The dobj} {is}n\'t something {you/he} can touch. ';
enUnthingGone:    Message id ='unthing.gone'    text ='{The dobj} {is}n\'t here. ';

/* One candidate in a disambiguation question, told apart when it has to be. */
enParseWhichOne: Message id ='parse.whichone'
    say(c) {", the <<c.way_ == nil ? '' : c.way_ + ' '>><<c.dobj.name>>"; return nil; }
;
enTalkHermit:     Message id ='talk.hermit'     say(c) {"<<TheName(c.dobj)>> is too busy to answer. "; return nil; };
enOrderRefused:   Message id ='order.refused'   say(c) {"<<TheName(c.dobj)>> has no intention of doing that. "; return nil; };

enPrecondFirst:   Message id ='precond.first'    say(c) {"(first <<c.way_>> <<theName(c.dobj)>>)"; return nil; };
enPrecondCannot:  Message id ='precond.cannot'   text ='{You/he} {can}not do that to {the dobj}. ';
enPrecondHeld:    Message id ='precond.held'     text ='{You/he} {is}n\'t holding {the dobj}. ';
enPrecondVisible: Message id ='precond.visible'  text ='{You/he} {can}not see {the dobj}. ';
enPrecondOpen:    Message id ='precond.open'     say(c) {"<<TheName(c.dobj)>> is closed. "; return nil; };
enPrecondClosed:  Message id ='precond.closed'   say(c) {"<<TheName(c.dobj)>> is open. "; return nil; };
enPrecondUnlocked: Message id ='precond.unlocked' say(c) {"<<TheName(c.dobj)>> is locked. "; return nil; };
enPrecondWorn:    Message id ='precond.worn'     say(c) {"You're wearing <<theName(c.dobj)>>. "; return nil; };
enPrecondEmpty:   Message id ='precond.empty'    say(c) {"There's something in <<theName(c.dobj)>>. "; return nil; };
enPrecondReach:   Message id ='precond.reach'    text ='{You/he} {can}not reach {the dobj} through what it\'s in. ';
/* Text, not a body: `refuses` reads it rather than saying it. */
enTakePart:       Message id ='take.part'     text ='{The dobj} {is} part of {the iobj}. ';
enDetachPart:     Message id ='detach.part'   text ='{You/he} {detach} {the dobj}. ';
enDetachFixed:    Message id ='detach.fixed'  say(c) {"<<TheName(c.dobj)>> will not come off. "; return nil; };

/* Score. `c.way_` carries the number. */
enScoreIsWhole:   Message id ='score.is'       say(c) {"Your score is <<c.way_>>. "; return nil; };
enScoreGained:    Message id ='score.gained'   say(c) {"[Your score has just gone up by <<c.way_>> points.]"; return nil; };
enScoreGained1:   Message id ='score.gained1'  text ='[Your score has just gone up by 1 point.]';

/* Optional dialogue module's ordinary exit label. */
enDialogueGoodbye: Message id ='dialogue.goodbye' text ='Say goodbye';

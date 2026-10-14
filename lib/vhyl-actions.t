/* Optional observational action previews. Include after vhyl.t.
 * Copyright (c) 2026 John Cunningham. MIT License; see LICENSE. */

/** @api author
 * Player-safe disclosure supplied by an audited observational author hook.
 * Hidden by default. Never copy secret verification ranks or reasons here. */
class ActionAffordance: object
    /** @api author
     * Opt in to displaying this candidate. */
    visible = nil
    /** @api author
     * Whether attempting this option is player-safe and reasonable. */
    enabled = true
    /** @api author
     * Localizable player-visible label ID; required for visible candidates. */
    labelId = nil
    /** @api author
     * Optional player-safe explanation ID. */
    reasonId = nil
    /** @api author
     * Zero to two player-safe entities for the explanation. */
    reasonArgs = []
    /** @api author
     * Authored default preference; never inferred from semantic ranking. */
    isDefault = nil
;

modify Action
    /** @api author
     * Return a player-safe ActionAffordance; nil hides this candidate.
     * Context contains both roles, including nil slots for incomplete requests. */
    affordance(c) { return nil; }
;

/** @api host
 * Temporary preview result. status is ok, unknown-verb, invalid or game-ended.
 * Missing roles describe syntax; enabled means reasonable to attempt, not success. */
class ActionPreview: object
    /** @api host
     * ok, invalid, unknown-verb or game-ended. */
    status = 'ok'
    /** @api host
     * Requested structured verb code. */
    verb = nil
    /** @api host
     * Supplied direct entity, or nil. */
    dobj = nil
    /** @api host
     * Supplied indirect entity, or nil. */
    iobj = nil
    /** @api host
     * Whether a required direct argument is missing. */
    missingDobj = nil
    /** @api host
     * Whether a required indirect argument is missing. */
    missingIobj = nil
    /** @api host
     * Whether the action accepts an optional indirect argument. */
    optionalIobj = nil
    /** @api host
     * Authored disclosure result, or nil to hide the candidate. */
    affordance = nil
;

/** @api host
 * Observe an authored affordance without verification, checks, implicit actions,
 * Doer dispatch, reports, scheduling or durable query bookkeeping.
 * subjects may omit required roles or use nil placeholders, e.g. [nil, target]. */
previewAction(verb, subjects)
{
    local result = new ActionPreview(); result.verb = verb;
    local v = verbFor(verb);
    if (v == nil || v.action == nil || actionUI.accepts(verb) || dialogueUI.accepts(verb))
    {
        result.status = 'unknown-verb'; return result;
    }
    local a = v.action;
    if (!validActionSubjects(a, subjects))
    {
        result.status = 'invalid'; return result;
    }
    if (gameOver.done) { result.status = 'game-ended'; return result; }
    local c = new Command(); c.action = a; c.dir_ = v.dir;
    local n = subjects == nil ? 0 : subjects.length();
    c.dobj = n > 0 ? subjects[1] : nil;
    c.iobj = n > 1 ? subjects[2] : nil;
    result.dobj = c.dobj; result.iobj = c.iobj;
    result.missingDobj = a.needsDobj && c.dobj == nil;
    result.missingIobj = a.needsIobj && c.iobj == nil;
    result.optionalIobj = a.optionalIobj;
    /* Scope, knowledge and disclosure are author policy. Even a topic need not
     * be physically present. No hidden-state-derived library filter runs here. */
    result.affordance = a.affordance(new ActionContext(c, nil));
    return result;
}

/** @api host
 * Emit one bounded action.preview v1 event; hidden results carry no authored data. */
publishActionPreview(verb, subjects)
{
    local r = previewAction(verb, subjects);
    local f = r.affordance;
    local shown = r.status == 'ok' && f != nil && f.visible;
    if (shown && (dataType(f.labelId) != TypeSString || f.labelId == ''
        || dataType(f.reasonArgs) != TypeList || f.reasonArgs.length() > 2))
        throw new ActionPreviewError();
    event('action.preview');
    eventValue(1); eventValue(verb); eventValue(r.status);
    eventValue(r.dobj); eventValue(r.iobj);
    eventValue(r.missingDobj); eventValue(r.missingIobj); eventValue(r.optionalIobj);
    eventValue(shown);
    eventValue(shown ? f.enabled : nil);
    eventValue(shown ? f.labelId : nil);
    eventValue(shown ? f.reasonId : nil);
    eventValue(shown ? f.isDefault : nil);
    local args = shown ? f.reasonArgs : [];
    eventValue(args.length());
    foreach (local value in args) eventValue(value);
    return nil;
}

class ActionPreviewError: object;

/* This transport verb is intercepted before any gameplay bookkeeping. */
vActionPreview: Verb code = 83 action = actionPreviewTransport label = 'preview-action';
actionPreviewTransport: Action;

modify actionUI
    accepts(verb) { return verb == 83; }
    act(verb, args)
    {
        local n = args == nil ? 0 : args.length();
        if (n < 1 || n > 3 || dataType(args[1]) != TypeInt)
        {
            event('action.preview.invalid'); return nil;
        }
        local subjects = [];
        /* The example consumer has no nil literal; integer zero is a hole. */
        if (n > 1) subjects = subjects + [args[2] == 0 ? nil : args[2]];
        if (n > 2) subjects = subjects + [args[3] == 0 ? nil : args[3]];
        return publishActionPreview(args[1], subjects);
    }
;

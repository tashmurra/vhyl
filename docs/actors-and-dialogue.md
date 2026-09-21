# Actors and dialogue

`Actor` participates in the world and has a current `ActorState`. Actors can use agendas, accompany a stored leader, or guide another actor. Actor travel applies connector and follower policies; a group is bounded and invalid/oversized travel is refused. Author declaration order must not be used as a substitute for an explicit leader.

`Event` calls an owner's property after a number of turns. `Fuse` fires once; `Daemon` repeats. `AgendaItem` adds actor-oriented scheduling. Set `owner`, `prop`, `turnsLeft`, `interval` and `isActive` as appropriate; the library updates scheduling state as commands complete.

`TopicEntry` provides ask/tell dialogue. Set its actor, matched topic, optional state and message ID. It can be active or once-only. `TopicDialogueChoice` is an explicit adapter when a topic should also appear in a choice-driven conversation.

## Choice-driven conversations

Include `vhyl-dialogue.t`. A `Conversation` has a stable nonempty ID, target, authored choices and optional opening/closing callbacks. A `DialogueChoice` has an ID, label message ID and `selected(context)` handler. The [dialogue example](../examples/dialogue/main.t) is a complete small program.

Choices may require a subject or fact tags in the asker's knowledge. `available(context)` adds an observational condition. `once` records consumption for the asker/choice pair. A selection does not automatically teach a fact: the handler explicitly records knowledge. Do not mutate state or emit output while computing availability or labels.

One conversation is active per session. Accepted opening/selection advances the normal world cycle. Refresh and refused selections do not create a history interval or advance time. The host supplies conversation ID, snapshot token and choice ID; stale tokens and unavailable choices are refused. Refresh after undo, restore or rollback rather than reusing an old token.

`InternalSpeaker` binds to a character through `voiceOwner`. Private choices/lines require that owner to be the asker. Internal voices are not physical actors. A conversation may contain private interjections without opening another session.

Snapshots are limited to 64 choices and the transport's bounded payload. Duplicate IDs and oversized snapshots fail rather than truncating. Transcripts and transport tokens are presentation state, not saved world data. The regression suite covers knowledge, per-asker consumption, stale input, private voices, rollback, limits and cross-process restore.

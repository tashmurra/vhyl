# API reference

This is the supported authoring surface used by the bundled examples and tests. Internal scratch objects and underscore-suffixed fields are not stable extension APIs. This experimental release does not promise compatibility with every TADS or adv3Lite class/property.

| Surface | Author sets or overrides | Library maintains |
| --- | --- | --- |
| `gameMain` | `initialRoom`, `intro`, `usePastTense` | Startup dispatch |
| `Thing` | `name`, `desc`, `vocab`, flags, bulk/capacity, `presentation` | Adventure interactions and discovery |
| `Room` | Description and exit relation rows | Room description and scope policy |
| `Container` / `Door` | Open/locked properties and initial relation rows | State changes from actions |
| `Thing.rank(action, role)` | Candidate rank | Candidate resolution |
| `Thing.refuses(action, command)` | Nil or refusal text | Refusal dispatch |
| `Action` | Argument requirements, `rank`, `preCond`, `exec`, `report` | Resolved command flow |
| `Verb` | Unique `code`, `action`, optional direction and label | Code lookup |
| `Message` | Stable `id`, priority/activity, `text` or `say` | Active message selection |
| `Actor` / `ActorState` | Initial state and behaviour hooks | Current state and turn scheduling |
| `AccompanyingState` | `actor`, `accompanyingActor` | Coordinated travel |
| `TopicEntry` | `actor`, `matchObj`, `inState`, `id`/`reply`, `once` | `used` after an accepted exchange |
| `Event` / `Fuse` / `Daemon` | `owner`, `prop`, interval/activity and initial delay | Remaining delay and dispatch |
| `Conversation` | `id`, `target`, `choices`, availability and opening/closing hooks | Active conversation relation |
| `DialogueChoice` | `id`, `labelId`, knowledge requirements, `once`, availability and selection hook | Per-asker consumption |
| `InternalSpeaker` | `voiceOwner` relation | Eligibility for the bound asker |

Call `vhylStart()` once at startup. Delegate text turns to `vhylTurn(tokens)` and structured actions to `vhylAct(code, arguments)`. Use `here()` for the player's current room. Use relations to change placement and `setKnowsAbout`/`forget` for explicit knowledge changes.

Read the [actions guide](../actions.md) before overriding hooks and the [dialogue guide](../actors-and-dialogue.md) before interpreting conversation events. Conditions used while observing or presenting the world must not mutate it.

Machine-readable interfaces: [messages](messages.json) and [verbs](verbs.json). Regenerate these with `python3 tools/export_surface.py`; CI checks they match the library. Application declarations belong in application catalogues.

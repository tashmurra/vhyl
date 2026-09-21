# World model

A vhyl world consists of entities and relations. `contains(container, item)` has inverse access through `location`; `exits(from, to, direction)` describes travel; `connects(door, room)` gives one door multiple sides. `presentIn` supports entities present in several rooms. Vocabulary and knowledge have their own relations.

Write initial rows in declarations. At runtime use relation operations such as `contains.set(destination, item)`. Do not add a parallel writable location field: it would disagree with the relation that scope and travel read.

`Thing` provides adventure properties. `Room`, `Container`, `Door`, `Actor`, `Fixture`, `Wearable` and other specialised classes add policy. Entity identity and storage belong to Zebulon; visibility, reachability, bulk, containers, lighting and travel rules belong to vhyl.

The default player is the library's `player` object. `gameMain.initialRoom` chooses where play starts. `vhylStart()` initialises the world and describes that room. Hosts should identify entities through manifest/inspection data rather than relying on enumeration order.

World changes use Zebulon's journals. Undo and failed-turn rollback restore supported mutations; they do not promise complete reversal of entity creation and despawning. Logical saves must match the compiled program. Restoring state does not restore the previous undo history.

The library also schedules events, actors and vocabulary-state synchronisation. A `State` names vocabulary for a boolean condition; its vocabulary updates at command boundaries rather than on every property write. Keep conditions and observation hooks free of side effects.

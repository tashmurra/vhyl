# Host integration

A vhyl game is compiled together with the library through textual includes. There is no separately linked vhyl binary or package manager requirement. Zebulon supplies the generated header, manifest, runtime and consumer for each native bundle.

Use the bundle's manifest/header as the ABI authority. Entity declaration indexes and runtime handles are different; use inspection to obtain handles. Internal Rust types are not a public interface. Keep the game's libraries and consumer together according to the generated loader paths.

`vhylAct(code, subjects)` maps public verb codes to the same world rules used by parsed commands. The core [verb catalogue](api/verbs.json) gives built-in codes and entity counts. Application verbs may extend that surface. General scalar transport exists in Zebulon, but it does not automatically give every parser-only built-in a structured verb code.

The optional dialogue module reserves 80 (begin with a conversation ID), 81 (select with conversation ID, token and choice ID), and 82 (refresh). The example Python client reads structured events and sends typed action arguments to the generated consumer. It never decides knowledge eligibility or applies world mutations itself.

The optional `vhyl-actions.t` module reserves **83** for an observational preview. Supply the requested verb code as the first integer, followed by up to two entity arguments. A nil argument leaves a role open; integer zero is also accepted as a hole by this preview transport for compatibility with the example consumer. For example, `@83 i:41 h:HANDLE` previews unlock with an unspecified key, and `@83 i:58 i:0 h:HANDLE` previews giving an unspecified item to a target. Obtain handles through inspection; do not use declaration indexes. Call `vhylAct` directly from the game's `act` entry without unconditional post-command story mutations for preview requests.

Each valid preview envelope emits exactly one `action.preview` event, with these ordered scalar values:

| Position (zero-based) | Value |
| --- | --- |
| 0–2 | Schema version `1`, requested verb code, status string |
| 3–4 | Supplied direct and indirect entity, or nil |
| 5–7 | Missing required direct role, missing required indirect role, accepts optional indirect role |
| 8–12 | Visible, enabled, label message ID, safe reason message ID, authored default |
| 13 | Explanation argument count (0–2) |
| 14 onward | Explanation entities in message direct/indirect order |

Booleans use true/nil. Hidden results have nil fields 8–12 and zero explanation arguments. There is no verification rank, success prediction or message rendering in this response. Hosts localize the IDs and render entities using player-safe names. Validate the schema, lengths and scalar types; the runtime's normal bounded event transport applies. Malformed envelopes (missing/noninteger verb or more than two subjects) emit `action.preview.invalid`. Structurally invalid candidate arguments produce status `invalid`. Dialogue control codes and preview code 83 are not gameplay candidates.

Preview responses are advisory presentation data. Discard them on `world.resync` and refresh when gameplay changes. Always submit a selected action for fresh verification and checks; a preview is not an execution token. Keep structured execution, transcript echo and replay identities in the host's normal command queue. Bellwether's menu layout, notebook discovery rules and replay policy remain consumer responsibilities.

Ordinary structured gameplay actions now reject extra arguments or arguments that are not `Thing` entities (including `Topic` subclasses), instead of silently ignoring them. Lock/unlock accept one required entity and one optional key. The core verb catalogue retains `subjects` as the required count and adds `optional_subjects: 1` for those two codes. Topics remain exempt from physical scope for either role.

Drain output/events according to the generated consumer protocol. Refresh host state when `world.resync` invalidates a view. Message IDs and semantic events can select presentation assets without parsing prose. Inspection reads published state; it does not evaluate arbitrary game methods.

The [example client](../examples/dialogue/host.py) validates event lengths, tags and scalar ranges and preserves exact 64-bit entity identities. It is a demonstration transport adapter, not a production UI/server. A production host must also define storage policy, cancellation, presentation and application resource limits.

Saving/restoring is owned by the runtime/host boundary. A rejected restore must not be treated as success. Library APIs do not bypass runtime lifetime, history or persistence limitations; consult the pinned compiler's embedding documentation.

With the pinned Zebulon v0.1.1 Linux runtime, a save requested after a recovered source exception can be rejected with code 11. This reproduces with the unchanged dialogue fixture as well as a throwing action check. Ordinary check denials return results and do not raise exceptions. The action tests verify exception rollback separately from successful save/restore; hosts must surface a rejected save and must not claim it was written.

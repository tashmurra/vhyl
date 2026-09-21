# Host integration

A vhyl game is compiled together with the library through textual includes. There is no separately linked vhyl binary or package manager requirement. Zebulon supplies the generated header, manifest, runtime and consumer for each native bundle.

Use the bundle's manifest/header as the ABI authority. Entity declaration indexes and runtime handles are different; use inspection to obtain handles. Internal Rust types are not a public interface. Keep the game's libraries and consumer together according to the generated loader paths.

`vhylAct(code, subjects)` maps public verb codes to the same world rules used by parsed commands. The core [verb catalogue](api/verbs.json) gives built-in codes and entity counts. Application verbs may extend that surface. General scalar transport exists in Zebulon, but it does not automatically give every parser-only built-in a structured verb code.

The optional dialogue module reserves 80 (begin with a conversation ID), 81 (select with conversation ID, token and choice ID), and 82 (refresh). The example Python client reads structured events and sends typed action arguments to the generated consumer. It never decides knowledge eligibility or applies world mutations itself.

Drain output/events according to the generated consumer protocol. Refresh host state when `world.resync` invalidates a view. Message IDs and semantic events can select presentation assets without parsing prose. Inspection reads published state; it does not evaluate arbitrary game methods.

The [example client](../examples/dialogue/host.py) validates event lengths, tags and scalar ranges and preserves exact 64-bit entity identities. It is a demonstration transport adapter, not a production UI/server. A production host must also define storage policy, cancellation, presentation and application resource limits.

Saving/restoring is owned by the runtime/host boundary. A rejected restore must not be treated as success. Library APIs do not bypass runtime lifetime, history or persistence limitations; consult the pinned compiler's embedding documentation.

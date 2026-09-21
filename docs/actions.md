# Actions

Text and structured commands reach the same action machinery. A host choosing an action does not bypass scope, reachability, preconditions or object refusals.

An `Action` describes requirements and provides `exec(command)` and `report(command)`. `needsDobj` and `needsIobj` declare entity arguments. The command carries resolved objects in `dobj` and `iobj` and the action in `action`.

Candidate ranking chooses among possible interpretations. `rank(item, role)` returns a verification rank; an object's `rank(action, role)` can also affect ranking. A poor rank is not itself a refusal. `preCond` hooks return required preconditions, which may perform implied actions. An object's `refuses(action, command)` returns nil to allow the action or explanatory text to stop it.

An action records successful work through `noteDone(command, item)`. Reports run for completed work, and helpers such as `accountDefault` select message IDs. Keep world mutation in action execution and presentation in reports/messages. A `Doer` can redirect or customise a resolved command without editing the core library.

To add a host-driven action, define an `Action` and a `Verb` with a unique code and an `action` reference. To expose text syntax, add a grammar rule that produces the appropriate command shape. Consult existing declarations in the core and test both successful and refused paths.

The text example checks an authored refusal on the reference weight. Putting the gauge into its closed case exercises implied opening. Tests also cover travel policy, rollback and report/event behaviour.

Built-in codes are listed in [verbs.json](api/verbs.json). Reserve application codes outside that list and the optional dialogue module's 80–82 range. Numeric codes and message IDs are integration interfaces: changing them requires an intentional compatibility change.

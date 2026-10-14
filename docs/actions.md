# Actions

Text and structured commands reach the same action machinery. A host choosing an action does not bypass scope, reachability, preconditions or object refusals.

An `Action` describes requirements and provides `exec(command)` and `report(command)`. `needsDobj` and `needsIobj` declare required entity arguments. `optionalIobj` accepts a second entity when supplied; unlock and lock use it for an explicit key. Both text and structured input preserve that key, including a wrong one. Omitting it retains the existing carried-key fallback. The command carries resolved objects in `dobj` and `iobj` and the action in `action`.

Candidate ranking chooses among possible interpretations. `rank(item, role)` returns a verification rank; an object's `rank(action, role)` can also affect ranking. A poor rank is not itself a refusal. `preCond` hooks return required preconditions, which may perform implied actions. An object's `refuses(action, command)` returns nil to allow the action or explanatory text to stop it.

An action records successful work through `noteDone(command, item)`. Reports run for completed work, and helpers such as `accountDefault` select message IDs. Keep world mutation in action execution and presentation in reports/messages. A `Doer` can redirect or customise a resolved command without editing the core library.

To add a host-driven action, define an `Action` and a `Verb` with a unique code and an `action` reference. To expose text syntax, add a grammar rule that produces the appropriate command shape. Consult existing declarations in the core and test both successful and refused paths.

The text example checks an authored refusal on the reference weight. Putting the gauge into its closed case exercises implied opening. Tests also cover travel policy, rollback and report/event behaviour.

Built-in codes are listed in [verbs.json](api/verbs.json). Reserve application codes outside that list and the optional modules' 80–83 range. Numeric codes and message IDs are integration interfaces: changing them requires an intentional compatibility change.

## Verification and execution checks

`Action.verify(context)` and `Thing.verify(context)` return a `VerificationResult` (nil means no additional restriction). The result separates `rank`, `allowed` and `implicitAllowed`. `reasonId` and `reasonArgs` explain a denial; arguments are zero to two entities in message direct/indirect order. `verificationFailure(id, direct, indirect)` constructs a denial. `rankedVerification(score)` preserves the legacy rule: every rank permits an explicit attempt, while ranks below `rankImplicit` decline implicit execution. Authors can override either permission independently of the rank.

`ActionContext` contains `actor` (the current player), `action`, `dobj`, `iobj`, `role`, `item` (the entity for that role), and `commandArgs` (the underlying command). Candidate ranking supplies only the role being ranked; hooks must tolerate a missing other argument. Execution verification sees both resolved roles. Action verification runs once for each supplied role, or once with a nil role for a command without objects. Thing verification runs for each supplied object. Ranks combine by minimum, permissions by conjunction, and the first explicit denial supplies the explanation. Denied candidates receive `rankNever` during parser ranking, but selecting a sole candidate still reaches the normal refusal path.

After a Doer chooses the effective action, the shared execution path runs verification, reach checks, preconditions, action and object `check(context)` hooks, legacy `refuses`, room hooks, actor hooks, execution and reporting. Checks return nil to allow or a denied `VerificationResult` to stop. The action check runs once with nil role, followed by direct and indirect object checks. Existing `refuses(action, command)` hooks still work and are never called by previews. Lock/key matching now lives in lock/unlock checks. Other existing built-ins may still refuse in `exec`; verification is not a promise of success.

Implicit commands must pass both permissions for both roles. Each nested implicit command has its own temporary command object. Preconditions can perform implicit actions, so an execution-time refusal can occur after an implied action has changed the world. Refused attempts reaching the action cycle retain the existing one-turn scheduling policy; previews do not enter that cycle.

`verifyAction(command)` exposes semantic verification to game code without preconditions or checks. Its results can contain puzzle secrets. Verification and ranking hooks must be observational: no output, mutations, knowledge changes or persistence. Zebulon v0.1.2 does not enforce that purity.

## Player-visible previews

Include `vhyl-actions.t` after `vhyl.t` to use `previewAction(code, subjects)` or its host transport, reserved code **83**. The [action example](../examples/actions/main.t) demonstrates an authored default, incomplete giving, and equally plausible keys.

`Action.affordance(context)` is the disclosure boundary. It returns nil or an `ActionAffordance`, hidden unless `visible` is true. Set `labelId`, `enabled`, optional `reasonId`/`reasonArgs`, and `isDefault`. These are author settings, not values inferred from verification ranks. `enabled` means reasonable to attempt; even an enabled option can fail when attempted. Never select the secretly correct key, expose an unknown action, or reveal an NPC's knowledge in this hook. The game decides scope, known topics, player-safe names, candidate enumeration and menu order. Core actions have no visible affordance by default.

`previewAction` returns a temporary `ActionPreview` with `status`, the supplied verb and objects, `missingDobj`, `missingIobj`, `optionalIobj` and `affordance`. Required arguments may be absent: `[item]` previews giving an item to someone; `[nil, target]` previews giving something to that target. An optional absent key is not a missing required argument. Status is `ok`, `invalid`, `unknown-verb` or `game-ended`. Hidden or disabled options never authorize execution: submit the chosen verb and entities to `vhylAct`, which evaluates current rules again.

Previews call only structural validation and the authored affordance hook. They do not call semantic verification, Doer hooks, preconditions, implicit actions, checks, refusals, reports, scenes, actors or events. `previewAction` emits nothing; `publishActionPreview` emits only the query response. No durable query cache or history interval is created by the library. Returned objects belong to the current Turn: do not save them in World properties. Hooks must only read game state and fill new temporary result objects. Purity is an author contract, not a runtime sandbox; the native regression suite checks state, knowledge, scheduling, hooks, gameplay events and undo depth across repeated previews and restore.

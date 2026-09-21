# Getting started

Include `vhyl.h` first, then `vhyl.t`, then `vhyl-en.t` if you want English prose. Include `vhyl-dialogue.t` after the core when using conversation choices. Add your own message declarations after the language module. Supply `lib` as a compiler include directory; no external TADS headers are needed.

The complete runnable text example is [main.t](../examples/text/main.t), with its world declarations in [world.h](../examples/text/world.h). A `Room` provides a location; `Thing` provides an entity with adventure properties. Declare initial placement as `location(room)` and travel as `exits(destination, north)`. These are relation rows, not ordinary property assignments.

Set `gameMain.initialRoom` in a `modify gameMain` declaration. Call `vhylStart()` from `startup()`. For text input, delegate `turn(tokens)` to `vhylTurn(tokens)`. For structured input, delegate `act(verb, subjects)` to `vhylAct(verb, subjects)`. A program can expose both.

Build the text example using the README commands. The generated consumer reads commands from standard input. End input to close it. Commands such as `undo` are library actions; `:save PATH` and `:restore PATH` are generated-consumer commands.

The [structured example](../examples/structured/main.t) has no text entry point:

```sh
mkdir -p build
zebc build examples/structured/main.t --include-dir lib --emit shared --out-dir build/structured
printf '!10\n!11\n' | ./build/structured/consumer
```

Codes 10 and 11 request north and south. The player visits the Platform and returns to the Station. Entity-taking actions additionally need handles obtained from the bundle's inspection interface, not declaration indexes guessed by the host.

The shell examples use a Unix shell. Compiler and consumer executables on Windows use their platform-specific names; the native test harness currently runs on macOS. Do not infer a tested platform from the portability of the library's source.

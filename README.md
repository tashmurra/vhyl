# vhyl

vhyl is an adventure library for [Zebulon](https://github.com/tashmurra/zebulon-lang). It supplies rooms, things, actions, actors, conversations and scheduling on Zebulon's entity/relation world model. Hosts can submit text commands or structured actions.

The library draws on TADS 3 and adv3Lite authoring concepts, but targets Zebulon; it is not a drop-in TADS library. It is experimental, and its API may change.

## Requirements

- A `zebc` compiler built from the revision recorded in [compiler.json](compiler.json).
- Python 3.10+ for the test runner and example host.
- For native programs, the prerequisites documented by that compiler release. The library contains no compiler or runtime binaries.

Use an installed compiler or build the pinned revision from a separate Zebulon checkout. Set `ZEBC` for the test runner if the executable is not on `PATH`. Native tool settings such as `ZEB_LLVM_CONFIG`, `ZEB_RUSTC` and `SDKROOT` are interpreted by Zebulon.

## First adventure

From this repository's root, with `zebc` on `PATH`:

```sh
zebc check examples/text/main.t --include-dir lib
mkdir -p build
zebc build examples/text/main.t --include-dir lib --emit shared --out-dir build/text
./build/text/consumer
```

Try `look`, `take gauge`, `put gauge in case`, `take weight`, `ask attendant about route`, `north` and `undo`. The example demonstrates containment, implied opening, an authored refusal, topic dialogue and travel. Each build needs a new output directory.

See [Getting started](docs/getting-started.md) for the include order and entry points. The [documentation index](docs/README.md) links the authoring guides and API reference.

For a local searchable programmer reference, install `requirements-docs.txt` and run `python3 tools/build_docs.py`; open `build/site/index.html`.

## Hosts and conversations

`examples/structured/main.t` exposes only structured actions. `examples/dialogue/main.t` exposes a small choice-driven conversation with a Python host:

```sh
mkdir -p build
zebc build examples/dialogue/main.t --include-dir lib --emit shared --out-dir build/dialogue
python3 examples/dialogue/host.py build/dialogue
```

The host prints the available choices and the archivist's answer. It uses the generated consumer's public transport; it does not import Rust internals.

## Checks

```sh
python3 tools/test.py
python3 tools/export_surface.py --check
python3 tools/check_repository.py
```

Select a compiler with `python3 tools/test.py --zebc /path/to/zebc`, or `ZEBC`. An invalid explicit setting fails rather than falling back. Source checking does not require LLVM.

On macOS (Intel or Apple Silicon), Linux x86-64 or Windows x86-64 with the pinned compiler's native prerequisites:

```sh
python3 tools/test.py --native
```

This runs real native behaviour checks and fails if prerequisites are missing. Use `--out build/checks` to retain bundles and logs in a new directory. Temporary output is removed on success and retained on failure otherwise.

Windows native checks require an x64 Visual Studio developer environment and Windows SDK; use `python` if `python3` is unavailable. Linux requires its host C/C++ development toolchain. All platforms require the pinned LLVM and Rust versions; macOS also needs its SDK and both Rust target libraries. See [Development](docs/development.md) for setup.

The Library checks workflow is manual-only: in GitHub Actions, select **Library checks → Run workflow**, then choose the branch or tag. It runs source and native behaviour checks on Linux x86-64, Windows x86-64 and macOS. macOS builds are universal; the Apple Silicon runner executes the ARM slice. Pushes, pull requests and releases do not start jobs automatically. Run checks for compiler-pin updates and before releases. Local native execution has been checked on Intel macOS; successful native CI runs are needed to establish execution coverage on the other runners.

## Licence

Copyright (c) 2026 John Cunningham. [MIT](LICENSE). See [provenance](docs/provenance.md). Compiler releases have their own prerequisites and platform-validation status.

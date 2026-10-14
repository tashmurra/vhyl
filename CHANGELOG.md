# Changelog

## 0.2.1

- Pin the compiler to Zebulon v0.1.2 for faster live-object enumeration, including object creation, destruction, Turn cleanup and restore. The compiler retains its save format.
- Native prerequisites remain Rust 1.98.1 and LLVM/LLD 22.1.8.
- No changes to vhyl library behaviour, authoring or host APIs, message IDs or verb codes.

## 0.2.0

- Add structured action verification and execution-only checks, preserving legacy ranking and `refuses` hooks.
- Add optional `vhyl-actions.t` with authored, observational affordances and preview transport code 83. Preview purity is an author contract, covered by native mutation/history regressions, not enforced by the compiler.
- Resolve optional keys for both text and structured lock/unlock commands. Explicit wrong keys are no longer ignored. Publish optional argument counts and reject surplus or malformed structured arguments.
- Keep nested implicit command state separate and honor verification permissions for both roles. Apply the topic scope exemption to structured direct topics too.
- Add an original action-preview example and native coverage for disclosure, execution parity, implicit actions, refusals, undo and restore. Existing verb codes and message IDs are retained; two generic refusal IDs are added. The compiler pin remains v0.1.1.

## 0.1.1

- Pin the compiler to Zebulon v0.1.1 for macOS linker discovery, full-LTO linking and universal-binary verification fixes.
- Document separate macOS LLVM/LLD installations and linker selection. Native prerequisites remain Rust 1.98.1 and LLVM/LLD 22.1.8.
- No changes to library behaviour, authoring or host APIs, message IDs or verb codes.

## 0.1.0

- Adventure entities, relations, actions, actor behaviour and scheduling.
- English messages and optional host-driven conversation choices.
- Original examples, public interface catalogues and regression tests.

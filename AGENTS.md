# Working on vhyl

- Read the README, development guide and relevant API guide before changing behaviour.
- Keep vhyl independent of compiler internals. Use the pinned compiler through its CLI.
- Preserve language behaviour, message IDs and verb codes unless a compatibility change is explicitly requested and documented.
- Keep author settings, maintained state and extension hooks clear in documentation.
- Keep fixtures original and independent of private stories, third-party exercises and network services.
- Use shared test helpers for compiler selection, temporary output and subprocess execution.
- Run source checks for every change and native checks for affected runtime behaviour. Missing prerequisites must not appear as successful coverage.
- Regenerate API catalogues after relevant library changes and check for unintended interface drift.
- Keep generated output, credentials, personal paths and planning/evidence archives out of Git.
- Do not push, publish or create external issues without authorization.

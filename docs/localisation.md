# Localisation

The optional `vhyl-en.t` module provides English message text and grammatical presentation. Core actions choose message IDs and entities; the language module turns those into prose. A host may omit the English module and use IDs to select its own text, audio or other presentation.

Declare `Message` objects for application lines, with stable `id` values and literal `text` or a computed `say(command)` implementation. Higher-priority active messages can replace a library message. Keep translated display text separate from verb codes, entity identities and conversation/choice IDs.

The generated [message catalogue](api/messages.json) describes the core/English defaults. Dynamic conversation labels and application messages are declared by their owning program; this catalogue is not a complete list of every event a world can emit.

**Parser limitation:** English command grammar remains in `vhyl.t`. Replacing `vhyl-en.t` changes presentation; it does not automatically translate the parser's command syntax or vocabulary. Structured-action hosts can use their own interface language without calling that parser.

Message parameter expansion is a supported subset, not a complete implementation of another library's localisation system. Test agreement, substitutions, missing keys and custom-message precedence with the actual compiled world.

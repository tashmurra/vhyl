"""Exercise declaration extraction and the generated reference's links."""

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("build_docs", ROOT / "tools" / "build_docs.py")
docs = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = docs
SPEC.loader.exec_module(docs)


class DocumentationTests(unittest.TestCase):
    def test_strings_comments_multiline_members_and_modification(self):
        source = """/** @api author\n * A sample class. */
class Sample: Thing
    /** @api author\n     * A value containing declaration punctuation. */
    value = '}; /* not a comment */'
    run(item)
    {
        local text = "x; }";
        return item;
    }
;
modify Sample
    extra = [1, 2]
;
relation paired(left: Entity, right: Entity) many_to_many;
grammar command(example): 'look' : Command;
"""
        declarations = docs.parse_source("sample.t", source)
        self.assertEqual([d.kind for d in declarations], ["class", "modify", "relation", "grammar"])
        merged = docs.merge_symbols(declarations)
        sample = merged[0]
        self.assertEqual(sample.audience, "author")
        self.assertEqual(sample.line, 3)
        self.assertEqual([(m.name, m.kind) for m in sample.members],
                         [("value", "property"), ("run", "method"), ("extra", "property")])
        self.assertEqual(sample.members[0].signature, "value = '}; /* not a comment */'")
        self.assertEqual(sample.members[0].description, "A value containing declaration punctuation.")
        self.assertEqual(sample.members[1].signature, "run(item)")
        self.assertEqual(merged[-1].name, "command(example)")

    def test_real_library_has_required_symbols_and_no_comment_leakage(self):
        symbols = docs.model()
        self.assertGreaterEqual(len(symbols), 700)
        by_name = {s.name: s for s in symbols if s.kind != "template"}
        self.assertEqual(by_name["Thing"].audience, "author")
        self.assertEqual(by_name["vhylAct"].audience, "host")
        self.assertEqual(by_name["Conversation"].parent, "object")
        self.assertIn("dialogueVoice", by_name)
        self.assertTrue(any(s.kind == "grammar" for s in symbols))
        self.assertEqual(next(m.signature for m in by_name["Thing"].members if m.name == "bulk"), "bulk = 1")

    def test_generated_pages_and_fragments_resolve(self):
        with tempfile.TemporaryDirectory(prefix="vhyl docs ") as name:
            stage = Path(name) / "docs"
            docs.render(docs.model(), stage)
            docs.check_links(stage)
            self.assertIn("Inherited members", (stage / "reference" / "Actor.md").read_text())
            self.assertTrue((stage / "reference" / "grammar.md").is_file())

    def test_missing_supported_description_and_anchor_fail(self):
        incomplete = docs.parse_source("sample.t", "/** @api author */\nclass Sample: object;\n")
        with self.assertRaisesRegex(ValueError, "lacks description"):
            docs.merge_symbols(incomplete)
        duplicate = [docs.Symbol("same", "relation", "sample.t", 1, "relation same;"),
                     docs.Symbol("same", "relation", "sample.t", 2, "relation same;")]
        with tempfile.TemporaryDirectory(prefix="vhyl duplicate docs ") as name:
            with self.assertRaisesRegex(ValueError, "duplicate relation anchor"):
                docs.render(duplicate, Path(name) / "docs")
        with tempfile.TemporaryDirectory(prefix="vhyl broken docs ") as name:
            page = Path(name) / "index.md"
            page.write_text("# Page\n\n[bad](index.md#missing)\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "missing anchor"):
                docs.check_links(Path(name))


if __name__ == "__main__":
    unittest.main()

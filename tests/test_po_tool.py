"""scripts/po-tool.py: pending entries of a catalogue and applying translations."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "po-tool.py"

PO = '''\
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"

msgid "Done"
msgstr "Hecho"

#, fuzzy, qt-format
#| msgid "Restart %1"
msgid "Restart now"
msgstr "Reiniciar %1"

msgctxt "Power"
msgid "Later"
msgstr ""

#, qt-format
msgid "%n update"
msgid_plural "%n updates"
msgstr[0] "%n actualización"
msgstr[1] "%n actualizaciones"

#, qt-format
msgid "%n file"
msgid_plural "%n files"
msgstr[0] "%n fichero"
msgstr[1] ""

#~ msgid "Old"
#~ msgstr ""
'''


class PoTool(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.po = Path(self.tmp.name) / "es.po"
        self.po.write_text(PO)

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), "--po", str(self.po), *args],
                              capture_output=True, text=True)

    def apply(self, mapping):
        path = Path(self.tmp.name) / "map.json"
        path.write_text(json.dumps(mapping))
        return self.run_tool("set", str(path))

    def test_status_lists_pending(self):
        out = self.run_tool("status")
        self.assertEqual(out.returncode, 1)
        self.assertIn("UNTRANSLATED  Later", out.stdout)
        self.assertIn("UNTRANSLATED  %n file", out.stdout)  # a plural with an empty form
        self.assertIn("FUZZY         Restart now", out.stdout)
        self.assertNotIn("%n update", out.stdout)  # a complete plural
        self.assertNotIn("Old", out.stdout)  # obsolete
        self.assertIn("-- untranslated: 2  fuzzy: 1", out.stdout)

    def test_set_clears_fuzzy_and_keeps_flags(self):
        out = self.apply({"Restart now": "Reiniciar ahora", "Later": 'Más "tarde"'})
        self.assertEqual(out.returncode, 0, out.stdout)
        text = self.po.read_text()
        self.assertIn('#, qt-format\nmsgid "Restart now"\nmsgstr "Reiniciar ahora"', text)
        self.assertNotIn("#|", text)
        self.assertIn('msgctxt "Power"\nmsgid "Later"\nmsgstr "Más \\"tarde\\""', text)
        self.assertIn("-- untranslated: 1  fuzzy: 0", self.run_tool("status").stdout)

    def test_set_skips_plurals_and_reports_unknown(self):
        out = self.apply({"%n file": "x", "Nope": "no"})
        self.assertEqual(out.returncode, 1)
        self.assertIn("plural, edit it by hand", out.stdout)
        self.assertIn("not in the catalogue: Nope", out.stdout)
        self.assertIn('msgstr[1] ""', self.po.read_text())

    def test_same_translation_changes_nothing(self):
        self.apply({"Done": "Hecho"})
        self.assertEqual(self.po.read_text(), PO)

    def test_complete_catalogue(self):
        self.po.write_text('msgid ""\nmsgstr ""\n\nmsgid "Done"\nmsgstr "Hecho"\n')
        out = self.run_tool("status")
        self.assertEqual(out.returncode, 0)
        self.assertIn("-- untranslated: 0  fuzzy: 0", out.stdout)


if __name__ == "__main__":
    unittest.main()

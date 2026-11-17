"""Runs the QML tests of the display arrangement geometry (tests/qml) with qmltestrunner, offscreen."""
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"


@unittest.skipUnless(os.path.exists(RUNNER), "qmltestrunner (qt6-declarative) is not installed")
class DisplayLayout(unittest.TestCase):
    def test_qml_tests_pass(self):
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        r = subprocess.run([RUNNER, "-input", str(ROOT / "tests" / "qml")], env=env, capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stdout[-3000:] + r.stderr[-1000:])


if __name__ == "__main__":
    unittest.main()

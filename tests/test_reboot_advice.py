"""scripts/reboot-advice.py: when a restart is recommended after an update."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "reboot-advice.py"
RELEASE = os.uname().release

LOG = """\
[2026-11-19T10:00:00+0100] [ALPM] upgraded linux (7.3.4-arch1-2 -> 7.3.5-arch1-1)
[2026-11-20T09:00:00+0100] [ALPM] upgraded firefox (140.0-1 -> 141.0-1)
[2026-11-20T09:00:01+0100] [ALPM] upgraded mesa (1:26.0-1 -> 1:26.1-1)
[2026-11-20T09:00:02+0100] [ALPM] upgraded linux-headers (7.3.4-arch1-2 -> 7.3.5-arch1-1)
[2026-11-20T09:00:03+0100] [ALPM] installed amd-ucode (20261101-1)
[2026-11-20T09:00:04+0100] [ALPM] warning: something about systemd
"""
SINCE = "1795158000"  # 2026-11-20T08:00:00+01:00


class RebootAdvice(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        (root / "pacman.log").write_text(LOG)
        self.modules = root / "modules"
        (self.modules / RELEASE).mkdir(parents=True)
        self.env = {**os.environ, "XDG_STATE_HOME": str(root / "state"),
                    "SYLENARA_PACMAN_LOG": str(root / "pacman.log"), "SYLENARA_MODULES_DIR": str(self.modules)}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args):
        out = subprocess.run([sys.executable, str(SCRIPT), *args], env=self.env, capture_output=True, text=True,
                             check=True)
        return json.loads(out.stdout)

    def test_nothing_to_do(self):
        self.assertEqual(self.run_script("check"), {"kernel": False, "packages": [], "recommended": False})

    def test_kernel_replaced(self):
        (self.modules / RELEASE).rmdir()
        self.assertTrue(self.run_script("check")["kernel"])
        self.assertTrue(self.run_script("check")["recommended"])

    def test_record_only_system_pieces_since_the_update(self):
        data = self.run_script("record", "--since", SINCE)
        # linux is from the day before; firefox and linux-headers do not need a restart; the warning is no update
        self.assertEqual(data["packages"], ["mesa", "amd-ucode"])
        self.assertTrue(data["recommended"])

    def test_remembered_until_the_next_boot(self):
        self.run_script("record", "--since", SINCE)
        self.assertEqual(self.run_script("check")["packages"], ["mesa", "amd-ucode"])
        state = Path(self.env["XDG_STATE_HOME"]) / "sylenara/reboot.json"
        data = json.loads(state.read_text())
        data["bootId"] = "an-earlier-boot"
        state.write_text(json.dumps(data))
        self.assertEqual(self.run_script("check")["packages"], [])


if __name__ == "__main__":
    unittest.main()

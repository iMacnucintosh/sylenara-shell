"""setup-defaults.py and setup-kitty.py in a sandboxed HOME: what they write, and what they never touch."""
import json
import unittest
from pathlib import Path

from helpers import run_script, tmpdir


def status(proc):
    return json.loads(proc.stdout)["status"]


class Defaults(unittest.TestCase):
    def test_fresh_home_gets_the_defaults_once(self):
        with tmpdir() as d:
            home = Path(d)
            self.assertEqual(status(run_script("setup-defaults.py", ["--check"], home)), "needed")
            self.assertFalse((home / ".config/lunele/shell.json").exists())  # --check writes nothing
            self.assertEqual(status(run_script("setup-defaults.py", [], home)), "done")
            cfg = json.loads((home / ".config/lunele/shell.json").read_text())
            acts = cfg["activities"]["activities"]
            self.assertEqual([a["id"] for a in acts], ["principal"])
            self.assertEqual(acts[0]["workspaceCount"], 2)
            self.assertTrue(Path(acts[0]["wallpaper"]).is_file())  # the wallpaper that ships with the shell
            self.assertNotIn("@", acts[0]["wallpaper"])
            self.assertEqual(status(run_script("setup-defaults.py", [], home)), "seen")

    def test_nothing_personal_in_the_template(self):
        text = (Path(__file__).resolve().parent.parent / "assets/defaults/shell.json").read_text()
        for word in ("/home/", "weatherLocation", "favouriteApps", "provider", "lastList"):
            self.assertNotIn(word, text)

    def test_never_replaces_an_existing_configuration(self):
        with tmpdir() as d:
            home = Path(d)
            cfg = home / ".config/lunele/shell.json"
            cfg.parent.mkdir(parents=True)
            cfg.write_text('{"bar": {"dragThreshold": 5}}')
            self.assertEqual(status(run_script("setup-defaults.py", [], home)), "kept")
            self.assertEqual(status(run_script("setup-defaults.py", ["--force"], home)), "kept")
            self.assertEqual(json.loads(cfg.read_text()), {"bar": {"dragThreshold": 5}})

    def test_an_empty_json_object_counts_as_no_configuration(self):
        with tmpdir() as d:
            home = Path(d)
            cfg = home / ".config/lunele/shell.json"
            cfg.parent.mkdir(parents=True)
            cfg.write_text("{}")
            self.assertEqual(status(run_script("setup-defaults.py", [], home)), "done")

    def test_a_file_that_is_not_json_is_left_alone(self):
        with tmpdir() as d:
            home = Path(d)
            cfg = home / ".config/lunele/shell.json"
            cfg.parent.mkdir(parents=True)
            cfg.write_text("{broken")
            self.assertEqual(status(run_script("setup-defaults.py", [], home)), "kept")
            self.assertEqual(cfg.read_text(), "{broken")


class Kitty(unittest.TestCase):
    BLOCK = "# >>> lunele"

    def test_connects_kitty_idempotently_and_keeps_the_user_content(self):
        with tmpdir() as d:
            home = Path(d)
            conf = home / ".config/kitty/kitty.conf"
            conf.parent.mkdir(parents=True)
            conf.write_text("font_size 12\n")
            self.assertEqual(status(run_script("setup-kitty.py", ["--check"], home)), "needed")
            self.assertEqual(status(run_script("setup-kitty.py", [], home)), "done")
            text = conf.read_text()
            self.assertIn("font_size 12", text)
            self.assertIn(self.BLOCK, text)
            self.assertEqual(text.count("allow_remote_control yes"), 1)
            self.assertEqual((conf.parent / "kitty.conf.lunele-backup").read_text(), "font_size 12\n")
            self.assertEqual(status(run_script("setup-kitty.py", [], home)), "seen")
            run_script("setup-kitty.py", ["--force"], home)
            self.assertEqual(conf.read_text().count("allow_remote_control yes"), 1)

    def test_respects_a_remote_control_setting_of_the_user(self):
        with tmpdir() as d:
            home = Path(d)
            conf = home / ".config/kitty/kitty.conf"
            conf.parent.mkdir(parents=True)
            conf.write_text("allow_remote_control no\n")
            run_script("setup-kitty.py", [], home)
            text = conf.read_text()
            self.assertIn("allow_remote_control no", text)
            self.assertNotIn("allow_remote_control yes", text)


if __name__ == "__main__":
    unittest.main()


class Player(unittest.TestCase):
    """setup-player.py: Veo opens videos, without overriding a player the user chose."""

    VEO = "[Desktop Entry]\nName=Veo\nType=Application\nExec=veo %f\nMimeType=video/mp4;video/matroska;\n"

    def install_veo(self, home: Path) -> None:
        apps = home / ".local/share/applications"
        apps.mkdir(parents=True, exist_ok=True)
        (apps / "veo.desktop").write_text(self.VEO)
        exe = home / ".local/bin/veo"
        exe.parent.mkdir(parents=True, exist_ok=True)
        exe.write_text("#!/bin/sh\n")
        exe.chmod(0o755)

    def test_without_veo_it_does_nothing(self):
        with tmpdir() as d:
            home = Path(d)
            self.assertEqual(status(run_script("setup-player.py", [], home)), "skipped")
            self.assertFalse((home / ".config/mimeapps.list").exists())

    def test_veo_opens_videos_once(self):
        with tmpdir() as d:
            home = Path(d)
            self.install_veo(home)
            cfg = home / ".config/lunele/shell.json"
            cfg.parent.mkdir(parents=True)
            cfg.write_text('{"general": {"apps": {"playback": []}}, "bar": {"x": 1}}')
            self.assertEqual(status(run_script("setup-player.py", ["--check"], home)), "needed")
            self.assertFalse((home / ".config/mimeapps.list").exists())  # --check writes nothing
            self.assertEqual(status(run_script("setup-player.py", [], home)), "done")
            mimeapps = (home / ".config/mimeapps.list").read_text()
            self.assertIn("[Default Applications]", mimeapps)
            self.assertIn("video/mp4=veo.desktop;", mimeapps)
            self.assertIn("video/matroska=veo.desktop;", mimeapps)
            data = json.loads(cfg.read_text())
            self.assertEqual(data["general"]["apps"]["playback"], ["veo"])
            self.assertEqual(data["bar"], {"x": 1})  # the rest of the configuration is kept
            self.assertEqual(status(run_script("setup-player.py", [], home)), "seen")

    def test_a_player_the_user_chose_is_kept(self):
        with tmpdir() as d:
            home = Path(d)
            self.install_veo(home)
            apps = home / ".local/share/applications"
            (apps / "other.desktop").write_text("[Desktop Entry]\nName=Other\nType=Application\nExec=other\n")
            mimeapps = home / ".config/mimeapps.list"
            mimeapps.parent.mkdir(parents=True)
            mimeapps.write_text("[Added Associations]\ntext/html=zen.desktop;\n\n[Default Applications]\n"
                                "video/mp4=other.desktop;\nvideo/matroska=gone.desktop;\n")
            out = json.loads(run_script("setup-player.py", [], home).stdout)
            self.assertEqual(out["status"], "done")
            text = mimeapps.read_text()
            self.assertIn("video/mp4=other.desktop;", text)          # installed and chosen: kept
            self.assertIn("video/matroska=veo.desktop;", text)       # chosen app is gone: Veo
            self.assertIn("text/html=zen.desktop;", text)            # other sections untouched
            self.assertEqual(text.count("video/matroska="), 1)
            self.assertTrue(any("video/mp4" in n for n in out["notes"]))

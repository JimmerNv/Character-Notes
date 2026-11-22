"""Run the real publisher with real jq and offline gh/curl substitutes."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CurseForgePublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "release.md"
        self.log = self.root / "upload.json"
        self.notes = self.root / "notes.md"
        self.archive = self.root / "addon.zip"
        self.archive.write_bytes(b"offline archive fixture")
        self.state.write_text("Existing GitHub release\n")
        self.env = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "CURSEFORGE_API_TOKEN": "mock-token-not-real",
            "CURSEFORGE_PROJECT_ID": "123456",
            "CURSEFORGE_GAME_VERSION_IDS": "[17053,17054]",
            "MOCK_STATE": str(self.state),
            "MOCK_UPLOAD": str(self.log),
        }
        for name, source in {
            "gh": '''
                import os, pathlib, sys
                args = sys.argv[1:]
                state = pathlib.Path(os.environ["MOCK_STATE"])
                if args[:2] == ["release", "view"]:
                    print(state.read_text(), end="")
                elif args[:2] == ["release", "edit"]:
                    state.write_text(pathlib.Path(args[args.index("--notes-file")+1]).read_text())
                else:
                    sys.exit(9)
            ''',
            "curl": '''
                import json, os, pathlib, sys
                args = sys.argv[1:]
                assert sys.stdin.read().strip() == "X-Api-Token: mock-token-not-real"
                metadata = json.loads(args[args.index("--form-string")+1].removeprefix("metadata="))
                pathlib.Path(os.environ["MOCK_UPLOAD"]).write_text(json.dumps({
                    "metadata": metadata,
                    "url": args[-1],
                    "archive": args[args.index("--form")+1],
                }))
                pathlib.Path(args[args.index("--output")+1]).write_text('{"id": 7654321}')
                print(os.environ.get("MOCK_HTTP", "200"), end="")
                sys.exit(int(os.environ.get("MOCK_CURL_EXIT", "0")))
            ''',
        }.items():
            stub = self.bin / name
            stub.write_text("#!" + sys.executable + "\n" + textwrap.dedent(source))
            stub.chmod(0o700)
        self.notes.write_text("# Release\n\n- Feature\n\n  - Full patch detail.\n")

    def publish(self, tag="v1.13.4"):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/publish_curseforge.sh"), tag,
             str(self.archive), str(self.notes), "Character Notes " + tag],
            env=self.env, text=True, capture_output=True,
        )

    def test_generated_full_commit_details_reach_metadata_unchanged(self):
        repo = self.root / "repo"
        repo.mkdir()
        def git(*args):
            subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)
        git("init", "-q")
        git("config", "user.email", "test@example.invalid")
        git("config", "user.name", "Release test")
        git("-c", "core.hooksPath=/dev/null", "commit", "-q", "--allow-empty", "-m", "feat: previous release")
        git("tag", "v1.10.0")
        body = "- Add ten builds.\n- Fix cursor selection.\n\nUnicode: äöü and `links`."
        git("-c", "core.hooksPath=/dev/null", "commit", "-q", "--allow-empty", "-m", "feat(notes): add guides\n\n" + body)
        git("tag", "v1.13.4")
        generated = subprocess.check_output(
            [sys.executable, str(ROOT / "scripts/generate_release_notes.py"),
             "--tag", "v1.13.4", "--product", "Character Notes"], cwd=repo, text=True,
        )
        self.notes.write_text(generated)
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        upload = json.loads(self.log.read_text())
        self.assertEqual(upload["metadata"]["changelog"], generated)
        self.assertIn("  - Fix cursor selection.", upload["metadata"]["changelog"])
        self.assertEqual(upload["metadata"]["changelogType"], "markdown")
        self.assertEqual(upload["metadata"]["gameVersions"], [17053, 17054])
        self.assertEqual(upload["url"], "https://wow.curseforge.com/api/projects/123456/upload-file")
        self.assertEqual(upload["archive"], "file=@" + str(self.archive) + ";type=application/zip")
        self.assertEqual(self.state.read_text(), generated + "\n<!-- curseforge-file-id:7654321 -->\n")
        self.assertNotIn("mock-token-not-real", result.stdout + result.stderr)

    def test_release_type_mapping(self):
        for tag, expected in (("v1.13.4", "release"), ("v1.13.4-alpha.1", "alpha"), ("v1.13.4-beta.1", "beta"), ("v1.13.4-rc.1", "beta")):
            with self.subTest(tag=tag):
                self.state.write_text("Existing release\n")
                result = self.publish(tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(self.log.read_text())["metadata"]["releaseType"], expected)

    def test_accepted_or_uncertain_upload_is_not_repeated(self):
        for marker, expected in (("<!-- curseforge-file-id:7654321 -->", 0), ("<!-- curseforge-upload-pending -->", 1)):
            with self.subTest(marker=marker):
                self.state.write_text(marker + "\n")
                self.assertEqual(self.publish().returncode, expected)
                self.assertFalse(self.log.exists())

    def test_missing_configuration_fails_without_upload(self):
        for name, invalid in (("CURSEFORGE_API_TOKEN", ""), ("CURSEFORGE_PROJECT_ID", "invalid"), ("CURSEFORGE_GAME_VERSION_IDS", "[]")):
            with self.subTest(name=name):
                original = self.env[name]
                self.env[name] = invalid
                result = self.publish()
                self.env[name] = original
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(name, result.stderr)
                self.assertFalse(self.log.exists())

    def test_rejection_clears_pending_marker_but_timeout_keeps_it(self):
        self.env["MOCK_HTTP"] = "401"
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.state.read_text(), self.notes.read_text())
        self.env["MOCK_CURL_EXIT"] = "28"
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertIn("<!-- curseforge-upload-pending -->", self.state.read_text())

    def test_workflow_preserves_existing_secret_and_variable_names(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn("CURSEFORGE_API_TOKEN: ${{ secrets.CURSEFORGE_API_TOKEN }}", workflow)
        for name in ("CURSEFORGE_PROJECT_ID", "CURSEFORGE_GAME_VERSION_IDS"):
            self.assertIn(name + ": ${{ vars." + name + " }}", workflow)
        self.assertIn("GH_TOKEN: ${{ github.token }}", workflow)


if __name__ == "__main__":
    unittest.main()

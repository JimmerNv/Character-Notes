"""Exercise release-note filtering against real, isolated Git histories."""

import pathlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts/generate_release_notes.py"


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = self.temp.name
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Release test")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True)

    def commit(self, message):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-q", "--allow-empty", "-m", message)

    def notes(self):
        self.git("tag", "v2.0.0")
        return subprocess.check_output(
            [sys.executable, str(SCRIPT), "--tag", "v2.0.0", "--product", "CharNotes"],
            cwd=self.root, text=True,
        )

    def test_only_public_types_since_previous_tag(self):
        self.commit("feat: old release feature")
        self.git("tag", "v1.0.0")
        for message in (
            "feat(notes): add shared guides", "fix(ui): restore selection",
            "perf: speed up search", "security: validate incoming guides",
            "revert: restore previous behavior", "feat(sync)!: change protocol",
            "docs: internal documentation", "test: internal tests",
            "ci: internal workflow", "chore: internal cleanup",
            "refactor: internal organization", "build: internal packaging",
            "style: internal formatting", "unclassified internal commit",
        ):
            self.commit(message)
        notes = self.notes()
        self.assertIn("notes: add shared guides", notes)
        self.assertIn("ui: restore selection", notes)
        self.assertIn("## Performance", notes)
        self.assertIn("## Security", notes)
        self.assertIn("## Reverts", notes)
        self.assertIn("BREAKING: sync: change protocol", notes)
        self.assertNotIn("internal", notes)
        self.assertNotIn("old release feature", notes)

    def test_first_release_includes_public_history(self):
        self.commit("feat: first public feature")
        self.commit("fix: first public fix")
        notes = self.notes()
        self.assertIn("first public feature", notes)
        self.assertIn("first public fix", notes)

    def test_full_multiline_body_is_preserved(self):
        self.commit("feat: previous release")
        self.git("tag", "v1.0.0")
        body = (
            "- Keep ten named builds.\n"
            "- Preserve item and spell links.\n\n"
            "More details: äöü, %s, tabs\there, and `code`.\n\n"
            "```lua\nprint('hello')\n```\n\n"
            "BREAKING CHANGE: Explicit migration instructions."
        )
        self.commit("feat(notes): add guides\n\n" + body)
        self.commit("ci: internal work\n\nINTERNAL BODY MUST STAY PRIVATE")
        self.commit("fix(ui): fix cursor\n\n- Keep selection stable.")
        notes = self.notes()
        for line in body.splitlines():
            if line:
                self.assertIn("  " + line, notes)
        self.assertIn("  - Keep selection stable.", notes)
        self.assertNotIn("INTERNAL BODY MUST STAY PRIVATE", notes)

    def test_subject_only_commit_does_not_consume_next_record(self):
        self.commit("feat: subject only")
        self.commit("fix: with details\n\n- Detail for the second commit.")
        notes = self.notes()
        self.assertIn("subject only", notes)
        self.assertIn("with details", notes)
        self.assertIn("  - Detail for the second commit.", notes)

    def test_release_without_public_changes_has_fallback(self):
        self.commit("feat: old feature")
        self.git("tag", "v1.0.0")
        self.commit("ci: update workflow")
        notes = self.notes()
        self.assertIn("No player-facing changes", notes)
        self.assertNotIn("## CI", notes)


if __name__ == "__main__":
    unittest.main()

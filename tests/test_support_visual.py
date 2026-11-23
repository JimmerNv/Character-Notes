"""Static regressions for addon branding, version, and support field sections."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "CharNotes"


class SupportVisualTests(unittest.TestCase):
    def test_version_is_consistent_and_visible_in_both_windows(self):
        toc = (ADDON / "ElvUI_CharNotes.toc").read_text(encoding="utf-8")
        core = (ADDON / "Core.lua").read_text(encoding="utf-8")
        main = (ADDON / "UI.lua").read_text(encoding="utf-8")
        support = (ADDON / "SupportUI.lua").read_text(encoding="utf-8")
        version = re.search(r"(?m)^## Version: (\d+\.\d+\.\d+)$", toc).group(1)
        self.assertIn(f"CN.VERSION = '{version}'", core)
        self.assertIn("'CharNotes  v' .. tostring(self.VERSION", main)
        self.assertIn("L.SUPPORT .. ' - v' .. tostring(CN.VERSION", support)

    def test_punk_is_only_a_player_marker_not_addon_branding(self):
        toc = (ADDON / "ElvUI_CharNotes.toc").read_text(encoding="utf-8")
        main = (ADDON / "UI.lua").read_text(encoding="utf-8")
        support = (ADDON / "SupportUI.lua").read_text(encoding="utf-8")
        self.assertIn("## Title: |cffff9855CharNotes|r", toc)
        self.assertNotIn("[PUNK]", next(line for line in main.splitlines() if "local title = label(w, 'CharNotes" in line))
        self.assertNotIn("[PUNK]", next(line for line in support.splitlines() if "text(w, 'CharNotes - '" in line))
        self.assertIn("entry.punk and ORANGE .. '[PUNK]", main)

    def test_support_sections_and_input_borders_are_present(self):
        support = (ADDON / "SupportUI.lua").read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"(?m)^        section\(w,", support)), 3)
        self.assertIn("local function section(parent, top, height, purpose)", support)
        self.assertIn("-- Thin borders keep dark editable fields visibly separate", support)
        self.assertIn("bg:SetVertexColor(.04, .05, .07, 1)", support)
        self.assertIn("local bg = parent:CreateTexture(nil, 'BACKGROUND')", support)
        self.assertIn("local marker = parent:CreateTexture(nil, 'BORDER')", support)
        self.assertNotIn("local panel = CreateFrame('Frame', nil, parent)", support)
        self.assertIn("if multiline then", support)
        self.assertIn("edit = CreateFrame('EditBox', nil, outer)", support)
        for label in ("SUPPORT_TITLE", "SUPPORT_DESCRIPTION", "SUPPORT_REPORT", "SUPPORT_LINK"):
            self.assertRegex(support, r"text\(w, L\." + label + r",\s*\d+,\s*-\d+\)")


if __name__ == "__main__":
    unittest.main()

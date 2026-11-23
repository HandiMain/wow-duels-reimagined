"""Approved Patch Notes vertical-rail layout and single-data-owner regression checks.

Static/geometry-only tests; they cannot certify an in-game pixel match.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def source(name):
    return (ROOT / "UI" / name).read_text(encoding="utf-8")

PAGE = source("PatchNotes.lua")
DATA = source("PatchNotesData.lua")
NAV = source("Navigation.lua")


def geometry(root_width, root_height, entries):
    usable = min(1190, max(1, root_width - 40))
    inset = max(20, (root_width - usable)/2)
    detail_width = usable - 194 - 16
    canvas_width = max(1, min(970, detail_width - 16))
    compact = canvas_width < 620
    # Body top y=-88; selected patch content scrolls separately.
    dense = root_height - 106 < 590
    if dense:
        notes_height = 221 + entries*65 + 5 + (220 if compact else 110) + 27
    else:
        notes_height = 258 + entries*80 + 12 + (248 if compact else 124) + 40
    return inset, usable, canvas_width, compact, notes_height


class PatchNotesLayoutTests(unittest.TestCase):
    def test_version_list_is_scrollable_and_from_the_data_owner(self):
        for item in (
            "for index, release in ipairs(releases) do",
            'local versionScroll = CreateFrame("ScrollFrame", nil, rail)',
            'local versionBar = Widgets.ScrollBar(versionScroll,',
            'versionScroll:SetScript("OnMouseWheel"',
            'ns.Navigation.SelectKey("patchnotes", release.key)',
            'button:SetScript("OnClick"',
            'if index == 4 then',
        ):
            self.assertIn(item, PAGE)
        self.assertIn('Window.nav:SetShown(#section.pages > 1 and section.key ~= "patchnotes")', NAV)
        self.assertIn('for index, release in ipairs(ns.PatchNotesData or {})', NAV)

    def test_template_keeps_demo_and_live_release_metadata_distinct(self):
        self.assertEqual(DATA.count("demo = true"), 3)
        self.assertIn('overview =', DATA)
        self.assertIn('highlights = {', DATA)
        self.assertIn('release.demo == false', PAGE)
        self.assertIn('not an actual changelog', PAGE)
        self.assertIn("release.overview or release.summary", PAGE)
        self.assertIn("release.entries and release.entries[i]", PAGE)
        self.assertIn("entry.target and Search.entries[entry.target]", PAGE)
        self.assertIn("relatedButton:SetShown(hasSetting)", PAGE)
        self.assertIn("if item.index == 1 then", PAGE)
        self.assertIn("Settings.MarkPatchNotesSeen(item.data.id)", PAGE)

    def test_narrow_and_wide_layouts_never_stretch_banner_or_clip_archive(self):
        for root_width in (770, 800, 980, 1240, 1680, 2400):
            inset, width, canvas, compact, height = geometry(root_width, 620, 3)
            self.assertLessEqual(width, 1190)
            self.assertGreaterEqual(inset, 20)
            self.assertLessEqual(canvas, 970)
            self.assertGreater(canvas, 500 if root_width >= 770 else 1)
            self.assertGreater(height, 520)
            if root_width >= 1240:
                self.assertFalse(compact)
            if root_width < 850:
                self.assertTrue(compact)
            self.assertEqual(height, 221+3*65+5+(220 if compact else 110)+27)
        for marker in (
            'local usable = math.min(1190, math.max(1, total - 40))',
            'local inset = math.max(20, (total - usable) / 2)',
            'root:HookScript("OnSizeChanged", LayoutWorkspace)',
            'scroll:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)',
            'local compact = width < 620',
            'canvas:SetHeight(y + (dense and 27 or 40))',
            'local dense = scroll:GetHeight() < 590',
            'summaryPanel:SetHeight(summaryH)',
            'frame:SetHeight(rowHeight)',
        ):
            self.assertIn(marker, PAGE)

    def test_two_scroll_owners_and_no_new_persistent_polling(self):
        self.assertIn("function PatchNotes.GetPageScroll(pageKey)", PAGE)
        self.assertIn("function PatchNotes.SetPageScroll(pageKey, offset)", PAGE)
        self.assertIn("function PatchNotes.RefreshReminder()", PAGE)
        self.assertIn('Motion.Fade(canvas, 1, Motion.Duration("gentle"))', PAGE)
        self.assertIn("ClampVersions()", PAGE)
        self.assertIn("Clamp()", PAGE)
        self.assertNotIn('SetScript("OnUpdate"', PAGE)
        self.assertNotIn("DuelsReimaginedDB", PAGE)
        self.assertNotIn("GetNumGuildMembers", PAGE)


if __name__ == "__main__":
    unittest.main()

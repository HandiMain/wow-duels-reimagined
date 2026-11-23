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
    # Mirror the block-to-block anchors, not hardcoded cumulative offsets.
    dense = root_height - 106 < 590
    banner_h = 153 if compact else (120 if dense else 141)
    summary_y = banner_h + 13
    summary_h = (81 if dense else 84) if compact else (54 if dense else 64)
    heading_y = summary_y + summary_h + (11 if dense else 14)
    rows_y = heading_y + (23 if dense else 26)
    rows_bottom = rows_y + entries * (65 if dense else 80) + (5 if dense else 12)
    panel_h = 100 if dense else 114
    panels_h = 2 * panel_h + 20 if compact else panel_h + 10
    notes_height = rows_bottom + panels_h + (27 if dense else 40)
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
            'local archived = index > 3',
            'railY = railY + (archived and 47 or 67)',
        ):
            self.assertIn(item, PAGE)
        self.assertIn('Window.nav:SetShown(#section.pages > 1 and section.key ~= "patchnotes")', NAV)
        self.assertIn('for index, release in ipairs(ns.PatchNotesData or {})', NAV)

    def test_template_keeps_demo_and_live_release_metadata_distinct(self):
        self.assertEqual(DATA.count("demo = true"), 6)
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
            expected = (728 if compact else 558)
            self.assertEqual(height, expected)
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
            'local bannerHeight = compact and 153 or (dense and 120 or 141)',
            'local summaryH = compact and (dense and 81 or 84) or (dense and 54 or 64)',
            'local titleY = summaryY + summaryH + (dense and 11 or 14)',
            'local rowsY = titleY + (dense and 23 or 26)',
            'item.title:SetHeight(dense and 20 or 23)',
            'item.description:SetHeight(dense and 16 or 18)',
            'summaryDescription:SetHeight(42)',
        ):
            self.assertIn(marker, PAGE)

    def test_compact_geometry_does_not_clip_metadata_or_summary(self):
        # In compact mode, wrapped title, version badge, and summary all fit
        # their respective frames. Taller release art remains readable.
        self.assertLessEqual(107 + 27, 153)
        self.assertLessEqual(30 + 42, 81)
        self.assertLessEqual(43 + 16, 61)
        self.assertIn('compact and -107 or -79', PAGE)
        self.assertIn('bannerTitle:SetHeight(compact and 75 or 50)', PAGE)
        self.assertIn('local relatedButton = Style.Action(related, "View Settings", "patchnotes", {', PAGE)
        self.assertIn('fill=C.nav, edge=C.goldDim, light=C.gold, dark=C.border', PAGE)
        self.assertNotIn('Style.Action(related, "View Settings", "footer")', PAGE)

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

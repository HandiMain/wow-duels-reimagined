"""Static contracts for the approved version-based Patch Notes UI."""
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"

def load(path):
    return (ADDON / path).read_text(encoding="utf-8")

class PatchNotesUITests(unittest.TestCase):
    def test_toc_order_and_no_real_version_bump(self):
        toc = load("DuelsReimagined.toc")
        sequence = [
            r"UI\Search.lua", r"UI\PatchNotesData.lua",
            r"UI\Navigation.lua", r"UI\Options.lua", r"UI\PatchNotes.lua"
        ]
        self.assertEqual([toc.count(p) for p in sequence], [1] * len(sequence))
        self.assertEqual([toc.index(p) for p in sequence],
                         sorted(toc.index(p) for p in sequence))
        self.assertIn("## Interface: 120105, 16001", toc)

    def test_single_version_data_owner_and_demo_labels(self):
        data = load("UI/PatchNotesData.lua")
        nav = load("UI/Navigation.lua")
        page = load("UI/PatchNotes.lua")
        self.assertEqual(data.count('version = "v0.1.'), 3)
        self.assertEqual(len(re.findall(r'id = "demo-patch-[^"]+"', data)), 6)
        self.assertIn("for index, release in ipairs(ns.PatchNotesData or {})", nav)
        self.assertIn("local releases = ns.PatchNotesData or {}", page)
        self.assertNotIn('key = "latest", label = "Latest Update"', nav)
        self.assertIn('Settings.MarkPatchNotesSeen(item.data.id)', page)
        self.assertIn("if item.index == 1 then", page)
        self.assertIn("not an actual changelog", page)
        self.assertEqual(data.count("demo = true"), 6)
        self.assertIn("overview =", data)
        self.assertIn("highlights = {", data)
        self.assertIn('section.key ~= "patchnotes"', nav)

    def test_art_assets_and_wow_tga_headers(self):
        for name, expected in (
            ("PatchNotesAtlas.tga", (256, 256)),
        ):
            blob = (ADDON / "Media" / "Concept" / name).read_bytes()
            self.assertEqual(blob[2], 2)  # uncompressed true-color
            self.assertEqual(struct.unpack_from("<HH", blob, 12), expected)
            self.assertEqual(blob[16], 32)  # BGRA with alpha
            self.assertEqual(blob[17], 0x28)  # upper-left origin, 8-bit alpha
            self.assertEqual(len(blob), 18 + expected[0] * expected[1] * 4)
        hero = (ADDON / "Media" / "Concept" / "PatchNotesHeroApproved.png").read_bytes()
        self.assertEqual(hero[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack_from(">II", hero, 16), (1024, 256))
        self.assertEqual(hero[25], 6)  # RGBA source, no baked release text
        for name, dimensions in (
            ("PatchNotesVersionSelected.png", (256, 128)),
            ("PatchNotesVersionRing.png", (64, 64)),
        ):
            blob = (ADDON / "Media" / "Concept" / name).read_bytes()
            self.assertEqual(blob[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack_from(">II", blob, 16), dimensions)
            self.assertEqual(blob[25], 6)

    def test_shared_owners_and_font_consistency(self):
        nav, page = load("UI/Navigation.lua"), load("UI/PatchNotes.lua")
        self.assertIn('label:SetText("Patch Notes")', nav)
        self.assertNotIn('PatchNotesAtlas.tga', nav)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)', nav)
        self.assertNotIn('local parchment = Style.Fill(icon, C.goldDim, "ARTWORK")', nav)
        self.assertIn('PatchNotes = { 0,   0.5, 0.5, 1 }', load("UI/Chrome.lua"))
        self.assertIn('Style.Text(button, isPrimary and "HALL" or section.label,', nav)
        self.assertIn("isPrimary and 23 or 12, C.tabMuted, nil,", nav)
        self.assertIn("Style.Text(root,", page)
        self.assertIn("Widgets.ScrollBar(scroll,", page)
        self.assertIn("Motion.Fade(canvas,", page)
        self.assertNotIn('SetScript("OnUpdate"', page)
        self.assertNotIn("DuelsReimaginedDB", page)
        self.assertIn("Search.entries[entry.target]", page)
        self.assertIn('ns.Navigation.SelectKey("patchnotes", release.key)', page)
        self.assertIn('versionScroll:SetScript("OnMouseWheel"', page)
        self.assertIn('scroll:SetScript("OnMouseWheel"', page)
        self.assertIn('relatedButton:SetShown(hasSetting)', page)
        self.assertIn('local function VersionFlank(side)', page)
        self.assertNotIn('local railDivider = Chrome.Divider(rail', page)
        self.assertIn('PatchNotesVersionSelected.png', page)
        self.assertIn('PatchNotesVersionRing.png', page)
        self.assertIn('item.dot:SetShown(not current and not item.archived)', page)
        self.assertIn('versionBadge:SetPoint("TOPLEFT"', page)
        self.assertIn('Style.Skin(banner, C.nav, { corner=11, edge=C.goldDim,', page)
        self.assertIn('bannerArt:SetPoint("TOPLEFT", banner, "TOPLEFT", 10, -10)', page)
        self.assertIn('bannerArt:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -10, 10)', page)
        self.assertIn('bannerArt:SetTexCoord(28 / 1024, 996 / 1024, 51 / 256, 197 / 256)', page)
        self.assertNotIn('bannerArt:SetAllPoints(banner)', page)
        self.assertNotIn('bannerArt:SetTexCoord(0, 1, 37 / 256, 212 / 256)', page)
        self.assertIn('bannerDate:SetText(compact and', page)
        self.assertIn('local dense = scroll:GetHeight() < 590', page)
        self.assertIn('PatchNotes.relatedTarget = nil', page)
        self.assertIn('release.demo == false', page)
        self.assertIn('local maxEntries = 0', page)
        self.assertIn('if index == 4 then', page)
        self.assertIn('local archived = index > 3', page)
        self.assertIn('button:SetHeight(archived and 39 or 58)', page)
        self.assertIn('railY = railY + (archived and 47 or 67)', page)
        self.assertIn('item.archiveArrow:SetShown(item.archived and not current)', page)
        self.assertNotIn('local archiveLine = Chrome.Divider', page)

if __name__ == "__main__":
    unittest.main()

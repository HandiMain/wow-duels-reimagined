"""Regression contracts for refined shell, grip and all five themes.

Structural checks are NOT proof of in-game UI appearance or behavior.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def get(path):
    return (ROOT / path).read_text(encoding="utf-8")


class PremiumPolishTests(unittest.TestCase):
    def test_utility_rail_labels_have_more_room(self):
        w, n = get("UI/Window.lua"), get("UI/Navigation.lua")
        self.assertIn("utility:SetWidth(98)", w)
        self.assertIn("button:SetSize(90, 90)", n)
        self.assertIn("label:SetWidth(88)", n)
        self.assertIn('label:SetHeight(30)', n)
        self.assertIn('label:SetJustifyV("MIDDLE")', n)
        self.assertIn("nav:SetWidth(210)", w)
        self.assertIn('Window.utility = utility', w)
        self.assertIn('local primaryKeys = { hall = true }', n)

    def test_outer_frame_fills_seam_but_respects_rounded_corners(self):
        w, c = get("UI/Window.lua"), get("UI/Chrome.lua")
        self.assertIn('Style.Skin(frame, C.window, {', w)
        self.assertIn('corner=12, edge=C.shellEdge', w)
        self.assertIn('local inset = 6', w)
        self.assertIn('interior:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)', w)
        self.assertIn('interior:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)', w)
        self.assertIn('Style.SkinMask(rim, C.shellEdge, "rim"', c)
        self.assertNotIn("local inset = 8", w)

    def test_grip_uses_compact_themeable_glyph_and_existing_motion_engine(self):
        w = get("UI/Window.lua")
        self.assertNotIn('Style.Skin(grip, C.rail, {', w)
        self.assertIn('plate:SetSize(26, 26)', w)
        self.assertIn('local gripGlow = Style.Skin(plate, C.tabActive', w)
        self.assertIn('local gripGlyph = Style.TintedImage(plate,', w)
        self.assertIn('ResizeGlyph.tga', w)
        self.assertIn('gripGlyph:SetAlpha(0.74)', w)
        self.assertIn('Motion.Fade(gripGlow, alpha, duration)', w)
        self.assertIn('GripFeedback(0.94, Motion.Duration("quick"))', w)
        self.assertIn('grip:SetScript("OnMouseDown"', w)
        self.assertIn('grip:SetScript("OnMouseUp"', w)
        self.assertIn('grip:SetScript("OnEnter"', w)
        self.assertIn('grip:SetScript("OnLeave"', w)
        self.assertIn('Motion.Stop(gripGlow, 0)', w)
        self.assertIn('frame:StartSizing("BOTTOMRIGHT")', w)
        self.assertIn('Window.CommitResize()', w)
        self.assertIn('Window.ResetSize()', w)
        self.assertIn('Motion.Stop(gripGlyph, 0.74)', w)
        self.assertNotIn("ResizeGripHighlight.png", w)
        self.assertNotIn('SetScript("OnUpdate"', w)

    def test_five_complete_consistent_theme_palettes(self):
        s = get("UI/Style.lua")
        roles = set(re.findall(r'\b([a-zA-Z]+)="[0-9A-F]{6}"', s))
        block = s[s.index("local schemes = {"):s.index("local choices = {")]
        expected = ("ivory","slate","verdant","ember","moonstone")
        role_sets = {}
        for i, name in enumerate(expected):
            start = block.index("    " + name + " = {")
            end = block.index("    },", start)
            palette = block[start:end]
            role_sets[name] = set(re.findall(r'\b([a-zA-Z]+)="[0-9A-F]{6}"', palette))
            self.assertEqual(len(role_sets[name]), 26)
            self.assertIn('key = "' + name + '"', s)
        for name in expected[1:]:
            self.assertEqual(role_sets["ivory"], role_sets[name])
        self.assertIn('label = "Obsidian & Ember (Default)"', s)
        self.assertIn('label = "Moonstone & Violet"', s)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', s)

    def test_saved_theme_validation_uses_single_style_registry(self):
        settings = get("Core/Settings.lua")
        self.assertIn('ns.Style.IsTheme(value)', settings)
        self.assertIn('if key == "uiTheme" then return "ember" end', settings)
        self.assertIn('db.uiTheme = value', settings)
        self.assertIn('db.uiTheme = Settings.Get("uiTheme")', settings)
        self.assertNotIn('value == "slate" or value == "verdant"', settings)

    def test_ellesmere_color_match_preserves_access_to_premium_skins(self):
        opt, theme, settings = (get(path) for path in (
            "UI/Options.lua", "UI/Theme.lua", "Core/Settings.lua"))
        self.assertIn('local matchedColors = ready and Settings.Get("matchColors") == true', opt)
        self.assertIn('themeChoice:SetAvailable(true)', opt)
        self.assertIn('EllesmereUI provides the colors; choose any visual skin', opt)
        self.assertNotIn('themeChoice:SetAvailable(not matchedColors,', opt)
        self.assertIn('themeChoice:SetModified(Settings.IsModified("uiTheme"))', opt)
        self.assertIn('if Settings.Get("matchColors") then', theme)
        self.assertIn('Style.ApplyTheme(accent, panel, font)', theme)
        self.assertIn('db.uiTheme = value', settings)
        self.assertNotIn('db.uiTheme = nil', opt)
        self.assertNotIn('db.uiTheme = nil', theme)

    def test_feature_paths_not_replaced_by_visual_edits(self):
        w,n = get("UI/Window.lua"),get("UI/Navigation.lua")
        self.assertIn('function Window.SetSizingEnabled(on)', w)
        self.assertIn('function Window.ApplyScale(value)', w)
        self.assertIn('function Window.ShowPage(page)', w)
        self.assertIn('ns.Search.Register("page:" .. section.key', n)
        self.assertIn('SetPatchUnread = function(unread)', n)
        self.assertIn('SelectKey = function(sectionKey, pageKey)', n)


if __name__ == "__main__":
    unittest.main()

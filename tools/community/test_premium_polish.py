"""Regression contracts for refined shell, grip and the fixed Duel Hall palette.

Structural checks are NOT proof of in-game UI appearance or behavior.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def get(path):
    return (ROOT / path).read_text(encoding="utf-8")


class PremiumPolishTests(unittest.TestCase):
    def test_compact_footer_shortcuts_preserve_secondary_names(self):
        w, n = get("UI/Window.lua"), get("UI/Navigation.lua")
        self.assertIn('utility:SetSize(360, 36)', w)
        self.assertIn('button:SetSize(112, 30)', n)
        self.assertIn('icon:SetSize(isPrimary and 48 or 20', n)
        self.assertIn('Window.utility = utility', w)
        self.assertIn('local primaryKeys = { hall = true }', n)
        self.assertNotIn('button:SetSize(90, 90)', n)

    def test_outer_frame_fills_seam_but_respects_rounded_corners(self):
        w, c = get("UI/Window.lua"), get("UI/Chrome.lua")
        self.assertIn('Style.Skin(frame, C.window, {', w)
        self.assertIn('corner=12, edge=C.window', w)
        self.assertIn('local inset = 6', w)
        self.assertIn('interior:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)', w)
        self.assertIn('interior:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)', w)
        self.assertIn('Style.Plate(rim, "shellCopper"', c)
        self.assertNotIn("local inset = 8", w)

    def test_grip_uses_compact_themeable_glyph_and_existing_motion_engine(self):
        w = get("UI/Window.lua")
        self.assertNotIn('Style.Skin(grip, C.rail, {', w)
        self.assertIn('resizeArt:SetSize(64, 64)', w)
        self.assertIn('grip:SetSize(38, 38)', w)
        self.assertIn('DuelFilledTriangleCorner.png', w)
        self.assertIn('gripGlow:SetBlendMode("ADD")', w)
        self.assertNotIn('ResizeGlyph.tga', w)
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
        self.assertIn('resizeArt:SetShown(on and true or false)', w)
        self.assertNotIn("ResizeGripHighlight.png", w)
        # Drag-edge guides may update ONLY while dragging. They self-disarm
        # at drag stop and hide; a permanent window polling loop is forbidden.
        self.assertIn('self:SetScript("OnUpdate", function() DrawGuides() end)', w)
        self.assertIn('self:SetScript("OnUpdate", nil)', w)
        self.assertNotIn('frame:SetScript("OnUpdate"', w)

    def test_single_complete_duel_hall_palette(self):
        s = get("UI/Style.lua")
        block = s[s.index("local duelHall = {"):s.index("Style.color = {}")]
        self.assertEqual(block.count('local duelHall = {'), 1)
        roles = set(re.findall(r'\b([a-zA-Z]+)="[0-9A-F]{6}"', block))
        self.assertEqual(len(roles), 26)
        self.assertNotIn('local choices =', s)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', s)
        for old in ('ivory = {','slate = {','verdant = {',
                    'ember = {','moonstone = {'):
            self.assertNotIn(old, s)

    def test_obsolete_theme_and_color_overrides_are_retired(self):
        settings = get("Core/Settings.lua")
        self.assertIn('db.uiTheme = nil', settings)
        self.assertIn('db.matchColors = nil', settings)
        self.assertNotIn('ns.Style.IsTheme(value)', settings)
        self.assertNotIn('if key == "uiTheme"', settings)
        self.assertNotIn('db.uiTheme = value', settings)

    def test_only_font_matching_can_use_ellesmere(self):
        opt, theme, settings = (get(path) for path in (
            "UI/Options.lua", "UI/Theme.lua", "Core/Settings.lua"))
        self.assertIn('local matchFontRow = AddToggle(', opt)
        self.assertIn('Settings.Get("matchFont")', theme)
        self.assertIn('skin.GetFont', theme)
        self.assertIn('Style.ApplyTheme(font)', theme)
        self.assertNotIn('themeChoice', opt)
        self.assertNotIn('matchColorsRow', opt)
        self.assertNotIn('GetAccentColor', theme)
        self.assertNotIn('GetPanelColor', theme)
        self.assertNotIn('matchColors = false', settings)

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

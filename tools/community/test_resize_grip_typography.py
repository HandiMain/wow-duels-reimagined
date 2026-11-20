"""Targeted regressions: small resize glyph and clean theme typography."""
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def source(path):
    return (BASE / path).read_text(encoding="utf-8")

class GripTypographyTests(unittest.TestCase):
    def test_glyph_is_neutral_32bit_rgba_tga(self):
        data = (BASE / "Media" / "Skin" / "ResizeGlyph.tga").read_bytes()
        self.assertEqual(len(data), 18 + 32*32*4)
        self.assertEqual(data[2], 2)
        self.assertEqual(struct.unpack_from("<HH", data, 12), (32,32))
        self.assertEqual((data[16],data[17]), (32,0x28))
        pixels = data[18:]
        alpha = pixels[3::4]
        self.assertIn(0, alpha)
        self.assertIn(255, alpha)
        self.assertTrue(all(pixels[i:i+3] == b"\xff\xff\xff"
                            for i in range(0,len(pixels),4)))

    def test_invisible_hit_area_visible_small_glyph_only(self):
        win = source("UI/Window.lua")
        self.assertIn('grip:SetSize(34, 34)', win)
        self.assertIn('plate:SetSize(26, 26)', win)
        self.assertIn('plate:EnableMouse(false)', win)
        self.assertIn('local gripGlyph = Style.TintedImage(plate,', win)
        self.assertIn('gripGlyph:SetAllPoints(plate)', win)
        self.assertIn('gripGlyph:SetAlpha(0.74)', win)
        self.assertNotIn('Style.Skin(grip, C.rail', win)
        self.assertNotIn('for i = 1, 3 do\n    local length = 8', win)

    def test_existing_hover_press_drag_reset_and_fold(self):
        win = source("UI/Window.lua")
        for needle in ('Motion.Fade(gripGlow, alpha, duration)',
                       'Motion.Fade(gripGlyph, alpha > 0 and 1 or 0.74, duration)',
                       'Motion.Stop(gripGlow, 0)', 'Motion.Stop(gripGlyph, 0.74)',
                       'frame:StartSizing("BOTTOMRIGHT")',
                       'frame:StopMovingOrSizing()', 'Window.CommitResize()',
                       'if button == "RightButton" then Window.ResetSize() end',
                       'grip:SetScript("OnEnter"', 'grip:SetScript("OnLeave"',
                       'grip:HookScript("OnHide"'):
            self.assertIn(needle, win)
        self.assertNotIn('SetScript("OnUpdate"', win)

    def test_new_glyph_uses_existing_theme_tint_registry(self):
        style = source("UI/Style.lua")
        self.assertIn('function Style.TintedImage(parent, path, color, layer)', style)
        self.assertIn('RegisterTexture(tex, color, "vertex")', style)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', style)
        self.assertIn('function Style.ApplyTheme(accent, panel, fontPath)', style)

    def test_burgundy_light_surface_headings_have_no_forced_outlines(self):
        for file in ("UI/Community.lua","UI/PatchNotes.lua","UI/Tooltips.lua"):
            contents = source(file)
            self.assertNotIn('C.pale, true)', contents, file)
            self.assertNotIn('C.gold, true)', contents, file)
        self.assertIn('Style.Text(root, "Patch Notes", 29, C.pale)',
                      source("UI/PatchNotes.lua"))
        self.assertIn('Style.Text(row, "", 17, C.pale)',
                      source("UI/PatchNotes.lua"))
        self.assertIn('Style.Text(tip, "", 15, C.pale)',
                      source("UI/Tooltips.lua"))

    def test_explicit_user_outline_setting_remains_available(self):
        style, opts = source("UI/Style.lua"), source("UI/Options.lua")
        self.assertIn('local mode = ns.Settings and ns.Settings.Get("fontOutline")', style)
        self.assertIn('if mode == "none" then outline = ""', style)
        self.assertIn('elseif mode == "outline" then outline = "OUTLINE"', style)
        self.assertIn('elseif mode == "thick" then outline = "THICKOUTLINE"', style)
        self.assertIn('RegisterOption("fontOutline",', opts)

if __name__ == "__main__":
    unittest.main()

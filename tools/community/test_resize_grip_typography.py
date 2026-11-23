"""Targeted regressions: forged copper corner and clean theme typography."""
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def source(path):
    return (BASE / path).read_text(encoding="utf-8")

class GripTypographyTests(unittest.TestCase):
    def test_forged_corner_is_transparent_native_png(self):
        import hashlib
        path = BASE / "Media" / "Skin" / "DuelCorner03Copper.png"
        data = path.read_bytes()
        self.assertEqual(data[:8], bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack_from(">IIBB",data,16), (256,256,8,6))
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc")

    def test_integrated_frame_corner_without_second_button_skin(self):
        win = source("UI/Window.lua")
        for marker in ('resizeArt:SetSize(96, 96)',
                       'resizeArt:EnableMouse(false)',
                       'forgedCorner:SetTexture(CORNER_ART)',
                       'grip:SetSize(54, 54)',
                       'DuelCorner03Copper.png',
                       'gripGlow:SetBlendMode("ADD")',
                       'resizeArt:SetShown(on and true or false)'):
            self.assertIn(marker,win)
        self.assertNotIn("ResizeGlyph.tga",win)
        self.assertNotIn("Style.Skin(grip, C.rail",win)
        self.assertNotIn("plate:SetSize(26, 26)",win)

    def test_existing_hover_press_drag_reset_and_fold(self):
        win = source("UI/Window.lua")
        for needle in ('Motion.Fade(gripGlow, alpha, duration)',
                       'Motion.Stop(gripGlow, 0)',
                       'frame:StartSizing("BOTTOMRIGHT")',
                       'frame:StopMovingOrSizing()', 'Window.CommitResize()',
                       'if button == "RightButton" then Window.ResetSize() end',
                       'grip:SetScript("OnEnter"', 'grip:SetScript("OnLeave"',
                       'grip:HookScript("OnHide"'):
            self.assertIn(needle, win)
        # The new magnetic guide uses temporary per-handle updates, not
        # permanent resize or window-wide polling.
        self.assertIn('self:SetScript("OnUpdate", function() DrawGuides() end)', win)
        self.assertIn('self:SetScript("OnUpdate", nil)', win)
        self.assertNotIn('frame:SetScript("OnUpdate"', win)

    def test_new_glyph_uses_existing_theme_tint_registry(self):
        style = source("UI/Style.lua")
        self.assertIn('function Style.TintedImage(parent, path, color, layer)', style)
        self.assertIn('RegisterTexture(tex, color, "vertex")', style)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', style)
        self.assertIn('function Style.ApplyTheme(fontPath)', style)

    def test_burgundy_light_surface_headings_have_no_forced_outlines(self):
        for file in ("UI/Community.lua","UI/PatchNotes.lua","UI/Tooltips.lua"):
            contents = source(file)
            self.assertNotIn('C.pale, true)', contents, file)
            self.assertNotIn('C.gold, true)', contents, file)
        self.assertIn('Style.Text(root, "Patch Notes", 24, C.pale, nil, "display")',
                      source("UI/PatchNotes.lua"))
        self.assertIn('Style.Text(row, "", 16, C.pale)',
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

"""Static contracts for the code-driven, tintable premium skin."""
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def src(p):
    return (BASE / p).read_text(encoding="utf-8")

class PremiumSkinTests(unittest.TestCase):
    def test_tga_has_four_neutral_rgba_masks(self):
        data = (BASE / "Media" / "Skin" / "NeutralMasks.tga").read_bytes()
        self.assertEqual(len(data), 18 + 128 * 128 * 4)
        self.assertEqual(data[2], 2)
        self.assertEqual(struct.unpack_from("<HH", data, 12), (128,128))
        self.assertEqual((data[16], data[17]), (32, 0x28))
        pixels = data[18:]
        for ox,oy in ((0,0),(64,0),(0,64),(64,64)):
            alpha = [pixels[((y+oy)*128+x+ox)*4+3]
                     for y in range(64) for x in range(64)]
            self.assertGreater(max(alpha),0)
            self.assertLess(min(alpha),max(alpha))
        self.assertTrue(all(pixels[i:i+3] == b"\xff\xff\xff"
                            for i in range(0,len(pixels),4)))

    def test_tint_and_animation_alpha_survive_recolor(self):
        s = src("UI/Style.lua")
        for token in (
            'Media\\\\Skin\\\\NeutralMasks.tga',
            'function Style.SkinMask(parent, color, mask, layer, sublevel, corner, inset)',
            'function Style.Skin(parent, fill, opts)',
            'RegisterTexture(tex, color, "vertex")',
            'entry.region:SetVertexColor(unpack(value))',
            'local opacity = entry.region:GetAlpha()',
            'entry.region:SetAlpha(opacity)',
            'function skin:GetAlpha() return self.alpha end',
            'function skin:SetAlpha(a)',
            'function Style.LitBand(parent, base, opts)'):
            self.assertIn(token, s)
        self.assertIn('Style.ApplyTheme(accent, panel, font)', src("UI/Theme.lua"))
        self.assertIn('if panel then', s)
        self.assertIn('if accent then', s)
        for theme in ("ivory","slate","verdant"):
            self.assertIn(theme + " = {", s)

    def test_shared_premium_skin_reaches_every_current_page(self):
        for p, expected in (
            ("UI/Window.lua", "Style.Skin(content, C.body"),
            ("UI/Window.lua", "Style.LitBand(header, C.header"),
            ("UI/Window.lua", "Style.Skin(nav, C.nav"),
            ("UI/Navigation.lua", "Style.Skin(button, C.tabActive"),
            ("UI/Header.lua", "Style.Skin(searchBox, C.window"),
            ("UI/Footer.lua", "Style.Skin(button, C.goldDim"),
            ("UI/Options.lua", "Style.Skin(card, C.nav"),
            ("UI/Community.lua", "Style.Skin(card, C.nav"),
            ("UI/Community.lua", "Style.Skin(listing, C.nav"),
            ("UI/PatchNotes.lua", "Style.Skin(banner, C.nav"),
            ("UI/PatchNotes.lua", "Style.Skin(row, C.nav"),
            ("UI/Widgets.lua", "Style.Skin(control, C.body"),
            ("UI/Widgets.lua", "Style.Skin(popup, C.nav"),
            ("UI/BlizzardSettings.lua", "Style.Skin(surface, LANDING_BG")):
            self.assertIn(expected, src(p), p)

    def test_features_still_have_their_owners(self):
        for p, tokens in {
            "UI/Header.lua": ("function Header.Fold(value)",
                              "function Header.RefreshAutoPeek()",
                              "function Header.CloseSearch("),
            "UI/Navigation.lua": ("local function Select(","local function FitTabs(",
                                  "SetPatchUnread = function("),
            "UI/Window.lua": ("function Window.ResetWindow()",
                              "function Window.ApplyScale(value)",
                              "function Window.SetSizingEnabled(on)"),
            "UI/Footer.lua": ("Settings.NeedsReload()","Window.ResetWindow()"),
            "UI/Theme.lua": ('pcall(eui.RegisterSkin, "DuelsReimagined"',),
        }.items():
            for token in tokens:
                self.assertIn(token, src(p))
        self.assertIn("local function WriteDB()", src("Core/Settings.lua"))
        self.assertIn("HeaderOption5TintAtlas.png", src("UI/Window.lua"))
        self.assertIn("HeaderOption5TintAtlas.png", src("UI/BlizzardSettings.lua"))
        for p in ("UI/Style.lua","UI/Chrome.lua","UI/Navigation.lua"):
            self.assertNotIn('SetScript("OnUpdate"', src(p))

if __name__ == "__main__":
    unittest.main()

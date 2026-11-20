"""Focused source / asset contracts for Duels premium visual skin families.

The addon still needs in-game visual and input verification on WoW Forever/Retail.
"""
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def src(path):
    return (BASE / path).read_text(encoding="utf-8")

class PremiumVisualSkinsTests(unittest.TestCase):
    def test_shared_skin_owner_is_loaded_before_every_consumer(self):
        toc = src("DuelsReimagined.toc")
        self.assertLess(toc.index("UI\\Style.lua"), toc.index("UI\\SkinDecor.lua"))
        self.assertLess(toc.index("UI\\SkinDecor.lua"), toc.index("UI\\Chrome.lua"))
        self.assertLess(toc.index("UI\\SkinDecor.lua"), toc.index("UI\\Window.lua"))
        self.assertLess(toc.index("UI\\SkinDecor.lua"), toc.index("UI\\Options.lua"))
        self.assertIn("ns.SkinDecor = Decor", src("UI/SkinDecor.lua"))

    def test_four_identities_and_untouched_ember_baseline(self):
        art = src("UI/SkinDecor.lua")
        for key in ('ivory','verdant','slate','moonstone'):
            self.assertIn(key + " = {", art)
        self.assertIn('ember = { family = "baseline", radius = 1, uv = nil }', art)
        self.assertIn('family = "hall"', art)
        self.assertIn('family = "arena"', art)
        self.assertIn('return Decor.Profile().family', art)
        self.assertIn('if not p.uv then', art)
        self.assertIn('motif:Hide()', art)
        self.assertIn('top:Hide()', art)
        self.assertIn('seal:Hide()', art)
        self.assertIn('if key == "uiTheme" then return "ember" end', src("Core/Settings.lua"))

    def test_art_is_ours_unbaked_power_of_two_rgba_atlas(self):
        png = (BASE / "Media" / "Skin" / "DuelsPremiumMotifs.png").read_bytes()
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        w,h,depth,pixel = struct.unpack(">IIBB",png[16:26])
        self.assertEqual((w,h,depth,pixel),(128,128,8,6))
        self.assertIn(b"IDAT",png)
        self.assertLess(len(png),10000)
        decor=src("UI/SkinDecor.lua")
        for uv in ('{0.5, 1, 0, 0.5}', '{0, 0.5, 0, 0.5}',
                   '{0, 0.5, 0.5, 1}', '{0.5, 1, 0.5, 1}'):
            self.assertIn(uv,decor)
        self.assertIn('motif:SetTexCoord(unpack(p.uv))', decor)

    def test_theme_switch_repaints_and_reforms_existing_masks(self):
        st, decor, th = (src(p) for p in
            ("UI/Style.lua","UI/SkinDecor.lua","UI/Theme.lua"))
        self.assertIn('function group:SetCorner(radius)',st)
        self.assertIn('ns.SkinDecor.RegisterMask(group, corner)',st)
        self.assertIn('masks = setmetatable({}, {__mode = "k"})',decor)
        self.assertIn('function Decor.Refresh()',decor)
        self.assertIn('group:SetCorner(math.max(4, math.floor(corner * p.radius + 0.5)))',decor)
        self.assertIn('ns.SkinDecor.Refresh()',th)
        self.assertIn('Style.ApplyTheme(accent, panel, font)',th)
        self.assertIn('pcall(eui.RegisterSkin',th)

    def test_shared_hit_areas_and_options_remain_unmoved(self):
        window, nav, options = (src(p) for p in
            ("UI/Window.lua","UI/Navigation.lua","UI/Options.lua"))
        for role in ('shell','header','rail','utility','nav','content'):
            self.assertIn('ns.SkinDecor.Attach(',window)
            self.assertIn('"' + role + '"',window)
        self.assertIn('ns.SkinDecor.Attach(button, "navButton")',nav)
        self.assertIn('ns.SkinDecor.Attach(card, "card")',options)
        self.assertIn('button:SetSize(90, 90)',nav)
        self.assertIn('button:SetSize(216, 44)',nav)
        self.assertIn('RegisterOption("uiTheme", "Visual skin"',options)
        self.assertIn('themeChoice:SetChoices(Style.ThemeChoices()',options)
        self.assertIn('themeChoice:SetAvailable(not matchedColors,',options)

    def test_no_duplicate_state_or_forever_polling(self):
        decor=src("UI/SkinDecor.lua")
        for forbidden in ('_G.DuelsReimaginedDB','C_Timer.NewTicker',
                          'SetScript("OnUpdate"','RegisterEvent(',
                          'CreateFrame("Button"','_G.EllesmereUI'):
            self.assertNotIn(forbidden,decor)
        self.assertIn('local C = Style.color',decor)
        self.assertIn('Style.TintedImage(parent, motifs, C.goldDim',decor)
        self.assertIn('Settings.Get("fontChoice") ~= "default"',decor)
        self.assertIn('local path = fontPath or skinFont',src("UI/Style.lua"))

if __name__ == "__main__":
    unittest.main()

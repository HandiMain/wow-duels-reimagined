"""Options text-safe bitmap geometry and clear Hall/header feedback.

Static contracts; only the WoW client can verify on-screen pixel alignment.
"""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def lua(name): return (ROOT/"UI"/name).read_text(encoding="utf-8")
class TextSafeOptionsAndHoverTests(unittest.TestCase):
    def test_all_eight_banners_have_safe_text_height_and_row_separation(self):
        o=lua("Options.lua")
        for t in (
            'local BANNER_HEIGHT = 72',
            'local ROW_TOP = 90',
            'headingBand:SetHeight(72)',
            'math.max(1, height - 8) / BANNER_CELL_H',
            'left:SetPoint("LEFT", header, "LEFT", 0, 0)',
            'right:SetPoint("RIGHT", header, "RIGHT", 0, 0)',
            'divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -82)',
            'local y = largeText and 104 or ROW_TOP',
            'function appearance:Relayout(width)',
            'function interface:Relayout(width)',
        ): self.assertIn(t,o)
        self.assertEqual(o.count('Section('),11)
        self.assertIn('Section(resultCard,"result","Duel Result",',o)
        self.assertIn('headingBand:SetClipsChildren(false)',o)
        self.assertIn('(width - 24) / BANNER_REFERENCE_WIDTH',o)
        self.assertIn("DuelOptionsBanner.png",o)
        self.assertNotIn("DuelBannerAmbient.png",o)
        self.assertNotIn("local center = Slice(",o)
        self.assertLess(6+72,82) # card-header end before divider
        self.assertLess(82,90) # divider before first live row

    def test_large_window_uses_short_gradients_not_stretched_masks(self):
        style=lua("Style.lua")
        window=lua("Window.lua")
        self.assertIn('if opts.smooth then',style)
        self.assertIn('strengths[2], strengths[3] = 0, 0',style)
        self.assertIn('EdgeFade(true, 112, true, 0.024)',style)
        self.assertIn('EdgeFade(false, 88, false, 0.045)',style)
        self.assertIn('Style.Skin(rail, C.rail, { corner=8, edge=C.shellEdge, smooth=true })',window)
        self.assertIn('Style.Skin(content, C.body, { corner=7, edge=C.border, smooth=true })',window)

    def test_smaller_header_x_preserves_behavior(self):
        h=lua("Header.lua")
        self.assertIn('name == "Close" and 24 or 29',h)
        self.assertIn('name == "Close" and 15 or 19',h)
        self.assertIn('close:SetScript("OnClick", function() frame:Hide() end)',h)
        self.assertIn('ns.Widgets.PressFeedback(b, hover, {',h)
        self.assertIn('Tooltips.Bind(b, function()',h)
        self.assertIn('HeaderButton("FoldUp"',h)
        self.assertIn('HeaderButton("Eye"',h)

    def test_hall_has_distinct_hover_without_changing_its_click_art(self):
        n=lua("Navigation.lua")
        self.assertIn('Style.MenuButton(button, section.key, section.label, {primary=isPrimary})',n)
        s=lua("Style.lua")
        self.assertIn('local selected=MenuPlate(button,kind,-1,true)',s)
        self.assertIn('local hover=MenuPlate(button,kind,0,true)',s)
        self.assertIn('t:SetBlendMode("ADD")',s)
        self.assertIn('ns.Motion.Fade(hover,selected:GetAlpha()>0 and .24 or .34',s)
        self.assertIn('ns.Motion.Fade(hover,0,ns.Motion.Duration("gentle"))',s)
        self.assertIn('flashFactory=function() return MenuPlate(button,kind,1,true) end',s)
        self.assertIn('ns.Widgets.PressFeedback(button, hover, {',s)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)',n)
        self.assertNotIn('SetScript("OnUpdate"',n)
if __name__=="__main__":unittest.main()

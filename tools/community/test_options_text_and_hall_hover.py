"""Options text-safe bitmap geometry and clear Hall/header feedback.

Static contracts; only the WoW client can verify on-screen pixel alignment.
"""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def lua(name): return (ROOT/"UI"/name).read_text(encoding="utf-8")
class TextSafeOptionsAndHoverTests(unittest.TestCase):
    def test_all_six_banners_have_safe_text_height_and_row_separation(self):
        o=lua("Options.lua")
        for t in (
            'local BANNER_HEIGHT = 62',
            'local ROW_TOP = 80',
            'headingBand:SetHeight(62)',
            'math.max(1, height - 4) / BANNER_CELL_H',
            'left:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -2)',
            'right:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -2)',
            'divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -72)',
            'local y = largeText and 94 or ROW_TOP',
            'function appearance:Relayout(width)',
            'function interface:Relayout(width)',
        ): self.assertIn(t,o)
        self.assertEqual(o.count('Section('),7)
        self.assertIn("DuelOptionsSoftArt.png",o)
        self.assertIn("DuelBannerAmbient.png",o)
        self.assertNotIn("local center = Slice(",o)
        self.assertLess(6+62,72) # card-header end before divider
        self.assertLess(72,80) # divider before first live row

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
        self.assertIn('local concept = Style.ConceptImage(button, "hall", "ARTWORK", 2)',n)
        self.assertIn('local hallGlow = Style.ConceptImage(button, "hall", "OVERLAY", 6)',n)
        self.assertIn('hallGlow:SetBlendMode("ADD")',n)
        self.assertIn('hallGlow:SetAlpha(0)',n)
        self.assertIn('Motion.Fade(button.hallGlow, 0.30, Motion.Duration("quick"))',n)
        self.assertIn('Motion.Fade(button.hallGlow, 0, Motion.Duration("gentle"))',n)
        self.assertIn('Motion.Stop(hallGlow, 0)',n)
        self.assertIn('ns.Widgets.PressFeedback(button, hover, {',n)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)',n)
        self.assertNotIn('SetScript("OnUpdate"',n)
if __name__=="__main__":unittest.main()

"""Regression contract for the approved single-owner visual skin.

These are source checks only. WoW pixel accuracy and texture upload remain
in-game verification tasks, not automatic PASS claims.
"""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def lua(p):return (ROOT/p).read_text(encoding="utf-8")

class VisualOwnerTests(unittest.TestCase):
    def test_brand_has_one_live_drag_owner_and_one_visible_asset(self):
        win=lua("UI/Window.lua")
        self.assertIn("local brandDrag = CreateFrame",win)
        self.assertIn("Drag(brandDrag)",win)
        self.assertIn("DuelBrand.png",win)
        self.assertNotIn("BrandLayer(",win)
        self.assertNotIn("brandTagline",win)
        self.assertNotIn("local mark = Chrome.Icon(brandArea",win)
        self.assertIn("function Window.PlaceBrandBefore(searchBox)",win)

    def test_single_ornamental_skin_per_component(self):
        nav=lua("UI/Navigation.lua")
        options=lua("UI/Options.lua")
        header=lua("UI/Header.lua")
        self.assertIn('Style.PlateImage(button, "hall", "ARTWORK", 2)',nav)
        self.assertIn('Style.Plate(sub, "dark", { corner=10 })',nav)
        self.assertNotIn('Style.Skin(sub, C.nav',nav)
        self.assertNotIn('Style.Skin(button, C.button',nav)
        self.assertIn('item.bar:SetShown(false)',nav)
        self.assertIn('Style.Plate(card, "cardBody"',options)
        self.assertNotIn('Style.Skin(card, C.nav',options)
        self.assertIn('DuelOptionsBanner.png',options)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',options)
        self.assertIn('Style.Plate(b, name == "Close" and "hall" or "dark"',header)
        self.assertNotIn('Style.Skin(b, name == "Close"',header)

    def test_neutral_background_and_no_extra_decorative_outline(self):
        style=lua("UI/Style.lua")
        window=lua("UI/Window.lua")
        self.assertIn('window="0F1011"',style)
        self.assertIn('rail="0D0E0F"',style)
        self.assertIn('header="090A0B"',style)
        self.assertNotIn('Style.ForgedEdge(frame,',window)
        self.assertNotIn('Style.ForgedEdge(rail,',window)

    def test_buttons_search_and_options_still_independent(self):
        nav=lua("UI/Navigation.lua")
        header=lua("UI/Header.lua")
        options=lua("UI/Options.lua")
        for text in ('ns.Search.Register("page:" .. section.key',
                     'button:SetScript("OnClick", function() Select(index, 1) end)',
                     'sub:SetScript("OnClick", function() Select(index, pageIndex) end)'):
            self.assertIn(text,nav)
        self.assertIn('function Header.Fold(value)',header)
        self.assertIn('function Header.SetManualPeek(on)',header)
        self.assertIn('function appearance:Relayout(width)',options)
        self.assertIn('function interface:Relayout(width)',options)

if __name__=="__main__": unittest.main()

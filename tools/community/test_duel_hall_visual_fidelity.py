"""Screenshot-driven visual contract checks for the Duel Hall WoW UI.

These are structural tests. They cannot prove the pixels rendered inside WoW.
The reference is the user's approved 1536x1024 concept and 1119x700
in-game comparison from the 2026-11-21 review.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def lua(name):
    return (ROOT / name).read_text(encoding="utf-8")

class VisualFidelityTests(unittest.TestCase):
    def test_header_is_still_compact_with_full_native_controls(self):
        w, h = lua("UI/Window.lua"), lua("UI/Header.lua")
        for token in ('header:SetHeight(72)', 'rail:SetWidth(226)',
                      'footer:SetHeight(50)', 'DuelExactBrand.png',
                      'Drag(brandDrag)', 'local brandArea = CreateFrame',
                      'Style.Text(content, "Welcome to the Hall", 27, C.pale, nil, "display")'):
            self.assertIn(token, w)
        for token in ('name == "Close" and 34 or 29', 'Style.Plate(b, name == "Close" and "hall" or "dark", { corner=7 })',
                      'function Header.Fold(value)', 'function Header.CloseSearch(',
                      'function Header.SetManualPeek(on)'):
            self.assertIn(token, h)

    def test_primary_hall_is_a_standalone_crimson_plaque(self):
        n = lua("UI/Navigation.lua")
        self.assertIn('local HALL_BUTTON_WIDTH = 205', n)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)', n)
        self.assertIn('Style.ConceptImage(button, "hall", "ARTWORK", 2)', n)
        self.assertNotIn('DuelHallLaurel.tga', n)
        self.assertIn('railDivider:SetPoint("TOP", primaryButtons[#primaryButtons].button', n)
        self.assertIn('Window.rail:SetScript("OnSizeChanged", FitTabs)', n)
        self.assertIn('button:SetSize(104, 30)', n)
        self.assertIn('sub:SetSize(174, 35)', n)
        self.assertIn('DuelCategoryIcons.tga', n)

    def test_readable_display_font_does_not_override_user_font_choice(self):
        style, options = lua("UI/Style.lua"), lua("UI/Options.lua")
        self.assertIn('function Style.Text(parent, value, size, color, outline, role)', style)
        self.assertIn('role=role', style)
        self.assertIn('fontPath or', style)
        self.assertIn('entry.role == "display" and "Fonts\\\\MORPHEUS.TTF"', style)
        self.assertIn('local heading = Style.Text(header, title, 22, C.pale, nil, "display")', options)
        self.assertIn('function Style.ForgedEdge(parent, opts)', style)
        self.assertIn('Style.Plate(card, "cardBody", { corner=15 })', options)
        self.assertIn('local headingBand = CreateFrame("Frame", nil, card)', options)

    def test_compact_options_reflow_and_explicit_font_matching(self):
        options, settings = lua("UI/Options.lua"), lua("Core/Settings.lua")
        self.assertIn('local CARD_BREAKPOINT = 720', options)
        self.assertIn('width >= (largeText and 1080 or CARD_BREAKPOINT)', options)
        self.assertIn('if key == "matchFont" then return false end', settings)
        self.assertIn('if type(stored) == "boolean" then return stored end', settings)
        self.assertIn('db.uiTheme = nil', settings)
        self.assertIn('db.matchColors = nil', settings)
        self.assertIn('local duelHall = {', lua("UI/Style.lua"))
        self.assertNotIn('themeChoice', options)

    def test_no_extra_gameplay_and_esc_menu_code_unchanged_in_scope(self):
        n = lua("UI/Navigation.lua")
        self.assertIn('local primaryKeys = { hall = true }', n)
        self.assertIn('ns.Search.Register("page:" .. section.key', n)
        self.assertIn('SetPatchUnread = function(unread)', n)
        self.assertNotIn('SetScript("OnUpdate"', n)
        self.assertIn('function Theme.IsAvailable()', lua("UI/Theme.lua"))
        self.assertTrue((ROOT / "UI" / "GameMenu.lua").is_file())

if __name__ == "__main__":
    unittest.main()

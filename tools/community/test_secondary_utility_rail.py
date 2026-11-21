"""Navigation ownership: main gameplay left, subpages within content, utilities footer."""
from pathlib import Path
import unittest
BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def read(path):
    return (BASE / path).read_text(encoding="utf-8")

class UtilityRailTests(unittest.TestCase):
    def test_distinct_primary_secondary_and_subpage_owners(self):
        w, n = read("UI/Window.lua"), read("UI/Navigation.lua")
        for token in (
            'local primaryKeys = { hall = true }',
            'local railButtons, primaryButtons, subButtons = {}, {}, {}',
            'local parent = isPrimary and Window.rail or Window.utility',
            'local HALL_BUTTON_WIDTH = 205',
            'button:SetSize(HALL_BUTTON_WIDTH, 84)',
            'button:SetSize(112, 30)',
            '(utilityIndex - 1) * 120',
            'sub:SetSize(174, 35)',
            'Window.nav:SetShown(#section.pages > 1)',
            'local function FitTabs(self, width)',
            'local function FitSubTabs(self, width)',
        ):
            self.assertIn(token, n)
        self.assertIn('Window.utility = utility', w)
        self.assertIn('utility:SetPoint("RIGHT", footer, "RIGHT", -187, 0)', w)
        self.assertIn('nav:SetPoint("TOPLEFT", content, "TOPLEFT", 22, -83)', w)
        self.assertIn('main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)', w)
        self.assertNotIn('nav:SetWidth(210)', w)

    def test_secondary_links_are_compact_and_future_main_tabs_have_room(self):
        n = read("UI/Navigation.lua")
        for key in ('community','patchnotes','options'):
            self.assertIn('key = "' + key + '"', n)
        self.assertIn('if isPrimary then primaryButtons[#primaryButtons + 1] = item end', n)
        self.assertIn('button:SetPoint("TOP", self, "TOP", 0, -31 - (i - 1) * 99)', n)
        self.assertIn('button:SetPoint("LEFT", Window.utility, "LEFT",', n)
        self.assertNotIn('button:SetSize(90, 90)', n)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)', n)
        self.assertIn('Style.ConstrainButtonLabel(button, label, 35, 7, 9)', n)

    def test_native_appearance_interface_tabs_do_not_enter_gameplay_rail(self):
        n = read("UI/Navigation.lua")
        self.assertIn('if page.key == "options" or page.key == "interface" then', n)
        self.assertIn('glyph:SetSize(28, 28)', n)
        self.assertIn('local sub = CreateFrame("Button", nil, Window.nav)', n)
        self.assertIn('Style.Plate(sub, "dark", { corner=10 })', n)
        self.assertIn('sub:SetScript("OnClick", function() Select(index, pageIndex) end)', n)
        self.assertIn('item.label:SetTextColor(unpack(active and C.tabText or C.text))', n)

    def test_premium_skin_motion_search_unread_and_fold_stay_owned(self):
        n, w, st, h = (read(p) for p in ("UI/Navigation.lua", "UI/Window.lua",
                                       "UI/Style.lua", "UI/Header.lua"))
        for token in ('local selected = Style.FeedbackOverlay(button',
                      'local hover = Style.FeedbackOverlay(button',
                      'Motion.Fade(hover, active and 0.16 or',
                      'ns.Widgets.PressFeedback(button, hover, {',
                      'patchPulse:SetLooping("BOUNCE")',
                      'ns.Search.Register("page:" .. section.key',
                      'SetPatchUnread = function(unread)',
                      'SelectKey = function(sectionKey, pageKey)'):
            self.assertIn(token, n)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', st)
        self.assertIn('Window.body:Hide()', h)
        self.assertIn('Window.rail:Hide()', h)
        self.assertIn('Window.body:Show()', h)
        self.assertIn('Window.rail:Show()', h)
        self.assertNotIn('SetScript("OnUpdate"', n)
        self.assertIn('function Window.ResetWindow()', w)

if __name__ == "__main__":
    unittest.main()

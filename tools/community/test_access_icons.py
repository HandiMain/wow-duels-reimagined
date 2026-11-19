"""Source-level regression checks; CI Lua parser performs syntax checks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"

def read(path):
    return (ADDON / path).read_text(encoding="utf-8")

class AccessIconsTests(unittest.TestCase):
    def test_toc_order_and_existing_addon_icon(self):
        toc = read("DuelsReimagined.toc")
        self.assertIn("UI\\AccessIcons.lua", toc)
        self.assertLess(toc.index("Core\\Settings.lua"), toc.index("UI\\AccessIcons.lua"))
        self.assertLess(toc.index("UI\\Options.lua"), toc.index("UI\\AccessIcons.lua"))
        self.assertIn("DuelsReimagined-AddonIcon.blp", read("UI/AccessIcons.lua"))

    def test_minimap_and_widget_modes(self):
        s = read("Core/Settings.lua")
        a = read("UI/AccessIcons.lua")
        self.assertIn('iconMode = "minimap"', s)
        self.assertIn("widget = true, both = true, none = true", s)
        self.assertIn('iconMode == "minimap" or iconMode == "both"', a)
        self.assertIn('iconMode == "widget" or iconMode == "both"', a)
        self.assertIn('Settings.GetWidgetPosition()', a)
        self.assertIn('Settings.SetWidgetPosition(x - cx, y - cy)', a)
        self.assertIn("Settings.SetMinimapAngle(pendingMinimapAngle)", a)
        self.assertIn("function Settings.ResetAccessPositions()", s)

    def test_only_left_click_and_no_quick_menu(self):
        a = read("UI/AccessIcons.lua")
        self.assertIn('button:RegisterForClicks("LeftButtonUp")', a)
        self.assertIn('if which ~= "LeftButton"', a)
        self.assertIn("ns.Window.Toggle()", a)
        self.assertNotIn("RightButtonUp", a)
        for forbidden in ("PatchNotes", "ShowQuickActions", "ToggleQuickActions",
                          "UISounds.Play", "GameTooltip:SetOwner"):
            self.assertNotIn(forbidden, a)

    def test_self_disarming_motion_and_drag(self):
        a = read("UI/AccessIcons.lua")
        self.assertIn('Motion.Value(root, root:GetScale()', a)
        self.assertIn("Motion.Value(sweep, 0, 1, 0.28", a)
        self.assertIn("button.duelsIdleToken", a)
        self.assertIn('self:SetScript("OnUpdate", nil)', a)
        self.assertIn("Minimap:HookScript", a)
        self.assertIn("GetMinimapShape", a)
        self.assertIn('self:StartMoving()', a)
        self.assertIn('self:StopMovingOrSizing()', a)
        self.assertIn("self.duelsDraggedThisPress", a)

    def test_settings_visible_searchable(self):
        o = read("UI/Options.lua")
        s = read("Core/Settings.lua")
        self.assertIn('Section(accessCard, "Access icons"', o)
        for name in ("iconMode", "widgetSize", "widgetTransparency",
                     "resetIconPositions"):
            self.assertIn('RegisterOption("' + name + '"', o)
        self.assertIn("SetAvailable(hasWidget)", o)
        self.assertIn("formatValue and formatValue(clean)", read("UI/Widgets.lua"))
        self.assertIn('outsideWindow', read("UI/Tooltips.lua"))
        self.assertIn('db.widgetPosition = nil', s)

    def test_hall_revert_and_unrelated_sections(self):
        n = read("UI/Navigation.lua")
        c = read("UI/Chrome.lua")
        self.assertIn('key = "hall", label = "Hall", icon = "Hall", pages = {', n)
        self.assertNotIn("primary = true", n)
        self.assertNotIn("PrimaryRail", n)
        self.assertNotIn("PrimaryRail", c)
        self.assertIn('button:SetSize(86, 68)', n)
        self.assertIn('key = "community", label = "Community"', n)
        self.assertIn('key = "options", label = "Options"', n)

if __name__ == "__main__":
    unittest.main()

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
        self.assertIn('Section(accessCard, "Minimap button"', o)
        for name in ("iconMode", "widgetSize", "widgetTransparency",
                     "resetIconPositions"):
            self.assertIn('RegisterOption("' + name + '"', o)
        self.assertIn("SetAvailable(hasWidget)", o)
        self.assertIn("formatValue and formatValue(clean)", read("UI/Widgets.lua"))
        self.assertIn('outsideWindow', read("UI/Tooltips.lua"))
        self.assertIn('RegisterOption("minimapButton"', o)
        self.assertIn('db.widgetPosition = nil', s)

    def test_launcher_tooltip_handlers_and_context(self):
        a = read("UI/AccessIcons.lua")
        t = read("UI/Tooltips.lua")
        start = a.index("local function ConnectClick(button, isWidget)")
        end = a.index("-- Polestar/Ellesmere collector interoperability:", start)
        block = a[start:end]
        self.assertLess(block.index('button:SetScript("OnEnter"'),
                        block.index("Tooltips.Bind(button, function()"))
        self.assertLess(block.index('button:SetScript("OnLeave"'),
                        block.index("Tooltips.Bind(button, function()"))
        self.assertIn('Left-click: Open the window.', block)
        self.assertIn('Left-click: Close the window.', block)
        self.assertIn('Drag: Move around the minimap.', block)
        self.assertIn('outsideWindow = true', block)
        self.assertIn('local data = Value(source, owner)', t)

    def test_live_widget_sliders_without_full_refresh(self):
        o, w, s = read("UI/Options.lua"), read("UI/Widgets.lua"), read("Core/Settings.lua")
        self.assertIn('function Options.RefreshAccessModified()', o)
        self.assertIn('if live then CommitLive(clean) end', w)
        self.assertIn('if programmatic or not (fromUser or dragging) then return end', w)
        self.assertIn('function row:IsDragging()', w)
        self.assertIn('ns.Options.RefreshAccessModified()', s)
        self.assertIn('.. " px" end, true)', o)
        self.assertIn('end, nil, true)', o)
        self.assertIn('RegisterOption("minimapButton"', o)

    def test_compartment_toggle_and_collector_contract(self):
        s, a, o = read("Core/Settings.lua"), read("UI/AccessIcons.lua"), read("UI/Options.lua")
        self.assertIn('showInCompartment = true', s)
        self.assertIn('Settings.RegisterReloadRequired("showInCompartment")', a)
        self.assertIn('not Settings.Get("showInCompartment")', a)
        self.assertIn('"showInCompartment", "Show in AddOn Compartment"', o)
        self.assertIn("needsCompartment", o)
        self.assertIn('CreateFrame("Button", "DuelsReimaginedMinimapButton", Minimap or UIParent)', a)
        self.assertIn('local function OwnsMinimapPlacement()', a)
        self.assertIn('elseif not lastMiniWanted then', a)
        self.assertNotIn('elseif OwnsMinimapPlacement() then', a)
        self.assertIn('miniButton:GetParent() ~= Minimap', a)
        self.assertIn('Settings.NeedsReload()', read("UI/Footer.lua"))

    def test_hall_revert_and_unrelated_sections(self):
        n = read("UI/Navigation.lua")
        c = read("UI/Chrome.lua")
        self.assertIn('key = "hall", label = "Hall", icon = "Hall", pages = {', n)
        self.assertNotIn("primary = true", n)
        self.assertNotIn("PrimaryRail", n)
        self.assertNotIn("PrimaryRail", c)
        self.assertIn('button:SetSize(216, 44)', n)
        self.assertIn('button:SetSize(70, 90)', n)
        self.assertIn('button:SetPoint("LEFT", Window.rail, "LEFT",', n)
        self.assertIn('key = "community", label = "Community"', n)
        self.assertIn('key = "options", label = "Options"', n)

if __name__ == "__main__":
    unittest.main()

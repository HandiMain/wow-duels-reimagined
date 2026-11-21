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
        self.assertIn("DuelsDRIcon.png", toc)
        self.assertIn("DuelsDRIcon.png", read("UI/AccessIcons.lua"))
        self.assertNotIn("DuelsReimagined-AddonIcon.blp", toc)
        self.assertNotIn("DuelsCrestIcon.png", read("UI/AccessIcons.lua"))
        self.assertEqual(toc.count("DuelsDRIcon.png"), 1)
        self.assertEqual(read("UI/AccessIcons.lua").count("DuelsDRIcon.png"), 1)
        a = read("UI/AccessIcons.lua")
        for marker in ("glow:SetTexture(ICON)", "ring:SetTexture(ICON)",
                       "mark:SetTexture(ICON)", "highlight:SetTexture(ICON)"):
            self.assertIn(marker, a)

    def test_selected_icon_wow_asset_uses_128_png_with_transparency(self):
        import struct
        raw = (ADDON / "Media" / "Icons" / "DuelsDRIcon.png").read_bytes()
        self.assertEqual(raw[:8], b"\x89PNG\r\n\x1a\n")
        width, height, depth, color_type = struct.unpack(">IIBB", raw[16:26])
        self.assertEqual((width, height), (128, 128))
        self.assertEqual((depth, color_type), (8, 3))
        self.assertIn(b"tRNS", raw)  # Transparent area outside the DR badge
        self.assertIn(b"IDAT", raw)
        self.assertLess(len(raw), 25000)

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
        # Patch Notes MAY trigger a visual-only update ping. Still forbid
        # opening a Patch Notes menu from the DR icon or adding right clicks.
        for forbidden in ('ns.PatchNotes.Show', 'Navigation.SelectKey("patchnotes"',
                          "ShowQuickActions", "ToggleQuickActions",
                          "UISounds.Play", "GameTooltip:SetOwner"):
            self.assertNotIn(forbidden, a)
        self.assertIn("function Access.NotifyPatchNotes(unread)", a)
        self.assertIn("local ring = target.duelsFace.ring", a)

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
        self.assertIn('Section(accessCard, "Minimap & widget"', o)
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
        end = a.index("-- Independent minimap icon (Narcissus/BurstFX):", start)
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

    def test_independent_minimap_avoids_ellesmere_collection(self):
        # EllesmereUI 9.8.9 only scans direct Minimap/flyout children.
        # Narcissus can keep its button independent under UIParent.
        a = read("UI/AccessIcons.lua")
        self.assertIn('CreateFrame("Button", "DuelsReimaginedMinimapButton", UIParent)', a)
        self.assertIn('miniButton:GetParent() ~= UIParent', a)
        self.assertIn('miniButton:SetPoint("CENTER", Minimap, "CENTER", x, y)', a)
        self.assertIn('Minimap:HookScript("OnHide"', a)
        self.assertIn('Minimap:HookScript("OnShow"', a)
        self.assertIn('Minimap:HookScript("OnSizeChanged"', a)
        self.assertIn('miniButton:SetShown(miniWanted and true or false)', a)
        self.assertIn('placementMode = "independent"', a)
        self.assertNotIn('lastMiniWanted', a)
        self.assertIn('if not OwnsMinimapPlacement() then return end', a)
        self.assertIn('Settings.SetMinimapAngle(pendingMinimapAngle)', a)
        self.assertNotIn('C_Timer.NewTicker', a)

    def test_independent_visibility_tracks_minimap_and_mode(self):
        a = read("UI/AccessIcons.lua")
        self.assertIn('local initialMode = Mode()', a)
        self.assertIn('miniButton:SetShown(Minimap and Minimap:IsShown() and', a)
        self.assertIn('(initialMode == "minimap" or initialMode == "both"))', a)
        self.assertIn('local miniWanted = loginReady and Minimap and Minimap:IsShown() and', a)
        self.assertIn('miniButton:SetShown(miniWanted and true or false)', a)
        self.assertIn('widgetButton:SetShown(loginReady and', a)
        for mode, expected in (("minimap", True), ("both", True),
                               ("widget", False), ("none", False)):
            self.assertEqual(mode in ("minimap", "both"), expected)

    def test_collector_controls_minimap_root_alpha_not_our_idle_effect(self):
        a = read("UI/AccessIcons.lua")
        self.assertIn('Motion.Fade(button == miniButton and button.duelsFace.icon or button, 1, 0.16)', a)
        self.assertEqual(a.count('Motion.Fade(button.duelsFace.icon, IDLE_ALPHA, 0.30)'), 2)
        self.assertNotIn('Motion.Fade(button, IDLE_ALPHA', a)
        self.assertIn('if isWidget then\n            Motion.Stop(self, 1)\n        else\n            Motion.Stop(face.icon, 1)', a)
        self.assertIn('Motion.Fade(button, target, 0.18)', a) # floating-widget settings still live
        self.assertIn('if not OwnsMinimapPlacement()', a) # drag respects collector ownership
        self.assertIn('miniButton:GetParent() ~= UIParent', a)
        self.assertNotIn('C_Timer.NewTicker', a)
        self.assertIn('Minimap:HookScript("OnShow"', a)
        self.assertIn('Minimap:HookScript("OnSizeChanged"', a)

    def test_compartment_toggle_and_collector_contract(self):
        s, a, o = read("Core/Settings.lua"), read("UI/AccessIcons.lua"), read("UI/Options.lua")
        self.assertIn('showInCompartment = true', s)
        self.assertIn('Settings.RegisterReloadRequired("showInCompartment")', a)
        self.assertIn('not Settings.Get("showInCompartment")', a)
        self.assertIn('"showInCompartment", "Show in AddOn Compartment"', o)
        self.assertIn("needsCompartment", o)
        self.assertIn('CreateFrame("Button", "DuelsReimaginedMinimapButton", UIParent)', a)
        self.assertIn('local function OwnsMinimapPlacement()', a)
        self.assertIn('miniButton:SetShown(miniWanted and true or false)', a)
        self.assertNotIn('elseif OwnsMinimapPlacement() then', a)
        self.assertIn('miniButton:GetParent() ~= UIParent', a)
        self.assertIn('Settings.NeedsReload()', read("UI/Footer.lua"))

    def test_hall_revert_and_unrelated_sections(self):
        n = read("UI/Navigation.lua")
        c = read("UI/Chrome.lua")
        self.assertIn('key = "hall", label = "Hall", icon = "Hall", pages = {', n)
        self.assertNotIn("primary = true", n)
        self.assertNotIn("PrimaryRail", n)
        self.assertNotIn("PrimaryRail", c)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)', n)
        self.assertIn('button:SetSize(104, 30)', n)
        self.assertIn('button:SetPoint("TOP", Window.rail, "TOP",', n)
        self.assertIn('key = "community", label = "Community"', n)
        self.assertIn('key = "options", label = "Options"', n)

if __name__ == "__main__":
    unittest.main()

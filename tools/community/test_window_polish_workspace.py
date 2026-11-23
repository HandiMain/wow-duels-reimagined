"""Regression contracts for the approved 2026-11 window polish batch.

Source checks are automated evidence, not an in-game WoW runtime PASS.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class WindowPolishWorkspaceTests(unittest.TestCase):
    def test_logo_is_static_again_but_original_brand_and_drag_remain(self):
        w = read("UI/Window.lua")
        self.assertIn("DuelBrand.png", w)
        self.assertNotIn("BrandLayer(", w)
        self.assertIn("Drag(brandDrag)", w)
        self.assertNotIn('brandLogo:SetScript("OnEnter"', w)
        self.assertNotIn("MakeShimmerBand", w)
        self.assertNotIn("HideBrandShimmer", w)
        self.assertNotIn("shimmerKey", w)

    def test_magnet_snap_with_opt_out_and_alignment_guides(self):
        w = read("UI/Window.lua")
        self.assertIn("local MAGNET_GAP, MAGNET_RANGE = 14, 24", w)
        self.assertIn('if IsAltKeyDown and IsAltKeyDown() then return nil, nil end', w)
        self.assertIn('guideX:SetSize(2, 96)', w)
        self.assertIn('guideY:SetSize(112, 2)', w)
        self.assertIn('Motion.Value(snapKey, 0, 1, 0.13', w)
        self.assertIn('frame:SetClampedToScreen(true)', w)
        self.assertIn('local function FinishSnap()', w)
        self.assertIn('self:SetScript("OnUpdate", function() DrawGuides() end)', w)
        self.assertIn('self:SetScript("OnUpdate", nil)', w)
        self.assertIn('handle:HookScript("OnHide"', w)
        self.assertIn('function Window.CancelMagnet()', w)
        self.assertIn('Motion.Stop(snapKey)', w)
        self.assertNotIn("C_Timer.NewTicker", w)
        self.assertNotIn('driver:SetScript("OnUpdate"', w)

    def test_snap_never_fights_fold_scale_and_resize(self):
        win, header = read("UI/Window.lua"), read("UI/Header.lua")
        self.assertIn('function Window.ApplyScale(value)\n    Window.CancelMagnet()', win)
        self.assertIn('function Header.Fold(value)\n    if Window.CancelMagnet then Window.CancelMagnet() end', header)
        self.assertIn('Motion.Stop(snapKey)', win)
        self.assertIn('frame:StartSizing("BOTTOMRIGHT")', win)
        self.assertIn('Window.CommitResize()', win)
        self.assertIn('Window.SetSizingEnabled(on)', win)
        self.assertIn('Window.closeButton = close', win)

    def test_compact_back_is_in_footer_with_real_close_anchor(self):
        nav, win = read("UI/Navigation.lua"), read("UI/Window.lua")
        self.assertIn('Style.Action(Window.content, "Back", "footer", {', nav)
        self.assertIn('backButton:SetSize(60, 24)', nav)
        self.assertIn('backButton:SetPoint("TOPRIGHT", Window.content, "TOPRIGHT", -24, -25)', nav)
        self.assertIn('ns.Tooltips.Bind(backButton', nav)
        self.assertNotIn('Style.Action(Window.rail, "Back")', nav)
        self.assertIn('close:SetSize(105, 30)', win)
        self.assertIn('Window.closeButton = close', win)
        self.assertIn('if backButton then backButton:SetShown(#history > 0) end', nav)
        self.assertIn('ns.Search.Register("navigation:back", "Back", "Navigation",', nav)

    def test_last_workspace_uses_only_central_account_savedvariables(self):
        settings, nav = read("Core/Settings.lua"), read("UI/Navigation.lua")
        self.assertIn('function Settings.GetWorkspace()', settings)
        self.assertIn('function Settings.SetWorkspace(section, page, scroll)', settings)
        self.assertIn('db.lastWorkspace = { section = section, page = page, scroll = offset }', settings)
        self.assertIn('value:match("^[%w%-]+$")', settings)
        self.assertIn('math.min(60000, value)', settings)
        self.assertIn('if type(state) ~= "table"', settings)
        self.assertIn('local workspaceReady = false', nav)
        self.assertIn('ns.Settings.SetWorkspace(section.key, page.key, offset)', nav)
        self.assertNotIn('_G.DuelsReimaginedDB', nav)
        self.assertNotIn('navigationHistory', settings)
        self.assertIn('if #history >= 12 then table.remove(history, 1) end', nav)

    def test_resume_only_when_actually_open_not_during_addon_load(self):
        nav, win = read("UI/Navigation.lua"), read("UI/Window.lua")
        self.assertIn('ResumeWorkspace = function()', nav)
        self.assertIn('if workspaceReady then return end', nav)
        self.assertIn('local sectionKey, pageKey, offset = ns.Settings.GetWorkspace()', nav)
        self.assertIn('scrollMemory[sectionKey .. ":" .. pageKey] = offset', nav)
        self.assertIn('Select(i, j, true, false, true)', nav)
        self.assertIn('Select(1, 1, true)', nav)
        self.assertIn('frame:Show()', win)
        self.assertIn('ns.Navigation.ResumeWorkspace()', win)
        self.assertLess(win.index("frame:Show()\n        frame:Raise()"),
                        win.index("ns.Navigation.ResumeWorkspace()"))
        self.assertIn('logout:RegisterEvent("PLAYER_LOGOUT")', nav)
        self.assertIn('if workspaceReady then CapturePage() end', nav)

    def test_scroll_is_owned_by_each_actual_page_not_navigation(self):
        nav = read("UI/Navigation.lua")
        self.assertIn('local function ScrollOwner(page)', nav)
        self.assertIn('owner.GetPageScroll(page.key)', nav)
        self.assertIn('owner.SetPageScroll(page.key, scrollMemory[id] or 0)', nav)
        for owner in ("Options", "Community", "PatchNotes"):
            code = read("UI/" + owner + ".lua")
            self.assertIn('function ' + owner + '.GetPageScroll(', code)
            self.assertIn('function ' + owner + '.SetPageScroll(', code)
            self.assertIn('scroll:SetVerticalScroll(', code)
        self.assertIn('page.scrollBar:Refresh()', read('UI/Options.lua'))
        self.assertIn('bar:Refresh()', read('UI/Community.lua'))
        self.assertIn('bar:Refresh()', read('UI/PatchNotes.lua'))

    def test_persist_scroll_when_leaving_closing_or_reloading(self):
        nav = read("UI/Navigation.lua")
        self.assertIn('if not repaintOnly and priorSection then CapturePage() end', nav)
        self.assertIn('if workspaceReady then CapturePage() end', nav)
        self.assertIn('logout:RegisterEvent("PLAYER_LOGOUT")', nav)
        self.assertIn('Window.frame:HookScript("OnHide"', nav)
        self.assertIn('for i = #history, 1, -1 do history[i] = nil end', nav)
        self.assertIn('not repaintOnly and not isBack', nav)
        self.assertIn('if repaintOnly then return end', nav)

    def test_new_labels_dismiss_on_sighting_not_only_after_click(self):
        feedback, settings = read("UI/Feedback.lua"), read("Core/Settings.lua")
        self.assertIn('badge:HookScript("OnShow", function(self)', feedback)
        self.assertIn('Later(2.0, function()', feedback)
        self.assertIn('parent:HookScript("OnEnter", Seen)', feedback)
        self.assertIn('not Window.frame:IsVisible()', feedback)
        self.assertIn('local owner = parent.optionsScroll', feedback)
        self.assertIn('Feedback.Acknowledge(id)', feedback)
        self.assertIn('Settings.MarkDiscoverySeen(id)', feedback)
        self.assertIn('db.discoverySeen[id] = true', settings)
        self.assertIn('if type(db.discoverySeen) ~= "table"', settings)

    def test_notifications_always_anchor_at_real_button_and_do_not_block(self):
        feedback, footer = read("UI/Feedback.lua"), read("UI/Footer.lua")
        self.assertIn('function Feedback.Toast(message, button)', feedback)
        self.assertIn('not button or not button:IsVisible()', feedback)
        self.assertIn('toast:ClearAllPoints()', feedback)
        self.assertIn('toast:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -2, 8)', feedback)
        self.assertNotIn('toast:SetPoint("TOP", Window.content', feedback)
        self.assertIn('toast:EnableMouse(false)', feedback)
        self.assertEqual(footer.count('Feedback.Toast("Window layout restored", reset)'), 2)
        self.assertIn('if token ~= toastToken then return end', feedback)
        self.assertIn('Window.frame:HookScript("OnHide"', feedback)

    def test_saved_interface_and_no_accidental_new_engines(self):
        toc, window, access, settings = (
            read("DuelsReimagined.toc"), read("UI/Window.lua"),
            read("UI/AccessIcons.lua"), read("Core/Settings.lua"))
        self.assertNotIn('SkinDecor', toc)
        self.assertIn('db.uiTheme = nil', settings)
        self.assertIn('CreateFrame("Button", "DuelsReimaginedMinimapButton", UIParent)', access)
        self.assertIn('local HALL_BUTTON_WIDTH = 205', read("UI/Navigation.lua"))
        self.assertIn('UI\\Motion.lua', toc)
        self.assertIn('UI\\Feedback.lua', toc)
        self.assertNotIn('PlaySound(', window)
        self.assertNotIn('PlaySoundFile(', window)
        self.assertNotIn('SetScript("OnUpdate"', read("UI/Feedback.lua"))

if __name__ == "__main__":
    unittest.main()

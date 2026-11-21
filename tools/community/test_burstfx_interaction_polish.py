"""Source contracts for nine deliberately focused BurstFX-derived UI ideas.

This is NOT a live WoW test: target focus, layering, alpha, and interaction
feel still require the player to verify them with EllesmereUI enabled.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class BurstFXInteractionPolishTests(unittest.TestCase):
    def test_feedback_loaded_after_owners_before_consumers(self):
        toc = read("DuelsReimagined.toc")
        for before, after in [
            ("Core\\Settings.lua", "UI\\Feedback.lua"),
            ("UI\\Motion.lua", "UI\\Feedback.lua"),
            ("UI\\Style.lua", "UI\\Feedback.lua"),
            ("UI\\Window.lua", "UI\\Feedback.lua"),
            ("UI\\Feedback.lua", "UI\\Navigation.lua"),
            ("UI\\Feedback.lua", "UI\\Options.lua"),
            ("UI\\Feedback.lua", "UI\\Footer.lua"),
        ]:
            self.assertLess(toc.index(before), toc.index(after))
        self.assertEqual(toc.count("UI\\Feedback.lua"), 1)

    def test_patch_note_link_finds_the_real_option_then_pulses_twice(self):
        opt, notes, motion, feedback = (
            read("UI/Options.lua"), read("UI/PatchNotes.lua"),
            read("UI/Motion.lua"), read("UI/Feedback.lua"))
        self.assertIn('ns.Search.Register("setting:" .. key', opt)
        self.assertIn('ns.Navigation.SelectKey("options", pageKey)', opt)
        self.assertIn("sf:SetVerticalScroll(", opt)
        self.assertIn("ns.Feedback.PulseTarget(widget)", opt)
        self.assertIn('if item then Search.Open(item) end', notes)
        self.assertIn('function Feedback.PulseTarget(target)', feedback)
        self.assertIn('math.sin(progress * math.pi * 2)^2', feedback)
        self.assertIn('if activeTarget and activeTarget ~= target then ClearTarget(activeTarget)', feedback)
        self.assertIn('Settings.Get("reduceMotion")', feedback)
        self.assertIn("Motion.Value(target, 0, 1", feedback)
        self.assertIn('function Motion.Value(', motion)
        self.assertNotIn('SetScript("OnUpdate"', feedback)

    def test_selection_slides_on_real_page_change_not_theme_repaint(self):
        nav = read("UI/Navigation.lua")
        self.assertIn('local movingBar = Style.Fill(Window.nav, C.gold, "OVERLAY")', nav)
        self.assertIn('Motion.Value(movingBar, movingIndex or pageIndex, pageIndex,', nav)
        self.assertIn('priorSection == sectionIndex', nav)
        self.assertIn('if repaintOnly then return end', nav)
        self.assertIn('local changed = priorSection ~= sectionIndex or priorPage ~= pageIndex', nav)
        self.assertIn('local function PlaceBar(_, index)', nav)
        self.assertIn('Window.frame:HookScript("OnHide"', nav)

    def test_page_sweep_short_lived_and_reduced_motion_safe(self):
        nav = read("UI/Navigation.lua")
        self.assertIn('local function SweepPage()', nav)
        self.assertIn('ns.Settings.Get("reduceMotion")', nav)
        self.assertIn('Motion.Value(sweep, 0, 1, 0.35', nav)
        self.assertIn('if progress >= 1 then region:Hide() end', nav)
        self.assertIn('if changed and not noMotion then SweepPage() end', nav)
        self.assertNotIn('C_Timer.NewTicker', nav)

    def test_discovery_is_account_owned_not_fake_game_state(self):
        settings, feedback, nav, opts = (
            read("Core/Settings.lua"), read("UI/Feedback.lua"),
            read("UI/Navigation.lua"), read("UI/Options.lua"))
        self.assertIn('local discoveries = { ["navigation-back-v1"] = true, ["widget-preview-v1"] = true }', settings)
        self.assertIn('function Settings.HasSeenDiscovery(id)', settings)
        self.assertIn('function Settings.MarkDiscoverySeen(id)', settings)
        self.assertIn('if type(db.discoverySeen) ~= "table"', settings)
        self.assertIn('if ns.Feedback then ns.Feedback.RefreshDiscovery() end', settings)
        self.assertIn('NewBadge(backButton, "navigation-back-v1")', nav)
        self.assertIn('NewBadge(widgetSize, "widget-preview-v1", true)', opts)
        self.assertIn('Settings.MarkDiscoverySeen(id)', feedback)
        self.assertNotIn('_G.DuelsReimaginedDB', feedback)

    def test_toasts_are_rare_scoped_and_nonblocking(self):
        feedback, footer = read("UI/Feedback.lua"), read("UI/Footer.lua")
        self.assertIn('local toast = CreateFrame("Frame", nil, Window.frame)', feedback)
        self.assertIn('toast:EnableMouse(false)', feedback)
        self.assertIn('function Feedback.Toast(message, button)', feedback)
        self.assertIn('if token ~= toastToken then return end', feedback)
        self.assertIn('Window.frame:HookScript("OnHide"', feedback)
        self.assertIn('ns.Feedback.Toast("Window layout restored", reset)', footer)
        self.assertNotIn('FULLSCREEN_DIALOG', feedback)
        self.assertNotIn('C_Timer.NewTicker', feedback)

    def test_action_confirmation_restores_original_real_label(self):
        feedback, opts, style = read("UI/Feedback.lua"), read("UI/Options.lua"), read("UI/Style.lua")
        self.assertIn('button.label = label', style)
        self.assertIn('function Feedback.ConfirmAction(button, message)', feedback)
        self.assertIn('button.label:SetText(message)', feedback)
        self.assertIn('button.label:SetText(button.duelsOriginalLabel)', feedback)
        self.assertIn('if actionTokens[button] ~= token then return end', feedback)
        self.assertIn('ns.Feedback.ConfirmAction(resetAccess, "Positions restored")', opts)

    def test_mini_bling_keeps_proven_ellesmere_independent_parent(self):
        access, notes = read("UI/AccessIcons.lua"), read("UI/PatchNotes.lua")
        self.assertIn('CreateFrame("Button", "DuelsReimaginedMinimapButton", UIParent)', access)
        self.assertIn('miniButton:SetPoint("CENTER", Minimap, "CENTER", x, y)', access)
        self.assertIn('function Access.NotifyPatchNotes(unread)', access)
        self.assertIn('local ring = target.duelsFace.ring', access)
        self.assertIn('if pendingPatchPing then Access.NotifyPatchNotes(true) end', access)
        self.assertIn('Settings.Get("reduceMotion") then return end', access)
        self.assertIn('ns.AccessIcons.NotifyPatchNotes(unread)', notes)
        self.assertIn('if not pendingPatchPing or patchPingPlayed', access)
        self.assertNotIn('target:SetAlpha(', access)

    def test_context_preview_uses_real_saved_widget_appearance(self):
        feedback, opts = read("UI/Feedback.lua"), read("UI/Options.lua")
        self.assertIn('Feedback.BindWidgetPreview(widgetSize)', opts)
        self.assertIn('Feedback.BindWidgetPreview(widgetTransparency)', opts)
        self.assertIn('Settings.Get("widgetSize")', feedback)
        self.assertIn('Settings.Get("widgetTransparency")', feedback)
        self.assertIn('DuelsDRIcon.png', feedback)
        self.assertIn('preview:EnableMouse(false)', feedback)
        self.assertIn('row.slider:HookScript("OnEnter"', feedback)
        self.assertIn('row:HookScript("OnHide", Feedback.HidePreview)', feedback)
        self.assertIn('function Feedback.RefreshWidgetPreview()', feedback)
        self.assertIn('if preview:IsShown() then PaintWidgetPreview() end', feedback)
        self.assertIn('ns.Feedback.RefreshWidgetPreview()', opts)
        self.assertIn('hover to show a live widget preview', opts)
        self.assertNotIn('Settings.Set("widgetSize"', feedback)

    def test_back_navigation_runtime_only_doesnt_loop(self):
        nav, settings = read("UI/Navigation.lua"), read("Core/Settings.lua")
        self.assertIn('local history, backButton = {}, nil', nav)
        self.assertIn('if #history >= 12 then table.remove(history, 1) end', nav)
        self.assertIn('not repaintOnly and not isBack', nav)
        self.assertIn('Select(previous.section, previous.page, false, false, true)', nav)
        self.assertIn('for i = #history, 1, -1 do history[i] = nil end', nav)
        self.assertIn('CanGoBack = function() return #history > 0 end', nav)
        self.assertIn('ns.Search.Register("navigation:back", "Back", "Navigation",', nav)
        self.assertIn('return ns.Navigation.CanGoBack()', nav)
        self.assertNotIn('navigationHistory', settings)
        self.assertNotIn('Settings.Set("navigationHistory"', nav)

    def test_existing_interface_remains_shared_and_no_sounds(self):
        toc, nav, opts, feedback = (
            read("DuelsReimagined.toc"), read("UI/Navigation.lua"),
            read("UI/Options.lua"), read("UI/Feedback.lua"))
        self.assertNotIn('SkinDecor', toc)
        self.assertNotIn('UI\\UISounds.lua', toc)
        self.assertNotIn('PlaySound(', feedback)
        self.assertNotIn('PlaySoundFile(', feedback)
        self.assertIn('local HALL_BUTTON_WIDTH = 205', nav)
        self.assertIn('local initialMode = Mode()', read("UI/AccessIcons.lua"))
        self.assertIn('local themeChoice = Widgets.ChoiceRow(appearanceCard, "Color theme"', opts)
        self.assertIn('if key == "uiTheme" then return "duelhall" end', read("Core/Settings.lua"))

if __name__ == "__main__":
    unittest.main()

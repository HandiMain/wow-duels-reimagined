"""Escape menu integration contracts, source-only; in-game testing still required."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def src(name):
    return (ROOT / name).read_text(encoding="utf-8")

class DuelsEscapeMenuTests(unittest.TestCase):
    def test_native_button_is_optional_and_loaded_after_ui_owners(self):
        toc = src("DuelsReimagined.toc")
        self.assertEqual(toc.count("UI\\GameMenu.lua"), 1)
        for file in ("UI\\Window.lua", "UI\\Theme.lua", "UI\\Options.lua",
                     "UI\\Footer.lua"):
            self.assertLess(toc.index(file), toc.index("UI\\GameMenu.lua"))
        s = src("Core/Settings.lua")
        self.assertIn('showGameMenuButton = true', s)
        self.assertIn('elseif key == "showGameMenuButton" then', s)
        self.assertIn('ns.GameMenu.Refresh()', s)
        self.assertIn('for key, default in pairs(boolDefaults)', s)

    def test_setting_is_searchable_in_central_options_and_reflows(self):
        o = src("UI/Options.lua")
        self.assertIn('AddToggle(gameAccessCard, "interface", "showGameMenuButton"', o)
        self.assertIn('"Show Escape menu button"', o)
        self.assertIn('{ widget = gameMenuRow }', o)
        self.assertIn('RegisterOption(key, name, detail, pageKey, row)', o)
        self.assertIn('function LayoutPage(page, groups, width)', o)
        self.assertIn('card:SetHeight(cardHeight)', o)
        self.assertNotIn('Settings.RegisterReloadRequired("showGameMenuButton")', o)

    def test_uses_native_blizzard_button_in_default_and_no_eui_mode(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('menu.buttonTemplate', gm)
        self.assertIn('"MainMenuFrameButtonTemplate"', gm)
        self.assertIn('"UIPanelButtonTemplate"', gm)
        self.assertIn('b:SetText("Duels Reimagined")', gm)
        self.assertIn('if not skinned then', gm)
        self.assertIn('for tex, opacity in pairs(nativeTextures)', gm)
        self.assertIn('tex:SetAlpha(skinned and 0 or opacity)', gm)
        self.assertIn('if look then look.frame:Hide(); look.highlight:Hide() end', gm)
        self.assertNotIn('ns.Style', gm)
        self.assertNotIn('ns.Theme', gm)
        self.assertNotIn('C.gold', gm)
        self.assertNotIn('ns.Settings.Get("uiTheme")', gm)

    def test_matches_ellesmere_only_when_pause_menu_skin_is_active(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('"EllesmereUIBlizzardSkin"', gm)
        self.assertIn('db.reskinGameMenu == false', gm)
        self.assertIn('local skinned = MenuSkinActive()', gm)
        self.assertIn('_getPopupMenuButtonTextColor', gm)
        self.assertIn('_applyBlizzardConfiguredBorder', gm)
        self.assertIn('"popupMenuButton"', gm)
        self.assertIn('popupMenuButtonBackgroundColor', gm)
        self.assertIn('_G.EllesmereUI_GameMenuButton', gm)
        self.assertIn('PaintFont(b, referenceFont)', gm)
        self.assertIn('rgb .. "Duels|r |cffffffffReimagined|r"', gm)
        self.assertNotIn('EllesmereUIDB =', gm)

    def test_native_layout_when_no_manual_buttons(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('local pool = menu and menu.buttonPool', gm)
        self.assertIn('name == _G.BLIZZARD_STORE', gm)
        self.assertIn('name == _G.GAMEMENU_OPTIONS', gm)
        self.assertIn('name == _G.ADDONS', gm)
        self.assertIn('local function HasManualButtons(menu)', gm)
        self.assertIn('manualMode = HasManualButtons(menu)', gm)
        self.assertIn('child.layoutIndex == nil', gm)
        self.assertIn('not native[child]', gm)
        self.assertIn('w >= 100 and h >= 15', gm)
        self.assertIn('return first + (nextIndex - first) * 0.25', gm)
        self.assertIn('b.layoutIndex, b.topPadding = index, SECTION', gm)
        self.assertIn('placementState = "native-layout"', gm)

    def test_manual_buttons_reserve_exactly_one_own_space(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('manualMode = HasManualButtons(menu)', gm)
        self.assertIn('local function ManualSlot(menu, upper, addons)', gm)
        self.assertIn('local index = ManualSlot(menu, upper, addons)', gm)
        self.assertIn('idx > occupied and idx < last', gm)
        self.assertIn('child ~= button and child ~= spacer', gm)
        self.assertIn('spacer:SetSize(1, b:GetHeight() + GAP)', gm)
        self.assertIn('spacer.layoutIndex, spacer.topPadding = index, nil', gm)
        self.assertIn('spacer:Show()', gm)
        self.assertIn('b.layoutIndex, b.topPadding = nil, nil', gm)
        self.assertIn('placementState = "manual-reserved"', gm)
        self.assertIn('local function PlaceManual(menu)', gm)
        self.assertIn('or not button or not spacer or not spacer:IsShown()', gm)
        self.assertIn('local above, space = FindGap(menu, button, upper, addons)', gm)
        self.assertIn('space >= height + GAP * 2', gm)
        self.assertIn('local targetTop = aboveBottom - GAP', gm)
        self.assertIn('button:SetPoint("TOP", menu, "TOP", 0, -offset)', gm)
        self.assertIn('HideOwn()', gm)
        self.assertIn('if manualMode then PlaceManual(menu) end', gm)
        self.assertIn('hooksecurefunc(menu, "InitButtons"', gm)
        self.assertIn('hooksecurefunc(menu, "Layout"', gm)
        self.assertIn('menu:HookScript("OnShow"', gm)
        self.assertNotIn('HorizonSuiteGameMenuButton', gm)
        self.assertNotIn('PolestarGameMenuButton', gm)
        self.assertNotIn('C_Timer.After(', gm)
        self.assertNotIn('ScheduleSettle(', gm)
        self.assertNotIn('button:SetPoint("TOP", above, "BOTTOM"', gm)
        self.assertNotRegex(gm, r'(?m)^\s*menu:Layout\(')
        self.assertNotIn('menu:SetHeight(', gm)
        self.assertNotIn('menu:ClearAllPoints()', gm)
        self.assertNotIn('SetScript("OnUpdate"', gm)

    def test_native_mode_hides_its_optional_spacer(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('if spacer then', gm)
        self.assertIn('spacer:Hide()', gm)
        self.assertIn('spacer.layoutIndex, spacer.topPadding = nil, nil', gm)
        self.assertIn('b.layoutIndex, b.topPadding = index, SECTION', gm)
        self.assertIn('local function HideOwn()', gm)

    def test_reference_menu_geometry_model_not_live_client(self):
        # Deliberately model the *failure* reported by the player:
        # with EUI only, the gap after its 32px custom button cannot fit
        # another 32px button until OUR reserved layout slot is added.
        # These are synthetic units, not measured WoW client coordinates.
        BUTTON_HEIGHT, GAP = 32, 4
        shop_bottom = 180
        eui_bottom = shop_bottom + 12 + BUTTON_HEIGHT
        addons_top_without_us = eui_bottom + 16
        self.assertLess(addons_top_without_us - eui_bottom,
                        BUTTON_HEIGHT + 2 * GAP)
        addons_top_with_us = addons_top_without_us + BUTTON_HEIGHT + GAP
        self.assertGreaterEqual(addons_top_with_us - eui_bottom,
                                BUTTON_HEIGHT + 2 * GAP)

        # Addon-independent index reservation: each existing native layout
        # item (including Polestar's spacer or Horizon's native button)
        # is preserved, and ours occupies one additional distinct slot.
        for case, occupied in [
            ("Ellesmere only", []),
            ("Ellesmere and Polestar", [2.5]),
            ("Ellesmere and Horizon", [2.5]),
            ("Ellesmere Polestar Horizon", [2.5, 2.5]),
        ]:
            upper, addons = 2.0, 3.0
            last = max([upper] + occupied)
            index = last + (addons - last) * 0.5
            with self.subTest(case=case):
                self.assertGreater(index, last)
                self.assertLess(index, addons)
                self.assertNotIn(index, occupied)

    def test_click_closes_escape_menu_then_opens_not_toggles_away(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('"DuelsReimaginedGameMenuButton"', gm)
        self.assertIn('button:RegisterForClicks("LeftButtonUp")', gm)
        self.assertIn('if menu:IsShown() then', gm)
        self.assertIn('_G.HideUIPanel(menu)', gm)
        self.assertIn('if not window.frame:IsShown() then window.Toggle()', gm)
        self.assertIn('else window.frame:Raise() end', gm)
        self.assertNotIn('PlaySound(', gm)
        self.assertNotIn('SetScript("OnUpdate"', gm)

    def test_runtime_toggle_hides_only_our_controls_and_no_force_reload(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('function GameMenu.Refresh()', gm)
        self.assertIn('HideOwn(); placementState = "disabled"; return', gm)
        self.assertIn('if button then button:Hide() end', gm)
        self.assertNotIn('if spacer then spacer:Hide() end', gm)
        self.assertIn('menu:HookScript("OnShow"', gm)
        self.assertIn('load:RegisterEvent("PLAYER_LOGIN")', gm)
        self.assertIn('load:RegisterEvent("ADDON_LOADED")', gm)
        self.assertIn('if hooked then self:UnregisterAllEvents() end', gm)
        self.assertIn('HideOwn(); placementState = "disabled"; return', gm)

    def test_combat_input_and_legacy_guarded_without_replacing_blizzard_ui(self):
        gm = src("UI/GameMenu.lua")
        self.assertIn('if not menu or hooked then return end', gm)
        self.assertIn('InCombatLockdown and InCombatLockdown()', gm)
        self.assertIn('local function Legacy(menu)', gm)
        self.assertIn('if not (pool and pool.EnumerateActive) then return end', gm)
        self.assertIn('button:SetParent(menu)', gm)
        self.assertIn('local function HideOwn()', gm)
        self.assertNotIn('hooksecurefunc("GameMenuFrame", "OnKeyDown"', gm)
        self.assertNotIn('SetAttribute("type"', gm)

    def test_requested_logo_hover_animation_is_completely_gone(self):
        win = src("UI/Window.lua")
        for forbidden in ('MakeShimmerBand', 'shimmerBands', 'shimmerKey',
                          'HideBrandShimmer', 'brandLogo:SetScript("OnEnter"',
                          'brandLogo.CreateMaskTexture'):
            self.assertNotIn(forbidden, win)
        self.assertIn('Drag(brandDrag)', win)
        self.assertIn('DuelExactBrand.png', win)
        self.assertNotIn('BrandLayer(', win)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)', win)

if __name__ == "__main__":
    unittest.main()

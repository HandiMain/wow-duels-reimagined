"""Cross-system source contracts; complements the Lua runtime smoke test."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"

def read(path):
    return (ADDON / path).read_text(encoding="utf-8")


class IntegrationContracts(unittest.TestCase):
    def test_tooltip_hooks_survive_resize_and_minimap_handlers(self):
        w = read("UI/Window.lua")
        a = read("UI/AccessIcons.lua")
        self.assertIn('grip:HookScript("OnHide"', w)
        self.assertNotIn('grip:SetScript("OnHide"', w)
        self.assertIn('local function ConnectClick(button, isWidget)', a)
        i = a.index('local function ConnectClick(button, isWidget)')
        j = a.index("miniButton = CreateFrame", i)
        body = a[i:j]
        self.assertLess(body.index('button:SetScript("OnEnter"'),
                        body.index('Tooltips.Bind(button, function()'))

    def test_every_search_result_is_accessible_and_disabled_actions_filtered(self):
        s = read("UI/Search.lua")
        h = read("UI/Header.lua")
        f = read("UI/Footer.lua")
        self.assertIn('for i = 1, #matches do', s)
        self.assertIn('available = ok and result == true', s)
        self.assertIn('dropdown:SetScript("OnMouseWheel"', h)
        self.assertIn('firstVisible + i - 1', h)
        self.assertIn('if picked >= firstVisible + PAGE_SIZE', h)
        self.assertIn('moreInfo:SetText("Showing "', h)
        self.assertIn('function() return reset:IsEnabled() end', f)
        self.assertIn('function() return reload:IsEnabled() end', f)
        self.assertIn('Search.Register("header:close"', h)
        self.assertIn('Window.HighlightMenuScale()', f)
        self.assertIn('function Window.HighlightMenuScale()', read("UI/Window.lua"))

    def test_refresh_selection_does_not_close_search_or_page(self):
        navigation = read("UI/Navigation.lua")
        theme = read("UI/Theme.lua")
        self.assertIn('Select(currentSection, currentPage, true, true)', navigation)
        self.assertIn('if repaintOnly then return end', navigation)
        self.assertIn('if not repaintOnly and ns.Header and ns.Header.CloseSearch', navigation)
        self.assertIn('ns.Navigation.RefreshSelection()', theme)

    def test_already_moving_peek_and_combat_secret_gates(self):
        h = read("UI/Header.lua")
        self.assertIn('pcall(IsPlayerMoving)', h)
        self.assertIn('pcall(GetUnitSpeed, "player")', h)
        self.assertIn('not issecretvalue or not issecretvalue(speed)', h)
        self.assertIn('movement:RegisterEvent("PLAYER_STARTED_MOVING")', h)
        self.assertIn('movement:RegisterEvent("PLAYER_STOPPED_MOVING")', h)

    def test_new_settings_must_join_search(self):
        settings = read("Core/Settings.lua")
        options = read("UI/Options.lua")
        b = settings.split("local boolDefaults = {", 1)[1].split("}", 1)[0]
        toggle_keys = re.findall(r"^\s*(\w+)\s*=\s*(?:true|false)\s*,", b, re.M)
        self.assertIn("showInCompartment", toggle_keys)
        # Extract actual AddToggle argument lists, not a greedy match spanning
        # unrelated lines that could hide an unregistered new setting.
        registered = set(re.findall(
            r'\bAddToggle\(\s*\w+\s*,\s*"(?:options|interface|widget|combatvisuals)"\s*,\s*"([^"]+)"',
            options, re.S))
        # Mode is an immediate gameplay choice, not a general option.
        gameplay = {"practiceDuels"}
        self.assertTrue((set(toggle_keys) - gameplay).issubset(registered),
            "Missing Options/Search registration for toggles: " +
            str(sorted(set(toggle_keys) - gameplay - registered)))
        self.assertNotIn("practiceDuels", registered)
        self.assertIn('Settings.Set("practiceDuels",practice)',read("UI/DuelHUD.lua"))
        for key in ("iconMode", "widgetSize", "widgetTransparency",
                    "fontChoice", "fontScale", "fontOutline", "minimapButton",
                    "resetIconPositions", "duelHUDScale", "duelHUDOpacity", "resetDuelHUDPosition", "duelCountdownStyle", "duelCountdownFont"):
            self.assertIn('RegisterOption("' + key + '"', options)
        self.assertIn('RegisterOption(key, name, detail, pageKey, row)', options)
        self.assertIn('ns.Search.Register("page:" .. section.key', read("UI/Navigation.lua"))
        self.assertIn('ns.Search.Register("setting:menuScale"', read("UI/Footer.lua"))

    def test_compartment_is_independent_and_requires_reload(self):
        a = read("UI/AccessIcons.lua")
        s = read("Core/Settings.lua")
        o = read("UI/Options.lua")
        toc = read("DuelsReimagined.toc")
        self.assertIn('showInCompartment = true', s)
        self.assertIn('Settings.RegisterReloadRequired("showInCompartment")', a)
        self.assertIn('not Settings.Get("showInCompartment")', a)
        self.assertNotIn("AddonCompartmentFunc:", toc)
        self.assertIn('needsCompartment', o)
        self.assertIn('"showInCompartment", "Show in AddOn Compartment"', o)
        self.assertIn('Settings.NeedsReload()', read("UI/Footer.lua"))

    def test_font_preview_is_opt_in_and_not_theme_registered(self):
        widgets = read("UI/Widgets.lua")
        options = read("UI/Options.lua")
        self.assertIn('above, fontSamples, grouped)', widgets)
        self.assertIn('if not fontSamples then return Style.Text(owner,"",12,C.text) end', widgets)
        self.assertIn('local fs=owner:CreateFontString(nil,"OVERLAY")', widgets)
        self.assertIn('ns.Fonts.PaintSample(entry.label,opt.key,opt.label,16,194)', widgets)
        self.assertIn('ns.Fonts.PaintSample(valueText,', widgets)
        self.assertIn('function() Settings.Reset("duelCountdownFont") end,false,true)', options)
        self.assertIn('function() Settings.Reset("fontChoice") end, false,true)', options)

    def test_workflow_runs_whenever_any_addon_file_changes(self):
        text = (ROOT / ".github" / "workflows" / "community-credits.yml").read_text()
        self.assertIn("- addon/DuelsReimagined/**", text)
        self.assertIn("lua5.1 tools/community/check_runtime.lua", text)
        self.assertIn("python3 -m unittest discover -s tools/community", text)


if __name__ == "__main__":
    unittest.main()

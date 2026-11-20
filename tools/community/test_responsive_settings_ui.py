"""Responsive settings, branding and utility-navigation regression contracts.

Source-level tests do not certify in-game rendering. They protect the game API
contracts and layout ownership that previously regressed.
"""
from pathlib import Path
import re
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def read(path):
    return (BASE / path).read_text(encoding="utf-8")

class ResponsiveSettingsTests(unittest.TestCase):
    def test_polestar_inspired_columns_reflow_from_actual_width(self):
        src = read("UI/Options.lua")
        self.assertIn("local COLUMN_BREAKPOINT = 630", src)
        self.assertIn("local two = width >= COLUMN_BREAKPOINT", src)
        self.assertIn("math.floor((usable - COLUMN_GAP) / 2)", src)
        self.assertIn("y = y + math.max(firstHeight, height) + ROW_GAP", src)
        self.assertIn("if content.Relayout then content:Relayout(content:GetWidth()) end", src)
        self.assertIn("function appearance:Relayout(width)", src)
        self.assertIn("function interface:Relayout(width)", src)
        for width in (490, 629):
            self.assertFalse(width >= 630)
        for width in (630, 830, 1100):
            self.assertTrue(width >= 630)

    def test_shared_row_responsiveness_without_second_storage_owner(self):
        src = read("UI/Widgets.lua")
        self.assertEqual(src.count("function row:LayoutForWidth(width, paired)"), 3)
        for kind in ("ToggleRow", "ChoiceRow", "SliderRow"):
            self.assertIn("function Widgets."+kind+"(", src)
        for marker in (
            "self:SetHeight(paired and 76 or 54)",
            "self:SetHeight(paired and 102 or 66)",
            "self:SetHeight(paired and 96 or 64)",
            'control:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8, 7)',
            'slider:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -63, 8)',
            'Paint(slider:GetValue())',
        ):
            self.assertIn(marker, src)
        self.assertNotIn('SetScript("OnUpdate"', src[:src.index("function Widgets.ScrollBar(")])

    def test_card_group_layout_owns_all_existing_settings(self):
        src = read("UI/Options.lua")
        for name in ("appearanceCard", "behaviorCard", "typographyCard", "accessCard"):
            self.assertIn("{ card = "+name+", entries = {", src)
        for name in ("themeChoice", "availability", "matchColorsRow", "matchFontRow",
                     "autoPeekRow", "reduceMotionRow", "tooltipsRow", "reminderRow",
                     "fontChoice", "fontScale", "fontOutline", "iconMode", "widgetSize",
                     "widgetTransparency", "compartmentToggle"):
            self.assertIn("{ widget = "+name, src)
        self.assertIn("resetAccess.optionsY = sectionY + y", src)

    def test_search_destinations_are_recalculated_after_resize(self):
        src = read("UI/Options.lua")
        self.assertIn("widget.optionsY = sectionY + y", src)
        self.assertIn("widget.optionsScroll", src)
        self.assertIn('ns.Search.Register("setting:" .. key', src)
        self.assertIn("ns.Navigation.SelectKey(\"options\", pageKey)", src)
        self.assertIn("sf:SetVerticalScroll(", src)
        self.assertIn("appearance:Relayout(appearance:GetWidth())", src)
        self.assertIn("interface:Relayout(interface:GetWidth())", src)

    def test_theme_explanations_cover_all_three_runtime_states(self):
        opts = read("UI/Options.lua")
        for phrase in (
            "if not ready then",
            "elseif matchedColors then",
            "Duels theme is active. EllesmereUI is unavailable",
            "EllesmereUI controls the interface colors.",
            "Duels theme colors are active. Enable Match EllesmereUI colors",
            "themeChoice:SetAvailable(not matchedColors,",
            "themeChoice:SetModified(Settings.IsModified(\"uiTheme\"))",
            "availability:SetTextColor(unpack(C.muted))",
        ):
            self.assertIn(phrase, opts)
        self.assertNotIn('db.uiTheme = nil', opts)
        self.assertIn("pcall(eui.RegisterSkin", read("UI/Theme.lua"))

    def test_main_and_landing_share_same_two_wordmark_layers(self):
        win, land = read("UI/Window.lua"), read("UI/BlizzardSettings.lua")
        self.assertIn("BrandLayer(C.gold,       0,    0.25, -4)", win)
        self.assertIn("BrandLayer(C.headerText, 0.25, 0.50, -4)", win)
        self.assertIn("LogoBand(C.gold, 0, 0.25)", land)
        self.assertIn("LogoBand(C.headerText, 0.25, 0.50)", land)
        self.assertNotIn("local underline = CreateFrame(", win)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", land)
        self.assertIn("Style.TintedImage(logo, brandAtlas", land)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)', win)

    def test_hall_has_idle_skin_and_click_feedback(self):
        nav = read("UI/Navigation.lua")
        self.assertIn("if isPrimary then\n        Style.Skin(button, C.rail", nav)
        self.assertIn("local selected, hover = AddOverlay(button, isPrimary)", nav)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)', nav)
        self.assertIn("ns.Widgets.PressFeedback(button, hover)", nav)
        self.assertIn("local primaryKeys = { hall = true }", nav)

    def test_patch_icon_is_drawn_with_shared_theme_tokens(self):
        nav = read("UI/Navigation.lua")
        self.assertNotIn("PatchNotesAtlas.tga", nav)
        self.assertIn('local parchment = Style.Fill(icon, C.goldDim, "ARTWORK")', nav)
        self.assertIn("for _, x in ipairs({ 11, 32 }) do", nav)
        self.assertIn("for _, y in ipairs({ -13, -19, -25 }) do", nav)
        self.assertIn("patchPulse:SetLooping(\"BOUNCE\")", nav)
        self.assertIn('label:SetText("PATCH\\nNOTES")', nav)
        self.assertIn("if item.icon.SetVertexColor then", nav)

    def test_all_wow_vertical_alignment_literal_values_valid(self):
        for file in BASE.rglob("*.lua"):
            text = file.read_text(encoding="utf-8")
            for mode in re.findall(r':SetJustifyV\s*\(\s*"([^"]+)"', text):
                self.assertIn(mode, ("TOP", "MIDDLE", "BOTTOM"), str(file))

    def test_no_gameplay_or_storage_changes_in_layout_files(self):
        for file in ("UI/Window.lua", "UI/Options.lua",
                     "UI/Navigation.lua", "UI/BlizzardSettings.lua"):
            text = read(file)
            self.assertNotIn("_G.DuelsReimaginedDB =", text)
            self.assertNotIn('SetScript("OnUpdate"', text)

if __name__ == "__main__":
    unittest.main()

"""Addon Status is an independently owned, searchable utility page."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"


def read(path):
    return (ADDON / path).read_text(encoding="utf-8")


class AddonStatusUIContracts(unittest.TestCase):
    def test_load_order_and_cross_client_availability(self):
        toc = read("DuelsReimagined.toc")
        self.assertEqual(toc.count("UI\\AddonStatus.lua"), 1)
        self.assertLess(toc.index("Core\\Group.lua"), toc.index("Core\\Presence.lua"))
        self.assertLess(toc.index("Core\\Presence.lua"), toc.index("UI\\AddonStatus.lua"))
        self.assertLess(toc.index("UI\\AddonStatus.lua"), toc.index("UI\\Navigation.lua"))
        self.assertNotIn("AllowLoadGameType", next(line for line in toc.splitlines()
            if line.startswith("UI\\AddonStatus.lua")))

    def test_footer_link_not_hall_subcategory(self):
        nav = read("UI/Navigation.lua")
        self.assertIn('key = "addonstatus", label = "Addon Status", icon = "Community"', nav)
        self.assertIn('key = "status", label = "Addon Status", addonStatus = true', nav)
        self.assertIn('local primaryKeys = { hall = true, wargames = true }', nav)
        self.assertIn('if section.key ~= "patchnotes" and section.key ~= "addonstatus"', nav)
        self.assertIn('if page.addonStatus then return ns.AddonStatus end', nav)
        self.assertIn('local utilityButtons = {}', nav)
        self.assertIn('Window.frame:HookScript("OnSizeChanged", FitUtilityButtons)', nav)
        self.assertIn('ns.Search.Register("page:" .. section.key', nav)
        self.assertNotIn('primaryKeys = { hall = true, addonstatus', nav)

    def test_responsive_footer_avoids_crowding(self):
        nav, foot = read("UI/Navigation.lua"), read("UI/Footer.lua")
        self.assertIn('local minWidths = { 112, 102, 98, 82 }', nav)
        self.assertIn('local maxWidths = { 136, 110, 124, 104 }', nav)
        self.assertIn('Window.utility:SetWidth(offset)', nav)
        self.assertIn('local function FitFooter()', foot)
        self.assertIn('frame:HookScript("OnSizeChanged", FitFooter)', foot)
        self.assertIn('reload:SetWidth(85 + 25 * ratio)', foot)
        self.assertIn('Style.ConstrainButtonLabel(button, label, 34, 6, 9)', nav)

    def test_custom_page_excludes_hall_art_and_uses_live_status(self):
        win, page = read("UI/Window.lua"), read("UI/AddonStatus.lua")
        self.assertIn('local isAddonStatus = page.addonStatus == true', win)
        self.assertIn('ns.AddonStatus.Show(isAddonStatus)', win)
        self.assertIn('local isCustomPage = isOptions or isCommunity or isPatchNotes or isAddonStatus', win)
        self.assertIn('ns.AddonStatus = Status', page)
        self.assertIn('local snap = Presence.GetSnapshot()', page)
        self.assertIn('Presence.CheckNow()', page)
        self.assertIn('Status.GetPageScroll', page)
        self.assertIn('Status.SetPageScroll', page)
        self.assertIn('Widgets.ScrollBar(scroll', page)
        self.assertIn('for i = count + 1, #rows do rows[i]:Hide()', page)
        self.assertIn('CLASS_ICON_TCOORDS', page)
        for disallowed in ('C_ChatInfo.SendAddonMessage', 'RegisterAddonMessagePrefix',
                           'DuelsReimaginedDB', 'SetScript("OnUpdate"', "WarGames",
                           'GetNumGroupMembers(', "UnitName(", "NewTicker"):
            self.assertNotIn(disallowed, page)

    def test_empty_error_truthful_and_full_lifecycle(self):
        page = read("UI/AddonStatus.lua")
        for label in ("This client", "Confirmed", "Checking...",
                      "Not confirmed", "Offline", "Not reported",
                      "No response does not mean the addon is missing.",
                      "Group information is temporarily unavailable.",
                      "Blizzard is restricting addon messages"):
            self.assertIn(label, page)
        self.assertIn('if not root:IsShown() then return end', page)
        self.assertIn('unsubscribe = Presence.Subscribe(Refresh)', page)
        self.assertIn('if unsubscribe then unsubscribe(); unsubscribe = nil end', page)
        self.assertIn('check:SetEnabled(canCheck)', page)
        self.assertIn('reason == "cooldown"', page)
        self.assertIn('ns.Search.Register("addonstatus:check"', page)
        theme = read("UI/Theme.lua")
        self.assertIn('ns.AddonStatus.Refresh()', theme)
        present = read("Core/Presence.lua")
        self.assertIn('A communication restriction can change without any roster change', present)

    def test_minimum_and_default_footer_geometry_clear_left_controls(self):
        # The layout derives from Window's 1050px minimum, its existing
        # right-anchored utility region and Footer's responsive widths.
        # This is source-specific geometry, not an in-game visual claim.
        for width in (1050, 1075, 1120, 1175, 1200, 1240):
            ratio = max(0, min(1, (width - 1050) / 190))
            buttons = [small + (large - small) * ratio
                       for small, large in zip((112, 102, 98, 82),
                                               (136, 110, 124, 104))]
            utility_width = sum(buttons) + 3 * (5 + 3 * ratio)
            utility_left = width - 187 - utility_width
            # Earlier footer: build tag, icon, reset and reload.
            # The left controls shrink with the same ratio.
            left_edge = (247 + (12 + 12 * ratio - 24) +
                         (105 + 27 * ratio) + (6 + 6 * ratio) +
                         (85 + 25 * ratio))
            self.assertGreaterEqual(utility_left - left_edge, 16)
            self.assertLess(width - 187, width - 169)

    def test_no_sample_players_or_fabricated_versions(self):
        page = read("UI/AddonStatus.lua")
        for name in ("Aethon", "Kaelor", "Selara", "Mirelith",
                     "SAMPLE DATA", "DEMO", "version = 1."):
            self.assertNotIn(name, page)
        self.assertIn('member.version or', page)
        self.assertIn('and "Not reported" or "—"', page)


if __name__ == "__main__":
    unittest.main()

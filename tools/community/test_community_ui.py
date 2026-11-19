#!/usr/bin/env python3
"""Check the Community UI's isolated and verifiable integration contracts."""

import struct
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"


def content(path):
    return (ADDON / path).read_text(encoding="utf-8")


class CommunityUITests(unittest.TestCase):
    def test_toc_load_order_and_single_credits_owner(self):
        toc = content("DuelsReimagined.toc")
        order = [
            r"UI\Widgets.lua",
            r"UI\Window.lua",
            r"UI\Search.lua",
            r"UI\Navigation.lua",
            r"Community\Credits.lua",
            r"UI\Community.lua",
            r"UI\Options.lua",
            r"UI\Footer.lua",
        ]
        for name in order:
            self.assertIn(name, toc)
        indices = [toc.index(x) for x in order]
        self.assertEqual(indices, sorted(indices))
        self.assertEqual(toc.count(r"Community\Credits.lua"), 1)

    def test_main_shell_keeps_hall_and_options_separate(self):
        window = content("UI/Window.lua")
        self.assertIn('local isCommunity = page.community == true', window)
        self.assertIn('watermark:SetShown(not isOptions and not isCommunity)', window)
        self.assertIn("ns.Community.Show(isCommunity and page.key or nil)", window)
        self.assertIn('ns.Options.Show(isOptions and page.key or nil)', window)

    def test_community_navigation_and_search(self):
        nav = content("UI/Navigation.lua")
        community = content("UI/Community.lua")
        self.assertEqual(nav.count("community = true"), 5)
        for key in ('"community"', '"contributors"', '"bug-hunters"',
                    '"community-ideas"', '"special-thanks"'):
            self.assertIn(key, nav)
        self.assertIn('Search.Register("community:report-bug"', community)
        self.assertIn('Search.Register("community:suggest-idea"', community)
        self.assertIn('ns.Navigation.SelectKey("community", data.key)', community)

    def test_copyable_links_and_focus_restoration(self):
        footer = content("UI/Footer.lua")
        self.assertIn("function Footer.ShowCommunityLink(title, url)", footer)
        self.assertIn('url ~= prefix .. "bug-report.yml"', footer)
        self.assertIn('url ~= prefix .. "feature-request.yml"', footer)
        self.assertIn("copyBox:SetFocus()", footer)
        self.assertIn("copyBox:HighlightText()", footer)
        self.assertIn("copyBox:ClearFocus()", footer)
        self.assertIn("copyBox:SetScript(\"OnEscapePressed\", Footer.ClosePopup)", footer)
        self.assertNotIn("LaunchURL(", footer)
        self.assertNotIn("GameTooltip:Set", footer)

    def test_generated_credits_zero_state(self):
        credits = content("Community/Credits.lua")
        community = content("UI/Community.lua")
        self.assertIn("ns.CommunityCredits = {", credits)
        for field in ("contributors", "bugHunters", "ideas", "specialThanks"):
            self.assertIn(field + " = {", credits)
            self.assertIn('field = "' + field + '"', community)
        self.assertIn("No contributors credited yet.", community)
        self.assertIn("No verified reports yet.", community)
        self.assertIn("No implemented ideas yet.", community)
        self.assertIn("No acknowledgements yet.", community)

    def test_faction_texture_truecolor_and_power_of_two(self):
        png = ADDON / "Media" / "Concept" / "CommunityFactionMarks.png"
        data = png.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(data[12:16], b"IHDR")
        width, height = struct.unpack(">II", data[16:24])
        self.assertEqual((width, height), (512, 256))
        self.assertEqual(data[25], 6, "WoW texture must be truecolor RGBA")
        community = content("UI/Community.lua")
        self.assertIn("CommunityFactionMarks.png", community)
        self.assertIn("tex:SetAlpha(left and 0.12 or 0.10)", community)

    def test_shared_components_and_no_network_in_wow(self):
        source = content("UI/Community.lua")
        for marker in ("Widgets.ScrollBar(", "ns.Tooltips.Bind(",
                       "Style.Action(", "Style.Border(", "Style.Text(",
                       "ns.CommunityCredits"):
            self.assertIn(marker, source)
        for banned in ("C_HTTP", "SendAddonMessage", "HTTPGet",
                       "CreateHTTPRequest", "LoadURL"):
            self.assertNotIn(banned, source)


if __name__ == "__main__":
    unittest.main()

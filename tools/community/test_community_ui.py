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
        self.assertIn('watermark:SetShown(not isCustomPage)', window)
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
        # Category navigation is supplied by the five existing upper tabs.
        self.assertIn("local overviewPieces = {}", community)
        self.assertNotIn("PreviewCard(", community)
        self.assertIn('UpdateOverview()', community)
        self.assertIn('listing:SetShown(not overview)', community)

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
        for key in ("contributors", "bugReports", "communityIdeas", "specialThanks"):
            self.assertIn(key + " = 0,", credits)
        self.assertIn("local stats = source.stats", community)
        self.assertIn('item.value:SetText("—")', community)
        self.assertNotIn("147", community)
        self.assertNotIn("328", community)
        self.assertNotIn('item.value:SetText("96")', community)

    def test_faction_texture_truecolor_and_power_of_two(self):
        png = ADDON / "Media" / "Concept" / "CommunityFactionMarks.png"
        data = png.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(data[12:16], b"IHDR")
        width, height = struct.unpack(">II", data[16:24])
        self.assertEqual((width, height), (128, 64))
        self.assertEqual(data[25], 6, "WoW texture must be truecolor RGBA")
        community = content("UI/Community.lua")
        # The previous tiny/client-dependent badges are preserved as
        # historical assets, but not drawn over approved reference artwork.
        for name, dimensions in (
            ("CommunityConceptHero.png", (2048, 512)),
            ("CommunityConceptTitle.png", (1024, 128)),
            ("CommunityConceptButtons.png", (1024, 128)),
            ("CommunityConceptIcons.png", (512, 128)),
            ("CommunityConceptHeaders.png", (1024, 128)),
            ("CommunityConceptCards.png", (2048, 512)),
        ):
            image = (ADDON / "Media" / "Concept" / name).read_bytes()
            self.assertEqual(image[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", image[16:24]), dimensions)
            self.assertEqual(image[25], 6, name + ": RGBA source required")
        for token in ("conceptHero", "conceptTitle", "conceptButtons",
                      "conceptHeaders", "conceptIcons"):
            self.assertIn(token, community)
        self.assertNotIn("local function FactionMark(left)", community)
        self.assertNotIn("PvPQueueBackgroundAlliance", community)

    def test_concept_assets_have_partial_alpha_and_correct_sources(self):
        # Explicitly reject the previous flat color squares. The approved
        # concept textures must retain soft-edged transparent silhouettes.
        import zlib
        for filename, dims in (
            ("CommunityFactionMarks.png", (128, 64)),
            ("CommunityConceptSymbols.png", (128, 128)),
        ):
            raw = (ADDON / "Media" / "Concept" / filename).read_bytes()
            self.assertEqual(struct.unpack(">II", raw[16:24]), dims)
            self.assertEqual(raw[25], 6, "Use truecolor RGBA, not palette PNG")
            pos = 8
            chunks = []
            while pos < len(raw):
                size = struct.unpack(">I", raw[pos:pos+4])[0]
                kind = raw[pos+4:pos+8]
                if kind == b"IDAT":
                    chunks.append(raw[pos+8:pos+8+size])
                pos += 12 + size
                if kind == b"IEND":
                    break
            packed = zlib.decompress(b"".join(chunks))
            width, height = dims
            previous = bytearray(width * 4)
            offset = 0
            soft_pixels = 0
            for _ in range(height):
                mode = packed[offset]
                offset += 1
                line = bytearray(packed[offset:offset+width*4])
                offset += width*4
                for x in range(len(line)):
                    left = line[x-4] if x >= 4 else 0
                    up = previous[x]
                    up_left = previous[x-4] if x >= 4 else 0
                    if mode == 1:
                        predictor = left
                    elif mode == 2:
                        predictor = up
                    elif mode == 3:
                        predictor = (left+up)//2
                    elif mode == 4:
                        p = left+up-up_left
                        distances = (abs(p-left), abs(p-up), abs(p-up_left))
                        predictor = (left, up, up_left)[distances.index(min(distances))]
                    else:
                        self.assertEqual(mode, 0)
                        predictor = 0
                    line[x] = (line[x] + predictor) & 255
                soft_pixels += sum(0 < line[i] < 255 for i in range(3, len(line), 4))
                previous = line
            self.assertGreater(soft_pixels, 100,
                "Source-derived artwork needs faded/transparent shapes, not flat colored squares")
        community = content("UI/Community.lua")
        self.assertIn("exactHeroArt:SetTexCoord(0, 1, 0, 352 / 512)", community)
        self.assertIn("exactTitle:SetTexCoord(0, 518 / 1024, 0, 93 / 128)", community)
        self.assertIn("CommunityConceptSymbols.png", community)

    def test_alliance_lion_detail_and_horde_bytes_unchanged(self):
        import hashlib
        path = ADDON / "Media" / "Concept"
        old = (path / "CommunityFactionMarks.png").read_bytes()
        self.assertEqual(hashlib.sha256(old).hexdigest(),
            "ffb1518a5a4b4974d199067ab6961518b862db98159c143ab6a472c68785adac",
            "The approved Horde artwork must remain byte-for-byte unchanged")
        lion = (path / "CommunityAllianceLion.png").read_bytes()
        self.assertEqual(lion[:8], bytes((137, 80, 78, 71, 13, 10, 26, 10)))
        self.assertEqual(struct.unpack(">II", lion[16:24]), (128, 128))
        self.assertEqual(lion[24], 8)
        self.assertEqual(lion[25], 6)
        self.assertGreater(len(lion), 5000, "Refuse a flat placeholder texture")
        community = content("UI/Community.lua")
        self.assertIn("CommunityAllianceLion.png", community)

    def test_circle_has_one_stats_bar_and_two_information_panels(self):
        community = content("UI/Community.lua")
        self.assertIn('local statsPanel = CreateFrame("Frame", nil, stage)', community)
        self.assertIn('Style.Skin(statsPanel, C.window', community)
        self.assertIn('shine=0.09, shade=0.08, rim=0.96', community)
        self.assertIn('Style.Skin(hero, C.window', community)
        self.assertIn('smooth=true, rim=0', community)
        self.assertIn('local creditsPanel = InfoPanel(true, "COMMUNITY CREDITS"', community)
        self.assertIn('local helpPanel = InfoPanel(false, "HOW TO HELP"', community)
        self.assertNotIn('"COMMUNITY TOOLS", 16', community)
        self.assertNotIn('UtilityAction(', community)
        self.assertIn('canvas:SetHeight(height)', community)
        self.assertIn('local DESIGN_WIDTH, CARD_BREAKPOINT = 940, 930', community)
        self.assertIn('ReflowCommunity = function()', community)
        self.assertIn('hero:SetScale(heroScale)', community)
        self.assertIn('local statsHeight = compact and 116 or 58', community)
        self.assertIn('local cardWidth = math.min(510, math.max(1, width - 24))', community)
        self.assertIn('stage:SetWidth(width)', community)
        self.assertIn('local communityHeading = Style.Text(root, "Community"', community)
        self.assertIn('Style.Skin(hero, C.window', community)
        self.assertIn('exactTitle:SetTexture(conceptTitle)', community)
        self.assertIn('artTex:SetTexture(conceptRoot .. "CommunityConceptCards.png")', community)
        self.assertIn('hero:Show()', community)
        self.assertNotIn('hero:SetShown(overview)', community)
        self.assertIn('bugAction:SetShown(overview)', community)
        self.assertIn('ideaAction:SetShown(overview)', community)
        self.assertIn('listing:SetShown(not overview)', community)
        self.assertIn('local bugAction = Action("bug"', community)
        self.assertIn('local ideaAction = Action("idea"', community)
        self.assertIn('artTex:SetTexCoord(0, 633 / 2048, 0, 255 / 512)', community)
        self.assertIn('artTex:SetTexCoord(768 / 2048, 1362 / 2048, 0, 255 / 512)', community)
        self.assertIn('artTex:SetTexture(conceptButtons)', community)
        self.assertIn('for _, item in ipairs(overviewPieces) do item:SetShown(overview) end', community)
        self.assertNotIn('PreviewCard(', community)
        self.assertNotIn('SetScript("OnUpdate"', community)
        self.assertNotIn('GetNumGuildMembers', community)

    def test_community_buttons_are_coded_and_have_one_click_target(self):
        style = content("UI/Style.lua")
        chrome = content("UI/Chrome.lua")
        community = content("UI/Community.lua")
        self.assertIn('local community = variant == "community"', style)
        self.assertIn('Style.Skin(button, C.button, {', style)
        self.assertIn('corner=9, edge=C.gold', style)
        self.assertIn('Style.SkinMask(parent, color, mask, layer', style)
        self.assertNotIn('ns.Chrome.SlicedButton(button)', style)
        self.assertNotIn('function Chrome.SlicedButton(parent)', chrome)
        self.assertNotIn('middle:SetTexCoord', chrome)
        self.assertIn('local btn = Style.Action(hero, heading, "community-art")', community)
        self.assertIn('elseif not communityArt and not landingArt then', style)
        self.assertIn('local communityArt = variant == "community-art"', style)
        self.assertIn('artTex:SetTexCoord(x / 1024, (x + 308) / 1024, 0, 60 / 128)', community)
        self.assertNotIn('(x + 295) / 1024, 0, 55 / 128', community)
        self.assertIn('btn:SetSize(242, 42)', community)
        self.assertIn('artTex:SetAllPoints(btn)', community)
        self.assertIn('local x = kind == "bug" and 0 or 512', community)
        self.assertEqual(community.count('btn:SetScript("OnClick"'), 1)
        self.assertNotIn('local copy = CreateFrame("Button"', community)
        self.assertNotIn('copy:SetScript("OnClick"', community)
        self.assertIn('Get a link to report a bug on GitHub.', community)
        self.assertIn('Get a link to suggest an improvement.', community)
        self.assertNotIn('local note = Style.Text(canvas, description, 12, C.muted)', community)
        self.assertIn('ns.Tooltips.Bind(btn, {', community)
        self.assertIn('elseif section.key == "community" then',
                      content("UI/Navigation.lua"))

    def test_hall_horizontal_navigation_and_search_preserved(self):
        navigation = content("UI/Navigation.lua")
        chrome = content("UI/Chrome.lua")
        self.assertIn('key = "hall", label = "Hall", icon = "Hall", pages = {', navigation)
        self.assertNotIn('primary = true', navigation)
        self.assertNotIn('Chrome.PrimaryRail', navigation)
        self.assertNotIn('function Chrome.PrimaryRail', chrome)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)', navigation)
        self.assertIn('button:SetSize(112, 30)', navigation)
        self.assertIn('Window.utility', navigation)
        self.assertIn('button:SetPoint("TOP", Window.rail, "TOP",', navigation)
        self.assertIn('local selected, hover = AddOverlay(button, isPrimary)', navigation)
        self.assertIn('ns.Widgets.PressFeedback(button, hover, {', navigation)

    def test_shared_components_and_no_network_in_wow(self):
        source = content("UI/Community.lua")
        for marker in ("Widgets.ScrollBar(", "ns.Tooltips.Bind(",
                       "Style.Action(", "Style.Skin(", "Style.Text(",
                       "ns.CommunityCredits"):
            self.assertIn(marker, source)
        for banned in ("C_HTTP", "SendAddonMessage", "HTTPGet",
                       "CreateHTTPRequest", "LoadURL"):
            self.assertNotIn(banned, source)


if __name__ == "__main__":
    unittest.main()

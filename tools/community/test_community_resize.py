"""Community width and height layout regression contracts.

These are geometry/source tests, not proof of the rendered UI in WoW.
The approved fixed-image design must never be stretched to the whole
window or squashed into two unreadable half-width cards at the minimum.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
COMMUNITY = (BASE / "UI" / "Community.lua").read_text(encoding="utf-8")
WINDOW = (BASE / "UI" / "Window.lua").read_text(encoding="utf-8")


def geometry(window_width, detail_height=245, details=False):
    # Matches current Window: 6px shell each edge, 226px rail, Community
    # scroll 19px/22px gutters and 14px reserve for the scrollbar.
    viewport = max(1, window_width - (12 + 226 + 19 + 22 + 14))
    width = min(940, viewport)
    compact = width < 930
    hero = 158 * width / 940
    stats_top = hero + 5
    stat_h = 116 if compact else 58
    cards_top = stats_top + stat_h + 12
    if compact:
        card_w = min(510, max(1, width - 24))
        panels = [( (width-card_w)/2, cards_top, card_w, 203),
                  ( (width-card_w)/2, cards_top+213, card_w, 203)]
        bottom = cards_top + 213 + 203
    else:
        panels = [(12, cards_top, width / 2 + 8, 203),
                  (width / 2 + 38, cards_top, width / 2 - 50, 203)]
        bottom = cards_top + 203
    listing_top = hero + 17
    height = listing_top + detail_height + 20 if details else bottom + 24
    return width, compact, hero, stats_top, stat_h, panels, height


class CommunityResizeTests(unittest.TestCase):
    def test_one_centered_max_width_layout(self):
        for token in (
            "local DESIGN_WIDTH, CARD_BREAKPOINT = 940, 930",
            'stage:SetPoint("TOP", canvas, "TOP", 0, 0)',
            "local width = math.max(1, math.min(DESIGN_WIDTH, canvas:GetWidth()))",
            "stage:SetWidth(width)",
            "hero:SetScale(heroScale)",
            "scroll:SetScript(\"OnSizeChanged\", function(_, width)",
            "if ReflowCommunity then ReflowCommunity() end",
        ):
            self.assertIn(token, COMMUNITY)
        self.assertNotIn('hero:SetPoint("TOPRIGHT", canvas', COMMUNITY)
        for window_width in (1240, 1500, 1900, 2500):
            width, compact, _, _, _, panels, _ = geometry(window_width)
            self.assertEqual(width, 940)
            self.assertFalse(compact)
            self.assertEqual(panels[0][0] + panels[0][2] + 18, panels[1][0])

    def test_compact_card_stack_preserves_source_art_and_scrolls(self):
        for window_width in (1050, 1080, 1150, 1200):
            width, compact, hero, top, stats_height, panels, total = geometry(window_width)
            self.assertTrue(compact)
            self.assertLessEqual(hero * 940 / width, 158.001)
            self.assertEqual(stats_height, 116)
            self.assertGreaterEqual(width / 2 - 12, 300)
            self.assertGreaterEqual(panels[1][1] - (panels[0][1] + panels[0][3]), 10)
            self.assertLessEqual(panels[1][0] + panels[1][2], width + 0.01)
            self.assertGreaterEqual(total, panels[1][1] + panels[1][3] + 24)
            self.assertGreater(total, 460)
        self.assertIn("local compact = width < CARD_BREAKPOINT", COMMUNITY)
        self.assertIn("local cardWidth = math.min(510, math.max(1, width - 24))", COMMUNITY)
        self.assertIn("statsColumns = compact and 2 or 4", COMMUNITY)
        self.assertIn("local line = math.floor((i - 1) / statsColumns)", COMMUNITY)
        self.assertIn('canvas:SetHeight(height)', COMMUNITY)

    def test_detail_pages_keep_banner_and_responsive_list(self):
        for window_width in (1050, 1240, 1880):
            width, _, hero, _, _, _, total = geometry(window_width, details=True)
            self.assertAlmostEqual(total, hero + 17 + 245 + 20, places=4)
        for token in (
            "hero:Show()",
            "bugAction:SetShown(overview)",
            "ideaAction:SetShown(overview)",
            "listing:SetShown(not overview)",
            "listing:SetWidth(math.max(1, width - 44))",
            "height = listingTop + listing:GetHeight() + 20",
            "ReflowCommunity()",
            "ClampScroll()",
        ):
            self.assertIn(token, COMMUNITY)

    def test_resize_does_not_add_polling_or_change_global_window_minimum(self):
        self.assertIn("local MIN_WIDTH, MIN_HEIGHT = 1050, 650", WINDOW)
        self.assertIn('frame:StartSizing("BOTTOMRIGHT")', WINDOW)
        self.assertNotIn('SetScript("OnUpdate"', COMMUNITY)
        self.assertIn('ns.CommunityCredits or {}', COMMUNITY)
        self.assertIn('function Community.GetPageScroll(key)', COMMUNITY)
        self.assertIn('function Community.SetPageScroll(key, offset)', COMMUNITY)


if __name__ == "__main__":
    unittest.main()

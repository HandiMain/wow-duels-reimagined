"""The approved dark card background must hide the *baked-in* sepia top band.

The source cardBody 9-slice includes the unwanted brown strip. Ensure a scoped
overlay covers its interior without redrawing the shared copper border or
covering icons/labels. Static contracts are not in-game pixel proof.
"""
from pathlib import Path
import hashlib
import struct
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"

class FlatDarkOptionsHeaderTests(unittest.TestCase):
    def test_native_clean_gold_art(self):
        data=(ROOT/"Media/Skin/DuelOptionsBanner.png").read_bytes()
        self.assertEqual(data[:8],bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack_from(">IIBB",data,16),(2048,256,8,6))
        self.assertEqual(hashlib.sha256(data).hexdigest(),
            "1981b7fc18b5c0e77a5079470524624e2f329fec8a7093e9237279ea5a4755c9")

    def test_clean_top_over_source_card_plate_below_live_art(self):
        src=(ROOT/"UI/Options.lua").read_text(encoding="utf-8")
        for needle in (
            'Style.Plate(card, "cardBody", { corner=15 })',
            'local cleanTop = card:CreateTexture(nil, "BORDER", nil, 5)',
            'cleanTop:SetColorTexture(unpack(C.window))',
            'cleanTop:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -5)',
            'cleanTop:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, -5)',
            'cleanTop:SetHeight(21)',
            'left:SetPoint("LEFT", header, "LEFT", 0, 0)',
            'right:SetPoint("RIGHT", header, "RIGHT", 0, 0)',
            'divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -82)',
            'local ROW_TOP = 90',
            "function appearance:Relayout(width)",
            "function interface:Relayout(width)",
        ):
            self.assertIn(needle,src)
        self.assertLess(src.index('Style.Plate(card, "cardBody"'),
                        src.index('local cleanTop = card:CreateTexture('))
        self.assertLess(src.index('local cleanTop = card:CreateTexture('),
                        src.index('local headingBand = CreateFrame('))
        self.assertEqual(src.count('Style.Plate(card, "cardBody"'),1)
        self.assertNotIn('BANNER_AMBIENT',src)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',src)

    def test_shared_card_plate_and_approved_other_ui_untouched(self):
        style=(ROOT/"UI/Style.lua").read_text(encoding="utf-8")
        nav=(ROOT/"UI/Navigation.lua").read_text(encoding="utf-8")
        win=(ROOT/"UI/Window.lua").read_text(encoding="utf-8")
        self.assertIn('cardBody = { path=PLATE_ATLAS',style)
        self.assertIn('DuelTabIcons.tga',nav)
        self.assertIn('DuelResizeCopper.png',win)

if __name__=="__main__":
    unittest.main()

"""Regression guard for single copper border and readable options symbols.

Static evidence only: visual feel and frame layering still require WoW testing.
"""
from pathlib import Path
import hashlib
import struct
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
SKIN=ROOT/"Media"/"Skin"
def lua(p):return (ROOT/p).read_text(encoding="utf-8")

class SingleRimOptionsTests(unittest.TestCase):
    def test_banner_inlay_preserves_graphics_without_baked_frame_strokes(self):
        b=(SKIN/"DuelOptionsSoftArt.png").read_bytes()
        self.assertEqual(b[:8],bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(2048,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
                         "7409daba912b6a9437e836bbbd5ff4fa902deecc1f20a73e19abe8786e7d19ba")
        o=lua("UI/Options.lua")
        self.assertEqual(o.count('Style.Plate(card, "cardBody", { corner=15 })'),1)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',o)
        for marker in (
            'headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -6)',
            'headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -6)',
            'divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -72)',
            'divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -72)',
            'card.optionsBand:SetHeight(BANNER_HEIGHT)',
            'widget.optionsY = sectionY + y',
            'function appearance:Relayout(width)',
            'function interface:Relayout(width)',
        ):self.assertIn(marker,o)

    def test_simple_icons_remain_two_distinct_live_tabs(self):
        b=(SKIN/"DuelMinimalGoldTabs.tga").read_bytes()
        self.assertEqual(struct.unpack_from("<HH",b,12),(128,64))
        self.assertEqual((b[2],b[16],b[17]),(2,32,0x28))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
                         "6a15481f315ab81a7b20f7b5a594080dc93db4bf057ff3708761ad102e8879dd")
        n=lua("UI/Navigation.lua")
        self.assertIn("DuelMinimalGoldTabs.tga",n)
        self.assertIn("glyph:SetSize(28, 28)",n)
        self.assertIn('sub:SetScript("OnClick", function() Select(index, pageIndex) end)',n)
        self.assertIn('Motion.Fade(subHover, chosen and 0.16 or 0.42',n)

    def test_corner_uses_one_subtle_artpiece_and_existing_resize_owner(self):
        b=(SKIN/"DuelCorner03Copper.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
                         "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc")
        w=lua("UI/Window.lua")
        for token in ("resizeArt:SetSize(96, 96)",
                      "grip:SetSize(54, 54)","DuelCorner03Copper.png",
                      "gripPress:SetBlendMode",
                      'frame:StartSizing("BOTTOMRIGHT")',
                      "Window.CommitResize()",
                      'if button == "RightButton" then Window.ResetSize() end',
                      "resizeArt:SetShown(on and true or false)"):
            self.assertIn(token,w)
        self.assertNotIn("gripGlyph",w)

    def test_superseded_borders_and_icons_are_not_packaged(self):
        for f in ("DuelOptionsCompleteBanners.png","DuelPremiumCategoryIcons.tga",
                  "DuelSculptedCopperCorner.png","DuelOptionsBannerInlays.png",
                  "DuelArchitecturalResizeL.png"):
            self.assertFalse((SKIN/f).exists())

if __name__=="__main__":unittest.main()

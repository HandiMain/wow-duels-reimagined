"""Options banner soft-art and filled copper corner contract.

Automated passes are not live WoW visual verification.
"""
from pathlib import Path
import hashlib
import struct
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
MEDIA=ROOT/"Media"/"Skin"
def source(p):return (ROOT/p).read_text(encoding="utf-8")

class OptionsSoftArtTests(unittest.TestCase):
    def test_true_alpha_art_without_unwanted_brown_header_fill(self):
        for file, dimensions, sha in (
            ("DuelOptionsBanner.png",(2048,256),"1981b7fc18b5c0e77a5079470524624e2f329fec8a7093e9237279ea5a4755c9"),
        ):
            b=(MEDIA/file).read_bytes()
            self.assertEqual(b[:8],bytes((137,80,78,71,13,10,26,10)))
            self.assertEqual(struct.unpack_from(">IIBB",b,16),(*dimensions,8,6))
            self.assertEqual(hashlib.sha256(b).hexdigest(),sha)
        s=source("UI/Options.lua")
        self.assertEqual(s.count('Style.Plate(card, "cardBody", { corner=15 })'),1)
        self.assertNotIn("BANNER_AMBIENT",s)
        self.assertNotIn("wash:SetTexture",s)
        self.assertNotIn('header:CreateTexture(nil, "ARTWORK", nil, 1)',s)
        self.assertFalse((MEDIA/"DuelBannerAmbient.png").exists())
        self.assertIn("local left = Slice(0, BANNER_LEFT)",s)
        self.assertIn("local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)",s)
        self.assertNotIn("local center = Slice(",s)
        self.assertIn("left:SetSize(math.max(1, BANNER_LEFT * scale)",s)
        self.assertIn("right:SetSize(math.max(1, BANNER_RIGHT * scale)",s)
        self.assertIn("function appearance:Relayout(width)",s)
        self.assertIn("function interface:Relayout(width)",s)

    def test_filled_triangle_preserves_clickable_grip(self):
        b=(MEDIA/"DuelResizeCopper.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
             "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc")
        s=source("UI/Window.lua")
        for code in ("resizeArt:SetSize(96, 96)","grip:SetSize(54, 54)",
            'frame:StartSizing("BOTTOMRIGHT")',"Window.CommitResize()",
            'if button == "RightButton" then Window.ResetSize() end',
            "gripPress:SetBlendMode",
            "resizeArt:SetShown(on and true or false)"):
            self.assertIn(code,s)

    def test_tab_icons_unchanged_and_obsolete_art_absent(self):
        n=source("UI/Navigation.lua")
        self.assertIn("DuelTabIcons.tga",n)
        self.assertIn("glyph:SetSize(28, 28)",n)
        for old in ("DuelOptionsBannerInlays.png","DuelArchitecturalResizeL.png"):
            self.assertFalse((MEDIA/old).exists())
if __name__=="__main__":unittest.main()

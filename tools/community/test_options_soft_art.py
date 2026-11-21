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
    def test_true_alpha_art_and_independent_ambient_gradient(self):
        for file, dimensions, sha in (
            ("DuelOptionsSoftArt.png",(2048,256),"7409daba912b6a9437e836bbbd5ff4fa902deecc1f20a73e19abe8786e7d19ba"),
            ("DuelBannerAmbient.png",(256,64),"ca0745547059179f065bc691e11f9b03423501347f1b73dab249e48ceeb06c94"),
        ):
            b=(MEDIA/file).read_bytes()
            self.assertEqual(b[:8],bytes((137,80,78,71,13,10,26,10)))
            self.assertEqual(struct.unpack_from(">IIBB",b,16),(*dimensions,8,6))
            self.assertEqual(hashlib.sha256(b).hexdigest(),sha)
        s=source("UI/Options.lua")
        self.assertEqual(s.count('Style.Plate(card, "cardBody", { corner=15 })'),1)
        self.assertIn("wash:SetTexture(BANNER_AMBIENT)",s)
        self.assertIn("wash:SetAllPoints(header)",s)
        self.assertIn("local left = Slice(0, BANNER_LEFT)",s)
        self.assertIn("local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)",s)
        self.assertNotIn("local center = Slice(",s)
        self.assertIn("left:SetSize(math.max(1, BANNER_LEFT * scale)",s)
        self.assertIn("right:SetSize(math.max(1, BANNER_RIGHT * scale)",s)
        self.assertIn("function appearance:Relayout(width)",s)
        self.assertIn("function interface:Relayout(width)",s)

    def test_filled_triangle_preserves_clickable_grip(self):
        b=(MEDIA/"DuelFactionCorner06Blended.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
             "6a7923d5249901b6231736fa6c03cc5ad44d0d8c2fae2aa3886926dd90b450f2")
        s=source("UI/Window.lua")
        for code in ("resizeArt:SetSize(96, 96)","grip:SetSize(54, 54)",
            'frame:StartSizing("BOTTOMRIGHT")',"Window.CommitResize()",
            'if button == "RightButton" then Window.ResetSize() end',
            "gripPress:SetBlendMode",
            "resizeArt:SetShown(on and true or false)"):
            self.assertIn(code,s)

    def test_tab_icons_unchanged_and_obsolete_art_absent(self):
        n=source("UI/Navigation.lua")
        self.assertIn("DuelMinimalGoldTabs.tga",n)
        self.assertIn("glyph:SetSize(28, 28)",n)
        for old in ("DuelOptionsBannerInlays.png","DuelArchitecturalResizeL.png"):
            self.assertFalse((MEDIA/old).exists())
if __name__=="__main__":unittest.main()

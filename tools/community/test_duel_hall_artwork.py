"""Duel Hall fidelity textures: independent, native WoW art assets.

The screenshot is now the literal source of the ornamental atlas, not a pasted UI.
All dynamic labels, controls, hit targets and state owners remain in Lua.
"""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
SKIN = ROOT / "Media" / "Skin"
ASSETS = {
    "DuelHallPlaque.tga": (256, 128),
    "DuelCornerJewel.tga": (64, 64),
    "DuelMinimalGoldTabs.tga": (128, 64),
}

def read(name):
    return (ROOT / name).read_text(encoding="utf-8")

def pixels(path):
    blob = path.read_bytes()
    width, height = struct.unpack_from("<HH", blob, 12)
    return blob, width, height

def rgba(data, w, x, y):
    offset = 18 + 4*(y*w+x)
    blue, green, red, alpha = data[offset:offset+4]
    return red,green,blue,alpha

class DuelHallArtworkTests(unittest.TestCase):
    def test_all_art_is_native_pow2_uncompressed_rgba(self):
        for name, dimensions in ASSETS.items():
            with self.subTest(name=name):
                data,w,h = pixels(SKIN / name)
                self.assertEqual((w,h), dimensions)
                self.assertEqual(data[2], 2)
                self.assertEqual(data[16], 32)
                self.assertEqual(data[17], 0x28)
                self.assertEqual(len(data), 18+w*h*4)
                self.assertEqual(w&(w-1), 0)
                self.assertEqual(h&(h-1), 0)

    def test_plaques_have_transparent_corners_and_sculpted_midpoints(self):
        for name in ("DuelHallPlaque.tga",):
            with self.subTest(name=name):
                data,w,h = pixels(SKIN / name)
                self.assertEqual(rgba(data,w,0,0)[3], 0)
                self.assertEqual(rgba(data,w,w//2,h//2)[3], 255)
                self.assertNotEqual(rgba(data,w,w//2,h//2),
                                    rgba(data,w,w//2,11))
        data,w,h = pixels(SKIN / "DuelHallPlaque.tga")
        red, green, blue, alpha = rgba(data,w,w//2,h//2)
        self.assertGreater(red, green*2)
        self.assertGreater(red, blue*3)

    def test_ornament_assets_have_real_transparency(self):
        for name in ("DuelCornerJewel.tga","DuelMinimalGoldTabs.tga"):
            data,w,h = pixels(SKIN / name)
            alpha = data[21::4]
            self.assertTrue(any(v == 0 for v in alpha), name)
            self.assertTrue(any(v > 230 for v in alpha), name)

    def test_pieces_are_reusable_nineslice_not_a_baked_window(self):
        style,nav,chrome,options,header = (read(p) for p in
            ("UI/Style.lua","UI/Navigation.lua","UI/Chrome.lua",
             "UI/Options.lua","UI/Header.lua"))
        for token in ('function Style.Plate(parent, kind, opts)',
                      'for y = 1, 3 do', 'for x = 1, 3 do',
                      'function group:SetStyle(newKind)',
                      'DuelHallPlaque.tga','DuelExactAtlas.png'):
            self.assertIn(token,style)
        self.assertIn('Style.ConceptImage(button, "hall", "ARTWORK", 2)',nav)
        self.assertNotIn('DuelHallLaurel.tga',nav)
        self.assertIn('DuelMinimalGoldTabs.tga',nav)
        self.assertIn('item.plate:SetStyle(active and "gold" or "dark")',nav)
        self.assertNotIn('for i = 1, 7 do',nav)
        self.assertIn('Style.Plate(rim, "shellCopper"',chrome)
        self.assertIn('Style.Plate(card, "cardBody", { corner=15 })',options)
        self.assertIn('DuelOptionsSoftArt.png', options)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',options)
        self.assertIn('Style.Plate(b, name == "Close" and "hall" or "dark"',header)

    def test_existing_state_and_input_owners_preserved(self):
        nav,header,options = (read(p) for p in
            ("UI/Navigation.lua","UI/Header.lua","UI/Options.lua"))
        for token in ('button:SetScript("OnClick", function() Select(index, 1) end)',
                      'sub:SetScript("OnClick", function() Select(index, pageIndex) end)',
                      'ns.Search.Register("page:" .. section.key'):
            self.assertIn(token,nav)
        for token in ('function Header.Fold(', 'function Header.SetManualPeek(',
                      'function Header.CloseSearch('):
            self.assertIn(token,header)
        self.assertIn('function appearance:Relayout(width)',options)
        self.assertIn('function interface:Relayout(width)',options)

if __name__ == "__main__":
    unittest.main()

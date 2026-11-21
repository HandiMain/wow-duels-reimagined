"""Approved Options banner contracts. Static/asset checks, not live WoW proof."""
from pathlib import Path
import hashlib
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
OPTIONS = (ROOT / "UI" / "Options.lua")
ART = ROOT / "Media" / "Skin" / "DuelOptionsCategoryArt.png"

class ApprovedOptionsBannersTests(unittest.TestCase):
    def test_literal_source_cropped_art_is_valid_png(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], bytes([137,80,78,71,13,10,26,10]))
        self.assertEqual(struct.unpack(">II", data[16:24]), (256, 128))
        self.assertEqual(data[25], 6)  # RGBA: supported by the existing pack
        self.assertEqual(hashlib.sha1(b"blob " + str(len(data)).encode() + bytes([0]) + data).hexdigest(),
                         "f0b185f860d73d94ab44cdad41328bf2313ec7ba")
        at = 8
        while at < len(data):
            length = struct.unpack(">I", data[at:at+4])[0]
            chunk = data[at+4:at+8]
            body = data[at+8:at+8+length]
            crc = struct.unpack(">I", data[at+8+length:at+12+length])[0]
            self.assertEqual(zlib.crc32(chunk + body) & 0xffffffff, crc)
            at += 12 + length
            if chunk == b"IEND":
                break
        self.assertEqual(at, len(data))

    def test_six_cropped_icons_and_six_motifs_on_both_pages(self):
        src = OPTIONS.read_text(encoding="utf-8")
        self.assertIn('DuelOptionsCategoryArt.png', src)
        self.assertEqual(src.count('Section('), 7)
        for key in ('appearance', 'motion', 'access', 'minimap', 'typography', 'notifications'):
            self.assertIn('"' + key + '"', src)
        for title in ("Appearance", "Window & Motion", "Game Access",
                      "Minimap & Widget", "Typography", "Notifications & Help"):
            self.assertIn('"' + title + '"', src)
        self.assertIn('local BANNER_HEIGHT = 50', src)
        self.assertIn('Style.Plate(card, "cardBody", { corner=15 })', src)
        self.assertIn('Style.Plate(headingBand, "cardHeading"', src)
        self.assertIn('local heading = Style.Text(header, title', src)
        self.assertIn('local detail = Style.Text(header, meta.subtitle', src)
        self.assertIn('ns.Tooltips.Bind(header, {', src)
        self.assertIn('if widget.LayoutForWidth then', src)
        self.assertIn('widget.optionsY = sectionY + y', src)
        self.assertIn('function appearance:Relayout(width)', src)
        self.assertIn('function interface:Relayout(width)', src)

if __name__ == "__main__":
    unittest.main()

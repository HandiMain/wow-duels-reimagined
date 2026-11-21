"""Four-part Options and footer polish contract (static; live WoW TBD)."""
from pathlib import Path
import hashlib
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def lua(path):
    return (ROOT / path).read_text(encoding="utf-8")

class ApprovedOptionsPolishTests(unittest.TestCase):
    def test_banners_fit_card_rim_and_leave_controls_below(self):
        o = lua("UI/Options.lua")
        self.assertIn('headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -6)',o)
        self.assertIn('headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -6)',o)
        self.assertIn('local BANNER_LEFT, BANNER_RIGHT = 438, 160',o)
        self.assertIn('local BANNER_HEIGHT = 50',o)
        self.assertIn('local ROW_TOP = 64',o)
        self.assertIn('widget.optionsY = sectionY + y',o)
        self.assertIn('function appearance:Relayout(width)',o)
        self.assertIn('function interface:Relayout(width)',o)

    def test_footer_text_is_clamped_by_its_button_at_every_font_refresh(self):
        s,n,f = (lua(p) for p in
            ("UI/Style.lua","UI/Navigation.lua","UI/Footer.lua"))
        self.assertIn('function Style.ConstrainButtonLabel(',s)
        self.assertIn('fs.GetUnboundedStringWidth or fs.GetStringWidth',s)
        self.assertIn('FitLabelFont(entry)',s)
        self.assertIn('entry.size * scale',s)
        self.assertIn('button:HookScript("OnSizeChanged"',s)
        self.assertIn('Style.ConstrainButtonLabel(button, label, 35, 7, 9)',n)
        self.assertIn('Style.ConstrainButtonLabel(button, title, 25, 9, 9)',f)
        self.assertIn('Style.ConstrainButtonLabel(sub, text, 46, 10, 10)',n)

    def test_simplified_gold_tab_symbols_remain_native_rgba(self):
        b = (ROOT/"Media/Skin/DuelMinimalGoldTabs.tga").read_bytes()
        self.assertEqual(b[2],2)
        self.assertEqual((b[16],b[17]),(32,0x28))
        self.assertEqual(struct.unpack_from("<HH",b,12),(128,64))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
                         "6a15481f315ab81a7b20f7b5a594080dc93db4bf057ff3708761ad102e8879dd")
        n=lua("UI/Navigation.lua")
        self.assertIn('DuelMinimalGoldTabs.tga',n)
        self.assertIn('glyph:SetSize(28, 28)',n)
        self.assertIn('sub:SetScript("OnClick"',n)

    def test_forged_corner_preserves_original_single_resize_owner(self):
        w = lua("UI/Window.lua")
        for marker in ('DuelCorner03Copper.png',
                       'local grip = CreateFrame("Button", nil, frame)',
                       'grip:SetSize(54, 54)',
                       'resizeArt:SetSize(96, 96)',
                       'frame:StartSizing("BOTTOMRIGHT")',
                       'frame:StopMovingOrSizing()',
                       'Window.CommitResize()',
                       'if button == "RightButton" then Window.ResetSize() end',
                       'resizeArt:SetShown(on and true or false)',
                       'close:SetPoint("RIGHT", footer, "RIGHT", -64, 0)',
                       'utility:SetPoint("RIGHT", footer, "RIGHT", -187, 0)'):
            self.assertIn(marker,w)
        self.assertNotIn('ResizeGlyph.tga',w)
        self.assertNotIn('gripGlyph',w)
        self.assertNotIn('frame:SetScript("OnUpdate"',w)

if __name__ == "__main__":
    unittest.main()

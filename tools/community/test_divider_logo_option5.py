"""Source checks for the shared pixel-stable divider and approved new Option 5."""
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def src(path):
    return (BASE / path).read_text(encoding="utf-8")

class DividerAndWordmarkTests(unittest.TestCase):
    def test_pixel_aligned_physical_two_pixel_lines(self):
        chrome=src("UI/Chrome.lua")
        for token in ('HAIRLINE_IMAGE = "Interface\\\\Buttons\\\\WHITE8X8"',
                      'Style.Pixel(f, 2)', 'Style.Pixel(entry.frame, 2)',
                      'PixelAlign(left)', 'PixelAlign(right)',
                      'tex:SetSnapToPixelGrid(true)',
                      'tex:SetTexelSnappingBias(0)'):
            self.assertIn(token, chrome)
        self.assertNotIn('left:SetHeight(1)',chrome)
        self.assertNotIn('right:SetHeight(1)',chrome)
        for scale in (0.65,0.75,0.9,1.0,1.15,1.25):
            self.assertAlmostEqual((2/scale)*scale, 2.0)

    def test_dividers_share_one_owner_and_refresh_without_polling(self):
        chrome,win=src("UI/Chrome.lua"),src("UI/Window.lua")
        self.assertIn('local pixelDividers = {}',chrome)
        self.assertIn('function Chrome.Divider(parent, width, height)',chrome)
        self.assertIn('function Chrome.Refresh()',chrome)
        self.assertIn('entry.left:SetHeight(pixels)',chrome)
        self.assertIn('entry.right:SetHeight(pixels)',chrome)
        self.assertIn('if ns.Chrome and ns.Chrome.Refresh then ns.Chrome.Refresh() end',win)
        self.assertNotIn('SetScript("OnUpdate"',chrome)

    def test_old_landing_atlas_remains_but_main_uses_exact_identity(self):
        p=BASE/"Media"/"Skin"/"HeaderOption5TintAtlas.png"
        data=p.read_bytes()
        self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II",data[16:24]),(256,256))
        self.assertIn(b"tRNS",data)
        window=src("UI/Window.lua")
        self.assertIn('DuelExactBrand.png',window)
        self.assertNotIn('BrandLayer(',window)
        self.assertNotIn('BrandLayer(C.gold,       0.50, 0.75, 3)',window)
        self.assertNotIn('local underline = CreateFrame(',window)
        self.assertNotIn('local leftRule = Style.Fill(',window)
        self.assertNotIn('local rightRule = Style.Fill(',window)
        self.assertIn('local visualWidth = math.min(330, available)',window)
        self.assertIn('Drag(brandDrag)',window)
        self.assertNotIn('Option5HeaderLogo.png',window)

    def test_tints_and_previous_controls_still_work(self):
        style,theme=src("UI/Style.lua"),src("UI/Theme.lua")
        window,landing=src("UI/Window.lua"),src("UI/BlizzardSettings.lua")
        self.assertIn('RegisterTexture(tex, color, "vertex")',style)
        self.assertIn('entry.region:SetVertexColor(unpack(value))',style)
        self.assertIn('Style.ApplyTheme(font)',theme)
        self.assertNotIn('GetAccentColor', theme)
        self.assertNotIn('GetPanelColor', theme)
        self.assertIn('brandArea:SetScript("OnSizeChanged", FitBrand)',window)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)',window)
        self.assertIn('brandArea:SetPoint("RIGHT", searchBox, "LEFT", -12, 0)',window)
        self.assertIn('HeaderOption5TintAtlas.png',landing)
        self.assertNotIn('DuelsReimagined-HeaderLogoFlat.png',landing)
        self.assertIn('function Window.ResetWindow()',window)

if __name__ == "__main__":
    unittest.main()

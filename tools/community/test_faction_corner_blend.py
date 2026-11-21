"""Concept 06 integration and image/state safeguards; not live WoW proof."""
from pathlib import Path
import hashlib, struct, unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
SKIN=ROOT/"Media"/"Skin"
def lua(n):return (ROOT/n).read_text(encoding="utf-8")

class FactionCornerBlendTests(unittest.TestCase):
    def test_rebalanced_faction_assets_and_native_rgba(self):
        for name,digest in (
            ("DuelFactionCorner06Blended.png","6a7923d5249901b6231736fa6c03cc5ad44d0d8c2fae2aa3886926dd90b450f2"),
            ("DuelFactionCorner06BlendedHover.png","60ff9bfa2f585401ac94a64d5208e6bd819a9169fcf54e55d4382e65f330774a"),
            ("DuelFactionCorner06BlendedPress.png","3e38b902c7719ed526e200904f28e4ba45b7e75c8a9a51dd1cae407e94c03218"),
        ):
            b=(SKIN/name).read_bytes()
            self.assertEqual(b[:8],bytes((137,80,78,71,13,10,26,10)))
            self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6))
            self.assertEqual(hashlib.sha256(b).hexdigest(),digest)

    def test_art_sits_below_chrome_perimeter_not_over_buttons(self):
        w,c=lua("UI/Window.lua"),lua("UI/Chrome.lua")
        self.assertIn("resizeArt:SetFrameLevel(frame:GetFrameLevel() + 18)",w)
        self.assertIn("rim:SetFrameLevel(frame:GetFrameLevel() + 20)",c)
        self.assertIn('Style.Plate(rim, "shellCopper"',c)
        self.assertIn("resizeArt:SetSize(96, 96)",w)
        self.assertIn("resizeArt:EnableMouse(false)",w)
        self.assertIn("grip:SetSize(54, 54)",w)
        self.assertIn('grip:SetFrameLevel(frame:GetFrameLevel() + 45)',w)
        self.assertIn('close:SetPoint("RIGHT", footer, "RIGHT", -64, 0)',w)

    def test_hover_press_drag_fold_reset_still_work_via_one_owner(self):
        w=lua("UI/Window.lua")
        for token in (
            "DuelFactionCorner06BlendedHover.png",
            "DuelFactionCorner06BlendedPress.png",
            'gripGlow:SetBlendMode("ADD")',
            'gripPress:SetBlendMode("ADD")',
            "Motion.Fade(gripGlow, alpha, duration)",
            "Motion.Fade(gripPress, pressed and 0.94 or 0, duration)",
            'frame:StartSizing("BOTTOMRIGHT")',
            "Window.CommitResize()",
            'if button == "RightButton" then Window.ResetSize() end',
            "resizeArt:SetShown(on and true or false)",
        ):self.assertIn(token,w)
        self.assertEqual(w.count('local grip = CreateFrame("Button", nil, frame)'),1)
        self.assertNotIn('frame:SetScript("OnUpdate"',w)

if __name__ == "__main__":
    unittest.main()

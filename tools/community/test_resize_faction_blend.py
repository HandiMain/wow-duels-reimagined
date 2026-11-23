"""Artwork 06 integration and image/state safeguards; not live WoW proof."""
from pathlib import Path
import hashlib, struct, unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
SKIN=ROOT/"Media"/"Skin"
def lua(n):return (ROOT/n).read_text(encoding="utf-8")

class FactionCornerBlendTests(unittest.TestCase):
    def test_rebalanced_faction_assets_and_native_rgba(self):
        for name,digest in (
            ("DuelResizeCopper.png","e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc"),
            ("DuelResizeHover.png","b8be31d80cf2f69119950499e2994a39b0b1373af767dd1a3270446d1f8944e5"),
            ("DuelResizePress.png","8ce544af9cdc3809757eaa9b13906bc1f94dd65f4ffea705b991c665e2b9e065"),
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
            "DuelResizeHover.png",
            "DuelResizePress.png",
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

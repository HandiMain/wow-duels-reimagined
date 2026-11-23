"""Artwork 06 Alliance/Horde corner: art integrity and mouse state contracts.
Static tests are NOT live WoW visual/interaction verification.
"""
from pathlib import Path
import hashlib
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
SKIN = ROOT / "Media" / "Skin"

def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

class Artwork06CornerTests(unittest.TestCase):
    def test_rgba_base_hover_and_pressed_art(self):
        cases = (
            ("DuelResizeCopper.png", "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc"),
            ("DuelResizeHover.png", "b8be31d80cf2f69119950499e2994a39b0b1373af767dd1a3270446d1f8944e5"),
            ("DuelResizePress.png", "8ce544af9cdc3809757eaa9b13906bc1f94dd65f4ffea705b991c665e2b9e065"),
        )
        for name, digest in cases:
            data = (SKIN / name).read_bytes()
            self.assertEqual(data[:8], bytes([137, 80, 78, 71, 13, 10, 26, 10]), name)
            self.assertEqual(struct.unpack_from(">IIBB", data, 16), (256,256,8,6), name)
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest, name)
            pos = 8
            while pos < len(data):
                n = struct.unpack_from(">I", data, pos)[0]
                tag = data[pos+4:pos+8]
                value = data[pos+8:pos+8+n]
                crc = struct.unpack_from(">I", data, pos+8+n)[0]
                self.assertEqual(zlib.crc32(tag+value) & 0xffffffff, crc, name)
                pos += 12+n
                if tag == b"IEND":
                    break
            self.assertEqual(pos,len(data),name)

    def test_shared_motion_and_resizing_owner(self):
        w=source("UI/Window.lua")
        for marker in (
            "resizeArt:SetSize(96, 96)",
            "resizeArt:SetFrameLevel(frame:GetFrameLevel() + 18)",
            "grip:SetSize(54, 54)",
            "resizeArt:EnableMouse(false)",
            'grip:RegisterForClicks("RightButtonUp")',
            'gripGlow:SetBlendMode("ADD")',
            'gripPress:SetBlendMode("ADD")',
            'Motion.Fade(gripGlow, alpha, duration)',
            'Motion.Fade(gripPress, pressed and 0.94 or 0, duration)',
            "ShiftCorner(true)", "ShiftCorner(false)",
            'GripFeedback(0.94, Motion.Duration("quick"))',
            'GripFeedback(pressed and 0.94 or 0.62, Motion.Duration("quick"))',
            'frame:StartSizing("BOTTOMRIGHT")',
            'frame:StopMovingOrSizing()',
            'Window.CommitResize()',
            'if button == "RightButton" then Window.ResetSize() end',
            'Motion.Stop(gripGlow, 0)',
            'Motion.Stop(gripPress, 0)',
            'resizeArt:SetShown(on and true or false)',
        ):
            self.assertIn(marker,w)
        self.assertEqual(w.count('local grip = CreateFrame("Button", nil, frame)'),1)
        self.assertNotIn('frame:SetScript("OnUpdate"',w)
        self.assertNotIn('DuelFilledTriangleCorner.png',w)

    def test_footer_safety_and_unchanged_approved_art(self):
        w=source("UI/Window.lua")
        self.assertIn('close:SetPoint("RIGHT", footer, "RIGHT", -64, 0)',w)
        self.assertIn('utility:SetPoint("RIGHT", footer, "RIGHT", -187, 0)',w)
        # Distance from the active grip to Close (54 vs 64) and
        # from Close to utility (187 vs 64+105) is strictly positive.
        self.assertGreater(64-54,0)
        self.assertGreater(187-(64+105),0)
        self.assertIn("DuelTabIcons.tga",source("UI/Navigation.lua"))
        self.assertIn("DuelOptionsBanner.png",source("UI/Options.lua"))
        self.assertFalse((SKIN/"DuelFilledTriangleCorner.png").exists())
        for old in ("DuelFactionCorner06.png","DuelFactionCorner06Hover.png","DuelFactionCorner06Press.png",
                    "DuelFactionCorner06Blended.png","DuelFactionCorner06BlendedHover.png","DuelFactionCorner06BlendedPress.png"):
            self.assertFalse((SKIN/old).exists())

if __name__ == "__main__":
    unittest.main()
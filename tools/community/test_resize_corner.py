"""Approved copper Artwork 03 corner: native graphic and interaction checks.

These tests verify packaged pixels and Lua contracts; only WoW verifies visuals.
"""
from pathlib import Path
import hashlib
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
SKIN = ROOT/"Media"/"Skin"

def source(filename):
    return (ROOT/filename).read_text(encoding="utf-8")

class ApprovedCorner03Tests(unittest.TestCase):
    def test_source_extracted_copper_filigree_and_distinct_state_layers(self):
        cases = {
            "DuelResizeCopper.png": "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc",
            "DuelResizeHover.png": "b8be31d80cf2f69119950499e2994a39b0b1373af767dd1a3270446d1f8944e5",
            "DuelResizePress.png": "8ce544af9cdc3809757eaa9b13906bc1f94dd65f4ffea705b991c665e2b9e065",
        }
        for name,digest in cases.items():
            b=(SKIN/name).read_bytes()
            self.assertEqual(b[:8],bytes((137,80,78,71,13,10,26,10)),name)
            self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6),name)
            self.assertEqual(hashlib.sha256(b).hexdigest(),digest,name)
            i=8
            while i < len(b):
                n=struct.unpack_from(">I",b,i)[0]
                typ=b[i+4:i+8]
                payload=b[i+8:i+8+n]
                crc=struct.unpack_from(">I",b,i+8+n)[0]
                self.assertEqual(zlib.crc32(typ+payload)&0xffffffff,crc,name)
                i+=12+n
                if typ==b"IEND":break
            self.assertEqual(i,len(b),name)

    def test_single_copper_shell_perimeter_with_noninteractive_corner_art(self):
        w,c=source("UI/Window.lua"),source("UI/Chrome.lua")
        self.assertIn('resizeArt:SetSize(96, 96)',w)
        self.assertIn('resizeArt:SetFrameLevel(frame:GetFrameLevel() + 18)',w)
        self.assertIn('rim:SetFrameLevel(frame:GetFrameLevel() + 20)',c)
        self.assertIn('Style.Plate(rim, "shellCopper"',c)
        self.assertIn('resizeArt:EnableMouse(false)',w)
        self.assertIn('grip:SetSize(54, 54)',w)
        self.assertIn('close:SetPoint("RIGHT", footer, "RIGHT", -64, 0)',w)
        self.assertNotIn("DuelFactionCorner06",w)

    def test_approved_hover_click_glow_and_resize_lifecycle_preserved(self):
        w=source("UI/Window.lua")
        for token in (
            'DuelResizeHover.png','DuelResizePress.png',
            'gripGlow:SetBlendMode("ADD")',
            'gripPress:SetBlendMode("ADD")',
            'Motion.Fade(gripGlow, alpha, duration)',
            'Motion.Fade(gripPress, pressed and 0.94 or 0, duration)',
            'ShiftCorner(true)','ShiftCorner(false)',
            'GripFeedback(0.94, Motion.Duration("quick"))',
            'frame:StartSizing("BOTTOMRIGHT")',
            'Window.CommitResize()',
            'if button == "RightButton" then Window.ResetSize() end',
            'Motion.Stop(gripGlow, 0)','Motion.Stop(gripPress, 0)',
            'resizeArt:SetShown(on and true or false)',
        ):
            self.assertIn(token,w)
        self.assertEqual(w.count('local grip = CreateFrame("Button", nil, frame)'),1)
        self.assertNotIn('frame:SetScript("OnUpdate"',w)

    def test_unapproved_dual_faction_art_not_packaged(self):
        for name in ("DuelFactionCorner06.png","DuelFactionCorner06Hover.png",
                     "DuelFactionCorner06Press.png","DuelFactionCorner06Blended.png",
                     "DuelFactionCorner06BlendedHover.png","DuelFactionCorner06BlendedPress.png"):
            self.assertFalse((SKIN/name).exists(),name)
        self.assertIn("DuelTabIcons.tga",source("UI/Navigation.lua"))
        self.assertIn("DuelOptionsBanner.png",source("UI/Options.lua"))

if __name__=="__main__": unittest.main()

"""Compact default dimensions, reset consistency, and header logo clearance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"

def source(path):
    return (ADDON / path).read_text(encoding="utf-8")

class CompactDefaultWindowTests(unittest.TestCase):
    def test_default_is_existing_resize_minimum(self):
        window = source("UI/Window.lua")
        self.assertIn("local MIN_WIDTH, MIN_HEIGHT, EDGE = 1050, 650, 16", window)
        self.assertIn("frame:SetSize(MIN_WIDTH, MIN_HEIGHT)", window)
        self.assertIn("math.min(MIN_WIDTH, maxW)", window)
        self.assertIn("math.min(MIN_HEIGHT, maxH)", window)
        self.assertIn("return minW, minH, minW, minH, maxW, maxH", window)
        self.assertNotIn("BASE_WIDTH", window)
        self.assertNotIn("GetPhysicalScreenSize", window)
        self.assertIn("frame:SetResizeBounds(minW, minH, maxW, maxH)", window)
        self.assertIn("Settings.GetWindowSize()", window)

    def test_reset_and_resizing_use_same_default(self):
        window = source("UI/Window.lua")
        footer = source("UI/Footer.lua")
        self.assertIn("function Window.DefaultSize()", window)
        self.assertIn("return WindowGeometry(Settings.Get", window)
        self.assertIn("Settings.SetWindowSize(nil)", window)
        self.assertIn('Settings.Reset("menuScale")', window)
        self.assertIn("Window.ApplyScale(Settings.Get", window)
        self.assertIn("if math.abs(w - defaultW) <= 2 and math.abs(h - defaultH) <= 2", window)
        self.assertIn("return math.abs(w - dw) <= 2 and math.abs(h - dh) <= 2", window)
        self.assertIn("function Window.IsDefault()", window)
        self.assertIn("Window.IsDefault()", footer)
        self.assertIn("Window.ResetWindow()", footer)
        self.assertIn("if button == \"RightButton\" then Window.ResetSize() end", window)

    def test_saved_prefs_and_uiscale_are_unchanged(self):
        window = source("UI/Window.lua")
        settings = source("Core/Settings.lua")
        self.assertIn("Settings.GetWindowSize()", window)
        self.assertIn("savedW or dw", window)
        self.assertIn("savedH or dh", window)
        self.assertIn("Settings.SetWindowSize(w, h)", window)
        self.assertIn("db.windowSize = nw and { width = nw, height = nh } or nil", settings)
        self.assertIn("if userInput or draggingScale then pendingScale", window)

    def test_header_logo_only_reduces_its_own_height(self):
        window = source("UI/Window.lua")
        landing = source("UI/BlizzardSettings.lua")
        self.assertIn("BRAND_MAX_WIDTH, BRAND_MAX_HEIGHT = 250, 55", window)
        self.assertIn("HeaderOption5TintAtlas.png", window)
        self.assertIn("brandArea:SetPoint(\"RIGHT\", searchBox,", window)
        self.assertIn("HeaderOption5TintAtlas.png", landing)
        self.assertNotIn("Option5HeaderLogo.png", landing)

if __name__ == "__main__":
    unittest.main()

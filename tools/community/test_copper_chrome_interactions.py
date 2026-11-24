"""Copper frame + shared button-feedback regression contracts.

Source assertions are NOT a substitute for live in-game visual confirmation.
"""
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def lua(rel):
    return (ROOT / rel).read_text(encoding="utf-8")

class CopperChromeTests(unittest.TestCase):
    def test_frame_is_a_real_rgba_texture_not_a_screenshot(self):
        data = (ROOT / "Media/Skin/DuelFrameRim.png").read_bytes()
        self.assertEqual(data[:8], bytes([137,80,78,71,13,10,26,10]))
        w,h,depth,color = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((w,h,depth,color), (512,512,8,6))
        self.assertLess(len(data), 200000)

    def test_one_border_owner_and_no_floating_corner_jewels(self):
        st,ch,wi = (lua(p) for p in ("UI/Style.lua","UI/Chrome.lua",
                                    "UI/Window.lua"))
        self.assertIn('shellCopper = { path=PLATE_ROOT .. "DuelFrameRim.png"',st)
        self.assertIn('Style.Plate(rim, "shellCopper"',ch)
        self.assertNotIn('Style.PlateImage(rim, "corner"',ch)
        self.assertNotIn('GlowSeam(',ch)
        self.assertIn('corner=12, edge=C.window, shine=0.07, shade=0.11, rim=0',wi)
        self.assertIn('Window.chromeSeams = Chrome.Shell',wi)

    def test_navigation_seam_follows_hidden_navigation(self):
        ch = lua("UI/Chrome.lua")
        nav = lua("UI/Navigation.lua")
        # A shell-owned texture may remain across the Patch Notes banner.
        # Parenting the separator to the nav frame makes hide unconditional
        # and preserves the line when ordinary multi-page tabs are visible.
        self.assertIn('local navSeam = Line(nav, nav, "BOTTOMLEFT", "BOTTOMRIGHT"', ch)
        self.assertIn('navSeam:EnableMouse(false)', ch)
        self.assertNotIn('Line(seams, nav, "BOTTOMLEFT", "BOTTOMRIGHT", false, C.goldDim)', ch)
        self.assertNotIn('navSeam:SetShown(nav:IsShown())', ch)
        self.assertNotIn('nav:HookScript("OnHide", function() navSeam:Hide() end)', ch)
        self.assertIn('Window.nav:SetShown(#section.pages > 1 and section.key ~= "patchnotes" and not page.competitive)', nav)

    def test_shared_presses_and_no_new_polling_engine(self):
        w=lua("UI/Widgets.lua")
        motion=lua("UI/Motion.lua")
        for token in ('function Widgets.PressFeedback(button, hover, opts)',
                      'button._duelsPressBound = true',
                      'button:HookScript("OnMouseDown"',
                      'button:HookScript("OnMouseUp"',
                      'button:HookScript("OnClick"',
                      'button:HookScript("OnHide"',
                      'Motion.Fade(flash, 0, Motion.Duration("gentle"))',
                      'self.available ~= false'):
            self.assertIn(token,w)
        self.assertIn('if not next(active) then driver:SetScript("OnUpdate", nil)',motion)
        self.assertNotIn('CreateFrame("Frame")\nlocal active',w)

    def test_hover_selected_pressed_are_independent(self):
        nav=lua("UI/Navigation.lua")
        header=lua("UI/Header.lua")
        footer=lua("UI/Footer.lua")
        self.assertIn('Hover is visible even on the currently selected destination.',nav)
        self.assertIn('activeAlpha = isPrimary and 0.15 or 0.33',nav)
        self.assertIn('activeAlpha = 0.13',nav)
        self.assertIn('item.plate:SetStyle(active and "gold" or "dark")',nav)
        self.assertIn('Motion.Fade(foldButton.chosen, folded and 0.58',header)
        self.assertIn('Motion.Fade(Header.peekButton.chosen, manualPeek and 0.52',header)
        self.assertIn('ns.Widgets.PressFeedback(discord, nil, {',footer)
        self.assertIn('ns.Widgets.PressFeedback(button, hover, {',footer)
        self.assertIn('function Header.Fold(value)',header)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)',nav)

    def test_hover_and_click_glows_are_above_approved_art(self):
        style=lua("UI/Style.lua")
        nav=lua("UI/Navigation.lua")
        header=lua("UI/Header.lua")
        footer=lua("UI/Footer.lua")
        widget=lua("UI/Widgets.lua")
        self.assertIn('function Style.FeedbackOverlay(parent, opts)',style)
        self.assertIn('"shine", "OVERLAY", 0, corner, inset',style)
        self.assertIn('"rim", "OVERLAY", 1, corner, inset',style)
        self.assertIn('local selected = Style.FeedbackOverlay(button',nav)
        self.assertIn('local hover = Style.FeedbackOverlay(button',nav)
        self.assertIn('local hover = Style.FeedbackOverlay(b',header)
        self.assertIn('local chosen = Style.FeedbackOverlay(b',header)
        self.assertIn('local hover = Style.FeedbackOverlay(button',footer)
        self.assertIn('"shine", "OVERLAY", -1,',widget)

if __name__ == "__main__":
    unittest.main()

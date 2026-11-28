"""Verify the approved reusable menu art, with no screenshot or baked labels."""
from pathlib import Path
import hashlib
import re
import struct
import unittest

A=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (A/p).read_text(encoding="utf-8")

class SharedMenuArt(unittest.TestCase):
    def test_exact_extracted_rgba_assets(self):
        for path,size,sha in (
            ("Media/Skin/DRMenuPlates.png",(256,256),"cbafb33fb278c83f0f2f61772005e6a486684606"),
            ("Media/Icons/DRMenuEmblems.png",(512,128),"d7a203ea7e66d82d38de78738a5d28f51486e263"),
        ):
            data=(A/path).read_bytes()
            self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack_from(">IIBB",data,16),(*size,8,6))
            self.assertEqual(hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest(),sha)
        self.assertFalse((A/"Media/Skin/DuelTournamentPlate.png").exists())
        self.assertFalse((A/"Media/Skin/DuelWarGamesPlate.png").exists())

    def test_all_destinations_share_the_renderer(self):
        style=read("UI/Style.lua")
        nav=read("UI/Navigation.lua")
        win=read("UI/Window.lua")
        self.assertEqual(nav.count("Style.MenuButton(button, section.key, section.label"),1)
        self.assertIn('Style.MenuButton(close,"close","Close",{danger=true})',win)
        self.assertNotIn("CompetitiveUI.Plaque",nav)
        self.assertNotIn("AchievementUI.Plaque",nav)
        self.assertNotIn("Style.PlateImage(button",nav)
        self.assertNotIn("label:Hide()",nav)
        self.assertIn("opts.emblemTexture",style)
        cells=style.split("local menuEmblems={",1)[1].split("\n}",1)[0]
        specs=re.findall(r"(\w+)=\{(\d+),(\d+),(\d+),(\d+)\}",cells)
        self.assertEqual(len(specs),11)
        rects=[]
        for key,x,y,w,h in specs:
            x,y,w,h=map(int,(x,y,w,h))
            self.assertGreater(w,0);self.assertGreater(h,0)
            self.assertLessEqual(x+w,512);self.assertLessEqual(y+h,128)
            for a,b,c,d in rects:
                self.assertTrue(x+w<=a or a+c<=x or y+h<=b or b+d<=y,key)
            rects.append((x,y,w,h))

    def test_footer_widths_are_data_and_stay_in_budget(self):
        nav=read("UI/Navigation.lua")
        self.assertIn("section.footerWidths or {90,120}",nav)
        self.assertIn("local budget=409+89*ratio",nav)
        for ratio in (0,.5,1):
            for widths in ([(112,136),(102,110),(98,124),(82,104)],
                           [(112,136),(102,110),(98,124),(82,104),(90,120)]):
                gap=5+3*ratio
                budget=409+89*ratio
                preferred=[a+(b-a)*ratio for a,b in widths]
                factor=min(1,max(1,budget-gap*(len(widths)-1))/max(1,sum(preferred)))
                self.assertLessEqual(sum(preferred)*factor+gap*(len(widths)-1),budget+1e-8)

if __name__=="__main__": unittest.main()

"""Result presentation assets and safe title layout (not a live visual test)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
class ResultVisualTest(unittest.TestCase):
    def test_stat_atlas_is_transparent_and_distinct(self):
        data=(ROOT/"Media/Skin/DuelResultStatIcons.tga").read_bytes()
        self.assertEqual(data[2],2)
        self.assertEqual(data[12:18],bytes((128,0,128,0,32,40)))
        self.assertEqual(len(data),18+128*128*4)
        masks=[]
        for x,y in ((0,0),(64,0),(0,64),(64,64)):
            alpha=bytes(data[18+4*(128*(y+j)+x+i)+3] for j in range(64) for i in range(64))
            masks.append(alpha)
        for alpha in masks[:3]:
            self.assertGreater(sum(v>0 for v in alpha),300)
            self.assertLess(sum(v>0 for v in alpha),2300)
            self.assertGreater(len(set(alpha)),3)
        self.assertEqual(len(set(masks[:3])),3)
        self.assertFalse(any(masks[3]))
    def test_title_clear_of_crest_and_rule(self):
        src=(ROOT/"UI/DuelResult.lua").read_text()
        self.assertIn('DuelResultStatIcons.tga',src)
        self.assertNotIn('INV_Sword_04',src)
        self.assertNotIn('INV_Shield_04',src)
        self.assertNotIn('Spell_Holy_Heal',src)
        self.assertIn('local icons={{0,.5,0,.5},{.5,1,0,.5},{0,.5,.5,1}}',src)
        heading=re.search(r'heading=Label\(card,"VICTORY",(\d+),(\d+),(\d+),-(\d+)',src)
        subtitle=re.search(r'subtitle=Label\(card,"",(\d+),(\d+),(\d+),-(\d+)',src)
        self.assertIsNotNone(heading);self.assertIsNotNone(subtitle)
        self.assertGreaterEqual(int(heading[4]),65+8)
        self.assertLessEqual(int(heading[4])+int(heading[3]),int(subtitle[4]))
if __name__=="__main__":
    unittest.main()

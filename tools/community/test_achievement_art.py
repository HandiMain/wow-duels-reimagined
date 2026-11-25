from pathlib import Path
import re
import struct
import hashlib
import unittest

ADDON=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"

class AchievementArtTests(unittest.TestCase):
    def test_custom_icon_catalogue_and_hidden_slot(self):
        core=(ADDON/"Core/Achievements.lua").read_text()
        ui=(ADDON/"UI/AchievementUI.lua").read_text()
        ids=set(re.findall(r'^\s*\{"([a-z]+)","(?:Dueling|Mastery|Competitive|Rivalries|Legacy)"',core,re.M))
        mapping=ui.split("local iconSlots={",1)[1].split("}",1)[0]
        slots=dict((name,int(slot)) for name,slot in re.findall(r"(\w+)=(\d+)",mapping))
        self.assertEqual(len(ids),30)
        self.assertEqual(set(slots),ids)
        self.assertEqual(set(slots.values()),set(range(30)))
        self.assertIn("HIDDEN_SLOT=35",ui)
        self.assertIn("U.PaintAchievementIcon(f.icon,r.id,r.hidden)",ui)
        self.assertIn("PaintIcon(t,hidden and HIDDEN_SLOT or iconSlots[id] or HIDDEN_SLOT)",ui)
        self.assertNotIn("Interface\\\\Icons",ui)
        self.assertNotIn("wreathL",ui)
        self.assertNotIn("pointsLaurel",ui)
        self.assertIn('f.medallion=Crop(f,"ARTWORK",1,768,274,128,92)',ui)
        self.assertIn('pointsPlaque=Crop(pointsPanel,"ARTWORK",1,0,784,384,126)',ui)
        self.assertIn("f.points:SetText(tostring(r.points))",ui)
        self.assertIn("points:SetText(tostring(data.points))",ui)
    def test_shared_motion_contract(self):
        ui=(ADDON/"UI/AchievementUI.lua").read_text()
        self.assertIn("local M=ns.Motion",ui)
        self.assertIn("W.PressFeedback(b,hover,{corner=11,hoverAlpha=.25,clickAlpha=.52})",ui)
        self.assertIn("if b.chosen==on then return end",ui)
        self.assertIn("M.Fade(selected,on and .13 or 0,.18)",ui)
        self.assertIn("M.Stop(b._duelsPressFlash,0)",ui)
        self.assertNotIn('SetScript("OnUpdate"',ui)
        self.assertNotIn("CreateAnimationGroup",ui)

    def test_exact_packaged_atlas(self):
        data=(ADDON/"Media/Skin/DuelAchievementArt.png").read_bytes()
        self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II",data[16:24]),(1024,1024))
        self.assertEqual(hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest(),"b61e3b9afc29c8114fabffb1f6042f612a3cfc93")

if __name__=="__main__": unittest.main()

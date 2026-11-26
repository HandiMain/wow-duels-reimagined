from pathlib import Path
import re
import struct
import hashlib
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"
SOURCE_ART=ROOT/"tools/community/artwork"

class AchievementArtTests(unittest.TestCase):
    def test_custom_icon_catalogue_and_hidden_slot(self):
        core=(ADDON/"Core/Achievements.lua").read_text()
        ui=(ADDON/"UI/AchievementUI.lua").read_text()
        ids=set(re.findall(r'^\s*\{"([a-z]+)","(?:Dueling|Mastery|Competitive|Rivalries|Legacy)"',core,re.M))
        mapping=ui.split("local iconSlots={",1)[1].split("}",1)[0]
        slots=dict((name,int(slot)) for name,slot in re.findall(r"(\w+)=(\d+)",mapping))
        extra_mapping=ui.split("local expansionSlots={",1)[1].split("}",1)[0]
        extra_slots=dict((name,int(slot)) for name,slot in re.findall(r"(\w+)=(\d+)",extra_mapping))
        self.assertEqual(len(extra_slots),16)
        self.assertEqual(set(extra_slots.values()),set(range(10,26)))
        self.assertEqual(len(ids),39)
        self.assertEqual(set(slots),ids-set(extra_slots))
        self.assertEqual(set(slots.values()),set(range(30)))
        tournament_ids=set(re.findall(r'^\s*\{"([a-z]+)","Tournaments"',core,re.M))
        tour_mapping=ui.split("local tourSlots={",1)[1].split("}",1)[0]
        tour_slots=dict((name,int(slot)) for name,slot in re.findall(r"(\w+)=(\d+)",tour_mapping))
        self.assertEqual(len(tournament_ids),16)
        self.assertEqual(set(tour_slots),tournament_ids-set(extra_slots))
        self.assertEqual(set(slots)|set(tour_slots)|set(extra_slots),ids|tournament_ids)
        expansion=(SOURCE_ART/"AchievementExpansionArt.png").read_bytes()
        self.assertEqual(struct.unpack(">II",expansion[16:24]),(1024,512))
        self.assertEqual(hashlib.sha1(b"blob "+str(len(expansion)).encode()+b"\0"+expansion).hexdigest(),"ea5b7482285551ff74d87c3f915dc3b22cc64aca")
        self.assertIn("rim:SetTexture(COMMON_FRAME)",ui)
        self.assertIn("rim:SetAllPoints(t)",ui)
        self.assertIn("t:SetTexture(FRAMED_ART)",ui)
        self.assertIn("TintFrame(f.icon",ui)
        self.assertNotIn("PaintIcon(t,0)",ui)
        self.assertIn("HideFrame(t)",ui)
        self.assertIn("CollectionIcon(categoryEmblem)",ui)
        for filename, dimensions, digest in [
            ("AchievementCommonFrame.png",(256,256),"d11f31b8ea66ca836f009211284249a28612aeb8"),
            ("AchievementFramedArt.png",(1024,512),"8159fb59572c68f5b71450e7763024a9afaf21ad"),
        ]:
            image=(ADDON/"Media/Skin"/filename).read_bytes()
            self.assertEqual(image[:8],b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II",image[16:24]),dimensions)
            self.assertEqual(hashlib.sha1(b"blob "+str(len(image)).encode()+b"\0"+image).hexdigest(),digest)
        self.assertEqual(set(tour_slots.values()),set(range(9)))
        data=(SOURCE_ART/"TournamentAchievementArt.png").read_bytes()
        self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II",data[16:24]),(512,512))
        self.assertEqual(hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest(),"c435e48a1757c92eddb1256af7853992c1a16e68")
        self.assertIn("HIDDEN_SLOT=35",ui)
        self.assertIn("U.PaintAchievementIcon(f.icon,r.id,r.hidden)",ui)
        self.assertIn("PaintIcon(t,hidden and HIDDEN_SLOT or iconSlots[id] or HIDDEN_SLOT,parent)",ui)
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

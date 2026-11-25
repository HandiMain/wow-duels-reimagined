from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (ROOT/p).read_text(encoding="utf-8")

class DuelHUDTests(unittest.TestCase):
    def test_approved_concept_art_and_bounded_regions(self):
        h=read("UI/DuelHUD.lua")
        self.assertIn("DuelHUDArt.png",h)
        self.assertNotIn('Artwork("shell"',h)
        for part in ("bodyFill","sideEdge","topEdge","bottomEdge","topLeft","topRight","bottomLeft","bottomRight","gem","headerFace","timerFace","timerBlade","statRow"):
            self.assertIn('Artwork("'+part+'"',h)
        self.assertIn("f:ClearAllPoints();f:SetPoint",h)
        self.assertNotIn("S.Fill(",h)
        self.assertNotIn("S.Skin(root",h)
        self.assertTrue((ROOT/"Media/Skin/DuelHUDArt.png").is_file())
        self.assertIn("DuelHUDPremiumParts.png",h)
        self.assertIn('local foldedTrim=CreateFrame("Frame",nil,root)',h)
        self.assertIn("body:SetShown(not folded);foldedTrim:SetShown(folded)",h)

    def test_rounded_health_assets_and_secret_safe_percentage(self):
        import hashlib, struct
        assets={
            "DuelHUDPremiumParts.png": ((1024,512),"ef13136df2a270171e43968c1fa2820ed7899309"),
            "DuelHUDHealthFill.png": ((256,32),"77aa11d7b1e264d25b1e7b03ac2fd36d9027536d"),
            "DuelHUDHealthMask.png": ((256,32),"953bba2639425582fe6b138f9ca083ad77a3e412"),
        }
        for name,(dims,sha) in assets.items():
            data=(ROOT/"Media/Skin"/name).read_bytes()
            self.assertEqual(struct.unpack(">II",data[16:24]),dims)
            self.assertEqual(hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest(),sha)
        h=read("UI/DuelHUD.lua")
        for token in ('Artwork("healthTrack",x,181,142,19)','side.hp:SetStatusBarTexture(HEALTH_FILL)',
                      'tex:AddMaskTexture(mask)','pcall(UnitHealthPercent,unit,false,CurveConstants.ScaleTo100)',
                      'if Secret(percent) then','pcall(side.hpText.SetFormattedText,side.hpText,"%.0f%%",percent)',
                      'elseif type(percent)=="number" and percent>=0 and percent<=100 then'):
            self.assertIn(token,h)

    def test_secret_measurement_not_used_by_health_labels(self):
        h=read("UI/DuelHUD.lua")
        self.assertNotIn("S.ConstrainText(side.hpText",h)
        s=read("UI/Style.lua")
        self.assertIn("if not ok or not ReadableNumber(width) then return end",s)
        self.assertIn("pcall(issecretvalue,v)",s)
        self.assertIn("local ok,width=pcall(measure,fs)",s)

    def test_independent_default_and_settings(self):
        s,o,h=read("Core/Settings.lua"),read("UI/Options.lua"),read("UI/DuelHUD.lua")
        self.assertIn("duelHUDEnabled = true",s)
        self.assertIn("duelHUDLocked = false",s)
        self.assertIn("math.max(.8,math.min(1.2",s)
        self.assertIn("Settings.SetDuelHUDPosition",h)
        self.assertIn('CreateFrame("Frame","DuelsReimaginedDuelHUD",UIParent)',h)
        self.assertIn('RegisterOption("duelHUDScale"',o)
        self.assertIn("UI\\DuelHUD.lua",read("DuelsReimagined.toc"))
    def test_read_only_lifecycle_and_damage(self):
        h=read("UI/DuelHUD.lua")
        for token in ('ns.DuelDetection.Subscribe(Receive)','root:UnregisterAllEvents()',
                      'root:SetScript("OnUpdate",nil)','ResetDamage(activeID)',
                      'ns.DuelDetection.LaunchWidgetChallenge(ranked,id.guid)','Native(ForfeitDuel)',
                      'Plain(UnitGUID,unit)==id.guid','side.hp:SetMinMaxValues(0,max)',
                      'side.hp:SetValue(value)','SOLO PREVIEW - SIMULATED'):
            self.assertIn(token,h)
        for forbidden in ("ResetAllCombatSessions(","SendChatMessage(","CreateMacro(","EditMacro(",
                          "RecordLocalObservation(","CommitPeerNode(","Communication.Send("):
            self.assertNotIn(forbidden,h)

    def test_ranked_launch_is_widget_only(self):
        d,h,l=read("Core/DuelDetection.lua"),read("UI/DuelHUD.lua"),read("Core/CompetitiveLifecycle.lua")
        self.assertIn("widgetLaunch=nil",d)
        self.assertIn('c.rankedWidget==true and "R" or "P"',l)
        self.assertIn("RankedAvailability",h)
        self.assertIn('Action("Unranked"',h)
        self.assertIn('ns.OpponentDiscovery.Subscribe(Paint)',h)
        self.assertNotIn('Action("Practice"',h)

    def test_range_and_request_recovery(self):
        d,h=read("Core/DuelDetection.lua"),read("UI/DuelHUD.lua")
        self.assertIn('api.interactDistance,"target",3',d)
        self.assertIn('D.GetChallengeRange(expectedGuid)~=true',d)
        self.assertIn('ACK_WAIT=5',d)
        self.assertIn('request_not_confirmed',d)
        self.assertIn('requestConfirmed=true',d)
        self.assertIn('pcall(_G.StartDuel,"target",true)',d)
        self.assertIn('lastRange==true',h)
        self.assertIn('ns.DuelDetection.DismissUnconfirmed()',h)

    def test_footer_ornaments_do_not_cover_controls(self):
        import re
        h=read("UI/DuelHUD.lua")
        gem_y,gem_h=map(int,re.search(r'Artwork\("gem",WIDTH/2-\d+,(\d+),\d+,(\d+),',h).groups())
        for name in ("Challenge Target","Forfeit"):
            x,y,w,height=map(int,re.search(r'Action\("'+name+r'",(\d+),(\d+),(\d+),(\d+),',h).groups())
            self.assertLessEqual(y+height,gem_y)
            self.assertGreaterEqual(x,38)
            self.assertLessEqual(x+w,336-38)
        self.assertLessEqual(gem_y+gem_h,310)

    def test_header_corner_and_control_clearance(self):
        h=read("UI/DuelHUD.lua")
        self.assertIn('Artwork("topLeft",0,0,28,30,"ARTWORK")',h)
        self.assertIn('Artwork("topRight",WIDTH-28,0,28,30,"ARTWORK")',h)
        self.assertIn('Artwork("swords",30,4,28,28,"OVERLAY")',h)
        self.assertNotIn('Artwork("crest"',h)
        self.assertIn('Label("Duels Reimagined",16,C.pale,62,4,165,26',h)
        self.assertIn('gear=Action("",234,6,20,20',h)
        self.assertIn('Place(foldButton,258,6,20,20)',h)
        self.assertIn('close=Action("",282,6,20,20',h)
        self.assertLessEqual(62+165,234)
        self.assertLessEqual(282+20,336-28)
        self.assertIn('Artwork("statRow",18,202,300,24)',h)
        self.assertIn('Artwork("statRow",18,227,300,24)',h)
        self.assertGreaterEqual(18,11)
        self.assertLessEqual(18+300,336-11)
        self.assertIn('Action("Ranked",43,40,119,30',h)
        self.assertIn('Action("Unranked",174,40,119,30',h)

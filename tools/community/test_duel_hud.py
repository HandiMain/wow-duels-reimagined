from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (ROOT/p).read_text(encoding="utf-8")

class DuelHUDTests(unittest.TestCase):
    def test_approved_concept_art_and_bounded_regions(self):
        h=read("UI/DuelHUD.lua")
        self.assertIn("DuelHUDArt.png",h)
        self.assertIn('Artwork("shell",0,0,WIDTH,HEIGHT,"BACKGROUND")',h)
        self.assertIn("f:ClearAllPoints();f:SetPoint",h)
        self.assertNotIn("S.Fill(",h)
        self.assertNotIn("S.Skin(root",h)
        self.assertTrue((ROOT/"Media/Skin/DuelHUDArt.png").is_file())
        self.assertIn("DuelHUDPremium.png",h)
        self.assertIn('local foldedShell=Artwork("foldedShell",0,0,WIDTH,FOLDED_HEIGHT,"BACKGROUND")',h)
        self.assertIn("body:SetShown(not folded);foldedShell:SetShown(folded)",h)

    def test_rounded_health_assets_and_secret_safe_percentage(self):
        import hashlib, struct
        assets={
            "DuelHUDPremium.png": ((1024,1024),"6fd4670b4b21b1859dee9d54fa782a6e8b997dac"),
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

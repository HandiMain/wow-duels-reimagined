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

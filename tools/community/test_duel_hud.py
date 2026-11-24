from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (ROOT/p).read_text(encoding="utf-8")

class DuelHUDTests(unittest.TestCase):
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
                      'Native(StartDuel,"target")','Native(ForfeitDuel)',
                      'Plain(UnitGUID,unit)==id.guid','side.hp:SetMinMaxValues(0,max)',
                      'side.hp:SetValue(value)','SOLO PREVIEW - SIMULATED'):
            self.assertIn(token,h)
        for forbidden in ("ResetAllCombatSessions(","SendChatMessage(","CreateMacro(","EditMacro(",
                          "RecordLocalObservation(","CommitPeerNode(","Communication.Send("):
            self.assertNotIn(forbidden,h)

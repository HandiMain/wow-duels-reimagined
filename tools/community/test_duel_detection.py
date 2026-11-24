"""Duel detection single-owner and diagnostic integration contracts."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"

class DuelDetectionContracts(unittest.TestCase):
    def test_both_clients_and_shared_identity(self):
        toc=(ADDON/"DuelsReimagined.toc").read_text()
        self.assertEqual(toc.count("Core\\DuelDetection.lua"),1)
        self.assertLess(toc.index("Core\\Group.lua"),toc.index("Core\\DuelDetection.lua"))
        self.assertNotIn("AllowLoadGameType",next(l for l in toc.splitlines()
            if l.startswith("Core\\DuelDetection.lua")))
        self.assertIn("function Group.ReadPlayerIdentity(unit)",
            (ADDON/"Core/Group.lua").read_text())

    def test_passive_local_owner(self):
        s=(ADDON/"Core/DuelDetection.lua").read_text()
        for forbidden in ("COMBAT_LOG_EVENT_UNFILTERED","PLAYER_REGEN_DISABLED",
                          'SetScript("OnUpdate"',"NewTicker","SendAddonMessage",
                          "DuelsReimaginedDB","AcceptDuel(","CancelDuel(",
                          "ForfeitDuel(","StartDuel("):
            self.assertNotIn(forbidden,s)
        for required in ("DUEL_COUNTDOWN","DUEL_FINISHED","DUEL_WINNER_KNOCKOUT",
                         "DUEL_WINNER_RETREAT","pcall(issecretvalue,v)",
                         "ns.Group.ReadPlayerIdentity(unit)","rankEligible=false",
                         'scope="LOCAL"',"function D.GetSnapshot()",
                         "function D.Subscribe(fn)"):
            self.assertIn(required,s)

    def test_solo_sandbox_isolated_and_repeatable(self):
        e=(ADDON/"Core/DuelDetection.lua").read_text()
        s=(ADDON/"Core/DuelSelfTest.lua").read_text()
        toc=(ADDON/"DuelsReimagined.toc").read_text()
        self.assertLess(toc.index("Core\\DuelDetection.lua"),toc.index("Core\\DuelSelfTest.lua"))
        self.assertIn("local function BuildDetector(ns, api)",e)
        self.assertIn('scope="LOCAL", GetTime=GetTime',e)
        self.assertIn('scope="SIMULATED",GetTime=function() return clock end',e)
        self.assertIn("function live.NewSandbox",e)
        self.assertIn("before.revision==after.revision",s)
        self.assertIn('s.last.scope=="SIMULATED" and not s.last.rankEligible',s)
        for forbidden in ("_G.", "SendAddonMessage", "DuelsReimaginedDB",
                          "C_Timer.After", "AcceptDuel(", "StartDuel("):
            self.assertNotIn(forbidden,s)
        self.assertIn('message=="test verbose"',(ADDON/"Core/Commands.lua").read_text())

    def test_runtime_and_diagnostic_commands(self):
        test=(ROOT/"tools/community/check_runtime.lua").read_text()
        self.assertIn('dofile("tools/community/check_duel_detection_runtime.lua")',test)
        cmd=(ADDON/"Core/Commands.lua").read_text()
        self.assertIn('ns.DuelDetection.PrintStatus(message=="trace")',cmd)
        self.assertIn("ns.Window.Toggle()",cmd)

if __name__=="__main__":
    unittest.main()

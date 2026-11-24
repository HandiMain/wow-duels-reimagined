from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"
def read(path): return (ADDON/path).read_text()

class DiagnosticsContracts(unittest.TestCase):
    def test_entry_points_and_load_order(self):
        toc=read("DuelsReimagined.toc")
        self.assertLess(toc.index("Core\\DuelSelfTest.lua"),toc.index("Core\\Diagnostics.lua"))
        self.assertLess(toc.index("UI\\Header.lua"),toc.index("UI\\Diagnostics.lua"))
        self.assertLess(toc.index("UI\\Diagnostics.lua"),toc.index("UI\\BlizzardSettings.lua"))
        for path in ("UI/AddonStatus.lua","UI/BlizzardSettings.lua"):
            self.assertIn("ns.DiagnosticsUI.Open()",read(path))
        self.assertIn('Search.Register("diagnostics:open"',read("UI/Diagnostics.lua"))
    def test_no_live_action_or_storage_mutation_in_scanner(self):
        core=read("Core/Diagnostics.lua")
        for forbidden in ("StartDuel(", "AcceptDuel(", "ForfeitDuel(", "SendAddonMessage(",
                          "DuelsReimaginedDB", "seterrorhandler(", 'SetScript("OnUpdate"'):
            self.assertNotIn(forbidden,core)
        self.assertIn("ns.DuelSelfTest.Run",core)
        self.assertIn("Fingerprint()==before",core)
        self.assertIn('Static package / Lua syntax","SKIP"',core)
        self.assertIn('Live gameplay / multiplayer","SKIP"',core)
        self.assertIn('ns.Motion.GetRuntimeState()',core)
    def test_extended_audit_contracts(self):
        audit=read("Core/DiagnosticAudit.lua")
        core=read("Core/Diagnostics.lua")
        ui=read("UI/Diagnostics.lua")
        toc=read("DuelsReimagined.toc")
        self.assertLess(toc.index("Core\\Diagnostics.lua"),toc.index("Core\\DiagnosticAudit.lua"))
        for owner in ("DuelDetection","Group","Presence","Communication","WarGames"):
            self.assertIn("GetDiagnosticResources()",read("Core/"+owner+".lua"))
        for marker in ("C_AddOnProfiler.GetAddOnMetric","RecentAverageTime",
                       "GetAddOnMemoryUsage","CompareResources","CompareBaseline",
                       "RELEASE BLOCKED","geterrorhandler","state.previous"):
            self.assertIn(marker,audit)
        self.assertIn("C_Timer.NewTicker(5",ui)
        self.assertIn("ticker:Cancel()",ui)
        self.assertIn("SaveDiagnosticBaseline",ui)
        self.assertIn("Regression Intelligence / baseline",core)
        self.assertIn("Leak Sentinel / remaining resource coverage",core)
        self.assertNotIn("SetScript(\"OnUpdate\"",audit)
        self.assertIn("Learning receipt:",core)
        self.assertIn("function Settings.SaveDiagnosticBaseline",read("Core/Settings.lua"))

    def test_cost_and_capture_regressions(self):
        a=read("Core/DiagnosticAudit.lua")
        d=read("Core/Diagnostics.lua")
        u=read("UI/Diagnostics.lua")
        self.assertIn("bg.GetDB or bg.GetErrors",a)
        self.assertIn("ns.DiagnosticAudit.BugGrabberAPI()",d)
        self.assertIn("GetSessionId",d)
        self.assertIn("external_unknown",a)
        self.assertNotIn("UpdateAddOnMemoryUsage",a.split("function A.Performance()",1)[1])
        self.assertIn("now-prior.time<15",a)
        self.assertIn("coroutine.yield()",a)
        self.assertIn("GetNumRegions",a)
        self.assertIn("function D.RunAsync",d)
        self.assertIn("ns.Diagnostics.CancelPending()",u)
        self.assertIn('Tool("Sample Memory"',u)
        for page in ("Options","Community","AddonStatus","WarGames","PatchNotes"):
            self.assertIn("RegisterUIRoot",read("UI/"+page+".lua"))

    def test_player_first_diagnostics_disclosure(self):
        u=read("UI/Diagnostics.lua")
        self.assertIn('Button("Run Full Scan",20,78,220,"gold"',u)
        self.assertIn('Run("complete")',u)
        self.assertIn('local advanced=true',u)
        self.assertIn('SetTools(false)',u)
        self.assertIn('for _,b in ipairs(tools) do b:SetShown(open) end',u)
        self.assertIn('Footer("Copy Report"',u)
        self.assertIn('box:SetFocus();box:HighlightText()',u)
        self.assertIn('Press Ctrl+C',u)
        self.assertIn('closeFooter:SetScript("OnClick",function() frame:Hide() end)',u)
        for label in ("Quick Health","Summary","Performance","Error Capture","Save Baseline",
                      "Release Gate","Incident Log","Sample Memory","Save Report","Saved Reports",
                      "Latest","Clear Saved"):
            self.assertIn('Tool("'+label+'"',u)
        self.assertNotIn('Button("Run Complete Check"',u)
        self.assertNotIn('Button("Run Health Check"',u)

    def test_report_storage_owned_by_settings(self):
        self.assertIn("function Settings.SaveDiagnosticReport",read("Core/Settings.lua"))
        self.assertIn("ns.Settings.SaveDiagnosticReport",read("UI/Diagnostics.lua"))
        self.assertIn("while #list>3",read("Core/Settings.lua"))
        self.assertIn("98304",read("Core/Settings.lua"))
        self.assertIn('dofile("tools/community/check_diagnostics_runtime.lua")',
            (ROOT/"tools/community/check_runtime.lua").read_text())

if __name__=="__main__": unittest.main()

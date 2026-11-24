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
    def test_report_storage_owned_by_settings(self):
        self.assertIn("function Settings.SaveDiagnosticReport",read("Core/Settings.lua"))
        self.assertIn("ns.Settings.SaveDiagnosticReport",read("UI/Diagnostics.lua"))
        self.assertIn("while #list>3",read("Core/Settings.lua"))
        self.assertIn("98304",read("Core/Settings.lua"))
        self.assertIn('dofile("tools/community/check_diagnostics_runtime.lua")',
            (ROOT/"tools/community/check_runtime.lua").read_text())

if __name__=="__main__": unittest.main()

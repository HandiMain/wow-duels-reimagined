"""One client identity owner. Retail and Forever gameplay must be gated correctly."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"


class ClientCompatibilityTests(unittest.TestCase):
    def test_shared_detector_loads_before_other_modules(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        self.assertIn("## Interface: 120105, 16001", toc)
        self.assertIn("Core\\Client.lua", toc)
        self.assertEqual(toc.count("Core\\Client.lua"), 1)
        self.assertLess(toc.index("Core\\Client.lua"), toc.index("Core\\Settings.lua"))

    def test_retail_files_must_have_a_load_time_game_gate(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        for line in toc.splitlines():
            if "WarGames\\" in line or "WarGames/" in line:
                self.assertIn("[AllowLoadGameType standard]", line,
                              "Retail-only War Games source must not run on Forever")

    def test_one_api_source_and_fail_closed(self):
        source = (ADDON / "Core" / "Client.lua").read_text(encoding="utf-8")
        self.assertIn("local ok, _, _, _, interface = pcall(GetBuildInfo)", source)
        self.assertIn('return "unsupported"', source)
        self.assertIn('number >= 16000 and number < 20000', source)
        self.assertIn('number >= 120000 and number < 200000', source)
        self.assertIn("function Client.IsRetail()", source)
        self.assertIn("function Client.IsForever()", source)
        self.assertNotIn("WOW_PROJECT_ID", source.split("local function Detect()", 1)[1])
        self.assertNotIn("CreateFrame", source)
        self.assertNotIn("DuelsReimaginedDB", source)

    def test_cross_client_runtime_cases_exist(self):
        runtime = (ROOT / "tools" / "community" / "check_runtime.lua").read_text(encoding="utf-8")
        for case in ("ClientFor(120105)", 'ClientFor("120105")',
                     "ClientFor(16001)", "11507", "50500",
                     '"missing"', '"error"'):
            self.assertIn(case, runtime)


if __name__ == "__main__":
    unittest.main()

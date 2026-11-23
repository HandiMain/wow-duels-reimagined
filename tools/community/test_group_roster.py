"""Cross-client group roster structure and integration contracts."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"


class GroupRosterContracts(unittest.TestCase):
    def test_shared_load_order(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        self.assertEqual(toc.count("Core\\Group.lua"), 1)
        self.assertLess(toc.index("Core\\Client.lua"), toc.index("Core\\Group.lua"))
        self.assertLess(toc.index("Core\\Group.lua"), toc.index("UI\\Navigation.lua"))
        self.assertNotIn("AllowLoadGameType", [x for x in toc.splitlines()
                                               if x.startswith("Core\\Group.lua")][0])

    def test_no_extra_engine_or_communication(self):
        src = (ADDON / "Core" / "Group.lua").read_text(encoding="utf-8")
        for fn in ("GetSnapshot", "IsReady", "Subscribe", "Refresh"):
            self.assertIn("function Group." + fn, src)
        self.assertIn("ns.Group = Group", src)
        for forbidden in ('SetScript("OnUpdate"', "NewTicker", "C_Timer",
                          "SendAddonMessage", "CHAT_MSG_ADDON",
                          "DuelsReimaginedDB", "WarGames"):
            self.assertNotIn(forbidden, src)

    def test_group_events_and_secret_safety(self):
        src = (ADDON / "Core" / "Group.lua").read_text(encoding="utf-8")
        self.assertIn("pcall(issecretvalue, v)", src)
        self.assertIn("if current.mode == mode and current.complete", src)
        self.assertIn("pcall(fn, Copy(current))", src)
        for event in ("PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
                      "PARTY_LEADER_CHANGED", "UNIT_CONNECTION", "UNIT_NAME_UPDATE"):
            self.assertIn(event, src)
        workflow = (ROOT / ".github/workflows/community-credits.yml").read_text()
        self.assertIn("lua5.1 tools/community/check_group_runtime.lua", workflow)


if __name__ == "__main__":
    unittest.main()

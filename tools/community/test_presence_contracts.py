"""Addon presence follows the shared roster and never invents an install state."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"


class PresenceContracts(unittest.TestCase):
    def test_one_transport_and_a_group_consumer(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text()
        self.assertEqual(toc.count("Core\\Communication.lua"), 1)
        self.assertEqual(toc.count("Core\\Presence.lua"), 1)
        self.assertLess(toc.index("Core\\Group.lua"), toc.index("Core\\Communication.lua"))
        self.assertLess(toc.index("Core\\Communication.lua"), toc.index("Core\\Presence.lua"))
        self.assertLess(toc.index("Core\\Presence.lua"), toc.index("UI\\Navigation.lua"))
        self.assertNotIn("AllowLoadGameType", next(line for line in toc.splitlines()
            if line.startswith("Core\\Presence.lua")))

    def test_comms_exclusive_api_owner(self):
        all_files = list(ADDON.rglob("*.lua"))
        owners = [p for p in all_files if
            "C_ChatInfo.SendAddonMessage" in p.read_text() or
            "RegisterAddonMessagePrefix" in p.read_text()]
        self.assertEqual([x.name for x in owners], ["Communication.lua"])
        src = (ADDON / "Core/Communication.lua").read_text()
        self.assertIn("SendAddonMessageResult", src)
        self.assertIn("AddOnRestrictionType", src)
        self.assertIn("Readability" if False else "Readable", src)
        self.assertIn("pcall(fn, body, channel, sender)", src)

    def test_presence_group_only_and_never_marks_missing(self):
        src = (ADDON / "Core/Presence.lua").read_text()
        self.assertIn("Group.Subscribe(", src)
        self.assertIn("Group.GetSnapshot()", src)
        self.assertIn("function Presence.GetSnapshot()", src)
        self.assertIn("function Presence.CheckNow()", src)
        self.assertIn("function Presence.Subscribe(fn)", src)
        self.assertIn('return "unknown"', src)
        self.assertIn('return "confirmed"', src)
        for prohibited in ("DuelsReimaginedDB", "WarGames",
                           "RegisterAddonMessagePrefix", "CHAT_MSG_ADDON",
                           'SetScript("OnUpdate"'):
            self.assertNotIn(prohibited, src)
        self.assertNotIn('"missing"', src)

    def test_runtime_has_negative_and_multiparty_cases(self):
        src = (ROOT / "tools/community/check_presence_runtime.lua").read_text()
        for value in ("Stranger-Realm", "Beta-DifferentRealm",
                      "CHAT_MSG_ADDON", "raid", "locked = true",
                      "sendResult = 11", "issecretvalue"):
            self.assertIn(value, src)
        workflow = (ROOT / ".github/workflows/community-credits.yml").read_text()
        self.assertIn("lua5.1 tools/community/check_presence_runtime.lua", workflow)


if __name__ == "__main__":
    unittest.main()

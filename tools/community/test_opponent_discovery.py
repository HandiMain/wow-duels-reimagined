from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"
class OpponentDiscovery(unittest.TestCase):
    def test_ownership(self):
        toc=(ADDON/"DuelsReimagined.toc").read_text()
        self.assertEqual(toc.count("Core\\OpponentDiscovery.lua"),1)
        self.assertLess(toc.index("Core\\Communication.lua"),toc.index("Core\\OpponentDiscovery.lua"))
        p=(ADDON/"Core/OpponentDiscovery.lua").read_text()
        self.assertIn('ns.Communication.Send("D1",body,"WHISPER",target)',p)
        self.assertIn('q.peer.guid~=from',p)
        self.assertIn('q.peer.key~=key',p)
        self.assertIn('q.nonce~=nonce',p)
        self.assertIn('rankEligible=false',p)
        for x in ("DuelsReimaginedDB","AcceptDuel(","StartDuel(","SendChatMessage(","CHAT_MSG_ADDON"):
            self.assertNotIn(x,p)
        self.assertIn("RunSelfTest", (ADDON/"Core/Diagnostics.lua").read_text())
if __name__=="__main__": unittest.main()

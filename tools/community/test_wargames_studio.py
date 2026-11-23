"""War Games companion ownership, safety and layout regression contracts."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"

def read(name): return (ADDON/name).read_text(encoding="utf-8")

class MatchCommandTests(unittest.TestCase):
    def test_toc_order_and_client_gate(self):
        toc=read("DuelsReimagined.toc")
        for token in (
            "Core\\WarGamesSession.lua [AllowLoadGameType standard]",
            "UI\\WarGamesStudio.lua [AllowLoadGameType standard]",
        ):
            self.assertIn(token,toc)
        self.assertLess(toc.index("Core\\Settings.lua"),toc.index("Core\\WarGamesSession.lua"))
        self.assertLess(toc.index("Core\\WarGames.lua"),toc.index("Core\\WarGamesSession.lua"))
        self.assertLess(toc.index("UI\\WarGames.lua"),toc.index("UI\\WarGamesStudio.lua"))
        self.assertLess(toc.index("UI\\WarGamesStudio.lua"),toc.index("UI\\Navigation.lua"))

    def test_one_communication_and_request_owner(self):
        tools=read("Core/WarGamesSession.lua")
        studio=read("UI/WarGamesStudio.lua")
        core=read("Core/WarGames.lua")
        for text in ("StartWarGameByName","StartSpectatorWarGame",
                     "SendAddonMessage","CHAT_MSG_ADDON",
                     'SetScript("OnUpdate"','CreateTicker('):
            self.assertNotIn(text,tools+studio)
        self.assertIn("pcall(StartWarGameByName,",core)
        self.assertIn("pcall(StartSpectatorWarGame,",core)
        self.assertIn("requestState[page]=\"submitted\"",core)
        self.assertIn("requestState[page]=\"refused\"",core)
        self.assertIn("function WarGames.GetRequestState(page)",core)
        self.assertIn("if IsArena() then return \"in_arena\" end",core)

    def test_storage_owner_and_manual_proof(self):
        settings=read("Core/Settings.lua")
        tools=read("Core/WarGamesSession.lua")
        for token in ("function Settings.GetWarGamesLibrary()",
                      "function Settings.SaveWarGamesLibrary(data)",
                      "favoriteCaptains={}, recentCaptains={}",
                      "favoriteMaps={}, recentMaps={}, history={}",
                      'manual==true','math.min(#history,20)'):
            self.assertIn(token,settings)
        self.assertNotIn("_G.DuelsReimaginedDB",tools)
        for token in ('manual=true,format=series.bestOf',
                      'page=series.page',
                      'if record.page=="player" then',
                      'No automatic','Target realm identity is unavailable'):
            # Some wording appears only in comments/tooltips.
            if token!="No automatic": self.assertIn(token,tools)
        self.assertIn('type(friend.characterRealm)=="string"',tools)
        self.assertIn("pcall(UnitFullName,\"target\")",tools)
        self.assertIn("function Tools.Rivalries()",tools)
        self.assertIn("function Tools.GetVeto()",tools)
        self.assertIn("function Tools.DraftListing(page)",tools)

    def test_view_native_layout_and_search(self):
        ui=read("UI/WarGames.lua")
        studio=read("UI/WarGamesStudio.lua")
        widgets=read("UI/Widgets.lua")
        for token in ("function View.AttachStudio(panel)",
                      "function View.ScrollToStudio()",
                      "studio:Refresh()",
                      "Position(studio,0,y,w,342)",
                      "canvas:SetHeight(y+356)",
                      "SCROLLBAR_GUTTER = 25, 30, 22",
                      'FillRows(hostRows1,first,math.min(5,cfgHost.bracket),"Not observed")'):
            self.assertIn(token,ui)
        for token in ('{"quick","QUICK PLAY"}',
                      '{"series","SERIES"}',
                      '{"veto","MAP VETO"}',
                      '{"community","COMMUNITY"}',
                      'Tools.MarkRound(side)',
                      'Tools.DraftListing(currentPage)',
                      'Widgets.OpenChoices(anchor,entries,nil,callback,true)',
                      'View.ScrollToStudio()'):
            self.assertIn(token,studio)
        for token in ('function Widgets.OpenChoices(anchor, choices, selected, onChoose, searchable)',
                      'search:SetAutoFocus(false)',
                      'search:SetScript("OnEscapePressed"',
                      'search:SetScript("OnTextChanged"',
                      'hint:SetShown(filterText=="")',
                      'empty:SetShown(n==0)',
                      'searchEnabled and 36 or 0'):
            self.assertIn(token,widgets)
        # Four compact tabs and three tools per row remain inside the
        # 22-pixel scrollbar-safe canvas at the minimum supported width.
        for root_width in (760,800,900,1050):
            w=root_width-25-30-22
            usable=w-36
            tab_width=(usable-18)/4
            self.assertLessEqual(18+3*(tab_width+6)+tab_width,w-18+0.01)
            col=(usable-20)/3
            self.assertLessEqual(18+2*(col+10)+col,w-18+0.01)
        self.assertNotIn('SetScript("OnUpdate"',studio)

    def test_no_spectator_overlay_or_unverified_claims(self):
        docs=(ROOT/"docs/WAR_GAMES.md").read_text(encoding="utf-8")
        self.assertIn("Spectator Presentation Mode (#10)",docs)
        self.assertIn("no code in this pass",docs)
        self.assertIn("MULTIPLAYER VERIFIED",docs)
        self.assertIn("LOCAL",docs)
        self.assertIn("MANUAL",docs)
        self.assertIn("raw ZIP bytes were unavailable",docs)

if __name__=="__main__":
    unittest.main()

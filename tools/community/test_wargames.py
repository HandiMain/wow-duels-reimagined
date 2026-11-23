"""Retail War Games, 5v5, guarded requests, UI and asset integration."""
from pathlib import Path
import struct
import unittest
import zlib

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"
def src(p):return (ADDON/p).read_text(encoding="utf-8")

class WarGamesTests(unittest.TestCase):
    def test_retail_only_and_forever_tooltip(self):
        toc=src("DuelsReimagined.toc")
        self.assertIn("Core\\WarGames.lua [AllowLoadGameType standard]",toc)
        self.assertIn("UI\\WarGames.lua [AllowLoadGameType standard]",toc)
        self.assertLess(toc.index("Core\\Group.lua"),toc.index("Core\\WarGames.lua"))
        self.assertLess(toc.index("UI\\WarGames.lua"),toc.index("UI\\Navigation.lua"))
        nav=src("UI/Navigation.lua")
        self.assertIn('primaryKeys = { hall = true, wargames = true }',nav)
        self.assertIn('button:SetEnabled(false)',nav)
        self.assertIn('help:EnableMouse(true)',nav)
        self.assertIn("War Games — Retail only",nav)
        self.assertIn('if section.key == "wargames" and not ns.Client.IsRetail() then return end',nav)

    def test_players_host_and_arena_paths(self):
        core=src("Core/WarGames.lua");ui=src("UI/WarGames.lua")
        self.assertIn("for index = 1, 5 do",core)
        self.assertIn("Two(UnitName, unit)",core)
        self.assertIn("Group.GetSnapshot()",core)
        self.assertIn("function WarGames.InArena()",core)
        self.assertIn("StartWarGameByName",core)
        self.assertIn("StartSpectatorWarGame",core)
        self.assertIn("FriendByID",core)
        self.assertIn('local inArena=Engine.InArena()',ui)
        self.assertIn('playerSetup:SetShown(active=="player" and not inArena)',ui)
        self.assertIn('enemyTeam:SetShown(active=="player" and inArena)',ui)
        self.assertIn('hostForm:SetShown(active=="host" and not inArena)',ui)
        self.assertIn("FillRows(enemyRows,Engine.GetOpponents()",ui)
        self.assertIn("Roster(hostTeam1,5)",ui)
        self.assertIn("Roster(hostTeam2,5)",ui)
        self.assertIn('Engine.Request("player")',ui)
        self.assertIn('Engine.Request("host")',ui)
        self.assertIn("unsubscribe=Engine.Subscribe(View.Refresh)",ui)
        for forbidden in ("WarGamesDB","C_ChatInfo.SendAddonMessage",
                          "CHAT_MSG_ADDON","GetNumGroupMembers(",
                          'SetScript("OnUpdate"',"/roll","Horde","Alliance"):
            self.assertNotIn(forbidden,core+ui)

    def test_navigation_theme_search_and_scroll(self):
        nav=src("UI/Navigation.lua");w=src("UI/Window.lua")
        self.assertIn('if page.warGames then return ns.WarGamesUI end',nav)
        self.assertIn('local isWarGames = page.warGames == true',w)
        self.assertIn('ns.WarGamesUI.Show(isWarGames and page.key or nil)',w)
        self.assertIn("ns.WarGamesUI.Refresh()",src("UI/Theme.lua"))
        ui=src("UI/WarGames.lua")
        self.assertIn('ns.Search.Register("wargames:challenge"',ui)
        self.assertIn('ns.Search.Register("wargames:spectate"',ui)
        self.assertIn("function View.GetPageScroll()",ui)
        self.assertIn("function View.SetPageScroll(",ui)

    def test_png_integrity_and_path(self):
        p=ADDON/"Media/Artwork/WarGamesPlaque.png"
        raw=p.read_bytes()
        self.assertEqual(raw[:8],b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II",raw[16:24]),(128,64))
        pos=8;types=[]
        while pos<len(raw):
            n=struct.unpack(">I",raw[pos:pos+4])[0];pos+=4
            name=raw[pos:pos+4];pos+=4
            payload=raw[pos:pos+n];pos+=n
            crc=struct.unpack(">I",raw[pos:pos+4])[0];pos+=4
            self.assertEqual(zlib.crc32(name+payload)&0xffffffff,crc)
            types.append(name)
            if name==b"IEND":break
        self.assertEqual(pos,len(raw))
        self.assertIn(b"IDAT",types)
        self.assertIn("WarGamesPlaque.png",src("UI/Navigation.lua"))

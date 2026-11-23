"""Retail War Games, 5v5, guarded requests, UI and asset integration."""
from pathlib import Path
import unittest

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
        self.assertIn('if id == nil then return nil end',core)
        self.assertIn('elseif page == "host" and slot == 2 then',core)
        self.assertIn('type(online) ~= "boolean"',core)
        self.assertIn('GetNumWarGameTypes',core)
        self.assertIn('GetWarGameTypeInfo',core)
        self.assertIn('function WarGames.GetMaps()',core)
        self.assertIn('name = "Cage of Carnage"',core)
        self.assertIn('name = "The Robodrome"',core)
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
        self.assertIn("Widgets.ChoiceControl(playerForm,235)",ui)
        self.assertIn("Widgets.ChoiceControl(hostForm,209)",ui)
        self.assertIn("Widgets.OpenChoices(",ui)
        self.assertIn("Engine.GetMaps()",ui)
        self.assertIn('if captainID==0 then captainID=nil end',ui)
        self.assertNotIn('menuPrev',ui)
        self.assertNotIn('menuNext',ui)
        widgets=src("UI/Widgets.lua")
        self.assertIn("function Widgets.ChoiceControl(parent, width)",widgets)
        self.assertIn("function Widgets.OpenChoices(anchor, choices, selected, onChoose)",widgets)
        self.assertIn("scrollbar=Widgets.ScrollBar(popup",widgets)
        self.assertIn('choiceCounter = choiceCounter + 1',widgets)
        self.assertIn('row.dot:SetShown(type(status) == "boolean")',widgets)
        self.assertIn('ChoiceCatcher():Show()',widgets)

    def test_same_sized_primary_skin_reuses_existing_art(self):
        nav=src("UI/Navigation.lua")
        self.assertIn("HALL_BUTTON_WIDTH = 205",nav)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)',nav)
        self.assertIn('Style.PlateImage(button, "hall", "ARTWORK", 2)',nav)
        self.assertIn('DuelWarGamesPlate.png',nav)
        self.assertIn('button.hallGlow = glow',nav)
        self.assertNotIn('Style.Plate(button, "hall", { corner=14',nav)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)',nav)
        self.assertIn('if section.key == "hall" or section.key == "wargames" then',nav)
        self.assertIn('icon:Hide()',nav)
        self.assertIn('label:Hide()',nav)
        self.assertNotIn('label:SetTextColor(unpack(C.pale))',nav)
        self.assertNotIn('jewel:SetPoint("CENTER", icon',nav)
        self.assertIn('if section.key == "hall" then',nav)
        self.assertIn('elseif section.key == "wargames" then',nav)
        self.assertNotIn("WarGamesPlaque.png",nav)
        self.assertFalse((ADDON/"Media/Artwork/WarGamesPlaque.png").exists())
        self.assertTrue((ADDON/"Media/Skin/DuelWarGamesPlate.png").is_file())

    def test_no_overlapping_cards_and_no_duplicate_divider(self):
        ui=src("UI/WarGames.lua")
        # An orphan panel previously painted over YOUR TEAM even in the lobby.
        self.assertNotIn('playerArena = Panel(',ui)
        self.assertNotIn('local retail = Style.Text(',ui)
        self.assertNotIn('local rule = Chrome.Divider(root',ui)
        self.assertIn('local symbol = Chrome.Icon(root, "Hall")',ui)
        self.assertIn('hostStatus:SetShown(active=="host" and inArena)',ui)
        self.assertIn('playerSetup:SetShown(active=="player" and not inArena)',ui)
        self.assertIn('playerForm:SetShown(active=="player" and not inArena)',ui)
        self.assertIn('hostForm:SetShown(active=="host" and not inArena)',ui)
        self.assertIn('for i,button in ipairs(hostBrackets) do',ui)
        self.assertIn('At(hostMap,x[2],85,col)',ui)
        self.assertIn('At(hostCaptain1,x[3],85,col)',ui)
        self.assertIn('At(hostCaptain2,x[4],85,col)',ui)
        self.assertIn('local col=(w-36-3*gap)/4',ui)
        self.assertIn('scroll:SetScript("OnSizeChanged"',ui)
        # Test the exact geometry used at the supported minimum and larger
        # widths. Each visible card occupies its own vertical interval.
        for width in (760,800,900,1050):
            gap=12
            col=(width-36-3*gap)/4
            x=[18+n*(col+gap) for n in range(4)]
            self.assertGreaterEqual(col,160)
            self.assertLessEqual(x[-1]+col,width-18+0.01)
            self.assertLess(236,253)
            self.assertLess(252,268)
            self.assertLess(258,274)
            self.assertLess(253+258,524)
            self.assertLess(268+63+39*5,280+63+39*5)


    def test_derived_hall_artwork_matches_original(self):
        import subprocess
        import sys
        result = subprocess.run(
            [sys.executable, str(ROOT/"tools/community/generate_wargames_plate.py"), "--check"],
            cwd=ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("finished plaque matches approved Hall art: PASS", result.stdout)
        generator=src("../../tools/community/generate_wargames_plate.py")
        self.assertIn("display_width, display_height = 112, 24",generator)

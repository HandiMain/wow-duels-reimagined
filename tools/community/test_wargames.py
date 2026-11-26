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
        self.assertIn('primaryKeys = { hall = true, leaderboard = true, matchhistory = true, achievements = true, tournaments = true, wargames = true }',nav)
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
        self.assertIn('ns.WarGamesArenaPicker.CreatePreview(playerForm,"player")',ui)
        self.assertIn('ns.WarGamesArenaPicker.CreatePreview(hostForm,"host")',ui)
        self.assertIn("Widgets.OpenChoices(",ui)
        self.assertIn("Engine.GetMaps()",ui)
        self.assertIn('if captainID==0 then captainID=nil end',ui)
        self.assertNotIn('menuPrev',ui)
        self.assertNotIn('menuNext',ui)
        widgets=src("UI/Widgets.lua")
        self.assertIn("function Widgets.ChoiceControl(parent, width, opts)",widgets)
        self.assertIn("function Widgets.OpenChoices(anchor, choices, selected, onChoose, owner)",widgets)
        self.assertIn("scrollbar=Widgets.ScrollBar(popup",widgets)
        self.assertIn('choiceCounter = choiceCounter + 1',widgets)
        self.assertIn('row.dot:SetShown(type(status) == "boolean")',widgets)
        self.assertIn('ChoiceCatcher(host):Show()',widgets)

    def test_tournament_rules_remain_independent_and_match_local(self):
        core=src("Core/WarGames.lua")
        ui=src("UI/WarGames.lua")
        runtime=(ROOT/"tools/community/check_wargames_runtime.lua").read_text(encoding="utf-8")
        for token in ("tournamentRules = false",
                      "function WarGames.SelectTournamentRules(page, enabled)",
                      'type(enabled) ~= "boolean"',
                      "tournamentRules=s.tournamentRules",
                      'local rules = s.tournamentRules and "1" or "0"',
                      'map.name, s.tournamentRules == true'):
            self.assertIn(token,core)
        for token in ('local playerTournament=TournamentToggle(playerForm,"player")',
                      'local hostTournament=TournamentToggle(hostForm,"host")',
                      'Widgets.ToggleRow(parent,"Tournament Rules"',
                      'toggle:LayoutForWidth(toggleWidth,true)',
                      'PlaceMatchControls(playerForm,playerTournament,playerSend,w,229)',
                      'PlaceMatchControls(hostForm,hostTournament,hostSend,w,180)',
                      'playerTournament:SetChecked(cfgPlayer.tournamentRules)',
                      'hostTournament:SetChecked(cfgHost.tournamentRules)',
                      'ns.Search.Register("wargames:tournament:player"',
                      'ns.Search.Register("wargames:tournament:host"'):
            self.assertIn(token,ui)
        self.assertNotIn('Settings.Set("tournamentRules"',ui)
        self.assertNotIn('SetScript("OnUpdate"',core+ui)
        self.assertIn('sends[2]=="OneAccount nagrand 1"',runtime)
        self.assertIn('spectates[2][5]==true',runtime)
        self.assertIn('Position(playerForm,0,0,w,301)',ui)
        self.assertIn('Position(hostForm,0,0,w,277)',ui)
        for width in (683,720,820,1000):
            for action in (180,260):
                toggle=max(160,min(290,width-36-action-18))
                self.assertLessEqual(18+toggle+18,width-18-action)

    def test_request_lifecycle_readiness_and_gated_captain_exchange(self):
        core=src("Core/WarGames.lua");ui=src("UI/WarGames.lua")
        for token in ('REQUEST_WAIT=90','pending={page=page,deadline=now+REQUEST_WAIT}',
                      'function WarGames.GetMatchStatus()', 'One(IsWargame)',
                      'function WarGames.GetReadiness(team)', 'C_PartyInfo.DoReadyCheck',
                      'function WarGames.InvalidateFriends()', 'PEER_TEST_ENABLED=false',
                      'ns.Communication.Subscribe("W1",ReceivePeer)', 'Key(sender)~=Key(c.route)'):
            self.assertIn(token,core)
        for token in ('Engine.GetReadiness(team)', 'Engine.ReadyCheck()', 'Engine.GetMatchStatus()',
                      'Engine.PeerTestingEnabled()', 'Engine.GetMessage("player")'):
            self.assertIn(token,ui)
        self.assertIn('ns.WarGames.CanCommunicate()',src("Core/Communication.lua"))
        self.assertIn('warGamesConsent = false',src("Core/Settings.lua"))
        self.assertIn('warGamesConsent',src("UI/Options.lua"))
        self.assertNotIn('local messages = {}',ui)
        self.assertNotIn('CompetitiveStorage',core)

    def test_same_sized_primary_skin_reuses_existing_art(self):
        nav=src("UI/Navigation.lua")
        self.assertIn("HALL_BUTTON_WIDTH, HALL_BUTTON_HEIGHT = 166, 68",nav)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, HALL_BUTTON_HEIGHT)',nav)
        self.assertIn('Style.PlateImage(button, "hall", "ARTWORK", 2)',nav)
        self.assertIn('DuelWarGamesPlate.png',nav)
        self.assertIn('button.hallGlow = glow',nav)
        self.assertNotIn('Style.Plate(button, "hall", { corner=14',nav)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)',nav)
        self.assertIn('if isPrimary then',nav)
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
        self.assertIn('local SCROLL_LEFT, SCROLL_RIGHT, SCROLLBAR_GUTTER = 25, 30, 22',ui)
        self.assertIn('local w=UsableCanvasWidth()',ui)
        self.assertIn('canvas:SetWidth(w+SCROLLBAR_GUTTER)',ui)
        self.assertIn('vs:SetPoint("CENTER",canvas,"TOPLEFT",w/2,-145)',ui)
        self.assertIn('vs:SetPoint("CENTER",canvas,"TOPLEFT",w/2,-440)',ui)
        self.assertNotIn('canvas:SetWidth(w)\n',ui)
        self.assertEqual(ui.count('vs:SetPoint("CENTER",canvas,"TOPLEFT",w/2,-145)'),2)
        self.assertIn('root:HookScript("OnSizeChanged"',ui)
        self.assertIn('C_Timer.After(0,function()',ui)
        self.assertNotIn('scroll:GetWidth()-5',ui)
        # Validate scrollbar gutter and the exact card geometry before any
        # resize event, including default and minimum window configurations.
        for root_width in (760,800,900,1050):
            width=root_width-25-30-22
            scroll_width=root_width-25-30
            self.assertGreaterEqual(scroll_width-width,22)
            # Bar starts 14 px from the viewport's right edge. Panel border
            # must end at least 8 px before the bar's left edge.
            self.assertLessEqual(width,scroll_width-22)
            first_half=(width-72)/2
            right_start=width-first_half
            self.assertAlmostEqual(right_start+first_half,width)
            self.assertGreaterEqual(width-right_start-first_half,0)
            gap=12
            col=(width-36-3*gap)/4
            x=[18+n*(col+gap) for n in range(4)]
            self.assertGreaterEqual(col,150)
            self.assertLessEqual(x[-1]+col,width-18+0.01)
            self.assertLess(277,294)
            self.assertLess(301,317)
            self.assertLess(258,274)
            self.assertLess(294+258,565)
            self.assertLess(317+63+39*5,329+63+39*5)


    def test_approved_coliseum_artwork_is_current(self):
        import hashlib
        import struct
        import subprocess
        import sys
        result = subprocess.run(
            [sys.executable, str(ROOT/"tools/community/generate_wargames_plate.py"), "--check"],
            cwd=ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Coliseum War Games plaque matches approved artwork: PASS", result.stdout)
        source = ROOT/"tools/community/artwork/WarGamesColiseumPlate.png"
        plate = ADDON/"Media/Skin/DuelWarGamesPlate.png"
        self.assertTrue(source.is_file())
        self.assertEqual(source.read_bytes(), plate.read_bytes())
        data = plate.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack_from(">IIBB", data, 16), (256, 128, 8, 6))
        self.assertEqual(
            hashlib.sha256(data).hexdigest(),
            "79c3d68a4040f5b8cb169ebd3d41b71826b1b8e136e630118bf079c15b1bb2c2")
        self.assertFalse((ROOT/"tools/community/artwork/WarGamesArenaCrest.png").exists())
        generator = src("../../tools/community/generate_wargames_plate.py")
        self.assertIn("WarGamesColiseumPlate.png", generator)
        self.assertNotIn("WarGamesArenaCrest.png", generator)

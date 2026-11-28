from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"
def read(path):return (ADDON/path).read_text(encoding="utf-8")
class CompetitiveUI(unittest.TestCase):
    def test_approved_sidebar_order_and_single_paint_owner(self):
        n=read("UI/Navigation.lua")
        self.assertLess(n.index('key = "hall"'),n.index('key = "leaderboard"'))
        self.assertLess(n.index('key = "leaderboard"'),n.index('key = "matchhistory"'))
        self.assertLess(n.index('key = "matchhistory"'),n.index('key = "achievements"'))
        self.assertLess(n.index('key = "achievements"'),n.index('key = "wargames"'))
        self.assertIn('if item.key=="wargames" then',n)
        self.assertIn('top=top+21',n)
        self.assertIn('Style.MenuButton(button, section.key, section.label, {primary=isPrimary})',n)
        self.assertNotIn('{ key = "profile", label = "Player Profile"',n)
        self.assertNotIn('CompetitiveUI.Plaque',n)
        self.assertNotIn('DuelWarGamesPlate.png',n)
        self.assertNotIn('label:Hide()',n)
        self.assertIn('wargames={263,67,114,47}',read("UI/Style.lua"))
        self.assertIn('backButton:SetShown(can or (page and (page.competitive or page.achievements or page.tournament)) or false)',n)
        self.assertIn('backButton:SetEnabled(can)',n)
        self.assertIn('page and (page.achievements or (page.competitive and page.key~="overview")) then Select(1,1,false,false,true)',n)
        self.assertTrue((ADDON/"Media/Skin/DuelCompetitiveAtlas.png").is_file())
    def test_competitive_symbols_do_not_depend_on_unsupported_font_glyphs(self):
        ui=read("UI/CompetitiveUI.lua")
        self.assertNotIn("⌕",ui)
        self.assertNotIn("→",ui)
        self.assertIn('Media\\\\Artwork\\\\Header\\\\Search.png',ui)
        self.assertTrue((ADDON/"Media/Artwork/Header/Search.png").is_file())
        self.assertIn('Number(item.before).." to "..Number(item.after)',ui)
        self.assertIn('local boardSearch=Search(board,',ui)
        self.assertIn('local historySearch=Search(history,',ui)

    def test_local_view_remains_isolated_from_preview(self):
        ui=read("UI/CompetitiveUI.lua")
        p=read("UI/CompetitivePreview.lua")
        storage=read("Core/CompetitiveStorage.lua")
        history=read("Core/PersonalHistory.lua")
        self.assertIn('LOCAL_RECORDING_ENABLED=false',storage)
        self.assertIn('function P.OpenLocal(',history)
        self.assertIn('function D.ReadLocalHistory()',storage)
        self.assertIn('function P.Local()',p)
        self.assertIn('storage.ReadLocalHistory()',p)
        self.assertIn('preview.scope~=wanted',ui)
        self.assertNotIn('competitivePreview',read("Core/Settings.lua"))
        self.assertNotIn('competitivePreview',read("UI/Options.lua"))
        self.assertIn('ns.CompetitivePreview.IsActive()',ui)
        self.assertIn('function P.Command(command)',p)
        self.assertIn('local TEST_ENABLED=true',p)
        self.assertIn('session,cached=nil,nil',p)
        self.assertIn('SOLO TEST - SIMULATED',ui)
        self.assertIn('Placement Matches',ui)
        self.assertIn('rules.PLACEMENT_CREDIT',ui)
        self.assertIn('rules.MIN_RIVALS',ui)
        self.assertNotIn('Voidreign',p)
        self.assertNotIn('function U.LowerRim(parent)',ui)
        self.assertIn('Style.MenuButton(button, section.key, section.label, {primary=isPrimary})',read("UI/Navigation.lua"))

    def test_duel_mode_isolated_and_explained(self):
        ui=read("UI/CompetitiveUI.lua")
        for label in ("Rating capped","MatchExplanation","Awaiting the other player's matching result"):
            self.assertIn(label,ui)
        self.assertIn('practiceDuels = false',read("Core/Settings.lua"))
        self.assertNotIn('practiceDuels',read("UI/Options.lua"))
        self.assertIn('practice_cannot_rank',read("Core/PersonalHistory.lua"))
        self.assertIn('r.duelMode=="practice"',read("Core/ResultConfirmation.lua"))
        self.assertIn('IsResultPending(row.matchID)',read("UI/CompetitivePreview.lua"))

    def test_approved_placement_plate_and_shared_animation(self):
        ui=read("UI/CompetitiveUI.lua")
        for token in ("DuelPlacementPanel.png","DuelPlacementEffects.png",
                      "Placement(d,p,d.current,true)","Unique opponents: ",
                      "M.Value(placementPanel,0,1,.78","StopPlacementEffects()",
                      "hall:HookScript(\"OnHide\"","progress.total/5",
                      "1-fraction,1","p.rank.provisional"):
            self.assertIn(token,ui)
        self.assertNotIn("local placementBars={}",ui)
        for name,dimensions in (("DuelPlacementPanel.png",(512,256)),("DuelPlacementEffects.png",(128,64))):
            import struct
            data=(ADDON/"Media/Skin"/name).read_bytes()
            self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II",data[16:24]),dimensions)
        self.assertNotIn('SetScript("OnUpdate"',ui)

    def test_gated_production_paths_and_peer_evidence_scope(self):
        store=read("Core/CompetitiveStorage.lua")
        life=read("Core/CompetitiveLifecycle.lua")
        results=read("Core/ResultConfirmation.lua")
        transport=read("Core/Communication.lua")
        provider=read("UI/CompetitivePreview.lua")
        for token in ("LOCAL_RECORDING_ENABLED=false","PEER_TEST_ENABLED=false","PEER_EPOCH=nil",
                      "function D.OpenPeerNode()","function D.CommitPeerNode(node)","stale_or_incomplete_evidence",
                      "OpenCompactPeer","function D.ReadLocalCapacity()"):
            self.assertIn(token,store)
        for token in ("function P.Initialize()","Store.LocalRecordingEnabled()",
                      "Store.RecordLocalObservation(id,r,body and candidate or nil)",
                      "NewCatchupPeer","NormalizeSender","competitiveConsent"):
            self.assertIn(token,life)
        self.assertIn('scope=="PEER" and "2" or VERSION',results)
        self.assertIn('fields[#fields+1]=tostring(r.observedAt)',results)
        self.assertIn('ns.CompetitiveLifecycle.CanCommunicate()',transport)
        self.assertIn('storage.ReadPeerView(asOf)',provider)
        self.assertIn('own==row.statement',provider)

    def test_live_widgets_and_isolated_data(self):
        ui=read("UI/CompetitiveUI.lua");p=read("UI/CompetitivePreview.lua")
        for key in ("overview","standings","profile","history"):
            self.assertIn('Page("'+key+'"',ui)
        for token in ("SOLO TEST - SIMULATED","W.ScrollBar","W.ChoiceControl","W.OpenChoices","W.PressFeedback",
                      "OnEscapePressed","OnEnterPressed","RegisterUIRoot","ProfileSummary","view.Progression","view.Leaderboard"):
            self.assertIn(token,ui)
        for token in ("NewSimulated","OpenSeasonSimulated","OpenCompetitiveView","preview is read-only"):
            self.assertIn(token,p)
        for source in (ui,p):
            for token in ("SendAddonMessage(","AcceptDuel(","StartDuel(","_G.DuelsReimaginedCompetitiveDB","SetScript(\"OnUpdate\""):
                self.assertNotIn(token,source)
        toc=read("DuelsReimagined.toc")
        self.assertLess(toc.index("UI\\CompetitivePreview.lua"),toc.index("UI\\CompetitiveUI.lua"))
        self.assertLess(toc.index("UI\\CompetitiveUI.lua"),toc.index("UI\\Navigation.lua"))
    def test_floating_profile_reuses_native_controls(self):
        ui=read("UI/CompetitiveUI.lua")
        widgets=read("UI/Widgets.lua")
        for token in ('CreateFrame("Frame","DuelsReimaginedPlayerCard",UIParent)',
                      'card:SetMovable(true)', 'card:SetClampedToScreen(true)',
                      'card:StartMoving()', 'card:StopMovingOrSizing()',
                      'ns.Header.CreateCloseButton(card)', 'U.OpenPlayerCard=OpenProfile',
                      'RemoveSpecial("DuelsReimaginedWindow")',
                      'ns.Window.frame:HookScript("OnHide",function()card:Hide()end)',
                      'profileSeason=v;profile.Render()end,card)'):
            self.assertIn(token,ui)
        self.assertNotIn('ns.Navigation.SelectKey("leaderboard","profile")',ui)
        self.assertIn('popup:SetParent(host)',widgets)
        self.assertIn('ChoiceCatcher(host):Show()',widgets)
        self.assertIn('local parent=owner or ns.Window.frame',widgets)
    def test_sidebar_compact_geometry(self):
        for h in (400,510,636,850):
            for count in (5,6,7):
                compact=h<590
                top=16 if compact else 24
                gap=8 if compact else 10
                height=max(1,min(68,(h-top-21-12-(count-1)*gap)/count))
                end_of_duel_buttons=top+(count-1)*height+(count-2)*gap
                divider_top=end_of_duel_buttons+3
                war_top=end_of_duel_buttons+gap+21
                self.assertLessEqual(divider_top+14,war_top)
                self.assertLessEqual(war_top+height,h-12+1e-8)
                if h>=636:
                    self.assertEqual(height,68) # two future slots at full intended size

if __name__=="__main__":unittest.main()

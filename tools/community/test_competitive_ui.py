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
        self.assertLess(n.index('key = "matchhistory"'),n.index('key = "wargames"'))
        self.assertIn('if item.key=="wargames" then',n)
        self.assertIn('top=top+21',n)
        self.assertIn('ns.CompetitiveUI.Plaque(button,section.key,"ARTWORK",2)',n)
        self.assertNotIn('{ key = "profile", label = "Player Profile"',n)
        war=n.split('elseif section.key == "wargames" then',1)[1].split('\n    else',1)[0]
        self.assertIn('DuelWarGamesPlate.png',war)
        self.assertIn('artwork:SetAllPoints(button)',war)
        self.assertIn('glow:SetTexture(path)',war)
        self.assertIn('ns.CompetitiveUI.LowerRim(button)',war)
        self.assertNotIn('CompetitiveUI.Plaque',war)
        self.assertNotIn('artwork:SetPoint(',war)
        self.assertIn('backButton:SetShown(can or (page and page.competitive) or false)',n)
        self.assertIn('backButton:SetEnabled(can)',n)
        self.assertIn('page and page.competitive and page.key~="overview" then Select(1,1,false,false,true)',n)
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
        self.assertIn('function U.LowerRim(parent)',ui)

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
            compact=h<590
            top=20 if compact else 31
            height=max(48,min(76,(h-95)/4)) if compact else 84
            gap=10 if compact else 15
            end_of_history=top+3*height+2*gap
            divider_top=end_of_history+3
            war_top=end_of_history+gap+21
            self.assertLessEqual(divider_top+14,war_top)
            self.assertLessEqual(war_top+height,h)
if __name__=="__main__":unittest.main()

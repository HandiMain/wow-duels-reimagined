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
        self.assertIn('ns.CompetitiveUI.Plaque(button,"rim","ARTWORK",3)',n)
        self.assertIn('backButton:SetShown(can or (page and page.competitive) or false)',n)
        self.assertIn('backButton:SetEnabled(can)',n)
        self.assertIn('page and page.competitive and page.key~="overview" then Select(1,1,false,false,true)',n)
        self.assertTrue((ADDON/"Media/Skin/DuelCompetitiveAtlas.png").is_file())
    def test_live_widgets_and_isolated_data(self):
        ui=read("UI/CompetitiveUI.lua");p=read("UI/CompetitivePreview.lua")
        for key in ("overview","standings","profile","history"):
            self.assertIn('Page("'+key+'"',ui)
        for token in ("Preview • Simulated data","W.ScrollBar","W.ChoiceControl","W.OpenChoices","W.PressFeedback",
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

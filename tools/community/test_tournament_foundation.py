"""Stage-one interface boundaries and navigation regression."""
import unittest
from pathlib import Path
A=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (A/p).read_text(encoding="utf-8")
class TournamentFoundation(unittest.TestCase):
    def test_load_order(self):
        t=read("DuelsReimagined.toc")
        for before,after in [(r"Core\TournamentState.lua",r"UI\TournamentUI.lua"),(r"UI\TournamentUI.lua",r"UI\Navigation.lua"),(r"Core\Diagnostics.lua",r"Core\TournamentState.lua")]:
            self.assertLess(t.index(before),t.index(after))
    def test_shared_navigation(self):
        n=read("UI/Navigation.lua")
        self.assertLess(n.index('{ key = "tournaments"'),n.index('{ key = "wargames"'))
        self.assertIn('PageAvailable(sections[i],sections[i].pages[j])',n)
        self.assertIn('if not PageAvailable(section,page) then return false end',n)
        self.assertIn('function() return PageAvailable(section,page) end',n)
        self.assertIn('ns.TournamentUI.Show(isTournament and page.key or nil)',read("UI/Window.lua"))
    def test_no_gameplay_or_fake_data(self):
        for p in ("Core/TournamentState.lua","UI/TournamentUI.lua"):
            s=read(p)
            for forbidden in ("SendAddonMessage","C_ChatInfo","C_Timer","OnUpdate","AcceptDuel(","StartDuel("):
                self.assertNotIn(forbidden,s)
        self.assertIn('discovery=false,hosting=false',read("Core/TournamentState.lua"))
        self.assertIn('No tournaments discovered.',read("UI/TournamentUI.lua"))
    def test_tournament_plaque_has_single_art_owner(self):
        n=read("UI/Navigation.lua")
        plaque=n.split('elseif section.key == "tournaments" then',1)[1].split('elseif section.key == "wargames" then',1)[0]
        self.assertIn("DuelTournamentPlate.png",plaque)
        self.assertIn('artwork:SetAllPoints(button)',plaque)
        self.assertIn('glow:SetAllPoints(button)',plaque)
        self.assertNotIn('Style.Plate(button',plaque)
        self.assertNotIn('PaintEmblem',plaque)
        self.assertTrue((A/"Media/Skin/DuelTournamentPlate.png").is_file())
        self.assertNotIn('FitEmblem',n)
    def test_storage_lifecycle_expected_count(self):
        d=read("Core/Diagnostics.lua")
        check=d.split('Check("Competitive storage / isolated lifecycle QA"',1)[1].split('Check("Competitive storage / isolated record roundtrip QA"',1)[0]
        self.assertIn('f==0 and p==22',check)
    def test_creation_stays_local(self):
        c=read("Core/TournamentState.lua")
        u=read("UI/TournamentUI.lua")
        self.assertIn("function T.ValidateDraft",c)
        self.assertIn("function T.SaveDraft",c)
        self.assertIn('state="draft"',c)
        self.assertIn("discovery=false,hosting=false",c)
        self.assertIn("T.SaveDraft(form,displayedKey)",u)
        self.assertIn("Population.GetCurrent()",u)
        self.assertIn("LayoutCommunity(w)",u)
        self.assertIn("ns.CompetitiveScope",c)
        self.assertNotIn("GetCurrentRegion",c)
        self.assertNotIn("UnitFactionGroup",c)
        self.assertIn("Core\\CompetitiveScope.lua",read("DuelsReimagined.toc"))
        self.assertIn("W.ChoiceControl",u)
        self.assertIn("W.OpenChoices",u)
        self.assertIn("SetAutoFocus(false)",u)
        self.assertIn("Draft saved for this session. Not published.",u)
    def test_calendar_uses_shared_popup_and_canonical_date(self):
        c=read("Core/TournamentState.lua")
        u=read("UI/TournamentUI.lua")
        w=read("UI/Widgets.lua")
        self.assertIn("function T.ResolveCalendar",c)
        self.assertIn("function Widgets.OpenCalendar",w)
        self.assertIn("openChoicePopup=self;ChoiceCatcher(host):Show()",w)
        self.assertIn("W.OpenCalendar(startButton,T,selectedUTC",u)
        self.assertIn("form[key]=selectedUTC",u)
        self.assertNotIn('Field(manage,"startUTC"',u)
    def test_single_active_tournament(self):
        c=read("Core/TournamentRegistration.lua")
        t=read("Core/TournamentState.lua")
        u=read("UI/TournamentUI.lua")
        n=read("UI/Navigation.lua")
        self.assertIn("if BlocksCreation(event) then",c)
        self.assertIn("if not R.CanCreatePreview() then",c)
        self.assertIn("not ns.TournamentRegistration.CanCreatePreview()",t)
        self.assertIn('hosting={overview=true,manage=true,champions=true}',t)
        self.assertIn('local organizer=Page("manage")',u)
        self.assertIn('label = "Host Tournament"',n)
        self.assertIn('label = "Manage Tournament"',n)
    def test_registration_rehearsal_is_isolated(self):
        c=read("Core/TournamentRegistration.lua")
        u=read("UI/TournamentUI.lua")
        self.assertIn("P.Matches(s,ad)",c)
        self.assertIn('scope="SIMULATED"',c)
        self.assertIn("ns.TournamentRegistration.PreviewState()",read("Core/TournamentState.lua"))
        self.assertIn("Test Publishing",u)
        self.assertIn("LOCAL TEST",u)
        self.assertNotIn("SendAddonMessage",c)
        self.assertNotIn("C_ChatInfo",c)
        self.assertNotIn("DuelsReimaginedDB",c)
if __name__=="__main__": unittest.main()

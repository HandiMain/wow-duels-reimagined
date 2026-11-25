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
if __name__=="__main__": unittest.main()

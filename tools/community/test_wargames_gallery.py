"""Native-client-first gallery with documented illustrated arena fallbacks."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
ADDON=ROOT/"addon"/"DuelsReimagined"

def src(path): return (ADDON/path).read_text(encoding="utf-8")

class ArenaGalleryTests(unittest.TestCase):
    def test_retail_load_order_and_ownership(self):
        toc=src("DuelsReimagined.toc")
        self.assertIn("UI\\WarGamesArenaPicker.lua [AllowLoadGameType standard]",toc)
        self.assertLess(toc.index("UI\\Widgets.lua"),toc.index("UI\\WarGamesArenaPicker.lua"))
        self.assertLess(toc.index("UI\\WarGamesArenaPicker.lua"),toc.index("UI\\WarGames.lua"))
        self.assertLess(toc.index("UI\\WarGames.lua"),toc.index("UI\\Navigation.lua"))
        view=src("UI/WarGames.lua")
        picker=src("UI/WarGamesArenaPicker.lua")
        self.assertIn('Picker.CreatePreview(parent, page)',picker)
        self.assertIn('Picker.Open(page)',picker)
        self.assertIn('local playerMap = ns.WarGamesArenaPicker.CreatePreview(playerForm,"player")',view)
        self.assertIn('local hostMap=ns.WarGamesArenaPicker.CreatePreview(hostForm,"host")',view)
        for unsafe in ('StartWarGameByName','StartSpectatorWarGame',
                       'SendAddonMessage','CHAT_MSG_ADDON','SetScript("OnUpdate"',
                       '_G.DuelsReimaginedDB'):
            self.assertNotIn(unsafe,picker)
        self.assertNotIn('function SelectMap(page,anchor)',view)
        self.assertIn('Engine.SelectMap(page,index)',picker)

    def test_native_game_art_and_no_mismatched_arena(self):
        picker=src("UI/WarGamesArenaPicker.lua")
        for marker in ('GetFileIDFromPath','PaintArt(art,missing,name)',
                       'image:SetTexture(id)','PREVIEW UNAVAILABLE',
                       '["Nagrand Arena"]',"[\"Blade's Edge Arena\"]",
                       '["Ruins of Lordaeron"]','["Dalaran Sewers"]',
                       "[\"Tol'viron Arena\"]","[\"The Tiger's Peak\"]",
                       "[\"Ashamane's Fall\"]",'["Black Rook Hold Arena"]'):
            self.assertIn(marker,picker)
        self.assertNotIn('http://',picker)
        self.assertNotIn('https://',picker)
        self.assertIn("WarGamesArenaFallback.png",picker)
        self.assertNotIn('C_Map.GetMapArtLayers',picker)
        self.assertIn('for index,item in ipairs(known) do',picker)
        self.assertIn('local known=Engine.GetMaps()',picker)

    def test_generated_fallback_atlas_is_named_and_verified(self):
        import hashlib
        import struct
        picker=src("UI/WarGamesArenaPicker.lua")
        atlas=ADDON/"Media/Arenas/WarGamesArenaFallback.png"
        raw=atlas.read_bytes()
        self.assertEqual(raw[:8],bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack(">II",raw[16:24]),(1024,512))
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
            "029f3a70d4dba215a87bd3fcacb15ec5798cb0e6fbe800dd1485fb9833b22265")
        names=[
            "Nagrand Arena","Cage of Carnage","Empyrean Domain",
            "Enigma Crucible","Hook Point","Maldraxxus Coliseum",
            "Mugambala","Nokhudon Proving Grounds","The Robodrome",
        ]
        for index,name in enumerate(names):
            self.assertIn('["'+name+'"]',picker)
            self.assertIn('{'+str(index%4)+','+str(index//4)+'}',picker)
        self.assertIn('local candidates = visuals[name]',picker)
        self.assertLess(picker.index('if candidates then'),
                        picker.index('local tile = illustrationTiles[name]'))
        self.assertIn('return unpack(entry)',picker)
        self.assertIn("PREVIEW UNAVAILABLE",picker) # future maps still safe

    def test_popup_tooltips_disabled_without_affecting_other_actions(self):
        picker=src("UI/WarGamesArenaPicker.lua")
        style=src("UI/Style.lua")
        self.assertNotIn("ns.Tooltips.Bind(",picker)
        self.assertIn('tooltip=false',picker)
        self.assertIn('not (palette and palette.tooltip == false)',style)
        self.assertIn('if ns.Tooltips then ns.Tooltips.Hide(nil,true) end',picker)
        self.assertIn('ns.Tooltips.Bind(button, { title = caption,',style)

    def test_modal_cancel_confirm_filter_and_lifecycle(self):
        picker=src("UI/WarGamesArenaPicker.lua")
        view=src("UI/WarGames.lua")
        for marker in ('CHOOSE ARENA','Search arenas...', 'All Arenas',
                       'Favorites','Select Arena','Cancel','No matching arenas',
                       'function Picker.Close()', 'function Picker.Refresh()',
                       'search:SetScript("OnEscapePressed"',
                       'scroll:SetScript("OnMouseWheel"',
                       'scrollbar=Widgets.ScrollBar(scroll',
                       'if Engine.InArena() then return end',
                       'if not popup:IsShown() then return end'):
            self.assertIn(marker,picker)
        self.assertIn('Engine.SelectMap(page,index)',picker)
        self.assertEqual(picker.count('Engine.SelectMap(page,index)'),1)
        self.assertIn('ns.Search.Register("wargames:arena:"..pageKey',picker)
        self.assertIn('ns.WarGamesArenaPicker.Close()',view)
        self.assertIn('View.Refresh()',view)
        self.assertIn('playerMap:Refresh(selectedPlayerMap)',view)
        self.assertIn('hostMap:Refresh(selectedHostMap)',view)
        self.assertNotIn('SetScript("OnUpdate"',picker)

    def test_concept_fidelity_no_full_card_bleed(self):
        picker=src("UI/WarGamesArenaPicker.lua")
        # Regression: Style.Fill adds SetAllPoints by default. Any
        # replacement line/card edge must clear it BEFORE new anchors.
        self.assertIn('rule:ClearAllPoints()',picker)
        self.assertIn('bar:ClearAllPoints()',picker)
        self.assertIn('rim[i]:ClearAllPoints()',picker)
        self.assertLess(picker.index('rule:ClearAllPoints()'),
                        picker.index('rule:SetPoint("TOPLEFT"'))
        self.assertLess(picker.index('bar:ClearAllPoints()'),
                        picker.index('bar:SetPoint("BOTTOMLEFT"'))
        self.assertLess(picker.index('rim[i]:ClearAllPoints()'),
                        picker.index('rim[1]:SetPoint("TOPLEFT"'))
        self.assertIn('Style.Plate(popup,"shellCopper"',picker)
        self.assertIn('smooth=true',picker)
        self.assertIn('popup:SetPoint("BOTTOM",Window.content,"BOTTOM",55,13)',picker)
        self.assertIn('ns.Chrome.Icon(headerGroup,"Hall")',picker)
        self.assertIn('local all = Action("All Arenas",101,"dark")',picker)
        self.assertIn('Action("Select Arena",142,"gold")',picker)
        self.assertIn('local colWidth=math.max(160,(scroll:GetWidth()-32)/2)',picker)
        self.assertIn('col*(colWidth+12)',picker)
        self.assertNotIn('Action("★ Favorites"',picker)
        self.assertNotIn('Style.Text(b,"✓"',picker)
        self.assertNotIn('Style.Text(star,"☆"',picker)

    def test_popup_actions_share_real_footer_and_header_button_owners(self):
        picker=src("UI/WarGamesArenaPicker.lua")
        style=src("UI/Style.lua")
        header=src("UI/Header.lua")
        window=src("UI/Window.lua")
        toc=src("DuelsReimagined.toc")
        # These are the EXISTING artwork and interaction owners, not new
        # button images or a second independent hover/press engine.
        self.assertIn('local close=ns.Header.CreateCloseButton(popup)',picker)
        self.assertIn('function Header.CreateCloseButton(parent)',header)
        self.assertIn('return HeaderButton("Close", "Close", "Close dialog", parent, true)',header)
        self.assertIn('local b = CreateFrame("Button", nil, parent or header)',header)
        self.assertIn('Style.Plate(b, name == "Close" and "hall" or "dark"',header)
        self.assertIn('art:SetTexture(iconBase .. name .. ".png")',header)
        self.assertIn('if not withoutTooltip then',header)
        self.assertIn('Style.Plate(button, palette.plate',style)
        self.assertIn('button.plate = Style.Plate(',style)
        self.assertIn('plate=kind, tooltip=false',picker)
        self.assertIn('local cancel = Action("Cancel",142)',picker)
        self.assertIn('local confirm = Action("Select Arena",142,"gold")',picker)
        self.assertIn('local all = Action("All Arenas",101,"dark")',picker)
        self.assertIn('local favorites = Action("Favorites",108,"dark")',picker)
        self.assertIn('all.plate:SetStyle(not onlyFavorite and "gold" or "dark")',picker)
        self.assertIn('favorites.plate:SetStyle(onlyFavorite and "gold" or "dark")',picker)
        self.assertIn('Style.MenuButton(close,"close","Close",{danger=true})',window)
        self.assertIn('Style.Plate(button, "hall", { corner=9 })',style)
        self.assertLess(toc.index("UI\\Header.lua"),toc.index("UI\\WarGamesArenaPicker.lua"))
        self.assertNotIn('Action("X",23)',picker)
        self.assertNotIn('allSelected=Style.Fill',picker)
        self.assertNotIn('favoritesSelected=Style.Fill',picker)
        self.assertNotIn('ns.Tooltips.Bind(',picker)
        # Shared styles still preserve the tooltip opt-out for modal buttons.
        self.assertIn('not (palette and palette.tooltip == false)',style)

    def test_authored_glyph_atlas_valid(self):
        import struct
        asset=ADDON/"Media/Skin/WarGamesPickerGlyphs.tga"
        data=asset.read_bytes()
        self.assertEqual(len(data),18+128*32*4)
        self.assertEqual(data[2],2)  # uncompressed true-color
        self.assertEqual(struct.unpack_from("<HH",data,12),(128,32))
        self.assertEqual(data[16],32)  # RGBA8
        self.assertEqual(data[17],40)  # top-left origin + 8-bit alpha
        picker=src("UI/WarGamesArenaPicker.lua")
        self.assertIn("WarGamesPickerGlyphs.tga",picker)
        self.assertIn('check:SetTexCoord(0.5,0.75,0,1)',picker)
        self.assertIn('filterJewel:SetTexCoord(0.25,0.5,0,1)',picker)
        self.assertIn('card.star:SetTexCoord(item.favorite',picker)

    def test_favorites_one_owner_and_bounded(self):
        settings=src("Core/Settings.lua")
        picker=src("UI/WarGamesArenaPicker.lua")
        for marker in ('function Settings.GetWarGamesArenaFavorites()',
                       'function Settings.IsWarGamesArenaFavorite(name)',
                       'function Settings.ToggleWarGamesArenaFavorite(name)',
                       'math.min(#source,32)','warGamesArenaFavorites'):
            self.assertIn(marker,settings)
        self.assertIn('Settings.ToggleWarGamesArenaFavorite(b.name)',picker)
        self.assertNotIn('_G.DuelsReimaginedDB',picker)

    def test_responsive_geometry_safe_gutter(self):
        view=src("UI/WarGames.lua")
        self.assertIn('SCROLLBAR_GUTTER = 25, 30, 22',view)
        self.assertIn('Position(playerForm,0,0,w,301)',view)
        self.assertIn('Position(hostForm,0,0,w,277)',view)
        self.assertIn('Position(hostTeam1,0,294,half,258)',view)
        self.assertIn('PlaceMatchControls(hostForm,hostTournament,hostSend,w,180)',view)
        self.assertIn('PlaceMatchControls(playerForm,playerTournament,playerSend,w,229)',view)
        for width in (760,800,900,1050):
            useful=width-25-30-22
            col=(useful-36-3*12)/4
            self.assertGreater(col,140)
            self.assertLess(277,294)
            self.assertLess(301,317)
            self.assertLess(294+258,565)

if __name__=="__main__":
    unittest.main()

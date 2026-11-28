-- Injected local-shaped records, never real match or character data.
local ns={}
local root="addon/DuelsReimagined/"
local oldPrefs=_G.DuelsReimaginedCharacterPreferences
local oldAccount=_G.DuelsReimaginedDB
local oldChar=_G.DuelsReimaginedCharacterDB
local oldCompetitive=_G.DuelsReimaginedCompetitiveDB
local oldCreate=CreateFrame
local loader
local function noop()end
CreateFrame=function()
    local frame={RegisterEvent=noop,UnregisterEvent=noop}
    function frame:SetScript(key,fn) self[key]=fn end
    loader=frame;return frame
end
_G.DuelsReimaginedCharacterPreferences=nil
_G.DuelsReimaginedDB={}
for _,file in ipairs({"Settings","Achievements","DuelistTitles","AchievementShowcase","DuelistCollections"}) do
    assert(loadfile(root.."Core/"..file..".lua"))("DuelsReimagined",ns)
end
local K,A,S,T=ns.DuelistCollections,ns.Achievements,ns.Settings,ns.DuelistTitles
assert(not S.SetCharacterCosmetic("background","bronze"))
loader.OnEvent(loader,"ADDON_LOADED","DuelsReimagined")
local sim=false
local live={scope="LOCAL",matches={},recordingDisabled=true}
ns.CompetitivePreview={IsActive=function()return sim end,Local=function()return live end,Get=function()return live end}
local function Read()
    local a=A.Current(live);return K.Model(a,T.Model(a))
end
local model=Read()
assert(model.total==54 and model.earned==3 and #model.rows==14)
assert(model.counts.background.total==8 and model.counts.border.total==6 and model.counts.title.total==40)
assert(model.equipped.background=="faction" and model.equipped.border=="bronze")
assert(K.Rewards("rising")=="Background: Blood and Steel")
assert(K.Rewards("tested")=="Border: Battle Forged")
assert(not K.Equip("background","blood") and not K.Equip("border","faction"))
assert(_G.DuelsReimaginedCharacterPreferences==nil)
assert(K.Equip("background","bronze"))
local saved=_G.DuelsReimaginedCharacterPreferences
assert(saved.profileBackground=="bronze" and Read().equipped.background=="bronze")
S.Set("profileFactionBackdrop",false)
assert(K.Equip("background",nil) and Read().equipped.background=="bronze")
S.Set("profileFactionBackdrop",true)
assert(Read().equipped.background=="faction")
live.recordingDisabled=false
for i=1,25 do live.matches[i]={id="duel-"..i,kind="standard",outcome="won",time=1790000000+i} end
assert(Read().byKind.background.blood.earned)
assert(K.Equip("background","blood") and Read().equipped.background=="blood")
assert(K.Equip("border","blood") and Read().equipped.border=="blood")
saved.equippedTitle="first";saved.showcase={"begin"}
_G.DuelsReimaginedCharacterPreferences={}
assert(Read().equipped.background=="faction" and Read().equipped.border=="bronze")
_G.DuelsReimaginedCharacterPreferences=saved
assert(Read().equipped.background=="blood")
sim=true
assert(not K.Equip("background","bronze") and not K.Equip("border",nil))
local test=K.Model(A.Evaluate({scope="SIMULATED",matches=live.matches}))
assert(test.earned==3 and not test.editable and not test.byKind.background.blood.earned)
sim=false
live.matches={}
assert(Read().equipped.background=="faction" and Read().saved.background=="blood")
assert(K.Equip("background",nil) and saved.profileBackground==nil)
assert(saved.equippedTitle=="first" and saved.showcase[1]=="begin")
local private=K.Model({scope="LOCAL",rows={{id="tourwin",earned=true,testOnly=true,progress=1}}})
assert(not private.byKind.border.champion.earned)
local art=K.Art("border","grandmaster");art.color[1]=0
assert(K.Art("border","grandmaster").color[1]>.5)
assert(_G.DuelsReimaginedCharacterDB==oldChar and _G.DuelsReimaginedCompetitiveDB==oldCompetitive)
_G.DuelsReimaginedCharacterPreferences=oldPrefs;_G.DuelsReimaginedDB=oldAccount;CreateFrame=oldCreate
print("Duelist Collections: PASS (54 items, defaults, live eligibility, preference isolation, revoked evidence and test rejection)")

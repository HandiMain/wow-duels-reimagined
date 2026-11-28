-- Injected local-shaped records, never real match or character data.
local client="retail"
local ns={Client={Kind=function()return client end}}
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
assert(model.total==106 and model.earned==45 and #model.rows==66)
assert(model.counts.background.total==60 and model.counts.border.total==6 and model.counts.title.total==40)
local specs,keys=0,{}
for _,row in ipairs(model.rows) do
    if row.spec then
        specs=specs+1
        assert(row.earned and row.requirement=="Available by default." and row.atlas and not keys[row.spec])
        keys[row.spec]=true
    end
end
assert(specs==40 and keys[1480] and model.byKind.background["spec-1480"].name=="Devourer Demon Hunter")
assert(model.byKind.background.alliance.earned and model.byKind.background.horde.earned)
client="forever"
local classic=Read()
assert(classic.total==93 and classic.earned==32 and classic.counts.background.total==47)
assert(not classic.byKind.background["spec-104"] and not classic.byKind.background["spec-1480"])
assert(classic.byKind.background["spec-260"].name=="Combat Rogue")
assert(classic.byKind.background["spec-103"].name=="Feral Combat Druid")
assert(not classic.byKind.background["spec-260"].atlas and classic.byKind.background["spec-260"].native)
local classes={}
for _,row in ipairs(classic.rows) do if row.spec then classes[row.group]=(classes[row.group] or 0)+1;assert(row.earned and row.native) end end
local classCount=0;for _,count in pairs(classes) do classCount=classCount+1;assert(count==3) end
assert(classCount==9 and not classes.Evoker)
for _,group in ipairs(K.Groups(classic)) do assert(group.key~="Evoker" and group.key~="Demon Hunter") end
assert(not K.Equip("background","spec-1480"))
assert(K.IsKnown("background","spec-1480") and not K.IsSupported("background","spec-1480"))
client="retail"
assert(K.IsSupported("background","spec-1480"))
assert(model.equipped.background=="faction" and model.equipped.border=="bronze")
assert(K.Rewards("rising")=="Background: Blackrock Depths")
assert(K.Rewards("spree")=="Background: Molten Core; Border: Bloodforged")
assert(K.Rewards("tested")=="Border: Battle Forged")
assert(not K.Equip("background","blood") and not K.Equip("border","faction"))
assert(_G.DuelsReimaginedCharacterPreferences==nil)
assert(K.Equip("background","bronze"))
local saved=_G.DuelsReimaginedCharacterPreferences
assert(saved.profileBackground=="bronze" and Read().equipped.background=="bronze")
assert(K.Equip("background","alliance") and Read().equipped.background=="alliance")
assert(K.Equip("background","horde") and Read().equipped.background=="horde")
assert(K.Equip("background","spec-1480") and Read().equipped.background=="spec-1480")
client="forever"
assert(Read().equipped.background=="faction" and Read().saved.background=="spec-1480")
assert(not K.Equip("background","spec-1480"))
client="retail"
assert(Read().equipped.background=="spec-1480")
assert(K.Equip("background","bronze"))
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
assert(test.earned==45 and not test.editable and not test.byKind.background.blood.earned)
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
print("Duelist Collections: PASS (40 Retail specs, 27 Forever trees, 16 prestige rewards, client gates, defaults, live eligibility, saved choices and simulation isolation)")

-- Title catalogue uses the actual achievement engine. All live-looking
-- histories here are injected fixtures; never use the player's saved data.
local ns={}
local root="addon/DuelsReimagined/"
local original=_G.DuelsReimaginedCharacterPreferences
local originalAccount=_G.DuelsReimaginedDB
local originalCharacter=_G.DuelsReimaginedCharacterDB
local originalCompetitive=_G.DuelsReimaginedCompetitiveDB
local loader
local function noop()end
CreateFrame=function()
    local frame={RegisterEvent=noop,UnregisterEvent=noop}
    function frame:SetScript(key,fn) self[key]=fn end
    loader=frame;return frame
end
_G.DuelsReimaginedCharacterPreferences=nil
_G.DuelsReimaginedDB={}
assert(loadfile(root.."Core/Settings.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."Core/Achievements.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."Core/DuelistTitles.lua"))("DuelsReimagined",ns)
local T,A,S=ns.DuelistTitles,ns.Achievements,ns.Settings
assert(not S.SetCharacterTitle("first"))
loader.OnEvent(loader,"ADDON_LOADED","DuelsReimagined")
assert(_G.DuelsReimaginedCharacterPreferences==nil)
local sim=false
local live={scope="LOCAL",matches={},recordingDisabled=false}
ns.CompetitivePreview={IsActive=function()return sim end,Local=function()return live end,
    Get=function()return live end}
local function Read()return T.Read(live)end
local blank=Read();assert(blank.total==40 and blank.earned==0 and #blank.rows==40)
local unique={}
for _,r in ipairs(blank.rows) do
    assert(not unique[r.id] and r.name==T.Reward(r.id) and r.description and r.target>0)
    unique[r.id]=true
end
assert(blank.byId.giant.description:find("higher%-tier") and not blank.byId.giant.earned)
assert(not T.Equip("first") and not T.Equip("does-not-exist"))
assert(_G.DuelsReimaginedCharacterPreferences==nil)
live.matches={{id="one",kind="standard",outcome="won",time=1790000000}}
local model=Read();assert(model.earned==2 and model.byId.begin.earned and model.byId.first.earned)
assert(T.Equip("first") and Read().equipped=="first")
assert(_G.DuelsReimaginedCharacterPreferences.equippedTitle=="first")
local saved=_G.DuelsReimaginedCharacterPreferences
_G.DuelsReimaginedCharacterPreferences={}
assert(Read().equipped==nil,"other character inherited title")
_G.DuelsReimaginedCharacterPreferences=saved
assert(Read().equipped=="first","selection did not survive root replacement")
sim=true;assert(not T.Equip("begin") and not T.Equip(nil))
assert(T.Model(A.Evaluate({scope="SIMULATED",matches=live.matches})).earned==0)
assert(_G.DuelsReimaginedCharacterPreferences==saved and saved.equippedTitle=="first")
sim=false
live.recordingDisabled=true
assert(Read().earned==0 and not Read().equipped and not T.Equip("begin"))
live.recordingDisabled=false;assert(Read().equipped=="first")
live.matches={}
assert(not Read().equipped and not T.Equip("first"),"corrected evidence still equipped title")
assert(T.Equip(nil) and saved.equippedTitle==nil)
assert(not S.SetCharacterTitle("unknown"))
live.storageReason="unavailable";assert(Read().earned==0 and not T.Equip("begin"))
live.storageReason=nil
local fakeTournament={scope="LOCAL",rows={{id="tourwin",earned=true,testOnly=true,progress=1}}}
assert(not T.Model(fakeTournament).byId.tourwin.earned)
assert(_G.DuelsReimaginedCharacterDB==originalCharacter and _G.DuelsReimaginedCompetitiveDB==originalCompetitive)
_G.DuelsReimaginedCharacterPreferences=original;_G.DuelsReimaginedDB=originalAccount
print("Duelist Titles: PASS (40 reward mappings, real eligibility, character choice, correction, simulation and test isolation)")

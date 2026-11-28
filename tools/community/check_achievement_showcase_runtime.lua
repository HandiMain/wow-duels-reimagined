-- Exercise the real achievement evaluator and preference owner with isolated
-- mock histories. No test outcome can enter the player's cosmetic choices.
local ns={}
local root="addon/DuelsReimagined/"
local original=_G.DuelsReimaginedCharacterPreferences
local originalAccount=_G.DuelsReimaginedDB
local originalCharacter=_G.DuelsReimaginedCharacterDB
local originalCompetitive=_G.DuelsReimaginedCompetitiveDB
local oldCreateFrame=CreateFrame
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
assert(loadfile(root.."Core/AchievementShowcase.lua"))("DuelsReimagined",ns)
local Q,A,S=ns.AchievementShowcase,ns.Achievements,ns.Settings
assert(not S.SetCharacterShowcase({"first"}))
loader.OnEvent(loader,"ADDON_LOADED","DuelsReimagined")
assert(_G.DuelsReimaginedCharacterPreferences==nil)
local sim=false
local live={scope="LOCAL",matches={},recordingDisabled=false}
ns.CompetitivePreview={IsActive=function()return sim end,Local=function()return live end,
    Get=function()return live end}
local function Read()return Q.Model(A.Current(live))end
assert(#Read().saved==0 and Read().editable)
assert(not Q.Toggle("first") and not Q.Toggle("not-an-id"))
assert(_G.DuelsReimaginedCharacterPreferences==nil)
assert(not Q.Validate({"first","first"}))
assert(not Q.Validate({[2]="first"}))
assert(not Q.Validate({"begin","first","double","spree"}))
assert(not Q.Validate({first=true}))
for i=1,5 do live.matches[i]={id="duel-"..i,kind="standard",outcome="won",time=1790000000+i} end
assert(Read().byId.first and Read().byId.double and Read().byId.spree)
assert(Q.Toggle("begin") and Q.Toggle("first") and Q.Toggle("double"))
assert(Q.Same(Read().saved,{"begin","first","double"}))
assert(not Q.Toggle("spree"),"fourth pin silently displaced another")
assert(not Q.SaveOrder({"begin","spree"},{"begin","first","double"}),"editor added an unpinned achievement")
assert(Q.SaveOrder({"double","begin","first"},{"begin","first","double"}))
assert(Q.Same(Read().saved,{"double","begin","first"}))
assert(not Q.SaveOrder({"first"},{"begin","first","double"}),"stale draft overwrote new order")
local detached=S.GetCharacterShowcase();detached[1]="spree"
assert(Read().saved[1]=="double","read returned a SavedVariables alias")
local stored=_G.DuelsReimaginedCharacterPreferences
stored.equippedTitle="first"
_G.DuelsReimaginedCharacterPreferences={}
assert(#Read().saved==0,"other character inherited showcase")
_G.DuelsReimaginedCharacterPreferences=stored
assert(Q.Same(Read().saved,{"double","begin","first"}))
sim=true
assert(not Q.Toggle("double") and not Q.SaveOrder({},{"double","begin","first"}))
local test=Q.Model(A.Evaluate({scope="SIMULATED",matches=live.matches}))
assert(not test.editable and #test.saved==0 and not next(test.byId))
assert(Q.Same(S.GetCharacterShowcase(),{"double","begin","first"}))
sim=false
live.recordingDisabled=true
assert(not Read().byId.double and #Read().saved==3,"unavailable data lost preference or granted badge")
assert(Q.Toggle("double"),"unpin should work even if original evidence is unavailable")
assert(not Q.Toggle("spree"))
live.recordingDisabled=false;live.matches={}
assert(not Read().byId.first and #Read().saved==2,"corrected evidence still displayed a badge")
assert(Q.SaveOrder({},{"begin","first"}))
assert(#Read().saved==0 and stored.equippedTitle=="first","clearing showcase affected title")
live.storageReason="unavailable"
assert(not Q.Toggle("first"))
local private=Q.Model({scope="LOCAL",rows={{id="tourwin",earned=true,testOnly=true,progress=1}}})
assert(not private.byId.tourwin)
stored.showcase={"first","first"}
assert(not Read().editable and not Q.Toggle("first"),"malformed storage accepted")
assert(stored.showcase[2]=="first","malformed storage silently rewritten")
assert(_G.DuelsReimaginedCharacterDB==originalCharacter and _G.DuelsReimaginedCompetitiveDB==originalCompetitive)
_G.DuelsReimaginedCharacterPreferences=original;_G.DuelsReimaginedDB=originalAccount
CreateFrame=oldCreateFrame
print("Achievement Showcase: PASS (eligible pins, cap, order, stale edits, character isolation and test rejection)")

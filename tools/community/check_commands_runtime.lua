-- Player command smoke test: execute the shipped registry with stubbed owners.
local ns,output,actions={}, {}, {}
local shown,combat,retail,editing=false,false,true,false
DEFAULT_CHAT_FRAME={AddMessage=function(_,line) output[#output+1]=line end}
SlashCmdList={}
InCombatLockdown=function()return combat end
ns.Client={IsRetail=function()return retail end}
ns.Window={frame={IsShown=function()return shown end},Toggle=function()shown=not shown;actions[#actions+1]="toggle" end}
ns.Search={entries={},Open=function(item)item.activate();return true end}
local function Item(id,available)
    ns.Search.entries[id]={activate=function()actions[#actions+1]=id end,available=available}
end
for _,id in ipairs({"page:options:options","page:addonstatus:status","page:hall:overview","page:leaderboard:standings",
    "page:matchhistory:history","page:achievements:achievements","page:tournaments:overview","page:tournaments:champions",
    "page:wargames:player","page:community:community","page:patchnotes:latest",
    "setting:duelCountdownVisual","setting:notificationEnabled","setting:duelCountdownSoundPack"}) do Item(id) end
ns.PatchNotesData={{key="latest"}}
ns.CompetitiveUI={OpenMyProfile=function()actions[#actions+1]="profile";return true end,
    OpenMyTitles=function()actions[#actions+1]="titles";return true end}
ns.DiagnosticsUI={Open=function()actions[#actions+1]="diagnostics" end}
local enabled=true
ns.Settings={Get=function()return enabled end,Set=function(_,value)enabled=value end,
    ResetDuelHUDPosition=function()actions[#actions+1]="reset position" end,Reset=function(key)actions[#actions+1]=key end}
ns.EditMode={IsActive=function()return editing end,Open=function(key)editing=true;actions[#actions+1]=key;return true end,
    Cancel=function()editing=false end}
ns.DuelSelfTest={Run=function(_,verbose)actions[#actions+1]=verbose and "verbose" or "test" end}
assert(loadfile("addon/DuelsReimagined/Core/Commands.lua"))("DuelsReimagined",ns)
local run=SlashCmdList.DUELSREIMAGINED
local function Last()return actions[#actions] end
run(" HELP ");local help=table.concat(output,"\n")
for _,name in ipairs({"help","options","status","diagnostics","hall","profile","titles","leaderboard","history","achievements","tournaments","champions","wargames","hud","hud reset","edit","countdown","notifications","sounds","community","patchnotes"}) do
    assert(help:find("/duels "..name.."|r",1,true),name)
end
for _,name in ipairs({"sim","test","trace","peer","storage","sync","tournament net","sounds status","hud preview"}) do assert(not help:find("/duels "..name.."|r",1,true),name) end
assert(not shown and #actions==0)
retail=false;output={};run("help");assert(not table.concat(output,"\n"):find("/duels wargames",1,true))
run("wargames");assert(not shown and #actions==0)
retail=true
run("  MATCHHISTORY ");assert(not shown and #actions==0 and output[#output]:find("Unknown command",1,true))
run("  HISTORY  ");assert(shown and Last()=="page:matchhistory:history")
run("hall");assert(shown and Last()=="page:hall:overview")
run("profile");assert(shown and Last()=="profile")
run("titles");assert(shown and Last()=="titles")
run("patchnotes");assert(Last()=="page:patchnotes:latest")
run("countdown");assert(Last()=="setting:duelCountdownVisual")
run("notifications");assert(Last()=="setting:notificationEnabled")
run("sounds");assert(Last()=="setting:duelCountdownSoundPack")
run("hud");assert(not enabled)
run(" HUD   RESET ");assert(Last()=="duelHUDScale")
run("edit");assert(editing and Last()=="countdown")
run("edit");assert(not editing)
run("");assert(not shown)
combat=true;local n=#actions;run("options");run("");run("diagnostics");run("hud");assert(not shown and #actions==n and not enabled)
combat=false
Item("page:tournaments:champions",function()return false end);run("champions");assert(not shown and #actions==n)
run("test verbose");assert(Last()=="verbose")
run("diagnostics");assert(Last()=="diagnostics")
run("");assert(shown);run("");assert(not shown)
print("Player slash command registry: PASS (help, client gating, navigation, settings, edit, combat, unknown, hidden QA)")

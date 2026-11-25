-- Isolated creation and navigation QA. No WoW API, persistence or network.
local ns={Client={Kind=function()return "forever" end,IsSupported=function()return true end}}
local root=(arg and arg[1] or "addon/DuelsReimagined")
-- The overview projection is pure; the view is not constructed by QA.
ns.Style={color={pale={},text={},muted={},gold={}}}
assert(loadfile(root.."/UI/TournamentOverview.lua"))("DuelsReimagined",ns)
assert(ns.TournamentOverview.RunSelfTest(),"tournament overview state QA failed")
ns.Style=nil
assert(loadfile(root.."/Core/CompetitiveScope.lua"))("DuelsReimagined",ns)
local sp,sf=ns.CompetitiveScope.RunSelfTest(print)
assert(sp==7 and sf==0,"population QA failed")
assert(loadfile(root.."/Core/TournamentState.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/CompetitiveStorage.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/TournamentRecovery.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/TournamentRegistration.lua"))("DuelsReimagined",ns)
assert(ns.CompetitiveStorage.RunTournamentTestStorageSelfTest(),"private tournament test storage QA failed")
local rp,rf=ns.TournamentRegistration.RunSelfTest(print)
assert(rp==17 and rf==0,"registration QA failed")
local ep,ef=ns.TournamentRegistration.RunExchangeSelfTest(print)
assert(ep==10 and ef==0,"tournament exchange QA failed")
local jp,jf=ns.TournamentRegistration.RunRecoverySelfTest(print)
assert(jp==10 and jf==0,"tournament recovery QA failed")
assert(loadfile(root.."/Core/TournamentBracket.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/ResultConfirmation.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/TournamentGameplay.lua"))("DuelsReimagined",ns)
-- Minimal inert host for loading the detector; every gameplay case uses its own sandbox.
local oldFrame,oldClock=CreateFrame,GetTime
local oldAfter,oldHook=C_Timer,hooksecurefunc
local oldGroup=ns.Group;ns.Group={ReadPlayerIdentity=function()end}
CreateFrame=function()return {RegisterEvent=function()end,UnregisterAllEvents=function()end,SetScript=function()end}end
GetTime=function()return 0 end;C_Timer={After=function()end};hooksecurefunc=function()end
assert(loadfile(root.."/Core/DuelDetection.lua"))("DuelsReimagined",ns)
CreateFrame,GetTime,C_Timer,hooksecurefunc=oldFrame,oldClock,oldAfter,oldHook
ns.Group=oldGroup
local hp,hf=ns.TournamentRegistration.RunHostRecoverySelfTest(print)
assert(hp==72 and hf==0,"tournament host recovery QA failed")
local np,nf=ns.TournamentRegistration.RunPrivateNetworkSelfTest(print)
assert(np==2 and nf==0,"private tournament lifecycle QA failed")
assert(loadfile(root.."/Core/TournamentSession.lua"))("DuelsReimagined",ns)
assert(ns.TournamentSession.RunGateSelfTest(),"private tournament network gate QA failed")
local pp,pf=ns.TournamentRegistration.RunPlayerPreviewSelfTest(print)
assert(pp==2 and pf==0,"tournament player preview QA failed")
local xp,xf=ns.TournamentRegistration.RunShowcaseSelfTest(print)
assert(xp==2 and xf==0,"tournament showcase QA failed")
local bp,bf=ns.TournamentBracket.RunSelfTest(print)
assert(bp==24 and bf==0,"tournament bracket QA failed")
assert(loadfile(root.."/UI/BracketView.lua"))("DuelsReimagined",ns)
local vp,vf=ns.BracketView.RunSelfTest(print)
assert(vp==4 and vf==0,"bracket layout QA failed")
assert(loadfile(root.."/UI/TournamentHUD.lua"))("DuelsReimagined",ns)
local hp2,hf2=ns.TournamentHUD.RunSelfTest(print)
assert(hp2==2 and hf2==0,"tournament HUD projection QA failed")
local T=ns.TournamentState
local cp,cf=T.RunCalendarSelfTest(print)
assert(cp==5 and cf==0,"calendar QA failed")
assert(T.RunSelfTest()==12)
local p,f=T.RunCreationSelfTest(print)
assert(p==15 and f==0,"creation QA failed")
print("15 creation and 12 navigation checks passed")

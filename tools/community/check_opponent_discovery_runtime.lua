-- The in-game isolated protocol QA and a live-wiring mock.
local sent=0
local cb,duel
local ns={Client={Kind=function()return "retail" end},
    Group={ReadPlayerIdentity=function(unit)
        if unit=="player" then return {guid="Player-1-AAA",fullName="Alpha-Home"} end
        if unit=="target" then return {guid="Player-2-BBB",fullName="Beta-Other"} end
    end},
    Communication={IsAvailable=function()return true end,
        Send=function(tag,body,channel,target) sent=sent+1;assert(tag=="D1" and channel=="WHISPER" and target=="Beta-Other");return true end,
        Subscribe=function(tag,fn) assert(tag=="D1");cb=fn end},
    DuelDetection={Subscribe=function(fn)duel=fn end}}
GetTime=function()return 100 end
GetServerTime=function()return 123456789 end
GetNormalizedRealmName=function()return "Home" end
issecretvalue=function()return false end
C_Timer={After=function()end}
CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end} end
assert(loadfile("addon/DuelsReimagined/Core/OpponentDiscovery.lua"))("DuelsReimagined",ns)
local P=ns.OpponentDiscovery
local passed,failed=P.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(passed==13 and failed==0 and sent==0,"isolated discovery suite")
duel({scope="SIMULATED",state="challenge",challenge={opponent={guid="Player-2-BBB"}}})
duel({scope="LOCAL",state="challenge",challenge={opponent={guid="Player-3-CCC"}}})
assert(sent==0,"simulation or unrelated target sent a live probe")
duel({scope="LOCAL",state="challenge",challenge={opponent={guid="Player-2-BBB"}}})
assert(sent==1 and P.GetSnapshot().state=="checking" and not P.GetSnapshot().rankEligible,"live challenge probe")
passed,failed=P.RunSelfTest()
assert(passed==13 and failed==0 and sent==1 and P.GetSnapshot().state=="checking","QA did not change pending live probe")
print("Opponent discovery simulated protocol and live wiring mock: PASS")

-- Agreement has no live adapter. Guard the existing transport and detector.
local previous=sent
assert(loadfile("addon/DuelsReimagined/Core/PeerAgreement.lua"))("DuelsReimagined",ns)
local A=ns.PeerAgreement
local ap,af=A.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(ap==21 and af==0 and sent==previous and P.GetSnapshot().state=="checking","isolated agreement suite")
assert(A.GetSnapshot().state=="disabled" and not A.GetSnapshot().rankEligible,"live agreement gate")
print("Peer agreement isolated protocol: PASS")

-- Result confirmation stays isolated from both existing live and simulated peer states.
assert(loadfile("addon/DuelsReimagined/Core/ResultConfirmation.lua"))("DuelsReimagined",ns)
local R=ns.ResultConfirmation
local rp,rf=R.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(rp==21 and rf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated result confirmation suite")
assert(R.GetSnapshot().state=="disabled" and not R.GetSnapshot().rankEligible and A.GetSnapshot().state=="disabled","live competitive gates")
print("Result confirmation isolated records: PASS")

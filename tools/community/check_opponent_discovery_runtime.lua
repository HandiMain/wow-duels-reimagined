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

-- Ledger uses a private storage envelope; existing live state remains untouched.
local originalDB=_G.DuelsReimaginedDB
assert(loadfile("addon/DuelsReimagined/Core/MatchLedger.lua"))("DuelsReimagined",ns)
local L=ns.MatchLedger
local lp,lf=L.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(lp==25 and lf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated match ledger suite")
assert(L.GetSnapshot().state=="disabled" and not L.GetSnapshot().rankEligible and _G.DuelsReimaginedDB==originalDB,"live storage gate")
print("Match ledger isolated storage: PASS")

-- Personal history derives projections from private ledger instances only.
assert(loadfile("addon/DuelsReimagined/Core/PersonalHistory.lua"))("DuelsReimagined",ns)
local H=ns.PersonalHistory
local hp,hf=H.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(hp==25 and hf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated personal history suite")
assert(H.GetSnapshot().state=="disabled" and not H.GetSnapshot().rankEligible and _G.DuelsReimaginedDB==originalDB,"live history gate")
print("Personal history isolated statistics: PASS")

-- Exercise the explicit live probe against temporary globals, then restore.
local oldAccount,oldChar=_G.DuelsReimaginedCompetitiveDB,_G.DuelsReimaginedCharacterDB
local ok,err=pcall(function()
    _G.DuelsReimaginedCompetitiveDB=nil;_G.DuelsReimaginedCharacterDB=nil
    assert(loadfile("addon/DuelsReimagined/Core/CompetitiveStorage.lua"))("DuelsReimagined",ns)
    local S=ns.CompetitiveStorage
    assert(not S.RunPersistenceProbe(),"storage must wait for addon load")
    S.MarkLoaded()
    assert(S.GetSnapshot().accountProbe==0 and S.GetSnapshot().characterProbe==0)
    assert(S.RunPersistenceProbe(),"explicit storage probe")
    local a,c=_G.DuelsReimaginedCompetitiveDB,_G.DuelsReimaginedCharacterDB
    local sp,sf=S.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
    local q=S.GetSnapshot()
    assert(sp==21 and sf==0 and q.accountProbe==1 and q.characterProbe==1 and not q.rankEligible,"isolated storage lifecycle suite")
    assert(a==_G.DuelsReimaginedCompetitiveDB and c==_G.DuelsReimaginedCharacterDB and _G.DuelsReimaginedDB==originalDB,"QA never writes live roots")
    local dp,df=S.RunRecordSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
    assert(dp==15 and df==0 and a==_G.DuelsReimaginedCompetitiveDB and c==_G.DuelsReimaginedCharacterDB,"isolated durable record suite")
    _G.DuelsReimaginedCompetitiveDB={version=1,kind="account",clients={retail={probe=1}}}
    _G.DuelsReimaginedCharacterDB={version=1,kind="character",owner="Player-1-AAA",clients={retail={probe=1}}}
    assert(not S.GetSnapshot().prepared and S.PrepareSchema(),"explicit legacy migration")
    q=S.GetSnapshot()
    assert(q.prepared and q.version==2 and q.accountProbe==1 and q.characterProbe==1,"preserve probe values")
    assert(sent==previous and P.GetSnapshot().state=="checking","existing transport untouched")
end)
_G.DuelsReimaginedCompetitiveDB=oldAccount;_G.DuelsReimaginedCharacterDB=oldChar
assert(ok,err)
print("Competitive storage explicit probe and isolated lifecycle: PASS")

-- Rebuild ratings only from the isolated, validated ledger.
assert(loadfile("addon/DuelsReimagined/Core/CompetitiveRules.lua"))("DuelsReimagined",ns)
assert(loadfile("addon/DuelsReimagined/Core/RatingEngine.lua"))("DuelsReimagined",ns)
local E=ns.RatingEngine
local ep,ef=E.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(ep==25 and ef==0 and sent==previous and P.GetSnapshot().state=="checking","isolated rating replay")
assert(E.GetSnapshot().state=="disabled" and not E.GetSnapshot().rankEligible
    and _G.DuelsReimaginedDB==originalDB and _G.DuelsReimaginedCompetitiveDB==oldAccount
    and _G.DuelsReimaginedCharacterDB==oldChar,"rating QA never writes live data")
print("Rating engine isolated replay: PASS")

local C=ns.CompetitiveRules
local cp,cf=C.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(cp==19 and cf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated competitive rules")
assert(C.GetSnapshot().state=="disabled" and not C.GetSnapshot().rankEligible
    and _G.DuelsReimaginedDB==originalDB and _G.DuelsReimaginedCompetitiveDB==oldAccount
    and _G.DuelsReimaginedCharacterDB==oldChar,"rules QA never writes live data")
print("Competitive rules isolated anti-farming: PASS")

-- Logical pages never enter the actual communication transport or SavedVariables.
assert(loadfile("addon/DuelsReimagined/Core/LeaderboardSync.lua"))("DuelsReimagined",ns)
local Y=ns.LeaderboardSync
local yp,yf=Y.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(yp==25 and yf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated peer convergence")
assert(Y.GetSnapshot().state=="disabled" and not Y.GetSnapshot().rankEligible
    and _G.DuelsReimaginedDB==originalDB and _G.DuelsReimaginedCompetitiveDB==oldAccount
    and _G.DuelsReimaginedCharacterDB==oldChar,"sync QA never writes live data")
print("Leaderboard sync isolated peer convergence: PASS")

-- Simulated byte packets never use the live transport.
assert(loadfile("addon/DuelsReimagined/Core/SyncProtocol.lua"))("DuelsReimagined",ns)
local W=ns.SyncProtocol
local wp,wf=W.RunSelfTest(function(line)if line:find("FAIL",1,true) then print(line) end end)
assert(wp==23 and wf==0 and sent==previous and P.GetSnapshot().state=="checking","isolated packet lifecycle")
assert(W.GetSnapshot().state=="disabled" and not W.GetSnapshot().rankEligible
    and _G.DuelsReimaginedDB==originalDB and _G.DuelsReimaginedCompetitiveDB==oldAccount
    and _G.DuelsReimaginedCharacterDB==oldChar,"protocol QA never writes live data")
print("Sync protocol isolated packet lifecycle: PASS")

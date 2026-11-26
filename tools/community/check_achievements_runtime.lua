local base="addon/DuelsReimagined/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol","Achievements"}) do
    assert(loadfile(base.."Core/"..name..".lua"))("DuelsReimagined",ns)
end
assert(loadfile(base.."UI/CompetitivePreview.lua"))("DuelsReimagined",ns)
local function Row(a,id)for _,r in ipairs(a.rows) do if r.id==id then return r end end end
for _,client in ipairs({"retail","forever"}) do
    local function Eval(events)return ns.Achievements.Evaluate(ns.CompetitivePreview.Build(client,events))end
    local a=Eval({});assert(a.total==55 and a.earned==0 and a.points==0)
    a=Eval({{outcome="won",opponent=1,mode="unranked"},{outcome="won",opponent=1,mode="practice"},{outcome="unknown",opponent=2},{outcome="fled",opponent=3},{outcome="they_fled",opponent=4}})
    assert(a.earned==3 and a.points==15 and Row(a,"begin").earned and Row(a,"first").earned and Row(a,"double").earned)
    assert(Row(a,"tested").progress==2 and Row(a,"rising").progress==2 and Row(a,"meet").progress==1)
    assert(Row(a,"first").earnedAt and not Row(a,"placement").earned and Row(a,"giant").hidden)
    local events={};for i=1,5 do events[i]={outcome="won",opponent=i} end
    a=Eval(events);assert(Row(a,"placement").earned and Row(a,"aspirant").earned and Row(a,"rated").progress==5)
    assert(Row(a,"spree").earned and Row(a,"meet").progress==5)
    local d=ns.CompetitivePreview.Build(client,events);d.matches[#d.matches+1]=d.matches[1]
    assert(ns.Achievements.Evaluate(d).points==a.points)
    local unknown=ns.Achievements.Evaluate({scope="LOCAL",recordingDisabled=true,matches=d.matches,achievementReplay=d.achievementReplay,client=client})
    assert(unknown.points==0 and Row(unknown,"begin").unavailable)
    local raw=ns.Achievements.Evaluate({scope="SIMULATED",matches={{id="war",kind="wargame",outcome="won"},{id="unknown",kind="unclassified",outcome="won"}}})
    assert(raw.earned==0 and raw.points==0)
    local again=Eval(events);assert(again.points==a.points and Row(again,"first").earnedAt==Row(a,"first").earnedAt)
    local repeated={};for i=1,8 do repeated[i]={outcome="won",opponent=1} end
    local capped=Eval(repeated);assert(Row(capped,"rising").progress==8 and Row(capped,"rated").progress<8)
    -- Exercise the real local provider with canonical, reopened LOCAL history.
    -- Dependency injection is confined to this process; live gates unchanged.
    local me,peer="Player-1-SELF","Player-1-RIVAL"
    local h=assert(ns.PersonalHistory.OpenLocal(client,me))
    local stamp=1700000100
    assert(h.Observe("run-1",{scope="LOCAL",client=client,id=1,kind="standard",opponent={guid=peer},
        acceptedAt=0,endedAt=10,observedAt=stamp,outcome="won",endType="knockout",
        reason="matching_result_and_finish",outcomeObserved=true,finishObserved=true,resultObserved=true,
        conflict=false,rankEligible=false}))
    local saved=h.Save()
    assert(not ns.PersonalHistory.OpenLocal(client,"Player-1-OTHER",saved))
    local other=client=="retail" and "forever" or "retail"
    assert(not ns.PersonalHistory.OpenLocal(other,me,saved))
    local storage=ns.CompetitiveStorage
    local oldRead,oldPeer,oldCap,oldEnabled=storage.ReadLocalHistory,storage.ReadPeerView,storage.ReadLocalCapacity,storage.LocalRecordingEnabled
    storage.ReadLocalHistory=function()return assert(ns.PersonalHistory.OpenLocal(client,me,saved)).Snapshot()end
    storage.ReadPeerView=function()return nil,"no_evidence"end
    storage.ReadLocalCapacity=function()return {}end
    storage.LocalRecordingEnabled=function()return true end
    ns.Client={Kind=function()return client end}
    ns.Group={ReadPlayerIdentity=function()return {guid=me}end}
    GetServerTime=function()return stamp+20 end
    local localData=ns.Achievements.Evaluate(ns.CompetitivePreview.Local())
    assert(localData.scope=="LOCAL" and localData.points==10 and localData.earned==2)
    assert(Row(localData,"first").earnedAt==stamp and Row(localData,"rated").unavailable)
    local reopened=ns.Achievements.Evaluate(ns.CompetitivePreview.Local())
    assert(reopened.points==localData.points and Row(reopened,"first").earnedAt==stamp)
    storage.ReadLocalHistory,storage.ReadPeerView,storage.ReadLocalCapacity,storage.LocalRecordingEnabled=oldRead,oldPeer,oldCap,oldEnabled
end
-- New awards never leak test evidence into the existing achievement point total.
for _,scope in ipairs({"SIMULATED","PRIVATE_TEST"}) do
    local r={id="cup",scope=scope,played=true,placement=1,finishedAt=1700000000,count=32,wins=2,losses=0,
        matches={{won=true,score="2 - 0"},{won=true,score="2 - 0"}}}
    local host={id="hosted",scope=scope,hosted=true,finishedAt=1700000001}
    local data={scope="LOCAL",recordingDisabled=true}
    local a=ns.Achievements.Evaluate(data,{r,r,host},scope)
    assert(a.total==55 and a.points==0 and a.earned==0 and a.categories.Tournaments.earned==7)
    assert(Row(a,"tourbegin").earned and Row(a,"tourfinal").earned and Row(a,"tourwin").earned)
    assert(Row(a,"toursweep").earned and Row(a,"tourarena").earned and Row(a,"tourhost").earned)
    assert(Row(a,"tourreign").progress==1 and Row(a,"tourlegend").progress==1 and Row(a,"tourveteran").progress==1)
    r.matches[1].forfeit=true;assert(not Row(ns.Achievements.Evaluate(data,{r},scope),"toursweep").earned)
    r.matches[1].forfeit=nil;r.matches[1].score="2 - 1";assert(not Row(ns.Achievements.Evaluate(data,{r},scope),"toursweep").earned)
    assert(Row(ns.Achievements.Evaluate(data,{r},"LOCAL"),"tourwin").unavailable)
    assert(not Row(ns.Achievements.Evaluate(data,{r},scope=="SIMULATED" and "PRIVATE_TEST" or "SIMULATED"),"tourwin").earned)
end
assert(ns.Achievements.RunExpansionSelfTest())
assert(_G.DuelsReimaginedCompetitiveDB==nil and _G.DuelsReimaginedCharacterDB==nil)
print("Duel-only achievements: PASS (catalogue, evidence, streaks, simulation isolation, duplicate and disabled gates)")

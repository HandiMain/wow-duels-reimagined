local base="addon/DuelsReimagined/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol","Achievements"}) do
    assert(loadfile(base.."Core/"..name..".lua"))("DuelsReimagined",ns)
end
assert(loadfile(base.."UI/CompetitivePreview.lua"))("DuelsReimagined",ns)
local function Row(a,id)for _,r in ipairs(a.rows) do if r.id==id then return r end end end
for _,client in ipairs({"retail","forever"}) do
    local function Eval(events)return ns.Achievements.Evaluate(ns.CompetitivePreview.Build(client,events))end
    local a=Eval({});assert(a.total==30 and a.earned==0 and a.points==0)
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
end
assert(_G.DuelsReimaginedCompetitiveDB==nil and _G.DuelsReimaginedCharacterDB==nil)
print("Duel-only achievements: PASS (catalogue, evidence, streaks, simulation isolation, duplicate and disabled gates)")

local _,ns=...
-- Derived from canonical duel observations and validated season replay.
-- Never owns SavedVariables, rating, match transport or notification delivery.
local A={};ns.Achievements=A
A.Categories={"Dueling","Mastery","Competitive","Rivalries","Legacy","Tournaments"}
local catalog={
 {"begin","Dueling","The Beginning","Complete your first duel.","duels",1,5,1,"INV_Sword_04",1},
 {"first","Dueling","First Blood","Win your first duel.","wins",1,5,1,"INV_Helmet_03",2},
 {"tested","Dueling","Battle Tested","Complete 50 duels.","duels",50,10,3,"Ability_DualWield",3},
 {"rising","Dueling","Rising Challenger","Win 25 duels.","wins",25,10,4,"INV_BannerPVP_02",4},
 {"seasoned","Dueling","Seasoned Fighter","Win 100 duels.","wins",100,20,4,"INV_Helmet_06"},
 {"born","Dueling","Born to Duel","Win 500 duels.","wins",500,30,4,"INV_Sword_48"},
 {"thousand","Dueling","A Thousand Victories","Win 1,000 duels.","wins",1000,50,5,"INV_Sword_2H_ArcaniteChampion"},
 {"double","Mastery","Double Trouble","Win 2 consecutive duels.","streak",2,5,1,"Ability_Warrior_Cleave"},
 {"spree","Mastery","Killing Spree","Win 5 consecutive duels.","streak",5,10,2,"Ability_Rogue_KillingSpree"},
 {"unstoppable","Mastery","Unstoppable","Win 10 consecutive duels.","streak",10,20,3,"Ability_Warrior_Recklessness"},
 {"untouchable","Mastery","Untouchable","Win 20 consecutive duels.","streak",20,30,4,"Ability_Rogue_Evasion"},
 {"perfection","Mastery","Perfection","Win 30 consecutive duels.","streak",30,50,5,"Spell_Holy_DivineProtection"},
 {"placement","Competitive","Into the Arena","Complete ranked placement requirements.","rank",1,10,2,"INV_Shield_05"},
 {"aspirant","Competitive","Aspirant","Reach Aspirant or higher.","rank",1,10,2,"INV_Shield_04"},
 {"contender","Competitive","Contender","Reach Contender or higher.","rank",2,15,3,"INV_Shield_06"},
 {"veteran","Competitive","Veteran","Reach Veteran or higher.","rank",3,20,3,"INV_Shield_10"},
 {"duelist","Competitive","Duelist","Reach Duelist or higher.","rank",4,25,4,"INV_Shield_19"},
 {"master","Competitive","Master","Reach Master or higher.","rank",5,30,4,"INV_Shield_23"},
 {"grandmaster","Competitive","Grandmaster","Reach Grandmaster.","rank",6,50,5,"INV_Crown_01"},
 {"rated","Competitive","Competitive Spirit","Win 100 rated duels.","rated",100,30,4,"INV_Sword_39"},
 {"meet","Rivalries","Meet Your Match","Complete duels against 10 unique opponents.","rivals",10,5,1,"INV_Misc_GroupLooking"},
 {"challenger","Rivalries","Challenger of Many","Complete duels against 50 unique opponents.","rivals",50,15,3,"INV_Misc_Horn_01"},
 {"fearless","Rivalries","Fearless","Complete duels against 100 unique opponents.","rivals",100,25,4,"Ability_Warrior_IntimidatingShout"},
 {"conqueror","Rivalries","Conqueror","Defeat 50 unique opponents.","conquered",50,30,4,"INV_Axe_09"},
 {"giant","Rivalries","Giant Slayer","Defeat a higher-tier ranked opponent in a rated duel.","giant",1,20,4,"Ability_Warrior_Execute",nil,true},
 {"dedicated","Legacy","Dedicated","Complete 500 duels.","duels",500,20,3,"INV_Misc_Book_09"},
 {"warveteran","Legacy","Veteran of War","Complete 1,000 duels.","duels",1000,30,4,"INV_Misc_Book_11"},
 {"addict","Legacy","Duel Addict","Complete 2,500 duels.","duels",2500,50,5,"INV_Misc_Book_17"},
 {"eternal","Legacy","Eternal Challenger","Complete 5,000 duels.","duels",5000,75,5,"INV_Misc_PocketWatch_01"},
 {"legend","Legacy","Living Legend","Reach Grandmaster in 3 completed seasons.","seasons",3,100,5,"INV_Misc_Gem_Diamond_02"},
}
local tournamentCatalog={
 {"tourbegin","Tournaments","The First Challenge","Complete your first tournament.","tourPlayed",1,5,1,"INV_Sword_04"},
 {"tourfinal","Tournaments","One Step Away","Reach your first tournament final.","tourFinal",1,10,2,"INV_Misc_Trophy_01"},
 {"tourwin","Tournaments","Crowned Champion","Win your first tournament.","tourWon",1,20,3,"INV_Crown_01"},
 {"tourreign","Tournaments","Reigning Champion","Win 5 tournaments.","tourWon",5,30,4,"INV_Crown_01"},
 {"toursweep","Tournaments","Flawless Champion","Win a tournament without losing a game or winning by forfeit.","tourSweep",1,25,4,"INV_Shield_05"},
 {"tourarena","Tournaments","Arena Master","Win a tournament with at least 32 checked-in players.","tourLarge",1,40,5,"INV_Sword_48"},
 {"tourhost","Tournaments","The Organizer","Successfully host a completed tournament.","tourHosted",1,10,2,"INV_Misc_Book_09"},
 {"tourveteran","Tournaments","Tournament Veteran","Complete 25 tournaments.","tourPlayed",25,30,4,"INV_Helmet_06"},
 {"tourlegend","Tournaments","Tournament Legend","Win 25 tournaments.","tourWon",25,75,5,"INV_Crown_01"},
}
for _,d in ipairs(tournamentCatalog) do catalog[#catalog+1]=d end
local expansion={
 {"rematch","Dueling","Back for More","Win immediately after losing to the same opponent.","rematch",1,10,2,"INV_Sword_04"},
 {"familiar","Rivalries","Familiar Face","Complete 10 duels against the same opponent.","rivalCount",10,10,2,"INV_Helmet_03"},
 {"eternalrival","Rivalries","Eternal Rival","Complete 50 duels against the same opponent.","rivalCount",50,25,4,"INV_Sword_39"},
 {"regular","Legacy","Regular Challenger","Complete a duel on 25 different UTC dates.","duelDays",25,15,2,"INV_Misc_PocketWatch_01"},
 {"wayoflife","Legacy","A Way of Life","Complete a duel on 100 different UTC dates.","duelDays",100,50,5,"INV_Misc_Book_11"},
 {"nemesis","Rivalries","Nemesis","Defeat the same opponent 10 times.","rivalWins",10,20,3,"INV_Helmet_06"},
 {"revenge","Rivalries","Unfinished Business","Defeat a rival after losing your previous 5 duels against them.","revenge",1,25,4,"INV_Sword_04"},
 {"rankedrivals","Competitive","No Easy Victories","Win rated duels against 25 unique opponents.","ratedRivals",25,30,4,"INV_Shield_23"},
 {"tourcontender","Tournaments","Consistent Contender","Reach 5 tournament finals.","tourFinal",5,25,4,"INV_Misc_Trophy_01"},
 {"tourbacktoback","Tournaments","Back-to-Back Champion","Win 2 consecutive tournaments you participate in.","tourStreak",2,35,4,"INV_Crown_01"},
 {"tourstalwart","Tournaments","Tournament Stalwart","Complete 10 tournaments.","tourPlayed",10,20,3,"INV_Misc_Trophy_01"},
 {"tourceremonies","Tournaments","Master of Ceremonies","Successfully host 5 completed tournaments.","tourHosted",5,25,4,"INV_Misc_Book_09"},
 {"tourgrandhost","Tournaments","Grand Host","Successfully host 10 completed tournaments.","tourHosted",10,40,5,"INV_Crown_01"},
 {"tourbigstage","Tournaments","Big Stage","Reach the final with at least 16 checked-in players.","tourBigFinal",1,25,4,"INV_Misc_Trophy_01"},
 {"tourpath","Tournaments","Champion's Path","Win 10 tournaments.","tourWon",10,50,5,"INV_Crown_01"},
 {"collector","Legacy","The Collector","Earn 20 other achievements, excluding tournament test awards.","collection",20,25,4,"INV_Misc_Book_09"},
}
for _,d in ipairs(expansion) do catalog[#catalog+1]=d end
-- A milestone index keeps large history replays proportional to the metrics
-- that actually change, rather than scanning the entire catalogue per duel.
local milestones={}
for _,d in ipairs(catalog) do
    local key=d[5];milestones[key]=milestones[key] or {}
    milestones[key][#milestones[key]+1]=d
end
local ranks={Unranked=0,Aspirant=1,Contender=2,Veteran=3,Duelist=4,Master=5,Grandmaster=6}
local function Tier(v)return ranks[v] or 0 end
local function Date(v)return type(v)=="number" and v>=1 and v<=4102444800 and v==math.floor(v) and v or nil end
function A.Evaluate(data,tournamentRows,tournamentScope)
    assert(type(data)=="table" and (data.scope=="LOCAL" or data.scope=="SIMULATED"))
    local metrics={duels=0,wins=0,streak=0,rivals=0,conquered=0,rated=0,rank=0,giant=0,seasons=0,tourPlayed=0,tourFinal=0,tourWon=0,tourSweep=0,tourLarge=0,tourHosted=0,rematch=0,rivalCount=0,rivalWins=0,duelDays=0,revenge=0,ratedRivals=0,tourStreak=0,tourBigFinal=0,collection=0}
    local dates,seen,opponents,defeated={},{},{},{}
    local function Advance(key,value,time)
        if value<=metrics[key] then return end
        for _,d in ipairs(milestones[key] or {}) do
            if metrics[key]<d[6] and value>=d[6] then dates[d[1]]=Date(time) end
        end
        metrics[key]=value
    end
    local streak=0
    local priorPeer,priorOutcome
    local rivals,days={},{}
    -- The preview adapter returns newest first. Only canonical standard
    -- knockout observations count; unknowns/retreats break a streak.
    for i=#(data.matches or {}),1,-1 do
        local r=data.matches[i]
        if type(r.id)=="string" and not seen[r.id] then
            seen[r.id]=true
            if r.kind=="standard" then
                if r.outcome=="won" or r.outcome=="lost" then
                    Advance("duels",metrics.duels+1,r.time)
                    local time=Date(r.time)
                    if time then
                        local day=math.floor(time/86400)
                        if not days[day] then days[day]=true;Advance("duelDays",metrics.duelDays+1,time) end
                    end
                    local peer=type(r.peer)=="string" and r.peer~="" and r.peer or nil
                    if peer then
                        local rival=rivals[peer] or {count=0,wins=0,losses=0};rivals[peer]=rival
                        rival.count=rival.count+1;Advance("rivalCount",rival.count,r.time)
                        if r.outcome=="won" then
                            if priorPeer==peer and priorOutcome=="lost" then Advance("rematch",1,r.time) end
                            if rival.losses>=5 then Advance("revenge",1,r.time) end
                            rival.losses=0;rival.wins=rival.wins+1;Advance("rivalWins",rival.wins,r.time)
                        else rival.losses=rival.losses+1 end
                    end
                    priorPeer,priorOutcome=peer,r.outcome
                    if r.peer and not opponents[r.peer] then opponents[r.peer]=true;Advance("rivals",metrics.rivals+1,r.time) end
                    if r.outcome=="won" then
                        Advance("wins",metrics.wins+1,r.time)
                        streak=streak+1;Advance("streak",streak,r.time)
                        if r.peer and not defeated[r.peer] then defeated[r.peer]=true;Advance("conquered",metrics.conquered+1,r.time) end
                    else streak=0 end
                else
                    streak=0;priorPeer,priorOutcome=nil,nil
                    if type(r.peer)=="string" and rivals[r.peer] then rivals[r.peer].losses=0 end
                end
            elseif r.kind=="unclassified" then
                streak=0;priorPeer,priorOutcome=nil,nil
                if type(r.peer)=="string" and rivals[r.peer] then rivals[r.peer].losses=0 end
            else priorPeer,priorOutcome=nil,nil end
        end
    end
    local replay=data.achievementReplay
    local competitive=replay and replay.client==data.client and
        ((data.scope=="SIMULATED" and replay.scope=="SIMULATED") or
         (data.scope=="LOCAL" and replay.scope=="PEER" and not data.recordingDisabled))
    if competitive then
        local checked,ratedOpponents={},{}
        for _,r in ipairs(replay.changes or {}) do
            if r.weight>0 and not checked[r.id] then
                checked[r.id]=true
                if r.winner==data.me then
                    Advance("rated",metrics.rated+1,r.time)
                    if type(r.loser)=="string" and r.loser~=data.me and not ratedOpponents[r.loser] then
                        ratedOpponents[r.loser]=true;Advance("ratedRivals",metrics.ratedRivals+1,r.time)
                    end
                    if Tier(r.winnerRankBefore)>0 and Tier(r.loserRankBefore)>Tier(r.winnerRankBefore) then Advance("giant",1,r.time) end
                    Advance("rank",Tier(r.winnerRankAfter),r.time)
                elseif r.loser==data.me then Advance("rank",Tier(r.loserRankAfter),r.time) end
            end
        end
        for season=1,(replay.season or 1)-1 do
            local archive=replay.history and replay.history[season]
            local player=archive and archive.players[data.me]
            if player and player.peakRank and player.peakRank.name=="Grandmaster" then
                Advance("seasons",metrics.seasons+1,data.epoch and data.epoch+season*ns.SeasonRules.DURATION)
            end
        end
    end
    -- Public tournament awards stay gated: only explicitly marked, read-only
    -- rehearsal/private archive projections can exercise these milestones today.
    local tournamentTest=tournamentScope=="SIMULATED" or tournamentScope=="PRIVATE_TEST"
    if tournamentTest and type(tournamentRows)=="table" then
        local ordered={}
        for _,r in ipairs(tournamentRows) do
            if type(r)=="table" and r.scope==tournamentScope and type(r.id)=="string" and Date(r.finishedAt) then ordered[#ordered+1]=r end
        end
        table.sort(ordered,function(a,b)if a.finishedAt==b.finishedAt then return a.id<b.id end;return a.finishedAt<b.finishedAt end)
        local counted={}
        local tournamentStreak,priorFinish=0,nil
        for _,r in ipairs(ordered) do
            if not counted[r.id] then
                counted[r.id]=true
                if r.hosted==true then Advance("tourHosted",metrics.tourHosted+1,r.finishedAt) end
                if r.played==true then
                    Advance("tourPlayed",metrics.tourPlayed+1,r.finishedAt)
                    if r.placement==1 or r.placement==2 then
                        Advance("tourFinal",metrics.tourFinal+1,r.finishedAt)
                        if type(r.count)=="number" and r.count>=16 then Advance("tourBigFinal",1,r.finishedAt) end
                    end
                    -- A same-second or missing ordering cannot establish a consecutive win.
                    if priorFinish==r.finishedAt then tournamentStreak=0 end
                    priorFinish=r.finishedAt
                    if r.placement==1 then
                        tournamentStreak=tournamentStreak+1;Advance("tourStreak",tournamentStreak,r.finishedAt)
                        Advance("tourWon",metrics.tourWon+1,r.finishedAt)
                        if type(r.count)=="number" and r.count>=32 then Advance("tourLarge",metrics.tourLarge+1,r.finishedAt) end
                        local clean=type(r.matches)=="table" and #r.matches>0 and r.wins==#r.matches and r.losses==0
                        for _,m in ipairs(r.matches or {}) do
                            local won,lost
                            if type(m.score)=="string" then won,lost=m.score:match("^(%d+) %- (%d+)$") end
                            if not m.won or m.forfeit or not won or tonumber(won)<1 or tonumber(lost)~=0 then clean=false end
                        end
                        if clean then Advance("tourSweep",1,r.finishedAt) end
                    else tournamentStreak=0 end
                end
            end
        end
    end
    local out={scope=data.scope,tournamentTest=tournamentTest,tournamentScope=tournamentScope,rows={},points=0,earned=0,total=#catalog,categories={},recordingDisabled=data.recordingDisabled,
        storageReason=data.storageReason,competitiveAvailable=not not competitive}
    for _,cat in ipairs(A.Categories) do out.categories[cat]={earned=0,total=0} end
    local function Unavailable(d)
        local competitiveOnly=d[5]=="rank" or d[5]=="rated" or d[5]=="giant" or d[5]=="seasons" or d[5]=="ratedRivals"
        if d[2]=="Tournaments" then return not tournamentTest end
        return data.storageReason~=nil or (competitiveOnly and not competitive) or (data.scope=="LOCAL" and data.recordingDisabled)
    end
    -- The collection award is derived from other eligible non-test awards,
    -- never from itself. Unknown dates do not fabricate a collection date.
    local collectionDates,collectionCount,unknownDate={},0,false
    for _,d in ipairs(catalog) do
        if d[5]~="collection" and d[2]~="Tournaments" and not Unavailable(d) and metrics[d[5]]>=d[6] then
            collectionCount=collectionCount+1
            if dates[d[1]] then collectionDates[#collectionDates+1]=dates[d[1]] else unknownDate=true end
        end
    end
    table.sort(collectionDates)
    Advance("collection",collectionCount,not unknownDate and collectionDates[20] or nil)
    for _,d in ipairs(catalog) do
        local tournament=d[2]=="Tournaments"
        local unavailable=Unavailable(d)
        local progress=math.min(d[6],metrics[d[5]])
        local earned=not unavailable and progress>=d[6]
        local hidden=d[11] and not earned
        local row={id=d[1],category=d[2],title=hidden and "Hidden achievement" or d[3],
            description=hidden and "Discover this accomplishment through dueling." or d[4],
            progress=hidden and 0 or progress,target=hidden and 1 or d[6],points=d[7],rarity=d[8],
            icon=hidden and "INV_Misc_QuestionMark" or d[9],art=not hidden and d[10] or nil,
            earned=earned,earnedAt=earned and dates[d[1]] or nil,unavailable=unavailable,hidden=not not hidden,
            testOnly=tournament and tournamentTest or nil}
        out.rows[#out.rows+1]=row
        local c=out.categories[row.category];c.total=c.total+1
        if earned then
            c.earned=c.earned+1
            if not row.testOnly then out.earned=out.earned+1;out.points=out.points+row.points end
        end
    end
    return out
end

-- The same evaluator used by the page; no writes or notification calls.
function A.RunTournamentSelfTest()
    local data={scope="LOCAL",recordingDisabled=true}
    local function Row(model,id)
        for _,r in ipairs(model.rows) do if r.id==id then return r end end
    end
    for _,scope in ipairs({"SIMULATED","PRIVATE_TEST"}) do
        local cup={id="fixture",scope=scope,played=true,placement=1,finishedAt=1700000000,count=32,
            wins=2,losses=0,matches={{won=true,score="2 - 0"},{won=true,score="2 - 0"}}}
        local host={id="host",scope=scope,hosted=true,finishedAt=1700000001}
        local m=A.Evaluate(data,{cup,cup,host},scope)
        assert(m.total==55 and m.points==0 and m.earned==0 and m.categories.Tournaments.earned==7)
        assert(Row(m,"tourbegin").earned and Row(m,"tourfinal").earned and Row(m,"tourwin").earned
            and Row(m,"toursweep").earned and Row(m,"tourarena").earned and Row(m,"tourhost").earned)
        assert(Row(m,"tourreign").progress==1 and Row(m,"tourveteran").progress==1)
        cup.matches[1].forfeit=true
        assert(not Row(A.Evaluate(data,{cup},scope),"toursweep").earned)
        cup.matches[1].forfeit=nil;cup.matches[1].score="2 - 1"
        assert(not Row(A.Evaluate(data,{cup},scope),"toursweep").earned)
        assert(Row(A.Evaluate(data,{cup},"LOCAL"),"tourwin").unavailable)
        assert(not Row(A.Evaluate(data,{cup},scope=="SIMULATED" and "PRIVATE_TEST" or "SIMULATED"),"tourwin").earned)
    end
    return true
end
function A.RunExpansionSelfTest()
    local function Row(m,id) for _,r in ipairs(m.rows) do if r.id==id then return r end end end
    for _,client in ipairs({"forever","retail"}) do
        local rows={}
        local function Add(peer,outcome,time,kind)
            table.insert(rows,1,{id="test-"..(#rows+1),kind=kind or "standard",peer=peer,outcome=outcome,time=time})
        end
        local day=1700000000
        for i=1,5 do Add("rival","lost",day+i) end
        Add("rival","won",day+6)
        for i=1,44 do Add("rival","won",day+i*86400) end
        local d={scope="SIMULATED",client=client,matches=rows}
        local m=A.Evaluate(d)
        assert(m.total==55 and Row(m,"rematch").earned and Row(m,"revenge").earned)
        assert(Row(m,"familiar").earned and Row(m,"eternalrival").earned and Row(m,"nemesis").earned)
        assert(Row(m,"regular").earned and not Row(m,"wayoflife").earned and Row(m,"wayoflife").progress==45)
        table.insert(rows,1,rows[1]);assert(A.Evaluate(d).points==m.points)
        local bad=A.Evaluate({scope="SIMULATED",matches={{id="b",kind="standard",peer="r",outcome="won"},{id="x",kind="standard",peer="r",outcome="unknown"},{id="a",kind="standard",peer="r",outcome="lost"}}})
        assert(not Row(bad,"rematch").earned and Row(bad,"regular").progress==0)
        local changes={}
        for i=1,25 do changes[i]={id="rated-"..i,weight=1,winner="me",loser="r"..i,time=day+i} end
        changes[26]=changes[1]
        local c={scope="SIMULATED",client=client,me="me",achievementReplay={client=client,scope="SIMULATED",changes=changes}}
        assert(Row(A.Evaluate(c),"rankedrivals").earned)
        c.achievementReplay.scope="PEER";assert(Row(A.Evaluate(c),"rankedrivals").unavailable)
        local tour={}
        for i=1,10 do tour[i]={id="cup"..i,scope="SIMULATED",played=true,placement=1,count=16,finishedAt=day+i,hosted=true,matches={}} end
        local t=A.Evaluate({scope="LOCAL",recordingDisabled=true},tour,"SIMULATED")
        for _,id in ipairs({"tourcontender","tourbacktoback","tourstalwart","tourceremonies","tourgrandhost","tourbigstage","tourpath"}) do assert(Row(t,id).earned,id) end
        assert(t.points==0 and Row(t,"collector").progress==0)
        tour[2].placement=4
        local interrupted=A.Evaluate({scope="LOCAL"},{tour[1],tour[2],tour[3]},"SIMULATED")
        assert(not Row(interrupted,"tourbacktoback").earned)
        -- The same completed event cannot count twice toward a streak.
        local dupe=A.Evaluate({scope="LOCAL"},{tour[1],tour[1]},"SIMULATED")
        assert(not Row(dupe,"tourbacktoback").earned)
        assert(Row(A.Evaluate({scope="LOCAL"},tour,"LOCAL"),"tourpath").unavailable)
        assert(Row(A.Evaluate({scope="LOCAL",recordingDisabled=true,matches=rows}),"rematch").unavailable)
        local collection={}
        for i=1,500 do
            table.insert(collection,1,{id="collection-"..i,kind="standard",peer=i<=50 and "old-rival" or "peer-"..i,outcome="won",time=day+i*86400})
        end
        local earned=A.Evaluate({scope="SIMULATED",client=client,matches=collection})
        assert(Row(earned,"collector").earned and Row(earned,"collector").earnedAt)
        local qualifying=0
        for _,r in ipairs(earned.rows) do
            if r.earned and r.id~="collector" and not r.testOnly then qualifying=qualifying+1 end
        end
        assert(qualifying>=20 and earned.earned==qualifying+1)
    end
    return true
end
if ns.Diagnostics and ns.Diagnostics.Register then
    ns.Diagnostics.Register("Achievement expansion / isolated progression QA","deep",function()
        local ok,err=pcall(A.RunExpansionSelfTest)
        return ok and "PASS" or "FAIL",ok and "Rivalry, UTC dates, ranked opponents, tournament streaks, scope and duplicate isolation." or tostring(err)
    end)
    ns.Diagnostics.Register("Tournament achievements / isolated progression QA","deep",function()
        local ok,err=pcall(A.RunTournamentSelfTest)
        return ok and "PASS" or "FAIL",ok and "Two test scopes; duplicate, clean sweep, point and public gate isolation." or tostring(err)
    end)
end

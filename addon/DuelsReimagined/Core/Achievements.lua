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
local ranks={Unranked=0,Aspirant=1,Contender=2,Veteran=3,Duelist=4,Master=5,Grandmaster=6}
local function Tier(v)return ranks[v] or 0 end
local function Date(v)return type(v)=="number" and v>=1 and v<=4102444800 and v==math.floor(v) and v or nil end
function A.Evaluate(data,tournamentRows,tournamentScope)
    assert(type(data)=="table" and (data.scope=="LOCAL" or data.scope=="SIMULATED"))
    local metrics={duels=0,wins=0,streak=0,rivals=0,conquered=0,rated=0,rank=0,giant=0,seasons=0,tourPlayed=0,tourFinal=0,tourWon=0,tourSweep=0,tourLarge=0,tourHosted=0}
    local dates,seen,opponents,defeated={},{},{},{}
    local function Advance(key,value,time)
        if value<=metrics[key] then return end
        for _,d in ipairs(catalog) do
            if d[5]==key and metrics[key]<d[6] and value>=d[6] then dates[d[1]]=Date(time) end
        end
        metrics[key]=value
    end
    local streak=0
    -- The preview adapter returns newest first. Only canonical standard
    -- knockout observations count; unknowns/retreats break a streak.
    for i=#(data.matches or {}),1,-1 do
        local r=data.matches[i]
        if type(r.id)=="string" and not seen[r.id] then
            seen[r.id]=true
            if r.kind=="standard" then
                if r.outcome=="won" or r.outcome=="lost" then
                    Advance("duels",metrics.duels+1,r.time)
                    if r.peer and not opponents[r.peer] then opponents[r.peer]=true;Advance("rivals",metrics.rivals+1,r.time) end
                    if r.outcome=="won" then
                        Advance("wins",metrics.wins+1,r.time)
                        streak=streak+1;Advance("streak",streak,r.time)
                        if r.peer and not defeated[r.peer] then defeated[r.peer]=true;Advance("conquered",metrics.conquered+1,r.time) end
                    else streak=0 end
                else streak=0 end
            elseif r.kind=="unclassified" then streak=0 end
        end
    end
    local replay=data.achievementReplay
    local competitive=replay and replay.client==data.client and
        ((data.scope=="SIMULATED" and replay.scope=="SIMULATED") or
         (data.scope=="LOCAL" and replay.scope=="PEER" and not data.recordingDisabled))
    if competitive then
        local checked={}
        for _,r in ipairs(replay.changes or {}) do
            if r.weight>0 and not checked[r.id] then
                checked[r.id]=true
                if r.winner==data.me then
                    Advance("rated",metrics.rated+1,r.time)
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
        for _,r in ipairs(ordered) do
            if not counted[r.id] then
                counted[r.id]=true
                if r.hosted==true then Advance("tourHosted",metrics.tourHosted+1,r.finishedAt) end
                if r.played==true then
                    Advance("tourPlayed",metrics.tourPlayed+1,r.finishedAt)
                    if r.placement==1 or r.placement==2 then Advance("tourFinal",metrics.tourFinal+1,r.finishedAt) end
                    if r.placement==1 then
                        Advance("tourWon",metrics.tourWon+1,r.finishedAt)
                        if type(r.count)=="number" and r.count>=32 then Advance("tourLarge",metrics.tourLarge+1,r.finishedAt) end
                        local clean=type(r.matches)=="table" and #r.matches>0 and r.wins==#r.matches and r.losses==0
                        for _,m in ipairs(r.matches or {}) do
                            local won,lost
                            if type(m.score)=="string" then won,lost=m.score:match("^(%d+) %- (%d+)$") end
                            if not m.won or m.forfeit or not won or tonumber(won)<1 or tonumber(lost)~=0 then clean=false end
                        end
                        if clean then Advance("tourSweep",1,r.finishedAt) end
                    end
                end
            end
        end
    end
    local out={scope=data.scope,tournamentTest=tournamentTest,tournamentScope=tournamentScope,rows={},points=0,earned=0,total=#catalog,categories={},recordingDisabled=data.recordingDisabled,
        storageReason=data.storageReason,competitiveAvailable=not not competitive}
    for _,cat in ipairs(A.Categories) do out.categories[cat]={earned=0,total=0} end
    for _,d in ipairs(catalog) do
        local competitiveOnly=d[5]=="rank" or d[5]=="rated" or d[5]=="giant" or d[5]=="seasons"
        local tournament=d[2]=="Tournaments"
        local unavailable
        if tournament then unavailable=not tournamentTest else
            unavailable=data.storageReason~=nil or (competitiveOnly and not competitive) or (data.scope=="LOCAL" and data.recordingDisabled)
        end
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
        assert(m.total==39 and m.points==0 and m.earned==0 and m.categories.Tournaments.earned==6)
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
if ns.Diagnostics and ns.Diagnostics.Register then
    ns.Diagnostics.Register("Tournament achievements / isolated progression QA","deep",function()
        local ok,err=pcall(A.RunTournamentSelfTest)
        return ok and "PASS" or "FAIL",ok and "Two test scopes; duplicate, clean sweep, point and public gate isolation." or tostring(err)
    end)
end

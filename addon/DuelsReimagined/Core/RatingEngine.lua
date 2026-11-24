local _,ns=...
-- Experimental deterministic Elo replay. No live rating or persistence.
local P={}
ns.RatingEngine=P
local START,PLACEMENTS,K_NEW,K_BASE=1500,10,40,24
local RULE="elo-trial-1"
-- Win probability in basis points at positive gaps 0,50,...,800.
-- Frozen integer lookup + interpolation avoids runtime exponent/rounding drift.
local EXPECT={5000,5715,6401,7034,7597,8083,8490,8823,9091,9302,9468,9595,9693,9768,9825,9868,9901}
local function Expected(a,b)
    local gap=a-b;local d=math.min(math.abs(gap),800)
    local i=math.floor(d/50)+1;local rem=d%50
    local p=EXPECT[i]
    if rem>0 then p=p+math.floor(((EXPECT[i+1]-p)*rem+25)/50) end
    return gap<0 and 10000-p or p
end
local function K(n,placements) return n<(placements or PLACEMENTS) and K_NEW or K_BASE end
local function Step(w,l,weight,protected,placements)
    weight=weight or 4
    local p=Expected(w.rating,l.rating)
    if weight==0 then return 0,0,p end
    local wg=protected and w.credit/4 or w.games
    local lg=protected and l.credit/4 or l.games
    local wk,lk=K(wg,placements),K(lg,placements)
    local gain=math.floor((wk*(10000-p)*weight+20000)/40000)
    local loss=math.floor((lk*(10000-p)*weight+20000)/40000)
    w.credit=w.credit+weight;l.credit=l.credit+weight
    w.rating=w.rating+gain;l.rating=l.rating-loss
    w.games=w.games+1;l.games=l.games+1;w.wins=w.wins+1;l.losses=l.losses+1
    return gain,loss,p,wk,lk
end
local function Player() return {rating=START,games=0,wins=0,losses=0,credit=0} end
function P.GetSnapshot() return {scope="LOCAL",state="disabled",rankEligible=false,rule=RULE} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
-- Timestamp map is an explicit simulation fixture, NOT detector uptime or a
-- trusted network timestamp. Production records still need agreed chronology.
local function Replay(client,saved,chronology,rule,options,scope)
    rule=rule or RULE -- retain the original trial as a reproducible baseline
    local policy=ns.SeasonRules
    local balanced=policy and rule==policy.BALANCED_ID
    local seasonal=policy and (rule==policy.ID or balanced)
    local schedule
    if seasonal then
        if type(options)~="table" then return nil,"invalid_schedule" end
        schedule=policy.Schedule(options.epoch,options.asOf)
        if not schedule then return nil,"invalid_schedule" end
    end
    local protected=rule==ns.CompetitiveRules.ID or seasonal
    if rule~=RULE and not protected then return nil,"unknown_rule" end
    local pairWeight=protected and ns.CompetitiveRules.NewReplay() or nil
    if type(saved)~="table" or type(chronology)~="table" then return nil,"missing_input" end
    local open=scope=="PEER" and ns.MatchLedger.OpenPeer or ns.MatchLedger.OpenSimulated
    local ledger,why=open(client,saved)
    if not ledger then return nil,why end
    local snap=ledger.Snapshot();local known,ordered={},{}
    for _,r in ipairs(snap.disputed) do known[r.id]=true end
    for _,r in ipairs(snap.matched) do known[r.id]=true end
    for id,t in pairs(chronology) do
        if not known[id] or type(t)~="number" or t<1 or t>9007199254740991 or t~=math.floor(t) then return nil,"invalid_chronology" end
    end
    for _,r in ipairs(snap.matched) do
        local t=chronology[r.id];if not t then return nil,"missing_chronology" end
        if not seasonal or policy.SeasonOf(schedule,t) then ordered[#ordered+1]={time=t,record=r} end
    end
    table.sort(ordered,function(a,b) if a.time~=b.time then return a.time<b.time end;return a.record.id<b.record.id end)
    local players,changes={},{}
    local history,carry={},{}
    local season=1
    local function Visible(skill) return balanced and policy.DisplayRating(skill) or skill end
    local function FinishPlayer(p)
        if balanced then p.skillRating=p.rating;p.rating=Visible(p.rating) end
    end
    local function Archive()
        if next(players)==nil then return end
        local rows={}
        for id,p in pairs(players) do
            if p.credit>0 then
                carry[id]={rating=p.rating,season=season}
                FinishPlayer(p)
                p.rank=policy.Rank(p.rating,p.credit,p.rivalCount)
                rows[id]=p
            end
        end
        if next(rows) then history[season]={players=rows} end
    end
    local function NewPlayer(id)
        local p=Player()
        if seasonal then
            p.rating=policy.START
            if carry[id] then
                p.rating=carry[id].rating
                for _=carry[id].season+1,season do p.rating=balanced and policy.ResetSkill(p.rating) or policy.Reset(p.rating) end
            end
            p.rivals={};p.rivalCount=0;p.peakRating=nil;p.peakRank=nil
        end
        return p
    end
    local function UpdatePlayer(p,peer)
        if not p.rivals[peer] then p.rivals[peer]=true;p.rivalCount=p.rivalCount+1 end
        local rating=Visible(p.rating)
        p.peakRating=math.max(p.peakRating or rating,rating)
        local rank=policy.Rank(rating,p.credit,p.rivalCount)
        if not rank.provisional and (not p.peakRankRating or rating>p.peakRankRating) then p.peakRankRating=rating;p.peakRank=rank end
    end
    local rated,restricted=0,0
    for _,item in ipairs(ordered) do
        local r=item.record
        if seasonal then
            local n=policy.SeasonOf(schedule,item.time)
            if n~=season then Archive();players={};season=n end
        end
        local w,l=players[r.winner],players[r.loser]
        if not w then w=NewPlayer(r.winner);players[r.winner]=w end
        if not l then l=NewPlayer(r.loser);players[r.loser]=l end
        local beforeW,beforeL=Visible(w.rating),Visible(l.rating)
        local beforeWRank,beforeLRank
        if seasonal then
            beforeWRank=policy.Rank(beforeW,w.credit,w.rivalCount or 0).name
            beforeLRank=policy.Rank(beforeL,l.credit,l.rivalCount or 0).name
        end
        local weight,reason=4,"full"
        if pairWeight then weight,reason=pairWeight(r,item.time) end
        local gain,loss,p,wk,lk=Step(w,l,weight,protected,seasonal and policy.PLACEMENT_CREDIT/4 or nil)
        if seasonal and weight>0 then UpdatePlayer(w,r.loser);UpdatePlayer(l,r.winner) end
        local afterW,afterL=Visible(w.rating),Visible(l.rating)
        if balanced then gain,loss=afterW-beforeW,beforeL-afterL end
        if weight>0 then rated=rated+1 else restricted=restricted+1 end
        changes[#changes+1]={id=r.id,time=item.time,winner=r.winner,loser=r.loser,
            winnerBefore=beforeW,loserBefore=beforeL,winnerAfter=afterW,loserAfter=afterL,
            gain=gain,loss=loss,expectedWin=p,weight=weight,reason=reason}
        if seasonal then
            local row=changes[#changes];row.season=season;row.winnerK=wk;row.loserK=lk
            row.winnerRankBefore=beforeWRank;row.loserRankBefore=beforeLRank
            row.winnerRankAfter=policy.Rank(afterW,w.credit,w.rivalCount or 0).name
            row.loserRankAfter=policy.Rank(afterL,l.credit,l.rivalCount or 0).name
        end
    end
    if seasonal and season~=schedule.season then Archive();players={};season=schedule.season end
    local standings={}
    for id,p in pairs(players) do
        FinishPlayer(p)
        if not seasonal or p.credit>0 then
            local row={id=id,rating=p.rating,games=p.games,wins=p.wins,losses=p.losses,credit=p.credit,provisional=p.credit<PLACEMENTS*4}
            if seasonal then p.rank=policy.Rank(p.rating,p.credit,p.rivalCount);row.rank=p.rank;row.provisional=p.rank.provisional;row.rivalCount=p.rivalCount end
            standings[#standings+1]=row
        end
    end
    table.sort(standings,function(a,b) if a.rating~=b.rating then return a.rating>b.rating end;return a.id<b.id end)
    local result={scope=scope,client=client,rule=rule,rankEligible=false,players=players,standings=standings,
        changes=changes,matched=#ordered,disputed=#snap.disputed,rated=rated,restricted=restricted}
    if seasonal then result.season=season;result.history=history;result.schedule=schedule;result.completeness="unknown" end
    return result
end
function P.ReplaySimulated(client,saved,chronology,rule,options)
    return Replay(client,saved,chronology,rule,options,"SIMULATED")
end
function P.ReplayPeer(client,saved,chronology,rule,options)
    return Replay(client,saved,chronology,rule,options,"PEER")
end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b,c="Player-1-AAA","Player-2-BBB","Player-3-CCC"
    local function Equal(x,y)
        if type(x)~=type(y) then return false end
        if type(x)~="table" then return x==y end
        for k,v in pairs(x) do if not Equal(v,y[k]) then return false end end
        for k in pairs(y) do if x[k]==nil then return false end end
        return true
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Record(n,w,l)
            local x,y=w,l;if y<x then x,y=y,x end
            local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,
                player1=x,player2=y,winner=w,loser=l,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),
                statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
        end
        local function Fixture()
            local l=assert(ns.MatchLedger.OpenSimulated(client));local t={}
            local function Add(r,at) assert(l.Insert(r));t[r.id]=at end
            local function Replay() return assert(P.ReplaySimulated(client,l.Save(),t)) end
            return l,t,Add,Replay
        end
        Case(client.." empty ledger no fabricated players",function()
            local _,_,_,replay=Fixture();local s=replay();assert(#s.standings==0 and s.matched==0 and not s.rankEligible)
        end)
        Case(client.." equal rating win and loss",function()
            local _,_,add,replay=Fixture();add(Record(1,a,b),10);local s=replay()
            assert(s.players[a].rating==1520 and s.players[b].rating==1480 and s.changes[1].expectedWin==5000)
        end)
        Case(client.." stronger opponent gives larger reward",function()
            local w,l=Player(),Player();w.rating=1300;l.rating=1700
            local g,d,p=Step(w,l);assert(g==36 and d==36 and p==909)
            w,l=Player(),Player();w.rating=1700;l.rating=1300;g,d=Step(w,l);assert(g==4 and d==4)
        end)
        Case(client.." placement adjustment ends after ten",function()
            local w,l=Player(),Player();w.games=9;l.games=10;local g,d=Step(w,l);assert(g==20 and d==12)
            assert(K(w.games)==24 and K(l.games)==24)
            local _,_,add,replay=Fixture();for i=1,10 do add(Record(i,a,b),i) end
            local s=replay();assert(s.players[a].games==10 and not s.standings[1].provisional)
        end)
        Case(client.." chronology and tie-break independent of insertion",function()
            local _,_,x,rx=Fixture();local _,_,y,ry=Fixture();local r1,r2,r3=Record(1,a,b),Record(2,b,c),Record(3,c,a)
            x(r1,20);x(r2,10);x(r3,20);y(r3,20);y(r2,10);y(r1,20)
            local s=rx();assert(Equal(s,ry()) and s.changes[1].id==r2.id and s.changes[2].id<s.changes[3].id)
        end)
        Case(client.." delayed earlier match triggers full replay",function()
            local _,_,add,replay=Fixture();local early,late=Record(1,a,b),Record(2,b,c)
            add(late,20);local before=replay();add(early,10);local after=replay()
            assert(after.changes[1].id==early.id and before.changes[1].winnerBefore~=after.changes[2].winnerBefore)
            local _,_,add2,replay2=Fixture();add2(early,10);add2(late,20);assert(Equal(after,replay2()))
        end)
        Case(client.." disputed match removed on replay",function()
            local l,_,add,replay=Fixture();local r=Record(1,a,b);add(r,10);add(Record(2,b,c),20)
            assert(l.Insert(Record(1,b,a)));local s=replay();assert(s.disputed==1 and s.matched==1 and s.players[a]==nil and s.players[b].rating==1520)
        end)
        Case(client.." missing invalid or unknown chronology rejected",function()
            local l,t,add=Fixture();local r=Record(1,a,b);add(r,10);local saved=l.Save()
            assert(not P.ReplaySimulated(client,saved,{}));t[r.id]=0;assert(not P.ReplaySimulated(client,saved,t))
            t[r.id]=1.5;assert(not P.ReplaySimulated(client,saved,t));t[r.id]=math.huge;assert(not P.ReplaySimulated(client,saved,t))
            t[r.id]=10;t.extra=20;assert(not P.ReplaySimulated(client,saved,t))
        end)
        Case(client.." duplicate ledger input cannot increase rating",function()
            local l,_,add,replay=Fixture();local r=Record(1,a,b);add(r,10);local s=replay();assert(not l.Insert(r) and Equal(s,replay()))
        end)
        Case(client.." scope client and corrupted evidence rejected",function()
            local l,t,add=Fixture();local r=Record(1,a,b);add(r,10);local saved=l.Save()
            assert(not P.ReplaySimulated(client=="forever" and "retail" or "forever",saved,t))
            saved.scope="LOCAL";assert(not P.ReplaySimulated(client,saved,t));saved.scope="SIMULATED"
            saved.entries[r.id][1].winner=b;assert(not P.ReplaySimulated(client,saved,t))
        end)
        Case(client.." replay snapshots and source independent",function()
            local l,t,add,replay=Fixture();local r=Record(1,a,b);add(r,10);local saved=l.Save();local s=assert(P.ReplaySimulated(client,saved,t))
            s.players[a].rating=999;s.changes[1].gain=0;assert(Equal(replay(),assert(P.ReplaySimulated(client,saved,t))))
        end)
        Case(client.." integer expectation symmetry and bounds",function()
            local last=0
            for d=-1000,1000 do local p=Expected(d,0);assert(p>=last and p+Expected(0,d)==10000 and p>=99 and p<=9901);last=p end
        end)
    end
    Case("live rating remains disabled",function()local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)end)
    return passed,failed
end

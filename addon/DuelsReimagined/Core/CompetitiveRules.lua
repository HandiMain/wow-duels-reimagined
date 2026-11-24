local _,ns=...
-- Trial policy only; chronology is supplied by the isolated rating replay.
local P={}
ns.CompetitiveRules=P
local DAY,WEEK=86400,604800
local WEIGHTS={4,4,4,2,2,1,1}
local BUDGET=48 -- quarters of full rating weight per trailing week and pair
P.ID="elo-trial-2"
function P.NewReplay()
    local pairsByID={}
    return function(record,time)
        local key=record.player1.."|"..record.player2
        local previous=pairsByID[key] or {}
        local keep,day,used={},0,0
        for _,e in ipairs(previous) do
            if time-e.time<WEEK then
                keep[#keep+1]=e;used=used+e.weight
                if time-e.time<DAY then day=day+1 end
            end
        end
        local daily=WEIGHTS[day+1] or 0
        local weight=math.min(daily,BUDGET-used)
        if weight>0 then keep[#keep+1]={time=time,weight=weight} end
        pairsByID[key]=keep
        local reason=weight==4 and "full" or daily==0 and "pair_day" or weight<daily and "pair_week" or "reduced"
        return weight,reason
    end
end
function P.GetSnapshot() return {scope="LOCAL",state="disabled",rankEligible=false,rule=P.ID} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b,c="Player-1-AAA","Player-2-BBB","Player-3-CCC"
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
            local function Add(n,w,loser,time)local r=Record(n,w,loser);assert(l.Insert(r));t[r.id]=time;return r end
            local function Replay(rule)return assert(ns.RatingEngine.ReplaySimulated(client,l.Save(),t,rule or P.ID))end
            return l,t,Add,Replay
        end
        Case(client.." daily weights and zero-value practice",function()
            local _,_,add,replay=Fixture();for i=1,10 do add(i,a,b,i)end
            local s=replay();local weights={4,4,4,2,2,1,1,0,0,0}
            for i,v in ipairs(weights)do assert(s.changes[i].weight==v)end
            assert(s.matched==10 and s.rated==7 and s.restricted==3 and s.players[a].credit==18 and s.players[b].credit==18)
            assert(s.changes[10].gain==0 and s.changes[10].loss==0 and s.players[a].games==7)
        end)
        Case(client.." alternating wins share one symmetric pair budget",function()
            local _,_,add,replay=Fixture();for i=1,8 do if i%2==0 then add(i,b,a,i)else add(i,a,b,i)end end
            local s=replay();assert(s.changes[8].weight==0 and s.players[a].credit==s.players[b].credit and s.players[a].rating+s.players[b].rating==3000)
        end)
        Case(client.." rolling day recovery excludes zero-value practice",function()
            local _,_,add,replay=Fixture();for i=1,7 do add(i,a,b,100)end
            add(8,a,b,DAY+99);add(9,a,b,DAY+100)
            local s=replay();assert(s.changes[8].weight==0 and s.changes[9].weight==4)
        end)
        Case(client.." weekly budget and exact expiry",function()
            local _,_,add,replay=Fixture();for i=1,4 do for j=1,3 do add((i-1)*3+j,a,b,100+(i-1)*DAY)end end
            add(13,a,b,4*DAY+100);add(14,a,b,WEEK+99);add(15,a,b,WEEK+100)
            local s=replay();assert(s.changes[13].weight==0 and s.changes[13].reason=="pair_week" and s.changes[14].weight==0 and s.changes[15].weight==4)
        end)
        Case(client.." other opponents retain full rewards",function()
            local _,_,add,replay=Fixture();for i=1,8 do add(i,a,b,i)end;add(9,a,c,9)
            local s=replay();assert(s.changes[8].weight==0 and s.changes[9].weight==4 and s.players[c].credit==4)
        end)
        Case(client.." repeated intentional losses limited relative to baseline",function()
            local _,_,add,replay=Fixture();for i=1,100 do add(i,a,b,i)end
            local s,old=replay(),replay("elo-trial-1");assert(s.players[a].rating<old.players[a].rating and s.players[b].rating>old.players[b].rating and s.players[a].credit==18)
        end)
        Case(client.." delayed dispute releases pair slot and recalculates",function()
            local l,_,add,replay=Fixture();for i=1,8 do add(i,a,b,i)end
            assert(replay().changes[8].weight==0);assert(l.Insert(Record(1,b,a)))
            local s=replay();assert(s.disputed==1 and s.changes[7].weight==1 and s.rated==7)
        end)
        Case(client.." weighted placement cannot be rushed with rematches",function()
            local _,_,add,replay=Fixture();for i=1,10 do add(i,a,b,i)end
            local s=replay();assert(s.players[a].credit==18 and s.standings[1].provisional)
            for i=11,16 do add(i,a,c,(i-10)*DAY+100)end
            s=replay();assert(s.players[a].credit==42 and not s.standings[1].provisional)
        end)
        Case(client.." deterministic recovery and invalid policy",function()
            local l,t,add,replay=Fixture();for i=1,9 do add(i,a,b,i)end
            local rev=assert(ns.MatchLedger.OpenSimulated(client));for i=9,1,-1 do assert(rev.Insert(Record(i,a,b)))end
            local s=replay();local other=assert(ns.RatingEngine.ReplaySimulated(client,rev.Save(),t,P.ID))
            for i,r in ipairs(s.changes)do assert(r.id==other.changes[i].id and r.weight==other.changes[i].weight and r.winnerAfter==other.changes[i].winnerAfter)end
            assert(not ns.RatingEngine.ReplaySimulated(client,l.Save(),t,"unknown"))
        end)
    end
    Case("live anti-farming gate remains disabled",function()local s=P.GetSnapshot();assert(s.state=="disabled" and not s.rankEligible)end)
    return passed,failed
end

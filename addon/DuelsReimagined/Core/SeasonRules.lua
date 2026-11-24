local _,ns=...
-- Versioned season policy. No calendar is activated until a release defines an epoch.
local P={ID="elo-season-1",START=1000,PLACEMENT_CREDIT=20,MIN_RIVALS=3,DURATION=84*86400}
ns.SeasonRules=P
P.BALANCED_ID="elo-season-2"
local function Int(v,lo,hi) return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
function P.Schedule(epoch,asOf)
    if not Int(epoch,1,4102444800) or not Int(asOf,epoch,4102444800) then return nil end
    local n=math.floor((asOf-epoch)/P.DURATION)+1
    if n>64 then return nil end -- development bound, not permanent history capacity
    return {epoch=epoch,asOf=asOf,season=n}
end
function P.SeasonOf(schedule,t)
    if not Int(t,schedule.epoch,schedule.asOf) then return nil end
    return math.floor((t-schedule.epoch)/P.DURATION)+1
end
function P.Reset(rating) return math.floor((P.START+rating)/2+0.5) end
-- Monotone presentation scale, not a second skill engine. Rounding is explicit.
function P.DisplayRating(skill)
    if skill>=P.START then return P.START+5*(skill-P.START) end
    local denominator=P.START+5*(P.START-skill)
    return math.max(1,math.floor((1000000+denominator/2)/denominator))
end
function P.ResetSkill(skill)
    -- Reset in visible points; invert to nearest whole skill unit (<= 2 points error).
    local target=P.Reset(P.DisplayRating(skill))
    if target>=P.START then return P.START+math.floor((target-P.START)/5+0.5) end
    return math.floor(P.START-(1000000/target-P.START)/5+0.5)
end
local names={"Contender","Veteran","Duelist","Master"}
local roman={"I","II","III","IV"}
function P.Rank(rating,credit,rivals)
    if credit<P.PLACEMENT_CREDIT or rivals<P.MIN_RIVALS then return {name="Unranked",label="Unranked",provisional=true} end
    if rating<1400 then return {name="Aspirant",label="Aspirant",provisional=false} end
    if rating>=3000 then return {name="Grandmaster",label="Grandmaster",provisional=false} end
    local i=math.floor((rating-1400)/400)+1
    local division=4-math.floor(((rating-1400)%400)/100)
    return {name=names[i],division=division,label=names[i].." "..roman[division],provisional=false}
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
    Case("all rank and division boundaries",function()
        assert(P.Rank(-10,20,3).label=="Aspirant" and P.Rank(1399,20,3).label=="Aspirant")
        for i,name in ipairs(names) do for step=0,3 do
            local low=1400+(i-1)*400+step*100;local expected=name.." "..roman[4-step]
            assert(P.Rank(low,20,3).label==expected and P.Rank(low+99,20,3).label==expected)
        end end
        assert(P.Rank(3000,20,3).label=="Grandmaster" and P.Rank(9000,20,3).label=="Grandmaster")
    end)
    Case("weighted placements and distinct rivals",function()
        assert(P.Rank(3000,19,4).provisional and P.Rank(3000,20,2).provisional and not P.Rank(1000,20,3).provisional)
    end)
    Case("season duration and exact cutoff",function()
        local s=assert(P.Schedule(100,100+P.DURATION));assert(s.season==2 and P.SeasonOf(s,100)==1 and P.SeasonOf(s,100+P.DURATION-1)==1 and P.SeasonOf(s,100+P.DURATION)==2)
        assert(not P.SeasonOf(s,99) and not P.SeasonOf(s,s.asOf+1) and not P.Schedule(100,99) and not P.Schedule(100,100+64*P.DURATION))
    end)
    Case("soft reset above and below starting rating",function() assert(P.Reset(3000)==2000 and P.Reset(800)==900 and P.Reset(1000)==1000 and P.Reset(1001)==1001) end)
    local a,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local l=assert(ns.MatchLedger.OpenSimulated(client));local t={};local n=0
            local function Add(w,v,at)
                n=n+1;local x,y=w,v;if y<x then x,y=y,x end;local s="a-"..n..":b-"..n
                local r={scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,player1=x,player2=y,winner=w,loser=v,endType="knockout",rankEligible=false,
                    statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
                assert(l.Insert(r));t[r.id]=at;return r
            end
            local function Replay(at) return assert(ns.RatingEngine.ReplaySimulated(client,l.Save(),t,P.ID,{epoch=100,asOf=at})) end
            return Add,Replay,l,t
        end
        Case(client.." starts at 1000 and no level input",function()
            local add,replay=Fixture();add(a,b,100);local s=replay(100)
            assert(s.players[a].rating==1020 and s.players[b].rating==980 and s.standings[1].rank.label=="Unranked")
        end)
        Case(client.." fifth full equivalent ends increased adjustment",function()
            local add,replay=Fixture();for i=1,3 do add(a,b,100+i)end;add(a,c,105);add(a,d,106);add(a,c,107)
            local s=replay(107);assert(s.players[a].credit==24 and s.players[a].rivalCount==3 and not s.standings[1].provisional)
            assert(s.changes[5].winnerK==40 and s.changes[6].winnerK==24)
        end)
        Case(client.." repeated opponents cannot reveal rank",function()
            local add,replay=Fixture();for i=1,5 do add(a,b,100+i)end;add(a,b,100+86400+5)
            local s=replay(100+86400+5);assert(s.players[a].credit>=20 and s.players[a].rivalCount==1 and s.standings[1].provisional)
        end)
        Case(client.." rollover archives and resets placements",function()
            local add,replay=Fixture();for i=1,3 do add(a,b,100+i)end;add(a,c,105);add(a,d,106)
            local prev=replay(106);local boundary=100+P.DURATION;add(a,b,boundary);local s=replay(boundary)
            assert(s.season==2 and s.history[1].players[a].rating==prev.players[a].rating and s.history[1].players[a].rank.label~="Unranked")
            assert(s.changes[#s.changes].winnerBefore==P.Reset(prev.players[a].rating) and s.players[a].credit==4 and s.players[a].rivalCount==1 and s.standings[1].provisional)
        end)
        Case(client.." anti farming continues across rollover",function()
            local add,replay=Fixture();local boundary=100+P.DURATION;for i=1,3 do add(a,b,boundary-i)end;add(a,b,boundary)
            local s=replay(boundary);assert(s.changes[4].weight==2 and s.players[a].credit==2)
        end)
        Case(client.." future and pre-season evidence excluded",function()
            local add,replay=Fixture();add(a,b,99);add(a,c,100);add(a,d,102);local s=replay(101)
            assert(s.matched==1 and s.players[b]==nil and s.players[d]==nil and s.season==1)
        end)
        Case(client.." empty season and inactive return deterministic",function()
            local add,replay=Fixture();add(a,b,100);local s=replay(100+P.DURATION);assert(#s.standings==0 and s.history[1].players[a].rating==1020)
            add(a,c,100+3*P.DURATION);s=replay(100+3*P.DURATION);assert(s.season==4 and s.changes[2].winnerBefore==P.Reset(P.Reset(P.Reset(1020))) and s.history[2]==nil)
        end)
        Case(client.." delayed evidence and dispute rebuild archive",function()
            local add,replay,l=Fixture();local r=add(a,b,101);add(a,c,100+P.DURATION);local before=replay(100+P.DURATION)
            local conflict={};for k,v in pairs(r)do conflict[k]=v end;conflict.winner=b;conflict.loser=a;conflict.statement1=r.statement1:gsub("|won|","|lost|");conflict.statement2=r.statement2:gsub("|lost|","|won|");assert(l.Insert(conflict))
            local after=replay(100+P.DURATION);assert(before.changes[2].winnerBefore~=after.changes[1].winnerBefore and after.history[1]==nil and after.disputed==1)
        end)
        Case(client.." invalid schedule rejected and legacy unchanged",function()
            local add,_,l,t=Fixture();add(a,b,100);assert(not ns.RatingEngine.ReplaySimulated(client,l.Save(),t,P.ID));assert(not ns.RatingEngine.ReplaySimulated(client,l.Save(),t,P.ID,{epoch=100,asOf=99}))
            local old=assert(ns.RatingEngine.ReplaySimulated(client,l.Save(),t,"elo-trial-2"));assert(old.players[a].rating==1520)
        end)
    end
    Case("live season remains disabled",function() local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible) end)
    return passed,failed
end

function P.RunBalanceSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    Case("visible rating examples and rank thresholds",function()
        assert(P.DisplayRating(1000)==1000 and P.DisplayRating(1012)==1060 and P.DisplayRating(988)==943)
        assert(P.DisplayRating(1020)==1100 and P.DisplayRating(980)==909)
        assert(P.DisplayRating(1080)==1400 and P.DisplayRating(1400)==3000 and P.DisplayRating(2000)==6000)
    end)
    Case("monotone positive visible scale",function()
        local previous=0
        for skill=-10000,5000 do local r=P.DisplayRating(skill);assert(r>=1 and r>=previous and r==math.floor(r));previous=r end
    end)
    Case("visible half reset quantization",function()
        for skill=-5000,5000 do local r=P.DisplayRating(skill);local reset=P.DisplayRating(P.ResetSkill(skill));assert(math.abs(reset-P.Reset(r))<=3) end
        assert(P.DisplayRating(P.ResetSkill(1400))==2000 and P.ResetSkill(1000)==1000)
    end)
    local a,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local l=assert(ns.MatchLedger.OpenSimulated(client));local t={};local n=0
            local function Add(w,v,at)
                n=n+1;local x,y=w,v;if y<x then x,y=y,x end;local s="a-"..n..":b-"..n
                local r={scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,player1=x,player2=y,winner=w,loser=v,endType="knockout",rankEligible=false,
                    statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
                assert(l.Insert(r));t[r.id]=at;return r
            end
            local function Replay(at,rule) return assert(ns.RatingEngine.ReplaySimulated(client,l.Save(),t,rule or P.BALANCED_ID,{epoch=100,asOf=at})) end
            return Add,Replay,l,t
        end
        Case(client.." visible deltas preserve original skill math",function()
            local add,replay=Fixture();for i=1,3 do add(a,b,100+i)end;add(a,c,105);add(a,d,106);add(c,a,107);add(d,b,108)
            local old,new=replay(108,P.ID),replay(108)
            for i,x in ipairs(old.changes) do local y=new.changes[i];assert(x.weight==y.weight and x.expectedWin==y.expectedWin and x.winnerK==y.winnerK and x.loserK==y.loserK)
                assert(y.winnerBefore==P.DisplayRating(x.winnerBefore) and y.winnerAfter==P.DisplayRating(x.winnerAfter) and y.loserBefore==P.DisplayRating(x.loserBefore) and y.loserAfter==P.DisplayRating(x.loserAfter))
                assert(y.gain==y.winnerAfter-y.winnerBefore and y.loss==y.loserBefore-y.loserAfter)
            end
            for id,p in pairs(new.players) do local o=old.players[id];assert(p.skillRating==o.rating and p.rating==P.DisplayRating(o.rating) and p.credit==o.credit and p.rivalCount==o.rivalCount and p.peakRating==P.DisplayRating(o.peakRating)) end
            assert(new.changes[1].gain==100 and new.changes[1].loss==91 and new.changes[6].winnerK==40 and new.changes[6].loserK==24)
        end)
        Case(client.." rank reveal and positive weighted credits",function()
            local add,replay=Fixture();for i=1,3 do add(a,b,100+i)end;add(a,c,105);local pre=replay(105);assert(pre.players[a].rank.provisional);add(a,d,106)
            local s=replay(106);local p=s.players[a];assert(p.credit==20 and p.rivalCount==3 and not p.rank.provisional and p.rank.label==P.Rank(p.rating,20,3).label)
        end)
        Case(client.." anti farming zero weight no visible gain",function()
            local add,replay=Fixture();for i=1,10 do add(a,b,100+i)end;local s=replay(110)
            assert(s.rated==7 and s.restricted==3 and s.players[a].credit==18 and s.players[a].rivalCount==1)
            for i=8,10 do local x=s.changes[i];assert(x.weight==0 and x.gain==0 and x.loss==0) end
        end)
        Case(client.." rollover uses visible soft reset and archived skill",function()
            local add,replay=Fixture();for i=1,3 do add(a,b,100+i)end;add(a,c,105);add(a,d,106)
            local old=replay(106);local boundary=100+P.DURATION;add(a,b,boundary);local s=replay(boundary)
            local past=s.history[1].players[a];assert(past.rating==old.players[a].rating and past.skillRating==old.players[a].skillRating and past.peakRating==old.players[a].peakRating)
            local row=s.changes[#s.changes];assert(row.winnerBefore==P.DisplayRating(P.ResetSkill(past.skillRating)) and math.abs(row.winnerBefore-P.Reset(past.rating))<=3 and s.players[a].credit==4 and s.players[a].rank.provisional)
        end)
        Case(client.." late dispute recalculates balanced carry",function()
            local add,replay,l=Fixture();local r=add(a,b,101);add(a,c,100+P.DURATION);local before=replay(100+P.DURATION)
            local conflict={};for k,v in pairs(r)do conflict[k]=v end;conflict.winner=b;conflict.loser=a;conflict.statement1=r.statement1:gsub("|won|","|lost|");conflict.statement2=r.statement2:gsub("|lost|","|won|");assert(l.Insert(conflict))
            local after=replay(100+P.DURATION);assert(before.changes[2].winnerBefore~=1000 and after.changes[1].winnerBefore==1000 and after.disputed==1 and not after.history[1])
        end)
    end
    Case("balanced simulation only",function()local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible) end)
    return passed,failed
end

local _,ns=...
-- Private simulated character history. No game events, network or storage writes.
local P={}
ns.PersonalHistory=P
-- Separate character observation capacity; not a shared community ledger.
local LIMIT=8192
function P.GetCapacity() return LIMIT end
function P.GetSnapshot() return {scope="LOCAL",state="disabled",rankEligible=false} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Run(v)
    return type(v)=="string" and #v<=64 and v:match("^[%w%-]+$")~=nil
end
local function Cycle(v)
    return type(v)=="number" and v>=1 and v<=2147483647 and v==math.floor(v)
end
local function Time(v) return type(v)=="number" and v>=0 and v<math.huge end
local function Copy(t)
    local o={};for k,v in pairs(t) do o[k]=type(v)=="table" and Copy(v) or v end;return o
end
local function Same(a,b)
    for k,v in pairs(a) do if b[k]~=v then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Counter() return {total=0,wins=0,losses=0,unknown=0,fled=0,theyFled=0,currentStreak=0,bestStreak=0,
    signedStreak=0,worstStreak=0,durationCount=0,totalDuration=0} end
local function Tally(c,r)
    c.total=c.total+1
    c.durationCount=c.durationCount+1;c.totalDuration=c.totalDuration+r.duration
    if r.outcome=="won" or r.outcome=="they_fled" then
        c.wins=c.wins+1;c.currentStreak=c.currentStreak+1
        c.bestStreak=math.max(c.bestStreak,c.currentStreak)
        c.signedStreak=math.max(0,c.signedStreak)+1
        if r.outcome=="they_fled" then c.theyFled=c.theyFled+1 end
    else
        c.currentStreak=0
        if r.outcome=="lost" or r.outcome=="fled" then
            c.losses=c.losses+1;if r.outcome=="fled" then c.fled=c.fled+1 end
            c.signedStreak=math.min(0,c.signedStreak)-1;c.worstStreak=math.max(c.worstStreak,-c.signedStreak)
        else c.unknown=c.unknown+1;c.signedStreak=0 end
    end
end
local function Rate(c)
    local n=c.wins+c.losses
    if n>0 then c.winRate=c.wins/n end
    if c.durationCount>0 then c.averageDuration=c.totalDuration/c.durationCount end
end
local rankReasons={practice_selected=true,practice_agreed=true,not_agreed=true,
    capacity=true,storage_unavailable=true,retreat=true,unknown_result=true,confirmation_unavailable=true}
local endReasons={world_transition=true,conflicting_result=true,result_not_observed=true,
    finish_not_observed=true,not_observed=true}
local function Build(client,me,ledger,cap,scope)
    scope=scope or "SIMULATED"
    assert((client=="forever" or client=="retail") and Guid(me))
    local D,rows,ids,linked,sources={}, {},{},{},{}
    cap=cap or LIMIT
    function D.Observe(run,r,agreement)
        if not Run(run) or type(r)~="table" or r.scope~=scope or r.client~=client
            or r.rankEligible~=false or not Cycle(r.id) or not Time(r.acceptedAt) or not Time(r.endedAt)
            or r.endedAt<r.acceptedAt or (r.kind~="standard" and r.kind~="unclassified") then return false,"invalid_observation" end
        local peer=type(r.opponent)=="table" and r.opponent.guid or nil
        if not Guid(peer) then peer=nil end
        if peer==me then return false,"self" end
        local out="unknown"
        if r.reason=="matching_result_and_finish" and r.outcomeObserved==true and r.finishObserved==true
            and r.resultObserved==true and r.conflict==false then
            if r.endType=="knockout" and (r.outcome=="won" or r.outcome=="lost") then out=r.outcome
            elseif r.endType=="retreat" and (r.outcome=="fled" or r.outcome=="they_fled") then out=r.outcome end
        end
        local id=run..":"..r.id
        local row={id=id,cycle=r.id,run=run,opponent=peer,outcome=out,duration=r.endedAt-r.acceptedAt}
        if r.duelMode~=nil and r.duelMode~="practice" then return false,"invalid_mode" end
        if r.duelMode=="practice" and agreement~=nil then return false,"practice_cannot_rank" end
        if r.rankReason~=nil and not rankReasons[r.rankReason] then return false,"invalid_rank_reason" end
        if r.endReason~=nil and not endReasons[r.endReason] then return false,"invalid_end_reason" end
        row.duelMode=r.duelMode;row.rankReason=r.rankReason;row.endReason=r.endReason
        -- Real candidates are explicitly PEER-scoped; fixture agreements
        -- must never be accepted into local history.
        if scope=="LOCAL" and agreement~=nil and
            (type(agreement)~="table" or agreement.scope~="PEER") then return false,"local_only" end
        if scope=="LOCAL" then
            local opponent=type(r.opponent)=="table" and r.opponent or {}
            local meta=type(opponent.metadata)=="table" and opponent.metadata or {}
            local function Text(v,limit)
                return type(v)=="string" and #v>0 and #v<=limit and not v:find("[%c|]") and v or nil
            end
            row.name=Text(opponent.display,160)
            if type(r.observedAt)=="number" and r.observedAt>=1 and
                r.observedAt<=4102444800 and r.observedAt==math.floor(r.observedAt) then
                row.time=r.observedAt
            end
            if peer and meta.guid==peer and meta.scope=="LOCAL" then
                row.name=Text(meta.name,160) or row.name
                row.fullName=Text(meta.fullName,160)
                row.realm=client=="retail" and Text(meta.realm,64) or nil
                row.class=Text(meta.class,24)
                if row.class and not row.class:match("^[A-Z]+$") then row.class=nil end
                if meta.faction=="Alliance" or meta.faction=="Horde" or meta.faction=="Neutral" then row.faction=meta.faction end
            end
        end
        if agreement and peer then
            local make=scope=="LOCAL" and ns.ResultConfirmation.MakePeerStatement or ns.ResultConfirmation.MakeSimulatedStatement
            local body=make({scope=scope=="LOCAL" and "PEER" or "SIMULATED",client=client,
                me=me,peer=peer,cycle=r.id,agreement=agreement},r)
            if body then
                local a,b=me,peer;if b<a then a,b=b,a end
                row.matchID=client.."|"..a.."|"..b.."|"..agreement.session
                row.statement=body
            end
        end
        if ids[id] then return false,Same(ids[id],row) and "duplicate" or "conflicting_observation" end
        if row.matchID and linked[row.matchID] then return false,"duplicate_session" end
        if #rows>=cap then return false,"capacity" end
        -- Retain bounded evidence, not the derived counters or ledger status.
        local source={run=run,result={scope=scope,client=client,id=r.id,kind=r.kind,
            opponent=peer and {guid=peer} or nil,acceptedAt=r.acceptedAt,endedAt=r.endedAt,
            outcome=out,endType=out=="unknown" and nil or r.endType,
            reason=r.reason=="matching_result_and_finish" and r.reason or "not_observed",
            outcomeObserved=r.outcomeObserved==true,finishObserved=r.finishObserved==true,
            resultObserved=r.resultObserved==true,conflict=r.conflict~=false,rankEligible=false}}
        -- Unknown outcome never needs an end type, including malformed input.
        if out=="unknown" then source.result.endType=nil end
        if scope=="LOCAL" and (peer or row.name) then
            source.result.opponent={guid=peer,display=row.name}
            if peer and (row.fullName or row.realm or row.class or row.faction) then
                source.result.opponent.metadata={scope="LOCAL",guid=peer,name=row.name,
                    fullName=row.fullName,realm=row.realm,class=row.class,faction=row.faction}
            end
        end
        if scope=="LOCAL" then source.result.observedAt=row.time end
        source.result.duelMode=row.duelMode
        source.result.rankReason=row.rankReason
        source.result.endReason=row.endReason
        if row.matchID then source.agreement={scope=scope=="LOCAL" and "PEER" or "SIMULATED",state="candidate",candidate=true,
            rankEligible=false,session=agreement.session} end
        sources[#sources+1]=source
        rows[#rows+1]=row;ids[id]=row
        if row.matchID then linked[row.matchID]=true end
        return true
    end
    function D.Save()
        return {version=1,scope=scope,client=client,character=me,observations=Copy(sources)}
    end
    function D.Snapshot()
        local matched,disputed={},{}
        if scope=="SIMULATED" then
            local snapshot=ledger.Snapshot()
            assert(snapshot.scope=="SIMULATED" and snapshot.client==client and snapshot.rankEligible==false)
            for _,r in ipairs(snapshot.matched) do matched[r.id]=r end
            for _,r in ipairs(snapshot.disputed) do disputed[r.id]=true end
        end
        local s={scope=scope,client=client,character=me,rankEligible=false,history={},overall=Counter(),
            categories={unranked=Counter(),practice=Counter(),pending=Counter(),matched=Counter(),disputed=Counter(),ranked=Counter()},opponents={}}
        -- Append order is local observation order, not cross-client replay time.
        for _,r in ipairs(rows) do
            local row=Copy(r);local category=r.duelMode=="practice" and "practice" or "unranked"
            if r.matchID then
                local rec=matched[r.matchID]
                if disputed[r.matchID] then category="disputed"
                elseif rec then
                    local body=rec.player1==me and rec.statement1 or rec.player2==me and rec.statement2
                    category=body==r.statement and "matched" or "disputed"
                else category="pending" end
            end
            row.category=category;s.history[#s.history+1]=row
            Tally(s.overall,r);Tally(s.categories[category],r)
            if r.opponent then
                local c=s.opponents[r.opponent] or Counter();s.opponents[r.opponent]=c;Tally(c,r)
            end
        end
        Rate(s.overall);for _,c in pairs(s.categories) do Rate(c) end;for _,c in pairs(s.opponents) do Rate(c) end
        return s
    end
    return D
end
-- Compare only against the bounded canonical tree; untrusted nested data is
-- never copied recursively. Extra fields and sparse arrays fail closed.
local function EqualSaved(clean,raw)
    if type(clean)~=type(raw) then return false end
    if type(clean)~="table" then return clean==raw end
    for k,v in pairs(clean) do if not EqualSaved(v,raw[k]) then return false end end
    for k in pairs(raw) do if clean[k]==nil then return false end end
    return true
end
local function Open(client,me,ledger,stored,cap,scope)
    if (client~="forever" and client~="retail") or not Guid(me) then return nil,"identity" end
    if cap==nil then cap=LIMIT end
    if type(cap)~="number" or cap<1 or cap>LIMIT or cap~=math.floor(cap) then return nil,"invalid_capacity" end
    local d=Build(client,me,ledger,cap,scope)
    if stored==nil then return d end
    if type(stored)~="table" or stored.version~=1 or stored.scope~=scope
        or stored.client~=client or stored.character~=me or type(stored.observations)~="table" then return nil,"schema" end
    local n=0
    for k in pairs(stored.observations) do
        n=n+1;if not Cycle(k) or k>cap or n>cap then return nil,"invalid_observations" end
    end
    for i=1,n do
        local src=stored.observations[i]
        if type(src)~="table" or not d.Observe(src.run,src.result,src.agreement) then return nil,"invalid_observation" end
    end
    if not EqualSaved(d.Save(),stored) then return nil,"noncanonical_history" end
    return d
end
function P.OpenSimulated(client,me,ledger,stored,cap)
    return Open(client,me,ledger,stored,cap,"SIMULATED")
end
-- Local observations may carry their own PEER candidate statement, never a
-- fixture or independently supplied ranking result.
function P.OpenLocal(client,me,stored,cap)
    return Open(client,me,nil,stored,cap,"LOCAL")
end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local a,b,c="Player-1-AAA","Player-2-BBB","Player-3-CCC"
        local function Fixture(cap)
            local ledger=assert(ns.MatchLedger.OpenSimulated(client))
            return Build(client,a,ledger,cap),ledger
        end
        local function R(n,out,peer)
            return {scope="SIMULATED",client=client,id=n,kind="standard",opponent=peer and {guid=peer} or nil,
                acceptedAt=10,endedAt=20,outcome=out,endType=(out=="fled" or out=="they_fled") and "retreat" or "knockout",
                reason="matching_result_and_finish",outcomeObserved=true,finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
        end
        local function Agreement(n)
            return {scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session="alpha-"..n..":beta-"..n}
        end
        local function Record(n,reverse,cycle)
            local ag=Agreement(n);local x,y=reverse and "lost" or "won",reverse and "won" or "lost"
            local s=ag.session
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,x,tostring(cycle or n)},"|"),
                statement2=table.concat({"1",client,s,b,a,y,"12"},"|")}
        end
        Case(client.." empty history has no invented win rate",function()
            local d=Fixture();local s=d.Snapshot();assert(s.overall.total==0 and s.overall.winRate==nil and s.categories.ranked.total==0)
        end)
        Case(client.." ordinary duels need no peer addon",function()
            local d=Fixture();assert(d.Observe("run",R(1,"won",b)));assert(d.Observe("run",R(2,"lost",b)))
            local s=d.Snapshot();assert(s.overall.wins==1 and s.overall.losses==1 and s.overall.winRate==0.5 and s.categories.unranked.total==2)
        end)
        Case(client.." explicit practice is isolated and durable",function()
            local d,l=Fixture();local r=R(1,"won",b);r.duelMode="practice";r.rankReason="practice_selected"
            assert(not d.Observe("run",r,Agreement(1)))
            assert(d.Observe("run",r));local saved=d.Save()
            local reopened=assert(P.OpenSimulated(client,a,l,saved))
            local snap=reopened.Snapshot()
            assert(snap.categories.practice.wins==1 and snap.overall.total==1 and not snap.history[1].matchID)
            assert(snap.history[1].rankReason=="practice_selected")
        end)
        Case(client.." retreats and unknown outcomes",function()
            local d=Fixture();d.Observe("run",R(1,"they_fled",b));d.Observe("run",R(2,"fled",b))
            local r=R(3,"won",b);r.finishObserved=false;d.Observe("run",r);local s=d.Snapshot().overall
            assert(s.total==3 and s.wins==1 and s.losses==1 and s.unknown==1 and s.fled==1 and s.theyFled==1 and s.winRate==0.5)
        end)
        Case(client.." streaks stop at losses and uncertainty",function()
            local d=Fixture();for i,out in ipairs({"won","won","lost","won","unknown","won"}) do d.Observe("run",R(i,out,b)) end
            local s=d.Snapshot().overall;assert(s.currentStreak==1 and s.bestStreak==2)
        end)
        Case(client.." GUID head to head and unresolved identity",function()
            local d=Fixture();d.Observe("run",R(1,"won",b));d.Observe("run",R(2,"lost",c));d.Observe("run",R(3,"won"))
            local s=d.Snapshot();assert(s.overall.total==3 and s.opponents[b].wins==1 and s.opponents[c].losses==1)
        end)
        Case(client.." cycle duplicate and separate runs",function()
            local d=Fixture();local r=R(1,"won",b);assert(d.Observe("run1",r));assert(not d.Observe("run1",r))
            assert(not d.Observe("run1",R(1,"lost",b)));assert(d.Observe("run2",r));assert(d.Snapshot().overall.total==2)
        end)
        Case(client.." matched candidate never double counted",function()
            local d,l=Fixture();assert(d.Observe("run",R(1,"won",b),Agreement(1)));assert(d.Snapshot().categories.pending.total==1)
            assert(l.Insert(Record(1)));local s=d.Snapshot();assert(s.categories.matched.total==1 and s.overall.total==1 and s.categories.ranked.total==0)
            assert(not d.Observe("other",R(1,"won",b),Agreement(1)))
        end)
        Case(client.." late dispute reclassifies without rewriting local observation",function()
            local d,l=Fixture();d.Observe("run",R(1,"won",b),Agreement(1));l.Insert(Record(1));l.Insert(Record(1,true))
            local s=d.Snapshot();assert(s.categories.disputed.total==1 and s.categories.matched.total==0 and s.overall.wins==1 and s.categories.ranked.total==0)
        end)
        Case(client.." unmatched statement cannot claim confirmation",function()
            local d,l=Fixture();d.Observe("run",R(1,"won",b),Agreement(1));l.Insert(Record(1,false,2))
            assert(d.Snapshot().categories.disputed.total==1)
        end)
        Case(client.." client, character and scope isolation",function()
            local d,l=Fixture();d.Observe("run",R(1,"won",b));local other=Build(client,c,l);assert(other.Snapshot().overall.total==0)
            local r=R(2,"won",b);r.scope="LOCAL";assert(not d.Observe("run",r));r.scope="SIMULATED";r.client=client=="forever" and "retail" or "forever";assert(not d.Observe("run",r))
        end)
        Case(client.." death duels and invalid durations excluded",function()
            local d=Fixture();local r=R(1,"won",b);r.kind="death_duel";assert(not d.Observe("run",r));r.kind="standard";r.endedAt=1;assert(not d.Observe("run",r));assert(d.Snapshot().overall.total==0)
        end)
        Case(client.." copy isolation and capacity",function()
            local d=Fixture(1);local r=R(1,"won",b);d.Observe("run",r);r.outcome="lost";local s=d.Snapshot();s.history[1].outcome="lost";s.overall.wins=0
            assert(not d.Observe("run",R(2,"lost",b)));assert(d.Snapshot().overall.wins==1 and d.Snapshot().history[1].outcome=="won")
        end)
    end
    Case("live history remains disabled",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible);s.state="changed";assert(P.GetSnapshot().state=="disabled")
    end)
    return passed,failed
end

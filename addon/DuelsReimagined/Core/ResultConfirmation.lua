local _,ns=...
-- Pure result validation for isolated simulation and unverified peer claims.
-- The lifecycle owns actual transport, settlement and persistence.
local P={}
ns.ResultConfirmation=P
local VERSION="1"
local function WireVersion(scope) return scope=="PEER" and "2" or VERSION end
function P.GetSnapshot()
    return {scope="LOCAL",state="disabled",rankEligible=false}
end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Session(v)
    if type(v)~="string" or #v>65 then return false end
    local a,b=v:match("^([%w%-]+):([%w%-]+)$")
    return a~=nil and #a<=32 and #b<=32 and a~="-" and b~="-"
end
local function Cycle(v)
    return type(v)=="number" and v>=1 and v<=2147483647 and v==math.floor(v)
end
local function Stamp(v)
    return type(v)=="number" and v>=1 and v<=4102444800 and v==math.floor(v)
end
local function Context(c,scope)
    if type(c)~="table" or c.scope~=scope or not Guid(c.me) or not Guid(c.peer)
        or c.me==c.peer or not Cycle(c.cycle) or (c.client~="forever" and c.client~="retail") then return end
    local a=c.agreement
    if type(a)~="table" or a.scope~=scope or a.state~="candidate" or a.candidate~=true
        or a.rankEligible~=false or not Session(a.session) then return end
    return {client=c.client,me=c.me,peer=c.peer,cycle=c.cycle,session=a.session}
end
local function Statement(c,r,scope)
    c=Context(c,scope)
    if not c or type(r)~="table" or r.scope~=((scope=="PEER" or scope=="PRIVATE_TEST") and "LOCAL" or "SIMULATED") or r.client~=c.client or r.id~=c.cycle
        or type(r.opponent)~="table" or r.opponent.guid~=c.peer or r.rankEligible~=false
        or r.duelMode=="practice" or (scope=="PEER" and r.duelMode=="tournament") or r.kind=="death_duel" or (r.kind~="standard" and r.kind~="unclassified")
        or r.reason~="matching_result_and_finish" or r.outcomeObserved~=true or r.finishObserved~=true
        or r.resultObserved~=true or r.conflict~=false or r.endType~="knockout"
        or (r.outcome~="won" and r.outcome~="lost") then return end
    if scope=="PRIVATE_TEST" and (r.duelMode~="tournament" or r.tournamentSession~=c.session) then return nil end
    local fields={WireVersion(scope),c.client,c.session,c.me,c.peer,r.outcome,tostring(c.cycle)}
    if scope=="PEER" then
        if not Stamp(r.observedAt) then return end
        fields[#fields+1]=tostring(r.observedAt)
    end
    return table.concat(fields,"|")
end
-- One bounded collector per simulated match. Exact sender is provided by the
-- fixture; a future live adapter must resolve actual event sender independently.
local function Build(client,session,a,b,scope)
    scope=scope or "SIMULATED"
    assert((client=="forever" or client=="retail") and Session(session) and Guid(a) and Guid(b) and a~=b)
    if b<a then a,b=b,a end
    local D,slots,conflict,closed={}, {},false,false
    function D.Receive(body,sender)
        if closed or (sender~=a and sender~=b) or type(body)~="string" or #body>240 or body:find("%c") then return false end
        local rev,k,id,from,to,out,cycle,stamp
        if scope=="PEER" then
            rev,k,id,from,to,out,cycle,stamp=body:match("^(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|(%a+)|(%d+)|(%d+)$")
            if not Stamp(tonumber(stamp)) or stamp~=tostring(tonumber(stamp)) then return false end
        else
            rev,k,id,from,to,out,cycle=body:match("^(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|(%a+)|(%d+)$")
        end
        if rev~=WireVersion(scope) or k~=client or id~=session or from~=sender or to~=(sender==a and b or a)
            or (out~="won" and out~="lost") or not Cycle(tonumber(cycle)) or cycle~=tostring(tonumber(cycle)) then return false end
        if slots[sender] then
            if slots[sender].body~=body then conflict=true end
            return false
        end
        slots[sender]={body=body,outcome=out,cycle=tonumber(cycle),time=tonumber(stamp)}
        if slots[a] and slots[b] then
            if slots[a].outcome==slots[b].outcome then conflict=true end
            if scope=="PEER" and math.abs(slots[a].time-slots[b].time)>5 then conflict=true end
        end
        return true
    end
    function D.Close() closed=true end
    function D.Snapshot()
        local x,y=slots[a],slots[b]
        local state=conflict and "disputed" or x and y and "matched" or closed and "unconfirmed" or "pending"
        local s={scope=scope,state=state,rankEligible=false,closed=closed}
        -- A matched snapshot is not final settlement. Only explicit close can
        -- export a candidate record; future ledger handles late conflicts.
        if state=="matched" and closed then
            local winner=x.outcome=="won" and a or b
            s.record={scope=scope,version=WireVersion(scope),client=client,session=session,
                id=client.."|"..a.."|"..b.."|"..session,player1=a,player2=b,
                winner=winner,loser=winner==a and b or a,endType="knockout",rankEligible=false,
                statement1=x.body,statement2=y.body}
            if scope=="PEER" then s.record.time1=x.time;s.record.time2=y.time end
        end
        return s
    end
    return D
end
-- Reconstruct a simulated canonical record from its statements. The ledger
-- never trusts derived fields or a caller-supplied status. Not proof of origin.
function P.NewSimulated(client,session,a,b) return Build(client,session,a,b,"SIMULATED") end
function P.NewPeer(client,session,a,b) return Build(client,session,a,b,"PEER") end
function P.MakeSimulatedStatement(c,r) return Statement(c,r,"SIMULATED") end
function P.MakePeerStatement(c,r) return Statement(c,r,"PEER") end
function P.MakePrivateTournamentStatement(c,r) return Statement(c,r,"PRIVATE_TEST") end
-- Shared reconstruction from canonical statement pairs; no derived input
-- fields or transport identity are trusted by this storage/codec helper.
local function Decode(client,a,b,scope)
    if type(a)~="string" or type(b)~="string" or #a>240 or #b>240 then return nil end
    local pattern=scope=="PEER" and "^(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|%a+|%d+|%d+$"
        or "^(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|%a+|%d+$"
    local rev,k,session,x,y=a:match(pattern)
    if rev~=WireVersion(scope) or k~=client or (client~="forever" and client~="retail")
        or not Session(session) or not Guid(x) or not Guid(y) or x>=y then return nil end
    local d=Build(client,session,x,y,scope)
    if not d.Receive(a,x) or not d.Receive(b,y) then return nil end
    d.Close();return d.Snapshot().record
end
local function Validate(r,scope)
    if type(r)~="table" or r.scope~=scope or r.version~=WireVersion(scope) or r.rankEligible~=false
        or (r.client~="forever" and r.client~="retail") or not Session(r.session)
        or not Guid(r.player1) or not Guid(r.player2) or r.player1>=r.player2 then return end
    local d=Build(r.client,r.session,r.player1,r.player2,scope)
    if not d.Receive(r.statement1,r.player1) or not d.Receive(r.statement2,r.player2) then return end
    d.Close()
    local clean=d.Snapshot().record
    if not clean then return end
    for k,v in pairs(clean) do if r[k]~=v then return end end
    if scope=="PEER" then for k in pairs(r) do if clean[k]==nil then return end end end
    return clean
end
function P.DecodeStatementsSimulated(client,a,b) return Decode(client,a,b,"SIMULATED") end
function P.DecodePeerStatements(client,a,b) return Decode(client,a,b,"PEER") end
function P.ValidateSimulatedRecord(r) return Validate(r,"SIMULATED") end
function P.ValidatePeerRecord(r) return Validate(r,"PEER") end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local function Fixture(client)
        local a,b="Player-1-AAA","Player-2-BBB"
        local id="alpha-1:beta-1"
        local function C(me,peer,cycle)
            return {scope="SIMULATED",client=client,me=me,peer=peer,cycle=cycle,
                agreement={scope="SIMULATED",state="candidate",candidate=true,session=id,rankEligible=false}}
        end
        local function R(peer,cycle,outcome,kind)
            return {scope="SIMULATED",client=client,id=cycle,opponent={guid=peer},kind=kind,
                outcome=outcome,endType="knockout",reason="matching_result_and_finish",outcomeObserved=true,
                finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
        end
        local f={a=a,b=b,id=id,ca=C(a,b,7),cb=C(b,a,12),ra=R(b,7,"won","unclassified"),rb=R(a,12,"lost","standard")}
        f.d=Build(client,id,a,b)
        function f.first() return assert(P.MakeSimulatedStatement(f.ca,f.ra)) end
        function f.second() return assert(P.MakeSimulatedStatement(f.cb,f.rb)) end
        function f.match() assert(f.d.Receive(f.first(),a));assert(f.d.Receive(f.second(),b)) end
        return f
    end
    for _,client in ipairs({"forever","retail"}) do
        Case(client.." complementary reports / canonical record",function()
            local f=Fixture(client);f.match();assert(not f.d.Snapshot().record);f.d.Close()
            local r=assert(f.d.Snapshot().record);assert(r.winner==f.a and r.loser==f.b and not r.rankEligible)
            local d=Build(client,f.id,f.b,f.a);d.Receive(f.second(),f.b);d.Receive(f.first(),f.a);d.Close()
            local q=assert(d.Snapshot().record);for k,v in pairs(r) do assert(q[k]==v,k) end
            r.winner="changed";assert(f.d.Snapshot().record.winner==f.a)
        end)
        Case(client.." missing agreement / wrong scope",function()
            local f=Fixture(client);assert(P.MakeSimulatedStatement(f.ca,f.ra))
            f.ca.agreement.candidate=false;assert(not P.MakeSimulatedStatement(f.ca,f.ra))
            f.ca.agreement.candidate=true;f.ra.scope="LOCAL";assert(not P.MakeSimulatedStatement(f.ca,f.ra))
        end)
        Case(client.." incomplete or conflicting local evidence",function()
            local f=Fixture(client)
            for _,k in ipairs({"outcomeObserved","finishObserved","resultObserved"}) do
                f.ra[k]=false;assert(not P.MakeSimulatedStatement(f.ca,f.ra));f.ra[k]=true
            end
            f.ra.conflict=true;assert(not P.MakeSimulatedStatement(f.ca,f.ra));f.ra.conflict=false
            f.ra.outcome="unknown";assert(not P.MakeSimulatedStatement(f.ca,f.ra))
        end)
        Case(client.." retreats and death duels excluded",function()
            local f=Fixture(client);f.ra.endType="retreat";assert(not P.MakeSimulatedStatement(f.ca,f.ra))
            f.ra.endType="knockout";f.ra.kind="death_duel";assert(not P.MakeSimulatedStatement(f.ca,f.ra))
        end)
        Case(client.." wrong cycle and opponent",function()
            local f=Fixture(client);f.ra.id=8;assert(not P.MakeSimulatedStatement(f.ca,f.ra));f.ra.id=7
            f.ra.opponent.guid=f.a;assert(not P.MakeSimulatedStatement(f.ca,f.ra))
        end)
        Case(client.." one report remains unconfirmed",function()
            local f=Fixture(client);f.d.Receive(f.first(),f.a);assert(f.d.Snapshot().state=="pending")
            f.d.Close();assert(f.d.Snapshot().state=="unconfirmed" and not f.d.Snapshot().record)
            assert(not f.d.Receive(f.second(),f.b))
        end)
        Case(client.." both win or both lose disputed",function()
            for _,out in ipairs({"won","lost"}) do
                local f=Fixture(client);f.ra.outcome=out;f.rb.outcome=out;f.match();f.d.Close()
                assert(f.d.Snapshot().state=="disputed" and not f.d.Snapshot().record)
            end
        end)
        Case(client.." duplicate and contradictory same-sender reports",function()
            local f=Fixture(client);f.match();assert(not f.d.Receive(f.first(),f.a));assert(f.d.Snapshot().state=="matched")
            f.ra.outcome="lost";assert(not f.d.Receive(f.first(),f.a));f.d.Close()
            assert(f.d.Snapshot().state=="disputed" and not f.d.Snapshot().record)
        end)
        Case(client.." spoof, malformed, protocol and client rejection",function()
            local f=Fixture(client);local p=f.first()
            assert(not f.d.Receive(p,f.b));assert(not f.d.Receive(p.."|extra",f.a))
            assert(not f.d.Receive(p.."\n",f.a));assert(not f.d.Receive(p:gsub("^1|","2|"),f.a))
            assert(not f.d.Receive(p:gsub(client,client=="forever" and "retail" or "forever",1),f.a))
            assert(not f.d.Receive(p:gsub("|7$","|07"),f.a));assert(f.d.Receive(p,f.a))
        end)
        Case(client.." prior match replay and close idempotence",function()
            local f=Fixture(client);f.match();f.d.Close();f.d.Close();local r=assert(f.d.Snapshot().record)
            local d=Build(client,"alpha-2:beta-2",f.a,f.b)
            assert(not d.Receive(f.first(),f.a) and not d.Receive(f.second(),f.b));d.Close()
            assert(not d.Snapshot().record and f.d.Snapshot().record.id==r.id)
        end)
    end
    Case("live result confirmation remains disabled",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
        s.state="changed";assert(P.GetSnapshot().state=="disabled")
    end)
    return passed,failed
end

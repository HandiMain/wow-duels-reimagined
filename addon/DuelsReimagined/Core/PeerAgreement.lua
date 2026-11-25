local _,ns=...
-- Simulation-only agreement engine. No live adapter, timers, storage or rank writes.
local P={}
ns.PeerAgreement=P
local WAIT,VERSION=8,"1"
function P.GetSnapshot()
    return {scope="LOCAL",state="disabled",reason="multiplayer_not_enabled",rankEligible=false}
end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end

local function Token(v)
    return type(v)=="string" and #v<=32 and v:match("^[%w%-]+$")~=nil
end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Build(client,prefix,now,available,send,scope,population)
    scope=scope or "SIMULATED"
    local D,s,seq={},nil,0
    local wire=scope=="PEER" and "2" or VERSION
    local function Valid()
        return s and now()<s.deadline and available()
    end
    local function Send(op,a,b)
        if not Valid() then return false end
        local fields={op,wire,client,s.me,s.peer,a,b}
        if scope=="PEER" then fields[#fields+1]=s.mode end
        return send(table.concat(fields,"|"),s.key)==true
    end
    function D.Snapshot()
        local state=s and s.state or "idle"
        if s and not s.frozen and not Valid() then state="unranked" end
        return {scope=scope,state=state,rankEligible=false,
            candidate=state=="candidate",practice=state=="practice",
            session=state=="candidate" and s.session or nil}
    end
    function D.Reset() s=nil end
    function D.Begin(c,d,consent,mode)
        if s or not available() or consent~=true or not c or not d then return false end
        if scope=="PEER" and mode~="R" and mode~="P" then return false end
        -- The actual detector marks outgoing attempts unclassified until more evidence arrives.
        local outgoing=c.direction=="outgoing" and (c.kind=="unclassified" or c.kind=="standard")
        local incoming=c.direction=="incoming" and c.kind=="standard"
        if not (outgoing or incoming) or c.state~="challenge" or not Guid(c.me) or not Guid(c.peer)
            or c.me==c.peer or d.state~="compatible" or d.protocol~=VERSION
            or d.guid~=c.peer or type(d.key)~="string" or d.key=="" or d.expiresAt<=now() then return false end
        seq=seq+1
        local token=prefix.."-"..seq
        if not Token(token) or (population and not ns.CompetitiveScope.TokenMatches(population,client,token)) then return false end
        s={state=outgoing and "offer" or "waiting",me=c.me,peer=c.peer,key=d.key,
            token=token,mode=mode or "R",deadline=math.min(now()+WAIT,d.expiresAt)}
        if outgoing and not Send("O",token,"-") then s.state="unranked";return false end
        return true
    end
    function D.Receive(body,sender)
        if not Valid() or s.frozen or sender~=s.key or type(body)~="string"
            or #body>220 or body:find("%c") then return end
        local op,rev,kind,from,to,a,b,mode
        if scope=="PEER" then
            op,rev,kind,from,to,a,b,mode=body:match("^([OAC])|(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([RP])$")
        else
            op,rev,kind,from,to,a,b=body:match("^([OAC])|(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
            mode="R"
        end
        if rev~=wire or kind~=client or from~=s.peer or to~=s.me or not Token(a) or not Token(b) then return end
        if population and (not ns.CompetitiveScope.TokenMatches(population,client,a) or (b~="-" and not ns.CompetitiveScope.TokenMatches(population,client,b))) then return end
        if op=="O" and s.state=="waiting" and b=="-" and a~="-" then
            s.remote=a;s.remoteMode=mode;s.state="ack"
            if not Send("A",a,s.token) then s.state="unranked" end
        elseif op=="A" and s.state=="offer" and a==s.token and b~="-" then
            s.remote=b;s.remoteMode=mode;s.state="unranked"
            if Send("C",a,b) then s.state="agreed";s.session=a..":"..b end
        elseif op=="C" and s.state=="ack" and a==s.remote and b==s.token and mode==s.remoteMode then
            s.state="agreed";s.session=a..":"..b
        end
    end
    function D.Freeze(peer,ordinary)
        if not s or s.frozen then return end
        -- Countdown is a hard boundary: no packet can promote this duel afterward.
        if Valid() and s.state=="agreed" and peer==s.peer and ordinary==true then
            s.state=(s.mode=="P" or s.remoteMode=="P") and "practice" or "candidate"
        else s.state="unranked" end
        s.frozen=true
    end
    return D
end

function P.NewSimulated(client,prefix,now,available,send)
    return Build(client,prefix,now,available,send,"SIMULATED")
end
-- Candidate only; the live adapter owns consent and actual sender checks.
function P.NewPeer(client,prefix,now,available,send,population)
    return Build(client,prefix,now,available,send,"PEER",population)
end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local function Fixture(kind,scope,modeA,modeB)
        local time,ready,packets=100,true,{}
        local x,y="Player-1-AAA","Player-2-BBB"
        local function Make(key)
            return Build(kind,key,function()return time end,function()return ready end,
                function(body,target) packets[#packets+1]={body=body,target=target,sender=key};return true end,scope)
        end
        local f={a=Make("alpha"),b=Make("beta"),packets=packets,x=x,y=y}
        local function challenge(me,peer,direction,k)
            return {state="challenge",me=me,peer=peer,direction=direction,kind=k}
        end
        f.ca=challenge(x,y,"outgoing","unclassified");f.cb=challenge(y,x,"incoming","standard")
        f.da={state="compatible",protocol="1",guid=y,key="beta",expiresAt=160}
        f.db={state="compatible",protocol="1",guid=x,key="alpha",expiresAt=160}
        function f.start() assert(f.b.Begin(f.cb,f.db,true,modeB));assert(f.a.Begin(f.ca,f.da,true,modeA)) end
        function f.deliver(i)
            local p=assert(packets[i]);(p.target=="alpha" and f.a or f.b).Receive(p.body,p.sender)
        end
        function f.agree() f.start();f.deliver(1);f.deliver(2);f.deliver(3) end
        function f.freeze() f.a.Freeze(y,true);f.b.Freeze(x,true) end
        function f.advance(n) time=time+n end
        function f.lock() ready=false end
        return f
    end
    for _,kind in ipairs({"forever","retail"}) do
        Case(kind.." mutual agreement before countdown",function()
            local f=Fixture(kind);f.agree();assert(not f.a.Snapshot().candidate);f.freeze()
            local a,b=f.a.Snapshot(),f.b.Snapshot()
            assert(a.candidate and b.candidate and a.session==b.session and not a.rankEligible and not b.rankEligible)
            a.session="changed";assert(f.a.Snapshot().session==b.session)
        end)
        Case(kind.." peer mode agreement never ranks practice",function()
            for _,m in ipairs({{"R","P"},{"P","R"},{"P","P"},{"R","R"}}) do
                local f=Fixture(kind,"PEER",m[1],m[2]);f.agree();f.freeze()
                local x,y=f.a.Snapshot(),f.b.Snapshot()
                local ranked=m[1]=="R" and m[2]=="R"
                assert(x.candidate==ranked and y.candidate==ranked and x.practice==(not ranked) and y.practice==(not ranked))
                assert(ranked or (x.session==nil and y.session==nil))
            end
        end)
        Case(kind.." missing practice confirmation cannot rank",function()
            local f=Fixture(kind,"PEER","R","P");f.start();f.deliver(1);f.deliver(2);f.freeze();f.deliver(3)
            assert(not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
            assert(f.a.Snapshot().practice and not f.b.Snapshot().practice)
        end)
        Case(kind.." consent and discovery required",function()
            local f=Fixture(kind);assert(not f.a.Begin(f.ca,f.da,false));f.da.state="unknown"
            assert(not f.a.Begin(f.ca,f.da,true));f.da.state="compatible";f.da.guid=f.x
            assert(not f.a.Begin(f.ca,f.da,true));f.da.guid=f.y;f.da.expiresAt=100
            assert(not f.a.Begin(f.ca,f.da,true));assert(#f.packets==0)
        end)
        Case(kind.." death duel and missing challenge excluded",function()
            local f=Fixture(kind);f.cb.kind="death_duel";assert(not f.b.Begin(f.cb,f.db,true))
            f.ca.state="accepted";assert(not f.a.Begin(f.ca,f.da,true));assert(#f.packets==0)
        end)
        Case(kind.." spoofed and malformed packets rejected",function()
            local f=Fixture(kind);f.start();local p=f.packets[1]
            f.b.Receive(p.body,"stranger");f.b.Receive(p.body.."|extra",p.sender)
            f.b.Receive(p.body.."\n",p.sender);f.b.Receive(p.body:gsub("|1|","|2|",1),p.sender)
            f.b.Receive(p.body:gsub("Player%-1%-AAA","Player-3-CCC"),p.sender)
            assert(#f.packets==1);f.deliver(1);assert(#f.packets==2)
        end)
        Case(kind.." duplicates bounded",function()
            local f=Fixture(kind);f.agree();f.deliver(1);f.deliver(2);f.deliver(3)
            assert(#f.packets==3);f.freeze();assert(f.a.Snapshot().candidate and f.b.Snapshot().candidate)
        end)
        Case(kind.." no reply and expired agreement",function()
            local f=Fixture(kind);f.start();f.advance(8);f.deliver(1);f.freeze()
            assert(#f.packets==1 and not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
            f=Fixture(kind);f.agree();f.advance(8);f.freeze();assert(not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
        end)
        Case(kind.." countdown rejects late packets",function()
            local f=Fixture(kind);f.start();f.deliver(1);f.freeze();f.deliver(2)
            assert(#f.packets==2 and not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
        end)
        Case(kind.." lost final message not bilateral proof",function()
            local f=Fixture(kind);f.start();f.deliver(1);f.deliver(2);f.freeze();f.deliver(3)
            assert(f.a.Snapshot().candidate and not f.b.Snapshot().candidate and not f.a.Snapshot().rankEligible)
        end)
        Case(kind.." rematch rejects prior confirmation",function()
            local f=Fixture(kind);f.agree();f.a.Reset();f.b.Reset();f.start();f.deliver(1);f.deliver(2);f.deliver(3)
            f.freeze();assert(not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
        end)
        Case(kind.." restriction and mismatched countdown",function()
            local f=Fixture(kind);f.agree();f.lock();f.freeze();assert(not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
            f=Fixture(kind);f.agree();f.a.Freeze("Player-3-CCC",true);f.b.Freeze(f.x,false)
            assert(not f.a.Snapshot().candidate and not f.b.Snapshot().candidate)
        end)
    end
    Case("live agreement remains disabled",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
        s.state="changed";assert(P.GetSnapshot().state=="disabled")
    end)
    return passed,failed
end

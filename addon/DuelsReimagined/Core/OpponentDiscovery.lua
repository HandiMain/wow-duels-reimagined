local _,ns=...
-- Discovery only. A compatible response is not duel confirmation, consent,
-- rank eligibility, or proof of honest client data.
local P={}
ns.OpponentDiscovery=P
local WAIT,GAP,TTL=8,3,60
local PROTOCOL="1"
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Plain(v) end
end
local function Text(v)
    v=Plain(v)
    if type(v)=="string" and #v>0 and #v<=160 and not v:find("[%c|]") then return v end
end
local function Guid(v)
    v=Text(v)
    if v and #v<=64 and v:match("^Player%-%w[%w%-]*$") then return v end
end
local function Name(v,kind,home)
    v=Text(v)
    if not v then return nil end
    if kind=="forever" then
        -- Sender may include a realm suffix; preserve the actual surname.
        v=v:match("^([^%-]+)") or v
        return v:gsub("%s+"," "):lower()
    end
    local first,realm=v:match("^([^%-]+)%-(.+)$")
    if not first then first,realm=v,home end
    if not Text(realm) then return nil end
    return first:lower().."-"..realm:lower():gsub("[%s%-]","")
end
local function Build(api)
    local D={}
    local state={state="idle",reason="no_probe",revision=0,scope=api.scope,rankEligible=false}
    local pending,lastProbe,lastReply,seq=nil,-math.huge,-math.huge,0
    local function Change(status,why,who,rev,untilTime)
        state={state=status,reason=why,revision=state.revision+1,scope=api.scope,
            rankEligible=false,opponent=who,protocol=rev,expiresAt=untilTime}
    end
    local function Clock()
        local v=api.now()
        if type(v)=="number" and v==v and v>=0 and v<math.huge then return v end
    end
    local function Identity(unit)
        local p=api.identity(unit)
        if not p then return end
        local guid=Guid(p.guid)
        local route=Text(p.fullName)
        local home=api.home()
        if route and api.kind~="forever" and not route:find("-",1,true) and Text(home) then
            route=route.."-"..home
        end
        local name=Name(route,api.kind,home)
        if guid and name then return {guid=guid,route=route,key=name} end
    end
    local function Expire(now)
        if pending and now>=pending.deadline then
            local who=pending.peer
            pending=nil
            Change("unknown","no_reply",who)
        elseif state.expiresAt and now>=state.expiresAt then
            Change("unknown","confirmation_expired",state.opponent)
        end
    end
    function D.GetSnapshot()
        local now=Clock()
        -- Snapshot reads are pure, including when an expiry timer is late.
        local out={}
        for k,v in pairs(state) do
            if k=="opponent" and v then out[k]={guid=v.guid,route=v.route,key=v.key}
            else out[k]=v end
        end
        if now and state.expiresAt and now>=state.expiresAt then
            out.state="unknown";out.reason=pending and "no_reply" or "confirmation_expired"
        end
        return out
    end
    function D.GetDiagnosticResources() return {pending=pending and 1 or 0} end
    function D.Reset()
        pending=nil
        Change("idle","reset")
    end
    function D.Probe(unit,expectedGuid)
        local now=Clock()
        if not now then return false,"clock_unavailable" end
        Expire(now)
        local me,peer=Identity("player"),Identity(unit)
        if not me or not peer or me.guid==peer.guid or me.key==peer.key or
            (expectedGuid and peer.guid~=expectedGuid) then return false,"identity_unavailable" end
        if pending or now-lastProbe<GAP then return false,"cooldown" end
        if state.state=="compatible" and state.opponent and state.opponent.guid==peer.guid
            and state.expiresAt and now<state.expiresAt then return true,"recent_reply" end
        local available,why=api.available()
        if not available then Change("unknown",why or "restricted",peer);return false,why end
        seq=seq+1
        local nonce=api.noncePrefix.."-"..seq
        local msg=table.concat({"H",nonce,api.kind,PROTOCOL,me.guid,peer.guid},"|")
        lastProbe=now -- refused attempts also throttle
        pending={peer=peer,nonce=nonce,deadline=now+WAIT,me=me.guid}
        Change("checking","request_sent",peer,nil,now+WAIT)
        local sent,reason=api.send(msg,peer.route)
        if not sent then pending=nil;Change("unknown",reason or "send_refused",peer);return false,reason end
        local request=pending
        if request then api.after(WAIT,function()
            if pending==request then local t=Clock();if t then Expire(t) end end
        end) end
        return true
    end
    function D.Receive(body,sender)
        body,sender=Text(body),Text(sender)
        if not body or not sender then return end
        local kind,nonce,client,rev,from,to=body:match("^([HA])|([%w%-]+)|(%a+)|(%d+)|([^|]+)|([^|]+)$")
        if not kind or #nonce>40 or #rev>3 or not Guid(from) or not Guid(to) or
            (client~="forever" and client~="retail") then return end
        local now,me=Clock(),Identity("player")
        if not now or not me or me.guid~=to or from==to then return end
        local key=Name(sender,api.kind,api.home())
        if not key or key==me.key then return end
        Expire(now)
        if not api.available() then return end
        if kind=="H" then
            -- Only reply to the actual event sender. No player stats, no
            -- chat text, no reply loops, globally bounded response rate.
            if now-lastReply<GAP then return end
            lastReply=now
            api.send(table.concat({"A",nonce,api.kind,PROTOCOL,me.guid,from},"|"),sender)
            return
        end
        local q=pending
        if not q or q.nonce~=nonce or q.peer.guid~=from or q.me~=to or q.peer.key~=key then return end
        pending=nil
        local compatible=client==api.kind and rev==PROTOCOL
        Change(compatible and "compatible" or "incompatible",
            compatible and "matching_reply" or "protocol_or_client_mismatch",q.peer,rev,now+TTL)
    end
    return D
end

local function Home() return Call(GetNormalizedRealmName) end
local function NoncePrefix()
    local t=Call(GetTime) or 0
    local epoch=Call(GetServerTime) or 0
    return tostring(math.floor(epoch)).."-"..tostring(math.floor(t*1000))
end
local live=Build({
    scope="LOCAL",kind=ns.Client.Kind(),now=function() return Call(GetTime) end,
    home=Home,noncePrefix=NoncePrefix(),
    identity=ns.Group.ReadPlayerIdentity,
    available=ns.Communication.IsAvailable,
    send=function(body,target) return ns.Communication.Send("D1",body,"WHISPER",target) end,
    after=function(delay,fn) if C_Timer and C_Timer.After then C_Timer.After(delay,fn) end end,
})
P.GetSnapshot=live.GetSnapshot
P.GetDiagnosticResources=live.GetDiagnosticResources
function P.ProbeTarget() return live.Probe("target") end
ns.Communication.Subscribe("D1",function(body,channel,sender)
    if channel=="WHISPER" then live.Receive(body,sender) end
end)
-- Automatic discovery only for a positively identified visible opponent.
-- Never substitute an unrelated target when the challenge identity is unknown.
ns.DuelDetection.Subscribe(function(s)
    if s.scope~="LOCAL" or s.state~="challenge" then return end
    local o=s.challenge and s.challenge.opponent
    if o and Guid(o.guid) then
        for _,unit in ipairs({"target","focus","mouseover"}) do
            local p=ns.Group.ReadPlayerIdentity(unit)
            if p and p.guid==o.guid then live.Probe(unit,o.guid);return end
        end
    end
end)
local frame=CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent",live.Reset)

-- Tests instantiate the identical protocol with private transport and time.
-- No simulated packet can be dispatched into the live receiver.
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local passed,failed=0,0
    local before=live.GetSnapshot().revision
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local function Check(v,why) assert(v,why) end
    local function Fixture(kind)
        local time,packets,ready=100,{},true
        local sep=kind=="forever" and " " or "-"
        local a={fullName="Alpha"..sep.."Home",guid="Player-1-AAA"}
        local b={fullName="Beta"..sep.."Other",guid="Player-2-BBB"}
        local function Make(me,other,tag)
            return Build({scope="SIMULATED",kind=kind,now=function()return time end,
                home=function()return "Home" end,noncePrefix=tag,
                identity=function(unit)return unit=="player" and me or unit=="target" and other end,
                available=function()return ready, "restricted" end,
                send=function(body,target) packets[#packets+1]={body=body,target=target,sender=me.fullName};return true end,
                after=function()end})
        end
        return {a=Make(a,b,"100-1"),b=Make(b,a,"100-2"),packets=packets,
            advance=function(n)time=time+n end,lock=function()ready=false end}
    end
    for _,kind in ipairs({"forever","retail"}) do
        Case(kind.." matching two-peer reply",function()
            local f=Fixture(kind)
            Check(f.a.Probe("target"),"probe failed")
            Check(f.a.GetSnapshot().state=="checking","send is not confirmation")
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            local a=f.packets[2];Check(a,"missing response")
            f.a.Receive(a.body,a.sender)
            local s=f.a.GetSnapshot()
            Check(s.state=="compatible" and s.scope=="SIMULATED" and not s.rankEligible,"matching response")
            local rev=s.revision
            f.a.Receive(a.body,a.sender)
            Check(f.a.GetSnapshot().revision==rev,"duplicate reply")
            f.advance(61)
            Check(f.a.GetSnapshot().state=="unknown","expired confirmation")
        end)
        Case(kind.." no reply / late reply",function()
            local f=Fixture(kind);f.a.Probe("target")
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            f.advance(9)
            local a=f.packets[2];f.a.Receive(a.body,a.sender)
            Check(f.a.GetSnapshot().state=="unknown","late reply confirmed")
        end)
        Case(kind.." sender, nonce and identity mismatch",function()
            local f=Fixture(kind);f.a.Probe("target")
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            local a=f.packets[2]
            f.a.Receive(a.body,"Stranger-Else")
            f.a.Receive(a.body:gsub("100%-1%-1","999-1-1"),a.sender)
            f.a.Receive(a.body:gsub("Player%-2%-BBB","Player-3-CCC"),a.sender)
            f.a.Receive("malformed",a.sender)
            Check(f.a.GetSnapshot().state=="checking","invalid packet confirmed")
            f.a.Receive(a.body,a.sender)
            Check(f.a.GetSnapshot().state=="compatible","valid response lost")
        end)
        Case(kind.." incompatible protocol",function()
            local f=Fixture(kind);f.a.Probe("target")
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            local a=f.packets[2]
            f.a.Receive(a.body:gsub("|1|","|2|",1),a.sender)
            Check(f.a.GetSnapshot().state=="incompatible","wrong revision accepted")
        end)
        Case(kind.." restriction, self, throttling",function()
            local f=Fixture(kind)
            Check(not f.a.Probe("player"),"self probe")
            Check(f.a.Probe("target"),"probe failed")
            Check(not f.a.Probe("target"),"duplicate probe sent")
            local h=f.packets[1];f.b.Receive(h.body,h.sender);f.b.Receive(h.body,h.sender)
            Check(#f.packets==2,"reply spam")
            f.lock();local a=f.packets[2];f.a.Receive(a.body,a.sender)
            Check(f.a.GetSnapshot().state=="checking","restricted reply accepted")
            f.advance(10);Check(not f.a.Probe("target"),"restricted send")
            Check(#f.packets==2,"restricted traffic")
        end)
        Case(kind.." world reset and snapshot isolation",function()
            local f=Fixture(kind);f.a.Probe("target")
            local s=f.a.GetSnapshot();s.opponent.guid="changed"
            Check(f.a.GetSnapshot().opponent.guid~="changed","mutable identity")
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            f.a.Reset();local a=f.packets[2];f.a.Receive(a.body,a.sender)
            Check(f.a.GetSnapshot().state=="idle","old reply after reset")
        end)
    end
    Case("live discovery untouched",function()Check(live.GetSnapshot().revision==before,"live revision changed")end)
    return passed,failed
end

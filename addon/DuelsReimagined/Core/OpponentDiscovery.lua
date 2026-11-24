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
-- Protocol bodies deliberately contain delimiters; identity fields do not.
local function Packet(v)
    v=Plain(v)
    if type(v)=="string" and #v>0 and #v<=237 and not v:find("%c") then return v end
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
    local listeners={}
    local confirmed,requester
    function D.Subscribe(fn)
        if type(fn)~="function" then return function()end end
        listeners[fn]=true;return function()listeners[fn]=nil end
    end
    local Expire
    local function Change(status,why,who,rev,untilTime,offer)
        state={state=status,reason=why,revision=state.revision+1,scope=api.scope,
            rankEligible=false,opponent=who,protocol=rev,expiresAt=untilTime,rankOffer=offer}
        for fn in pairs(listeners) do pcall(fn) end
        if untilTime and status~="checking" then
            local revision=state.revision
            local now=api.now()
            api.after(type(now)=="number" and math.max(0,untilTime-now) or TTL,function()
                if state.revision==revision then local t=api.now();if type(t)=="number" then Expire(t) end end
            end)
        end
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
    Expire=function(now)
        if pending and now>=pending.deadline then
            local who=pending.peer
            pending=nil
            Change("unknown","no_reply",who)
        elseif state.expiresAt and now>=state.expiresAt then
            confirmed=nil;Change("unknown","confirmation_expired",state.opponent)
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
    function D.GetDiagnosticResources()
        local n=0;for _ in pairs(listeners) do n=n+1 end
        return {pending=pending and 1 or 0,subscriptions=n}
    end
    function D.Reset()
        pending,confirmed,requester=nil,nil,nil
        Change("idle","reset")
    end
    function D.Probe(unit,expectedGuid,force)
        local now=Clock()
        if not now then return false,"clock_unavailable" end
        Expire(now)
        local me,peer=Identity("player"),Identity(unit)
        if not me or not peer or me.guid==peer.guid or me.key==peer.key or
            (expectedGuid and peer.guid~=expectedGuid) then return false,"identity_unavailable" end
        if pending or now-lastProbe<GAP then return false,"cooldown" end
        if not force and state.state=="compatible" and state.opponent and state.opponent.guid==peer.guid
            and state.expiresAt and now<state.expiresAt then return true,"recent_reply" end
        local available,why=api.available()
        if not available then Change("unknown",why or "restricted",peer);return false,why end
        seq=seq+1
        local nonce=api.noncePrefix.."-"..seq
        local msg=table.concat({"H",nonce,api.kind,PROTOCOL,me.guid,peer.guid},"|")
        lastProbe=now -- refused attempts also throttle
        confirmed=nil
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
    local function Offer()
        if type(api.rankOffer)~="function" then return nil end
        local ok,v=pcall(api.rankOffer)
        if ok and type(v)=="string" then return v end
    end
    local function Advertise(q,now)
        local offer=Offer()
        if q.advertised==offer and q.sent then return true end
        local reply=q.reply
        if offer and #reply+#offer+1<=237 then reply=reply.."|"..offer end
        lastReply=now
        if api.send(reply,q.route) then q.advertised=offer;q.sent=true;return true end
    end
    function D.PublishOffer()
        local q,now=requester,Clock()
        if not q or not now or now>=q.expires or not api.available() then return end
        if now-lastReply<GAP then
            if not q.queued then
                q.queued=true
                api.after(GAP-(now-lastReply),function()
                    q.queued=false
                    if requester==q then D.PublishOffer() end
                end)
            end
            return
        end
        Advertise(q,now)
    end
    function D.Receive(body,sender)
        body,sender=Packet(body),Text(sender)
        if not body or not sender then return end
        local kind,nonce,client,rev,from,to=body:match("^([HA])|([%w%-]+)|(%a+)|(%d+)|([^|]+)|([^|]+)$")
        local offer
        if not kind then
            kind,nonce,client,rev,from,to,offer=body:match("^(A)|([%w%-]+)|(%a+)|(%d+)|([^|]+)|([^|]+)|([RU]|%d+|[0-9a-f]+)$")
            if offer then
                local mode,epoch,fp=offer:match("^([RU])|(%d+)|([0-9a-f]+)$")
                if not mode or #fp~=64 or #epoch>10 then return end
            end
        end
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
            local q={reply=table.concat({"A",nonce,api.kind,PROTOCOL,me.guid,from},"|"),
                route=sender,expires=now+TTL}
            if Advertise(q,now) then requester=q end
            return
        end
        local q=pending
        if not q then
            -- A changed preference may refresh only the exact previously
            -- verified request, within its original lifetime. No unsolicited
            -- discovery or lifetime extension; final agreement is authoritative.
            q=confirmed
            if not q or now>=q.expires or q.nonce~=nonce or q.peer.guid~=from or
                q.me~=to or q.peer.key~=key or client~=api.kind or rev~=PROTOCOL then return end
            if state.rankOffer~=offer then Change("compatible","preference_updated",q.peer,rev,q.expires,offer) end
            return
        end
        if q.nonce~=nonce or q.peer.guid~=from or q.me~=to or q.peer.key~=key then return end
        pending=nil
        local compatible=client==api.kind and rev==PROTOCOL
        q.expires=now+TTL;confirmed=compatible and q or nil
        Change(compatible and "compatible" or "incompatible",
            compatible and "matching_reply" or "protocol_or_client_mismatch",q.peer,rev,q.expires,compatible and offer or nil)
    end
    return D
end

-- Explicit sandbox only; never returns or dispatches to the live receiver.
function P.NewSimulated(api)
    if type(api)~="table" or api.scope~="SIMULATED" then return nil end
    return Build(api)
end
local function Home() return Call(GetNormalizedRealmName) end
function P.NormalizeSender(sender) return Name(sender,ns.Client.Kind(),Home()) end
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
    rankOffer=function()
        local lifecycle=ns.CompetitiveLifecycle
        return lifecycle and lifecycle.GetRankOffer and lifecycle.GetRankOffer()
    end,
    send=function(body,target) return ns.Communication.Send("D1",body,"WHISPER",target) end,
    after=function(delay,fn) if C_Timer and C_Timer.After then C_Timer.After(delay,fn) end end,
})
P.GetSnapshot=live.GetSnapshot
P.GetDiagnosticResources=live.GetDiagnosticResources
P.Subscribe=live.Subscribe
P.PublishOffer=live.PublishOffer
function P.ProbeTarget(force) return live.Probe("target",nil,force==true) end
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
        local offer
        local sep=kind=="forever" and " " or "-"
        local a={fullName="Alpha"..sep.."Home",guid="Player-1-AAA"}
        local b={fullName="Beta"..sep.."Other",guid="Player-2-BBB"}
        local function Make(me,other,tag)
            return Build({scope="SIMULATED",kind=kind,now=function()return time end,
                home=function()return "Home" end,noncePrefix=tag,
                identity=function(unit)return unit=="player" and me or unit=="target" and other end,
                available=function()return ready, "restricted" end,
                rankOffer=function()return offer end,
                send=function(body,target) packets[#packets+1]={body=body,target=target,sender=me.fullName};return true end,
                after=function()end})
        end
        return {a=Make(a,b,"100-1"),b=Make(b,a,"100-2"),packets=packets,
            advance=function(n)time=time+n end,lock=function()ready=false end,
            setOffer=function(v)offer=v end}
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
        Case(kind.." rank preference update bound to verified request",function()
            local f=Fixture(kind);local fp=string.rep("a",64)
            f.setOffer("R|1000|"..fp);assert(f.a.Probe("target"))
            local h=f.packets[1];f.b.Receive(h.body,h.sender)
            local a=f.packets[2];f.a.Receive(a.body,a.sender)
            local expiry=f.a.GetSnapshot().expiresAt
            assert(f.a.GetSnapshot().rankOffer=="R|1000|"..fp)
            f.advance(4);f.setOffer("U|1000|"..fp);f.b.PublishOffer()
            local update=assert(f.packets[3]);f.a.Receive(update.body,"Stranger-Else")
            assert(f.a.GetSnapshot().rankOffer=="R|1000|"..fp)
            f.a.Receive(update.body,update.sender)
            assert(f.a.GetSnapshot().rankOffer=="U|1000|"..fp and f.a.GetSnapshot().expiresAt==expiry)
            f.advance(61);f.a.Receive(update.body,update.sender)
            assert(f.a.GetSnapshot().state=="unknown")
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
            f.a.Receive(a.body.."|extra",a.sender)
            f.a.Receive(a.body.."\n",a.sender)
            f.a.Receive(a.body,a.sender.."|extra")
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

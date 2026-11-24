local _, ns = ...

-- Single owner of LOCAL duel evidence. No UI, combat-log inference, protected
-- action, saved record, rating or peer communication. See docs/DUEL_DETECTION.md.
-- The same engine runs in independent instances. Only the live instance
-- receives real WoW APIs; the sandbox has its own clock, events and identities.
local function BuildDetector(ns, api)
local GetTime, CreateFrame, C_Timer = api.GetTime, api.CreateFrame, api.C_Timer
local hooksecurefunc, StartDuel, issecretvalue = api.hooksecurefunc, api.StartDuel, api.issecretvalue
local DUEL_COUNTDOWN, DUEL_WINNER_KNOCKOUT, DUEL_WINNER_RETREAT =
    api.countdown, api.knockout, api.retreat
local D = {}
local listeners, trace, capabilities = {}, {}, {}
local challenge, active, last
local cycle, revision = 0, 0
local state, reason = "unavailable", "initializing"
local WAIT, EXPIRE, TRACE_LIMIT = 2, 90, 24
local suppressDeath = false
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok, secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Text(v)
    v=Plain(v)
    if type(v)=="string" and #v>0 and #v<=2048 then return v end
end
local function Now()
    local ok,t=pcall(GetTime)
    if ok then
        t=Plain(t)
        if type(t)=="number" and t==t then return t end
    end
end
local function Copy(x)
    if type(x)~="table" then return x end
    local out={}
    for k,v in pairs(x) do out[k]=Copy(v) end
    return out
end
function D.GetSnapshot()
    return Copy({state=state,reason=reason,revision=revision,
        client=ns.Client.Kind(),scope=api.scope,challenge=challenge,active=active,last=last,
        capabilities=capabilities,trace=trace})
end
function D.Subscribe(fn)
    if type(fn)~="function" then return function() end end
    listeners[fn]=true
    return function() listeners[fn]=nil end
end
local function Publish(nextState,why)
    state,reason=nextState,why
    revision=revision+1
    trace[#trace+1]={time=Now(),state=state,reason=why,
        cycle=active and active.id or last and last.id or nil}
    if #trace>TRACE_LIMIT then table.remove(trace,1) end
    for fn in pairs(listeners) do pcall(fn,D.GetSnapshot()) end
end

-- Compile only the client's own localized strings. Ordered and positional
-- fields supported; unknown formatting fails closed instead of guessing.
local function Compile(format, expected)
    format=Text(format)
    if not format then return nil end
    local parts, order, used = {"^"}, {}, {}
    local i=1
    while i<=#format do
        local c=format:sub(i,i)
        if c=="%" then
            local rest=format:sub(i)
            if rest:sub(1,2)=="%%" then
                parts[#parts+1]="%%"; i=i+2
            else
                local pos,kind=rest:match("^%%(%d+)%$([sd])")
                local consumed
                if pos then consumed=#pos+3; pos=tonumber(pos)
                else
                    kind=rest:match("^%%([sd])")
                    pos=#order+1; consumed=2
                end
                if not kind or not expected[pos] or used[pos] or expected[pos]~=kind then
                    return nil
                end
                used[pos]=true; order[#order+1]=pos
                parts[#parts+1]=kind=="d" and "(%d+)" or "(.+)"
                i=i+consumed
            end
        else
            if c:match("[%^%$%(%)%%%.%[%]%*%+%-%?]") then c="%"..c end
            parts[#parts+1]=c; i=i+1
        end
    end
    if #order~=#expected then return nil end
    parts[#parts+1]="$"
    return {pattern=table.concat(parts),order=order}
end
local function Match(rule,text)
    if not rule then return nil end
    local captures={text:match(rule.pattern)}
    if #captures~=#rule.order then return nil end
    local args={}
    for i,pos in ipairs(rule.order) do args[pos]=captures[i] end
    return args
end
local rules={
    countdown=Compile(DUEL_COUNTDOWN,{"d"}),
    knockout=Compile(DUEL_WINNER_KNOCKOUT,{"s","s"}),
    retreat=Compile(DUEL_WINNER_RETREAT,{"s","s"}),
}

-- Keep full surnames on Forever; never drop a Retail realm. A short Retail
-- name may correspond to a full name, but ambiguous roles are rejected.
local function Name(value)
    local s=Text(value)
    if not s then return nil end
    s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        :gsub("|Hplayer:[^|]+|h%[([^%]]+)%]|h","%1")
        :gsub("^%s+",""):gsub("%s+$","")
    if #s==0 or #s>160 or s:find("[%c|%[%]]") then return nil end
    if ns.Client.IsForever() then
        s=s:gsub("%-"," "):gsub("%s+"," ")
        return {display=s,key=s:lower()}
    end
    local first,realm=s:match("^([^%-]+)%-(.+)$")
    first=first or s
    return {display=s,key=s:lower(),first=first:lower(),
        realm=realm and realm:lower():gsub("[%s%-]","") or nil}
end
local function Same(a,b)
    if not a or not b then return false end
    if ns.Client.IsForever() then return a.key==b.key end
    if a.first~=b.first then return false end
    return not a.realm or not b.realm or a.realm==b.realm
end
local function Identity(unit)
    local raw=ns.Group.ReadPlayerIdentity(unit)
    if not raw then return nil end
    local n=Name(raw.fullName)
    if n then n.guid=raw.guid end
    return n
end
local function Resolve(name)
    if not name then return nil end
    if name.guid then return name end
    local found, ambiguous
    local function Check(unit)
        local id=Identity(unit)
        -- Do not attach a GUID by a short-name-only Retail match.
        local exact=id and (ns.Client.IsForever() and name.key==id.key or
            not ns.Client.IsForever() and name.realm and id.realm and Same(name,id))
        if exact then
            if found and (found.key~=id.key or
                (found.guid and id.guid and found.guid~=id.guid)) then
                ambiguous=true
            elseif not found or (not found.guid and id.guid) then
                found=id
            end
        end
    end
    for _,unit in ipairs({"target","focus","mouseover"}) do Check(unit) end
    -- One bounded scan at a duel transition only; no nameplate event
    -- subscription, permanent timer or frame updates.
    for i=1,40 do Check("nameplate"..i) end
    if not ambiguous and found then return found end
    return name
end

local function Finalize(why,allowResult)
    local d=active
    if not d then return end
    local result=allowResult and d.result and d.finishSeen and not d.conflict
        and d.result or nil
    active,challenge=nil,nil
    last={id=d.id,client=ns.Client.Kind(),scope=api.scope,
        kind=d.kind,direction=d.direction,opponent=Copy(d.opponent),
        acceptedAt=d.acceptedAt,endedAt=Now(),
        outcome=result and result.outcome or "unknown",
        endType=result and result.endType or nil,
        outcomeObserved=result~=nil,finishObserved=d.finishSeen==true,
        resultObserved=d.result~=nil,conflict=d.conflict==true,
        reason=why,rankEligible=false}
    Publish("idle",why)
end
local function Await(d)
    if d.waiting then return end
    d.waiting=true
    C_Timer.After(WAIT,function()
        if active~=d then return end
        Finalize(d.conflict and "conflicting_result" or
            (d.finishSeen and "result_not_observed" or "finish_not_observed"),false)
    end)
end
local function Challenge(name,direction,kind)
    if active then
        -- Another request during a confirmed countdown is not proof that
        -- our duel ended or switched to another player.
        return
    end
    if challenge and challenge.direction==direction and challenge.kind==kind and
        ((not name and not challenge.opponent) or
         (name and challenge.opponent and name.key==challenge.opponent.key)) then
        return -- repeated delivery of the same request
    end
    local c={opponent=Resolve(name),direction=direction,kind=kind,time=Now()}
    challenge=c
    suppressDeath=kind=="death_duel"
    Publish("challenge",direction=="outgoing" and "outgoing_attempt" or "incoming_request")
    C_Timer.After(EXPIRE,function()
        if challenge==c and not active then
            challenge=nil
            -- Preserve known death-duel exclusion until finish/world reset
            -- or a fresh ordinary challenge; don't convert it into a duel.
            Publish("idle","challenge_expired")
        end
    end)
end
local function StartCountdown(n)
    if suppressDeath then return end
    if active then
        if not active.finishSeen and not active.result and
            (not active.countdown or n<active.countdown) then
            active.countdown=n
            Publish("accepted","countdown_observed")
        end
        return
    end
    -- Never reopen a completed cycle from a repeated tail of its countdown.
    local now=Now()
    if not challenge and last and now and last.endedAt and
        now-last.endedAt<WAIT then return end
    cycle=cycle+1
    active={id=cycle,kind=challenge and challenge.kind or "unclassified",
        direction=challenge and challenge.direction or "unknown",
        opponent=challenge and challenge.opponent,
        player=Identity("player"),acceptedAt=now,countdown=n}
    challenge=nil
    Publish("accepted","countdown_observed")
end
local function Result(args,endType)
    local d=active
    if not d or suppressDeath then return end
    local winner,loser=Name(args[1]),Name(args[2])
    local me=d.player or Identity("player")
    if not me or not winner or not loser then return end
    local win,lose=Same(me,winner),Same(me,loser)
    if win==lose or Same(winner,loser) then return end
    local other=win and loser or winner
    if d.opponent and not Same(d.opponent,other) then return end
    if d.result then
        if d.result.endType~=endType or
            d.result.outcome~=(endType=="retreat" and (win and "they_fled" or "fled") or (win and "won" or "lost")) then
            d.conflict=true
            Publish("finishing","conflicting_result")
        end
        return
    end
    local resolved=Resolve(other)
    if d.opponent and d.opponent.guid and resolved and resolved.guid and
        d.opponent.guid~=resolved.guid then return end
    if not d.opponent or not d.opponent.guid then d.opponent=resolved end
    d.result={endType=endType,outcome=endType=="retreat" and
        (win and "they_fled" or "fled") or (win and "won" or "lost")}
    if d.finishSeen then Finalize("matching_result_and_finish",true)
    else
        Publish("finishing","result_waiting_for_finish")
        Await(d)
    end
end
local function Finish()
    if suppressDeath then
        suppressDeath=false; challenge=nil
        if active then Finalize("death_duel_excluded",false)
        else Publish("idle","death_duel_excluded") end
        return
    end
    if not active then
        if challenge then challenge=nil; Publish("idle","challenge_closed_without_countdown") end
        return
    end
    local d=active
    if d.finishSeen then return end
    d.finishSeen=true
    if d.result then Finalize(d.conflict and "conflicting_result" or "matching_result_and_finish",true)
    else
        Publish("finishing","finish_waiting_for_result")
        Await(d)
    end
end
local function System(message)
    local text=Text(message)
    if not text then return end
    local countdown=Match(rules.countdown,text)
    if countdown then
        local n=tonumber(countdown[1])
        if n and n>=0 and n<=10 then StartCountdown(n) end
        return
    end
    local knockout=Match(rules.knockout,text)
    if knockout then Result(knockout,"knockout"); return end
    local retreat=Match(rules.retreat,text)
    if retreat then Result(retreat,"retreat") end
end
local function ResetWorld()
    challenge=nil; suppressDeath=false
    if active then Finalize("world_transition",false)
    elseif state~="idle" then Publish("idle","world_transition") end
end
function D.PrintStatus(verbose)
    local s=D.GetSnapshot()
    print("Duels Reimagined | "..api.scope.." detector: "..s.state.." ("..s.reason..") | "..s.client)
    local current=s.active or s.challenge
    if current then
        print("Opponent: "..(current.opponent and current.opponent.display or "not observed"))
    end
    if s.last then
        print("Last local duel #"..s.last.id..": "..s.last.outcome.." | "..
            (s.last.opponent and s.last.opponent.display or "opponent not observed")..
            " | "..s.last.reason.." | rank disabled")
    else print("No completed duel observed this session.") end
    if verbose then
        for _,k in ipairs({"request","finish","system","world","death","outgoing","countdown","knockout","retreat"}) do
            print(k..": "..(s.capabilities[k] and "available" or "not available"))
        end
        for _,e in ipairs(s.trace) do
            print(string.format("%.2f %s: %s",e.time or 0,e.state,e.reason))
        end
    end
end

capabilities.countdown=rules.countdown~=nil
capabilities.knockout=rules.knockout~=nil
capabilities.retreat=rules.retreat~=nil
if not ns.Client.IsSupported() or not ns.Group.ReadPlayerIdentity or
    type(CreateFrame)~="function" or type(GetTime)~="function" or
    not C_Timer or type(C_Timer.After)~="function" then
    Publish("unavailable","unsupported_client_or_api")
    return D
end
local driver=CreateFrame("Frame")
local function Register(key,event)
    local ok=pcall(driver.RegisterEvent,driver,event)
    capabilities[key]=ok
end
Register("request","DUEL_REQUESTED")
Register("finish","DUEL_FINISHED")
Register("system","CHAT_MSG_SYSTEM")
Register("world","PLAYER_ENTERING_WORLD")
Register("death","DUEL_TO_THE_DEATH_REQUESTED")
if not (capabilities.finish and capabilities.system and capabilities.world and
    capabilities.countdown and capabilities.knockout and capabilities.retreat) then
    driver:UnregisterAllEvents()
    Publish("unavailable","required_evidence_unavailable")
    return D
end
driver:SetScript("OnEvent",function(_,event,value)
    if event=="DUEL_REQUESTED" then
        Challenge(Name(value),"incoming","standard")
    elseif event=="DUEL_TO_THE_DEATH_REQUESTED" then
        Challenge(Name(value),"incoming","death_duel")
    elseif event=="CHAT_MSG_SYSTEM" then System(value)
    elseif event=="DUEL_FINISHED" then Finish()
    elseif event=="PLAYER_ENTERING_WORLD" then ResetWorld() end
end)
if type(hooksecurefunc)=="function" and type(StartDuel)=="function" then
    capabilities.outgoing=pcall(hooksecurefunc,"StartDuel",function(unit)
        unit=Text(unit)
        if unit=="player" then return end -- targeting cursor, not an invitation
        local id=unit and Identity(unit)
        if id then Challenge(id,"outgoing","unclassified")
        else
            -- Explicit names are supported only when a visible unit supplies
            -- matching full identity. Never silently substitute current target.
            local named=unit and Resolve(Name(unit))
            Challenge(named and named.guid and named or nil,"outgoing","unclassified")
        end
    end)
end
-- No automatic actions and no hooks to combat-state events. Actual finish
-- evidence and the localized result line, not combat, decide the outcome.
Publish("idle","detector_ready")

return D
end

local live = BuildDetector(ns,{
    scope="LOCAL", GetTime=GetTime, CreateFrame=CreateFrame, C_Timer=C_Timer,
    hooksecurefunc=hooksecurefunc, StartDuel=StartDuel, issecretvalue=issecretvalue,
    countdown=DUEL_COUNTDOWN, knockout=DUEL_WINNER_KNOCKOUT, retreat=DUEL_WINNER_RETREAT,
})
ns.DuelDetection=live

-- Only this explicitly simulated constructor is exposed. No caller can
-- dispatch fake signals into the live instance or replace the real APIs.
function live.NewSandbox(kind, currentLocale, missing)
    if kind~="forever" and kind~="retail" then return nil end
    local clock, timers, hooks = 0, {}, {}
    local hidden={}
    local frame={events={},scripts={}}
    function frame:RegisterEvent(event)
        if event==missing then error("SIMULATED unavailable event") end
        self.events[event]=true
    end
    function frame:UnregisterAllEvents() self.events={} end
    function frame:SetScript(key,fn) self.scripts[key]=fn end
    local sep=kind=="forever" and " " or "-"
    local people={
        player={fullName="TestAlpha"..sep.."Home",guid="SIMULATED-1"},
        target={fullName="TestBeta"..sep.."Other",guid="SIMULATED-2"},
    }
    local formats={
        countdown="Duel starting: %d",
        knockout="%1$s has defeated %2$s in a duel",
        retreat="%2$s has fled from %1$s in a duel",
    }
    if currentLocale then
        formats.countdown=DUEL_COUNTDOWN
        formats.knockout=DUEL_WINNER_KNOCKOUT
        formats.retreat=DUEL_WINNER_RETREAT
    end
    local fakeNS={
        Client={Kind=function() return kind end,IsSupported=function() return true end,
            IsForever=function() return kind=="forever" end},
        Group={ReadPlayerIdentity=function(unit) return people[unit] end},
    }
    local d=BuildDetector(fakeNS,{
        scope="SIMULATED",GetTime=function() return clock end,
        CreateFrame=function() return frame end,
        C_Timer={After=function(delay,fn)
            timers[#timers+1]={at=clock+delay,fn=fn}
        end},
        hooksecurefunc=function(key,fn) hooks[key]=fn end,
        StartDuel=function() error("SIMULATED action forbidden") end,
        issecretvalue=function(v) return v==hidden end,
        countdown=formats.countdown,knockout=formats.knockout,retreat=formats.retreat,
    })
    local box={detector=d,people=people,hidden=hidden,formats=formats}
    function box.Fire(event,value)
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame,event,value)
        end
    end
    function box.Outgoing(unit)
        local callback=hooks.StartDuel
        if callback then callback(unit) end
    end
    function box.Advance(seconds)
        local untilTime=clock+seconds
        while true do
            local best
            for i,job in ipairs(timers) do
                if job.at<=untilTime and (not best or job.at<timers[best].at) then best=i end
            end
            if not best then break end
            local job=table.remove(timers,best)
            clock=job.at
            job.fn()
        end
        clock=untilTime
    end
    return box
end

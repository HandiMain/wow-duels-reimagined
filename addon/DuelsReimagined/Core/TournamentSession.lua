local _,ns=...
-- Private registration transport adapter. The existing Communication,
-- Group, TournamentRegistration and CompetitiveStorage modules own all
-- transport, identity, registration semantics and persistence respectively.
local L={};ns.TournamentSession=L
local Store,Group,Comm,R,P=ns.CompetitiveStorage,ns.Group,ns.Communication,ns.TournamentRegistration,ns.CompetitiveScope
local active,unsubscribe,unroster,timer,queue
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if not ok then return nil end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,v)
        if not safe or secret then return nil end
    end
    return v
end
local function Clock()
    local n=Read(GetServerTime)
    if type(n)=="number" and n>=1 and n<=4102444800 and n==math.floor(n) then return n end
end
local function Guid(v) return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
local function Actor(unit,s)
    local id=Group.ReadCompetitiveIdentity(unit)
    local level=Read(UnitLevel,unit)
    if not id or not Guid(id.guid) or id.faction~=s.faction or type(id.fullName)~="string"
        or type(level)~="number" or level<1 or level>255 or level~=math.floor(level) then return nil end
    local actor={guid=id.guid,name=id.fullName,level=level,client=s.client,region=s.region,ruleset=s.ruleset,faction=s.faction}
    return actor
end
local function Roster()
    local v=Group.GetSnapshot()
    if v and v.complete and not v.stale and (v.mode=="party" or v.mode=="raid") then return v end
end
local function Name(v)
    return ns.OpponentDiscovery.NormalizeSender(v)
end
-- Match the client-supplied sender to exactly one currently observed
-- group member, then re-read the unit GUID, name, faction and level.
-- Packet body never supplies a trusted actor.
local function Resolve(s,own,sender,guid)
    local roster=Roster()
    if not roster then return nil end
    local wanted=sender and Name(sender)
    if sender and not wanted then return nil end
    local found
    for _,m in ipairs(roster.members) do
        if m.guid~=own and ((guid and m.guid==guid) or (wanted and Name(m.fullName)==wanted)) then
            if found then return nil end
            found=m
        end
    end
    if not found or found.online~=true then return nil end
    local a=Actor(found.unit,s)
    if not a or a.guid~=found.guid or Name(a.name)~=Name(found.fullName) then return nil end
    return a
end
function L.IsActive() return active~=nil end
function L.CanCommunicate()
    if not Store.TournamentTestEnabled() or not active then return false end
    local s=P.GetCurrent()
    if P.Key(s)~=active.key or Read(InCombatLockdown)~=false then return false end
    local me=Group.ReadPlayerIdentity("player")
    return me and me.guid==active.actor.guid and Roster()~=nil or false
end
local function ClearQueue()
    if timer then timer:Cancel();timer=nil end
    queue={}
end
local function Stop()
    ClearQueue()
    if unsubscribe then unsubscribe();unsubscribe=nil end
    if unroster then unroster();unroster=nil end
    active=nil
end
local function Pump()
    if not active or not L.CanCommunicate() or not Comm.IsAvailable() then ClearQueue();return end
    local row=queue[1]
    if not row then return end
    local a=Resolve(active.scope,active.actor.guid,nil,row.guid)
    if not a then ClearQueue();return end
    local ok,why=Comm.Send("T1",row.body,"WHISPER",a.name)
    active.sendStatus=ok and "Request sent; delivery not confirmed." or "Send refused; retry explicitly ("..tostring(why)..")."
    if not ok then ClearQueue();return end
    table.remove(queue,1)
    if #queue>0 then
        timer=C_Timer.NewTimer(.25,function()timer=nil;Pump()end)
    end
end
local function Send(guid,bodies)
    if not L.CanCommunicate() or not Comm.IsAvailable() then return false,"Communication unavailable." end
    if not Resolve(active.scope,active.actor.guid,nil,guid) then return false,"Player not confirmed in your group." end
    if type(bodies)~="table" or #bodies<1 or #bodies>12 or #queue+#bodies>48 then return false,"Reply queue is full." end
    if type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then return false,"Timer unavailable." end
    for _,body in ipairs(bodies) do
        if type(body)~="string" or #body<1 or #body>237 then return false,"Invalid message." end
    end
    for _,body in ipairs(bodies) do queue[#queue+1]={guid=guid,body=body} end
    if not timer then Pump() end
    return true,"Request queued; confirmation required."
end
local function Receive(body,channel,sender)
    if not L.CanCommunicate() or channel~="WHISPER" then return end
    local a=Resolve(active.scope,active.actor.guid,sender)
    if not a then return end
    if active.role=="host" then
        local replies=active.engine.Receive(sender,body)
        if replies then Send(a.guid,replies) end
    else
        local ok,why=active.engine.Receive(sender,body)
        if ok and why~="partial" then active.receipt=why end
    end
end
local function Open(role)
    if not Store.TournamentTestEnabled() then return false,"Private tournament network test is disabled in this build." end
    if active then return false,"Stop the current network session first." end
    if R.PreviewState() or R.TestListings() then return false,"End the local simulation first." end
    if not Roster() or Read(InCombatLockdown)~=false or not Comm.IsAvailable() then return false,"Join a readable group outside combat." end
    local s=P.GetCurrent();local key=P.Key(s)
    local actor=key and Actor("player",s)
    if not actor or not Clock() then return false,"Character or community unavailable." end
    local store={ReadTournamentJournal=Store.ReadTournamentTestJournal,CommitTournamentJournal=Store.CommitTournamentTestJournal}
    local function resolve(sender) return Resolve(s,actor.guid,sender) end
    local engine,cache=R.OpenRegistrationSession(s,actor,Clock,resolve,store,role)
    if not engine then return false,"Journal unavailable or committed to another role/community." end
    active={scope=s,key=key,actor=actor,role=role,engine=engine,cache=cache}
    queue={}
    unsubscribe=Comm.Subscribe("T1",Receive)
    unroster=Group.Subscribe(function()
        if not L.CanCommunicate() then ClearQueue() end
    end)
    return true,"Private "..role.." session opened. Registration only; no rating."
end
local function SelectedTarget()
    local id=Group.ReadPlayerIdentity("target")
    return id and Guid(id.guid) and Resolve(active.scope,active.actor.guid,nil,id.guid)
end
function L.Command(command)
    if command=="status" then
        if not Store.TournamentTestEnabled() then return true,"Private tournament network test disabled." end
        if not active then return true,"No private tournament network session." end
        local detail=active.role=="player" and active.engine.Status() or active.engine.Snapshot()
        local state=active.role=="player" and (detail and detail.status or "not registered")
            or detail and detail.ad and detail.ad.state or "no event"
        return true,active.role.." | "..state.." | "..(active.receipt or "No receipt").." | "..(active.sendStatus or "No sends")
    end
    if command=="stop" then Stop();return true,"Network session closed. Durable commitments retained." end
    if command=="host" or command=="player" then return Open(command) end
    if not L.CanCommunicate() then return false,"Open a private network session outside combat first." end
    local d=active.engine
    if active.role=="host" then
        if command=="publish" then
            local draft=ns.TournamentState.GetDraft()
            if not draft then return false,"Save a tournament draft first." end
            local ad=d.Publish(draft)
            return ad~=nil,ad and "Private group tournament published; players may query you." or "Publication refused."
        elseif command=="cancel" then
            local snap=d.Snapshot()
            local ok=snap and d.Cancel(active.actor.guid,snap.ad.id)
            return not not ok,ok and "Tournament cancelled. Participants must request status." or "Cancellation refused."
        elseif command=="roster" then
            local snap=d.Snapshot()
            if not snap then return false,"No tournament." end
            local lines={snap.ad.draft.name}
            for _,m in ipairs(snap.roster) do lines[#lines+1]=m.name..(m.checkedIn and " (checked in)" or " (registered)") end
            return true,table.concat(lines,"\n")
        end
    elseif active.role=="player" then
        if command=="browse" then
            local rows=active.cache.Browse();local lines={}
            for i,ad in ipairs(rows) do lines[#lines+1]=i..". "..ad.draft.name.." - "..ad.organizer end
            return true,#lines>0 and table.concat(lines,"\n") or "No fresh owner-confirmed tournament."
        end
        local body,owner
        if command=="query" then
            local a=SelectedTarget();if not a then return false,"Target the organizer in your group." end
            owner=a.guid;body=d.Query(owner)
        elseif command:match("^join %d+$") then
            local rows=active.cache.Browse()
            local ad=rows[tonumber(command:match("%d+$"))]
            if not ad then return false,"Browse and choose a fresh tournament." end
            owner=ad.owner;body=d.Join(owner,ad.id)
        elseif command=="leave" or command=="checkin" or command=="refresh" then
            local status=d.Status()
            owner=status and status.owner
            body=d.Action(command=="leave" and "L" or command=="checkin" and "C" or "S")
        elseif command=="retry" then
            body=d.Retry();owner=d.PendingOwner()
        end
        if owner and body then return Send(owner,{body}) end
    end
    return false,"Action unavailable or a request is still pending. Use status or retry."
end
function L.GetDiagnosticResources()
    return {subscriptions=(unsubscribe and 1 or 0)+(unroster and 1 or 0),timers=timer and 1 or 0,pending=queue and #queue or 0}
end
-- No listeners or timer while disabled/idle. Combat clears unsent packets,
-- world/logout closes the session; durable pending requests survive.
local frame=CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent",function(_,event)
    if not active then return end
    if event=="PLAYER_REGEN_DISABLED" then ClearQueue() else Stop() end
end)
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament network / private registration gate","health",function()
        if not Store.TournamentTestEnabled() then return "SKIP","Private network activation locked; no live tournament messages or writes." end
        return "SKIP","Private registration adapter enabled; requires consenting group members and live verification."
    end)
end

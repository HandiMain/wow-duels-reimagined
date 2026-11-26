local _,ns=...
-- Private registration transport adapter. The existing Communication,
-- Group, TournamentRegistration and CompetitiveStorage modules own all
-- transport, identity, registration semantics and persistence respectively.
local L={};ns.TournamentSession=L
local Store,Group,Comm,R,P=ns.CompetitiveStorage,ns.Group,ns.Communication,ns.TournamentRegistration,ns.CompetitiveScope
local active,unsubscribe,unroster,timer,queue,frame
local syncTimer,fetch,seatTimer,seatLink
local echoTimer,echo,graceTimer,graceTicking
local RefreshGrace
local pageFlags
local autoTimer
local autoPending={}
local ScheduleRefresh,PublishAdvisory,PublishGrace
local hintTimer,remoteGraceTimer,fanTimer
local hintPending={}
local function ClearRemoteGrace()
    if remoteGraceTimer then remoteGraceTimer:Cancel();remoteGraceTimer=nil end
    local old=active and active.remoteGrace
    if active then active.remoteGrace=nil end
    if old and ns.Notifications and ns.Notifications.ClearPrivateTournamentGrace then
        ns.Notifications.ClearPrivateTournamentGrace(old.event,old.match,old.sequence)
    end
end
local function StopHints()
    if hintTimer then hintTimer:Cancel();hintTimer=nil end
    if fanTimer then fanTimer:Cancel();fanTimer=nil end
    hintPending={}
    if active and active.role=="host" then active.advisedSignature=nil;active.advisory=nil end
    ClearRemoteGrace()
end
local function StopAuto()
    if autoTimer then autoTimer:Cancel();autoTimer=nil end
    autoPending={}
end
local function StopEcho()
    if echoTimer then echoTimer:Cancel();echoTimer=nil end
    echo=nil
end
local function StopGrace()
    local observing=graceTimer or active and active.grace
    if graceTimer then graceTimer:Cancel();graceTimer=nil end
    if active then
        local old=active.grace;active.grace=nil
        if old then
            if ns.Notifications and ns.Notifications.ClearPrivateTournamentGrace then ns.Notifications.ClearPrivateTournamentGrace(old.event,old.match,old.sequence) end
            if PublishGrace then PublishGrace({event=old.event,match=old.match,player=old.player,sequence=old.sequence,notice="interrupted"}) end
        end
        if observing and active.role=="host" then active.engine.ResetPrivateObservation() end
    end
end
local function CloseSeatLink()
    if seatTimer then seatTimer:Cancel();seatTimer=nil end
    if seatLink then seatLink.Close();seatLink=nil end
end
local function Changed()
    pageFlags=nil
    if RefreshGrace then RefreshGrace() end
    if PublishAdvisory then PublishAdvisory() end
    if ns.DuelHUD and ns.DuelHUD.Refresh then ns.DuelHUD.Refresh() end
    if ns.TournamentUI and ns.TournamentUI.RefreshActive then ns.TournamentUI.RefreshActive() end
end
local function StopFetch()
    if syncTimer then syncTimer:Cancel();syncTimer=nil end
    fetch=nil
end
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
    CloseSeatLink()
    StopGrace();StopHints();StopAuto();StopFetch();StopEcho()
    if active and active.role=="host" and active.engine.CloseSession then active.engine.CloseSession() end
    ClearQueue()
    if unsubscribe then unsubscribe();unsubscribe=nil end
    if unroster then unroster();unroster=nil end
    if frame then frame:UnregisterAllEvents() end
    active=nil
    Changed()
end
local function Pump()
    if not active or not L.CanCommunicate() or not Comm.IsAvailable() then ClearQueue();return false,"Communication unavailable." end
    local row=queue[1]
    if not row then return true end
    local a=Resolve(active.scope,active.actor.guid,nil,row.guid)
    if not a then ClearQueue();return false,"Recipient unavailable." end
    local ok,why=Comm.Send("T1",row.body,"WHISPER",a.name)
    active.sendStatus=ok and "Request sent; delivery not confirmed." or "Send refused; retry explicitly ("..tostring(why)..")."
    if not ok then ClearQueue();return false,why end
    table.remove(queue,1)
    if #queue>0 then
        timer=C_Timer.NewTimer(.25,function()timer=nil;Pump()end)
    end
    return true
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
    if not timer then
        local ok,why=Pump()
        if not ok then return false,"Send refused or unavailable ("..tostring(why).."). Retry explicitly." end
    end
    return true,"Request submitted to the transport; check status for confirmation."
end
-- Best effort advisory fanout; reliable replies keep the existing queue.
-- Do not enqueue new hints when the reply queue is already busy.
local function DrainHints()
    fanTimer=nil
    if not active or active.role~="host" or not L.CanCommunicate() then hintPending={};return end
    local now=Clock()
    if not now then hintPending={};return end
    while hintPending[1] and hintPending[1].expires<=now do table.remove(hintPending,1) end
    if #hintPending==0 then return end
    if #queue==0 and not timer then
        local row=table.remove(hintPending,1)
        if Resolve(active.scope,active.actor.guid,nil,row.guid) then Send(row.guid,{row.body}) end
    end
    if #hintPending>0 then fanTimer=C_Timer.NewTimer(.5,DrainHints) end
end
local function HintSend(guid,body)
    local now=Clock()
    if not now or #body>237 or not Resolve(active.scope,active.actor.guid,nil,guid) then return false end
    -- Only coalesce within the same tournament; a new cup cannot erase an old terminal notice.
    local event=body:match("^B|[^|]+|([^|]+)|")
    if event then
        for i=#hintPending,1,-1 do
            local row=hintPending[i]
            if row.guid==guid and row.body:match("^B|[^|]+|([^|]+)|")==event then
                if row.body:match("|terminal$") and not body:match("|terminal$") then return true end
                if row.body:match("|drawn$") and body:match("|match$") then body=body:gsub("|match$","|drawn") end
                table.remove(hintPending,i)
            end
        end
    end
    if #hintPending>=96 then return false end
    hintPending[#hintPending+1]={guid=guid,body=body,expires=now+45}
    if not fanTimer then fanTimer=C_Timer.NewTimer(.5,DrainHints) end
    return true
end
-- Bracket/control changes affect every checked-in entrant; readiness alone
-- targets the current and previous assigned pair. No result data in hints.
function L.AdvisoryRecipients(prev,n)
    local targets={}
    local terminal=n.phase=="completed" or n.phase=="cancelled"
    local all=n.phase=="drawn" and (not prev or prev.id~=n.id or prev.progress~=n.progress)
    for _,m in ipairs(n.peers) do
        local assigned=m.guid==n.first or m.guid==n.second or prev and prev.id==n.id and (m.guid==prev.first or m.guid==prev.second)
        if terminal or m.checked and (all or assigned) then
            targets[#targets+1]={guid=m.guid,kind=terminal and "terminal" or all and "drawn" or "match"}
        end
    end
    return targets
end
local function FlushAdvisory(owner)
    if active~=owner or not L.CanCommunicate() then return end
    local n=owner.engine.PrivateAdvisory()
    if not n or owner.advisedSignature==n.signature then return end
    for _,m in ipairs(L.AdvisoryRecipients(owner.advisory,n)) do
        HintSend(m.guid,table.concat({"B",owner.key,n.id,n.revision,m.kind},"|"))
    end
    owner.advisory=n;owner.advisedSignature=n.signature
end
PublishAdvisory=function()
    if not active or active.role~="host" or not L.CanCommunicate() then return end
    local v=active.engine.PrivateAdvisory()
    if not v or active.advisedSignature==v.signature then return end
    if v.phase=="completed" or v.phase=="cancelled" then
        -- Capture terminal recipients before a subsequent publication changes the checkpoint.
        if hintTimer then hintTimer:Cancel();hintTimer=nil end
        FlushAdvisory(active);return
    end
    if hintTimer then return end
    local owner=active
    hintTimer=C_Timer.NewTimer(1.5,function() hintTimer=nil;FlushAdvisory(owner) end)
end
PublishGrace=function(o)
    if not active or active.role~="host" or not L.CanCommunicate() or not o.notice or not o.sequence then return end
    local n=active.engine.PrivateAdvisory()
    local now=Clock()
    if not n or n.id~=o.event or not now or not Guid(o.player) then return end
    local deadline=o.notice=="started" and now+math.min(300,o.remaining or 300) or 0
    local body=table.concat({"D",active.key,n.id,o.match,o.player,o.sequence,o.notice,deadline},"|")
    for _,m in ipairs(n.peers) do if m.checked then HintSend(m.guid,body) end end
end
local function EchoNext()
    if not echo or not L.CanCommunicate() then StopEcho();return false,"Acknowledgement interrupted." end
    local body,last=echo.reader.Next()
    if not body then StopEcho();return false,"Acknowledgement page unavailable." end
    local ok,why=Send(echo.owner,{body})
    if not ok then StopEcho();return false,why end
    if last then
        echoTimer=C_Timer.NewTimer(30,function()
            echoTimer=nil
            if echo then StopEcho();active.receipt="Exact log acknowledgement not confirmed; retry.";Changed() end
        end)
    else echoTimer=C_Timer.NewTimer(.75,function()echoTimer=nil;EchoNext()end) end
    return true,"Sending exact organizer log acknowledgement."
end
-- Unknown includes missing/ambiguous group units, unreadable secret values,
-- unavailable API, and any non-boolean return. Only explicit false is offline.
local function ConnectionStates()
    local out={};local roster=Roster()
    if not roster then return out end
    for _,m in ipairs(roster.members) do
        if Guid(m.guid) and Read(UnitGUID,m.unit)==m.guid then
            local v=Read(UnitIsConnected,m.unit)
            out[m.guid]=v==true and "online" or v==false and "offline" or "unknown"
        end
    end
    return out
end
local function TickGrace()
    graceTimer=nil
    if not active or active.role~="host" or not L.CanCommunicate() then StopGrace();return end
    local a=active.engine.PrivateOffer()
    if not a then StopGrace();return end
    graceTicking=true
    Group.Refresh()
    local states=ConnectionStates()
    local observed=active.engine.ObserveMatch(a.match,{[a.player1]=states[a.player1] or "unknown",[a.player2]=states[a.player2] or "unknown"},a.term,active.actor.guid)
    local old=active.grace
    local notice=observed and observed.notice
    local function Notify(o)
        o.scope="PRIVATE_TEST"
        if ns.Notifications and ns.Notifications.OnPrivateTournamentGrace then ns.Notifications.OnPrivateTournamentGrace(o) end
        PublishGrace(o)
    end
    if old and (not observed or notice=="started" or observed.player~=old.player or observed.match~=old.match) then
        Notify({event=old.event,match=old.match,player=old.player,sequence=old.sequence,notice="interrupted"})
        old=nil
        if not notice then notice="interrupted" end
    end
    if observed and observed.remaining and observed.remaining>0 then
        local sequence=old and old.sequence
        if not sequence then
            sequence=math.max(Clock() or 1,(active.graceSerial or 0)+1)
            active.graceSerial=sequence
            notice="started"
        end
        active.grace={event=observed.event,match=a.match,remaining=observed.remaining,player=observed.player,sequence=sequence}
    else active.grace=nil end
    graceTicking=nil
    if notice and observed then
        observed.notice=notice
        observed.sequence=active.grace and active.grace.sequence or old and old.sequence
        if observed.sequence then Notify(observed) end
    end
    if old or active.grace or notice then Changed() else RefreshGrace() end
end
RefreshGrace=function()
    if graceTicking then return end
    if not active or active.role~="host" or not L.CanCommunicate() or not active.engine.PrivateOffer()
        or type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then StopGrace();return end
    if not graceTimer then graceTimer=C_Timer.NewTimer(5,TickGrace) end
end
local function RequestPage()
    if not fetch or not L.CanCommunicate() then StopFetch();return false,"Progress sync interrupted." end
    local body=fetch.reader.Request()
    if not body then StopFetch();return false,"Progress page unavailable." end
    local ok,why=Send(fetch.owner,{body})
    if not ok then StopFetch();return false,why end
    syncTimer=C_Timer.NewTimer(30,function()
        syncTimer=nil
        if fetch then StopFetch();active.receipt="Progress request expired; refresh explicitly.";Changed() end
    end)
    return true,"Requesting organizer progress."
end
local function OwnRow(v,guid,match)
    if not v or v.control.paused or v.bracket.state~="running" then return nil end
    for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do
        if m.state=="ready" and (m.a==guid or m.b==guid) and (not match or m.id==match) then return m end
    end end
end
local function SameSeat(a,b)
    return a and b and a.match==b.match and a.game==b.game and a.attempt==b.attempt and a.term==b.term
        and a.serial==b.serial and a.peer==b.peer
end
function L.CanArm(me,peer,session)
    if not L.CanCommunicate() or active.role~="player" or active.actor.guid~=me then return false end
    local seat=active.engine.PrivateSeat()
    return seat and seat.phase=="armed" and seat.peer==peer and ns.TournamentRecovery.PrivateSession(seat)==session
        and active.offer and SameSeat(seat,active.offer) and not active.offer.reported and true or false
end
local function SendMatch(op,match,term,serial,outcome)
    if not L.CanCommunicate() or active.role~="player" or fetch or echo then return false,"Finish the progress transfer first." end
    local n=Clock()
    if not n then return false,"Clock unavailable." end
    if active.matchRequest and n<active.matchRequest.deadline then return false,"Wait for the organizer reply." end
    local seq,lock=active.engine.ReserveProgress()
    if not seq then return false,"Resolve the pending registration request first." end
    local body=R.PrivateMatchRequest(active.scope,op,seq,lock.id,match,term,serial,outcome)
    if not body then return false,"Invalid match request." end
    active.matchRequest={seq=seq,owner=lock.owner,event=lock.id,match=match,term=term,serial=serial,op=op,deadline=n+30}
    local ok,why=Send(lock.owner,{body})
    if not ok then active.matchRequest=nil end
    return ok,why
end
local function SendResult()
    local seat=active and active.role=="player" and active.engine.PrivateSeat()
    if not seat or seat.phase~="reported" then return false,"No observed result to send." end
    return SendMatch("U",seat.match,seat.term,seat.serial,seat.winner==active.actor.guid and "won" or "lost")
end
local function ReconcileSeat()
    local seat=active.engine.PrivateSeat();local v=active.progress
    local grace=active.remoteGrace
    if grace then
        local valid=false
        if v and v.control.event==grace.event and not v.control.paused and v.bracket.state=="running" then
            for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do
                if m.id==grace.match and m.state=="ready" and (m.a==grace.player or m.b==grace.player) then valid=true end
            end end
        end
        if not valid then ClearRemoteGrace() end
    end
    if not seat or not v or v.control.event~=seat.event then return end
    local row=OwnRow(v,active.actor.guid,seat.match)
    local obsolete=v.control.term>seat.term or v.bracket.state=="completed"
        or row and (row.wins[1]+row.wins[2]+1>seat.game or (row.replayedGame==seat.game and 1 or 0)>seat.attempt)
    if not row and v.bracket.state=="running" then
        for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do
            if m.id==seat.match and m.state=="done" then obsolete=true end
        end end
    end
    local evidence="T:"..ns.TournamentRecovery.PrivateSession(seat)
    local acknowledged=false
    if seat.phase=="reported" then
        for _,r in ipairs(v.saved.reports) do
            if r.sender==active.actor.guid and r.evidence==evidence and r.winner==seat.winner then acknowledged=true;break end
        end
    end
    if obsolete or acknowledged then
        CloseSeatLink();active.offer=nil;active.both=nil
        if active.engine.ClearPrivateSeat() then active.receipt=acknowledged and "Observed result acknowledged in organizer log." or "Previous assignment ended; no result inferred." end
    end
end
local function ReceiveMatch(body,a)
    local q=active.matchRequest
    local n=Clock()
    if not q or not n or n>=q.deadline or a.guid~=q.owner then return end
    local v=R.DecodePrivateMatchReply(active.scope,q.seq,body)
    if not v or v.match~=q.match then return end
    local seat=active.engine.PrivateSeat()
    if v.kind=="receipt" and q.op=="U" then
        if not seat or seat.phase~="reported" or v.term~=q.term or v.serial~=q.serial
            or seat.term~=v.term or seat.serial~=v.serial then return end
        if active.engine.ClearPrivateSeat() then
            CloseSeatLink();active.offer=nil;active.both=nil;active.matchRequest=nil
            active.receipt="Organizer accepted result: "..v.status;Changed()
            ScheduleRefresh("sync")
        end
    elseif v.kind=="receipt" and (q.op=="W" or q.op=="E") and q.term==v.term and q.serial==v.serial then
        active.matchRequest=nil;CloseSeatLink();active.both=nil
        active.receipt="Organizer response: "..v.status..". Refreshing the bracket.";Changed()
        ScheduleRefresh("sync")
    elseif v.kind=="offer" and (q.op=="I" or q.op=="K") then
        local progress=active.progress
        local row=OwnRow(progress,active.actor.guid,v.match)
        if not row or progress.control.event~=q.event or v.term~=progress.control.term
            or v.game~=row.wins[1]+row.wins[2]+1 or v.attempt~=(row.replayedGame==v.game and 1 or 0)
            or v.peer~=(row.a==active.actor.guid and row.b or row.a) then return end
        v.event=q.event;v.owner=q.owner;v.seen=n
        if seat and not SameSeat(seat,v) then return end
        active.matchRequest=nil;active.offer=v
        active.both=seat and v.both and not v.reported or false
        active.receipt=v.reported and "Organizer already has your report." or v.both and "Both players ready. Challenge your assigned opponent normally."
            or v.ready and "Waiting for the other player." or "Assignment received. Confirm readiness."
        Changed()
    end
end
local function ReadySeat()
    local o=active.offer;local n=Clock()
    if not o or not n or n-o.seen>30 or o.reported or fetch or echo
        or active.matchRequest and n<active.matchRequest.deadline then return false,"Request your current assignment first and finish pending requests." end
    local seat=active.engine.PrivateSeat()
    if seat then
        if not SameSeat(seat,o) or seat.phase~="armed" or not seatLink or not seatLink.IsActive() then return false,"Previous assignment requires organizer review." end
        return SendMatch("K",seat.match,seat.term,seat.serial)
    end
    local d=ns.DuelDetection.GetSnapshot()
    if d.state~="idle" or d.active or d.challenge or not Resolve(active.scope,active.actor.guid,nil,o.peer) then return false,"Assigned opponent or idle duel detector unavailable." end
    local next={event=o.event,owner=o.owner,peer=o.peer,match=o.match,game=o.game,attempt=o.attempt,term=o.term,serial=o.serial,phase="armed"}
    if not active.engine.ArmPrivateSeat(next) then return false,"Could not save assignment." end
    local owner=active
    seatLink=ns.TournamentGameplay.ConnectPrivate(active.scope,active.actor.guid,next,ns.DuelDetection,
        function(session)return active==owner and active.both==true and ns.TournamentRecovery.PrivateSession(next)==session end,
        function(winner)
            CloseSeatLink()
            if active~=owner then return end
            if active.engine.RecordPrivateSeat(winner) then
                active.receipt="Local result observed; awaiting organizer receipt."
                if L.CanCommunicate() then SendResult() end
            else active.receipt="Observed result could not be saved; no result submitted." end
            Changed()
        end,
        function(reason)
            CloseSeatLink()
            if active==owner then active.receipt=reason;active.both=nil;Changed() end
        end)
    if not seatLink then return false,"Assignment saved, but detector unavailable. Organizer review required." end
    seatTimer=C_Timer.NewTimer(120,function()
        seatTimer=nil
        if seatLink and seatLink.IsWaiting() then
            CloseSeatLink();if active==owner then active.both=nil;active.receipt="Readiness expired; organizer review required.";Changed() end
        end
    end)
    return SendMatch("K",next.match,next.term,next.serial)
end
function L.IsAssignedDuel(s)
    if not active or active.role~="player" then return false end
    local seat=active.engine.PrivateSeat()
    local q=s and (s.active or s.challenge)
    return seat and q and q.duelMode=="tournament" and q.tournamentSession==ns.TournamentRecovery.PrivateSession(seat)
        and q.opponent and q.opponent.guid==seat.peer and true or false
end
-- Bounded follow-up on confirmed lifecycle changes, not permanent polling.
function L.RefreshIntent(lock,hasArchive)
    if lock and lock.status=="checked" then return "refresh" end
    if lock and lock.status=="registered" then return "refresh" end
    if hasArchive then return "sync-archive" end
end
local refreshOrder={"refresh","sync","offer","sync-archive"}
function L.NextRefresh(pending,lock,hasArchive)
    for _,command in ipairs(refreshOrder) do
        local row=pending[command]
        if row then
            local eligible=command=="sync-archive" and hasArchive or lock and row.event==lock.id and
                (command=="refresh" or lock.status=="checked" and (command=="sync" or command=="offer"))
            if eligible then return command,row end
            pending[command]=nil
        end
    end
end
local function RunAuto()
    autoTimer=nil
    if not active or active.role~="player" or not L.CanCommunicate() then StopAuto();return end
    local owner=active
    local lock=owner.engine.Status()
    local command,row=L.NextRefresh(autoPending,lock,#owner.engine.PendingArchives()>0)
    if not row then return end
    local now=Clock()
    if not now then StopAuto();return end
    if now>=row.expires then autoPending[command]=nil
    elseif fetch or echo or owner.engine.PendingOwner() or owner.matchRequest and now<owner.matchRequest.deadline then
        -- Wait for the existing transfer, without restarting the expiry budget.
    else
        row.attempts=row.attempts+1
        local ok=L.Command(command)
        if active~=owner then return end
        if ok or row.attempts>=3 then autoPending[command]=nil end
    end
    if next(autoPending) then autoTimer=C_Timer.NewTimer(3,RunAuto) end
end
ScheduleRefresh=function(command)
    if not active or active.role~="player" or not command then return end
    local now=Clock();if not now then return end
    local lock=active.engine.Status()
    if command~="sync-archive" and not lock then return end
    local event=command~="sync-archive" and lock.id or nil
    local old=autoPending[command]
    if not old or old.event~=event or now>=old.expires then
        autoPending[command]={event=event,attempts=0,expires=now+120}
    end
    if not autoTimer then
        local tail=active.actor.guid:sub(-1):byte() or 0
        autoTimer=C_Timer.NewTimer(2+(tail%7)*.4,RunAuto)
    end
end
-- Advisory data is never used to score, finalize, or write an archive.
function L.DecodeAdvisory(body,key,event)
    if type(body)~="string" or #body>237 then return nil end
    local k,id,rev,kind=body:match("^B|([^|]+)|([^|]+)|(%d+)|([a-z]+)$")
    local n=tonumber(rev)
    if k~=key or id~=event or not n or n<1 or n>2147483647 or tostring(n)~=rev
        or (kind~="drawn" and kind~="match" and kind~="terminal") then return nil end
    return n,kind
end
function L.DecodeGrace(body,key,event,now)
    if type(body)~="string" or #body>237 or type(now)~="number" then return nil end
    local k,id,match,player,seq,notice,deadline=body:match("^D|([^|]+)|([^|]+)|(R%d+M%d+)|([^|]+)|(%d+)|([a-z]+)|(%d+)$")
    local serial,untilAt=tonumber(seq),tonumber(deadline)
    if k~=key or id~=event or not serial or serial<1 or serial>4102444800 or tostring(serial)~=seq or not Guid(player)
        or not match or #match>8 or not untilAt or tostring(untilAt)~=deadline then return nil end
    if notice=="started" then
        if untilAt<=now or untilAt>now+300 then return nil end
    elseif (notice~="reconnected" and notice~="forfeited" and notice~="interrupted") or untilAt~=0 then return nil end
    return {event=id,match=match,player=player,sequence=serial,deadline=untilAt,notice=notice}
end
-- Terminal tombstones also reject late/reordered start packets.
function L.GraceDecision(last,o)
    if last and last.event==o.event then
        if o.sequence<last.sequence then return false end
        if o.sequence==last.sequence then
            if last.match~=o.match or last.player~=o.player or last.notice~="started" or o.notice=="started" then return false end
        end
    end
    return true
end
local function ReceiveGrace(body,a,lock)
    local now=Clock()
    local o=L.DecodeGrace(body,active.key,lock.id,now)
    if not o then return end
    local id,match,player,serial,untilAt,notice=o.event,o.match,o.player,o.sequence,o.deadline,o.notice
    local v=active.progress
    if not v or v.control.event~=id then return end
    local known=false
    for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do
        if m.id==match and (m.a==player or m.b==player) and (notice~="started" or m.state=="ready" and v.bracket.state=="running" and not v.control.paused) then known=true end
    end end
    if not known then return end
    local old=active.remoteGrace
    if not L.GraceDecision(active.lastGrace,o) then return end
    active.lastGrace=o
    ClearRemoteGrace()
    if notice=="started" then
        active.remoteGrace=o
        local owner=active
        local function Tick()
            remoteGraceTimer=nil
            if active~=owner or not owner.remoteGrace then return end
            if not L.CanCommunicate() then ClearRemoteGrace();Changed();return end
            local current=Clock()
            if not current or current>=untilAt then ClearRemoteGrace();Changed();return end
            Changed();remoteGraceTimer=C_Timer.NewTimer(math.min(5,untilAt-current),Tick)
        end
        remoteGraceTimer=C_Timer.NewTimer(math.min(5,untilAt-now),Tick)
    end
    if (notice=="started" or old and old.sequence==serial or notice=="forfeited") and ns.Notifications and ns.Notifications.OnPrivateTournamentGrace then
        ns.Notifications.OnPrivateTournamentGrace({scope="PRIVATE_TEST",event=id,match=match,player=player,sequence=serial,notice=notice,reported=true})
    end
    Changed()
    if notice=="forfeited" then ScheduleRefresh("sync") end
end
local function Receive(body,channel,sender)
    if not L.CanCommunicate() or channel~="WHISPER" then return end
    local a=Resolve(active.scope,active.actor.guid,sender)
    if not a then return end
    if active.role=="host" then
        local tag=body:sub(1,2)
        local replies
        if tag=="I|" or tag=="K|" or tag=="U|" or tag=="W|" or tag=="E|" then
            replies=R.ReceivePrivateMatchRequest(active.scope,active.engine,sender,body)
        elseif tag=="Z|" then replies=active.engine.PrivateReceiveEcho(sender,body)
        else replies=active.engine.Receive(sender,body) end
        if replies then
            Send(a.guid,replies)
            -- Snapshot/echo/offer queries must not rebuild all UI for every page.
            if tag=="M|" or tag=="K|" or tag=="U|" or tag=="W|" or tag=="E|" or tag=="Z|" then Changed() end
        end
    else
        local tag=body:sub(1,2)
        if tag=="B|" or tag=="D|" then
            local lock=active.engine.Status()
            if not lock or a.guid~=lock.owner then return end
            if tag=="D|" then ReceiveGrace(body,a,lock);return end
            local rev,kind=L.DecodeAdvisory(body,active.key,lock.id)
            if not rev then return end
            if active.hintEvent~=lock.id then active.hintEvent=lock.id;active.hintRevision=0 end
            if rev<=active.hintRevision then return end
            active.hintRevision=rev
            if kind=="terminal" then ScheduleRefresh("refresh")
            elseif lock.status=="checked" then
                local seat=active.engine.PrivateSeat()
                ScheduleRefresh(kind=="match" and seat and seat.phase=="armed" and active.progress and "offer" or "sync")
            end
            return
        end
        if tag=="J|" or tag=="N|" then ReceiveMatch(body,a);return end
        if body:sub(1,2)=="H|" and echo then
            if a.guid==echo.owner and R.PrivateEchoReceipt(active.scope,echo.seq,echo.term,echo.revision,body) then
                StopEcho();active.receipt="Organizer confirmed exact log acknowledgement.";Changed()
            end
            return
        end
        if body:sub(1,2)=="Z|" and fetch then
            local ok,why=fetch.reader.Receive(sender,body)
            if ok and why~="partial" then
                if syncTimer then syncTimer:Cancel();syncTimer=nil end
                if why=="complete" then
                    local v=fetch.reader.Snapshot()
                    local archiveOnly=fetch.archiveOnly
                    StopFetch()
                    if v.finishedAt then
                        local saved,message=active.engine.SaveFinalArchive(v)
                        active.receipt=message
                        if saved and message=="Completed tournament saved." and ns.Notifications and ns.Notifications.CheckTournamentAwards then
                            ns.Notifications.CheckTournamentAwards(v.saved.checkpoint.ad.id)
                        end
                        if not archiveOnly then
                            active.progress=v;ReconcileSeat()
                            -- Release the active commitment only after the final record is durable.
                            if saved and active.engine.Status() then
                                local lock=active.engine.Status()
                                local body=active.engine.Action("S")
                                if body then Send(lock.owner,{body}) end
                            end
                        end
                    elseif archiveOnly then
                        active.receipt="Organizer has not provided a finalized archive; retry."
                    else
                        active.progress=v
                        active.receipt="Organizer snapshot received; not independent match verification."
                        ReconcileSeat()
                    end
                    Changed()
                    if archiveOnly and active.receipt=="Completed tournament saved." and #active.engine.PendingArchives()>0 then
                        ScheduleRefresh("sync-archive")
                    end
                else
                    syncTimer=C_Timer.NewTimer(.75,function()syncTimer=nil;RequestPage()end)
                end
            elseif fetch.reader.IsFailed() then
                StopFetch();active.receipt="Inconsistent progress rejected; refresh again.";Changed()
            end
            return
        end
        local ok,why=active.engine.Receive(sender,body)
        if ok and why~="partial" then
            active.receipt=why
            if why=="cancelled" or why=="completed" then
                StopHints();StopAuto();StopFetch();StopEcho();CloseSeatLink();active.offer=nil;active.both=nil;active.matchRequest=nil
                active.progress=nil
                if #active.engine.PendingArchives()>0 and not fetch and not echo then
                    ScheduleRefresh("sync-archive")
                end
            elseif why=="confirmed" or why=="refused" then
                local lock=active.engine.Status()
                if not lock then
                    StopHints();StopAuto();StopFetch();StopEcho();CloseSeatLink();active.progress=nil;active.offer=nil;active.both=nil;active.matchRequest=nil
                elseif why=="confirmed" and lock.status=="checked" then ScheduleRefresh("sync") end
                if #active.engine.PendingArchives()>0 then ScheduleRefresh("sync-archive") end
            end
            Changed()
        end
    end
end
local function Open(role)
    if not Store.TournamentTestEnabled() then return false,"Private tournament network test is disabled in this build." end
    if active then return false,"Stop the current network session first." end
    if Store.LocalRecordingEnabled() or Store.PeerEpoch() then return false,"Use a separate private tournament build with ordinary recording and rankings disabled." end
    if R.PreviewState() or R.TestListings() then return false,"End the local simulation first." end
    if not Roster() or Read(InCombatLockdown)~=false or not Comm.IsAvailable() then return false,"Join a readable group outside combat." end
    if type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then return false,"Timer unavailable." end
    local s=P.GetCurrent();local key=P.Key(s)
    local actor=key and Actor("player",s)
    if not actor or not Clock() then return false,"Character or community unavailable." end
    local store={ReadTournamentJournal=Store.ReadTournamentTestJournal,CommitTournamentJournal=Store.CommitTournamentTestJournal,privateArchive=true}
    local function resolve(sender) return Resolve(s,actor.guid,sender) end
    local engine,cache=R.OpenRegistrationSession(s,actor,Clock,resolve,store,role)
    if not engine then return false,"Journal unavailable or committed to another role/community." end
    active={scope=s,key=key,actor=actor,role=role,engine=engine,cache=cache}
    queue={}
    unsubscribe=Comm.Subscribe("T1",Receive)
    unroster=Group.Subscribe(function()
        if not L.CanCommunicate() then
            StopHints();StopAuto();StopFetch();StopEcho();ClearQueue();StopGrace()
            if not Roster() and seatLink and seatLink.IsWaiting() then CloseSeatLink();active.both=nil end
            Changed()
        elseif active.role=="player" then
            local lock=active.engine.Status()
            if lock and not Resolve(active.scope,active.actor.guid,nil,lock.owner) then
                StopHints();StopAuto();StopFetch();StopEcho();ClearQueue()
                if seatLink and seatLink.IsWaiting() then CloseSeatLink();active.both=nil end
                active.organizerMissing=true
                active.receipt="Organizer unavailable. Last snapshot is not live.";Changed()
            elseif active.organizerMissing then
                active.organizerMissing=nil
                ScheduleRefresh(L.RefreshIntent(lock,#active.engine.PendingArchives()>0))
                if #active.engine.PendingArchives()>0 then ScheduleRefresh("sync-archive") end
            elseif not lock and #active.engine.PendingArchives()>0 and not fetch and not echo and not autoTimer then
                ScheduleRefresh("sync-archive")
            end
        elseif active.role=="host" and not active.advisedSignature then PublishAdvisory()
        end
    end)
    if not frame then
        frame=CreateFrame("Frame")
        frame:SetScript("OnEvent",function(_,event)
            if not active then return end
            if event=="PLAYER_REGEN_DISABLED" then
                StopHints();StopAuto();StopFetch();StopEcho();ClearQueue();StopGrace()
                active.matchRequest=nil
            elseif event=="PLAYER_REGEN_ENABLED" then
                if active.role=="player" then
                    if active.engine.PrivateSeat() and active.engine.PrivateSeat().phase=="reported" then SendResult()
                    else
                        ScheduleRefresh(L.RefreshIntent(active.engine.Status(),#active.engine.PendingArchives()>0))
                        if #active.engine.PendingArchives()>0 then ScheduleRefresh("sync-archive") end
                    end
                end
                Changed()
            else Stop() end
        end)
    end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_LOGOUT")
    Changed()
    if role=="player" then
        ScheduleRefresh(L.RefreshIntent(engine.Status(),#engine.PendingArchives()>0))
        if #engine.PendingArchives()>0 then ScheduleRefresh("sync-archive") end
    end
    return true,"Private "..role.." session opened. No rating."
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
    if command=="progress" then
        local v=active.role=="host" and d.PrivateProgress() or active.progress
        if not v then return false,"No bracket snapshot. Participant: use sync." end
        return true,v.saved.checkpoint.ad.draft.name.." | "..v.bracket.state.." | revision "..v.bracket.revision.." | "..v.source
    end
    if command=="broadcast" then active.broadcast=not active.broadcast;Changed();return true,"Broadcast view toggled." end
    if active.role=="host" then
        if command=="publish" then
            local limit=d.PublicationLimit();if limit then return false,limit end
            local draft=ns.TournamentState.GetDraft()
            if not draft then return false,"Save a tournament draft first." end
            local ad=d.Publish(draft)
            Changed()
            return ad~=nil,ad and "Private group tournament published; players may query you." or "Publication refused."
        elseif command=="start" then
            local ok=d.StartBracket(active.actor.guid);Changed()
            return not not ok,ok and "Private bracket started." or "Wait for the scheduled start and at least two checked-in entrants."
        elseif command=="assign" then
            local p=L.GetProjection();local a=p and p.selected and d.PrivateAssign(p.selected)
            Changed();return a~=nil,a and "Assignment issued. Both players must request it and confirm readiness." or "No unassigned ready game."
        elseif command=="hold" then
            local c=d.ControlSnapshot()
            local ok,why
            if c then ok,why=d.Hold(active.actor.guid,c.event,c.term) end
            Changed();return not not ok,ok and "Tournament paused safely." or why or "Hold refused."
        elseif command=="resume" then
            Group.Refresh()
            local ok=d.PrivateResume(ConnectionStates());Changed()
            return not not ok,ok and "Organizer resumed with matching participant acknowledgements." or "Matching online majority acknowledgements required."
        elseif command=="finalize" then
            local before=d.PrivateAdvisory()
            local ok=d.PrivateFinalize();Changed()
            if ok and before and ns.Notifications and ns.Notifications.CheckTournamentAwards then
                ns.Notifications.CheckTournamentAwards(before.id)
            end
            return not not ok,ok and "Tournament finalized in private history." or "Final result and exact finalist acknowledgements required."
        elseif command=="history" then
            local rows=d.PrivateHistory();local lines={}
            for _,r in ipairs(rows) do lines[#lines+1]=r.title.." - "..r.champion end
            return true,#lines>0 and table.concat(lines,"\n") or "No finalized private test tournaments."
        elseif command=="feature" then
            local v=d.PrivateProgress();local list={}
            if v then for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do if m.state=="ready" then list[#list+1]=m.id end end end end
            if #list<1 then return false,"No ready match." end
            local i=0;for j,id in ipairs(list) do if id==active.featured then i=j;break end end
            active.featured=list[i%#list+1];Changed();return true,"Featured match changed."
        elseif command=="cancel" then
            local snap=d.Snapshot()
            local ok=snap and d.Cancel(active.actor.guid,snap.ad.id)
            Changed()
            return not not ok,ok and "Tournament cancelled. Participants must request status." or "Cancellation refused."
        elseif command=="roster" then
            local snap=d.Snapshot()
            if not snap then return false,"No tournament." end
            local lines={snap.ad.draft.name}
            for _,m in ipairs(snap.roster) do lines[#lines+1]=m.name..(m.checkedIn and " (checked in)" or " (registered)") end
            return true,table.concat(lines,"\n")
        end
    elseif active.role=="player" then
        if command=="stop-ack" then StopEcho();ClearQueue();return true,"Acknowledgement stopped." end
        if echo then return false,"Finish or stop the acknowledgement first." end
        if command=="ack" then
            if fetch or active.matchRequest and Clock() and Clock()<active.matchRequest.deadline then return false,"Finish the pending request first." end
            local v=active.progress;local status=d.Status()
            if not v or not status or v.control.event~=status.id or not (v.control.paused or v.bracket.state=="completed") then
                return false,"Sync the held or completed bracket first."
            end
            local seq,lock=d.ReserveProgress()
            if not seq then return false,"Resolve registration first." end
            local reader=R.OpenPrivateProgressEcho(active.scope,active.actor,v,seq)
            if not reader then return false,"Exact log acknowledgement unavailable." end
            echo={owner=lock.owner,seq=seq,term=v.control.term,revision=v.bracket.revision,reader=reader}
            return EchoNext()
        elseif command=="withdraw-match" then
            local row=OwnRow(active.progress,active.actor.guid)
            if not row then return false,"Sync a ready match first." end
            return SendMatch("W",row.id,active.progress.control.term,0)
        elseif command=="consent-replay" then
            local v=active.progress;local dispute=v and v.bracket.dispute
            if not dispute or dispute.confirmed or v.control.paused then return false,"No replay-eligible disputed game." end
            return SendMatch("E",dispute.match,v.control.term,dispute.revision,dispute.game)
        elseif command=="offer" then
            local seat=d.PrivateSeat();local row=OwnRow(active.progress,active.actor.guid,seat and seat.match)
            if not row then return false,"Sync the current bracket first." end
            return SendMatch("I",row.id)
        elseif command=="ready" then return ReadySeat()
        elseif command=="report" then return SendResult()
        end
        if command=="sync-archive" then
            if fetch or d.PendingOwner() or active.matchRequest and Clock() and Clock()<active.matchRequest.deadline then return false,"Finish the pending request first." end
            active.matchRequest=nil
            local row
            for _,v in ipairs(d.PendingArchives()) do
                if Resolve(active.scope,active.actor.guid,nil,v.owner) then row=v;break end
            end
            if not row then return false,"Saved result pending: group with the organizer and retry." end
            local seq,lock=d.ReserveArchive(row.id)
            if not seq then return false,"Archive request unavailable." end
            local function resolve(sender)return Resolve(active.scope,active.actor.guid,sender)end
            local reader=R.OpenPrivateProgressFetch(active.scope,lock.owner,lock.id,active.actor.guid,seq,Clock,resolve)
            if not reader then return false,"Archive reader unavailable." end
            fetch={owner=lock.owner,reader=reader,archiveOnly=true}
            return RequestPage()
        elseif command=="sync" then
            if active.matchRequest and Clock() and Clock()<active.matchRequest.deadline then return false,"Wait for the match request to finish." end
            active.matchRequest=nil
            if fetch then return false,"A progress request is already running." end
            local status=d.Status()
            if not status or not Resolve(active.scope,active.actor.guid,nil,status.owner) then return false,"Organizer unavailable." end
            if type(C_Timer)~="table" or type(C_Timer.NewTimer)~="function" then return false,"Timer unavailable." end
            local seq,lock=d.ReserveProgress()
            if not seq then return false,"Resolve the pending registration request first." end
            local prior=active.progress
            if prior and prior.control.event~=lock.id then prior=nil end
            local function resolve(sender)return Resolve(active.scope,active.actor.guid,sender)end
            local reader=R.OpenPrivateProgressFetch(active.scope,lock.owner,lock.id,active.actor.guid,seq,Clock,resolve,prior)
            if not reader then return false,"Progress reader unavailable." end
            fetch={owner=lock.owner,reader=reader}
            return RequestPage()
        elseif command=="stop-sync" then StopAuto();StopFetch();ClearQueue();return true,"Progress sync stopped." end
        if fetch then return false,"Finish or stop the progress sync first." end
        if active.matchRequest and Clock() and Clock()<active.matchRequest.deadline then return false,"Wait for the match request to finish." end
        if command=="browse" then
            local rows=active.cache.Browse();local lines={}
            active.browseRows={}
            for i,ad in ipairs(rows) do
                lines[#lines+1]=i..". "..ad.draft.name.." - "..ad.organizer
                active.browseRows[i]={id=ad.id,owner=ad.owner}
            end
            return true,#lines>0 and table.concat(lines,"\n") or "No fresh owner-confirmed tournament."
        end
        local body,owner
        if command=="query" then
            local a=SelectedTarget();if not a then return false,"Target the organizer in your group." end
            owner=a.guid;body=d.Query(owner)
        elseif command:match("^join %d+$") then
            if d.ArchiveFull() then return false,"Private tournament history is full. Existing results are preserved." end
            local selected=active.browseRows and active.browseRows[tonumber(command:match("%d+$"))]
            if not selected then return false,"Browse and choose a fresh tournament." end
            owner=selected.owner;body=d.Join(owner,selected.id)
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
-- Read model uses the same bracket rows as the solo renderer. No local
-- fixture health, class guesses, simulated controls or live combat claims.
function L.GetProjection()
    if not active or not Store.TournamentTestEnabled() then return nil end
    local v=active.role=="host" and active.engine.PrivateProgress() or active.progress
    if not v then return nil end
    local cp=v.saved.checkpoint
    local p={scope="PRIVATE_TEST",role=active.role,event=cp.ad,bracket=v.bracket,names={},broadcast=active.broadcast==true,
        source=v.source,held=v.control.paused,readyCount=0,state=active.role=="host" and "hosting" or "competing",
        now=Clock(),roster=cp.roster,finishedAt=v.finishedAt,finalized=v.finishedAt~=nil,players={}}
    local first,featured,own
    for _,m in ipairs(cp.roster) do
        p.names[m.guid]=m.name;p.players[m.guid]=m
        if m.guid==active.actor.guid then p.member=m end
    end
    if active.role=="player" and not p.member then return nil end
    for _,round in ipairs(v.bracket.rounds) do
        for _,m in ipairs(round) do
            local mine=m.a==active.actor.guid or m.b==active.actor.guid
            if mine and m.state=="done" and not m.bye and m.winner~=active.actor.guid then p.state="eliminated" end
            if m.state=="ready" then
                p.readyCount=p.readyCount+1;first=first or m
                if m.id==active.featured then featured=m end
                if mine then own=m end
            end
        end
    end
    local seat=active.role=="player" and active.engine.PrivateSeat()
    local assigned=active.role=="host" and active.engine.PrivateOffer()
    if assigned then
        for _,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do if m.id==assigned.match then featured=m end end end
    end
    local selected=((not p.broadcast or seat) and own) or featured or first
    p.selected=selected and selected.id
    p.featured=selected and selected.id
    if own then
        local first=own.a==active.actor.guid
        local peer=first and own.b or own.a
        local roundIndex
        for i,round in ipairs(v.bracket.rounds) do for _,m in ipairs(round) do if m.id==own.id then roundIndex=i end end end
        p.match={id=own.id,round=roundIndex,roundCount=#v.bracket.rounds,score=own.wins[first and 1 or 2],opponentScore=own.wins[first and 2 or 1],opponent=p.names[peer] or "Unknown player",bestOf=cp.ad.draft.bestOf}
        p.opponent=p.players[peer]
    end
    p.offer=active.offer~=nil;p.seat=seat and seat.phase or nil
    p.pending=fetch~=nil or echo~=nil or active.role=="player" and active.engine.PendingOwner()~=nil
    p.canCommunicate=L.CanCommunicate() and not active.organizerMissing
    p.syncing=fetch~=nil;p.acknowledging=echo~=nil;p.assigned=assigned~=nil
    if active.grace and selected and active.grace.match==selected.id then
        local n=active.grace.remaining
        p.graceStatus=string.format("Reconnecting %02d:%02d",math.floor(n/60),n%60)
        p.offline={match=selected.id,player=active.grace.player,remaining=n}
    end
    local remote=active.remoteGrace
    if remote and remote.event==p.event.id and selected and remote.match==selected.id and p.now and remote.deadline>p.now then
        local remaining=remote.deadline-p.now
        p.graceStatus=string.format("Organizer reports reconnecting %02d:%02d",math.floor(remaining/60),remaining%60)
        p.offline={match=remote.match,player=remote.player,remaining=remaining,reported=true}
    end
    if seat and ns.DuelDetection and L.IsAssignedDuel(ns.DuelDetection.GetSnapshot()) then p.observedDuel=true end
    if assigned and selected and assigned.match==selected.id then
        p.assignmentStatus=assigned.ready1 and assigned.ready2 and "Both players ready" or "Waiting for players"
    elseif seat and selected and seat.match==selected.id then
        p.assignmentStatus=seat.phase=="reported" and "Awaiting result confirmation" or active.both and "Both players ready" or "Waiting for organizer"
    end
    return p
end
-- Same private registration owner; no new data or authority is created
-- for the Overview before a bracket has been synchronized.
function L.GetOverviewProjection()
    if not active or not Store.TournamentTestEnabled() then return nil end
    local p=L.GetProjection()
    if p then return p end
    if active.role=="host" then
        local snap=active.engine.Snapshot()
        if snap and snap.ad and snap.ad.state=="open" then
            return {scope="PRIVATE_TEST",role="host",event=snap.ad,now=Clock(),roster=snap.roster,names={},canCommunicate=L.CanCommunicate()}
        end
    else
        local lock=active.engine.Status()
        if not lock then return nil end
        local ad=active.cache and active.cache.Known(lock.id)
        local confirmed=lock.status=="registered" or lock.status=="checked"
        return {scope="PRIVATE_TEST",role="player",event=ad,now=Clock(),canCommunicate=L.CanCommunicate() and not active.organizerMissing,pending=active.engine.PendingOwner()~=nil,
            registrationPending=lock.status=="pending",
            member=confirmed and {guid=active.actor.guid,checkedIn=lock.status=="checked"} or nil}
    end
end
function L.PageFlags()
    if not active or not Store.TournamentTestEnabled() then return {} end
    if not pageFlags then
        local p=L.GetOverviewProjection()
        pageFlags={overview=true,champions=true}
        if p and p.event and p.now then
            pageFlags.brackets=p.bracket~=nil
            pageFlags.manage=p.role=="host"
            pageFlags["my-tournament"]=p.role=="player" and p.member~=nil
        end
    end
    local out={};for k,v in pairs(pageFlags) do out[k]=v end
    return out
end
function L.Now() return Clock() end
function L.GetControlModel()
    if not Store.TournamentTestEnabled() or R.PreviewState() or R.TestListings() then return nil end
    local actions={}
    local function Add(label,command,confirm)
        for _,a in ipairs(actions) do if a.command==command then return end end
        if #actions<11 or command=="stop" and #actions<12 then actions[#actions+1]={label=label,command=command,confirm=confirm==true} end
    end
    if not active then
        Add("Organizer session","host");Add("Participant session","player")
        return {active=false,context="idle",detail="PRIVATE NETWORK TEST\nSave a tournament draft first if organizing. Group with the other testers. Rankings are disabled.",actions=actions}
    end
    local d=active.engine
    local p=L.GetProjection()
    local detail,context
    if active.role=="host" then
        local snap=d.Snapshot()
        context=snap and snap.ad.id or "host"
        if snap then
            local checked=0;for _,m in ipairs(snap.roster) do if m.checkedIn then checked=checked+1 end end
            detail=snap.ad.draft.name.."\n"..snap.ad.count.." registered / "..checked.." checked in"
        else detail="No tournament published." end
        if not snap or snap.ad.state~="open" then
            local limit=d.PublicationLimit()
            if limit then detail=detail.."\n"..limit else Add("Publish saved draft","publish") end
            Add("Tournament history","history")
        elseif not p then
            Add("Start tournament","start");Add("Cancel tournament","cancel",true)
        elseif p.held then
            detail=detail.."\nTournament paused. Matching participant acknowledgements required."
            Add("Resume tournament","resume");Add("View bracket","view-bracket");Add("Cancel tournament","cancel",true)
        elseif p.bracket.state=="completed" then
            detail=detail.."\nFinal winner: "..(p.names[p.bracket.champion] or "Unknown")
            Add("Finalize tournament","finalize");Add("View bracket","view-bracket")
        else
            local a=d.PrivateOffer()
            if a then detail=detail.."\n"..(p.names[a.player1] or "Player").." vs "..(p.names[a.player2] or "Player").."\n"..(p.assignmentStatus or "Waiting for readiness")
            else Add("Assign featured match","assign") end
            Add("Next featured match","feature");Add("View bracket","view-bracket");Add("Pause tournament","hold",true)
            Add(p.broadcast and "Exit broadcast view" or "Broadcast view","broadcast")
        end
    else
        local lock=d.Status()
        local missing=d.PendingArchives()
        context=lock and lock.id or "player"
        if not lock then
            detail=d.ArchiveFull() and "Private tournament history is full. Existing results are preserved." or "Target the organizer in your group, then check their tournament."
            Add("Check target organizer","query")
            active.browseRows={}
            for i,ad in ipairs(active.cache.Browse()) do
                if i>4 then break end
                active.browseRows[i]={id=ad.id,owner=ad.owner}
                if not d.ArchiveFull() then Add("Join "..ad.draft.name,"join "..i) end
            end
        else
            detail="Registration: "..lock.status
            if d.PendingOwner() then Add("Retry request","retry")
            elseif lock.status=="registered" then Add("Check in","checkin");Add("Leave registration","leave",true)
            elseif lock.status=="checked" and not p then Add("Refresh bracket","sync");Add("Refresh registration","refresh") end
            if p then
                detail=detail.."\n"..p.event.draft.name.." - "..p.bracket.state
                Add("View bracket","view-bracket")
                if fetch then Add("Stop bracket refresh","stop-sync")
                elseif echo then Add("Stop acknowledgement","stop-ack")
                else
                    Add("Refresh bracket","sync")
                    if p.held or p.bracket.state=="completed" then Add("Acknowledge organizer log","ack")
                    elseif p.bracket.state=="disputed" and p.bracket.dispute and not p.bracket.dispute.confirmed then
                        Add("Agree to replay","consent-replay",true)
                    else
                        local seat=d.PrivateSeat()
                        if seat and seat.phase=="reported" then Add("Send observed result","report")
                        elseif p.match then
                            Add(seat and "Check both players ready" or "Request match assignment","offer")
                            if active.offer and not active.offer.reported then Add("Confirm readiness","ready") end
                            Add("Withdraw from match","withdraw-match",true)
                        end
                    end
                    Add(p.broadcast and "Exit broadcast view" or "Broadcast view","broadcast")
                end
            end
            if not d.PendingOwner() then Add("Refresh registration","refresh") end
        end
        if #missing>0 then
            detail=detail.."\n"..#missing.." completed tournament(s) awaiting saved results."
            if fetch then Add("Stop result sync","stop-sync") else Add("Recover saved results","sync-archive") end
        end
    end
    Add("Close network session","stop",true)
    return {active=true,context=context,detail=detail.."\n\n"..(active.receipt or active.sendStatus or "Waiting for organizer information."),
        actions=actions,role=active.role}
end
function L.GetDiagnosticResources()
    local deferred=0;for _ in pairs(autoPending) do deferred=deferred+1 end
    return {subscriptions=(unsubscribe and 1 or 0)+(unroster and 1 or 0),
        timers=(timer and 1 or 0)+(syncTimer and 1 or 0)+(seatTimer and 1 or 0)+(echoTimer and 1 or 0)+(graceTimer and 1 or 0)+(autoTimer and 1 or 0)+(hintTimer and 1 or 0)+(remoteGraceTimer and 1 or 0)+(fanTimer and 1 or 0),
        pending=deferred+(queue and #queue or 0)+#hintPending+(fetch and 1 or 0)+(echo and 1 or 0)+(active and active.matchRequest and 1 or 0),
        detectorSubscriptions=seatLink and 1 or 0}
end
-- No listeners or timer while disabled/idle. Combat clears unsent packets,
-- world/logout closes the session; durable pending requests survive.
function L.RunReliabilitySelfTest()
    for _,key in ipairs({"forever:EU:pvp:Alliance","retail:EU:retail:Alliance"}) do
        local lock={id="event",status="checked"}
        local pending={refresh={event="event"},sync={event="event"},offer={event="event"},["sync-archive"]={}}
        assert(L.NextRefresh(pending,lock,true)=="refresh")
        pending.refresh=nil;assert(L.NextRefresh(pending,lock,true)=="sync")
        pending.sync=nil;assert(L.NextRefresh(pending,lock,true)=="offer")
        assert(L.NextRefresh(pending,{id="different",status="checked"},true)=="sync-archive" and not pending.offer)
        assert(not L.NextRefresh(pending,nil,false))
        local peers={{guid="a",checked=true},{guid="b",checked=true},{guid="c",checked=true},{guid="d",checked=false}}
        local prev={id="event",phase="drawn",progress="1",first="a",second="b",peers=peers}
        local n={id="event",phase="drawn",progress="2",first="a",second="b",peers=peers}
        local rows=L.AdvisoryRecipients(prev,n);assert(#rows==3 and rows[3].kind=="drawn")
        n.progress="1";rows=L.AdvisoryRecipients(prev,n);assert(#rows==2 and rows[1].kind=="match")
        n.phase="completed";rows=L.AdvisoryRecipients(prev,n);assert(#rows==4 and rows[4].kind=="terminal")
        local prefix="D|"..key.."|event|R1M1|Player-1-00000001|"
        local started=assert(L.DecodeGrace(prefix.."100|started|400",key,"event",100))
        local interrupted=assert(L.DecodeGrace(prefix.."100|interrupted|0",key,"event",101))
        assert(L.GraceDecision(nil,started) and L.GraceDecision(started,interrupted))
        assert(not L.GraceDecision(interrupted,started) and not L.GraceDecision(interrupted,interrupted))
        assert(L.GraceDecision(interrupted,assert(L.DecodeGrace(prefix.."101|started|401",key,"event",101))))
        assert(not L.DecodeGrace(prefix.."100|started|401",key,"event",100))
        assert(not L.DecodeGrace(prefix.."100|forfeited|1",key,"event",101))
        assert(not L.DecodeGrace(prefix.."0100|interrupted|0",key,"event",101))
        assert(not L.DecodeGrace(prefix.."100|interrupted|0",key,"different",101))
    end
    return true
end
function L.RunGateSelfTest()
    -- This diagnostic never opens a live session in an enabled build.
    if Store.TournamentTestEnabled() then return nil,"Live test gate enabled; no network action attempted." end
    assert(L.DecodeAdvisory("B|key|event|1|drawn","key","event")==1)
    assert(not L.DecodeAdvisory("B|key|wrong|1|terminal","key","event"))
    assert(not L.DecodeAdvisory("B|key|event|01|drawn","key","event"))
    assert(not L.DecodeAdvisory("B|key|event|1|score","key","event"))
    assert(L.RefreshIntent({status="checked"},false)=="refresh" and L.RefreshIntent(nil,true)=="sync-archive")
    assert(L.RunReliabilitySelfTest())
    assert(ns.TournamentRecovery.RunArchiveCapacitySelfTest())
    local before=L.GetDiagnosticResources()
    assert(not L.CanCommunicate() and not L.IsActive())
    assert(not L.Command("host") and not L.Command("player") and not L.Command("publish"))
    assert(not L.Command("query") and not L.Command("join 1") and not L.Command("retry"))
    local after=L.GetDiagnosticResources()
    assert(before.subscriptions==after.subscriptions and before.timers==after.timers and before.pending==after.pending)
    assert(not Store.ReadTournamentTestJournal())
    assert(not Store.CommitTournamentTestJournal(0,{},"query"))
    return true
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament network / private registration gate","health",function()
        if Store.TournamentTestEnabled() then return "SKIP","Private registration adapter enabled; requires consenting group members and live verification." end
        local ok,result=pcall(L.RunGateSelfTest)
        return ok and result==true and "PASS" or "FAIL",ok and "Disabled registration gate; no live messages or writes." or tostring(result)
    end)
end

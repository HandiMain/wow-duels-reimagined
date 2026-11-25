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
local function StopEcho()
    if echoTimer then echoTimer:Cancel();echoTimer=nil end
    echo=nil
end
local function StopGrace()
    local observing=graceTimer or active and active.grace
    if graceTimer then graceTimer:Cancel();graceTimer=nil end
    if active then
        active.grace=nil
        if observing and active.role=="host" then active.engine.ResetPrivateObservation() end
    end
end
local function CloseSeatLink()
    if seatTimer then seatTimer:Cancel();seatTimer=nil end
    if seatLink then seatLink.Close();seatLink=nil end
end
local function Changed()
    if RefreshGrace then RefreshGrace() end
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
    StopFetch();StopEcho();StopGrace()
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
    if observed and observed.remaining and observed.remaining>0 then
        active.grace={match=a.match,remaining=observed.remaining,player=observed.player,sequence=old and old.sequence or Clock()}
    else active.grace=nil end
    graceTicking=nil
    if old or active.grace or observed and observed.notice then Changed() else RefreshGrace() end
    if observed and observed.notice and ns.Notifications and ns.Notifications.OnPrivateTournamentGrace then
        observed.scope="PRIVATE_TEST";observed.sequence=active.grace and active.grace.sequence or old and old.sequence or Clock()
        ns.Notifications.OnPrivateTournamentGrace(observed)
    end
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
        end
    elseif v.kind=="receipt" and (q.op=="W" or q.op=="E") and q.term==v.term and q.serial==v.serial then
        active.matchRequest=nil;CloseSeatLink();active.both=nil
        active.receipt="Organizer response: "..v.status..". Refresh the bracket.";Changed()
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
        if body:sub(1,2)=="J|" or body:sub(1,2)=="N|" then ReceiveMatch(body,a);return end
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
                    active.progress=fetch.reader.Snapshot()
                    active.receipt="Organizer snapshot received; not independent match verification."
                    StopFetch();ReconcileSeat();Changed()
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
                CloseSeatLink();active.offer=nil;active.both=nil;active.matchRequest=nil
                if why=="cancelled" then active.progress=nil end
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
    local store={ReadTournamentJournal=Store.ReadTournamentTestJournal,CommitTournamentJournal=Store.CommitTournamentTestJournal}
    local function resolve(sender) return Resolve(s,actor.guid,sender) end
    local engine,cache=R.OpenRegistrationSession(s,actor,Clock,resolve,store,role)
    if not engine then return false,"Journal unavailable or committed to another role/community." end
    active={scope=s,key=key,actor=actor,role=role,engine=engine,cache=cache}
    queue={}
    unsubscribe=Comm.Subscribe("T1",Receive)
    unroster=Group.Subscribe(function()
        if not L.CanCommunicate() then
            StopFetch();StopEcho();ClearQueue();StopGrace()
            if not Roster() and seatLink and seatLink.IsWaiting() then CloseSeatLink();active.both=nil end
            Changed()
        elseif active.role=="player" then
            local lock=active.engine.Status()
            if lock and not Resolve(active.scope,active.actor.guid,nil,lock.owner) then
                StopFetch();StopEcho();ClearQueue()
                if seatLink and seatLink.IsWaiting() then CloseSeatLink();active.both=nil end
                active.receipt="Organizer unavailable. Last snapshot is not live.";Changed()
            end
        end
    end)
    if not frame then
        frame=CreateFrame("Frame")
        frame:SetScript("OnEvent",function(_,event)
            if not active then return end
            if event=="PLAYER_REGEN_DISABLED" then
                StopFetch();StopEcho();ClearQueue();StopGrace()
                active.matchRequest=nil
            elseif event=="PLAYER_REGEN_ENABLED" then
                if active.role=="player" and active.engine.PrivateSeat() and active.engine.PrivateSeat().phase=="reported" then SendResult() end
                Changed()
            else Stop() end
        end)
    end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_LOGOUT")
    Changed()
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
            local draft=ns.TournamentState.GetDraft()
            if not draft then return false,"Save a tournament draft first." end
            local ad=d.Publish(draft)
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
            local ok=d.PrivateFinalize();Changed()
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
        if command=="sync" then
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
        elseif command=="stop-sync" then StopFetch();ClearQueue();return true,"Progress sync stopped." end
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
        source=v.source,held=v.control.paused,readyCount=0,state=active.role=="host" and "hosting" or "competing"}
    local first,featured,own
    for _,m in ipairs(cp.roster) do
        p.names[m.guid]=m.name
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
    if own then p.match={id=own.id} end
    if active.grace and selected and active.grace.match==selected.id then
        local n=active.grace.remaining
        p.graceStatus=string.format("Reconnecting %02d:%02d",math.floor(n/60),n%60)
    end
    if seat and ns.DuelDetection and L.IsAssignedDuel(ns.DuelDetection.GetSnapshot()) then p.observedDuel=true end
    if assigned and selected and assigned.match==selected.id then
        p.assignmentStatus=assigned.ready1 and assigned.ready2 and "Both players ready" or "Waiting for players"
    elseif seat and selected and seat.match==selected.id then
        p.assignmentStatus=seat.phase=="reported" and "Awaiting result confirmation" or active.both and "Both players ready" or "Waiting for organizer"
    end
    return p
end
function L.GetControlModel()
    if not Store.TournamentTestEnabled() or R.PreviewState() or R.TestListings() then return nil end
    local actions={}
    local function Add(label,command,confirm)
        if #actions<12 then actions[#actions+1]={label=label,command=command,confirm=confirm==true} end
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
            Add("Publish saved draft","publish");Add("Tournament history","history")
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
        context=lock and lock.id or "player"
        if not lock then
            detail="Target the organizer in your group, then check their tournament."
            Add("Check target organizer","query")
            active.browseRows={}
            for i,ad in ipairs(active.cache.Browse()) do
                if i>4 then break end
                active.browseRows[i]={id=ad.id,owner=ad.owner}
                Add("Join "..ad.draft.name,"join "..i)
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
    end
    Add("Close network session","stop",true)
    return {active=true,context=context,detail=detail.."\n\n"..(active.receipt or active.sendStatus or "Waiting for organizer information."),
        actions=actions,role=active.role}
end
function L.GetDiagnosticResources()
    return {subscriptions=(unsubscribe and 1 or 0)+(unroster and 1 or 0),
        timers=(timer and 1 or 0)+(syncTimer and 1 or 0)+(seatTimer and 1 or 0)+(echoTimer and 1 or 0)+(graceTimer and 1 or 0),
        pending=(queue and #queue or 0)+(fetch and 1 or 0)+(echo and 1 or 0)+(active and active.matchRequest and 1 or 0),
        detectorSubscriptions=seatLink and 1 or 0}
end
-- No listeners or timer while disabled/idle. Combat clears unsent packets,
-- world/logout closes the session; durable pending requests survive.
function L.RunGateSelfTest()
    -- This diagnostic never opens a live session in an enabled build.
    if Store.TournamentTestEnabled() then return nil,"Live test gate enabled; no network action attempted." end
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

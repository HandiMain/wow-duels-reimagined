local _,ns=...
-- One lifecycle owner for the opt-in, gated live adapter and isolated QA.
-- The live adapter never enters the simulation stores or awards authority
-- to a peer claim. Both recording and peer communication are build-locked.
local P={}
ns.CompetitiveLifecycle=P
local Store=ns.CompetitiveStorage
local initialized,run,lastSeen,seq=false,nil,0,0
local match,known,node,catchup,responder,replyActive,syncDeadline
local timerArmed,generation=false,0
local subscriptions=0
local status="disabled"
-- Preference is captured once per observed challenge; never retroactively
-- convert a completed loss, or change the mode of an accepted duel.
local intent
local function PreferredMode()
    return ns.Settings and ns.Settings.Get("practiceDuels")==true and "P" or "R"
end
function P.GetPreferredMode() return PreferredMode()=="P" and "Unranked" or "Ranked" end
-- Native outgoing invitations never qualify, even with Ranked selected.
-- Incoming invitations still require the initiator's R offer and both results.
local function ChallengeMode(c,preferred)
    if preferred~="R" then return "P" end
    if c.direction=="outgoing" then return c.rankedWidget==true and "R" or "P" end
    return c.direction=="incoming" and "R" or "P"
end
function P.IsResultPending(matchID)
    return type(matchID)=="string" and match~=nil and match.phase=="settling"
        and match.matchID==matchID and status=="pending"
end
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Plain(v) end
end
local function Now()
    local n=Read(GetTime)
    if type(n)=="number" and n>=0 and n<math.huge then return n end
end
local function EpochNow()
    local n=Read(GetServerTime)
    if type(n)=="number" and n>=1 and n<=4102444800 and n==math.floor(n) then return n end
end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function InCombat()
    if type(InCombatLockdown)~="function" then return false end
    local ok,v=pcall(InCombatLockdown)
    return not ok or (v~=nil and Plain(v)==nil) or v==true
end
local function Note(reason)
    if ns.Diagnostics and ns.Diagnostics.Record then
        ns.Diagnostics.Record("Competitive lifecycle",reason)
    end
end
local function Refresh()
    if ns.CompetitiveUI and ns.CompetitiveUI.Refresh then
        local ok=pcall(ns.CompetitiveUI.Refresh)
        if not ok then Note("Competitive view refresh failed") end
    end
    if ns.AchievementUI and ns.AchievementUI.Refresh then
        local ok=pcall(ns.AchievementUI.Refresh)
        if not ok then Note("Achievement view refresh failed") end
    end
end
function P.CanCommunicate()
    return initialized and Store.PeerEpoch()~=nil and
        ns.Settings.Get("competitiveConsent")==true
end
local function Available()
    return P.CanCommunicate() and ns.Communication.IsAvailable()
end
function P.GetSnapshot()
    return {scope="LOCAL",state=status,rankEligible=false,
        localRecording=initialized and Store.LocalRecordingEnabled(),
        peerEnabled=P.CanCommunicate(),peerState=match and match.phase,
        syncState=catchup and catchup.GetStatus().state,completeness="unknown",
        preferredMode=P.GetPreferredMode(),duelMode=intent and ((intent.mode=="P" or intent.practice) and "Unranked" or
            (intent.reason=="candidate" and "Ranked candidate" or "Awaiting agreement")) or nil,
        duelReason=intent and intent.reason}
end
function P.GetDiagnosticResources()
    return {pending=(match and 1 or 0)+(catchup and 1 or 0)+(replyActive and 1 or 0),
        subscriptions=subscriptions,timers=timerArmed and 1 or 0}
end
local function EnsureRun()
    if run then return run end
    local why
    run,why=Store.BeginLocalRun()
    if not run then Note("Local run unavailable: "..tostring(why)) end
    return run
end
local function Prefix()
    if not EnsureRun() or seq>=999999 then return nil end
    seq=seq+1
    return "r"..(run:match("^run%-(%d+)$") or "0").."-"..seq
end
local function CancelSync()
    if catchup then catchup.Cancel() end
    if responder then responder.Cancel() end
    catchup,responder,replyActive,syncDeadline=nil,nil,nil,nil
end
local function ResetPeer()
    match,known,node=nil,nil,nil
    CancelSync()
    generation=generation+1;timerArmed=false
end
local function AbortExchange()
    -- Revoking consent cancels transport immediately. Preserve the frozen
    -- candidate as local evidence, not as permission to keep sending.
    local frozen=match and match.phase=="accepted" and match or nil
    local pending=status=="pending"
    ResetPeer();match=frozen
    if pending then status="unconfirmed";Refresh() end
end
local function CommitNode()
    local ok,why=Store.CommitPeerNode(node)
    if not ok then
        Note("Peer evidence commit refused: "..tostring(why))
        node=nil;CancelSync()
        return false
    end
    Refresh()
    return true
end
local function EnsureNode()
    if node then return node end
    local why
    node,why=Store.OpenPeerNode()
    if not node then Note("Peer store unavailable: "..tostring(why)) end
    return node
end
local Tick
local function Arm()
    if timerArmed or not C_Timer or type(C_Timer.After)~="function" then return end
    if (not match or match.phase=="accepted") and not catchup and not replyActive then return end
    local g=generation
    timerArmed=true
    C_Timer.After(.5,function()
        if g~=generation then return end
        timerArmed=false
        local ok=pcall(Tick)
        if not ok then Note("A scheduled competitive callback failed");ResetPeer();return end
        Arm()
    end)
end
local function ValidPeer(sender,peer)
    return peer and ns.OpponentDiscovery.NormalizeSender(sender)==peer.key
end
local function Send(tag,body,peer)
    if not Available() or not peer or not peer.route then return false end
    return ns.Communication.Send(tag,body,"WHISPER",peer.route)==true
end
local function Capacity()
    local c=Store.ReadLocalCapacity()
    return c and c.history.state~="full" and c.ledger.state~="full"
end
local function LocalRankReady()
    if not P.CanCommunicate() then return false,"Ranked testing disabled" end
    if InCombat() or not Available() then return false,"Communication unavailable" end
    if match and match.phase=="settling" then return false,"Previous result pending" end
    if not Capacity() then return false,"Competitive storage unavailable" end
    local epoch=Store.PeerEpoch()
    local stamp=EpochNow()
    local fp=ns.CompetitiveManifest and ns.CompetitiveManifest.fingerprint
    if not epoch or not stamp or stamp<epoch or type(fp)~="string" or #fp~=64 then
        return false,"Competitive season unavailable"
    end
    return true,nil,epoch,fp
end
function P.GetRankOffer()
    local ok,_,epoch,fp=LocalRankReady()
    if not ok then return nil end
    return (PreferredMode()=="R" and "R" or "U").."|"..epoch.."|"..fp
end
function P.RankedAvailability(guid)
    if not Guid(guid) then return false,"Select a player",false end
    local me=ns.Group.ReadPlayerIdentity("player")
    if not me or me.guid==guid then return false,"Select another player",false end
    local ok,why,epoch,fp=LocalRankReady()
    if not ok then return false,why,false end
    return P.EvaluateRankOffer(ns.OpponentDiscovery.GetSnapshot(),guid,epoch,fp)
end
-- Pure UI eligibility projection. A compatible U response permits changing
-- preference, but never a ranked launch. This prevents two U players deadlocking.
function P.EvaluateRankOffer(d,guid,epoch,fp)
    if not d or not d.opponent or d.opponent.guid~=guid or d.state=="checking" then
        return false,"Checking opponent",false
    end
    if d.state~="compatible" then
        return false,d.state=="incompatible" and "Incompatible addon" or "Addon not confirmed",false
    end
    if d.rankOffer=="U|"..epoch.."|"..fp then return false,"Opponent prefers Unranked",true end
    if d.rankOffer~="R|"..epoch.."|"..fp then return false,"Ranked compatibility not confirmed",false end
    return true,"Ranked available",true
end
local function StartChallenge(s)
    local c=s.challenge
    if not c or not c.opponent or not Guid(c.opponent.guid) then return end
    if match and match.challengeAt==c.time and match.peer.guid==c.opponent.guid then return end
    ResetPeer()
    if not Available() then return end
    if not Capacity() then if intent then intent.reason="capacity" end;return end
    if not EnsureNode() then if intent then intent.reason="storage_unavailable" end;return end
    if not (c.direction=="outgoing" and (c.kind=="standard" or c.kind=="unclassified")
        or c.direction=="incoming" and c.kind=="standard") then return end
    local me=ns.Group.ReadPlayerIdentity("player")
    local now,epoch,prefix=Now(),EpochNow(),Prefix()
    local key=ns.OpponentDiscovery.NormalizeSender(c.opponent.display)
    if not me or not Guid(me.guid) or me.guid==c.opponent.guid or not now or not epoch
        or epoch<Store.PeerEpoch() or not prefix or not key then return end
    match={phase="challenge",challengeAt=c.time,deadline=now+8,me=me.guid,
        peer={guid=c.opponent.guid,key=key},direction=c.direction,kind=c.kind,
        prefix=prefix,helloAt=now,hellos=0,mode=intent and intent.mode or "R"}
    status="checking";Arm()
end
local function TryAgreement(x,now)
    local d=ns.OpponentDiscovery.GetSnapshot()
    if d.state~="compatible" or not d.opponent or d.opponent.guid~=x.peer.guid
        or d.opponent.key~=x.peer.key or not d.expiresAt or d.expiresAt<=now then return end
    x.peer.route=d.opponent.route
    local desc=ns.CompetitiveIntegrity.SeasonDescriptor(ns.Client.Kind(),Store.PeerEpoch())
    if not desc then return end
    if now>=x.helloAt and x.hellos<4 then
        Send("A1","V|"..desc,x.peer)
        x.hellos=x.hellos+1;x.helloAt=now+1.5
    end
    if not x.compatible or x.agreement then return end
    local agreement=ns.PeerAgreement.NewPeer(ns.Client.Kind(),x.prefix,Now,Available,
        function(body) return Send("A1",body,x.peer) end)
    if not agreement.Begin({state="challenge",me=x.me,peer=x.peer.guid,direction=x.direction,kind=x.kind},
        {state=d.state,protocol=d.protocol,guid=d.opponent.guid,key=d.opponent.key,expiresAt=d.expiresAt},true,x.mode) then
        x.phase="unranked";return
    end
    x.agreement=agreement
    if x.offer then agreement.Receive(x.offer,x.peer.key);x.offer=nil end
end
local function Freeze(s)
    local x=match
    if not x or x.phase~="challenge" or not s.active or x.cycle then return end
    local a=s.active
    x.cycle=a.id
    if (x.direction=="outgoing" and not a.rankedWidget and x.mode=="R")
        or not x.agreement or not a.opponent or a.opponent.guid~=x.peer.guid then
        match=nil;status="unranked";return
    end
    -- The incoming peer must have observed an ordinary challenge. No
    -- late handshake can upgrade an already accepted duel.
    x.agreement.Freeze(a.opponent.guid,a.kind=="standard" or a.kind=="unclassified")
    local candidate=x.agreement.Snapshot()
    if candidate.practice then
        if intent then intent.practice=true;intent.reason="practice_agreed" end
        match=nil;status="practice";return
    end
    if not candidate.candidate then
        if intent then intent.reason="not_agreed" end
        match=nil;status="unranked";return
    end
    x.candidate=candidate
    x.collector=ns.ResultConfirmation.NewPeer(ns.Client.Kind(),candidate.session,x.me,x.peer.guid)
    x.phase="accepted";status="candidate"
    if intent then intent.reason="candidate" end
end
local function ReceiveResult(body,sender)
    local x=match
    if not x or not x.collector or not ValidPeer(sender,x.peer) then return end
    local stamp=body:match("|(%d+)$")
    local t=tonumber(stamp);local now=EpochNow()
    if not t or not now or stamp~=tostring(t) or t<1 or math.abs(now-t)>60 then return end
    if x.collector.Receive(body,x.peer.guid) then x.peerTime=t end
end
local function StartSync()
    local now=Now()
    if not Available() or InCombat() or not now or not known or now>=known.expires
        or match or ns.DuelDetection.GetSnapshot().state~="idle" or not EnsureNode() then return false,"not_ready" end
    if catchup then return false,"busy" end
    local prefix=Prefix()
    if not prefix then return false,"prefix" end
    catchup=ns.SyncProtocol.NewCatchupPeer(ns.Client.Kind(),node,prefix,known.guid,"delta")
    if not catchup then return false,"sync_unavailable" end
    responder=responder or ns.SyncProtocol.NewResponder(ns.Client.Kind(),node)
    syncDeadline=now+300
    Arm();return true
end
P.StartSync=StartSync
local function FinalizeObservation(r)
    if not r or r.id<=lastSeen then return end
    lastSeen=r.id
    local choice=intent;intent=nil
    if r.kind~="standard" and r.kind~="unclassified" or r.reason=="death_duel_excluded" then return end
    local stamp=EpochNow()
    r.observedAt=stamp
    local x=match
    local earlier=x and x.phase=="settling" and x.cycle~=r.id
    local candidate=x and x.cycle==r.id and x.candidate or nil
    if choice and choice.cycle==r.id and (choice.mode=="P" or choice.practice) then
        r.duelMode="practice";r.rankReason=choice.reason=="native_unranked" and "native_unranked"
            or choice.practice and "practice_agreed" or choice.reason=="practice_selected" and "practice_selected" or "not_agreed"
        candidate=nil
    elseif not candidate then
        r.rankReason=choice and choice.cycle==r.id and choice.reason~="candidate" and choice.reason or "not_agreed"
    end
    if r.outcome=="unknown" then
        local observed={world_transition=true,conflicting_result=true,result_not_observed=true,finish_not_observed=true}
        r.endReason=observed[r.reason] and r.reason or "not_observed"
    end
    local body
    if candidate and stamp then
        body=ns.ResultConfirmation.MakePeerStatement({scope="PEER",client=ns.Client.Kind(),
            me=x.me,peer=x.peer.guid,cycle=r.id,agreement=candidate},r)
        if body and #body>237 then body=nil end
    end
    if candidate and not body then
        r.rankReason=r.endType=="retreat" and "retreat" or r.outcome=="unknown" and "unknown_result" or "confirmation_unavailable"
    end
    local id=EnsureRun()
    local ok,why
    if id then ok,why=Store.RecordLocalObservation(id,r,body and candidate or nil) end
    if not ok then
        Note("Local observation refused: "..tostring(why or "run_unavailable"))
        if not earlier then status="local_record_failed";match=nil end;return
    end
    if body and Available() and x.collector.Receive(body,x.me) then
        local now=Now()
        if now then
            x.localTime=stamp;x.body=body
            local a,b=x.me,x.peer.guid;if b<a then a,b=b,a end
            x.matchID=ns.Client.Kind().."|"..a.."|"..b.."|"..candidate.session
            x.phase="settling";x.deadline=now+12;x.nextResult=now;x.sends=0
            known={guid=x.peer.guid,key=x.peer.key,route=x.peer.route,expires=now+600}
            status="pending";Arm()
        else match=nil;status="unranked" end
    elseif not earlier then
        match=nil;status=body and "unconfirmed" or r.duelMode=="practice" and "practice_recorded" or "local_recorded"
    end
    Refresh()
end
local function Settle(x)
    x.collector.Close()
    local evidence=x.collector.Snapshot()
    match=nil
    if not evidence.record or not x.localTime or not x.peerTime
        or not EnsureNode() then status="unconfirmed";Refresh();return end
    local t1,t2=x.localTime,x.peerTime
    if evidence.record.player1~=x.me then t1,t2=t2,t1 end
    if t1<Store.PeerEpoch() or t2<Store.PeerEpoch() then status="unconfirmed";Refresh();return end
    local ok,why=node.Observe(evidence.record,t1,t2)
    if not ok then status="unconfirmed";Note("Peer observation refused: "..tostring(why));Refresh();return end
    if CommitNode() then
        status="peer_evidence_saved"
        StartSync()
    else status="unconfirmed";Refresh() end
end
Tick=function()
    local now=Now()
    if not now or not P.CanCommunicate() then AbortExchange();return end
    if match then
        local x=match
        if not Available() then
            AbortExchange()
            if x.phase=="challenge" then status="unranked" end
        elseif x.phase=="challenge" then
            if now>=x.deadline then match=nil;status="unranked"
            else
                TryAgreement(x,now)
                if x.agreement and x.agreement.Snapshot().state=="agreed" then status="ready" end
            end
        elseif x.phase=="unranked" then
            match=nil;status="unranked"
        elseif x.phase=="settling" then
            if now>=x.deadline then Settle(x)
            elseif now>=x.nextResult and x.sends<3 then
                Send("R1",x.body,x.peer);x.sends=x.sends+1;x.nextResult=now+2
            end
        end
    end
    -- No persistent polling during an accepted duel. It resumes only on
    -- terminal evidence or an explicit bounded sync session.
    if match and match.phase=="accepted" then return end
    if (catchup or replyActive) and (InCombat() or not Available() or
        not known or now>=known.expires or (syncDeadline and now>=syncDeadline)) then CancelSync();return end
    local sent=false
    if replyActive and responder then
        local body,peer=responder.Next(now)
        if body then
            sent=true
            if peer~=known.guid or not Send("S1",body,known) then responder.Cancel();replyActive=nil end
        elseif peer~="paced" then replyActive=nil end
    end
    if catchup and not sent then
        local body,why=catchup.Poll(now)
        if body then
            if not Send("S1",body,known) then CancelSync() end
        elseif catchup.GetStatus().state~="working" then catchup=nil end
    end
    if not catchup and not replyActive then syncDeadline=nil end
end
local function OnAgreement(body,_,sender)
    local x=match
    if not P.CanCommunicate() or not x or x.phase~="challenge" or not ValidPeer(sender,x.peer) then return end
    if body:sub(1,2)=="V|" then
        local result=ns.CompetitiveIntegrity.CompareSeasonSimulated(ns.Client.Kind(),Store.PeerEpoch(),body:sub(3))
        x.compatible=result.compatible
        if not x.compatible then x.agreement=nil;x.offer=nil end
    elseif x.agreement then x.agreement.Receive(body,x.peer.key)
    elseif body:sub(1,2)=="O|" and not x.offer then x.offer=body end
end
local function OnSync(body,_,sender)
    local now=Now()
    if not Available() or InCombat() or match or not now or not known or now>=known.expires
        or ns.DuelDetection.GetSnapshot().state~="idle"
        or not ValidPeer(sender,known) or not EnsureNode() then return end
    if body:sub(1,2)=="Q|" then
        responder=responder or ns.SyncProtocol.NewResponder(ns.Client.Kind(),node)
        if responder and responder.Begin(body,known.guid,known.guid,now) then
            replyActive=true;syncDeadline=syncDeadline or now+300;Arm()
        end
    elseif body:sub(1,2)=="R|" and catchup then
        local revision=node.GetEvidenceRevision()
        local ok=catchup.Receive(body,known.guid,now)
        if ok and node.GetEvidenceRevision()~=revision then CommitNode() end
    end
end
function P.PreferenceChanged()
    if not P.CanCommunicate() then AbortExchange() end
end
function P.Initialize()
    if initialized or not Store.LocalRecordingEnabled() then return end
    initialized=true;status="local_ready"
    -- Initial character entry resets the boundary; /reload restores it.
    local sessionLogin=CreateFrame("Frame")
    sessionLogin:RegisterEvent("PLAYER_ENTERING_WORLD")
    sessionLogin:SetScript("OnEvent",function(self,_,initial,reloading)
        self:UnregisterAllEvents()
        Store.StartSession(Plain(initial)==true and Plain(reloading)~=true)
        Refresh()
    end)
    local before=ns.DuelDetection.GetSnapshot()
    lastSeen=before.last and before.last.id or 0
    ns.DuelDetection.Subscribe(function(s)
        if s.scope~="LOCAL" then return end
        if s.state=="challenge" and s.challenge then
            local c=s.challenge
            if not intent or intent.time~=c.time or intent.direction~=c.direction
                or intent.key~=(c.opponent and c.opponent.key) or intent.widget~=c.rankedWidget or intent.widgetChallenge~=c.widgetChallenge then
                intent={time=c.time,direction=c.direction,key=c.opponent and c.opponent.key,widget=c.rankedWidget,widgetChallenge=c.widgetChallenge,
                    mode=ChallengeMode(c,PreferredMode()),reason="not_agreed"}
                if c.direction=="outgoing" and not c.widgetChallenge then
                    intent.reason="native_unranked"
                elseif c.direction=="outgoing" and not c.rankedWidget or PreferredMode()=="P" then
                    intent.reason="practice_selected"
                end
            end
            -- A new challenge must not silently replace an earlier settling
            -- match. Keep its bounded confirmation; the new duel is local.
            if P.CanCommunicate() and not (match and match.phase=="settling") then StartChallenge(s) end
        elseif s.state=="accepted" and s.active then
            if not intent then intent={mode="P",reason="not_agreed"} end
            if not intent.cycle then intent.cycle=s.active.id end
            if P.CanCommunicate() then Freeze(s) end
        elseif s.state=="idle" then
            if s.last and s.last.id>lastSeen then FinalizeObservation(s.last)
            else
                intent=nil
                if match and match.phase=="challenge" then match=nil;status="unranked" end
            end
        end
    end)
    subscriptions=1
    if Store.PeerEpoch() then
        ns.Communication.Subscribe("A1",OnAgreement)
        ns.Communication.Subscribe("R1",function(body,_,sender) if P.CanCommunicate() then ReceiveResult(body,sender) end end)
        ns.Communication.Subscribe("S1",OnSync)
        subscriptions=4
        local frame=CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:SetScript("OnEvent",function(_,event)
            if event=="PLAYER_ENTERING_WORLD" then
                local pending=status=="pending";ResetPeer()
                -- Detector owns the terminal world-transition observation.
                -- Its callback clears intent, regardless of event ordering.
                if pending then status="unconfirmed";Refresh() end
            else CancelSync() end
        end)
    end
end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    local epoch=1000
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local now=100
            local sep=client=="forever" and " " or "-"
            local names={"Alpha"..sep.."Home","Beta"..sep.."Other"}
            local ids={a,b}
            local f={peers={},discovery={},agreement={},queue={}}
            for i=1,2 do
                local j=3-i
                local x=ns.DuelDetection.NewSandbox(client,false)
                x.people.player={fullName=names[i],guid=ids[i]}
                x.people.target={fullName=names[j],guid=ids[j]}
                local peer={box=x,writes=0}
                function peer.open()
                    local d=ns.CompetitiveStorage.NewSimulated(function()return peer.account,peer.character end,
                        function(aa,cc)peer.account=aa;peer.character=cc;peer.writes=peer.writes+1 end,
                        function()return client end,function()return ids[i] end)
                    d.MarkLoaded();return d
                end
                f.peers[i]=peer
                f.discovery[i]=assert(ns.OpponentDiscovery.NewSimulated({scope="SIMULATED",kind=client,
                    now=function()return now end,home=function()return "Home" end,noncePrefix="peer-"..i,
                    identity=function(unit)return x.people[unit]end,available=function()return true end,
                    send=function(body,target)
                        assert(target==names[j]);f.queue[#f.queue+1]={to=j,from=i,body=body};return true
                    end,after=function()end}))
            end
            function f.discover()
                assert(f.discovery[1].Probe("target") and f.discovery[2].Probe("target"))
                local i=1
                while i<=#f.queue do
                    assert(i<=4,"unexpected discovery loop")
                    local q=f.queue[i];f.discovery[q.to].Receive(q.body,names[q.from]);i=i+1
                end
                assert(#f.queue==4)
                for k=1,2 do assert(f.discovery[k].GetSnapshot().state=="compatible") end
                f.queue={}
            end
            function f.challenge()
                f.peers[1].box.Outgoing("target")
                f.peers[2].box.Fire("DUEL_REQUESTED",names[1])
                for k=1,2 do assert(f.peers[k].box.detector.GetSnapshot().state=="challenge") end
            end
            function f.agree(dropFinal,badBuild)
                local descriptor=assert(ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch))
                for k=1,2 do
                    local i=k;local j=3-i
                    local d=f.discovery[i].GetSnapshot()
                    local s=f.peers[i].box.detector.GetSnapshot()
                    local remote=badBuild and descriptor.."x" or descriptor
                    if not ns.CompetitiveIntegrity.CompareSeasonSimulated(client,epoch,remote).compatible then return false end
                    f.agreement[i]=ns.PeerAgreement.NewSimulated(client,"peer-"..i,function()return now end,
                        function()return true end,function(body,target)
                            assert(target==d.opponent.key)
                            f.queue[#f.queue+1]={to=j,from=i,body=body};return true
                        end)
                    f.peers[i].discovery={state=d.state,protocol=d.protocol,guid=d.opponent.guid,key=d.opponent.key,expiresAt=d.expiresAt}
                    f.peers[i].challenge={state=s.state,me=ids[i],peer=s.challenge.opponent.guid,
                        direction=s.challenge.direction,kind=s.challenge.kind}
                end
                assert(f.agreement[2].Begin(f.peers[2].challenge,f.peers[2].discovery,true))
                assert(f.agreement[1].Begin(f.peers[1].challenge,f.peers[1].discovery,true))
                local i=1
                while i<=#f.queue do
                    assert(i<=3,"unexpected agreement loop")
                    local q=f.queue[i]
                    if not(dropFinal and i==3) then
                        f.agreement[q.to].Receive(q.body,f.peers[q.to].discovery.key)
                    end
                    i=i+1
                end
                assert(#f.queue==3);f.queue={}
                return true
            end
            function f.countdown()
                for i=1,2 do
                    local x=f.peers[i].box
                    x.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
                    local s=x.detector.GetSnapshot();assert(s.active)
                    if f.agreement[i] then f.agreement[i].Freeze(s.active.opponent.guid,true) end
                end
            end
            function f.finish(mode)
                for i=1,2 do
                    local peer=f.peers[i];local x=peer.box
                    x.Advance(4)
                    local winner=mode=="conflict" and names[i] or names[1]
                    local loser=winner==names[1] and names[2] or names[1]
                    local msg=mode=="retreat" and (loser.." has fled from "..winner.." in a duel") or (winner.." has defeated "..loser.." in a duel")
                    if i==1 then x.Fire("DUEL_FINISHED");x.Fire("CHAT_MSG_SYSTEM",msg)
                    else x.Fire("CHAT_MSG_SYSTEM",msg);x.Fire("DUEL_FINISHED") end
                    peer.result=assert(x.detector.GetSnapshot().last)
                    peer.candidate=f.agreement[i] and f.agreement[i].Snapshot() or nil
                    assert(peer.open().UpdateRecords(true,function(_,h,run)return h.Observe(run,peer.result,peer.candidate)end))
                end
            end
            function f.settle(dropSecond)
                local p,q=f.peers[1],f.peers[2]
                if not p.candidate or not p.candidate.candidate then return "unranked" end
                local collector=ns.ResultConfirmation.NewSimulated(client,p.candidate.session,a,b)
                for i=1,2 do
                    local peer=f.peers[i]
                    local statement=ns.ResultConfirmation.MakeSimulatedStatement({scope="SIMULATED",client=client,
                        me=ids[i],peer=ids[3-i],cycle=peer.result.id,agreement=peer.candidate},peer.result)
                    if statement and not(dropSecond and i==2) then assert(collector.Receive(statement,ids[i])) end
                end
                collector.Close();local snapshot=collector.Snapshot()
                if snapshot.record then
                    for i=1,2 do assert(f.peers[i].open().UpdateSeasonEvidence(epoch,snapshot.record,epoch+10,epoch+11)) end
                end
                return snapshot.state,snapshot.record
            end
            function f.stats(i) return assert(f.peers[i].open().ReadRecords()).history end
            function f.archive(i) return f.peers[i].open().ReadSeasonArchive(epoch+11) end
            return f
        end
        Case(client.." full lifecycle and peer replay convergence",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish()
            assert(f.stats(1).categories.pending.total==1 and not f.archive(1))
            local state,record=f.settle();assert(state=="matched" and record.winner==a and not record.rankEligible)
            for i=1,2 do
                local s=assert(f.archive(i));assert(s.players[a].rating==1100 and s.players[b].rating==909 and s.matched==1 and not s.rankEligible)
                assert(f.stats(i).overall.total==1 and f.stats(i).categories.matched.total==1)
                assert(s.players[a].rank.provisional and s.changes[1].gain==100)
            end
            -- Season-aware fixture wire binds evidence to the balanced policy and calendar.
            local part=f.peers[1].account.clients[client]
            local source=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,{version=1,scope="SIMULATED",client=client,
                rule=ns.CompetitiveRules.ID,ledger=part.ledger,clocks=part.season.clocks}))
            local target=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            local req=ns.SyncProtocol.NewRequester(client,target,"integration")
            local res=ns.SyncProtocol.NewResponder(client,source)
            local request=assert(req.Begin(a,1,0));assert(request:match('^Q|2|'));assert(res.Begin(request,b,b,0))
            local t=0
            while true do
                local body,peer=res.Next(t);if not body then break end
                assert(peer==b and #body+3<=240 and body:match('^R|2|'));assert(req.Receive(body,a,t));t=t+0.5;assert(t<120)
            end
            local remote=assert(target.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+11}))
            assert(remote.matched==1 and remote.players[a].rating==1100 and remote.players[b].rating==909 and remote.completeness=="unknown")
            local writes=f.peers[1].writes
            local ok,why=f.peers[1].open().UpdateSeasonEvidence(epoch,record,epoch+10,epoch+11)
            assert(ok and why=="unchanged" and f.peers[1].writes==writes)
            local past=assert(f.peers[1].open().ReadSeasonArchive(epoch+ns.SeasonRules.DURATION))
            assert(past.history[1].players[a].rating==1100 and #past.standings==0)
        end)
        Case(client.." absent addon keeps personal stats only",function()
            local f=Fixture();f.challenge();f.countdown();f.finish();assert(f.settle()=="unranked")
            assert(f.stats(1).categories.unranked.wins==1 and f.stats(2).categories.unranked.losses==1 and not f.archive(1))
        end)
        Case(client.." missing final agreement cannot settle",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree(true));f.countdown();f.finish()
            assert(f.settle()=="unconfirmed" and f.stats(1).categories.pending.total==1 and f.stats(2).categories.unranked.total==1 and not f.archive(1))
        end)
        Case(client.." incompatible build leaves duel unranked",function()
            local f=Fixture();f.discover();f.challenge();assert(not f.agree(false,true));f.countdown();f.finish()
            assert(f.settle()=="unranked" and f.stats(1).categories.unranked.wins==1 and not f.archive(1))
        end)
        Case(client.." retreat remains personal only",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish("retreat")
            assert(f.settle()=="unconfirmed" and f.stats(1).overall.theyFled==1 and f.stats(2).overall.fled==1 and not f.archive(1))
        end)
        Case(client.." conflicting or missing outcome cannot alter ratings",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish("conflict")
            assert(f.settle()=="disputed" and f.stats(1).overall.wins==1 and f.stats(2).overall.wins==1 and not f.archive(1))
            f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish()
            assert(f.settle(true)=="unconfirmed" and f.stats(1).categories.pending.total==1 and not f.archive(1))
        end)
    end
    Case("only explicit widget outgoing intent can rank",function()
        assert(ChallengeMode({direction="outgoing"},"R")=="P")
        assert(ChallengeMode({direction="outgoing",rankedWidget=true},"R")=="R")
        assert(ChallengeMode({direction="outgoing",rankedWidget=true},"P")=="P")
        assert(ChallengeMode({direction="incoming"},"R")=="R")
        assert(ChallengeMode({direction="incoming"},"P")=="P")
        assert(ChallengeMode({direction="unknown"},"R")=="P")
    end)
    Case("rank eligibility is exact-target and mutual preference",function()
        local guid="Player-2-BBB";local fp=string.rep("a",64)
        local d={state="compatible",opponent={guid=guid},rankOffer="R|1000|"..fp}
        local ok,_,selectable=P.EvaluateRankOffer(d,guid,1000,fp);assert(ok and selectable)
        d.rankOffer="U|1000|"..fp;ok,_,selectable=P.EvaluateRankOffer(d,guid,1000,fp)
        assert(not ok and selectable)
        d.rankOffer="R|1001|"..fp;ok,_,selectable=P.EvaluateRankOffer(d,guid,1000,fp);assert(not ok and not selectable)
        d.rankOffer="R|1000|"..fp;assert(not P.EvaluateRankOffer(d,"Player-3-CCC",1000,fp))
        d.state="unknown";assert(not P.EvaluateRankOffer(d,guid,1000,fp))
    end)
    Case("integration remains simulation only",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
    end)
    return passed,failed
end

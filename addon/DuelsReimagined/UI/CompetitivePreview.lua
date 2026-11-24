local _,ns=...
-- DEVELOPMENT PREVIEW ONLY. These fixtures are not player records, never
-- access SavedVariables or real identities, and use the existing replay.
local P={}
ns.CompetitivePreview=P
-- No pre-populated standings. Explicit session commands generate only
-- private synthetic observations. Rebuild transactionally through the same
-- canonical validation and replay used by the isolated regression suites.
local TEST_ENABLED=true
local MAX_EVENTS=250
local MAX_OPPONENTS=20
local classes={"PRIEST","MAGE","ROGUE","WARRIOR","WARLOCK","PALADIN"}
local function Guid(i) return string.format("Player-99-DR%04d",i) end
local function Build(client,events)
    assert(client=="retail" or client=="forever")
    events=events or {}
    assert(type(events)=="table" and #events<=MAX_EVENTS)
    local epoch=1700000000
    local asOf=epoch+#events*120+3600
    local node=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
    local metadata,localRows={},{}
    local me=Guid(0)
    local function Identity(n)
        local id=Guid(n)
        local name=n==0 and "Test Player" or "Test Rival "..n
        metadata[id]={scope="SIMULATED",client=client,guid=id,name=name,
            fullName=name,class=classes[n%#classes+1],observedAt=asOf}
        return id
    end
    for cycle,event in ipairs(events) do
        assert(type(event)=="table" and (event.outcome=="won" or event.outcome=="lost" or event.outcome=="unknown" or event.outcome=="fled" or event.outcome=="they_fled")
            and type(event.opponent)=="number" and event.opponent>=1
            and event.opponent<=MAX_OPPONENTS and event.opponent==math.floor(event.opponent))
        local a,b=Identity(0),Identity(event.opponent)
        local winner=event.outcome=="won" and a or b
        local session="sim-"..cycle..":duel-"..cycle
        local time=epoch+3600+cycle*120
        local mode=event.mode or "ranked"
        assert(mode=="ranked" or mode=="practice" or mode=="unranked" or mode=="pending")
        local knockout=event.outcome=="won" or event.outcome=="lost"
        local linked=knockout and (mode=="ranked" or mode=="pending")
        if linked and mode=="ranked" then
            local x=table.concat({"1",client,session,a,b,a==winner and "won" or "lost",tostring(cycle)},"|")
            local y=table.concat({"1",client,session,b,a,b==winner and "won" or "lost",tostring(cycle)},"|")
            local record=assert(ns.ResultConfirmation.DecodeStatementsSimulated(client,x,y))
            assert(node.Observe(record,time,time))
        end
        localRows[#localRows+1]={cycle=cycle,peer=b,outcome=event.outcome,
            session=linked and session or nil,mode=mode,duration=60,time=time}
    end
    local saved=node.Save()
    local ledger=assert(ns.MatchLedger.OpenSimulated(client,saved.ledger))
    local history=assert(ns.PersonalHistory.OpenSimulated(client,me,ledger))
    local function Observe(row)
        local unknown=row.outcome=="unknown"
        local retreat=row.outcome=="fled" or row.outcome=="they_fled"
        local r={scope="SIMULATED",client=client,id=row.cycle,kind="standard",opponent={guid=row.peer},
            acceptedAt=0,endedAt=row.duration,outcome=row.outcome,endType=not unknown and (retreat and "retreat" or "knockout") or nil,
            reason=unknown and "not_observed" or "matching_result_and_finish",
            outcomeObserved=not unknown,finishObserved=not unknown,resultObserved=not unknown,conflict=false,rankEligible=false}
        if row.mode=="practice" then r.duelMode="practice";r.rankReason="practice_selected"
        elseif not row.session then r.rankReason=unknown and "unknown_result" or retreat and "retreat" or "not_agreed" end
        if unknown then r.endReason="not_observed" end
        local ag=row.session and {scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session=row.session} or nil
        assert(history.Observe("run-1",r,ag))
    end
    for _,row in ipairs(localRows) do Observe(row) end
    local roots={version=2,kind="account",scope="SIMULATED",clients={[client]={probe=0,ledger=saved.ledger,
        identities=metadata,season={version=1,rule=ns.SeasonRules.BALANCED_ID,epoch=epoch,clocks=saved.clocks}}}}
    local char={version=2,kind="character",scope="SIMULATED",owner=me,clients={[client]={probe=0,runCounter=1,history=history.Save()}}}
    local store=ns.CompetitiveStorage.NewSimulated(function()return roots,char end,function()error("preview is read-only")end,
        function()return client end,function()return me end)
    store.MarkLoaded()
    local view=assert(store.OpenCompetitiveView(asOf))
    local replay=assert(store.ReadSeasonArchive(asOf))
    local change={}
    for _,r in ipairs(replay.changes) do change[r.id]=r end
    local personal=view.Personal()
    local matches={}
    for i=#personal.history,1,-1 do
        local row=personal.history[i]
        local r=row.matchID and change[row.matchID]
        local category=row.category
        if category=="matched" and r then category=r.weight>0 and "Ranked" or "Rating capped"
        elseif category=="matched" then category="Unconfirmed"
        elseif category=="practice" then category="Unranked"
        else category=category:sub(1,1):upper()..category:sub(2) end
        local before,after,delta
        if r and row.category=="matched" then
            local win=r.winner==me
            before=win and r.winnerBefore or r.loserBefore
            after=win and r.winnerAfter or r.loserAfter
            delta=after-before
        end
        matches[#matches+1]={id=row.id,identity=metadata[row.opponent],peer=row.opponent,
            category=category,outcome=row.outcome,duration=row.duration,before=before,after=after,delta=delta,
            time=r and r.time,confirmed=row.category=="matched",rankReason=row.rankReason,endReason=row.endReason}
    end
    return {scope="SIMULATED",rankEligible=false,client=client,me=me,view=view,identities=metadata,
        asOf=asOf,epoch=epoch,current=view.Status().season,personal=personal.overall,matches=matches}
end
P.Build=Build
local cached,session
function P.TestEnabled() return TEST_ENABLED end
function P.IsActive() return TEST_ENABLED and session~=nil end
-- This read-only source never opens a simulated store or invents a season,
-- rating, participant or match. Personal observations stay character-local.
function P.Local()
    local client=ns.Client.Kind()
    local storage=ns.CompetitiveStorage
    local snapshot,why=storage.ReadLocalHistory()
    local me=ns.Group.ReadPlayerIdentity("player")
    local asOf
    if type(GetServerTime)=="function" then
        local ok,t=pcall(GetServerTime)
        if ok and (not issecretvalue or not issecretvalue(t)) and type(t)=="number"
            and t>=1 and t<=4102444800 and t==math.floor(t) then asOf=t end
    end
    local view={}
    function view.ProfileSummary() return nil end
    function view.Profile() return nil end
    function view.Leaderboard() return {rows={},total=0} end
    function view.Progression() return {rows={},total=0} end
    local peer,peerReason
    if snapshot and asOf then peer,peerReason=storage.ReadPeerView(asOf) end
    if peer and peer.view then view=peer.view else peer=nil end
    local matched,disputed,changes={},{},{}
    if peer then
        for _,record in ipairs(peer.evidence.matched) do matched[record.id]=record end
        for _,record in ipairs(peer.evidence.disputed) do disputed[record.id]=true end
        for _,change in ipairs(peer.replay.changes) do changes[change.id]=change end
    end
    local matches={}
    if snapshot then
        for i=#snapshot.history,1,-1 do
            local row=snapshot.history[i]
            local identity=row.name and {name=row.name,fullName=row.fullName or row.name,
                realm=row.realm,class=row.class,faction=row.faction} or nil
            local category,confirmed,before,after,delta="Unranked",false
            if row.matchID then
                local record=matched[row.matchID]
                local own=record and me and (record.player1==me.guid and record.statement1 or
                    record.player2==me.guid and record.statement2)
                local change=changes[row.matchID]
                local clocks=peer and peer.clocks[row.matchID]
                if disputed[row.matchID] or (record and own~=row.statement) or (clocks and clocks[2]) then
                    category="Disputed"
                elseif record and own==row.statement and change then
                    category=change.weight>0 and "Ranked" or "Rating capped"
                    confirmed=true
                    if record.winner==me.guid then before,after=change.winnerBefore,change.winnerAfter
                    else before,after=change.loserBefore,change.loserAfter end
                    if before and after then delta=after-before end
                elseif ns.CompetitiveLifecycle and ns.CompetitiveLifecycle.IsResultPending and ns.CompetitiveLifecycle.IsResultPending(row.matchID) then
                    category="Pending"
                else category="Unconfirmed" end
            end
            matches[#matches+1]={id=row.id,identity=identity,peer=row.opponent,
                category=category,outcome=row.outcome,duration=row.duration,confirmed=confirmed,
                before=before,after=after,delta=delta,time=row.time,rankReason=row.rankReason,endReason=row.endReason}
        end
    end
    local capacity=storage.ReadLocalCapacity()
    return {scope="LOCAL",client=client,rankEligible=false,me=me and me.guid,
        current=peer and peer.replay.season or 0,epoch=peer and peer.epoch,asOf=asOf,
        view=view,identities=peer and peer.identities or {},personal=snapshot and snapshot.overall or {},
        matches=matches,storageReason=why,peerReason=peerReason,peerEvidence=peer~=nil,
        capacity=capacity,recordingDisabled=not storage.LocalRecordingEnabled()}
end
function P.Get()
    if not P.IsActive() then return P.Local() end
    return cached
end
local function Refresh()
    if ns.CompetitiveUI then ns.CompetitiveUI.Refresh() end
end
function P.Command(command)
    if not TEST_ENABLED then return false,"Solo simulation is unavailable in this build." end
    if command=="help" then return true,"/duels sim start | [unranked/pending] win/loss [1-20] | unknown/fled/retreat [1-20] | reset | stop | status" end
    if command=="stop" then
        session,cached=nil,nil;Refresh();return true,"Simulation discarded. Real data view restored."
    end
    if command=="status" then
        return true,session and ("SIMULATED: "..#session.." duels; /duels sim stop to exit.") or "Simulation inactive."
    end
    if command=="start" or command=="reset" then
        local ok,data=pcall(Build,ns.Client.Kind(),{})
        if not ok then return false,"Could not initialize test session." end
        session,cached={},data;Refresh();return true,"Empty SIMULATED session. No real data changed."
    end
    local mode,rest=command:match("^(%a+)%s+(.+)$")
    if mode~="practice" and mode~="unranked" and mode~="pending" then mode,rest="ranked",command end
    local verb,arg=rest:match("^(%a+)%s*(%d*)$")
    local outcomes={win="won",loss="lost",unknown="unknown",fled="fled",retreat="they_fled"}
    if not outcomes[verb] then return false,"Use /duels sim help." end
    if mode=="pending" and verb~="win" and verb~="loss" then return false,"Pending requires a knockout result." end
    if not session then return false,"Start with /duels sim start." end
    if #session>=MAX_EVENTS then return false,"Test limit reached. Use /duels sim reset." end
    local opponent=arg=="" and (#session%5+1) or tonumber(arg)
    if not opponent or opponent<1 or opponent>MAX_OPPONENTS then return false,"Opponent must be 1-20." end
    local nextEvents={}
    for i,e in ipairs(session) do nextEvents[i]=e end
    nextEvents[#nextEvents+1]={outcome=outcomes[verb],opponent=opponent,mode=mode}
    local ok,data=pcall(Build,ns.Client.Kind(),nextEvents)
    if not ok then return false,"Simulation rejected; previous state preserved." end
    session,cached=nextEvents,data;Refresh()
    local profile=data.view.ProfileSummary(data.me,data.current)
    return true,"SIMULATED "..verb.." vs Test Rival "..opponent.."; rating "..tostring(profile and profile.rating or "unavailable").."."
end

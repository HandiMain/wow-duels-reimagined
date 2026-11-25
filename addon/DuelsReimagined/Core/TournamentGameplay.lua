local _,ns=...
-- Match-scoped adapter for simulated detector snapshots. The bracket and
-- shared result validator remain the owners of advancement and duel evidence.
-- No live subscription, timer, challenge launch, storage or ranked mutation.
local G={};ns.TournamentGameplay=G
local P=ns.CompetitiveScope
local function Whole(v,lo,hi)
    return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v)
end
local function Time(v)
    return type(v)=="number" and v>=0 and v<math.huge
end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Find(view,id)
    if not view or view.scope~="SIMULATED" or view.state~="running" then return nil end
    for _,round in ipairs(view.rounds) do
        for _,m in ipairs(round) do if m.id==id and m.state=="ready" then return m end end
    end
end
function G.NewSimulated(scope,match,token,read,resolve,submit)
    if not P.Key(scope) or type(token)~="string" or #token>32 or not token:match("^[%w%-]+$")
        or type(read)~="function" or type(resolve)~="function" or type(submit)~="function" then return nil end
    local v,c=read();local m=Find(v,match)
    if not m or not c or c.paused or c.event~=v.event or c.owner~=v.owner
        or not Whole(c.term,1,2147483647) or not Guid(c.coordinator)
        or not Guid(m.a) or not Guid(m.b) or m.a==m.b then return nil end
    local a,b,event,term,controller=m.a,m.b,v.event,c.term,c.coordinator
    local game=m.wins[1]+m.wins[2]+1
    local attempt=m.replayedGame==game and 1 or nil
    if m.games[game] then return nil end
    local session="t"..term.."-"..match.."-"..game.."-"..(attempt or 0)..":"..token
    local evidence="T:"..session
    local slots={};local closed=false
    local D={}
    local function Current()
        if closed then return nil end
        local view,control=read();local row=Find(view,match)
        if not row or not control or control.paused or control.event~=event or view.event~=event
            or control.term~=term or control.coordinator~=controller or row.a~=a or row.b~=b
            or row.wins[1]+row.wins[2]+1~=game or (row.replayedGame==game and 1 or nil)~=attempt then
            closed=true;slots={};return nil
        end
        return row
    end
    local function Actor(sender)
        local actor=resolve(sender)
        if type(actor)=="table" and P.Matches(scope,actor) and (actor.guid==a or actor.guid==b) then
            return actor.guid,actor.guid==a and b or a
        end
    end
    local function SnapshotValid(s)
        return type(s)=="table" and s.scope=="SIMULATED" and s.client==scope.client and Whole(s.revision,0,2147483647)
    end
    function D.IsActive() return Current()~=nil end
    function D.Snapshot()
        local active=Current()~=nil
        return {scope="SIMULATED",event=event,match=match,game=game,attempt=attempt,term=term,
            player1=a,player2=b,bestOf=v.bestOf,rankEligible=false,mode="tournament",
            state=not active and "closed" or slots[a] and slots[b] and "ready" or "awaiting_players",
            player1State=slots[a] and slots[a].phase,player2State=slots[b] and slots[b].phase}
    end
    -- Consent and an idle baseline must precede the native challenge.
    function D.Consent(sender,s)
        if not Current() or not SnapshotValid(s) or s.state~="idle" or s.active or s.challenge then return false end
        local who=Actor(sender);if not who or slots[who] then return false end
        local last=s.last and s.last.id or 0
        if not Whole(last,0,2147483647) then return false end
        slots[who]={phase="consented",rev=s.revision,last=last}
        return true
    end
    local function Stop()
        closed=true;slots={};return false,"assignment_closed"
    end
    local function Deliver(sender,slot)
        if not Current() or not slot or not slot.pending then return false end
        local ok,why=submit(sender,slot.pending,term,controller)
        if not ok then return false,"retry" end
        slot.pending=nil;slot.phase="reported"
        -- Refresh authority after each accepted report. A confirmed game,
        -- dispute, pause, cancellation or migration invalidates this adapter.
        Current()
        return true,why
    end
    function D.Retry(sender)
        if not Current() then return false end
        local who=Actor(sender)
        return who and Deliver(sender,slots[who]) or false
    end
    function D.Observe(sender,s)
        if not Current() or not SnapshotValid(s) then return false end
        local who,peer=Actor(sender);local slot=who and slots[who]
        if not slot or slot.phase=="reported" or slot.pending or s.revision<=slot.rev then return false end
        if not slots[a] or not slots[b] then
            if s.state~="idle" then return Stop() end
            return false
        end
        slot.rev=s.revision
        if slot.phase=="consented" then
            if s.state=="idle" then
                if s.last and s.last.id~=slot.last then return Stop() end
                return false
            end
            local q=s.challenge
            if s.state~="challenge" or type(q)~="table" or not q.opponent or q.opponent.guid~=peer
                or q.rankedWidget==true or not Time(q.time)
                or not (q.direction=="outgoing" and (q.kind=="standard" or q.kind=="unclassified")
                    or q.direction=="incoming" and q.kind=="standard") then return Stop() end
            slot.phase="challenge";slot.challengeAt=q.time;slot.direction=q.direction
            return true,"challenge"
        end
        if slot.phase=="challenge" then
            if s.state=="challenge" then
                local q=s.challenge
                if not q or not q.opponent or q.opponent.guid~=peer or q.time~=slot.challengeAt
                    or q.direction~=slot.direction or q.rankedWidget==true then return Stop() end
                return true,"challenge"
            end
            local q=s.active
            if s.state~="accepted" or not q or not q.opponent or q.opponent.guid~=peer
                or not q.player or q.player.guid~=who or q.direction~=slot.direction or q.rankedWidget==true
                or not (q.kind=="standard" or q.kind=="unclassified") or not Whole(q.id,slot.last+1,2147483647)
                or not Time(q.acceptedAt) or q.acceptedAt<slot.challengeAt then return Stop() end
            slot.phase="playing";slot.cycle=q.id;slot.acceptedAt=q.acceptedAt
            return true,"playing"
        end
        if slot.phase~="playing" then return false end
        if s.state=="accepted" or s.state=="finishing" then
            local q=s.active
            if not q or q.id~=slot.cycle or not q.opponent or q.opponent.guid~=peer or q.acceptedAt~=slot.acceptedAt then return Stop() end
            return true,"playing"
        end
        local result=s.last
        if s.state~="idle" or not result or result.acceptedAt~=slot.acceptedAt or not Time(result.endedAt)
            or result.endedAt<slot.acceptedAt or result.duelMode and result.duelMode~="tournament" then return Stop() end
        local statement=ns.ResultConfirmation.MakeSimulatedStatement({scope="SIMULATED",client=scope.client,me=who,peer=peer,
            cycle=slot.cycle,agreement={scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session=session}},result)
        if not statement then return Stop() end
        -- The shared validator accepted a complete observation. Existing
        -- bracket logic compares independent reports and records conflicts.
        slot.pending={event=event,match=match,game=game,attempt=attempt,
            winner=result.outcome=="won" and who or peer,evidence=evidence}
        return Deliver(sender,slot)
    end
    return D
end

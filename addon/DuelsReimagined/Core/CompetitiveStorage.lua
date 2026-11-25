local _,ns=...
-- Isolated fixtures and gated local/peer persistence. Activation is locked.
local P={}
ns.CompetitiveStorage=P
local VERSION,MAX=2,2147483647
-- Explicit development gate. No local recording or run allocation before
-- actual detector/persistence verification; ranking has its own disabled gate.
local LOCAL_RECORDING_ENABLED=false
-- Test activation is a separate explicit build decision, not a preference.
-- A nil epoch cannot start a competitive calendar.
local PEER_TEST_ENABLED=false
local PEER_EPOCH=nil
function P.LocalRecordingEnabled() return LOCAL_RECORDING_ENABLED end
function P.PeerEpoch()
    if LOCAL_RECORDING_ENABLED and PEER_TEST_ENABLED and ns.CompetitiveScope and ns.CompetitiveScope.RankedReady() then return PEER_EPOCH end
end
local function Client(k) return k=="forever" or k=="retail" end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Count(v)
    return type(v)=="number" and v>=0 and v<=MAX and v==math.floor(v)
end
local function OpenLedger(client,raw)
    if type(raw)=="table" and raw.version==2 then return ns.MatchLedger.OpenCompactSimulated(client,raw) end
    return ns.MatchLedger.OpenSimulated(client,raw)
end
local function SaveLedger(node,previous)
    if type(previous)=="table" and previous.version==2 then return node.SaveCompact() end
    return node.Save()
end
local function Text(v,max)
    return type(v)=="string" and #v>0 and #v<=max and not v:find("[%c|]")
        and v:match("%S")~=nil
end
-- Local fixture metadata, not proof of a player's identity or class in a duel.
-- Never relayed or used in rating calculations. Latest whole observation wins.
local function Identity(client,v)
    if type(v)~="table" or v.scope~="SIMULATED" or v.client~=client or not Guid(v.guid)
        or not Text(v.name,64) or not Text(v.fullName,128)
        or type(v.observedAt)~="number" or v.observedAt<1 or v.observedAt>4102444800
        or v.observedAt~=math.floor(v.observedAt) then return nil end
    if v.realm~=nil and not Text(v.realm,64) then return nil end
    if v.class~=nil and (not Text(v.class,24) or not v.class:match("^[A-Z]+$")) then return nil end
    if v.faction~=nil and v.faction~="Alliance" and v.faction~="Horde" and v.faction~="Neutral" then return nil end
    local clean={scope="SIMULATED",client=client,guid=v.guid,name=v.name,fullName=v.fullName,
        observedAt=v.observedAt,realm=v.realm,class=v.class,faction=v.faction}
    for k in pairs(v) do if clean[k]==nil then return nil end end
    return clean
end
local function KnownPlayers(ledger)
    local known={}
    if ledger then
        local snap=ledger.Snapshot()
        for _,r in ipairs(snap.matched) do known[r.player1]=true;known[r.player2]=true end
        for _,e in ipairs(snap.disputed) do local r=e.evidence[1];known[r.player1]=true;known[r.player2]=true end
    end
    return known
end
-- One persisted ledger; season metadata adds only calendar and clock evidence.
local function SeasonNode(client,ledger,season)
    local rules=ns.SeasonRules
    if type(season)~="table" or season.version~=1 or season.rule~=rules.BALANCED_ID
        or not rules.Schedule(season.epoch,season.epoch) or type(season.clocks)~="table" or type(ledger)~="table" then return nil end
    for k in pairs(season) do if k~="version" and k~="rule" and k~="epoch" and k~="clocks" then return nil end end
    if ledger.version==2 then
        local opened=OpenLedger(client,ledger);if not opened then return nil end
        ledger=opened.Save()
    end
    return ns.LeaderboardSync.OpenSeasonSimulated(client,season.epoch,{version=1,scope="SIMULATED",client=client,
        rule=ns.CompetitiveRules.ID,ledger=ledger,clocks=season.clocks})
end
-- Exact, compact peer evidence. No simulation ledger is allowed here.
local function OpenPeerEvidence(client,raw)
    if type(raw)~="table" or raw.version~=1 or raw.scope~="PEER" or
        not ns.SeasonRules.Schedule(raw.epoch,raw.epoch) or type(raw.clocks)~="table" then return nil end
    for k in pairs(raw) do
        if k~="version" and k~="scope" and k~="epoch" and k~="ledger" and k~="clocks" then return nil end
    end
    local ledger=ns.MatchLedger.OpenCompactPeer(client,raw.ledger)
    if not ledger then return nil end
    return ns.LeaderboardSync.OpenSeasonPeer(client,raw.epoch,{version=1,scope="PEER",client=client,
        rule=ns.CompetitiveRules.ID,ledger=ledger.Save(),clocks=raw.clocks})
end
local function SavePeerEvidence(client,node)
    if not node or node.GetScope()~="PEER" then return nil end
    local data=node.Save()
    local ledger=ns.MatchLedger.OpenPeer(client,data.ledger)
    if not ledger then return nil end
    return {version=1,scope="PEER",epoch=node.GetSeasonEpoch(),ledger=ledger.SaveCompact(),clocks=data.clocks}
end
local function Root(raw,kind,owner,scope)
    local clean={version=VERSION,kind=kind,owner=owner,scope=scope,clients={}}
    if raw==nil then return clean end
    if type(raw)~="table" or (raw.version~=1 and raw.version~=VERSION) or raw.kind~=kind
        or raw.owner~=owner or type(raw.clients)~="table" then return nil end
    local legacy=raw.version==1
    if (legacy and raw.scope~=nil) or (not legacy and raw.scope~=scope) then return nil end
    for k in pairs(raw) do
        if k~="version" and k~="kind" and k~="owner" and k~="clients" and k~="scope" then return nil end
    end
    for k,v in pairs(raw.clients) do
        if not Client(k) or type(v)~="table" or not Count(v.probe) then return nil end
        local part={probe=v.probe}
        if kind=="character" then
            if not legacy and not Count(v.runCounter) then return nil end
            part.runCounter=legacy and 0 or v.runCounter
        end
        for field in pairs(v) do
            if field~="probe" and not (not legacy and kind=="character" and field=="runCounter")
                and not (not legacy and scope=="SIMULATED" and ((kind=="account" and (field=="ledger" or field=="season" or field=="identities"))
                    or (kind=="character" and field=="history")))
                and not (not legacy and scope=="LOCAL" and kind=="character" and (field=="localHistory" or field=="sessionStartIndex"))
                and not (not legacy and scope=="LOCAL" and kind=="account" and field=="peerEvidence") then return nil end
        end
        -- Only private simulation roots can contain simulated records.
        if scope=="SIMULATED" and not legacy then
            if kind=="account" and v.ledger~=nil then
                local ledger=OpenLedger(k,v.ledger)
                if not ledger then return nil end
                part.ledger=SaveLedger(ledger,v.ledger)
            elseif kind=="character" and v.history~=nil then
                local empty=ns.MatchLedger.OpenSimulated(k)
                local history=ns.PersonalHistory.OpenSimulated(k,owner,empty,v.history)
                if not history then return nil end
                part.history=history.Save()
                for _,src in ipairs(part.history.observations) do
                    local n=tonumber(src.run:match("^run%-(%d+)$"))
                    if not Count(n) or n==0 or n>part.runCounter or src.run~="run-"..n then return nil end
                end
            end
        end
        if scope=="LOCAL" and not legacy and kind=="character" and v.localHistory~=nil then
            local history=ns.PersonalHistory.OpenLocal(k,owner,v.localHistory)
            if not history then return nil end
            part.localHistory=history.Save()
            for _,src in ipairs(part.localHistory.observations) do
                local n=tonumber(src.run:match("^run%-(%d+)$"))
                if not Count(n) or n==0 or n>part.runCounter or src.run~="run-"..n then return nil end
            end
        end
        if scope=="LOCAL" and not legacy and kind=="character" and v.sessionStartIndex~=nil then
            if not Count(v.sessionStartIndex) or v.sessionStartIndex>(part.localHistory and #part.localHistory.observations or 0) then return nil end
            part.sessionStartIndex=v.sessionStartIndex
        end
        if scope=="LOCAL" and not legacy and kind=="account" and v.peerEvidence~=nil then
            local node=OpenPeerEvidence(k,v.peerEvidence)
            if not node then return nil end
            part.peerEvidence=SavePeerEvidence(k,node)
            if not part.peerEvidence then return nil end
        end
        if scope=="SIMULATED" and not legacy and kind=="account" and v.season~=nil then
            local node=SeasonNode(k,part.ledger,v.season)
            if not node then return nil end
            part.season={version=1,rule=v.season.rule,epoch=v.season.epoch,clocks=node.Save().clocks}
        end
        if scope=="SIMULATED" and not legacy and kind=="account" and v.identities~=nil then
            if type(v.identities)~="table" then return nil end
            local known=KnownPlayers(OpenLedger(k,part.ledger))
            local ids,n={},0
            for id,rawIdentity in pairs(v.identities) do
                n=n+1;if n>2*ns.MatchLedger.GetCapacity() or not known[id] then return nil end
                local cleanIdentity=Identity(k,rawIdentity)
                if not cleanIdentity or cleanIdentity.guid~=id then return nil end
                ids[id]=cleanIdentity
            end
            part.identities=ids
        end
        clean.clients[k]=part
    end
    return clean
end
-- Injected storage access for isolated tests. Never cache SavedVariables tables.
local BuildCompetitiveView
-- Project only the existing, append-only personal history. The session
-- boundary is a character-local row index, never a second match database.
local function SessionStats(history,start,replay)
    if type(history)~="table" or history.scope~="LOCAL" or type(history.history)~="table"
        or not Count(start) or start>#history.history then return nil end
    local out={scope="LOCAL",state="ready",total=0,wins=0,losses=0,unknown=0}
    local ids={}
    for i=start+1,#history.history do
        local row=history.history[i]
        out.total=out.total+1
        if row.outcome=="won" or row.outcome=="they_fled" then out.wins=out.wins+1
        elseif row.outcome=="lost" or row.outcome=="fled" then out.losses=out.losses+1
        else out.unknown=out.unknown+1 end
        if row.matchID then ids[row.matchID]=true end
    end
    if out.wins+out.losses>0 then out.winRate=out.wins/(out.wins+out.losses) end
    -- Only locally linked, peer-confirmed, rating-bearing replay entries.
    -- No subtraction of snapshots across seasons or unrelated sync changes.
    if type(replay)=="table" and replay.scope=="PEER" and replay.client==history.client then
        local seen={}
        for _,row in ipairs(replay.changes or {}) do
            if ids[row.id] and not seen[row.id] and type(row.weight)=="number" and row.weight>0 then
                local delta=row.winner==history.character and row.gain or row.loser==history.character and -row.loss
                if type(delta)=="number" then out.rating=(out.rating or 0)+delta;seen[row.id]=true end
            end
        end
    end
    return out
end
local function Build(read,write,client,identity,scope)
    scope=scope or "LOCAL"
    local D,loaded={},false
    function D.MarkLoaded() loaded=true end
    local function Pair()
        if not loaded then return nil,nil,nil,"not_loaded" end
        local k=client();if not Client(k) then return nil,nil,nil,"unsupported_client" end
        local owner=identity();if not Guid(owner) then return nil,nil,nil,"identity_unavailable" end
        local a,c=read()
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",owner,scope)
        if not aa or not cc then return nil,nil,nil,"invalid_or_unsupported_storage" end
        return aa,cc,k,nil,type(a)=="table" and a.version==VERSION and type(c)=="table" and c.version==VERSION
    end
    local function N(root,k) return root.clients[k] and root.clients[k].probe or 0 end
    function D.Snapshot()
        local a,c,k,why,prepared=Pair()
        if not a then return {scope=scope,state="unavailable",reason=why,rankEligible=false} end
        return {scope=scope,state="ready",version=VERSION,prepared=prepared,client=k,accountProbe=N(a,k),characterProbe=N(c,k),rankEligible=false}
    end
    function D.Probe()
        local a,c,k,why=Pair()
        if not a then return false,why end
        local x,y=N(a,k),N(c,k)
        if x>=MAX or y>=MAX then return false,"capacity" end
        a.clients[k]=a.clients[k] or {probe=0};c.clients[k]=c.clients[k] or {probe=0,runCounter=0}
        a.clients[k].probe=x+1;c.clients[k].probe=y+1
        -- Both roots validated first. No changes on rejection; replace only
        -- our two dedicated roots, never the existing preferences database.
        write(a,c)
        return true
    end
    function D.Prepare()
        local a,c,k,why,prepared=Pair()
        if not a then return false,why end
        if not prepared then write(a,c) end
        return true
    end
    -- Local observations use the character root only. No shared ledger,
    -- rating, simulated record, or account competitive data is imported.
    function D.ReadLocalHistory()
        if scope~="LOCAL" then return nil,"wrong_scope" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local cp=c.clients[k] or {probe=0,runCounter=0}
        local h=ns.PersonalHistory.OpenLocal(k,c.owner,cp.localHistory)
        if not h then return nil,"invalid_history" end
        return h.Snapshot()
    end
    function D.StartSession(reset)
        if scope~="LOCAL" or not LOCAL_RECORDING_ENABLED then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local cp=c.clients[k] or {probe=0,runCounter=0}
        if cp.sessionStartIndex~=nil and not reset then return true end
        cp.sessionStartIndex=cp.localHistory and #cp.localHistory.observations or 0
        c.clients[k]=cp
        local clean=Root(c,"character",c.owner,scope)
        if not clean then return false,"invalid_history" end
        write(a,clean);return true
    end
    function D.ReadSessionStats(asOf)
        if scope~="LOCAL" or not LOCAL_RECORDING_ENABLED then return {scope="LOCAL",state="disabled"} end
        local a,c,k=Pair()
        local cp=c and c.clients[k]
        if not cp or cp.sessionStartIndex==nil then return {scope="LOCAL",state="unavailable"} end
        local history=ns.PersonalHistory.OpenLocal(k,c.owner,cp.localHistory)
        if not history then return {scope="LOCAL",state="unavailable"} end
        local peer=P.PeerEpoch() and asOf and D.ReadPeerView(asOf)
        return SessionStats(history.Snapshot(),cp.sessionStartIndex,peer and peer.replay)
            or {scope="LOCAL",state="unavailable"}
    end
    function D.BeginLocalRun()
        if scope~="LOCAL" or not LOCAL_RECORDING_ENABLED then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local cp=c.clients[k] or {probe=0,runCounter=0}
        if cp.runCounter>=MAX then return nil,"capacity" end
        cp.runCounter=cp.runCounter+1;c.clients[k]=cp
        local clean=Root(c,"character",c.owner,scope)
        if not clean then return nil,"invalid_history" end
        write(a,clean);return "run-"..cp.runCounter
    end
    function D.RecordLocalObservation(run,r,agreement)
        if scope~="LOCAL" or not LOCAL_RECORDING_ENABLED then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local cp=c.clients[k]
        if not cp or cp.runCounter==0 or run~="run-"..cp.runCounter then return false,"stale_run" end
        local h=ns.PersonalHistory.OpenLocal(k,c.owner,cp.localHistory)
        if not h then return false,"invalid_history" end
        local ok,reason=h.Observe(run,r,agreement)
        if not ok then return false,reason end
        cp.localHistory=h.Save()
        local clean=Root(c,"character",c.owner,scope)
        if not clean then return false,"invalid_history" end
        write(a,clean);return true
    end
    -- Single live owner obtains a detached node, then commits only its
    -- validated compact source. No derived rating is written to SavedVariables.
    function D.OpenPeerNode()
        local epoch=P.PeerEpoch()
        if scope~="LOCAL" or not epoch then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local raw=a.clients[k] and a.clients[k].peerEvidence
        if raw and raw.epoch~=epoch then return nil,"schedule_mismatch" end
        if raw then return OpenPeerEvidence(k,raw) end
        return ns.LeaderboardSync.OpenSeasonPeer(k,epoch)
    end
    local function SameEvidence(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for k,v in pairs(a) do if not SameEvidence(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    function D.CommitPeerNode(node)
        local epoch=P.PeerEpoch()
        if scope~="LOCAL" or not epoch then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        if not node or node.GetScope()~="PEER" or node.GetSeasonEpoch()~=epoch then return false,"context" end
        local ap=a.clients[k] or {probe=0}
        if ap.peerEvidence and ap.peerEvidence.epoch~=epoch then return false,"schedule_mismatch" end
        local raw=SavePeerEvidence(k,node)
        if not raw or not OpenPeerEvidence(k,raw) then return false,"invalid_evidence" end
        if ap.peerEvidence then
            local prior=OpenPeerEvidence(k,ap.peerEvidence)
            local proposed=node.Save()
            if not prior or not prior.MergeSaved(proposed) or not SameEvidence(prior.Save(),proposed) then
                return false,"stale_or_incomplete_evidence"
            end
        end
        ap.peerEvidence=raw;a.clients[k]=ap
        local clean=Root(a,"account",nil,scope)
        if not clean then return false,"invalid_evidence" end
        write(clean,c);return true
    end
    function D.ReadLocalCapacity()
        if scope~="LOCAL" then return nil,"wrong_scope" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local ap,cp=a.clients[k] or {},c.clients[k] or {}
        local n=0
        for _ in pairs(ap.peerEvidence and ap.peerEvidence.ledger.entries or {}) do n=n+1 end
        local function Cap(used,limit)
            return {used=used,limit=limit,state=used>=limit and "full" or used>=limit*.9 and "near_capacity" or "available"}
        end
        return {scope="LOCAL",policy="preserve_exact_evidence",history=Cap(cp.localHistory and #cp.localHistory.observations or 0,ns.PersonalHistory.GetCapacity()),
            ledger=Cap(n,ns.MatchLedger.GetCapacity())}
    end
    function D.ReadPeerView(asOf)
        if scope~="LOCAL" then return nil,"wrong_scope" end
        if not ns.CompetitiveScope or not ns.CompetitiveScope.RankedReady() then return nil,"population_migration_required" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local raw=a.clients[k] and a.clients[k].peerEvidence
        if not raw then return nil,"no_evidence" end
        local node=OpenPeerEvidence(k,raw)
        if not node then return nil,"invalid_evidence" end
        local replay,err=node.ReplaySeasonPeer({epoch=raw.epoch,asOf=asOf})
        if not replay then return nil,err end
        local cp=c.clients[k] or {}
        local history=ns.PersonalHistory.OpenLocal(k,c.owner,cp.localHistory)
        if not history then return nil,"invalid_history" end
        local personal=history.Snapshot()
        local identities={}
        -- Only locally observed metadata; relayed claims never invent names.
        for _,row in ipairs(personal.history) do
            if row.opponent and row.name then
                identities[row.opponent]={guid=row.opponent,name=row.name,fullName=row.fullName or row.name,
                    realm=row.realm,class=row.class,faction=row.faction}
            end
        end
        local me=ns.Group.ReadCompetitiveIdentity and ns.Group.ReadCompetitiveIdentity("player")
        if me and me.guid==c.owner then identities[c.owner]=me end
        local view=BuildCompetitiveView(k,c.owner,personal,replay,asOf,identities,"PEER")
        local ledger=ns.MatchLedger.OpenCompactPeer(k,raw.ledger)
        return {view=view,replay=replay,epoch=raw.epoch,identities=identities,evidence=ledger.Snapshot(),
            clocks=raw.clocks}
    end
    -- Private fixture transaction: reopen from validated data every time;
    -- write only canonical record sources after successful edit. No live path.
    local function Records(a,c,k)
        local ap=a.clients[k] or {probe=0}
        local cp=c.clients[k] or {probe=0,runCounter=0}
        local ledger=OpenLedger(k,ap.ledger)
        if not ledger then return end
        local history=ns.PersonalHistory.OpenSimulated(k,c.owner,ledger,cp.history)
        if not history then return end
        return ledger,history,ap,cp
    end
    function D.ReadRecords()
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local l,h,_,cp=Records(a,c,k);if not l then return nil,"invalid_records" end
        return {scope=scope,ledger=l.Snapshot(),history=h.Snapshot(),runCounter=cp.runCounter}
    end
    function D.UpdateRecords(newRun,edit)
        if scope~="SIMULATED" then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local l,h,ap,cp=Records(a,c,k);if not l then return false,"invalid_records" end
        if newRun then
            if cp.runCounter>=MAX then return false,"capacity" end
            cp.runCounter=cp.runCounter+1
        end
        local run=cp.runCounter>0 and "run-"..cp.runCounter or nil
        local ok,accept=pcall(edit,l,h,run)
        if not ok or accept~=true then return false,"edit_rejected" end
        ap.ledger=SaveLedger(l,ap.ledger);cp.history=h.Save();a.clients[k]=ap;c.clients[k]=cp
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,run
    end
    -- Same canonical transaction for local fixtures and received logical pages.
    local function UpdateSeason(epoch,edit)
        if scope~="SIMULATED" then return false,"disabled" end
        local rules=ns.SeasonRules
        if not rules.Schedule(epoch,epoch) then return false,"invalid_schedule" end
        local a,c,k,why=Pair();if not a then return false,why end
        local ap=a.clients[k] or {probe=0}
        if ap.season and ap.season.epoch~=epoch then return false,"schedule_mismatch" end
        local ledger=ap.ledger or assert(ns.MatchLedger.OpenSimulated(k)).Save()
        local season=ap.season or {version=1,rule=rules.BALANCED_ID,epoch=epoch,clocks={}}
        local node=SeasonNode(k,ledger,season);if not node then return false,"invalid_season" end
        local ok,status=edit(node);if not ok then return false,status end
        if ap.season and status=="unchanged" then return true,status end
        local saved=node.Save()
        if ledger.version==2 then
            ap.ledger=assert(OpenLedger(k,saved.ledger)).SaveCompact()
        else ap.ledger=saved.ledger end
        ap.season={version=1,rule=season.rule,epoch=epoch,clocks=saved.clocks};a.clients[k]=ap
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,status
    end
    function D.UpdateSeasonEvidence(epoch,record,t1,t2)
        return UpdateSeason(epoch,function(node) return node.Observe(record,t1,t2) end)
    end
    -- Only an explicitly compatible simulated source page. This is not a
    -- transport receiver and cannot authenticate the injected sender.
    function D.ImportSeasonPage(epoch,context,page,sender,expected,token)
        if scope~="SIMULATED" then return false,"disabled" end
        return UpdateSeason(epoch,function(node)
            local k=client()
            local descriptor=ns.CompetitiveIntegrity.SeasonDescriptor(k,epoch)
            if not descriptor or context~=descriptor then return false,"season_context" end
            return node.Receive(page,sender,expected,token)
        end)
    end
    -- Explicit, lossless conversion of the one account evidence store.
    -- Old builds cannot open compact evidence. No automatic migration.
    function D.CompactEvidence()
        if scope~="SIMULATED" then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local ap=a.clients[k]
        if not ap or not ap.ledger then return false,"no_ledger" end
        if ap.ledger.version==2 then return true,"unchanged" end
        local ledger=OpenLedger(k,ap.ledger);if not ledger then return false,"invalid_ledger" end
        ap.ledger=ledger.SaveCompact()
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,"compacted"
    end
    function D.ObserveIdentity(v)
        if scope~="SIMULATED" then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local clean=Identity(k,v);if not clean then return false,"invalid_identity" end
        local ap=a.clients[k]
        if not ap or not ap.ledger or not KnownPlayers(OpenLedger(k,ap.ledger))[clean.guid] then return false,"not_observed" end
        ap.identities=ap.identities or {}
        local old=ap.identities[clean.guid]
        if old then
            if clean.observedAt<old.observedAt then return false,"stale_identity" end
            if clean.observedAt==old.observedAt then
                for field,value in pairs(clean) do if old[field]~=value then return false,"identity_conflict" end end
                for field,value in pairs(old) do if clean[field]~=value then return false,"identity_conflict" end end
                return true,"unchanged"
            end
        end
        ap.identities[clean.guid]=clean
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,"observed"
    end
    function D.ReadCapacity()
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local ap,cp=a.clients[k] or {},c.clients[k] or {}
        local n=0
        for _ in pairs(ap.ledger and ap.ledger.entries or {}) do n=n+1 end
        local h=cp.history and #cp.history.observations or 0
        local function Capacity(used,limit)
            return {used=used,limit=limit,remaining=limit-used,state=used>=limit and "full" or used>=limit*0.9 and "near_capacity" or "available"}
        end
        return {scope="SIMULATED",client=k,rankEligible=false,policy="preserve_evidence",
            ledger=Capacity(n,ns.MatchLedger.GetCapacity()),history=Capacity(h,ns.PersonalHistory.GetCapacity()),
            ledgerEncoding=ap.ledger and ap.ledger.version==2 and "compact" or "expanded"}
    end
    function D.ReadSeasonArchive(asOf)
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local ap=a.clients[k];if not ap or not ap.season then return nil,"no_archive" end
        local node=SeasonNode(k,ap.ledger,ap.season);if not node then return nil,"invalid_season" end
        local result,err=node.ReplaySeasonSimulated({epoch=ap.season.epoch,asOf=asOf})
        if not result then return nil,err end
        result.character=c.owner;return result
    end
    -- Build one private read snapshot per refresh. Derived queries reuse it;
    -- no duplicate persisted ratings or cache across storage transactions.
    function D.OpenCompetitiveView(asOf)
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local l,h,ap=Records(a,c,k);if not l then return nil,"invalid_records" end
        local replay
        if ap.season then
            local node=SeasonNode(k,ap.ledger,ap.season);if not node then return nil,"invalid_season" end
            replay,why=node.ReplaySeasonSimulated({epoch=ap.season.epoch,asOf=asOf})
            if not replay then return nil,why end
        end
        return BuildCompetitiveView(k,c.owner,h.Snapshot(),replay,asOf,ap.identities or {})
    end
    return D
end
-- Read model uses authoritative replay changes, not a second rating formula.
-- Private: called only with validated snapshots from the storage owner.
local function CopyView(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=CopyView(x) end;return out
end
local function Stat()
    return {wins=0,losses=0,games=0,practiceWins=0,practiceLosses=0,
        currentStreak=0,bestStreak=0,worstStreak=0,opponents={},progression={}}
end
local function TallyCompetitive(s,peer,won,row,rating)
    local o=s.opponents[peer] or {wins=0,losses=0,practiceWins=0,practiceLosses=0}
    s.opponents[peer]=o
    if row.weight>0 then
        local field=won and "wins" or "losses"
        s[field]=s[field]+1;o[field]=o[field]+1;s.games=s.games+1
        s.currentStreak=won and math.max(0,s.currentStreak)+1 or math.min(0,s.currentStreak)-1
        s.bestStreak=math.max(s.bestStreak,s.currentStreak)
        s.worstStreak=math.max(s.worstStreak,-s.currentStreak)
        s.progression[#s.progression+1]={id=row.id,time=row.time,rating=rating,season=row.season,
            delta=won and row.gain or -row.loss}
    else
        local field=won and "practiceWins" or "practiceLosses"
        s[field]=s[field]+1;o[field]=o[field]+1
    end
end
local function FinishStat(s)
    if s.games>0 then s.winRate=s.wins/s.games end
    for _,o in pairs(s.opponents) do
        if o.wins+o.losses>0 then o.winRate=o.wins/(o.wins+o.losses) end
    end
end
BuildCompetitiveView=function(client,me,personal,replay,asOf,identities,viewScope)
    viewScope=viewScope or "SIMULATED"
    local D,bySeason,byPlayer,boards={},{},{},{}
    local current=replay and replay.season
    if not Count(asOf) or asOf==0 then
        -- Replay permits UTC through 2100, beyond the run-counter bound.
        if type(asOf)~="number" or asOf<1 or asOf>4102444800 or asOf~=math.floor(asOf) then return nil,"invalid_time" end
    end
    local function Stats(id,season)
        local rows=bySeason[season] or {};bySeason[season]=rows
        local s=rows[id]
        if not s then
            s=Stat();rows[id]=s
            local all=byPlayer[id] or {};byPlayer[id]=all;all[season]=s
        end
        return s
    end
    if replay then
        for _,row in ipairs(replay.changes) do
            TallyCompetitive(Stats(row.winner,row.season),row.loser,true,row,row.winnerAfter)
            TallyCompetitive(Stats(row.loser,row.season),row.winner,false,row,row.loserAfter)
        end
        for _,seasons in pairs(byPlayer) do for _,s in pairs(seasons) do FinishStat(s) end end
    end
    local function Players(season)
        if not replay then return nil end
        if season==current then return replay.players end
        local h=replay.history[season];return h and h.players
    end
    local function ValidSeason(season)
        return current and type(season)=="number" and season>=1 and season<=current and season==math.floor(season)
    end
    local function Board(season)
        if boards[season] then return boards[season] end
        local rows={}
        for id,p in pairs(Players(season) or {}) do
            if p.rank and not p.rank.provisional and p.credit>0 then
                rows[#rows+1]={id=id,rating=p.rating,rank=CopyView(p.rank),games=p.games,wins=p.wins,
                    losses=p.losses,winRate=p.games>0 and p.wins/p.games or nil,
                    peakRating=p.peakRating,credit=p.credit}
            end
        end
        table.sort(rows,function(a,b) if a.rating~=b.rating then return a.rating>b.rating end;return a.id<b.id end)
        local positions={}
        for i,row in ipairs(rows) do row.position=i;positions[row.id]=i end
        for _,row in ipairs(rows) do row.identity=CopyView(identities[row.id]) end
        boards[season]={rows=rows,positions=positions,sorts={rating=rows}}
        return boards[season]
    end
    function D.Status()
        return {scope=viewScope,client=client,character=me,season=current,asOf=asOf,
            state=replay and "ready" or "no_archive",rankEligible=false,completeness="unknown",
            evidence=replay and {matched=replay.matched,rated=replay.rated,practice=replay.restricted,
                disputed=replay.disputed,missingTime=replay.missingTime,timeDisputed=replay.timeDisputed} or nil}
    end
    function D.Personal() return CopyView(personal) end
    -- Latest local identity observation is not historical class/faction proof.
    -- Private personal history never appears in competitive profiles.
    local function Profile(id,season,summaryOnly)
        if not Guid(id) then return nil,"identity" end
        if season==nil then season=current end
        if not ValidSeason(season) then return nil,"no_season" end
        if not byPlayer[id] then return nil,"not_observed" end
        local p=(Players(season) or {})[id]
        local s=byPlayer[id][season]
        local out={scope=viewScope,client=client,id=id,season=season,rankEligible=false,completeness="unknown",
            state=p and p.credit>0 and "observed" or "inactive",stats={},seasons={},
            identity=CopyView(identities[id])}
        for k,v in pairs(s or Stat()) do
            if not summaryOnly or (k~="opponents" and k~="progression") then out.stats[k]=CopyView(v) end
        end
        if p and p.credit>0 then
            out.rating=p.rating;out.peakRating=p.peakRating;out.rank=CopyView(p.rank);out.peakRank=CopyView(p.peakRank)
            out.credit=p.credit;out.rivalCount=p.rivalCount
            out.position=Board(season).positions[id]
        end
        for n=1,current do
            local prior=(Players(n) or {})[id]
            if prior and prior.credit>0 then
                out.seasons[#out.seasons+1]={season=n,rating=prior.rating,peakRating=prior.peakRating,
                    rank=CopyView(prior.rank),games=prior.games,wins=prior.wins,losses=prior.losses}
            end
        end
        return out
    end
    function D.Profile(id,season) return Profile(id,season,false) end
    function D.ProfileSummary(id,season) return Profile(id,season,true) end
    function D.Progression(id,season,offset,limit)
        season=season or current;offset=offset or 0;limit=limit or 25
        if not ValidSeason(season) or not Guid(id) or not Count(offset) or not Count(limit) or limit<1 or limit>100 then
            return nil,"invalid_query"
        end
        local stats=byPlayer[id] and byPlayer[id][season]
        local rows=stats and stats.progression or {}
        local out={scope=viewScope,client=client,rankEligible=false,completeness="unknown",total=#rows,offset=offset,rows={}}
        for i=offset+1,math.min(offset+limit,#rows) do out.rows[#out.rows+1]=CopyView(rows[i]) end
        return out
    end
    function D.Leaderboard(season,offset,limit,query,sort)
        season=season or current;offset=offset or 0;limit=limit or 25;query=query or "";sort=sort or "rating"
        if not ValidSeason(season) then return nil,"no_season" end
        if not Count(offset) or not Count(limit) or limit<1 or limit>100 or type(query)~="string" or #query>128
            or query:find("%c") or (sort~="rating" and sort~="wins" and sort~="winRate" and sort~="games") then return nil,"invalid_query" end
        local board=Board(season)
        local ordered=board.sorts[sort]
        if not ordered then
            ordered={};for i,row in ipairs(board.rows) do ordered[i]=row end
            table.sort(ordered,function(a,b)
                if a[sort]~=b[sort] then return a[sort]>b[sort] end
                return a.position<b.position
            end)
            board.sorts[sort]=ordered
        end
        query=query:lower()
        local out={scope=viewScope,client=client,season=season,rankEligible=false,completeness="unknown",
            total=0,knownRanked=#board.rows,offset=offset,rows={}}
        for _,row in ipairs(ordered) do
            local v=row.identity
            if row.id:lower():find(query,1,true) or (v and
                (v.name:lower():find(query,1,true) or v.fullName:lower():find(query,1,true)
                 or (v.realm and v.realm:lower():find(query,1,true)))) then
                out.total=out.total+1
                if out.total>offset and #out.rows<limit then out.rows[#out.rows+1]=CopyView(row) end
            end
        end
        return out
    end
    return D
end
-- Injected private roots only. No production adapter.
function P.NewSimulated(read,write,client,identity)
    return Build(read,write,client,identity,"SIMULATED")
end
local live=Build(function() return _G.DuelsReimaginedCompetitiveDB,_G.DuelsReimaginedCharacterDB end,
    function(a,c) _G.DuelsReimaginedCompetitiveDB=a;_G.DuelsReimaginedCharacterDB=c end,
    function() return ns.Client.Kind() end,
    function()
        local id=ns.Group and ns.Group.ReadPlayerIdentity("player")
        return id and id.guid
    end)
P.MarkLoaded=live.MarkLoaded
P.GetSnapshot=live.Snapshot
P.RunPersistenceProbe=live.Probe
P.PrepareSchema=live.Prepare
P.ReadLocalHistory=live.ReadLocalHistory
P.BeginLocalRun=live.BeginLocalRun
P.RecordLocalObservation=live.RecordLocalObservation
P.OpenPeerNode=live.OpenPeerNode
P.CommitPeerNode=live.CommitPeerNode
P.ReadLocalCapacity=live.ReadLocalCapacity
P.ReadPeerView=live.ReadPeerView
P.StartSession=live.StartSession
P.ReadSessionStats=live.ReadSessionStats
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSessionSelfTest()
    local h={scope="LOCAL",client="retail",character="Player-1-AAA",history={{outcome="won"},{outcome="lost",matchID="a"},{outcome="they_fled"},{outcome="unknown"},{outcome="won",matchID="b"}}}
    local replay={scope="PEER",client="retail",changes={{id="a",weight=1,loser=h.character,loss=15},{id="b",weight=1,winner=h.character,gain=30},{id="b",weight=1,winner=h.character,gain=30},{id="unlinked",weight=1,winner=h.character,gain=99}}}
    local v=assert(SessionStats(h,1,replay));assert(v.total==4 and v.wins==2 and v.losses==1 and v.unknown==1 and math.abs(v.winRate-2/3)<.001 and v.rating==15)
    v=assert(SessionStats(h,5));assert(v.total==0 and v.winRate==nil and v.rating==nil)
    assert(not SessionStats(h,6));replay.scope="SIMULATED";assert(SessionStats(h,1,replay).rating==nil)
    h.scope="SIMULATED";assert(not SessionStats(h,0));assert(P.ReadSessionStats().state=="disabled" and not P.StartSession(true))
    return true
end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    Case("session statistics projection and disabled live gate",P.RunSessionSelfTest)
    local me,alt="Player-1-AAA","Player-2-BBB"
    for _,client in ipairs({"forever","retail"}) do
        local other=client=="forever" and "retail" or "forever"
        local function Fixture()
            local f={client=client,owner=me,writes=0}
            function f.open(load)
                local d=Build(function()return f.a,f.c end,function(a,c)f.a=a;f.c=c;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end)
                if load~=false then d.MarkLoaded() end
                return d
            end
            return f
        end
        Case(client.." before load and read-only defaults",function()
            local f=Fixture();local d=f.open(false);assert(d.Snapshot().reason=="not_loaded" and not d.Probe())
            d.MarkLoaded();local s=d.Snapshot();assert(s.state=="ready" and s.accountProbe==0 and s.characterProbe==0 and f.writes==0 and f.a==nil and f.c==nil)
        end)
        Case(client.." explicit probe and simulated reload",function()
            local f=Fixture();local d=f.open();assert(d.Probe());local s=f.open().Snapshot();assert(s.accountProbe==1 and s.characterProbe==1 and f.writes==1)
            assert(f.open().Probe());s=d.Snapshot();assert(s.accountProbe==2 and s.characterProbe==2)
        end)
        Case(client.." character switching and return",function()
            local f=Fixture();local d=f.open();assert(d.Probe());local saved=f.c;f.c=nil;f.owner=alt
            local s=f.open().Snapshot();assert(s.accountProbe==1 and s.characterProbe==0)
            assert(f.open().Probe());f.c=saved;f.owner=me;s=f.open().Snapshot();assert(s.accountProbe==2 and s.characterProbe==1)
        end)
        Case(client.." mismatched character root rejected",function()
            local f=Fixture();local d=f.open();d.Probe();local a,c=f.a,f.c;f.owner=alt
            assert(not d.Probe() and d.Snapshot().state=="unavailable" and f.a==a and f.c==c and f.writes==1)
        end)
        Case(client.." client partition separation",function()
            local f=Fixture();local d=f.open();d.Probe();f.client=other;local s=d.Snapshot();assert(s.accountProbe==0 and s.characterProbe==0)
            d.Probe();d.Probe();f.client=client;s=d.Snapshot();assert(s.accountProbe==1 and s.characterProbe==1)
            f.client=other;s=d.Snapshot();assert(s.accountProbe==2 and s.characterProbe==2)
        end)
        Case(client.." unknown schema preserved",function()
            local f=Fixture();local d=f.open();d.Probe();f.a.version=3;local a,c=f.a,f.c
            assert(not d.Probe() and f.a==a and f.c==c and f.a.version==3 and f.writes==1)
        end)
        Case(client.." corrupt character refuses both writes",function()
            local f=Fixture();local d=f.open();d.Probe();f.c.clients[client].probe=-1;local a,c=f.a,f.c
            assert(not d.Probe() and f.a==a and f.c==c and f.a.clients[client].probe==1 and f.writes==1)
        end)
        Case(client.." unknown fields not silently stripped",function()
            local f=Fixture();local d=f.open();d.Probe();f.a.clients[client].records={}
            assert(not d.Probe() and type(f.a.clients[client].records)=="table" and f.writes==1)
        end)
        Case(client.." unavailable identity and unsupported client",function()
            local f=Fixture();local d=f.open();f.owner=nil;assert(not d.Probe());f.owner=me;f.client="unsupported"
            assert(not d.Probe() and f.writes==0)
        end)
        Case(client.." bounded counters and independent snapshots",function()
            local f=Fixture();local d=f.open();d.Probe();local s=d.Snapshot();s.accountProbe=99;assert(d.Snapshot().accountProbe==1)
            f.c.clients[client].probe=MAX;assert(not d.Probe() and f.a.clients[client].probe==1 and f.writes==1)
        end)
    end
    Case("live SavedVariables untouched by isolated storage QA",function()
        -- The fixture engine never uses the live writer.
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.rankEligible==false)
    end)
    return passed,failed
end

function P.RunRecordSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,peer,alt="Player-1-AAA","Player-2-BBB","Player-3-CCC"
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={owner=me,client=client,writes=0}
            function f.open()
                local d=Build(function()return f.a,f.c end,function(a,c)f.a=a;f.c=c;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                d.MarkLoaded();return d
            end
            return f
        end
        local function Observation(n,out)
            return {scope="SIMULATED",client=client,id=n,kind="standard",opponent={guid=peer},acceptedAt=10,endedAt=20,
                outcome=out or "won",endType="knockout",reason="matching_result_and_finish",outcomeObserved=true,
                finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
        end
        local function Agreement()
            return {scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session="a-1:b-1"}
        end
        local function Record(reverse)
            local session=Agreement().session
            local x,y=reverse and "lost" or "won",reverse and "won" or "lost"
            return {scope="SIMULATED",version="1",client=client,session=session,id=client.."|"..me.."|"..peer.."|"..session,
                player1=me,player2=peer,winner=reverse and peer or me,loser=reverse and me or peer,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,session,me,peer,x,"1"},"|"),statement2=table.concat({"1",client,session,peer,me,y,"2"},"|")}
        end
        Case(client.." v1 migration preserves counters / explicit prepare",function()
            local f=Fixture("LOCAL");f.a={version=1,kind="account",clients={[client]={probe=4}}}
            f.c={version=1,kind="character",owner=me,clients={[client]={probe=2}}}
            local d=f.open();assert(not d.Snapshot().prepared and f.writes==0);assert(d.Prepare());assert(d.Prepare())
            local s=f.open().Snapshot();assert(s.prepared and s.version==2 and s.accountProbe==4 and s.characterProbe==2 and f.writes==1)
        end)
        Case(client.." record roundtrip / local run IDs survive reopen",function()
            local f=Fixture();local d=f.open();assert(d.UpdateRecords(true,function(l,h,run) assert(run=="run-1");return h.Observe(run,Observation(1),Agreement()) end))
            assert(f.open().UpdateRecords(false,function(l,h,run) assert(run=="run-1" and not h.Observe(run,Observation(1),Agreement()));return l.Insert(Record()) end))
            local s=f.open().ReadRecords();assert(s.history.categories.matched.total==1 and s.history.overall.total==1 and #s.ledger.matched==1)
            assert(f.open().UpdateRecords(true,function(l,h,run) assert(run=="run-2");return h.Observe(run,Observation(1,"lost")) end))
            s=f.open().ReadRecords();assert(s.runCounter==2 and s.history.overall.total==2 and s.history.overall.winRate==0.5)
        end)
        Case(client.." late dispute persists across reopen",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run) assert(h.Observe(run,Observation(1),Agreement()));return l.Insert(Record()) end))
            assert(f.open().UpdateRecords(false,function(l)return l.Insert(Record(true)) end))
            local s=f.open().ReadRecords();assert(#s.ledger.disputed==1 and s.history.categories.disputed.total==1 and s.history.categories.matched.total==0 and s.history.overall.wins==1)
        end)
        Case(client.." account ledger shared / character history isolated",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run)assert(h.Observe(run,Observation(1),Agreement()));return l.Insert(Record())end))
            local saved=f.c;f.c=nil;f.owner=alt;local s=f.open().ReadRecords();assert(#s.ledger.matched==1 and s.history.overall.total==0 and s.runCounter==0)
            f.c=saved;f.owner=me;assert(f.open().ReadRecords().history.overall.total==1)
        end)
        Case(client.." invalid saved evidence and rejected edit preserve roots",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run)return h.Observe(run,Observation(1))end))
            local a,c=f.a,f.c;assert(not f.open().UpdateRecords(true,function()error("fixture")end));assert(f.a==a and f.c==c and f.writes==1)
            c.clients[client].history.observations[1].result.extra=true
            assert(not f.open().ReadRecords() and not f.open().UpdateRecords(true,function()return true end) and f.c==c and f.a==a)
        end)
        Case(client.." live gate rejects fixtures and record operations",function()
            local f=Fixture("LOCAL");local d=f.open();assert(d.Prepare());assert(not d.ReadRecords() and not d.UpdateRecords(true,function()error("must not run")end))
            local sim=Fixture();assert(sim.open().UpdateRecords(true,function(l,h,run)return h.Observe(run,Observation(1))end))
            f.a=sim.a;f.c=sim.c;assert(d.Snapshot().state=="unavailable" and not d.Prepare() and f.writes==1)
        end)
        Case(client.." invalid run token and unknown outcome roundtrip",function()
            local f=Fixture();assert(not f.open().UpdateRecords(true,function(l,h)return h.Observe("run-99",Observation(1))end));assert(f.writes==0)
            assert(f.open().UpdateRecords(true,function(l,h,run)local r=Observation(1);r.finishObserved=false;return h.Observe(run,r)end))
            local s=f.open().ReadRecords();assert(s.history.overall.unknown==1 and s.history.overall.wins==0)
        end)
    end
    Case("live status remains non-ranking",function()assert(P.GetSnapshot().rankEligible==false)end)
    return passed,failed
end

function P.RunArchiveSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    local epoch=100;local boundary=epoch+ns.SeasonRules.DURATION
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={owner=me,client=client,writes=0}
            function f.open()
                local x=Build(function()return f.a,f.c end,function(a,z)f.a=a;f.c=z;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                x.MarkLoaded();return x
            end
            return f
        end
        local function Record(n,w,l)
            local x,y=w,l;if y<x then x,y=y,x end;local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,
                player1=x,player2=y,winner=w,loser=l,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),
                statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
        end
        local function Add(f,n,w,l,t) local r=Record(n,w,l);assert(f.open().UpdateSeasonEvidence(epoch,r,t,t));return r end
        Case(client.." archive absent read only and live gate",function()
            local f=Fixture();local r,why=f.open().ReadSeasonArchive(epoch);assert(not r and why=="no_archive" and f.writes==0)
            local live=Fixture("LOCAL");assert(not live.open().ReadSeasonArchive(epoch) and not live.open().UpdateSeasonEvidence(epoch,Record(1,me,b),epoch,epoch) and live.writes==0)
        end)
        Case(client.." archive reload rollover and rating progression",function()
            local f=Fixture();for i=1,3 do Add(f,i,me,b,epoch+i) end;Add(f,4,me,c,105);Add(f,5,me,d,106)
            local s=assert(f.open().ReadSeasonArchive(106));local rating=s.players[me].rating;local peak=s.players[me].peakRating
            assert(s.players[me].wins==5 and not s.players[me].rank.provisional and s.character==me)
            Add(f,6,me,b,boundary);s=assert(f.open().ReadSeasonArchive(boundary));local p=s.history[1].players[me]
            assert(s.season==2 and p.rating==rating and p.peakRating==peak and p.wins==5 and #s.changes==6 and s.changes[6].season==2 and s.players[me].credit==4)
            local writes=f.writes;s.history[1].players[me].rating=99999;s.changes[1].gain=0
            local again=assert(f.open().ReadSeasonArchive(boundary));assert(again.history[1].players[me].rating==rating and again.changes[1].gain==100 and f.writes==writes)
        end)
        Case(client.." late evidence rebuilds archived ratings",function()
            local f=Fixture();Add(f,2,me,c,boundary);local before=assert(f.open().ReadSeasonArchive(boundary));assert(not before.history[1])
            Add(f,1,me,b,epoch);local after=assert(f.open().ReadSeasonArchive(boundary));assert(after.history[1].players[me].rating==1100 and after.changes[2].winnerBefore~=before.changes[1].winnerBefore)
            assert(f.open().UpdateSeasonEvidence(epoch,Record(1,b,me),epoch,epoch));local disputed=assert(f.open().ReadSeasonArchive(boundary));assert(disputed.disputed==1 and not disputed.history[1] and disputed.changes[1].winnerBefore==1000)
        end)
        Case(client.." missing and disputed clocks persist",function()
            local f=Fixture();local r=Record(1,me,b);assert(f.open().UpdateSeasonEvidence(epoch,r));local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.missingTime==1 and #s.changes==0)
            assert(f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch));s=assert(f.open().ReadSeasonArchive(boundary));assert(s.history[1].players[me].rating==1100)
            assert(f.open().UpdateSeasonEvidence(epoch,r,epoch+1,epoch+1));s=assert(f.open().ReadSeasonArchive(boundary));assert(s.timeDisputed==1 and not s.history[1] and #s.changes==0)
        end)
        Case(client.." duplicate and schedule mismatch do not write",function()
            local f=Fixture();local r=Add(f,1,me,b,epoch);local a,z=f.a,f.c
            local ok,why=f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch);assert(ok and why=="unchanged" and f.writes==1 and f.a==a and f.c==z)
            assert(not f.open().UpdateSeasonEvidence(epoch+1,r,epoch,epoch) and not f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch+6) and not f.open().ReadSeasonArchive(epoch-1) and f.writes==1)
        end)
        Case(client.." account ledger shared and client partition isolated",function()
            local f=Fixture();Add(f,1,me,b,epoch);local old=f.c;f.c=nil;f.owner=c
            local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.character==c and s.history[1].players[c]==nil and s.history[1].players[me].rating==1100)
            f.client=client=="forever" and "retail" or "forever";assert(not f.open().ReadSeasonArchive(boundary));f.client=client;f.owner=me;f.c=old;assert(f.open().ReadSeasonArchive(boundary).character==me)
        end)
        Case(client.." existing records shared and malformed archive preserved",function()
            local f=Fixture();local r=Add(f,1,me,b,epoch);assert(f.open().UpdateRecords(false,function(l)return l.Insert(Record(2,me,c))end))
            local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.missingTime==1 and #s.changes==1 and #f.open().ReadRecords().ledger.matched==2)
            local a,z,writes=f.a,f.c,f.writes;local part=a.clients[client];part.season.clocks.fake={{epoch,epoch}}
            assert(not f.open().ReadSeasonArchive(boundary) and not f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch) and f.a==a and f.c==z and f.writes==writes)
        end)
    end
    Case("archive live data remains disabled",function()assert(P.GetSnapshot().scope=="LOCAL" and not P.GetSnapshot().rankEligible)end)
    return passed,failed
end

function P.RunCompetitiveViewSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    local epoch=1000;local boundary=epoch+ns.SeasonRules.DURATION
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={owner=me,client=client,writes=0}
            function f.open()
                local x=Build(function()return f.a,f.c end,function(a,z)f.a=a;f.c=z;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                x.MarkLoaded();return x
            end
            return f
        end
        local function Record(n,w,l)
            local x,y=w,l;if y<x then x,y=y,x end;local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,
                player1=x,player2=y,winner=w,loser=l,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),
                statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
        end
        local function Add(f,n,w,l,t) assert(f.open().UpdateSeasonEvidence(epoch,Record(n,w,l),t,t)) end
        local function Seed(f)
            for i=1,3 do Add(f,i,me,b,epoch+i) end
            Add(f,4,me,c,epoch+4);Add(f,5,me,d,epoch+5)
        end
        local function Observe(f,n,out,peer)
            assert(f.open().UpdateRecords(true,function(_,h,run)
                return h.Observe(run,{scope="SIMULATED",client=client,id=n,kind="standard",
                    opponent={guid=peer},acceptedAt=0,endedAt=10*n,outcome=out,endType="knockout",
                    reason="matching_result_and_finish",outcomeObserved=true,finishObserved=true,
                    resultObserved=true,conflict=false,rankEligible=false})
            end))
        end
        Case(client.." empty view and separate storage capacity",function()
            local f=Fixture();local x=f.open();local v=assert(x.OpenCompetitiveView(epoch))
            assert(v.Status().state=="no_archive" and not v.Profile(me) and not v.Leaderboard())
            local p=v.Personal();assert(p.overall.total==0 and p.overall.winRate==nil and p.overall.averageDuration==nil)
            local cap=x.ReadCapacity();assert(cap.ledger.used==0 and cap.history.used==0 and cap.policy=="preserve_evidence" and f.writes==0)
            local live=Fixture("LOCAL").open();assert(not live.OpenCompetitiveView(epoch) and not live.ReadCapacity())
        end)
        Case(client.." private observation statistics and no fabricated remote identity",function()
            local f=Fixture()
            for i,out in ipairs({"won","lost","lost","won","unknown"}) do Observe(f,i,out,b) end
            local v=assert(f.open().OpenCompetitiveView(epoch))
            local p=v.Personal();assert(p.overall.wins==2 and p.overall.losses==2 and p.overall.unknown==1)
            assert(p.overall.signedStreak==0 and p.overall.worstStreak==2 and p.overall.averageDuration==30)
            assert(p.opponents[b].winRate==0.5 and not v.Profile(b))
            local cap=f.open().ReadCapacity();assert(cap.history.used==5 and cap.ledger.used==0)
            p.overall.wins=99;assert(v.Personal().overall.wins==2)
        end)
        Case(client.." seasonal profile agrees with replay and separates practice",function()
            local f=Fixture();Seed(f)
            -- Three further same-pair matches consume reduced weights, then a
            -- zero-weight match after seven positive-weight same-pair games.
            for i=6,10 do Add(f,i,me,b,epoch+i) end
            local v=assert(f.open().OpenCompetitiveView(epoch+10))
            local r=assert(f.open().ReadSeasonArchive(epoch+10))
            local p=assert(v.Profile(me));local stats=p.stats
            assert(p.rating==r.players[me].rating and p.peakRating==r.players[me].peakRating and not p.rank.provisional)
            assert(stats.games==r.players[me].games and stats.wins==r.players[me].wins and stats.losses==0)
            assert(stats.practiceWins==r.restricted and r.restricted>0 and #stats.progression==stats.games)
            assert(stats.opponents[b].wins+stats.opponents[b].practiceWins==8 and p.position==1)
            assert(p.name==nil and p.class==nil and p.personal==nil and not p.rankEligible)
        end)
        Case(client.." ranked board pagination filter and provisional exclusion",function()
            local f=Fixture();Seed(f)
            local v=assert(f.open().OpenCompetitiveView(epoch+6))
            local board=assert(v.Leaderboard(1,0,1,"","wins"))
            assert(board.total==1 and board.knownRanked==1 and board.rows[1].id==me and board.rows[1].position==1)
            assert(#v.Leaderboard(1,1,1).rows==0 and v.Leaderboard(1,0,5,"bbb").total==0)
            assert(v.Leaderboard(1,0,5,"aaa").total==1 and not v.Leaderboard(1,-1,10) and not v.Leaderboard(1,0,101))
            assert(v.Profile(b).rank.provisional and v.Profile(b).position==nil)
            board.rows[1].rating=0;assert(v.Leaderboard().rows[1].rating>0)
        end)
        Case(client.." archive rollover and late dispute refresh without private history rewrite",function()
            local f=Fixture();Seed(f);Observe(f,1,"won",b)
            Add(f,6,me,b,boundary)
            local before=assert(f.open().OpenCompetitiveView(boundary))
            local old=assert(before.Profile(me,1));assert(old.stats.games==5 and not old.rank.provisional)
            assert(before.Profile(me,2).rank.provisional and #before.Profile(me,2).seasons==2)
            Add(f,1,b,me,epoch+1)
            local after=assert(f.open().OpenCompetitiveView(boundary))
            assert(after.Profile(me,1).stats.games==4 and after.Profile(me,1).rank.provisional)
            assert(before.Profile(me,1).stats.games==5 and after.Status().evidence.disputed==1)
            assert(after.Personal().overall.wins==1 and after.Leaderboard(1).total==0)
            local writes=f.writes;after.Profile(me,1);after.Personal();assert(f.writes==writes)
        end)
        Case(client.." durable imported evidence is idempotent and context bound",function()
            local f=Fixture();local src=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            assert(src.Observe(Record(1,me,b),epoch,epoch))
            local page=assert(src.ExportPage("import",1))
            local descriptor=assert(ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch))
            local x=f.open();assert(not x.ImportSeasonPage(epoch,"wrong",page,b,b,"import"))
            assert(not x.ImportSeasonPage(epoch,descriptor,page,b,c,"import") and f.writes==0)
            assert(x.ImportSeasonPage(epoch,descriptor,page,b,b,"import") and f.writes==1)
            local a,z=f.a,f.c;local ok,why=f.open().ImportSeasonPage(epoch,descriptor,page,b,b,"import")
            assert(ok and why=="unchanged" and f.a==a and f.c==z and f.writes==1)
            assert(f.open().OpenCompetitiveView(epoch).Profile(me).stats.wins==1)
            assert(f.open().ReadCapacity().ledger.used==1)
            local live=Fixture("LOCAL").open();assert(not live.ImportSeasonPage(epoch,descriptor,page,b,b,"import"))
        end)
        Case(client.." client and character isolation with durable account records",function()
            local f=Fixture();Seed(f);Observe(f,1,"won",b)
            local original=f.c;f.c=nil;f.owner=c
            local v=assert(f.open().OpenCompetitiveView(epoch+5));assert(v.Personal().overall.total==0 and v.Profile(me).stats.wins==5)
            f.client=client=="forever" and "retail" or "forever"
            assert(f.open().OpenCompetitiveView(epoch+5).Status().state=="no_archive")
            f.client=client;f.owner=me;f.c=original
            assert(f.open().OpenCompetitiveView(epoch+5).Personal().overall.wins==1)
        end)
    end
    Case("competitive views remain simulation only",function()
        assert(P.GetSnapshot().scope=="LOCAL" and not P.GetSnapshot().rankEligible)
        assert(P.OpenCompetitiveView==nil and P.ImportSeasonPage==nil)
    end)
    return pass,fail
end

function P.RunFoundationSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    local epoch=1000
    local function Equal(x,y)
        if type(x)~=type(y) then return false end
        if type(x)~="table" then return x==y end
        for k,v in pairs(x) do if not Equal(v,y[k]) then return false end end
        for k in pairs(y) do if x[k]==nil then return false end end
        return true
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={writes=0,client=client,owner=a}
            function f.open()
                local x=Build(function()return f.a,f.c end,function(aa,cc)f.a=aa;f.c=cc;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                x.MarkLoaded();return x
            end
            return f
        end
        local function R(n,w,l)
            local x,y=w,l;if x>y then x,y=y,x end
            local s="a-"..n..":b-"..n
            local p=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|")
            local q=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")
            return assert(ns.ResultConfirmation.DecodeStatementsSimulated(client,p,q))
        end
        local function Seed(f)
            local x=f.open()
            for i,peer in ipairs({b,b,b,c,d}) do assert(x.UpdateSeasonEvidence(epoch,R(i,a,peer),epoch+i,epoch+i)) end
        end
        local function I(guid,name,time)
            return {scope="SIMULATED",client=client,guid=guid,name=name,
                fullName=client=="forever" and name.." Smith" or name.."-Home",
                realm=client=="retail" and "Home" or nil,class="PRIEST",faction="Alliance",observedAt=time}
        end
        Case(client.." lossless compact roundtrip and late correction",function()
            local f=Fixture();Seed(f)
            local x=f.open();local before=x.ReadSeasonArchive(epoch+6);local raw=x.ReadRecords()
            assert(x.CompactEvidence());local writes=f.writes
            assert(f.a.clients[client].ledger.version==2 and x.ReadCapacity().ledgerEncoding=="compact")
            assert(Equal(before,f.open().ReadSeasonArchive(epoch+6)) and Equal(raw,f.open().ReadRecords()))
            assert(f.open().CompactEvidence() and f.writes==writes)
            assert(f.open().UpdateSeasonEvidence(epoch,R(1,b,a),epoch+1,epoch+1))
            local after=f.open().ReadSeasonArchive(epoch+6)
            assert(after.disputed==1 and after.players[a].games==4 and f.a.clients[client].ledger.version==2)
            assert(f.open().UpdateRecords(false,function(l)return l.Insert(R(6,a,c))end))
            assert(f.a.clients[client].ledger.version==2 and f.open().ReadCapacity().ledger.used==6)
        end)
        Case(client.." malformed compact evidence rejected without overwrite",function()
            local f=Fixture();Seed(f);assert(f.open().CompactEvidence())
            local raw=f.a;local row=raw.clients[client].ledger.entries[R(1,a,b).id]
            row[1]="invalid";local n=f.writes
            assert(not f.open().ReadRecords() and not f.open().CompactEvidence() and not f.open().UpdateSeasonEvidence(epoch,R(7,a,c),epoch,epoch))
            assert(f.a==raw and f.writes==n)
            local l=assert(ns.MatchLedger.OpenSimulated(client));assert(l.Insert(R(1,a,b)));assert(l.Insert(R(1,b,a)))
            local compact=l.SaveCompact();local variants=compact.entries[R(1,a,b).id]
            variants[1],variants[2],variants[3],variants[4]=variants[3],variants[4],variants[1],variants[2]
            assert(not ns.MatchLedger.OpenCompactSimulated(client,compact))
        end)
        Case(client.." observed identity search and no effect on ratings",function()
            local f=Fixture();Seed(f);local x=f.open();local before=x.ReadSeasonArchive(epoch+6)
            assert(x.ObserveIdentity(I(a,"Alpha",epoch+6)))
            local v=assert(f.open().OpenCompetitiveView(epoch+6))
            assert(v.Profile(a).identity.name=="Alpha" and v.Leaderboard(1,0,10,"alpha").rows[1].id==a)
            assert(v.Leaderboard(1,0,10,client=="forever" and "smith" or "home").total==1)
            assert(v.Profile(b).identity==nil and Equal(before,f.open().ReadSeasonArchive(epoch+6)))
            local p=v.Profile(a);p.identity.name="bad";assert(v.Profile(a).identity.name=="Alpha")
        end)
        Case(client.." identity stale conflicting unknown and invalid updates refuse writes",function()
            local f=Fixture();Seed(f);local x=f.open();local v=I(a,"Alpha",epoch+6)
            assert(x.ObserveIdentity(v));local n=f.writes
            assert(x.ObserveIdentity(v) and f.writes==n)
            assert(not x.ObserveIdentity(I(a,"Old",epoch+5)) and not x.ObserveIdentity(I(a,"Conflict",epoch+6)))
            assert(not x.ObserveIdentity(I("Player-9-UNKNOWN","Fake",epoch+6)))
            local bad=I(a,"Bad|Name",epoch+7);assert(not x.ObserveIdentity(bad) and f.writes==n)
            local newer=I(a,"Renamed",epoch+7);newer.class=nil;assert(x.ObserveIdentity(newer))
            local view=assert(f.open().OpenCompetitiveView(epoch+7))
            assert(view.Profile(a).identity.name=="Renamed" and view.Profile(a).identity.class==nil)
            assert(view.Leaderboard(1,0,5,"alpha").total==0)
        end)
        Case(client.." compact import and snapshot query parity",function()
            local f=Fixture();Seed(f);local x=f.open();assert(x.CompactEvidence())
            local node=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            assert(node.Observe(R(6,a,b),epoch+6,epoch+6))
            local desc=assert(ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch))
            assert(x.ImportSeasonPage(epoch,desc,node.ExportPage("pack",1),b,b,"pack"))
            assert(f.a.clients[client].ledger.version==2)
            local v=assert(f.open().OpenCompetitiveView(epoch+6))
            local full=v.Profile(a);local summary=v.ProfileSummary(a)
            assert(full.stats.games==summary.stats.games and summary.stats.opponents==nil and summary.stats.progression==nil)
            local pages={}
            for i=0,#full.stats.progression-1,2 do
                local p=v.Progression(a,1,i,2)
                assert(p.total==#full.stats.progression)
                for _,r in ipairs(p.rows) do pages[#pages+1]=r end
            end
            assert(Equal(pages,full.stats.progression) and not v.Progression(a,1,-1,2))
            local first=v.Leaderboard(1,0,1,"","wins");first.rows[1].rating=0
            assert(v.Leaderboard(1,0,1,"","wins").rows[1].rating>0)
        end)
        Case(client.." identity partition and live gates",function()
            local f=Fixture();Seed(f);assert(f.open().ObserveIdentity(I(a,"Alpha",epoch+6)))
            f.client=client=="forever" and "retail" or "forever"
            assert(f.open().OpenCompetitiveView(epoch+6).Status().state=="no_archive")
            f.client=client;f.owner=c;f.c=nil
            assert(f.open().OpenCompetitiveView(epoch+6).Profile(a).identity.name=="Alpha")
            local localStore=Fixture("LOCAL").open()
            assert(not localStore.ObserveIdentity(I(a,"Alpha",epoch+6)) and not localStore.CompactEvidence())
        end)
    end
    Case("final data foundation remains simulation only",function()
        assert(P.GetSnapshot().scope=="LOCAL" and not P.GetSnapshot().rankEligible)
        assert(P.CompactEvidence==nil and P.ObserveIdentity==nil)
    end)
    return pass,fail
end

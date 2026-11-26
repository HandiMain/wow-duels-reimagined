local _,ns=...
-- Pure commitment rules; CompetitiveStorage owns reading and writing.
-- All records in this build are private simulated fixtures.
local R={};ns.TournamentRecovery=R
local P=ns.CompetitiveScope
local function Whole(v,lo,hi)return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
local function Guid(v)return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
-- One policy shared by admission and canonical journal validation.
-- Simulated fixture limits remain unchanged; private histories keep full evidence.
function R.ArchiveLimits(private)
    if private==true then return 64,256,512 end
    return 16,64,128
end
local function Copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out
end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
-- Control is a term-fenced projection of the existing organizer journal.
-- The fixture adapter supplies observed connections and exact checkpoints;
-- neither raw packets nor a timeout alone confer authority.
local function Control(bracket,raw)
    if not bracket or type(raw)~="table" or not Whole(raw.term,1,2147483647)
        or type(raw.paused)~="boolean" then return nil end
    local owner=bracket.checkpoint.ad.owner
    local eligible=raw.coordinator==owner
    for _,m in ipairs(bracket.checkpoint.roster) do
        if m.checkedIn and m.guid==raw.coordinator then eligible=true end
    end
    if not eligible or (raw.term==1 and raw.coordinator~=owner) then return nil end
    local clean={term=raw.term,coordinator=raw.coordinator,paused=raw.paused}
    if Equal(clean,raw) then return clean end
end
function R.InitialControl(bracket)
    if not bracket then return nil end
    return {term=1,coordinator=bracket.checkpoint.ad.owner,paused=false}
end
-- Fixed majority of the frozen checked-in electorate. No claim of
-- distributed consensus: only one injected storage root is authoritative.
function R.ReconcileControl(bracket,control,connections,copies)
    local c=Control(bracket,control)
    if not c or c.term>=2147483647 or type(connections)~="table" or type(copies)~="table" then return nil end
    local owner=bracket.checkpoint.ad.owner
    local ownerState=connections[owner]
    local coordinatorState=connections[c.coordinator]
    local function State(v) return v=="online" or v=="offline" or v=="unknown" end
    if not State(ownerState) or not State(coordinatorState) then return nil end
    local preferred=ownerState=="online" and owner or nil
    if not preferred and ownerState=="offline" then
        for _,m in ipairs(bracket.checkpoint.roster) do
            if m.checkedIn and connections[m.guid]=="online" and (not c.paused or Equal(copies[m.guid],bracket)) then preferred=m.guid;break end
        end
        -- Avoid unnecessary migration between available participants.
        if c.coordinator~=owner and coordinatorState=="online" and (not c.paused or Equal(copies[c.coordinator],bracket)) then preferred=c.coordinator end
    end
    if not c.paused then
        if coordinatorState=="online" and (not preferred or preferred==c.coordinator) then return nil end
        return {term=c.term+1,coordinator=c.coordinator,paused=true}
    end
    if not preferred or connections[preferred]~="online" then return nil end
    local voters,total,matching={},0,0
    for _,m in ipairs(bracket.checkpoint.roster) do
        if m.checkedIn then voters[m.guid]=true;total=total+1 end
    end
    for guid,copy in pairs(copies) do
        if guid~=owner and not voters[guid] then return nil end
        if not Equal(copy,bracket) then return nil end
        if voters[guid] and connections[guid]=="online" then matching=matching+1 end
    end
    if total<2 or matching<math.floor(total/2)+1 or not Equal(copies[preferred],bracket) then return nil end
    return {term=c.term+1,coordinator=preferred,paused=false}
end
-- Completion is deliberately stricter than temporary coordination.
-- Each checked-in participant must acknowledge the exact final log.
-- This is a simulated receipt, not cryptographic proof or a live award.
local function FinalRecord(client,owner,raw)
    if type(raw)~="table" or type(raw.bracket)~="table" or type(raw.bracket.checkpoint)~="table"
        or type(raw.bracket.checkpoint.ad)~="table" then return nil end
    local a=raw.bracket.checkpoint.ad
    local scope={client=client,region=a.region,ruleset=a.ruleset,faction=a.faction}
    local domain=ns.TournamentBracket
    local engine=domain and domain.OpenSimulated(scope,owner,raw.bracket)
    if not engine then return nil end
    local b=engine.Save();local v=engine.Snapshot()
    if v.state~="completed" or not Guid(v.champion) or v.champion==owner
        or not Whole(raw.finishedAt,b.startedAt,4102444800) or not Whole(raw.term,1,2147483647)
        or not Whole(a.revision,1,2147483646) then return nil end
    local clean={bracket=b,champion=v.champion,term=raw.term,finishedAt=raw.finishedAt,
        population=P.Key(a),revision=a.revision+1}
    if Equal(clean,raw) then return clean end
end
function R.FinalRecord(client,owner,bracket,control,now,copies)
    local c=Control(bracket,control)
    if not c or c.paused or c.coordinator~=owner or type(copies)~="table" then return nil end
    local a=bracket.checkpoint.ad
    local domain=ns.TournamentBracket
    local engine=domain and domain.OpenSimulated({client=client,region=a.region,ruleset=a.ruleset,faction=a.faction},owner,bracket)
    if not engine then return nil end
    local v=engine.Snapshot()
    if v.state~="completed" then return nil end
    -- Earlier rounds already require bilateral evidence or a canonical
    -- forfeit. Eliminated players need not remain online for the final.
    local eligible={}
    for _,m in ipairs(bracket.checkpoint.roster) do if m.checkedIn then eligible[m.guid]=true end end
    local final=v.rounds[#v.rounds][1]
    if not Equal(copies[v.champion],bracket) then return nil end
    local other=final.a==v.champion and final.b or final.a
    if other and not final.forfeit and not Equal(copies[other],bracket) then return nil end
    for guid,copy in pairs(copies) do if not eligible[guid] or not Equal(copy,bracket) then return nil end end
    return FinalRecord(client,owner,{bracket=engine.Save(),champion=v.champion,term=c.term,finishedAt=now,
        population=P.Key(a),revision=a.revision+1})
end
local function ArchiveReceipt(client,id,v)
    if type(id)~="string" or #id>96 or type(v)~="table" or not Guid(v.owner)
        or not P.Code(v.population,client) or not Whole(v.revision,2,2147483647) then return nil end
    local who,stamp,serial=id:match("^(Player%-%w[%w%-]*):(%d+):(%d+)$")
    if who~=v.owner or not Whole(tonumber(stamp),1,4102444800) or not Whole(tonumber(serial),1,2147483647)
        or tostring(tonumber(stamp))~=stamp or tostring(tonumber(serial))~=serial then return nil end
    local clean={owner=v.owner,population=v.population,revision=v.revision}
    if Equal(clean,v) then return clean end
end
local function ParticipantRecord(client,character,raw)
    if type(raw)~="table" or type(raw.bracket)~="table" or type(raw.bracket.checkpoint)~="table" then return nil end
    local ad=raw.bracket.checkpoint.ad
    if type(ad)~="table" or not Guid(ad.owner) or ad.owner==character then return nil end
    local clean=FinalRecord(client,ad.owner,raw)
    if not clean then return nil end
    for _,m in ipairs(clean.bracket.checkpoint.roster) do
        if m.guid==character and m.checkedIn then return clean end
    end
end
-- Organizer-reported, replay-validated history only; not independent proof.
function R.ParticipantFinalRecord(client,character,progress,now)
    if type(progress)~="table" or progress.scope~="PRIVATE_TEST" or progress.source~="organizer-reported"
        or type(progress.control)~="table" or progress.control.paused~=false
        or type(progress.saved)~="table" or type(progress.saved.checkpoint)~="table" then return nil end
    local ad=progress.saved.checkpoint.ad
    local c=progress.control
    if type(ad)~="table" or c.owner~=ad.owner or c.coordinator~=ad.owner or c.event~=ad.id
        or not Whole(progress.finishedAt,1,4102444800) or not Whole(now,progress.finishedAt,4102444800)
        or not Whole(ad.revision,1,2147483646) or type(progress.bracket)~="table" then return nil end
    return ParticipantRecord(client,character,{bracket=progress.saved,champion=progress.bracket.champion,
        term=c.term,finishedAt=progress.finishedAt,population=P.Key(ad),revision=ad.revision+1})
end
local function CompletedCheckpoint(record,cp)
    if not record or not cp then return false end
    local a,b=record.bracket.checkpoint.ad,cp.host.ad
    if b.state~="completed" or b.revision~=record.revision or b.id~=a.id then return false end
    local restored={}
    for k,v in pairs(b) do restored[k]=v end
    restored.state="open";restored.revision=a.revision
    return Equal(a,restored) and Equal(record.bracket.checkpoint.roster,cp.host.roster)
end
-- Private-test-only assignment identity. One owner-selected game at a
-- time; serial is the host journal revision at issuance, never a reused
-- simulated fixture token. The bracket remains the only result owner.
local function MatchID(v) return type(v)=="string" and #v<=8 and v:match("^R%d+M%d+$")~=nil end
local function SeatIdentity(a)
    return type(a)=="table" and MatchID(a.match) and Whole(a.game,1,5) and Whole(a.attempt,0,1)
        and Whole(a.term,1,2147483647) and Whole(a.serial,1,2147483647)
end
function R.PrivateSession(a)
    if not SeatIdentity(a) then return nil end
    return "t"..a.term.."-"..a.match.."-"..a.game.."-"..a.attempt..":"..a.serial
end
function R.PrivateAssignment(view,control,raw,revision)
    if not SeatIdentity(raw) or not view or view.state~="running" or not control or control.paused
        or control.coordinator~=view.owner or raw.term~=control.term or raw.serial>revision
        or type(raw.ready1)~="boolean" or type(raw.ready2)~="boolean" then return nil end
    local row
    for _,round in ipairs(view.rounds) do for _,m in ipairs(round) do if m.id==raw.match then row=m end end end
    if not row or row.state~="ready" or not Guid(row.a) or not Guid(row.b)
        or raw.player1~=row.a or raw.player2~=row.b or raw.game~=row.wins[1]+row.wins[2]+1
        or raw.attempt~=(row.replayedGame==raw.game and 1 or 0) then return nil end
    local game=row.games[raw.game]
    if game then
        if not raw.ready1 or not raw.ready2 then return nil end
        for _,report in pairs(game.reports) do
            if report.evidence~="T:"..R.PrivateSession(raw) then return nil end
        end
    end
    local clean={match=raw.match,game=raw.game,attempt=raw.attempt,term=raw.term,serial=raw.serial,
        player1=row.a,player2=row.b,ready1=raw.ready1,ready2=raw.ready2}
    if Equal(raw,clean) then return clean end
end
function R.PrivateSeat(character,lock,raw)
    if not SeatIdentity(raw) or not lock or lock.role~="participant" or lock.status~="checked"
        or raw.event~=lock.id or raw.owner~=lock.owner or not Guid(raw.peer)
        or raw.peer==character or raw.peer==lock.owner
        or (raw.phase~="armed" and raw.phase~="reported") then return nil end
    if raw.phase=="armed" and raw.winner~=nil then return nil end
    if raw.phase=="reported" and raw.winner~=character and raw.winner~=raw.peer then return nil end
    local clean={event=lock.id,owner=lock.owner,peer=raw.peer,match=raw.match,game=raw.game,
        attempt=raw.attempt,term=raw.term,serial=raw.serial,phase=raw.phase,winner=raw.winner}
    if Equal(raw,clean) then return clean end
end
local function Validate(client,character,raw,private,previous,nextMemo)
    if not Guid(character) or (client~="retail" and client~="forever") then return nil end
    if raw==nil then return {version=1,scope="SIMULATED",client=client,character=character,revision=0,sequence=0} end
    if type(raw)~="table" or raw.version~=1 or raw.scope~="SIMULATED" or raw.client~=client
        or raw.character~=character or not Whole(raw.revision,0,2147483647) or not Whole(raw.sequence,0,raw.revision) then return nil end
    local out={version=1,scope="SIMULATED",client=client,character=character,revision=raw.revision,sequence=raw.sequence}
    local hostLimit,participantLimit,cancelLimit=R.ArchiveLimits(private)
    local function Checked(id,rawRecord,participant)
        local key=(participant and "p:" or "h:")..id
        local prior=previous and previous[key]
        local record
        if prior and Equal(prior,rawRecord) then
            if nextMemo then nextMemo[key]=prior end
            return Copy(prior)
        elseif participant then record=ParticipantRecord(client,character,rawRecord)
        else record=FinalRecord(client,character,rawRecord) end
        if record and nextMemo then nextMemo[key]=Copy(record) end
        return record
    end
    local l=raw.commitment
    if l~=nil then
        if type(l)~="table" or not Guid(l.owner) or type(l.id)~="string" or #l.id>96
            or type(l.population)~="string" or not P.Code(l.population,client) or raw.sequence<1 then return nil end
        local owner,stamp,serial=l.id:match("^(Player%-%w[%w%-]*):(%d+):(%d+)$")
        local a,b=tonumber(stamp),tonumber(serial)
        if owner~=l.owner or not Whole(a,1,4102444800) or tostring(a)~=stamp
            or not Whole(b,1,2147483647) or tostring(b)~=serial then return nil end
        if l.role=="host" then
            if l.owner~=character or l.status~="hosting" then return nil end
        elseif l.role=="participant" then
            if l.owner==character or (l.status~="pending" and l.status~="registered" and l.status~="checked") then return nil end
        else return nil end
        local clean={role=l.role,owner=l.owner,id=l.id,population=l.population,status=l.status}
        for k in pairs(l) do if clean[k]==nil then return nil end end
        out.commitment=clean
    end
    if raw.pending~=nil then
        local p=raw.pending
        if type(p)~="table" or not l or l.role~="participant" or p.sequence~=raw.sequence
            or (p.op~="J" and p.op~="L" and p.op~="C" and p.op~="S") or (p.op=="J")~=(l.status=="pending") then return nil end
        for k in pairs(p) do if k~="op" and k~="sequence" then return nil end end
        out.pending={op=p.op,sequence=p.sequence}
    elseif l and l.status=="pending" then return nil end
    if raw.checkpoint~=nil then
        local domain=ns.TournamentRegistration
        local cp=domain and domain.ValidateHostCheckpoint(client,character,raw.checkpoint)
        if not cp then return nil end
        local a=cp.host.ad
        if a.state=="open" then
            if not l or l.role~="host" or l.id~=a.id or l.population~=P.Key(a) then return nil end
        elseif l and l.role=="host" then return nil end
        out.checkpoint=cp
    end
    if raw.bracket~=nil then
        local cp=out.checkpoint
        if not cp or not l or l.role~="host" or cp.host.ad.state~="open" or type(raw.bracket)~="table"
            or not Equal(raw.bracket.checkpoint,cp.host) then return nil end
        local b=ns.TournamentBracket
        local a=cp.host.ad
        local scope={client=client,region=a.region,ruleset=a.ruleset,faction=a.faction}
        local engine=b and b.OpenSimulated(scope,character,raw.bracket)
        if not engine then return nil end
        out.bracket=engine.Save()
        out.control=Control(out.bracket,raw.control)
        if not out.control then return nil end
        if raw.privateAssignment~=nil then
            if private~=true then return nil end
            out.privateAssignment=R.PrivateAssignment(engine.Snapshot(),out.control,raw.privateAssignment,raw.revision)
            if not out.privateAssignment then return nil end
        end
    elseif raw.control~=nil or raw.privateAssignment~=nil then return nil end
    if raw.privateSeat~=nil then
        if private~=true or (raw.pending and raw.pending.op~="S") then return nil end
        out.privateSeat=R.PrivateSeat(character,l,raw.privateSeat)
        if not out.privateSeat then return nil end
    end
    -- Compact terminal evidence is never evicted to make room for a new cup.
    if raw.cancelled~=nil then
        if type(raw.cancelled)~="table" then return nil end
        local archive,n={},0
        for id,v in pairs(raw.cancelled) do
            n=n+1
            if n>cancelLimit or type(id)~="string" or #id>96 or type(v)~="table"
                or type(v.population)~="string" or not P.Code(v.population,client)
                or not Whole(v.revision,2,2147483647) then return nil end
            local who,stamp,serial=id:match("^(Player%-%w[%w%-]*):(%d+):(%d+)$")
            local a,b=tonumber(stamp),tonumber(serial)
            if who~=character or not Whole(a,1,4102444800) or tostring(a)~=stamp
                or not Whole(b,1,2147483647) or tostring(b)~=serial then return nil end
            for k in pairs(v) do if k~="population" and k~="revision" then return nil end end
            if out.checkpoint and out.checkpoint.host.ad.id==id then
                local ad=out.checkpoint.host.ad
                if ad.state~="cancelled" or ad.revision~=v.revision or P.Key(ad)~=v.population then return nil end
            end
            archive[id]={population=v.population,revision=v.revision}
        end
        out.cancelled=archive
    end
    if raw.completed~=nil then
        if type(raw.completed)~="table" then return nil end
        local archive,n={},0
        for id,record in pairs(raw.completed) do
            n=n+1
            if n>hostLimit or type(id)~="string" or #id>96 or (out.cancelled and out.cancelled[id]) then return nil end
            local clean=Checked(id,record,false)
            if not clean or clean.bracket.checkpoint.ad.id~=id then return nil end
            if out.checkpoint and out.checkpoint.host.ad.id==id and not CompletedCheckpoint(clean,out.checkpoint) then return nil end
            archive[id]=clean
        end
        out.completed=archive
    end
    -- Bounded append-only receipts and received archives. Existing journals without
    -- these optional fields retain their original schema and semantics.
    local n=0
    if raw.participantCompleted~=nil then
        if private~=true or type(raw.participantCompleted)~="table" then return nil end
        out.participantCompleted={}
        for id,v in pairs(raw.participantCompleted) do
            n=n+1
            if n>participantLimit or type(id)~="string" or #id>96 then return nil end
            local clean=Checked(id,v,true)
            if not clean or clean.bracket.checkpoint.ad.id~=id
                or (out.completed and out.completed[id]) or (out.cancelled and out.cancelled[id]) then return nil end
            out.participantCompleted[id]=clean
        end
    end
    if raw.archiveReceipts~=nil then
        if private~=true or type(raw.archiveReceipts)~="table" then return nil end
        out.archiveReceipts={}
        for id,v in pairs(raw.archiveReceipts) do
            n=n+1
            if n>participantLimit then return nil end
            local clean=ArchiveReceipt(client,id,v)
            if not clean or clean.owner==character
                or (out.participantCompleted and out.participantCompleted[id])
                or (out.completed and out.completed[id]) or (out.cancelled and out.cancelled[id]) then return nil end
            out.archiveReceipts[id]=clean
        end
    end
    if out.checkpoint and out.checkpoint.host.ad.state=="completed"
        and not (out.completed and out.completed[out.checkpoint.host.ad.id]) then return nil end
    for k in pairs(raw) do if out[k]==nil then return nil end end
    return out
end
function R.Validate(client,character,raw,private)
    return Validate(client,character,raw,private)
end
-- Per-storage-owner memo, not a second journal. Only fully validated immutable
-- terminal records are retained, and only reused after exact deep equality.
-- Detached return values cannot mutate the memo; a changed owner clears it.
function R.NewJournalValidator()
    local owner,memos
    return function(client,character,raw,private)
        if private~=true or (client~="retail" and client~="forever") then
            return Validate(client,character,raw,private)
        end
        if owner~=character or not memos then owner=character;memos={} end
        local nextMemo={}
        local clean=Validate(client,character,raw,private,memos[client],nextMemo)
        if clean then memos[client]=nextMemo else memos[client]=nil end
        return clean
    end
end
function R.RunArchiveCapacitySelfTest()
    local owner="Player-1-00000001";local other="Player-1-00000002"
    local host,participant,cancel=R.ArchiveLimits(true)
    assert(host>16 and participant>64 and cancel>128)
    local validate=R.NewJournalValidator()
    for _,client in ipairs({"forever","retail"}) do
        local population=client..":EU:"..(client=="retail" and "retail" or "normal")..":Alliance"
        local raw=assert(R.Validate(client,owner,nil,true))
        raw.archiveReceipts={}
        for i=1,participant do raw.archiveReceipts[other..":1700000000:"..i]={owner=other,population=population,revision=2} end
        local copy=assert(validate(client,owner,raw,true))
        copy.archiveReceipts[other..":1700000000:1"].revision=99
        assert(validate(client,owner,raw,true).archiveReceipts[other..":1700000000:1"].revision==2)
        raw.archiveReceipts[other..":1700000000:"..(participant+1)]={owner=other,population=population,revision=2}
        assert(not validate(client,owner,raw,true))
        raw.archiveReceipts=nil;raw.cancelled={}
        for i=1,cancel do raw.cancelled[owner..":1700000000:"..i]={population=population,revision=2} end
        assert(validate(client,owner,raw,true) and not R.Validate(client,owner,raw,false))
        raw.cancelled[owner..":1700000000:"..(cancel+1)]={population=population,revision=2}
        assert(not validate(client,owner,raw,true))
    end
    return true
end
local function Same(a,b)
    if not a or not b then return a==b end
    return a.role==b.role and a.owner==b.owner and a.id==b.id and a.population==b.population
end
-- Called only after trusted local fixture adapter has verified the receipt.
-- Storage checks transitions but cannot establish sender authenticity.
function R.Transition(old,new,action,private)
    if new.revision~=old.revision+1 then return false end
    local beforeResults,afterResults=old.participantCompleted or {},new.participantCompleted or {}
    local beforeReceipts,afterReceipts=old.archiveReceipts or {},new.archiveReceipts or {}
    if action=="archive_terminal" or action=="archive_query" or action=="archive_save" then
        if private~=true then return false end
        local ignore={revision=true,participantCompleted=true,archiveReceipts=true}
        if action=="archive_terminal" then
            ignore.commitment=true;ignore.pending=true;ignore.privateSeat=true
        elseif action=="archive_query" then ignore.sequence=true end
        local a,b={},{}
        for k,v in pairs(old) do if not ignore[k] then a[k]=v end end
        for k,v in pairs(new) do if not ignore[k] then b[k]=v end end
        if not Equal(a,b) then return false end
        local lock=old.commitment
        if action=="archive_terminal" then
            if not lock or lock.role~="participant" or lock.status~="checked" or not old.pending
                or new.commitment or new.pending or new.privateSeat or not Equal(beforeResults,afterResults)
                or beforeResults[lock.id] or beforeReceipts[lock.id] then return false end
            local expected={};for k,v in pairs(beforeReceipts) do expected[k]=v end
            local receipt=afterReceipts[lock.id]
            if not receipt or receipt.owner~=lock.owner or receipt.population~=lock.population then return false end
            expected[lock.id]=receipt
            return Equal(expected,afterReceipts)
        elseif action=="archive_query" then
            return not old.pending and (not lock or lock.role=="participant")
                and next(beforeReceipts)~=nil and new.sequence==old.sequence+1
                and Equal(beforeResults,afterResults) and Equal(beforeReceipts,afterReceipts)
        else
            if old.pending or (lock and lock.role~="participant") then return false end
            local id,record
            for k,v in pairs(afterResults) do
                if not beforeResults[k] then if id then return false end;id=k;record=v
                elseif not Equal(beforeResults[k],v) then return false end
            end
            if not id then return false end
            for k in pairs(beforeResults) do if not afterResults[k] then return false end end
            local receipt=beforeReceipts[id]
            local ad=record.bracket.checkpoint.ad
            if receipt then
                if receipt.owner~=ad.owner or receipt.population~=record.population or receipt.revision~=record.revision then return false end
            elseif not lock or lock.status~="checked" or lock.id~=id or lock.owner~=ad.owner or lock.population~=record.population then return false end
            local expected={};for k,v in pairs(beforeReceipts) do if k~=id then expected[k]=v end end
            return Equal(expected,afterReceipts)
        end
    end
    if not Equal(beforeResults,afterResults) or not Equal(beforeReceipts,afterReceipts) then return false end
    local oa,na,os,newSeat=old.privateAssignment,new.privateAssignment,old.privateSeat,new.privateSeat
    if (oa or na or os or newSeat) and private~=true then return false end
    local privateAction=action=="private_assign" or action=="private_ready" or action=="seat_arm" or action=="seat_report" or action=="seat_clear"
    if privateAction then
        if private~=true then return false end
        local a,b={},{}
        for k,v in pairs(old) do if k~="revision" and k~="privateAssignment" and k~="privateSeat" then a[k]=v end end
        for k,v in pairs(new) do if k~="revision" and k~="privateAssignment" and k~="privateSeat" then b[k]=v end end
        if not Equal(a,b) or ((old.pending or new.pending) and not (action=="seat_report" and old.pending and new.pending and old.pending.op=="S")) then return false end
        if action=="private_assign" then
            return not oa and na and not os and not newSeat and na.serial==new.revision and not na.ready1 and not na.ready2
        elseif action=="private_ready" then
            if not oa or not na or os or newSeat then return false end
            local copy={};for k,v in pairs(oa) do copy[k]=v end
            if not oa.ready1 and na.ready1 and oa.ready2==na.ready2 then copy.ready1=true
            elseif not oa.ready2 and na.ready2 and oa.ready1==na.ready1 then copy.ready2=true
            else return false end
            return Equal(copy,na)
        elseif action=="seat_arm" then
            return not oa and not na and not os and newSeat and newSeat.phase=="armed"
        elseif action=="seat_report" then
            if oa or na or not os or not newSeat or os.phase~="armed" or newSeat.phase~="reported" then return false end
            local copy={};for k,v in pairs(os) do copy[k]=v end
            copy.phase="reported";copy.winner=newSeat.winner
            return Equal(copy,newSeat)
        else return not oa and not na and os~=nil and newSeat==nil end
    end
    if not Equal(os,newSeat) and not (action=="ack" and os and not newSeat and not new.commitment) then return false end
    if not Equal(oa,na) then
        if not oa or na then return false end
        if action=="bracket_report" then
            local saved=new.bracket;local ad=saved and saved.checkpoint.ad
            -- Revalidate the old assignment against the next canonical game.
            -- Clearing a still-valid offer would discard a recoverable result.
            local domain=ns.TournamentBracket
            if not domain or not ad then return false end
            local b=domain.OpenSimulated(ad,ad.owner,saved)
            if not b or R.PrivateAssignment(b.Snapshot(),new.control,oa,new.revision) then return false end
        elseif action~="control_change" and action~="host_cancel" and action~="host_complete" then return false end
    end
    local x,y=old.checkpoint,new.checkpoint
    local expected={}
    for id,v in pairs(old.cancelled or {}) do expected[id]=v end
    if action=="host_cancel" and y then
        local a=y.host.ad
        expected[a.id]={population=P.Key(a),revision=a.revision}
    elseif action=="host_open" and x and x.host.ad.state=="cancelled" then
        local a=x.host.ad
        expected[a.id]={population=P.Key(a),revision=a.revision}
    end
    if not Equal(expected,new.cancelled or {}) then return false end
    local before,after=old.bracket,new.bracket
    local oc,nc=old.control,new.control
    local finished={}
    for id,record in pairs(old.completed or {}) do finished[id]=record end
    if action=="host_complete" then
        if not before or after or not oc or oc.paused or oc.coordinator~=old.character or nc
            or not x or not y or not old.commitment or old.commitment.role~="host"
            or new.commitment or old.pending or new.pending or new.sequence~=old.sequence then return false end
        local id=x.host.ad.id
        local record=new.completed and new.completed[id]
        if finished[id] or not record or not Equal(record.bracket,before) or record.term~=oc.term
            or not CompletedCheckpoint(record,y) or not Equal(x.receipts,y.receipts) then return false end
        finished[id]=record
        return Equal(finished,new.completed)
    end
    if not Equal(finished,new.completed or {}) then return false end
    if action=="control_change" then
        if not before or not after or not oc or not nc or nc.term~=oc.term+1 or oc.paused==nc.paused
            or not Equal(before,after) or not Equal(x,y) or not Same(old.commitment,new.commitment)
            or old.pending or new.pending or new.sequence~=old.sequence then return false end
        return not nc.paused or nc.coordinator==oc.coordinator
    elseif action=="bracket_start" then
        if oc or not nc or not Equal(nc,R.InitialControl(after)) then return false end
    elseif action=="host_cancel" then
        if nc then return false end
    elseif not Equal(oc,nc) then return false end
    if action=="bracket_start" or action=="bracket_report" then
        if not x or not y or not old.commitment or old.commitment.role~="host"
            or not Same(old.commitment,new.commitment) or old.pending or new.pending
            or new.sequence~=old.sequence or not Equal(x,y) or not after then return false end
        if action=="bracket_start" then return not before and #after.reports==0 end
        if not oc or oc.paused or not before or before.startedAt~=after.startedAt or not Equal(before.checkpoint,after.checkpoint)
            or #after.reports~=#before.reports+1 then return false end
        for i,v in ipairs(before.reports) do if not Equal(v,after.reports[i]) then return false end end
        return true
    elseif action=="host_cancel" then
        if after then return false end
    elseif not Equal(before,after) then return false end
    if action=="host_open" then
        local n=0;for _ in pairs(expected) do n=n+1 end
        local hostLimit,_,cancelLimit=R.ArchiveLimits(private)
        if n>=cancelLimit then return false end
        local completed=0;for _ in pairs(finished) do completed=completed+1 end
        if completed>=hostLimit then return false end
        return not old.commitment and not old.pending and not new.pending and new.commitment
            and new.commitment.role=="host" and y and y.host.ad.state=="open" and y.host.ad.revision==1
            and y.host.ad.count==0 and next(y.receipts)==nil and new.sequence==old.sequence+1
            and (not x or ((x.host.ad.state=="cancelled" or x.host.ad.state=="completed") and y.host.ad.serial==x.host.ad.serial+1))
    elseif action=="host_checkpoint" or action=="host_cancel" then
        if not x or not y or not old.commitment or old.commitment.role~="host" or old.pending or new.pending
            or new.sequence~=old.sequence then return false end
        local a,b=x.host.ad,y.host.ad
        if a.state~="open" or a.id~=b.id or a.organizer~=b.organizer or not Equal(a.draft,b.draft)
            or b.revision<a.revision or b.revision>a.revision+1 then return false end
        if action=="host_cancel" then
            return b.state=="cancelled" and not new.commitment and b.revision==a.revision+1
                and Equal(x.host.roster,y.host.roster) and Equal(x.receipts,y.receipts)
        end
        if b.state~="open" or not Same(old.commitment,new.commitment) then return false end
        if before and not Equal(x.host,y.host) then return false end
        for guid,row in pairs(x.receipts) do
            local other=y.receipts[guid]
            if not other or other.seq<row.seq or (other.seq==row.seq and not Equal(row,other)) then return false end
        end
        return b.revision>a.revision or Equal(x.host.roster,y.host.roster)
    elseif not Equal(x,y) then return false end
    local a,b=old.commitment,new.commitment
    if action=="query" then
        return not old.pending and not new.pending and (not a or a.role=="participant")
            and Same(a,b) and (not a or a.status==b.status) and new.sequence==old.sequence+1
    elseif action=="begin" then
        if old.pending or not new.pending or new.sequence~=old.sequence+1 then return false end
        if new.pending.op=="J" then
            if private==true then
                local _,limit=R.ArchiveLimits(true)
                local n=0;for _ in pairs(beforeResults) do n=n+1 end;for _ in pairs(beforeReceipts) do n=n+1 end
                if n>=limit then return false end
            end
            return not a and b and b.role=="participant" and b.status=="pending"
        end
        return a and b and a.role=="participant" and Same(a,b) and a.status==b.status
    elseif action=="ack" then
        return old.pending and not new.pending and new.sequence==old.sequence
            and (not b or (Same(a,b) and b.status~="pending"))
    elseif action=="host" then
        return not x and not a and not old.pending and not new.pending and b and b.role=="host" and new.sequence==old.sequence+1
    elseif action=="host_terminal" then
        return not x and a and a.role=="host" and not b and not old.pending and not new.pending and new.sequence==old.sequence
    end
    return false
end

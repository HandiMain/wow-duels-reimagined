local _,ns=...
-- Pure commitment rules; CompetitiveStorage owns reading and writing.
-- All records in this build are private simulated fixtures.
local R={};ns.TournamentRecovery=R
local P=ns.CompetitiveScope
local function Whole(v,lo,hi)return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
local function Guid(v)return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
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
-- Conservative unanimity of the frozen checked-in electorate. No claim of
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
            if m.checkedIn and connections[m.guid]=="online" then preferred=m.guid;break end
        end
        -- Avoid unnecessary migration between available participants.
        if c.coordinator~=owner and coordinatorState=="online" then preferred=c.coordinator end
    end
    if not c.paused then
        if coordinatorState=="online" and (not preferred or preferred==c.coordinator) then return nil end
        return {term=c.term+1,coordinator=c.coordinator,paused=true}
    end
    if not preferred or connections[preferred]~="online" then return nil end
    local voters={}
    for _,m in ipairs(bracket.checkpoint.roster) do
        if m.checkedIn then
            voters[m.guid]=true
            if connections[m.guid]~="online" or not Equal(copies[m.guid],bracket) then return nil end
        end
    end
    if preferred==owner and not Equal(copies[owner],bracket) then return nil end
    for guid in pairs(copies) do if guid~=owner and not voters[guid] then return nil end end
    return {term=c.term+1,coordinator=preferred,paused=false}
end
function R.Validate(client,character,raw)
    if not Guid(character) or (client~="retail" and client~="forever") then return nil end
    if raw==nil then return {version=1,scope="SIMULATED",client=client,character=character,revision=0,sequence=0} end
    if type(raw)~="table" or raw.version~=1 or raw.scope~="SIMULATED" or raw.client~=client
        or raw.character~=character or not Whole(raw.revision,0,2147483647) or not Whole(raw.sequence,0,raw.revision) then return nil end
    local out={version=1,scope="SIMULATED",client=client,character=character,revision=raw.revision,sequence=raw.sequence}
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
    elseif raw.control~=nil then return nil end
    -- Compact terminal evidence is never evicted to make room for a new cup.
    if raw.cancelled~=nil then
        if type(raw.cancelled)~="table" then return nil end
        local archive,n={},0
        for id,v in pairs(raw.cancelled) do
            n=n+1
            if n>128 or type(id)~="string" or #id>96 or type(v)~="table"
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
    for k in pairs(raw) do if out[k]==nil then return nil end end
    return out
end
local function Same(a,b)
    if not a or not b then return a==b end
    return a.role==b.role and a.owner==b.owner and a.id==b.id and a.population==b.population
end
-- Called only after trusted local fixture adapter has verified the receipt.
-- Storage checks transitions but cannot establish sender authenticity.
function R.Transition(old,new,action)
    if new.revision~=old.revision+1 then return false end
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
        if n>=128 then return false end
        return not old.commitment and not old.pending and not new.pending and new.commitment
            and new.commitment.role=="host" and y and y.host.ad.state=="open" and y.host.ad.revision==1
            and y.host.ad.count==0 and next(y.receipts)==nil and new.sequence==old.sequence+1
            and (not x or (x.host.ad.state=="cancelled" and y.host.ad.serial==x.host.ad.serial+1))
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
        if new.pending.op=="J" then return not a and b and b.role=="participant" and b.status=="pending" end
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

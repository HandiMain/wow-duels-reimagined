local _,ns=...
-- Pure commitment rules; CompetitiveStorage owns reading and writing.
-- All records in this build are private simulated fixtures.
local R={};ns.TournamentRecovery=R
local P=ns.CompetitiveScope
local function Whole(v,lo,hi)return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
local function Guid(v)return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
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
            or (p.op~="J" and p.op~="L" and p.op~="C") or (p.op=="J")~=(l.status=="pending") then return nil end
        for k in pairs(p) do if k~="op" and k~="sequence" then return nil end end
        out.pending={op=p.op,sequence=p.sequence}
    elseif l and l.status=="pending" then return nil end
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
        return not a and not old.pending and not new.pending and b and b.role=="host" and new.sequence==old.sequence+1
    elseif action=="host_terminal" then
        return a and a.role=="host" and not b and not old.pending and not new.pending and new.sequence==old.sequence
    end
    return false
end

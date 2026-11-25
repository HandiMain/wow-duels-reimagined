local _,ns=...
-- Isolated host-authoritative tournament registration. No live transport or storage.
local R={};ns.TournamentRegistration=R
local T,P=ns.TournamentState,ns.CompetitiveScope
local function Copy(v)
    if type(v)~="table" then return v end
    local o={};for k,x in pairs(v) do o[k]=Copy(x) end;return o
end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Whole(v,lo,hi)
    return type(v)=="number" and tostring(v):match("^%d+$")~=nil and v>=lo and v<=hi
end
local function Guid(v) return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
local function Name(v) return type(v)=="string" and #v>0 and #v<=160 and not v:find("[%c|]") and v:match("%S")~=nil end
local function Actor(s,a) return type(a)=="table" and P.Matches(s,a) and Guid(a.guid) and Name(a.name) end
local function Now(clock) local n=clock();if Whole(n,1,4102444800) then return n end end
local function Draft(s,d,now)
    if type(d)~="table" or not P.Matches(s,d) then return nil end
    local form={name=d.name,location=d.location,startUTC=d.startUTC,capacity=d.capacity,bestOf=d.bestOf,closeBefore=d.closeBefore,
        minLevel=d.minLevel==0 and "" or tostring(d.minLevel),maxLevel=d.maxLevel==0 and "" or tostring(d.maxLevel),rules=d.rules}
    local clean=T.ValidateDraft(s.client,form,now,s.region,s.ruleset,s.faction)
    if clean and Equal(d,clean) then return clean end
end
local function ID(owner,stamp,serial) return owner..":"..stamp..":"..serial end
-- The scheduled start is not a terminal outcome. Unknown states fail closed.
local function BlocksCreation(event)
    return event~=nil and event.state~="cancelled" and event.state~="completed"
end
-- Canonical, detached organizer checkpoint, valid even after scheduled start.
local function Checkpoint(s,h,saved)
    if type(saved)~="table" or type(saved.ad)~="table" or type(saved.roster)~="table" then return nil end
    local a=saved.ad
    if not Actor(s,h) or not P.Matches(s,a) or a.scope~="SIMULATED" or a.version~=1 or a.owner~=h.guid
        or a.organizer~=h.name or not Whole(a.publishedAt,1,4102444800) or not Whole(a.serial,1,2147483647)
        or not Whole(a.revision,1,2147483647) or a.id~=ID(h.guid,a.publishedAt,a.serial)
        or (a.state~="open" and a.state~="cancelled" and a.state~="completed") then return nil end
    local d=Draft(s,a.draft,a.publishedAt)
    if not d or not Whole(a.count,0,d.capacity) then return nil end
    local rows,seen,n={},{},0
    for k,m in pairs(saved.roster) do
        n=n+1
        if n>d.capacity or not Whole(k,1,d.capacity) or type(m)~="table" or not Guid(m.guid)
            or m.guid==h.guid or seen[m.guid] or not Name(m.name) or not Whole(m.level,1,255)
            or (d.minLevel>0 and m.level<d.minLevel) or (d.maxLevel>0 and m.level>d.maxLevel)
            or type(m.checkedIn)~="boolean" then return nil end
        seen[m.guid]=true;rows[k]={guid=m.guid,name=m.name,level=m.level,checkedIn=m.checkedIn}
    end
    if n~=a.count then return nil end
    for i=1,n do if not rows[i] or (i>1 and rows[i-1].guid>=rows[i].guid) then return nil end end
    local clean={ad={scope="SIMULATED",version=1,id=a.id,owner=h.guid,organizer=h.name,client=s.client,region=s.region,
        ruleset=s.ruleset,faction=s.faction,state=a.state,publishedAt=a.publishedAt,serial=a.serial,revision=a.revision,draft=d,count=n},roster=rows}
    if Equal(saved,clean) then return clean end
end
local function Host(s,h,clock,saved)
    if not P.Key(s) or not Actor(s,h) then return nil end
    s,h=Copy(s),Copy(h)
    local D,event,roster,serial={},nil,{},0
    if saved~=nil then
        local clean=Checkpoint(s,h,saved)
        local now=Now(clock)
        if not clean or not now or clean.ad.publishedAt>now then return nil end
        event=clean.ad;event.count=nil;serial=event.serial
        for _,m in ipairs(clean.roster) do roster[m.guid]=m end
    end
    local function Count() local n=0;for _ in pairs(roster) do n=n+1 end;return n end
    local function Active(id,n) return event and event.id==id and event.state=="open" and n and n<event.draft.startAt end
    local function Bump() event.revision=event.revision+1 end
    function D.Ad() if event then local a=Copy(event);a.count=Count();return a end end
    function D.Publish(sender,d)
        local n=Now(clock)
        if sender~=h.guid or not n then return nil,"Organizer or time unavailable." end
        if BlocksCreation(event) then return nil,"Finish or cancel your current tournament first." end
        local clean=Draft(s,d,n)
        if not clean then return nil,"Review the draft and registration deadline." end
        serial=serial+1;roster={}
        event={scope="SIMULATED",version=1,id=ID(h.guid,n,serial),owner=h.guid,organizer=h.name,client=s.client,region=s.region,
            ruleset=s.ruleset,faction=s.faction,state="open",publishedAt=n,serial=serial,revision=1,draft=clean}
        return D.Ad()
    end
    function D.Roster(sender)
        if sender~=h.guid then return nil end
        local o={};for _,r in pairs(roster) do o[#o+1]=Copy(r) end
        table.sort(o,function(a,b)return a.guid<b.guid end);return o
    end
    function D.Save()
        if event then return {ad=D.Ad(),roster=D.Roster(h.guid)} end
    end
    function D.Join(id,sender,a)
        local n=Now(clock)
        if not Actor(s,a) or a.guid~=sender or sender==h.guid then return false,"Incompatible player or community." end
        if not Active(id,n) or n>=event.draft.registrationClosesAt then return false,"Registration is closed." end
        if roster[sender] then return true,"Already registered." end
        local d=event.draft
        if not Whole(a.level,1,255) or (d.minLevel>0 and a.level<d.minLevel) or (d.maxLevel>0 and a.level>d.maxLevel) then return false,"Character level is not eligible." end
        if Count()>=d.capacity then return false,"Tournament is full." end
        roster[sender]={guid=sender,name=a.name,level=a.level,checkedIn=false};Bump();return true,"Registered."
    end
    function D.Leave(id,sender)
        if not Active(id,Now(clock)) or not roster[sender] then return false,"Not registered." end
        roster[sender]=nil;Bump();return true,"Registration withdrawn."
    end
    function D.CheckIn(id,sender)
        local n=Now(clock)
        if not Active(id,n) or not roster[sender] then return false,"Join the tournament first." end
        if n<event.draft.startAt-1800 then return false,"Check-in opens 30 minutes before start." end
        if not roster[sender].checkedIn then roster[sender].checkedIn=true;Bump() end
        return true,"Checked in."
    end
    function D.Cancel(id,sender)
        if sender~=h.guid or not event or id~=event.id or event.state~="open" then return false,"Only the organizer can cancel." end
        event.state="cancelled";Bump();return true,"Cancelled."
    end
    -- Only the durable completion transition may persist this projection.
    function D.Complete(id,sender)
        if sender~=h.guid or not event or id~=event.id or event.state~="open" then return false end
        event.state="completed";Bump();return true
    end
    return D
end
-- Only complete, sender-bound, exact-community advertisements enter the cache.
-- Caller identities are fixture inputs, not proof of actual network origin.
local function ValidateAdvertisement(s,sender,ad,n)
        if not n or type(ad)~="table" or not P.Matches(s,ad) or ad.scope~="SIMULATED" or ad.version~=1
            or not Guid(sender) or ad.owner~=sender or not Name(ad.organizer) or not Whole(ad.publishedAt,1,n)
            or not Whole(ad.serial,1,2147483647) or not Whole(ad.revision,1,2147483647)
            or ad.id~=ID(sender,ad.publishedAt,ad.serial) or (ad.state~="open" and ad.state~="cancelled") then return false end
        local clean=Draft(s,ad.draft,ad.publishedAt)
        if not clean or not Whole(ad.count,0,clean.capacity) then return false end
        local expected={scope="SIMULATED",version=1,id=ad.id,owner=sender,organizer=ad.organizer,client=s.client,region=s.region,
            ruleset=s.ruleset,faction=s.faction,state=ad.state,publishedAt=ad.publishedAt,serial=ad.serial,revision=ad.revision,draft=clean,count=ad.count}
        if Equal(ad,expected) then return expected end
end

local function Cache(s,clock)
    if not P.Key(s) then return nil end
    s=Copy(s);local D,rows,hints={},{},{}
    local function Prune(n)
        for id,r in pairs(rows) do
            if not BlocksCreation(r.ad) and n>=r.ad.draft.startAt then rows[id]=nil end
        end
    end
    function D.Accept(sender,ad)
        local n=Now(clock)
        local expected=ValidateAdvertisement(s,sender,ad,n)
        if not expected then return false end
        local clean=expected.draft
        -- A known event may receive its creator's cancellation after start.
        if n>=clean.startAt and not (ad.state=="cancelled" and rows[ad.id] and BlocksCreation(rows[ad.id].ad)) then return false end
        Prune(n)
        local old=rows[ad.id]
        if old then
            if ad.revision<old.ad.revision or not Equal(old.ad.draft,clean) or old.ad.organizer~=ad.organizer
                or (not BlocksCreation(old.ad) and old.ad.state~=ad.state)
                or (ad.revision==old.ad.revision and not Equal(old.ad,expected)) then return false end
        else
            local count=0
            for _,r in pairs(rows) do
                count=count+1
                if BlocksCreation(ad) and BlocksCreation(r.ad) and r.ad.owner==sender then return false end
            end
            if count>=64 then return false end
        end
        rows[ad.id]={ad=expected,seen=n};hints[ad.id]=nil
        return true
    end
    -- The owner-bound terminal receipt may retire a known advertisement.
    -- Check before persisting the participant acknowledgement, then apply.
    function D.Terminal(owner,id,rev,state,apply)
        local n=Now(clock)
        if not n or not Guid(owner) or not Whole(rev,2,2147483647)
            or (state~="cancelled" and state~="completed") then return false end
        local row=rows[id]
        if row then
            local a=row.ad
            if a.owner~=owner or rev<a.revision
                or (a.state=="open" and rev==a.revision)
                or (a.state~="open" and (state~=a.state or rev~=a.revision)) then return false end
            if apply then a.state=state;a.revision=rev;row.seen=n end
        end
        if apply then hints[id]=nil end
        return true
    end
    -- Owner-observed data may be shared for discovery even after its fresh
    -- browse window. It is NOT a current owner confirmation for the receiver.
    function D.Known(id)
        local n=Now(clock);local row=rows[id]
        if n and row and row.ad.state=="open" and n<row.ad.draft.registrationClosesAt then return Copy(row.ad) end
    end
    function D.AcceptHint(actor,ad)
        local n=Now(clock)
        if not Actor(s,actor) or type(ad)~="table" or actor.guid==ad.owner then return false end
        local clean=ValidateAdvertisement(s,ad.owner,ad,n)
        if not clean or clean.state~="open" or n>=clean.draft.registrationClosesAt then return false end
        local known=rows[clean.id]
        if known and (known.ad.state~="open" or clean.revision<known.ad.revision
            or not Equal(known.ad.draft,clean.draft) or known.ad.organizer~=clean.organizer
            or (clean.revision==known.ad.revision and not Equal(known.ad,clean))) then return false end
        for id,row in pairs(rows) do
            if id~=clean.id and row.ad.owner==clean.owner and BlocksCreation(row.ad) then return false end
        end
        local previous=hints[clean.id]
        -- A relay cannot override a conflicting hint or replace owner rules.
        if previous and (clean.revision<previous.revision or not Equal(previous.draft,clean.draft)
            or previous.organizer~=clean.organizer or (clean.revision==previous.revision and not Equal(previous,clean))) then return false end
        local count=0
        for id,hint in pairs(hints) do
            if n>=hint.draft.registrationClosesAt then hints[id]=nil
            else
                if id~=clean.id and hint.owner==clean.owner then return false end
                count=count+1
            end
        end
        if not previous and count>=64 then return false end
        hints[clean.id]=clean;return true
    end
    function D.Hints()
        local n=Now(clock);local out={}
        if not n then return out end
        for id,hint in pairs(hints) do
            local known=rows[id]
            if n>=hint.draft.registrationClosesAt or (known and not BlocksCreation(known.ad)) then hints[id]=nil
            else out[#out+1]={status="unconfirmed",ad=Copy(hint)} end
        end
        table.sort(out,function(a,b)return a.ad.id<b.ad.id end)
        return out
    end
    function D.Browse()
        local n=Now(clock);local o={};if not n then return o end
        Prune(n)
        for _,r in pairs(rows) do if r.ad.state=="open" and n<r.ad.draft.registrationClosesAt and n-r.seen<=120 then o[#o+1]=Copy(r.ad) end end
        table.sort(o,function(a,b)if a.draft.startAt==b.draft.startAt then return a.id<b.id end;return a.draft.startAt<b.draft.startAt end)
        return o
    end
    return D
end
-- Stage 5B1: isolated, bounded request/reply protocol. The registration
-- engine and cache above remain the sole owners. Resolvers are fixture
-- observations, NOT identity authentication from live addon messages.
local MAX_BODY,MAX_PARTS,CHUNK=237,12,120
local function Split(s)
    local out={}
    for v in (s.."|"):gmatch("(.-)|") do out[#out+1]=v end
    return out
end
local function Packet(s)
    return type(s)=="string" and #s>0 and #s<=MAX_BODY and not s:find("[%c]")
end
local function Number(s,lo,hi)
    local n=tonumber(s)
    if Whole(n,lo,hi) and tostring(n)==s then return n end
end
local function Hex(s)
    return (s:gsub(".",function(c)return string.format("%02x",c:byte())end))
end
local function Unhex(s)
    if #s%2~=0 or s:find("[^0-9a-f]") then return nil end
    return (s:gsub("..",function(c)return string.char(tonumber(c,16))end))
end
local function EncodeAd(ad)
    if not ad then return "-" end
    local d=ad.draft
    return table.concat({ad.organizer,ad.publishedAt,ad.serial,ad.revision,ad.state,ad.count,
        d.name,d.location,d.startUTC,d.capacity,d.bestOf,d.closeBefore,d.minLevel,d.maxLevel,d.rules},"|")
end
local function DecodeAd(scope,owner,body)
    local a=Split(body)
    if #a~=15 then return nil end
    local stamp=Number(a[2],1,4102444800)
    local serial=Number(a[3],1,2147483647)
    local rev=Number(a[4],1,2147483647)
    local count=Number(a[6],0,32)
    local capacity,best,lead=Number(a[10],4,32),Number(a[11],1,5),Number(a[12],0,60)
    local lo,hi=Number(a[13],0,255),Number(a[14],0,255)
    if not stamp or not serial or not rev or not count or not capacity or not best or not lead or not lo or not hi then return nil end
    local draft=T.ValidateDraft(scope.client,{name=a[7],location=a[8],startUTC=a[9],capacity=capacity,bestOf=best,
        closeBefore=lead,minLevel=lo==0 and "" or a[13],maxLevel=hi==0 and "" or a[14],rules=a[15]},
        stamp,scope.region,scope.ruleset,scope.faction)
    if not draft then return nil end
    local ad={scope="SIMULATED",version=1,id=ID(owner,stamp,serial),owner=owner,organizer=a[1],client=scope.client,
        region=scope.region,ruleset=scope.ruleset,faction=scope.faction,state=a[5],publishedAt=stamp,
        serial=serial,revision=rev,count=count,draft=draft}
    if EncodeAd(ad)==body then return ad end
end
local function Fragments(key,seq,body)
    local encoded=Hex(body)
    local total=math.ceil(#encoded/CHUNK)
    if total<1 or total>MAX_PARTS then return nil end
    local out={}
    for i=1,total do
        local packet=table.concat({"F",key,seq,i,total,encoded:sub((i-1)*CHUNK+1,i*CHUNK)},"|")
        if not Packet(packet) then return nil end
        out[i]=packet
    end
    return out
end
-- Only a verified adapter may supply the mapping sender -> observed actor.
-- No caller may turn an untrusted packet GUID/name/level into this mapping.
local function WireHost(scope,host,engine,resolve,saved)
    local key=P.Key(scope)
    local receipts,n={},0
    local queries,queryCount={},0
    if saved then for guid,row in pairs(saved) do receipts[guid]=Copy(row);n=n+1 end end
    local D={}
    function D.Receive(sender,body)
        if not Packet(body) then return nil end
        local actor=resolve(sender)
        if not Actor(scope,actor) or actor.guid==host.guid then return nil end
        local a=Split(body)
        local seq=Number(a[3],1,2147483647)
        if a[2]~=key or not seq then return nil end
        local query=a[1]=="Q" and #a==3
        local mutation=a[1]=="M" and #a==5 and (a[4]=="J" or a[4]=="L" or a[4]=="C" or a[4]=="S")
        if not query and not mutation then return nil end
        local current=engine.Ad()
        if mutation and current and current.state=="cancelled" and current.id==a[5] then
            return {table.concat({"X",key,seq,current.id,current.revision},"|")}
        end
        local prior,recent=receipts[actor.guid],queries[actor.guid]
        local old=prior
        if recent and (not old or recent.seq>old.seq) then old=recent end
        if old then
            if seq<old.seq then return nil end
            if seq==old.seq then
                if old.body==body then return Copy(old.reply) end
                return nil
            end
        end
        if query and not recent and queryCount>=64 then return nil end
        if mutation and not prior and n>=64 then return nil end
        local ad=engine.Ad()
        local reply
        if query then
            reply=Fragments(key,seq,EncodeAd(ad and ad.state~="completed" and ad or nil))
        else
            if not ad or ad.id~=a[5] or ad.state~="open" then return nil end
            local ok
            if a[4]=="J" then ok=engine.Join(ad.id,actor.guid,actor)
            elseif a[4]=="L" then ok=engine.Leave(ad.id,actor.guid)
            elseif a[4]=="C" then ok=engine.CheckIn(ad.id,actor.guid)
            else ok=true end
            local status="none"
            for _,member in ipairs(engine.Roster(host.guid)) do
                if member.guid==actor.guid then status=member.checkedIn and "checked" or "registered";break end
            end
            reply={table.concat({"A",key,seq,a[4],ad.id,engine.Ad().revision,ok and "1" or "0",status},"|")}
            if not Packet(reply[1]) then return nil end
        end
        if not reply then return nil end
        local row={seq=seq,body=body,reply=Copy(reply)}
        if query then
            if not recent then queryCount=queryCount+1 end
            queries[actor.guid]=row
        else
            if not prior then n=n+1 end
            receipts[actor.guid]=row
        end
        return reply
    end
    function D.SaveReceipts() return Copy(receipts) end
    return D
end
-- One outstanding request and one commitment across all known organizers.
-- A lost mutation acknowledgement is not a rejection or permission to rejoin.
-- A relay can carry a pending request hint, never register on behalf of
-- the origin. The creator must observe the original sender's direct retry.
-- This is a volatile simulated mailbox, not a new persistence owner.
local function Relay(scope,cache,clock,resolve)
    local D,rows={},{}
    local key=P.Key(scope)
    if not key then return nil end
    local function Prune(now)
        for guid,row in pairs(rows) do if now>=row.deadline then rows[guid]=nil end end
    end
    function D.Queue(sender,body)
        local now=Now(clock)
        if not now or not Packet(body) then return false end
        local actor=resolve(sender)
        if not Actor(scope,actor) then return false end
        local a=Split(body)
        if #a~=5 or a[1]~="M" or a[2]~=key or not Number(a[3],1,2147483647) or a[4]~="J" then return false end
        local ad=cache.Known(a[5])
        if not ad or ad.owner==actor.guid or not Whole(actor.level,1,255) or now>=ad.draft.registrationClosesAt
            or (ad.draft.minLevel>0 and actor.level<ad.draft.minLevel)
            or (ad.draft.maxLevel>0 and actor.level>ad.draft.maxLevel) then return false end
        Prune(now)
        local previous=rows[actor.guid]
        if previous then return previous.body==body end
        local count=0;for _ in pairs(rows) do count=count+1 end
        if count>=64 then return false end
        rows[actor.guid]={origin=actor.guid,owner=ad.owner,event=ad.id,body=body,
            deadline=ad.draft.registrationClosesAt,status="pending-direct-confirmation"}
        return true
    end
    function D.Pending(sender)
        local now=Now(clock)
        local actor=resolve(sender)
        if not now or not Actor(scope,actor) then return {} end
        Prune(now)
        local out={}
        for _,row in pairs(rows) do if row.owner==actor.guid then out[#out+1]=Copy(row) end end
        table.sort(out,function(a,b)return a.origin<b.origin end)
        return out
    end
    return D
end
local function WireClient(scope,cache,clock,resolve,store)
    local key=P.Key(scope)
    local D,pending,commitment,seq={},nil,nil,0
    local journal
    if store then
        journal=store.ReadTournamentJournal()
        if not journal or journal.client~=scope.client then return nil end
        local lock=journal.commitment
        if lock and (lock.role~="participant" or lock.population~=key) then return nil end
        seq=journal.sequence
        if lock then commitment={owner=lock.owner,id=lock.id,status=lock.status} end
        if journal.pending then
            local op=journal.pending.op
            pending={owner=lock.owner,op=op,id=lock.id,seq=seq,body=table.concat({"M",key,seq,op,lock.id},"|")}
        end
    end
    local function Fresh()
        if not store then return true end
        local current=store.ReadTournamentJournal()
        return current and Equal(current,journal)
    end
    local function Persist(nextSeq,nextLock,nextOp,action)
        if not store then return true end
        if not Fresh() then return false end
        local candidate=Copy(journal)
        candidate.revision=journal.revision+1;candidate.sequence=nextSeq
        candidate.commitment=nextLock and {role="participant",owner=nextLock.owner,id=nextLock.id,population=key,status=nextLock.status} or nil
        candidate.pending=nextOp and {op=nextOp,sequence=nextSeq} or nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,action)
        if not saved then return false end
        journal=saved;return true
    end
    local function Expire()
        local now=Now(clock)
        if pending and pending.op=="Q" and now and now>=pending.deadline then pending=nil end
        return now
    end
    local function Begin(owner,op,id)
        local now=Expire()
        if not Fresh() or pending or not now or not Guid(owner) or seq>=2147483647 then return nil end
        local nextSeq=seq+1
        local body=op=="Q" and table.concat({"Q",key,nextSeq},"|") or table.concat({"M",key,nextSeq,op,id},"|")
        if not Packet(body) then return nil end
        local nextLock=op=="J" and {owner=owner,id=id,status="pending"} or commitment
        if not Persist(nextSeq,nextLock,op~="Q" and op or nil,op=="Q" and "query" or "begin") then return nil end
        seq=nextSeq;commitment=nextLock
        pending={owner=owner,op=op,id=id,seq=seq,body=body,deadline=now+30,parts={},count=0}
        return body
    end
    function D.Query(owner) return Begin(owner,"Q") end
    function D.Join(owner,id)
        if commitment then return nil end
        local found
        for _,ad in ipairs(cache.Browse()) do if ad.owner==owner and ad.id==id then found=true;break end end
        if not found then return nil end
        local body=Begin(owner,"J",id)
        return body
    end
    function D.JoinPending(owner,id)
        if commitment then return nil end
        for _,hint in ipairs(cache.Hints()) do
            if hint.ad.owner==owner and hint.ad.id==id then return Begin(owner,"J",id) end
        end
    end
    function D.Action(op)
        if not commitment or commitment.status=="pending" or (op~="L" and op~="C" and op~="S") then return nil end
        return Begin(commitment.owner,op,commitment.id)
    end
    function D.Retry()
        Expire()
        if Fresh() then return pending and pending.body end
    end
    function D.Status() return Copy(commitment) end
    function D.Receive(sender,body)
        local now=Expire()
        if not Fresh() or not pending or not now or not Packet(body) then return false end
        local actor=resolve(sender)
        if not Actor(scope,actor) or actor.guid~=pending.owner then return false end
        local a=Split(body)
        if a[2]~=key or Number(a[3],1,2147483647)~=pending.seq then return false end
        if pending.op=="Q" then
            if a[1]~="F" or #a~=6 then return false end
            local i,total=Number(a[4],1,MAX_PARTS),Number(a[5],1,MAX_PARTS)
            local fragment=a[6]
            if not i or not total or i>total or #fragment<2 or #fragment>CHUNK
                or (i<total and #fragment~=CHUNK) or not Unhex(fragment) then return false end
            if pending.total and pending.total~=total then pending=nil;return false end
            pending.total=total
            local old=pending.parts[i]
            if old and old~=fragment then pending=nil;return false end
            if not old then pending.parts[i]=fragment;pending.count=pending.count+1 end
            if pending.count<total then return true,"partial" end
            local decoded=Unhex(table.concat(pending.parts))
            local owner=pending.owner;pending=nil
            if decoded=="-" then return true,"no_event" end
            local ad=decoded and DecodeAd(scope,owner,decoded)
            if not ad or not cache.Accept(owner,ad) then return false end
            return true,"advertisement"
        end
        if a[1]=="X" or a[1]=="Y" then
            if #a~=5 or a[4]~=pending.id or not Number(a[5],2,2147483647)
                or not commitment or commitment.owner~=actor.guid or commitment.id~=pending.id then return false end
            local state=a[1]=="Y" and "completed" or "cancelled"
            local rev=Number(a[5],2,2147483647)
            if not cache.Terminal(actor.guid,pending.id,rev,state,false) then return false end
            if not Persist(seq,nil,nil,"ack") then return false end
            cache.Terminal(actor.guid,pending.id,rev,state,true)
            pending=nil;commitment=nil
            return true,state
        end
        if a[1]~="A" or #a~=8 or a[4]~=pending.op or a[5]~=pending.id
            or not Number(a[6],1,2147483647) or (a[7]~="1" and a[7]~="0")
            or (a[8]~="none" and a[8]~="registered" and a[8]~="checked") then return false end
        if not commitment or commitment.owner~=actor.guid or commitment.id~=pending.id then return false end
        local op,status,ok=pending.op,a[8],a[7]=="1"
        if ok and ((op=="J" and status=="none") or (op=="L" and status~="none") or (op=="C" and status~="checked")) then return false end
        local nextLock=status~="none" and {owner=commitment.owner,id=commitment.id,status=status} or nil
        if not Persist(seq,nextLock,nil,"ack") then return false end
        pending=nil;commitment=nextLock
        return true,ok and "confirmed" or "refused",Number(a[6],1,2147483647)
    end
    return D
end
function R.RunExchangeSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400
            local function A(id) local a=Copy(s);a.guid="Player-1-"..id;a.name="Test "..id;a.level=30;return a end
            local h,a,other=A("HOST"),A("PLAYER"),A("OTHER")
            h.name=string.rep("H",160)
            local foreign=A("FOREIGN");foreign.region="US"
            local observed={host=h,player=a,other=other,foreign=foreign}
            local function Resolve(sender)return observed[sender] end
            local clock=function()return n end
            local d=T.DraftDefaults();d.name="Test Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00"
            d.name=string.rep("N",60);d.location=string.rep("L",100)
            d.rules=string.rep("a",160);d.capacity=4
            d=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            local e=assert(Host(s,h,clock));local ad=assert(e.Publish(h.guid,d))
            local e2=assert(Host(s,other,clock));local ad2=assert(e2.Publish(other.guid,d))
            local c=assert(Cache(s,clock))
            return {s=s,h=h,a=a,other=other,ad=ad,ad2=ad2,e=e,e2=e2,c=c,
                hwire=WireHost(s,h,e,Resolve),otherWire=WireHost(s,other,e2,Resolve),
                player=WireClient(s,c,clock,Resolve),time=function(v)n=v end}
        end
        local function Deliver(x,wire,owner,sender,request)
            local frames=assert(wire.Receive("player",request))
            for _,packet in ipairs(frames) do assert(#packet+3<=240);assert(x.player.Receive(sender,packet)) end
        end
        local function Discover(x)
            Deliver(x,x.hwire,x.h.guid,"host",assert(x.player.Query(x.h.guid)))
            Deliver(x,x.otherWire,x.other.guid,"other",assert(x.player.Query(x.other.guid)))
            assert(#x.c.Browse()==2)
        end
        Case(client.." bounded discovery assembles reverse fragments and rejects wrong sender",function()
            local x=Fixture();local q=assert(x.player.Query(x.h.guid))
            assert(not x.hwire.Receive("unknown",q) and not x.hwire.Receive("foreign",q))
            assert(not x.hwire.Receive("player",q:gsub(":EU:",":US:")))
            local frames=assert(x.hwire.Receive("player",q));assert(#frames>1)
            assert(not x.player.Receive("other",frames[1]) and #x.c.Browse()==0)
            for i=#frames,1,-1 do
                assert(#frames[i]+3<=240 and x.player.Receive("host",frames[i]))
                if i>1 then assert(#x.c.Browse()==0 and x.player.Receive("host",frames[i])) end
            end
            assert(#x.c.Browse()==1 and Equal(x.c.Browse()[1],x.ad))
            assert(not x.player.Receive("host",frames[1]))
        end)
        Case(client.." conflicting and expired discovery cannot populate cache",function()
            local x=Fixture();local q=assert(x.player.Query(x.h.guid));local frames=assert(x.hwire.Receive("player",q))
            assert(x.player.Receive("host",frames[1]))
            local last=frames[1]:sub(-1);local changed=frames[1]:sub(1,-2)..(last=="0" and "1" or "0")
            assert(not x.player.Receive("host",changed) and #x.c.Browse()==0)
            local q2=assert(x.player.Query(x.h.guid));local f2=assert(x.hwire.Receive("player",q2))
            x.time(x.ad.publishedAt+31)
            assert(not x.player.Receive("host",f2[1]) and #x.c.Browse()==0)
            assert(not x.hwire.Receive("player",q))
        end)
        Case(client.." lost join acknowledgement blocks a second commitment",function()
            local x=Fixture();Discover(x)
            local j=assert(x.player.Join(x.h.guid,x.ad.id))
            local ack=assert(x.hwire.Receive("player",j))[1]
            assert(x.e.Ad().count==1 and x.player.Status().status=="pending")
            x.time(x.ad.publishedAt+31)
            assert(not x.player.Join(x.other.guid,x.ad2.id) and not x.player.Action("L"))
            assert(x.player.Retry()==j)
            local retry=assert(x.hwire.Receive("player",j))[1];assert(ack==retry and x.e.Ad().count==1)
            assert(not x.player.Receive("other",retry) and x.player.Receive("host",retry))
            assert(x.player.Status().status=="registered" and not x.player.Join(x.other.guid,x.ad2.id))
            local leave=assert(x.player.Action("L"))
            local gone=assert(x.hwire.Receive("player",leave))[1]
            assert(x.e.Ad().count==0 and x.player.Status().status=="registered")
            assert(not x.player.Join(x.other.guid,x.ad2.id) and x.player.Retry()==leave)
            assert(assert(x.hwire.Receive("player",leave))[1]==gone and x.player.Receive("host",gone))
            assert(not x.player.Status() and x.e.Ad().count==0)
            assert(not x.hwire.Receive("player",j))
            Deliver(x,x.otherWire,x.other.guid,"other",assert(x.player.Join(x.other.guid,x.ad2.id)))
            assert(x.player.Status().owner==x.other.guid and x.e2.Ad().count==1)
        end)
        Case(client.." altered requests, wrong event and out-of-order receipts cannot mutate",function()
            local x=Fixture();Discover(x)
            local j=assert(x.player.Join(x.h.guid,x.ad.id));local ack=assert(x.hwire.Receive("player",j))[1]
            local altered=j:gsub("|J|","|L|")
            assert(not x.hwire.Receive("player",altered))
            assert(not x.otherWire.Receive("player",j))
            assert(not x.player.Receive("host",ack:gsub("|J|","|L|")))
            assert(x.player.Status().status=="pending" and x.player.Receive("host",ack))
            assert(not x.player.Receive("host",ack) and x.e.Ad().count==1)
            local check=assert(x.player.Action("C"));Deliver(x,x.hwire,x.h.guid,"host",check)
            assert(x.player.Status().status=="registered")
            x.time(x.ad.draft.startAt-1800)
            Deliver(x,x.hwire,x.h.guid,"host",assert(x.player.Action("C")))
            assert(x.player.Status().status=="checked" and x.e.Roster(x.h.guid)[1].checkedIn)
        end)
        Case(client.." oversized and malformed frames are rejected without mutation",function()
            local x=Fixture();local q=assert(x.player.Query(x.h.guid))
            assert(not x.hwire.Receive("player",string.rep("x",238)))
            assert(not x.hwire.Receive("player",q.."|extra"))
            assert(not x.hwire.Receive("player",q:gsub("|1$","|01")))
            local frames=assert(x.hwire.Receive("player",q))
            assert(not x.player.Receive("host",string.rep("x",238)))
            assert(not x.player.Receive("host",frames[1]:sub(1,-2).."z"))
            assert(#x.c.Browse()==0 and x.e.Ad().count==0)
        end)
    end
    return p,f
end

-- Validate receipts before reconstructing the organizer. Private fixture
-- storage is not a signature or proof of a live peer's claims.
function R.ValidateHostCheckpoint(client,owner,raw)
    if type(raw)~="table" or type(raw.host)~="table" or type(raw.receipts)~="table" then return nil end
    local a=raw.host.ad
    if type(a)~="table" or a.client~=client or a.owner~=owner then return nil end
    local s={client=client,region=a.region,ruleset=a.ruleset,faction=a.faction}
    local h=Copy(s);h.guid=owner;h.name=a.organizer
    local host=Checkpoint(s,h,raw.host)
    if not host then return nil end
    local key=P.Key(s)
    local receipts,n={},0
    for guid,row in pairs(raw.receipts) do
        n=n+1
        if n>64 or not Guid(guid) or guid==owner or type(row)~="table" or not Whole(row.seq,1,2147483647)
            or not Packet(row.body) or type(row.reply)~="table" or not Packet(row.reply[1]) then return nil end
        local q,b=Split(row.body),Split(row.reply[1])
        if #q~=5 or q[1]~="M" or q[2]~=key or Number(q[3],1,2147483647)~=row.seq
            or (q[4]~="J" and q[4]~="L" and q[4]~="C" and q[4]~="S") or q[5]~=a.id
            or #b~=8 or b[1]~="A" or b[2]~=key or b[3]~=q[3] or b[4]~=q[4] or b[5]~=q[5]
            or not Number(b[6],1,a.revision) or (b[7]~="0" and b[7]~="1")
            or (b[8]~="none" and b[8]~="registered" and b[8]~="checked") then return nil end
        if b[7]=="1" and ((q[4]=="J" and b[8]=="none") or (q[4]=="L" and b[8]~="none")
            or (q[4]=="C" and b[8]~="checked")) then return nil end
        local clean={seq=row.seq,body=row.body,reply={row.reply[1]}}
        if not Equal(clean,row) then return nil end
        receipts[guid]=clean
    end
    local out={host=host,receipts=receipts}
    if Equal(out,raw) then return out end
end
-- Explicit one-page requests: no broadcast, no participant list to a
-- non-member, no mixed-revision roster. Each page uses bounded fragments.
local function RosterReply(s,actor,snap,body)
    local a=Split(body);local ad=snap.ad
    local nonce=Number(a[3],1,2147483647)
    local rev=Number(a[5],1,2147483647)
    local page=Number(a[6],0,32)
    if #a~=6 or a[1]~="G" or a[2]~=P.Key(s) or not nonce or a[4]~=ad.id
        or rev~=ad.revision or not page or page>ad.count or ad.state~="open" then return nil end
    local member
    for _,m in ipairs(snap.roster) do if m.guid==actor.guid then member=true;break end end
    if not member then return nil end
    local payload
    if page==0 then payload=ad.id.."|"..EncodeAd(ad)
    else
        local m=snap.roster[page]
        payload=table.concat({ad.id,m.guid,m.name,m.level,m.checkedIn and "1" or "0"},"|")
    end
    local encoded=Hex(payload)
    local total=math.ceil(#encoded/CHUNK)
    if total<1 or total>MAX_PARTS then return nil end
    local result={}
    for i=1,total do
        local packet=table.concat({"B",P.Key(s),nonce,rev,page,i,total,encoded:sub((i-1)*CHUNK+1,i*CHUNK)},"|")
        if not Packet(packet) then return nil end
        result[i]=packet
    end
    return result
end
local function DurableHost(s,h,clock,resolve,store)
    local D={}
    local journal=store.ReadTournamentJournal()
    if not journal or journal.character~=h.guid or journal.client~=s.client then return nil end
    local key=P.Key(s)
    if journal.commitment and (journal.commitment.role~="host" or journal.commitment.population~=key) then return nil end
    if journal.commitment and not journal.checkpoint then return nil end
    local function Fresh() return Equal(journal,store.ReadTournamentJournal()) end
    local function Open()
        if not Fresh() or not journal.checkpoint then return nil end
        -- Once started, a clock rollback cannot reopen registration.
        local function FrozenClock()
            local now=Now(clock)
            if not now then return nil end
            if journal.bracket then return math.max(now,journal.bracket.startedAt) end
            return now
        end
        return Host(s,h,FrozenClock,journal.checkpoint.host)
    end
    local function Save(engine,wire,action)
        if not Fresh() then return false end
        local snap=engine.Save()
        local candidate=Copy(journal)
        candidate.revision=candidate.revision+1
        if action=="host_open" then candidate.sequence=candidate.sequence+1 end
        candidate.checkpoint={host=snap,receipts=wire and wire.SaveReceipts() or {}}
        local a=snap.ad
        if action=="host_cancel" then
            candidate.bracket=nil;candidate.control=nil
            candidate.cancelled=candidate.cancelled or {}
            candidate.cancelled[a.id]={population=key,revision=a.revision}
        elseif action=="host_open" and journal.checkpoint then
            local old=journal.checkpoint.host.ad
            if old.state=="cancelled" then
                candidate.cancelled=candidate.cancelled or {}
                candidate.cancelled[old.id]={population=P.Key(old),revision=old.revision}
            end
        end
        candidate.commitment=a.state=="open" and {role="host",owner=h.guid,id=a.id,population=key,status="hosting"} or nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,action)
        if not saved then return false end
        journal=saved;return true
    end
    function D.Publish(d)
        if not Fresh() or journal.commitment then return nil end
        local e
        if journal.checkpoint then e=Open() else e=Host(s,h,clock) end
        if not e then return nil end
        local a=e.Publish(h.guid,d)
        if a and Save(e,nil,"host_open") then return a end
    end
    local at,spent,byPeer=nil,0,{}
    local function Permit(actor)
        local now=Now(clock)
        if not now or (at and now<at) then return false end
        if now~=at then at=now;spent=0;byPeer={} end
        if spent>=12 or (byPeer[actor.guid] or 0)>=2 then return false end
        spent=spent+1;byPeer[actor.guid]=(byPeer[actor.guid] or 0)+1
        return true
    end
    function D.Receive(sender,body)
        if not Packet(body) then return nil end
        local actor=resolve(sender)
        if not Actor(s,actor) or actor.guid==h.guid or not Permit(actor) then return nil end
        if not Fresh() then return nil end
        local a=Split(body)
        local seq=Number(a[3],1,2147483647)
        if #a==5 and a[1]=="M" and a[2]==key and seq
            and (a[4]=="J" or a[4]=="L" or a[4]=="C" or a[4]=="S") then
            local terminal=journal.cancelled and journal.cancelled[a[5]]
            if terminal and terminal.population==key then
                return {table.concat({"X",key,seq,a[5],terminal.revision},"|")}
            end
            local finished=journal.completed and journal.completed[a[5]]
            if finished and finished.population==key then
                return {table.concat({"Y",key,seq,a[5],finished.revision},"|")}
            end
        end
        local e=Open();if not e then return nil end
        if a[1]=="G" then return RosterReply(s,actor,e.Save(),body) end
        local w=WireHost(s,h,e,resolve,journal.checkpoint.receipts)
        local reply=w.Receive(sender,body)
        if not reply then return nil end
        if body:sub(1,2)=="M|" and e.Ad().state=="open" then
            if not Equal(w.SaveReceipts(),journal.checkpoint.receipts) or not Equal(e.Save(),journal.checkpoint.host) then
                if not Save(e,w,"host_checkpoint") then return nil end
            end
        end
        return reply
    end
    function D.Cancel(sender,id)
        local e=Open();if not e or not journal.commitment or not e.Cancel(id,sender) then return false end
        local w=WireHost(s,h,e,resolve,journal.checkpoint.receipts)
        return Save(e,w,"host_cancel")
    end
    -- Bracket changes use the same character-owned journal and CAS. No
    -- separate database, no live result intake, no actual tournament release.
    local function SaveBracket(engine,action)
        if not Fresh() then return false end
        local candidate=Copy(journal)
        candidate.revision=candidate.revision+1
        candidate.bracket=engine.Save()
        if action=="bracket_start" then candidate.control=ns.TournamentRecovery.InitialControl(candidate.bracket) end
        local saved=store.CommitTournamentJournal(journal.revision,candidate,action)
        if not saved then return false end
        journal=saved;return true
    end
    local function OpenBracket()
        if not Fresh() or not journal.bracket or not ns.TournamentBracket then return nil end
        return ns.TournamentBracket.OpenSimulated(s,h.guid,journal.bracket)
    end
    function D.StartBracket(sender)
        local e=Open();local now=Now(clock)
        if not e or not now or not journal.commitment or journal.bracket or sender~=h.guid or not ns.TournamentBracket then return false end
        local b=ns.TournamentBracket.NewSimulated(s,h.guid,e.Save(),now,sender)
        return b~=nil and SaveBracket(b,"bracket_start")
    end
    function D.BracketSnapshot()
        local b=OpenBracket();return b and b.Snapshot()
    end
    local observed={}
    function D.ReportBracket(sender,report,term,coordinator)
        local c=journal.control
        if not Fresh() or not c or c.paused or c.term~=term or c.coordinator~=coordinator then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or not Permit(actor) then return false end
        local b=OpenBracket();if not b then return false end
        local ok,why=b.Report(actor.guid,report)
        if not ok then return false end
        if why=="duplicate" then return true,why end
        if not SaveBracket(b,"bracket_report") then return false end
        observed[report.match]=nil
        return true,why
    end
    -- One transient observer per ready match; at most 31 match IDs.
    -- The caller supplies verified fixture observations, not remote claims.
    -- No timers, live presence subscriptions or notification side effects.
    function D.ObserveMatch(match,states,term,coordinator)
        local c=journal.control;local now=Now(clock)
        if not Fresh() or not c or c.paused or c.term~=term or c.coordinator~=coordinator or not now then return nil end
        local b=OpenBracket();local view=b and b.Snapshot()
        if not view or view.state~="running" or type(match)~="string" then return nil end
        if type(states)~="table" then observed[match]=nil;return nil end
        local m
        for _,round in ipairs(view.rounds) do for _,v in ipairs(round) do if v.id==match then m=v end end end
        if not m or m.state~="ready" then return nil end
        local a,z=states[m.a],states[m.b]
        local function valid(v)return v=="online" or v=="offline" or v=="unknown" end
        if not valid(a) or not valid(z) then observed[match]=nil;return nil end
        for guid in pairs(states) do if guid~=m.a and guid~=m.b then observed[match]=nil;return nil end end
        local old=observed[match]
        if old and (old.term~=term or now<old.last or now-old.last>15) then old=nil;observed[match]=nil end
        local loser=a=="offline" and z=="online" and m.a or z=="offline" and a=="online" and m.b or nil
        local out={scope="SIMULATED",event=view.event,match=match,players=Copy(states),grace=300}
        if not loser then
            if old and states[old.loser]=="online" then out.notice="reconnected";out.player=old.loser
            elseif old then out.notice="interrupted";out.player=old.loser end
            observed[match]=nil;return out
        end
        if not old or old.loser~=loser then
            old={loser=loser,since=now,last=now,term=term};observed[match]=old
            out.notice="started";out.player=loser
        end
        old.last=now
        out.player=loser;out.remaining=math.max(0,300-(now-old.since))
        if out.remaining==0 then
            local ok=b.ForfeitOffline({kind="offline",event=view.event,match=match,revision=view.revision,loser=loser,since=old.since,at=now})
            if not ok or not SaveBracket(b,"bracket_report") then return nil end
            observed[match]=nil;out.notice="forfeited"
        end
        return out
    end
    function D.WithdrawBracket(sender,request,term,coordinator)
        local c=journal.control
        if not Fresh() or not c or c.paused or c.term~=term or c.coordinator~=coordinator then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or not Permit(actor) then return false end
        local b=OpenBracket();if not b then return false end
        local ok,why=b.Withdraw(actor.guid,request)
        if not ok then return false end
        if why=="duplicate" then return true,why end
        if not SaveBracket(b,"bracket_report") then return false end
        return true,why
    end
    function D.ControlSnapshot()
        if not Fresh() or not journal.bracket or not journal.control then return nil end
        local c=Copy(journal.control);c.owner=h.guid;c.event=journal.checkpoint.host.ad.id;return c
    end
    -- Trusted simulated observation adapter, not a network message handler.
    -- All authority still comes from one CAS-protected journal in this build.
    function D.ReconcileControl(term,connections,copies)
        if not Fresh() or not journal.bracket or not journal.control or journal.control.term~=term then return false end
        local c=ns.TournamentRecovery.ReconcileControl(journal.bracket,journal.control,connections,copies)
        if not c then return false end
        local candidate=Copy(journal);candidate.revision=candidate.revision+1;candidate.control=c
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"control_change")
        if not saved then return false end
        journal=saved;return true
    end
    function D.Finalize(sender,id,term,copies)
        if not Fresh() or sender~=h.guid or not journal.commitment or journal.commitment.id~=id
            or not journal.bracket or not journal.control or journal.control.term~=term then return false end
        local now=Now(clock)
        local record=now and ns.TournamentRecovery.FinalRecord(s.client,h.guid,journal.bracket,journal.control,now,copies)
        if not record then return false end
        local e=Open()
        if not e or not e.Complete(id,sender) then return false end
        local candidate=Copy(journal);candidate.revision=candidate.revision+1
        candidate.checkpoint={host=e.Save(),receipts=Copy(journal.checkpoint.receipts)}
        candidate.completed=candidate.completed or {}
        candidate.completed[id]=record
        candidate.bracket=nil;candidate.control=nil;candidate.commitment=nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"host_complete")
        if not saved then return false end
        journal=saved;return true
    end
    function D.Completed(id)
        if Fresh() and journal.completed then return Copy(journal.completed[id]) end
    end
    -- Explicit owner hold; no fabricated result, no roster removal.
    function D.Hold(sender,id,term)
        local c=journal.control
        if not Fresh() or sender~=h.guid or not journal.commitment or journal.commitment.id~=id
            or not c or c.coordinator~=sender or c.paused or c.term~=term or term>=2147483647 then return false end
        local candidate=Copy(journal);candidate.revision=candidate.revision+1
        candidate.control={term=term+1,coordinator=sender,paused=true}
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"control_change")
        if not saved then return false end
        journal=saved;return true
    end
    function D.Snapshot() local e=Open();return e and e.Save() end
    return D
end
local function Replica(s,owner,id)
    local current
    local D={}
    function D.Accept(sender,snapshot)
        if sender~=owner or type(snapshot)~="table" or type(snapshot.ad)~="table" or snapshot.ad.id~=id then return false end
        local h=Copy(s);h.guid=owner;h.name=snapshot.ad.organizer
        local next=Checkpoint(s,h,snapshot)
        if not next then return false end
        if current then
            local a,b=current.ad,next.ad
            if b.revision<a.revision or not Equal(a.draft,b.draft) or a.organizer~=b.organizer
                or (a.state=="cancelled" and b.state~="cancelled")
                or (b.revision==a.revision and not Equal(current,next)) then return false end
        end
        current=next;return true
    end
    function D.Snapshot() return Copy(current) end
    return D
end

-- Read-only roster assembly for a registered participant. A caller starts
-- from an observed owner and the revision returned by a status receipt.
-- Nonces here are fixture inputs; live session/epoch binding is still required.
local function RosterReceiver(s,owner,id,rev,nonce,clock,resolve,replica)
    if not P.Key(s) or not Guid(owner) or not Whole(rev,1,2147483647) or not Whole(nonce,1,2147483647) then return nil end
    local D,ad,rows={},nil,{}
    local pending,dead
    function D.Request(page)
        local now=Now(clock)
        if dead or not now or not Whole(page,0,32) or (page~=0 and (not ad or page>ad.count)) then return nil end
        if pending and now<pending.deadline then return nil end
        if (page==0 and ad) or rows[page] then return nil end
        pending={page=page,parts={},count=0,deadline=now+30}
        return table.concat({"G",P.Key(s),nonce,id,rev,page},"|")
    end
    function D.Receive(sender,body)
        local now=Now(clock)
        if dead or not pending or not now or now>=pending.deadline or not Packet(body) then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or actor.guid~=owner then return false end
        local a=Split(body)
        if #a~=8 or a[1]~="B" or a[2]~=P.Key(s) or Number(a[3],1,2147483647)~=nonce
            or Number(a[4],1,2147483647)~=rev or Number(a[5],0,32)~=pending.page then return false end
        local i,n=Number(a[6],1,MAX_PARTS),Number(a[7],1,MAX_PARTS)
        local chunk=a[8]
        if not i or not n or i>n or #chunk<2 or #chunk>CHUNK or (i<n and #chunk~=CHUNK) or not Unhex(chunk) then return false end
        if (pending.total and pending.total~=n) or (pending.parts[i] and pending.parts[i]~=chunk) then
            dead=true;pending=nil;return false
        end
        pending.total=n
        if not pending.parts[i] then pending.parts[i]=chunk;pending.count=pending.count+1 end
        if pending.count<n then return true,"partial" end
        local payload=Unhex(table.concat(pending.parts))
        local page=pending.page;pending=nil
        local event,rest=payload:match("^([^|]+)|(.+)$")
        if event~=id then dead=true;return false end
        if page==0 then
            ad=DecodeAd(s,owner,rest)
            if not ad or ad.id~=id or ad.revision~=rev or ad.state~="open" or ad.count<1 then dead=true;return false end
        else
            local fields=Split(rest)
            local level=Number(fields[3],1,255)
            if #fields~=4 or not Guid(fields[1]) or not Name(fields[2]) or not level
                or (fields[4]~="0" and fields[4]~="1") then dead=true;return false end
            rows[page]={guid=fields[1],name=fields[2],level=level,checkedIn=fields[4]=="1"}
        end
        if ad then
            for i=1,ad.count do if not rows[i] then return true,"page" end end
            dead=true
            if replica.Accept(owner,{ad=ad,roster=rows}) then return true,"complete" end
            return false
        end
        return true,"page"
    end
    return D
end
-- Coordinator handoff readiness is only a checkpoint agreement check.
-- It never elects anyone, grants owner rights or advances the tournament.
-- Detached progress replica. Only the injected current-control observation
-- can authorize an update. This does not authenticate a remote election.
local function ProgressReplica(s,owner,id,readControl,resolve)
    local D,current,term={},nil,0
    function D.Accept(sender,claimedTerm,saved)
        local c,verified=readControl()
        local a=resolve(sender)
        if not Actor(s,a) or type(c)~="table" or c.owner~=owner or c.event~=id or c.paused
            or not Whole(claimedTerm,1,2147483647) or c.term~=claimedTerm or claimedTerm<term
            or c.coordinator~=a.guid then return false end
        local domain=ns.TournamentBracket
        local b=domain and domain.OpenSimulated(s,owner,saved)
        if not b then return false end
        local clean=b.Save()
        -- A coordinator's plausible replay is not independent result
        -- evidence. The fixture verifier must match the exact canonical log.
        if clean.checkpoint.ad.id~=id or not Equal(clean,verified) then return false end
        if current then
            if not Equal(clean.checkpoint,current.checkpoint) or clean.startedAt~=current.startedAt
                or #clean.reports<#current.reports then return false end
            for i,v in ipairs(current.reports) do if not Equal(v,clean.reports[i]) then return false end end
        end
        current=clean;term=claimedTerm;return true
    end
    function D.Snapshot() return Copy(current),term end
    return D
end
local function CheckpointAgreement(s,owner,snap,observations)
    if type(snap)~="table" or type(snap.ad)~="table" or snap.ad.owner~=owner
        or snap.ad.state~="open" or type(observations)~="table" then return false end
    local h=Copy(s);h.guid=owner;h.name=snap.ad.organizer
    local canonical=Checkpoint(s,h,snap)
    if not canonical or canonical.ad.count<2 then return false end
    local eligible={}
    for _,m in ipairs(canonical.roster) do if m.checkedIn then eligible[m.guid]=true end end
    local count=0
    for guid,copy in pairs(observations) do
        if not eligible[guid] or not Equal(copy,canonical) then return false end
        count=count+1
    end
    local total=0;for _ in pairs(eligible) do total=total+1 end
    return total>=2 and count==total
end

function R.RunRecoverySelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400
            local function A(id)local a=Copy(s);a.guid="Player-1-"..id;a.name=id;a.level=30;return a end
            local h,a=A("HOST"),A("PLAYER")
            local x={s=s,owner=a.guid,client=client,writes=0,h=h,a=a}
            function x.Open()
                local d=ns.CompetitiveStorage.NewSimulated(function()return x.account,x.character end,
                    function(ac,ch)x.account=ac;x.character=ch;x.writes=x.writes+1 end,
                    function()return x.client end,function()return x.owner end)
                d.MarkLoaded();return d
            end
            local clock=function()return n end
            local function resolve(sender)if sender=="host" then return h elseif sender=="player" then return a end end
            local d=T.DraftDefaults();d.name="Recovery Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00"
            d=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            x.engine=assert(Host(s,h,clock));x.ad=assert(x.engine.Publish(h.guid,d))
            x.cache=assert(Cache(s,clock));x.wire=WireHost(s,h,x.engine,resolve)
            function x.Player(scope,cache)return WireClient(scope or s,cache or x.cache,clock,resolve,x.Open()) end
            return x
        end
        local function Discover(x,w)
            for _,v in ipairs(assert(x.wire.Receive("player",assert(w.Query(x.h.guid))))) do assert(w.Receive("host",v)) end
        end
        Case(client.." lost join survives storage reopen and exact retry",function()
            local x=Fixture();local w=assert(x.Player());Discover(x,w)
            local j=assert(w.Join(x.h.guid,x.ad.id));local ack=assert(x.wire.Receive("player",j))[1]
            assert(x.Open().ReadTournamentJournal().pending.op=="J")
            local next=assert(x.Player());assert(next.Status().status=="pending" and next.Retry()==j)
            assert(not next.Join(x.h.guid,x.ad.id) and not next.Query(x.h.guid))
            assert(next.Receive("host",ack) and next.Status().status=="registered")
            assert(not w.Receive("host",ack) and not w.Retry())
            assert(x.engine.Ad().count==1 and assert(x.Player()).Status().status=="registered")
        end)
        Case(client.." withdrawal acknowledgement recovery and sequence continuity",function()
            local x=Fixture();local w=assert(x.Player());Discover(x,w)
            assert(w.Receive("host",assert(x.wire.Receive("player",assert(w.Join(x.h.guid,x.ad.id))))[1]))
            local l=assert(w.Action("L"));local ack=assert(x.wire.Receive("player",l))[1]
            local next=assert(x.Player());assert(next.Retry()==l and next.Status().status=="registered")
            assert(not next.Join(x.h.guid,x.ad.id) and next.Receive("host",ack))
            assert(not assert(x.Player()).Status() and x.engine.Ad().count==0)
            local q=assert(assert(x.Player()).Query(x.h.guid));assert(x.wire.Receive("player",q))
        end)
        Case(client.." community change and corrupted storage refuse recovery",function()
            local x=Fixture();local w=assert(x.Player());Discover(x,w);assert(w.Join(x.h.guid,x.ad.id))
            local foreign=Copy(x.s);foreign.faction="Horde"
            assert(not x.Player(foreign,Cache(foreign,function()return 1795622400 end)))
            local saved=x.character;local writes=x.writes
            x.character.clients[client].tournamentJournal.pending.sequence=0
            assert(not x.Player() and not x.Open().ReadTournamentJournal() and not w.Retry())
            assert(x.character==saved and x.writes==writes)
        end)
        Case(client.." host slot survives reload and refuses participant creation",function()
            local x=Fixture();x.owner=x.h.guid
            local d=x.Open();local old=assert(d.ReadTournamentJournal());local next=Copy(old)
            next.revision=1;next.sequence=1
            next.commitment={role="host",owner=x.h.guid,id=x.ad.id,population=P.Key(x.s),status="hosting"}
            assert(d.CommitTournamentJournal(0,next,"host"))
            local recovered=assert(x.Open().ReadTournamentJournal());assert(Equal(recovered,next))
            assert(not x.Player())
            local replace=Copy(recovered);replace.revision=2;replace.sequence=2
            replace.commitment.id=ID(x.h.guid,x.ad.publishedAt,2)
            assert(not x.Open().CommitTournamentJournal(1,replace,"host"))
            local release=Copy(recovered);release.revision=2;release.commitment=nil
            assert(not x.Open().CommitTournamentJournal(1,release,"ack"))
            assert(x.engine.Cancel(x.ad.id,x.h.guid))
            assert(x.Open().CommitTournamentJournal(1,release,"host_terminal"))
            assert(not x.Open().ReadTournamentJournal().commitment)
        end)
        Case(client.." stale writer and character isolation",function()
            local x=Fixture();local w=assert(x.Player());local stale=assert(x.Player());Discover(x,w)
            assert(not stale.Query(x.h.guid))
            local journal=x.Open().ReadTournamentJournal();journal.sequence=999
            assert(x.Open().ReadTournamentJournal().sequence==1)
            local ch=x.character;x.owner="Player-1-ALT";x.character=nil
            assert(x.Open().ReadTournamentJournal().sequence==0)
            x.character=ch;assert(not x.Open().ReadTournamentJournal())
            x.owner=x.a.guid;assert(x.Open().ReadTournamentJournal().sequence==1)
        end)
    end
    return p,f
end

function R.RunHostRecoverySelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400
            local function A(id)local a=Copy(s);a.guid="Player-1-"..id;a.name=id;a.level=30;return a end
            local h,a,other=A("HOST"),A("PLAYER"),A("OTHER")
            local x={s=s,h=h,a=a,other=other}
            function x.Store(who)
                local d=ns.CompetitiveStorage.NewSimulated(function()return x.account,x[who] end,
                    function(ac,ch)x.account=ac;x[who]=ch end,function()return client end,
                    function()return who=="hostRoot" and h.guid or a.guid end)
                d.MarkLoaded();return d
            end
            local clock=function()return n end
            local function Resolve(sender)if sender=="host" then return h elseif sender=="player" then return a elseif sender=="other" then return other end end
            local d=T.DraftDefaults();d.name="Host Recovery Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.capacity=4
            x.draft=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            x.clock=clock;x.resolve=Resolve
            function x.Open()return DurableHost(s,h,clock,Resolve,x.Store("hostRoot"))end
            x.cache=assert(Cache(s,clock))
            function x.Player()return WireClient(s,x.cache,clock,Resolve,x.Store("playerRoot"))end
            function x.Advance(v)n=n+(v or 1) end
            x.engine=assert(x.Open());x.ad=assert(x.engine.Publish(x.draft))
            return x
        end
        local function Join(x)
            local w=assert(x.Player())
            for _,p in ipairs(assert(x.engine.Receive("player",assert(w.Query(x.h.guid))))) do assert(w.Receive("host",p)) end
            x.Advance()
            local j=assert(w.Join(x.h.guid,x.ad.id))
            local ack=assert(x.engine.Receive("player",j))[1]
            return w,j,ack
        end
        Case(client.." host reload restores roster and exact mutation receipt",function()
            local x=Fixture();local w,j,ack=Join(x)
            local next=assert(x.Open());local before=next.Snapshot()
            assert(before.ad.count==1 and before.roster[1].guid==x.a.guid)
            assert(not next.Publish(x.draft))
            assert(assert(next.Receive("player",j))[1]==ack)
            assert(w.Receive("host",ack) and w.Status().status=="registered")
            x.Advance();local l=assert(w.Action("L"))
            local fresh=assert(x.Open())
            local gone=assert(fresh.Receive("player",l))[1]
            assert(w.Receive("host",gone) and not w.Status() and fresh.Snapshot().ad.count==0)
            assert(not next.Cancel(x.h.guid,x.ad.id) and not x.engine.Cancel(x.h.guid,x.ad.id))
        end)
        Case(client.." owner cancellation replaces lost join acknowledgement",function()
            local x=Fixture();local w,j,ack=Join(x)
            assert(not x.engine.Cancel(x.other.guid,x.ad.id))
            assert(x.engine.Cancel(x.h.guid,x.ad.id))
            assert(not x.Store("hostRoot").ReadTournamentJournal().commitment)
            local next=assert(x.Open());assert(next.Snapshot().ad.state=="cancelled")
            x.Advance();local terminal=assert(next.Receive("player",j))[1]
            assert(terminal:sub(1,2)=="X|" and not w.Receive("other",terminal))
            assert(w.Receive("host",terminal) and not w.Status())
            assert(not w.Receive("host",ack))
        end)
        Case(client.." registered participant reconciles owner cancellation",function()
            local x=Fixture();local w,j,ack=Join(x);assert(w.Receive("host",ack))
            assert(x.engine.Cancel(x.h.guid,x.ad.id))
            x.Advance()
            local q=assert(w.Action("S"));local a=assert(x.engine.Receive("player",q))[1]
            local restored=assert(x.Player());assert(restored.Retry()==q and restored.Receive("host",a) and not restored.Status())
        end)
        Case(client.." snapshot rejects foreign owner, tampering and stale revision",function()
            local x=Fixture();local old=x.engine.Snapshot();local w,j,ack=Join(x)
            local cp=x.engine.Snapshot();local replica=Replica(x.s,x.h.guid,x.ad.id)
            assert(not replica.Accept(x.other.guid,cp))
            local bad=Copy(cp);bad.roster[1].level=0;assert(not replica.Accept(x.h.guid,bad))
            assert(replica.Accept(x.h.guid,cp) and not replica.Accept(x.h.guid,old))
            bad=Copy(cp);bad.roster[1].name="Tampered";assert(not replica.Accept(x.h.guid,bad))
            local copy=replica.Snapshot();copy.roster[1].name="Changed";assert(Equal(replica.Snapshot(),cp))
            assert(x.engine.Cancel(x.h.guid,x.ad.id) and replica.Accept(x.h.guid,x.engine.Snapshot()))
            assert(not replica.Accept(x.h.guid,cp))
        end)
        Case(client.." cancelled history survives new publication and organizer reopen",function()
            local x=Fixture();local w,j,ack=Join(x)
            assert(x.engine.Cancel(x.h.guid,x.ad.id))
            local old=assert(x.Store("hostRoot").ReadTournamentJournal())
            assert(old.cancelled[x.ad.id].population==P.Key(x.s))
            local next=assert(x.engine.Publish(x.draft))
            assert(next.id~=x.ad.id and next.count==0)
            local recovered=assert(x.Open())
            x.Advance()
            local reply=assert(recovered.Receive("player",j))[1]
            assert(reply:sub(1,2)=="X|" and not w.Receive("other",reply))
            assert(w.Receive("host",reply) and not w.Status() and not w.Receive("host",ack))
            assert(recovered.Snapshot().ad.id==next.id and recovered.Snapshot().ad.count==0)
        end)
        Case(client.." cancellation evidence cannot be silently removed or invented",function()
            local x=Fixture();assert(x.engine.Cancel(x.h.guid,x.ad.id))
            local store=x.Store("hostRoot");local old=assert(store.ReadTournamentJournal())
            local candidate=Copy(old);candidate.revision=candidate.revision+1;candidate.sequence=candidate.sequence+1
            candidate.cancelled={}
            assert(not store.CommitTournamentJournal(old.revision,candidate,"query"))
            candidate=Copy(old);candidate.revision=candidate.revision+1;candidate.sequence=candidate.sequence+1
            candidate.cancelled[ID(x.h.guid,x.ad.publishedAt,99)]={population=P.Key(x.s),revision=2}
            assert(not store.CommitTournamentJournal(old.revision,candidate,"query"))
            assert(Equal(store.ReadTournamentJournal(),old))
        end)
        Case(client.." participant roster pages assemble atomically and reject wrong sender",function()
            local x=Fixture();local w,j,ack=Join(x)
            local ok,_,rev=w.Receive("host",ack);assert(ok and rev==2)
            local replica=Replica(x.s,x.h.guid,x.ad.id)
            local receiver=assert(RosterReceiver(x.s,x.h.guid,x.ad.id,rev,1,x.clock,x.resolve,replica))
            x.Advance()
            local request=assert(receiver.Request(0))
            assert(not x.engine.Receive("other",request))
            local frames=assert(x.engine.Receive("player",request))
            assert(not receiver.Receive("other",frames[1]))
            for i=#frames,1,-1 do
                assert(#frames[i]+3<=240 and receiver.Receive("host",frames[i]))
                if i>1 then assert(receiver.Receive("host",frames[i])) end
            end
            assert(not replica.Snapshot())
            x.Advance()
            local page=assert(x.engine.Receive("player",assert(receiver.Request(1))))
            for _,p in ipairs(page) do assert(#p+3<=240 and receiver.Receive("host",p)) end
            assert(Equal(replica.Snapshot(),x.engine.Snapshot()))
            assert(not receiver.Receive("host",page[1]))
        end)
        Case(client.." roster revision change forces fresh request and preserves previous snapshot",function()
            local x=Fixture();local w,j,ack=Join(x);assert(w.Receive("host",ack))
            local previous=x.engine.Snapshot()
            local replica=Replica(x.s,x.h.guid,x.ad.id);assert(replica.Accept(x.h.guid,previous))
            local receiver=assert(RosterReceiver(x.s,x.h.guid,x.ad.id,previous.ad.revision,2,x.clock,x.resolve,replica))
            x.Advance()
            for _,p in ipairs(assert(x.engine.Receive("player",assert(receiver.Request(0))))) do assert(receiver.Receive("host",p)) end
            x.Advance()
            local otherJoin=table.concat({"M",P.Key(x.s),1,"J",x.ad.id},"|")
            assert(x.engine.Receive("other",otherJoin))
            assert(not x.engine.Receive("player",assert(receiver.Request(1))))
            assert(Equal(replica.Snapshot(),previous))
            x.Advance()
            local q=assert(w.Action("S"));local result=assert(x.engine.Receive("player",q))[1]
            local ok,_,rev=w.Receive("host",result);assert(ok and rev==previous.ad.revision+1)
            local fresh=assert(RosterReceiver(x.s,x.h.guid,x.ad.id,rev,3,x.clock,x.resolve,replica))
            for i=0,2 do
                x.Advance()
                for _,p in ipairs(assert(x.engine.Receive("player",assert(fresh.Request(i))))) do assert(fresh.Receive("host",p)) end
            end
            assert(Equal(replica.Snapshot(),x.engine.Snapshot()))
        end)
        Case(client.." full 32-player roster and exact checkpoint agreement",function()
            local x=Fixture()
            local d=T.DraftDefaults();d.name="Full Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.capacity=32
            d=assert(T.ValidateDraft(client,d,x.clock(),x.s.region,x.s.ruleset,x.s.faction))
            local e=assert(Host(x.s,x.h,x.clock));local ad=assert(e.Publish(x.h.guid,d))
            local actors={}
            for i=1,32 do
                local a=Copy(x.s);a.guid=string.format("Player-1-P%02d",i);a.name=string.rep("N",160);a.level=30
                actors[i]=a;assert(e.Join(ad.id,a.guid,a))
            end
            local cp=e.Save();assert(cp.ad.count==32)
            local replica=Replica(x.s,x.h.guid,ad.id)
            local receiver=assert(RosterReceiver(x.s,x.h.guid,ad.id,cp.ad.revision,4,x.clock,x.resolve,replica))
            for i=0,32 do
                local reply=assert(RosterReply(x.s,actors[1],cp,assert(receiver.Request(i))))
                for k=#reply,1,-1 do assert(#reply[k]+3<=240 and receiver.Receive("host",reply[k])) end
                if i<32 then assert(not replica.Snapshot()) end
            end
            assert(Equal(cp,replica.Snapshot()))
            assert(not CheckpointAgreement(x.s,x.h.guid,cp,{}))
            x.Advance(cp.ad.draft.startAt-1800-x.clock())
            assert(e.CheckIn(ad.id,actors[1].guid) and e.CheckIn(ad.id,actors[2].guid))
            cp=e.Save()
            assert(not CheckpointAgreement(x.s,x.h.guid,cp,{[actors[1].guid]=cp}))
            assert(CheckpointAgreement(x.s,x.h.guid,cp,{[actors[1].guid]=cp,[actors[2].guid]=cp}))
            local conflict=Copy(cp);conflict.roster[1].name="Changed"
            assert(not CheckpointAgreement(x.s,x.h.guid,cp,{[actors[1].guid]=cp,[actors[2].guid]=conflict}))
            assert(not CheckpointAgreement(x.s,x.h.guid,cp,{[actors[1].guid]=cp,[actors[2].guid]=cp,[actors[3].guid]=cp}))
        end)
        local function StartCompetition()
            local x=Fixture()
            local w,j,ack=Join(x);assert(w.Receive("host",ack))
            x.Advance()
            local function Req(seq,op) return table.concat({"M",P.Key(x.s),seq,op,x.ad.id},"|") end
            assert(x.engine.Receive("other",Req(1,"J")))
            assert(not x.engine.StartBracket(x.h.guid))
            x.Advance(x.ad.draft.startAt-1800-x.clock())
            local check=assert(w.Action("C"))
            assert(w.Receive("host",assert(x.engine.Receive("player",check))[1]))
            assert(x.engine.Receive("other",Req(2,"C")))
            x.Advance(1800)
            assert(not x.engine.StartBracket(x.a.guid))
            local stale=assert(x.Open())
            assert(x.engine.StartBracket(x.h.guid) and not x.engine.StartBracket(x.h.guid))
            assert(not stale.StartBracket(x.h.guid))
            local view=assert(x.engine.BracketSnapshot())
            local match
            for _,round in ipairs(view.rounds) do for _,m in ipairs(round) do if m.state=="ready" then match=m end end end
            assert(match and view.state=="running")
            return x,w,Req,match,stale
        end
        Case(client.." bracket start freezes roster through clock rollback and reopen",function()
            local x,w,Req,m,stale=StartCompetition()
            local before=x.engine.Snapshot()
            local frozen=x.engine.BracketSnapshot()
            x.Advance(-3600)
            -- Reopen resets transient pacing; test the actual frozen clock,
            -- not merely a refusal from a stale rate limiter.
            local recovered=assert(x.Open())
            assert(recovered.Receive("other",Req(3,"L")))
            assert(Equal(recovered.Snapshot(),before))
            assert(Equal(recovered.BracketSnapshot(),frozen))
            assert(not recovered.Publish(x.draft) and not recovered.StartBracket(x.h.guid))
            assert(not stale.BracketSnapshot())
        end)
        Case(client.." bracket reports persist atomically and cannot be forged by organizer",function()
            local x,w,Req,m=StartCompetition()
            local report={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="fixture-1"}
            assert(not x.engine.ReportBracket("host",report,1,x.h.guid))
            x.Advance()
            assert(x.engine.ReportBracket("player",report,1,x.h.guid))
            local old=assert(x.Open())
            assert(old.BracketSnapshot().state=="running")
            local first=old.BracketSnapshot()
            assert(Equal(first,x.engine.BracketSnapshot()))
            assert(old.ReportBracket("player",report,1,x.h.guid))
            assert(Equal(first,old.BracketSnapshot()))
            assert(old.ReportBracket("other",report,1,x.h.guid))
            assert(old.BracketSnapshot().champion==x.a.guid)
            assert(not x.engine.BracketSnapshot())
            local current=assert(x.Open());assert(current.BracketSnapshot().state=="completed")
            assert(not current.Publish(x.draft))
            x.Advance()
            local wrong=Copy(report);wrong.winner=x.other.guid
            assert(current.ReportBracket("player",wrong,1,x.h.guid))
            local disputed=assert(x.Open())
            assert(disputed.BracketSnapshot().state=="disputed" and not disputed.BracketSnapshot().champion)
            assert(disputed.Cancel(x.h.guid,x.ad.id))
            assert(not disputed.BracketSnapshot() and not x.Store("hostRoot").ReadTournamentJournal().commitment)
        end)
        Case(client.." corrupt or rewritten bracket journal cannot release ownership",function()
            local x,w,Req,m=StartCompetition()
            local store=x.Store("hostRoot");local old=assert(store.ReadTournamentJournal())
            local changed=Copy(old);changed.revision=changed.revision+1;changed.bracket=nil
            assert(not store.CommitTournamentJournal(old.revision,changed,"host_checkpoint"))
            assert(Equal(store.ReadTournamentJournal(),old))
            x.Advance()
            local report={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="fixture-1"}
            assert(x.engine.ReportBracket("player",report,1,x.h.guid))
            old=assert(store.ReadTournamentJournal())
            changed=Copy(old);changed.revision=changed.revision+1
            changed.bracket.reports[1].sender=x.h.guid
            assert(not store.CommitTournamentJournal(old.revision,changed,"bracket_report"))
            assert(Equal(store.ReadTournamentJournal(),old))
            x.hostRoot.clients[client].tournamentJournal.bracket.reports[1].sender=x.h.guid
            assert(not x.Open() and not x.engine.Publish(x.draft))
        end)
        Case(client.." creator offline before start retains control and cannot enter roster",function()
            local x=Fixture()
            local cp=x.engine.Snapshot()
            local owner=x.h.guid
            assert(not x.engine.ControlSnapshot())
            local states={[owner]="offline",[x.a.guid]="online"}
            assert(not x.engine.ReconcileControl(1,states,{}))
            assert(not x.engine.Cancel(x.a.guid,x.ad.id))
            assert(not x.engine.StartBracket(x.a.guid))
            assert(not x.engine.Receive("host",table.concat({"M",P.Key(x.s),1,"J",x.ad.id},"|")))
            assert(Equal(x.engine.Snapshot(),cp))
            assert(x.Store("hostRoot").ReadTournamentJournal().commitment.owner==owner)
        end)
        Case(client.." unknown connection pauses; exact replicas migrate only after start",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid
            local initial=assert(x.engine.ControlSnapshot())
            assert(initial.owner==owner and initial.coordinator==owner and initial.term==1 and not initial.paused)
            local cp=x.Store("hostRoot").ReadTournamentJournal().bracket
            local states={[owner]="unknown",[x.a.guid]="online",[x.other.guid]="online"}
            local copies={[x.a.guid]=cp,[x.other.guid]=cp}
            assert(x.engine.ReconcileControl(1,states,copies))
            assert(x.engine.ControlSnapshot().paused and x.engine.ControlSnapshot().term==2)
            assert(not x.engine.ReconcileControl(2,states,copies))
            states[owner]="offline"
            assert(not x.engine.ReconcileControl(2,states,{[x.a.guid]=cp}))
            local conflict=Copy(cp);conflict.startedAt=conflict.startedAt+1
            assert(not x.engine.ReconcileControl(2,states,{[x.a.guid]=cp,[x.other.guid]=conflict}))
            local old=assert(x.Open())
            assert(x.engine.ReconcileControl(2,states,copies))
            local next=assert(x.engine.ControlSnapshot())
            assert(next.term==3 and not next.paused and next.owner==owner and next.coordinator~=owner)
            assert(not old.ControlSnapshot() and not x.engine.ReconcileControl(2,states,copies))
            assert(not x.engine.Cancel(next.coordinator,x.ad.id))
            assert(not x.engine.Publish(x.draft))
            assert(Equal(assert(x.Open()).ControlSnapshot(),next))
        end)
        Case(client.." creator reconnect synchronizes and regains coordination",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid
            local saved=x.Store("hostRoot").ReadTournamentJournal().bracket
            local states={[owner]="offline",[x.a.guid]="online",[x.other.guid]="online"}
            local copies={[x.a.guid]=saved,[x.other.guid]=saved}
            assert(x.engine.ReconcileControl(1,states,copies))
            assert(x.engine.ReconcileControl(2,states,copies))
            local active=x.engine.ControlSnapshot()
            local report={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="migration-game"}
            assert(not x.engine.ReportBracket("player",report,1,owner))
            x.Advance()
            assert(x.engine.ReportBracket("player",report,active.term,active.coordinator))
            local latest=x.Store("hostRoot").ReadTournamentJournal().bracket
            states[owner]="online"
            assert(x.engine.ReconcileControl(3,states,copies))
            assert(x.engine.ControlSnapshot().paused)
            assert(not x.engine.ReportBracket("other",report,3,active.coordinator))
            assert(not x.engine.ReconcileControl(4,states,{[owner]=saved,[x.a.guid]=latest,[x.other.guid]=latest}))
            local recovered=assert(x.Open())
            assert(recovered.ReconcileControl(4,states,{[owner]=latest,[x.a.guid]=latest,[x.other.guid]=latest}))
            local current=recovered.ControlSnapshot()
            assert(current.owner==owner and current.coordinator==owner and current.term==5 and not current.paused)
            assert(not recovered.ReportBracket("other",report,3,active.coordinator))
            x.Advance()
            assert(recovered.ReportBracket("other",report,5,owner))
            assert(recovered.BracketSnapshot().champion==x.a.guid)
            assert(not x.engine.ControlSnapshot())
        end)
        Case(client.." everyone disconnected pauses; journal cannot erase control or reopen registration",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid
            local states={[owner]="offline",[x.a.guid]="offline",[x.other.guid]="offline"}
            assert(x.engine.ReconcileControl(1,states,{}))
            assert(not x.engine.ReconcileControl(2,states,{}))
            local store=x.Store("hostRoot");local old=assert(store.ReadTournamentJournal())
            local bad=Copy(old);bad.revision=bad.revision+1;bad.control=nil
            assert(not store.CommitTournamentJournal(old.revision,bad,"host_checkpoint"))
            bad=Copy(old);bad.revision=bad.revision+1;bad.control.term=1;bad.control.paused=false
            assert(not store.CommitTournamentJournal(old.revision,bad,"control_change"))
            assert(Equal(store.ReadTournamentJournal(),old))
            local reopened=assert(x.Open());assert(reopened.ControlSnapshot().paused)
            assert(not reopened.Publish(x.draft))
            assert(not reopened.Cancel(x.a.guid,x.ad.id))
            assert(reopened.Cancel(owner,x.ad.id))
            assert(not reopened.ControlSnapshot() and not reopened.BracketSnapshot())
        end)
        Case(client.." stale owner listing relayed as unconfirmed only; direct join confirms",function()
            local x=Fixture()
            local carrier=assert(Cache(x.s,x.clock));assert(carrier.Accept(x.h.guid,x.ad))
            x.Advance(121)
            assert(#carrier.Browse()==0)
            local hint=assert(carrier.Known(x.ad.id))
            assert(x.cache.AcceptHint(x.other,hint))
            assert(#x.cache.Browse()==0 and #x.cache.Hints()==1 and x.cache.Hints()[1].status=="unconfirmed")
            local w=assert(x.Player())
            assert(not w.Join(x.h.guid,x.ad.id))
            local request=assert(w.JoinPending(x.h.guid,x.ad.id))
            assert(w.Status().status=="pending" and not w.JoinPending(x.h.guid,x.ad.id))
            local relay=assert(Relay(x.s,carrier,x.clock,x.resolve))
            assert(relay.Queue("player",request) and relay.Queue("player",request))
            assert(#relay.Pending("other")==0 and #relay.Pending("host")==1)
            local p=relay.Pending("host")[1];assert(p.origin==x.a.guid and p.body==request)
            assert(not relay.Queue("player",table.concat({"M",P.Key(x.s),99,"J",x.ad.id},"|")))
            assert(not relay.Queue("host",request))
            assert(x.engine.Snapshot().ad.count==0)
            local recovered=assert(x.Player())
            assert(recovered.Retry()==request and recovered.Status().status=="pending")
            local ack=assert(x.engine.Receive("player",recovered.Retry()))[1]
            assert(not recovered.Receive("other",ack))
            assert(recovered.Receive("host",ack) and recovered.Status().status=="registered")
            assert(x.engine.Snapshot().ad.count==1)
        end)
        Case(client.." relay expiry and known owner cancellation cannot resurrect listing",function()
            local x=Fixture();local carrier=assert(Cache(x.s,x.clock))
            assert(carrier.Accept(x.h.guid,x.ad))
            local foreign=Copy(x.other);foreign.faction="Horde"
            assert(not x.cache.AcceptHint(foreign,x.ad))
            assert(x.cache.AcceptHint(x.other,x.ad))
            local w=assert(x.Player());local request=assert(w.JoinPending(x.h.guid,x.ad.id))
            local relay=assert(Relay(x.s,carrier,x.clock,x.resolve))
            assert(relay.Queue("player",request))
            assert(x.engine.Cancel(x.h.guid,x.ad.id))
            local terminal=x.engine.Snapshot().ad
            assert(x.cache.Accept(x.h.guid,terminal))
            assert(not x.cache.AcceptHint(x.other,x.ad) and #x.cache.Hints()==0)
            x.Advance(x.ad.draft.registrationClosesAt-x.clock())
            assert(#relay.Pending("host")==0 and not relay.Queue("player",request))
            assert(w.Status().status=="pending" and w.Retry()==request)
            local response=assert(x.engine.Receive("player",request))[1]
            assert(w.Receive("host",response) and not w.Status())
        end)
        Case(client.." frozen majority recovers with absent participant but not a minority",function()
            local x=Fixture();local e=assert(Host(x.s,x.h,x.clock));local ad=assert(e.Publish(x.h.guid,x.draft))
            local players={}
            for i=1,4 do
                local a=Copy(x.a);a.guid="Player-1-Q"..i;a.name="Q"..i;players[i]=a
                assert(e.Join(ad.id,a.guid,a))
            end
            x.Advance(ad.draft.startAt-1800-x.clock())
            for _,a in ipairs(players) do assert(e.CheckIn(ad.id,a.guid)) end
            x.Advance(1800)
            local engine=assert(ns.TournamentBracket.NewSimulated(x.s,x.h.guid,e.Save(),x.clock(),x.h.guid))
            local saved=engine.Save();local R=ns.TournamentRecovery
            local initial=R.InitialControl(saved)
            local states={[x.h.guid]="offline",[players[1].guid]="offline"}
            local copies={}
            for i=2,4 do states[players[i].guid]="online";copies[players[i].guid]=saved end
            local pause=assert(R.ReconcileControl(saved,initial,states,copies))
            assert(pause.paused and pause.term==2)
            local insufficient=Copy(copies);insufficient[players[4].guid]=nil
            assert(not R.ReconcileControl(saved,pause,states,insufficient))
            local conflicting=Copy(copies);conflicting[players[1].guid]=Copy(saved);conflicting[players[1].guid].startedAt=saved.startedAt+1
            assert(not R.ReconcileControl(saved,pause,states,conflicting))
            local next=assert(R.ReconcileControl(saved,pause,states,copies))
            assert(next.coordinator==players[2].guid and next.term==3 and not next.paused)
            states[x.h.guid]="online"
            local handback=assert(R.ReconcileControl(saved,next,states,copies))
            assert(handback.paused and not R.ReconcileControl(saved,handback,states,copies))
            copies[x.h.guid]=saved
            local owner=assert(R.ReconcileControl(saved,handback,states,copies))
            assert(owner.coordinator==x.h.guid and owner.term==5 and not owner.paused)
        end)
        Case(client.." progress replica rejects stale coordinator and rewritten confirmed progress",function()
            local x,w,Req,m=StartCompetition()
            local store=x.Store("hostRoot")
            local function Control()
                local j=store.ReadTournamentJournal()
                return x.engine.ControlSnapshot(),j and j.bracket
            end
            local replica=ProgressReplica(x.s,x.h.guid,x.ad.id,Control,x.resolve)
            local initial=store.ReadTournamentJournal().bracket
            assert(not replica.Accept("player",1,initial))
            assert(replica.Accept("host",1,initial))
            local report={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="progress-game"}
            x.Advance();assert(x.engine.ReportBracket("player",report,1,x.h.guid))
            local saved=store.ReadTournamentJournal().bracket
            assert(replica.Accept("host",1,saved) and not replica.Accept("host",1,initial))
            local bad=Copy(saved);bad.reports[1].winner=x.other.guid
            assert(not replica.Accept("host",1,bad))
            local states={[x.h.guid]="offline",[x.a.guid]="online",[x.other.guid]="online"}
            local copies={[x.a.guid]=saved,[x.other.guid]=saved}
            assert(x.engine.ReconcileControl(1,states,copies))
            assert(not replica.Accept("host",1,saved))
            assert(x.engine.ReconcileControl(2,states,copies))
            local c=Control();local sender=c.coordinator==x.a.guid and "player" or "other"
            assert(not replica.Accept("host",3,saved) and not replica.Accept(sender,1,saved))
            local invented=Copy(saved)
            local forged=Copy(report);forged.sender=x.other.guid
            invented.reports[#invented.reports+1]=forged
            assert(ns.TournamentBracket.OpenSimulated(x.s,x.h.guid,invented))
            assert(not replica.Accept(sender,3,invented))
            x.Advance();assert(x.engine.ReportBracket("other",report,3,c.coordinator))
            local final=store.ReadTournamentJournal().bracket
            assert(replica.Accept(sender,3,final))
            local copy,term=replica.Snapshot();assert(term==3 and Equal(copy,final))
            copy.reports[1].winner=x.other.guid
            assert(Equal(replica.Snapshot(),final))
        end)
        Case(client.." completion requires undisputed final and all checked-in matching copies",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid;local id=x.ad.id
            local store=x.Store("hostRoot")
            local saved=store.ReadTournamentJournal().bracket
            local copies={[x.a.guid]=saved,[x.other.guid]=saved}
            assert(not x.engine.Finalize(owner,id,1,copies))
            local report={event=id,match=m.id,game=1,winner=x.a.guid,evidence="final-game"}
            x.Advance();assert(x.engine.ReportBracket("player",report,1,owner))
            assert(x.engine.ReportBracket("other",report,1,owner))
            local final=store.ReadTournamentJournal().bracket
            local exact={[x.a.guid]=final,[x.other.guid]=final}
            assert(not x.engine.Finalize(owner,id,1,copies))
            assert(not x.engine.Finalize(owner,id,1,{[x.a.guid]=final}))
            assert(not x.engine.Finalize(x.a.guid,id,1,exact))
            assert(not x.engine.Finalize(owner,id,2,exact))
            assert(not x.engine.Finalize(owner,id.."x",1,exact))
            assert(not x.engine.Publish(x.draft))
            local old=assert(x.Open());assert(x.engine.Finalize(owner,id,1,exact))
            assert(not old.Finalize(owner,id,1,exact))
            local record=x.engine.Completed(id)
            assert(record.champion==x.a.guid and Equal(record.bracket,final))
            assert(x.engine.Snapshot().ad.state=="completed")
            assert(not store.ReadTournamentJournal().commitment and not x.engine.BracketSnapshot())
            assert(not x.engine.Cancel(owner,id) and not x.engine.ReportBracket("player",report,1,owner))
            assert(Equal(assert(x.Open()).Completed(id),record))
            record.champion=owner;assert(x.engine.Completed(id).champion==x.a.guid)
        end)
        Case(client.." completion acknowledgement releases pending commitment across new publication",function()
            local x,w,Req,m=StartCompetition()
            local owner,id=x.h.guid,x.ad.id
            local store=x.Store("hostRoot")
            local report={event=id,match=m.id,game=1,winner=x.other.guid,evidence="terminal-game"}
            x.Advance();assert(x.engine.ReportBracket("player",report,1,owner))
            assert(x.engine.ReportBracket("other",report,1,owner))
            local final=store.ReadTournamentJournal().bracket
            local copies={[x.a.guid]=final,[x.other.guid]=final}
            assert(x.engine.Finalize(owner,id,1,copies))
            local request=assert(w.Action("S"))
            x.Advance()
            local ack=assert(x.engine.Receive("player",request))[1]
            assert(ack:sub(1,2)=="Y|" and w.Status().status=="checked")
            local d=T.DraftDefaults();d.name="Next Cup";d.location="Meeting place";d.startUTC="2026-11-26 18:00";d.capacity=4
            d=assert(T.ValidateDraft(client,d,x.clock(),x.s.region,x.s.ruleset,x.s.faction))
            local next=assert(x.engine.Publish(d))
            assert(next.id~=id and next.serial==x.ad.serial+1)
            local reopened=assert(x.Open());local recovered=assert(x.Player())
            assert(recovered.Retry()==request and not recovered.Receive("other",ack))
            assert(assert(reopened.Receive("player",request))[1]==ack)
            local ok,why=recovered.Receive("host",ack)
            assert(ok and why=="completed" and not recovered.Status())
            assert(not recovered.Receive("host",ack))
            x.Advance()
            for _,p in ipairs(assert(reopened.Receive("player",assert(recovered.Query(owner))))) do assert(recovered.Receive("host",p)) end
            assert(#x.cache.Browse()==1 and x.cache.Browse()[1].id==next.id)
            assert(recovered.Join(owner,next.id))
            assert(reopened.Completed(id).champion==x.other.guid)
        end)
        Case(client.." organizer hold blocks stale progress; dispute cannot finalize",function()
            local x,w,Req,m=StartCompetition()
            local owner,id=x.h.guid,x.ad.id
            local store=x.Store("hostRoot")
            local initial=store.ReadTournamentJournal().bracket
            local copies={[x.a.guid]=initial,[x.other.guid]=initial,[owner]=initial}
            assert(not x.engine.Hold(x.a.guid,id,1))
            assert(x.engine.Hold(owner,id,1) and not x.engine.Hold(owner,id,1))
            local report={event=id,match=m.id,game=1,winner=x.a.guid,evidence="held-game"}
            assert(not x.engine.ReportBracket("player",report,1,owner))
            assert(not x.engine.ReportBracket("player",report,2,owner))
            assert(x.engine.ReconcileControl(2,{[owner]="online",[x.a.guid]="online",[x.other.guid]="online"},copies))
            assert(x.engine.ControlSnapshot().term==3)
            x.Advance();assert(x.engine.ReportBracket("player",report,3,owner))
            local other=Copy(report);other.winner=x.other.guid
            assert(x.engine.ReportBracket("other",other,3,owner))
            local disputed=store.ReadTournamentJournal().bracket
            assert(x.engine.BracketSnapshot().state=="disputed")
            assert(not x.engine.Finalize(owner,id,3,{[x.a.guid]=disputed,[x.other.guid]=disputed}))
            assert(not x.engine.Publish(x.draft))
            assert(store.ReadTournamentJournal().commitment.id==id)
        end)
        Case(client.." completed history cannot be erased or falsified by later journal edits",function()
            local x,w,Req,m=StartCompetition()
            local owner,id=x.h.guid,x.ad.id
            local store=x.Store("hostRoot")
            local report={event=id,match=m.id,game=1,winner=x.a.guid,evidence="archive-game"}
            x.Advance();assert(x.engine.ReportBracket("player",report,1,owner))
            assert(x.engine.ReportBracket("other",report,1,owner))
            local final=store.ReadTournamentJournal().bracket
            assert(x.engine.Finalize(owner,id,1,{[x.a.guid]=final,[x.other.guid]=final}))
            local old=assert(store.ReadTournamentJournal())
            local bad=Copy(old);bad.revision=bad.revision+1;bad.completed=nil
            assert(not store.CommitTournamentJournal(old.revision,bad,"host_checkpoint"))
            bad=Copy(old);bad.revision=bad.revision+1;bad.completed[id].champion=x.other.guid
            assert(not store.CommitTournamentJournal(old.revision,bad,"host_checkpoint"))
            bad=Copy(old);bad.revision=bad.revision+1;bad.completed[id].term=2
            assert(not store.CommitTournamentJournal(old.revision,bad,"host_checkpoint"))
            assert(Equal(store.ReadTournamentJournal(),old))
            x.hostRoot.clients[client].tournamentJournal.completed[id].champion=owner
            assert(not x.Open() and not x.engine.Completed(id))
        end)
        Case(client.." five minute observed grace resets on reconnect unknown and gaps",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid
            local states={[x.a.guid]="online",[x.other.guid]="offline"}
            local function Observe()return assert(x.engine.ObserveMatch(m.id,states,1,owner))end
            local v=Observe();assert(v.remaining==300 and v.notice=="started")
            x.Advance(10);v=Observe();assert(v.remaining==290 and not v.notice)
            assert(not x.engine.ObserveMatch(m.id,{},1,owner))
            assert(Observe().remaining==300)
            states[x.other.guid]="online";v=Observe();assert(v.notice=="reconnected")
            states[x.other.guid]="offline";v=Observe();assert(v.remaining==300 and v.notice=="started")
            x.Advance(16);assert(Observe().remaining==300)
            states[x.a.guid]="unknown";v=Observe();assert(not v.remaining and v.notice=="interrupted")
            states[x.a.guid]="offline";assert(not Observe().remaining)
            states[x.a.guid]="online";assert(Observe().remaining==300)
            for i=1,29 do x.Advance(10);v=Observe();assert(v.remaining==300-i*10 and not v.notice) end
            x.Advance(9);assert(Observe().remaining==1)
            x.Advance();assert(not x.engine.ObserveMatch(m.id,states,2,owner))
            assert(not x.engine.ObserveMatch(m.id,states,1,x.other.guid))
            v=Observe();assert(v.remaining==0 and v.notice=="forfeited")
            assert(x.engine.BracketSnapshot().champion==x.a.guid)
            assert(not x.engine.ObserveMatch(m.id,states,1,owner))
            assert(Equal(assert(x.Open()).BracketSnapshot(),x.engine.BracketSnapshot()))
            local saved=x.Store("hostRoot").ReadTournamentJournal().bracket
            assert(not x.engine.Finalize(owner,x.ad.id,1,{}))
            local conflict=Copy(saved);conflict.startedAt=conflict.startedAt+1
            assert(not x.engine.Finalize(owner,x.ad.id,1,{[x.a.guid]=saved,[x.other.guid]=conflict}))
            assert(x.engine.Finalize(owner,x.ad.id,1,{[x.a.guid]=saved}))
            assert(x.engine.Completed(x.ad.id).champion==x.a.guid)
        end)
        Case(client.." reopen resets unverified absence and withdrawal preserves outcome",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid;local states={[x.a.guid]="online",[x.other.guid]="offline"}
            assert(x.engine.ObserveMatch(m.id,states,1,owner).remaining==300)
            x.Advance(10)
            local reopened=assert(x.Open())
            assert(reopened.ObserveMatch(m.id,states,1,owner).remaining==300)
            local q={event=x.ad.id,match=m.id}
            assert(not reopened.WithdrawBracket("host",q,1,owner))
            assert(not reopened.WithdrawBracket("other",q,2,owner))
            assert(reopened.WithdrawBracket("other",q,1,owner))
            assert(reopened.BracketSnapshot().champion==x.a.guid)
            assert(not x.engine.BracketSnapshot())
        end)
        Case(client.." rate limit and corrupt checkpoint cannot emit mutation acknowledgement",function()
            local x=Fixture();local w=assert(x.Player());local q=assert(w.Query(x.h.guid))
            assert(x.engine.Receive("player",q) and x.engine.Receive("player",q) and not x.engine.Receive("player",q))
            x.Advance()
            for _,p in ipairs(assert(x.engine.Receive("player",q))) do assert(w.Receive("host",p)) end
            x.Advance()
            local j=assert(w.Join(x.h.guid,x.ad.id))
            local saved=x.hostRoot
            x.hostRoot.clients[client].tournamentJournal.checkpoint.host.ad.count=1
            assert(not x.engine.Receive("player",j) and x.hostRoot==saved and not x.Open())
        end)
    end
    return pass,fail
end

local preview
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...);if not ok then return nil end
    if type(issecretvalue)=="function" then local good,secret=pcall(issecretvalue,v);if not good or secret then return nil end end
    return v
end
local function Current()
    if preview and P.Key(P.GetCurrent())~=preview.key then preview=nil end
    return preview
end
function R.PreviewState()
    local x=Current();if not x then return nil end
    if x.role=="host" then return "hosting" end
    return x.joined and "registered" or "preview-browse"
end
function R.CanCreatePreview() return Current()==nil end
function R.StartPreview(d)
    if not R.CanCreatePreview() then return false,"End the current test first." end
    local s=P.GetCurrent();local n=Read(GetServerTime);local level=Read(UnitLevel,"player")
    if not P.Key(s) or not Whole(n,1,4102444800) or not Whole(level,1,255) then return false,"Character or time unavailable." end
    local h,a=Copy(s),Copy(s)
    h.guid,h.name="Player-0-TESTHOST","Local test organizer"
    a.guid,a.name,a.level="Player-0-TESTPLAYER","You (local test)",level
    local x={key=P.Key(s),now=n,role="host",host=h,player=a}
    local clock=function()return x.now end
    x.engine=Host(s,h,clock);x.cache=Cache(s,clock)
    local ad,why=x.engine.Publish(h.guid,d)
    if not ad then return false,why end
    x.id=ad.id;preview=x;return true,"Local test created. Nothing sent to other players."
end
function R.EndPreview() preview=nil end
function R.PreviewSnapshot()
    local x=Current();if not x then return nil end
    local ad=x.engine.Ad();x.cache.Accept(x.host.guid,ad)
    local rows=x.engine.Roster(x.host.guid);local member
    for _,r in ipairs(rows) do if r.guid==x.player.guid then member=r end end
    return {scope="SIMULATED",role=x.role,state=R.PreviewState(),event=ad,events=x.cache.Browse(),roster=x.role=="host" and rows or nil,member=member,now=x.now}
end
function R.PreviewAction(action)
    local x=Current();if not x then return false,"No local test tournament." end
    if action=="host" or action=="player" then x.role=action;return true end
    if action=="cancel" and x.role=="host" then local ok,why=x.engine.Cancel(x.id,x.host.guid);if ok then R.EndPreview() end;return ok,why end
    if x.role~="player" then return false,"Switch to player preview first." end
    if action=="checkin-time" and x.joined then x.now=math.max(x.now,x.engine.Ad().draft.startAt-1800);return true,"Local test clock advanced." end
    if action=="join" then local ok,why=x.engine.Join(x.id,x.player.guid,x.player);if ok then x.joined=true end;return ok,why end
    if action=="leave" then local ok,why=x.engine.Leave(x.id,x.player.guid);if ok then x.joined=false end;return ok,why end
    if action=="checkin" then return x.engine.CheckIn(x.id,x.player.guid) end
    return false,"Action unavailable."
end
function R.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400
            local function A(id) local a=Copy(s);a.guid="Player-1-"..id;a.name="Test "..id;a.level=30;return a end
            local h=A("HOST");local clock=function()return n end
            local d=T.DraftDefaults();d.name="Test Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.capacity=4;d.minLevel="20";d.maxLevel="40"
            d=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            local e=assert(Host(s,h,clock));local ad=assert(e.Publish(h.guid,d))
            return {s=s,h=h,d=d,e=e,ad=ad,a=A,c=assert(Cache(s,clock)),time=function(v)n=v end}
        end
        Case(client.." publication and organizer authority",function()
            local x=Fixture();local ad=x.e.Ad();assert(ad.count==0 and not x.e.Publish(x.h.guid,x.d) and not x.e.Publish("Player-1-X",x.d))
            ad.draft.name="changed";assert(x.e.Ad().draft.name=="Test Cup" and not x.e.Roster("Player-1-X"))
        end)
        Case(client.." one active tournament survives scheduled start",function()
            local x=Fixture();local a=x.e.Ad();x.time(x.d.startAt+1)
            local nextDraft=T.DraftDefaults()
            nextDraft.name="Next Cup";nextDraft.location="Meeting place";nextDraft.startUTC="2026-11-26 18:00"
            nextDraft=assert(T.ValidateDraft(client,nextDraft,x.d.startAt+1,x.s.region,x.s.ruleset,x.s.faction))
            assert(not x.e.Publish(x.h.guid,nextDraft))
            assert(Equal(x.e.Ad(),a))
            assert(not x.e.Cancel(a.id,"Player-1-X"))
            assert(not x.e.Publish(x.h.guid,nextDraft))
            assert(x.e.Cancel(a.id,x.h.guid))
            local nextEvent=assert(x.e.Publish(x.h.guid,nextDraft))
            assert(nextEvent.id~=a.id and nextEvent.state=="open")
            assert(BlocksCreation({state="running"}) and BlocksCreation({state="paused"}))
            assert(not BlocksCreation({state="completed"}) and not BlocksCreation({state="cancelled"}))
        end)
        Case(client.." discovery refuses a second active event from the same owner",function()
            local x=Fixture();assert(x.c.Accept(x.h.guid,x.ad))
            local other=Copy(x.ad);other.serial=2;other.id=ID(x.h.guid,other.publishedAt,2)
            assert(not x.c.Accept(x.h.guid,other) and #x.c.Browse()==1)
            x.time(x.d.startAt+1);assert(#x.c.Browse()==0)
            local d=T.DraftDefaults();d.name="Next Cup";d.location="Meeting place";d.startUTC="2026-11-26 18:00"
            other.draft=assert(T.ValidateDraft(client,d,x.d.startAt+1,x.s.region,x.s.ruleset,x.s.faction))
            other.publishedAt=x.d.startAt+1;other.id=ID(x.h.guid,other.publishedAt,2)
            assert(not x.c.Accept(x.h.guid,other))
            assert(x.e.Cancel(x.ad.id,x.h.guid))
            assert(x.c.Accept(x.h.guid,x.e.Ad()))
            assert(x.c.Accept(x.h.guid,other) and #x.c.Browse()==1)
        end)
        Case(client.." strict sender and population admission",function()
            local x=Fixture();local a=x.a("A");assert(not x.e.Join(x.ad.id,"Player-1-B",a))
            for _,field in ipairs({"client","region","ruleset","faction"}) do local z=Copy(a);z[field]="wrong";assert(not x.e.Join(x.ad.id,z.guid,z)) end
            assert(x.e.Ad().count==0)
        end)
        Case(client.." level, capacity, duplicate and leave",function()
            local x=Fixture();local a=x.a("A");a.level=10;assert(not x.e.Join(x.ad.id,a.guid,a));a.level=30
            assert(x.e.Join(x.ad.id,a.guid,a));local rev=x.e.Ad().revision
            assert(x.e.Join(x.ad.id,a.guid,a) and x.e.Ad().revision==rev)
            for i=1,3 do local b=x.a("B"..i);assert(x.e.Join(x.ad.id,b.guid,b)) end
            local b=x.a("EXTRA");assert(not x.e.Join(x.ad.id,b.guid,b))
            assert(x.e.Leave(x.ad.id,a.guid) and x.e.Join(x.ad.id,b.guid,b) and x.e.Ad().count==4)
        end)
        Case(client.." registration cutoff and check-in",function()
            local x=Fixture();local a,b=x.a("A"),x.a("B")
            assert(x.e.Join(x.ad.id,a.guid,a) and not x.e.CheckIn(x.ad.id,a.guid))
            x.time(x.d.startAt-1800);assert(x.e.CheckIn(x.ad.id,a.guid) and x.e.Roster(x.h.guid)[1].checkedIn)
            x.time(x.d.registrationClosesAt);assert(not x.e.Join(x.ad.id,b.guid,b))
            x.time(x.d.startAt);assert(not x.e.CheckIn(x.ad.id,a.guid) and not x.e.Leave(x.ad.id,a.guid))
        end)
        Case(client.." discovery exact scope and cancellation",function()
            local x=Fixture();assert(not x.c.Accept("Player-1-X",x.ad))
            for _,field in ipairs({"client","region","ruleset","faction"}) do local z=Copy(x.ad);z[field]="wrong";assert(not x.c.Accept(x.h.guid,z)) end
            assert(#x.c.Browse()==0 and x.c.Accept(x.h.guid,x.ad) and #x.c.Browse()==1)
            local z=Copy(x.ad);z.count=1;assert(not x.c.Accept(x.h.guid,z))
            assert(not x.e.Cancel(x.ad.id,"Player-1-X") and x.e.Cancel(x.ad.id,x.h.guid))
            assert(x.c.Accept(x.h.guid,x.e.Ad()) and #x.c.Browse()==0 and not x.c.Accept(x.h.guid,x.ad))
        end)
        Case(client.." discovery expiry and immutable rules",function()
            local x=Fixture();assert(x.c.Accept(x.h.guid,x.ad))
            x.time(x.ad.publishedAt+121);assert(#x.c.Browse()==0 and x.c.Accept(x.h.guid,x.ad) and #x.c.Browse()==1)
            local z=Copy(x.ad);z.revision=2;z.draft.name="Changed";assert(not x.c.Accept(x.h.guid,z))
            x.time(x.d.registrationClosesAt);assert(#x.c.Browse()==0)
        end)
    end
    Case("live publication remains disabled",function()local s=T.GetSnapshot();assert(not s.discovery and not s.hosting and s.state=="idle")end)
    return p,f
end
if ns.Diagnostics then
ns.Diagnostics.Register("Tournament host recovery / isolated checkpoint QA","deep",function()
    local log={};local p,f=R.RunHostRecoverySelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==54 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament recovery / isolated journal QA","deep",function()
    local log={};local p,f=R.RunRecoverySelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==10 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament exchange / isolated wire QA","deep",function()
    local log={};local p,f=R.RunExchangeSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==10 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament registration / isolated host QA","deep",function()
    local log={};local p,f=R.RunSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==17 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end) end

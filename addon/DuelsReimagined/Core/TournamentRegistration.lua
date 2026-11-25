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
        if not nextLock then candidate.privateSeat=nil end
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
        if not commitment or commitment.status=="pending" or (op~="L" and op~="C" and op~="S")
            or (journal and journal.privateSeat and op~="S") then return nil end
        return Begin(commitment.owner,op,commitment.id)
    end
    function D.Retry()
        Expire()
        if Fresh() then return pending and pending.body end
    end
    function D.Status() return Copy(commitment) end
    function D.PendingOwner() Expire();return pending and pending.owner end
    function D.PrivateSeat()
        if journal and Fresh() then return Copy(journal.privateSeat) end
    end
    local function SaveSeat(seat,action)
        Expire()
        if not journal or not store or (pending and not (action=="seat_report" and pending.op=="S")) or not Fresh() then return false end
        local next=Copy(journal);next.revision=next.revision+1;next.privateSeat=seat
        local saved=store.CommitTournamentJournal(journal.revision,next,action)
        if not saved then return false end
        journal=saved;return true
    end
    function D.ArmPrivateSeat(seat)
        if not journal or journal.privateSeat or not commitment or commitment.status~="checked"
            or type(seat)~="table" or seat.phase~="armed" then return false end
        return SaveSeat(Copy(seat),"seat_arm")
    end
    function D.RecordPrivateSeat(winner)
        local seat=D.PrivateSeat()
        if not seat or seat.phase~="armed" then return false end
        seat.phase="reported";seat.winner=winner
        return SaveSeat(seat,"seat_report")
    end
    function D.ClearPrivateSeat()
        if not D.PrivateSeat() then return false end
        return SaveSeat(nil,"seat_clear")
    end
    function D.ReserveProgress()
        Expire()
        if not Fresh() or pending or not commitment or commitment.status=="pending" or seq>=2147483647 then return nil end
        if not Persist(seq+1,commitment,nil,"query") then return nil end
        seq=seq+1;return seq,Copy(commitment)
    end
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
-- Private owner-reported progress. This is not an independently certified
-- replica or authority-transfer protocol. Each page is pinned to one log
-- revision and controller term; the client only commits a complete replay.
local function EncodeProgressReport(r)
    if r.kind=="offline" then
        return table.concat({"O",r.match,r.revision,r.loser,r.since,r.at},"|")
    elseif r.kind=="withdraw" then
        return table.concat({"W",r.match,r.sender},"|")
    elseif r.kind=="replay" then
        return table.concat({"E",r.match,r.sender,r.game,r.revision},"|")
    end
    return table.concat({"R",r.match,r.sender,r.game,r.winner,r.evidence,r.attempt or 0},"|")
end
local function DecodeProgressReport(id,body)
    local a=Split(body);local r={event=id,match=a[2]}
    if type(r.match)~="string" or not r.match:match("^R%d+M%d+$") or #r.match>8 then return nil end
    if a[1]=="O" and #a==6 then
        r.kind="offline";r.revision=Number(a[3],0,497);r.loser=a[4]
        r.since=Number(a[5],1,4102444500);r.at=Number(a[6],1,4102444800)
        if not r.revision or not Guid(r.loser) or not r.since or not r.at then return nil end
    elseif a[1]=="W" and #a==3 then
        r.kind="withdraw";r.sender=a[3];if not Guid(r.sender) then return nil end
    elseif a[1]=="E" and #a==5 then
        r.kind="replay";r.sender=a[3];r.game=Number(a[4],1,5);r.revision=Number(a[5],1,497)
        if not Guid(r.sender) or not r.game or not r.revision then return nil end
    elseif a[1]=="R" and #a==7 then
        r.sender=a[3];r.game=Number(a[4],1,5);r.winner=a[5];r.evidence=a[6]
        local attempt=Number(a[7],0,1);r.attempt=attempt==1 and 1 or nil
        if not Guid(r.sender) or not r.game or not Guid(r.winner) or not attempt
            or #r.evidence<1 or #r.evidence>96 or not r.evidence:match("^[%w%-_:]+$") then return nil end
    else return nil end
    if EncodeProgressReport(r)==body then return r end
end
local function ProgressPage(s,actor,saved,c,finishedAt,body)
    local a=Split(body);local ad=saved.checkpoint.ad
    local nonce=Number(a[3],1,2147483647);local revision=Number(a[5],0,497)
    local term=Number(a[6],0,2147483647);local page=Number(a[7],0,529)
    if #a~=7 or a[1]~="V" or a[2]~=P.Key(s) or not nonce or a[4]~=ad.id
        or not revision or not term or not page or c.coordinator~=ad.owner then return nil end
    local member
    for _,m in ipairs(saved.checkpoint.roster) do if m.guid==actor.guid then member=true;break end end
    if not member then return nil end
    local count=#saved.reports
    local payload
    if page==0 then
        if revision~=0 or term~=0 then return nil end
        payload=table.concat({ad.id,saved.startedAt,count,c.term,c.coordinator,c.paused and 1 or 0,finishedAt or 0,EncodeAd(ad)},"|")
    else
        if revision~=count or term~=c.term or page>ad.count+count then return nil end
        if page<=ad.count then
            local row=saved.checkpoint.roster[page]
            payload=table.concat({row.guid,row.name,row.level,row.checkedIn and 1 or 0},"|")
        else payload=EncodeProgressReport(saved.reports[page-ad.count]) end
    end
    local encoded=Hex(payload);local total=math.ceil(#encoded/CHUNK)
    if total<1 or total>MAX_PARTS then return nil end
    local out={}
    for i=1,total do
        out[i]=table.concat({"Z",P.Key(s),nonce,page,i,total,encoded:sub((i-1)*CHUNK+1,i*CHUNK)},"|")
        if not Packet(out[i]) then return nil end
    end
    return out
end
function R.OpenPrivateProgressEcho(s,actor,progress,nonce)
    if not Actor(s,actor) or not progress or progress.scope~="PRIVATE_TEST" or progress.finishedAt
        or not Whole(nonce,1,2147483647) or not progress.saved or not progress.control
        or not (progress.control.paused or progress.bracket and progress.bracket.state=="completed") then return nil end
    local saved,c=progress.saved,progress.control
    local b=ns.TournamentBracket.OpenSimulated(s,c.owner,saved)
    if not b or c.coordinator~=c.owner then return nil end
    local page,index,parts=0,1,nil
    local D={}
    function D.Next()
        if page>saved.checkpoint.ad.count+#saved.reports then return nil end
        if not parts then
            local q=table.concat({"V",P.Key(s),nonce,c.event,page==0 and 0 or #saved.reports,page==0 and 0 or c.term,page},"|")
            parts=ProgressPage(s,actor,saved,c,nil,q)
            if not parts then return nil end
        end
        local body=parts[index]
        index=index+1
        if index>#parts then page=page+1;index=1;parts=nil end
        return body,page>saved.checkpoint.ad.count+#saved.reports
    end
    return D
end
function R.PrivateEchoReceipt(s,nonce,term,revision,body)
    return Packet(body) and body==table.concat({"H",P.Key(s),nonce,term,revision},"|")
end
function R.OpenPrivateProgressFetch(s,owner,id,me,nonce,clock,resolve,prior)
    if not P.Key(s) or not Guid(owner) or not Guid(me) or me==owner or type(id)~="string" or #id>96
        or not Whole(nonce,1,2147483647) or type(clock)~="function" or type(resolve)~="function" then return nil end
    local D,page,pending,header,rows,reports,complete,dead={},0,nil,nil,{},{},nil,false
    function D.Request()
        local n=Now(clock)
        if dead or complete or not n or (pending and n<pending.deadline) then return nil end
        pending={deadline=n+30,parts={},count=0}
        local packet=table.concat({"V",P.Key(s),nonce,id,header and header.count or 0,header and header.term or 0,page},"|")
        return Packet(packet) and packet or nil
    end
    function D.Receive(sender,body)
        local n=Now(clock)
        if dead or complete or not pending or not n or n>=pending.deadline or not Packet(body) then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or actor.guid~=owner then return false end
        local a=Split(body);local i,total=Number(a[5],1,MAX_PARTS),Number(a[6],1,MAX_PARTS)
        if #a~=7 or a[1]~="Z" or a[2]~=P.Key(s) or Number(a[3],1,2147483647)~=nonce
            or Number(a[4],0,529)~=page or not i or not total or i>total or #a[7]<2 or #a[7]>CHUNK
            or (i<total and #a[7]~=CHUNK) or not Unhex(a[7]) then return false end
        if (pending.total and pending.total~=total) or (pending.parts[i] and pending.parts[i]~=a[7]) then dead=true;return false end
        pending.total=total
        if not pending.parts[i] then pending.parts[i]=a[7];pending.count=pending.count+1 end
        if pending.count<total then return true,"partial" end
        local payload=Unhex(table.concat(pending.parts));pending=nil
        local fields=Split(payload)
        if page==0 then
            local started=Number(fields[2],1,4102444800);local count=Number(fields[3],0,497)
            local term=Number(fields[4],1,2147483647);local finished=Number(fields[7],0,4102444800)
            local ad=DecodeAd(s,owner,table.concat(fields,"|",8))
            if #fields~=22 or fields[1]~=id or not started or started>n or not count or not term
                or fields[5]~=owner or (fields[6]~="0" and fields[6]~="1") or not finished
                or (finished~=0 and (finished<started or finished>n or fields[6]=="1"))
                or not ad or ad.id~=id or ad.state~="open" or ad.count<2
                or (prior and (term<prior.control.term or count<#prior.saved.reports
                    or not Equal(ad,prior.saved.checkpoint.ad) or started~=prior.saved.startedAt
                    or (prior.finishedAt and finished~=prior.finishedAt))) then dead=true;return false end
            header={ad=ad,started=started,count=count,term=term,paused=fields[6]=="1",finished=finished}
        elseif page<=header.ad.count then
            local level=Number(fields[3],1,255)
            if #fields~=4 or not Guid(fields[1]) or not Name(fields[2]) or not level
                or (fields[4]~="0" and fields[4]~="1") then dead=true;return false end
            rows[page]={guid=fields[1],name=fields[2],level=level,checkedIn=fields[4]=="1"}
        else
            local r=DecodeProgressReport(id,payload)
            if not r then dead=true;return false end
            reports[page-header.ad.count]=r
        end
        if page==header.ad.count+header.count then
            local saved={scope="SIMULATED",version=1,checkpoint={ad=header.ad,roster=rows},startedAt=header.started,reports=reports}
            local b=ns.TournamentBracket.OpenSimulated(s,owner,saved)
            local member
            for _,m in ipairs(rows) do if m.guid==me then member=true;break end end
            if not b or not member or (header.finished~=0 and b.Snapshot().state~="completed") then dead=true;return false end
            if prior then
                if not Equal(prior.saved.checkpoint,saved.checkpoint) then dead=true;return false end
                for j,r in ipairs(prior.saved.reports) do if not Equal(r,reports[j]) then dead=true;return false end end
                if prior.control.term==header.term and prior.control.paused~=header.paused then dead=true;return false end
            end
            complete={scope="PRIVATE_TEST",source="organizer-reported",saved=b.Save(),bracket=b.Snapshot(),
                control={owner=owner,event=id,coordinator=owner,term=header.term,paused=header.paused},
                finishedAt=header.finished~=0 and header.finished or nil}
            return true,"complete"
        end
        page=page+1
        return true,"page"
    end
    function D.Snapshot() return Copy(complete) end
    function D.IsFailed() return dead end
    return D
end
-- Shared observation policy. The caller supplies verified observations in
-- its own scope and owns atomic result persistence. Unknown never means offline.
local function ObserveGrace(observed,view,match,states,term,now,commit)
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
        local ok=commit({kind="offline",event=view.event,match=match,revision=view.revision,loser=loser,since=old.since,at=now})
        if not ok then return nil end
        observed[match]=nil;out.notice="forfeited"
    end
    return out
end
local function DurableHost(s,h,clock,resolve,store)
    local D={}
    local assignments={}
    local function CloseMatch(id)
        local a=assignments[id]
        if a then assignments[id]=nil;a.Close() end
    end
    local function CloseAssignments()
        for id in pairs(assignments) do CloseMatch(id) end
    end
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
            candidate.bracket=nil;candidate.control=nil;candidate.privateAssignment=nil
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
        if a[1]=="V" then
            local current=journal.bracket
            if current and current.checkpoint.ad.id==a[4] then
                return ProgressPage(s,actor,current,journal.control,nil,body)
            end
            local record=journal.completed and journal.completed[a[4]]
            if record then
                return ProgressPage(s,actor,record.bracket,{term=record.term,coordinator=h.guid,paused=false},record.finishedAt,body)
            end
            return nil
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
        local ok=Save(e,w,"host_cancel");if ok then CloseAssignments() end;return ok
    end
    -- Bracket changes use the same character-owned journal and CAS. No
    -- separate database, no live result intake, no actual tournament release.
    local function SaveBracket(engine,action)
        if not Fresh() then return false end
        local candidate=Copy(journal)
        candidate.revision=candidate.revision+1
        candidate.bracket=engine.Save()
        if action=="bracket_start" then candidate.control=ns.TournamentRecovery.InitialControl(candidate.bracket) end
        if candidate.privateAssignment and not ns.TournamentRecovery.PrivateAssignment(engine.Snapshot(),candidate.control,candidate.privateAssignment,candidate.revision) then
            candidate.privateAssignment=nil
        end
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
        if why=="disputed" then CloseAssignments()
        elseif why=="confirmed" then CloseMatch(report.match) end
        return true,why
    end
    -- One transient observer per ready match; at most 31 match IDs.
    -- The caller supplies verified fixture observations, not remote claims.
    -- No timers, live presence subscriptions or notification side effects.
    function D.ObserveMatch(match,states,term,coordinator)
        local c=journal.control;local now=Now(clock)
        if not Fresh() or not c or c.paused or c.term~=term or c.coordinator~=coordinator or not now then return nil end
        local b=OpenBracket();local view=b and b.Snapshot()
        return ObserveGrace(observed,view,match,states,term,now,function(record)
            local ok=b.ForfeitOffline(record)
            if not ok or not SaveBracket(b,"bracket_report") then return false end
            CloseMatch(match);return true
        end)
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
        CloseMatch(request.match)
        return true,why
    end
    function D.ConsentReplay(sender,request,term,coordinator)
        local c=journal.control
        if not Fresh() or not c or c.paused or c.term~=term or c.coordinator~=coordinator then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or not Permit(actor) then return false end
        local b=OpenBracket();if not b then return false end
        local ok,why=b.ConsentReplay(actor.guid,request)
        if not ok then return false end
        if why=="duplicate" then return true,why end
        if not SaveBracket(b,"bracket_report") then return false end
        observed[request.match]=nil
        return true,why
    end
    -- No permanent detector connection: one fixture adapter for each
    -- assigned ready match. The existing host is the only writer.
    function D.AssignMatch(sender,match,token,term)
        if not Fresh() or not journal.control or journal.control.paused or journal.control.term~=term
            or type(match)~="string" then return nil end
        local actor=resolve(sender)
        if not Actor(s,actor) or actor.guid~=journal.control.coordinator then return nil end
        local existing=assignments[match]
        if existing and existing.IsActive() then return nil end
        local domain=ns.TournamentGameplay
        if not domain then return nil end
        local adapter=domain.NewSimulated(s,match,token,function()return D.BracketSnapshot(),D.ControlSnapshot()end,
            resolve,D.ReportBracket)
        if adapter then assignments[match]=adapter end
        return adapter
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
        local candidate=Copy(journal);candidate.revision=candidate.revision+1;candidate.control=c;candidate.privateAssignment=nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"control_change")
        if not saved then return false end
        journal=saved;CloseAssignments();return true
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
        candidate.bracket=nil;candidate.control=nil;candidate.commitment=nil;candidate.privateAssignment=nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"host_complete")
        if not saved then return false end
        journal=saved;CloseAssignments();return true
    end
    function D.Completed(id)
        if Fresh() and journal.completed then return Copy(journal.completed[id]) end
    end
    local function SavePrivateAssignment(a,action)
        if not Fresh() then return false end
        local candidate=Copy(journal);candidate.revision=candidate.revision+1;candidate.privateAssignment=Copy(a)
        local saved=store.CommitTournamentJournal(journal.revision,candidate,action)
        if not saved then return false end
        journal=saved;return true
    end
    local function PrivateCurrent()
        if not Fresh() then return nil end
        local a=journal.privateAssignment
        local b=a and OpenBracket()
        if b and ns.TournamentRecovery.PrivateAssignment(b.Snapshot(),journal.control,a,journal.revision) then return a,b end
    end
    function D.PrivateAssign(match)
        if not Fresh() or journal.privateAssignment then return nil end
        local b=OpenBracket();local c=journal.control
        if not b or not c or c.paused or c.coordinator~=h.guid then return nil end
        local v=b.Snapshot()
        if v.state~="running" then return nil end
        for _,round in ipairs(v.rounds) do
            for _,m in ipairs(round) do
                if m.id==match and m.state=="ready" then
                    local game=m.wins[1]+m.wins[2]+1
                    if m.games[game] then return nil end
                    local a={match=match,game=game,attempt=m.replayedGame==game and 1 or 0,term=c.term,
                        serial=journal.revision+1,player1=m.a,player2=m.b,ready1=false,ready2=false}
                    if SavePrivateAssignment(a,"private_assign") then return Copy(a) end
                end
            end
        end
    end
    function D.PrivateOffer()
        local a=PrivateCurrent();return Copy(a)
    end
    function D.ResetPrivateObservation()
        local a=journal.privateAssignment
        if a then observed[a.match]=nil end
    end
    local function ForActor(actor,a,b)
        local side=actor.guid==a.player1 and 1 or actor.guid==a.player2 and 2
        if not side then return nil end
        local v=b.Snapshot()
        for _,round in ipairs(v.rounds) do for _,m in ipairs(round) do if m.id==a.match then
            local game=m.games[a.game]
            return {event=v.event,match=a.match,game=a.game,attempt=a.attempt,term=a.term,serial=a.serial,
                peer=side==1 and a.player2 or a.player1,ready=side==1 and a.ready1 or side==2 and a.ready2,
                both=a.ready1 and a.ready2,reported=game and game.reports[actor.guid]~=nil or false}
        end end end
    end
    function D.PrivateOfferFor(sender,event,match)
        local actor=resolve(sender);local a,b=PrivateCurrent()
        if not Actor(s,actor) or not a or not Permit(actor) or event~=b.Snapshot().event or match~=a.match then return nil end
        return ForActor(actor,a,b)
    end
    function D.PrivateReady(sender,event,match,term,serial)
        local actor=resolve(sender);local a,b=PrivateCurrent()
        if not Actor(s,actor) or not a or not Permit(actor) or event~=b.Snapshot().event
            or match~=a.match or term~=a.term or serial~=a.serial then return nil end
        local offer=ForActor(actor,a,b)
        if not offer or offer.reported then return nil end
        if not offer.ready then
            local next=Copy(a)
            if actor.guid==a.player1 then next.ready1=true else next.ready2=true end
            if not SavePrivateAssignment(next,"private_ready") then return nil end
            a=next
        end
        return ForActor(actor,a,b)
    end
    function D.PrivateReport(sender,event,match,term,serial,outcome)
        if outcome~="won" and outcome~="lost" then return false end
        local actor=resolve(sender)
        if not Actor(s,actor) or not Fresh() then return false end
        local a,b=PrivateCurrent()
        if a and b and a.match==match and a.term==term and a.serial==serial and a.ready1 and a.ready2
            and b.Snapshot().event==event then
            local offer=ForActor(actor,a,b)
            if not offer then return false end
            local winner=outcome=="won" and actor.guid or offer.peer
            return D.ReportBracket(sender,{event=event,match=match,game=a.game,attempt=a.attempt==1 and 1 or nil,
                winner=winner,evidence="T:"..ns.TournamentRecovery.PrivateSession(a)},term,h.guid)
        end
        -- Exact receipt retry after a confirmed game cleared its offer.
        -- Never use a late unmatched claim to manufacture a new report.
        local saved=journal.bracket
        if not saved or saved.checkpoint.ad.id~=event then
            local finished=journal.completed and journal.completed[event]
            saved=finished and finished.bracket
        end
        if not saved or saved.checkpoint.ad.id~=event or not Permit(actor) then return false end
        for _,r in ipairs(saved.reports) do
            if r.sender==actor.guid and not r.kind and r.match==match
                and r.evidence=="T:"..tostring(ns.TournamentRecovery.PrivateSession({match=match,game=r.game,
                    attempt=r.attempt or 0,term=term,serial=serial}))
                and (r.winner==actor.guid)==(outcome=="won") then return true,"duplicate" end
        end
        return false
    end
    function D.PrivateProgress()
        if not Fresh() then return nil end
        local saved,c,finishedAt=journal.bracket,D.ControlSnapshot(),nil
        if not saved then
            local ad=journal.checkpoint and journal.checkpoint.host.ad
            local final=ad and journal.completed and journal.completed[ad.id]
            if final then
                saved=final.bracket;finishedAt=final.finishedAt
                c={owner=h.guid,event=ad.id,coordinator=h.guid,term=final.term,paused=false}
            end
        end
        local b=saved and ns.TournamentBracket.OpenSimulated(s,h.guid,saved)
        if b and c then return {scope="PRIVATE_TEST",source="organizer-journal",saved=b.Save(),bracket=b.Snapshot(),control=c,finishedAt=finishedAt} end
    end
    -- Exact owner-log acknowledgements, session-local. Reopening requires
    -- new receipts rather than inventing peer agreement from local disk.
    local echoes={}
    local function EchoContext()
        if not Fresh() or not journal.bracket or not journal.control or journal.control.coordinator~=h.guid then return nil end
        local b=OpenBracket();local v=b and b.Snapshot()
        if not v or not (journal.control.paused or v.state=="completed") then return nil end
        return journal.bracket,journal.control,v.event..":"..journal.control.term..":"..v.revision
    end
    function D.PrivateReceiveEcho(sender,body)
        if not Packet(body) then return nil end
        local actor=resolve(sender)
        local saved,c,epoch=EchoContext()
        if not saved or not Actor(s,actor) or not Permit(actor) then return nil end
        local eligible
        for _,m in ipairs(saved.checkpoint.roster) do if m.guid==actor.guid and m.checkedIn then eligible=true;break end end
        if not eligible then return nil end
        local a=Split(body);local nonce=Number(a[3],1,2147483647);local page=Number(a[4],0,529)
        local index=Number(a[5],1,MAX_PARTS)
        if #a~=7 or a[1]~="Z" or a[2]~=key or not nonce or not page or not index then return nil end
        local e=echoes[actor.guid]
        if e and e.epoch~=epoch then e=nil;echoes[actor.guid]=nil end
        if e and nonce<e.nonce then return nil end
        if not e or nonce>e.nonce then
            if page~=0 or index~=1 then return nil end
            e={epoch=epoch,nonce=nonce,page=0,index=1};echoes[actor.guid]=e
        end
        local receipt=table.concat({"H",key,nonce,c.term,#saved.reports},"|")
        if e.done then return e.last==body and {receipt} or nil end
        if e.page~=page or e.index~=index then return nil end
        local q=table.concat({"V",key,nonce,c.event or saved.checkpoint.ad.id,page==0 and 0 or #saved.reports,page==0 and 0 or c.term,page},"|")
        -- Journal control has no event field; the canonical checkpoint owns it.
        local parts=ProgressPage(s,actor,saved,c,nil,q)
        if not parts or parts[index]~=body then return nil end
        e.last=body;e.index=e.index+1
        if e.index>#parts then e.index=1;e.page=e.page+1 end
        if e.page>saved.checkpoint.ad.count+#saved.reports then e.done=true;return {receipt} end
        return nil
    end
    local function EchoCopies()
        local saved,c,epoch=EchoContext()
        if not saved then return nil end
        local copies={}
        for _,m in ipairs(saved.checkpoint.roster) do
            local e=echoes[m.guid]
            if m.checkedIn and e and e.epoch==epoch and e.done then copies[m.guid]=Copy(saved) end
        end
        return copies,saved,c
    end
    function D.PrivateFinalize()
        local copies,saved,c=EchoCopies()
        if not copies or c.paused then return false end
        return D.Finalize(h.guid,saved.checkpoint.ad.id,c.term,copies)
    end
    function D.PrivateResume(states)
        local copies,saved,c=EchoCopies()
        if not copies or not c.paused or type(states)~="table" or states[h.guid]~="online" then return false end
        copies[h.guid]=Copy(saved)
        return D.ReconcileControl(c.term,states,copies)
    end
    function D.PrivateHistory()
        if not Fresh() then return {} end
        local rows={}
        for id,record in pairs(journal.completed or {}) do
            if record.population==key then
                local names={};for _,row in ipairs(record.bracket.checkpoint.roster) do names[row.guid]=row.name end
                rows[#rows+1]={id=id,title=record.bracket.checkpoint.ad.draft.name,champion=names[record.champion] or "Unknown",
                    finishedAt=record.finishedAt,scope="PRIVATE_TEST"}
            end
        end
        table.sort(rows,function(a,b)if a.finishedAt==b.finishedAt then return a.id<b.id end;return a.finishedAt>b.finishedAt end)
        return rows
    end
    function D.CloseSession() CloseAssignments() end
    -- Explicit owner hold; no fabricated result, no roster removal.
    function D.Hold(sender,id,term)
        local c=journal.control
        if not Fresh() or sender~=h.guid or not journal.commitment or journal.commitment.id~=id
            or not c or c.coordinator~=sender or c.paused or c.term~=term or term>=2147483647 then return false end
        -- Preserve a partially reported game: changing term would orphan its matching receipt.
        local a=journal.privateAssignment
        if a then
            local b=OpenBracket();if not b then return false end
            for _,round in ipairs(b.Snapshot().rounds) do for _,m in ipairs(round) do
                if m.id==a.match then
                    local game=m.games[a.game]
                    if game and next(game.reports) then return false,"A result is awaiting its matching report. Close and reopen the session to preserve it." end
                end
            end end
        end
        local candidate=Copy(journal);candidate.revision=candidate.revision+1
        candidate.control={term=term+1,coordinator=sender,paused=true};candidate.privateAssignment=nil
        local saved=store.CommitTournamentJournal(journal.revision,candidate,"control_change")
        if not saved then return false end
        journal=saved;CloseAssignments();return true
    end
    function D.Snapshot() local e=Open();return e and e.Save() end
    return D
end
-- Shared registration-session port. Transport supplies independently observed
-- actors and an explicit journal adapter. No gameplay or UI ownership here.
function R.OpenRegistrationSession(s,actor,clock,resolve,store,role)
    if not Actor(s,actor) or not P.Key(s) or type(clock)~="function" or type(resolve)~="function"
        or type(store)~="table" or type(store.ReadTournamentJournal)~="function"
        or type(store.CommitTournamentJournal)~="function" then return nil end
    local journal=store.ReadTournamentJournal()
    if not journal or journal.character~=actor.guid or journal.client~=s.client then return nil end
    if journal.commitment and journal.commitment.population~=P.Key(s) then return nil end
    if role=="host" then
        if journal.commitment and journal.commitment.role~="host" then return nil end
        return DurableHost(s,actor,clock,resolve,store)
    elseif role=="player" then
        if journal.commitment and journal.commitment.role~="participant" then return nil end
        local cache=Cache(s,clock)
        local wire=WireClient(s,cache,clock,resolve,store)
        if wire then return wire,cache end
    end
end
-- Private match packets use the same registration codec and size bound.
-- The caller resolves the real sender before routing to the durable owner.
function R.PrivateMatchRequest(s,op,seq,event,match,term,serial,outcome)
    if not P.Key(s) or not Whole(seq,1,2147483647) or type(event)~="string" or #event>96
        or type(match)~="string" or #match>8 or not match:match("^R%d+M%d+$") then return nil end
    local parts={op,P.Key(s),seq,event,match}
    if op=="K" or op=="U" or op=="W" or op=="E" then
        if not Whole(term,1,2147483647) or not Whole(serial,op=="W" and 0 or 1,2147483647)
            or (op=="W" and serial~=0) then return nil end
        parts[#parts+1]=term;parts[#parts+1]=serial
        if op=="U" then
            if outcome~="won" and outcome~="lost" then return nil end
            parts[#parts+1]=outcome
        elseif op=="E" then
            local game=Number(tostring(outcome),1,5)
            if not game then return nil end
            parts[#parts+1]=game
        end
    elseif op~="I" then return nil end
    local body=table.concat(parts,"|")
    return Packet(body) and body or nil
end
function R.ReceivePrivateMatchRequest(s,engine,sender,body)
    if not Packet(body) then return nil end
    local a=Split(body);local op=a[1];local seq=Number(a[3],1,2147483647)
    local term=Number(a[6],1,2147483647);local serial=Number(a[7],0,2147483647)
    if a[2]~=P.Key(s) or not seq or type(a[4])~="string" or type(a[5])~="string" then return nil end
    local canonical=R.PrivateMatchRequest(s,op,seq,a[4],a[5],term,serial,a[8])
    if canonical~=body then return nil end
    local offer
    if op=="I" then offer=engine.PrivateOfferFor(sender,a[4],a[5])
    elseif op=="K" then offer=engine.PrivateReady(sender,a[4],a[5],term,serial)
    elseif op=="U" or op=="W" or op=="E" then
        local ok,why
        if op=="U" then ok,why=engine.PrivateReport(sender,a[4],a[5],term,serial,a[8])
        else
            local c=engine.ControlSnapshot()
            if not c or c.event~=a[4] or c.term~=term or c.coordinator~=c.owner then return nil end
            if op=="W" then ok,why=engine.WithdrawBracket(sender,{event=a[4],match=a[5]},term,c.owner)
            else ok,why=engine.ConsentReplay(sender,{event=a[4],match=a[5],game=tonumber(a[8]),revision=serial},term,c.owner) end
        end
        if not ok or (why~="pending" and why~="confirmed" and why~="duplicate" and why~="disputed" and why~="forfeited" and why~="replay") then return nil end
        local reply=table.concat({"N",P.Key(s),seq,a[5],term,serial,why},"|")
        return Packet(reply) and {reply} or nil
    end
    if not offer then return nil end
    local reply=table.concat({"J",P.Key(s),seq,offer.match,offer.game,offer.attempt,offer.term,offer.serial,
        offer.peer,offer.ready and 1 or 0,offer.both and 1 or 0,offer.reported and 1 or 0},"|")
    return Packet(reply) and {reply} or nil
end
function R.DecodePrivateMatchReply(s,seq,body)
    if not Packet(body) then return nil end
    local a=Split(body)
    if a[2]~=P.Key(s) or Number(a[3],1,2147483647)~=seq or type(a[4])~="string"
        or #a[4]>8 or not a[4]:match("^R%d+M%d+$") then return nil end
    if a[1]=="J" and #a==12 then
        local game,attempt,term,serial=Number(a[5],1,5),Number(a[6],0,1),Number(a[7],1,2147483647),Number(a[8],1,2147483647)
        if not game or not attempt or not term or not serial or not Guid(a[9]) then return nil end
        for i=10,12 do if a[i]~="0" and a[i]~="1" then return nil end end
        if a[11]=="1" and a[10]~="1" then return nil end
        return {kind="offer",match=a[4],game=game,attempt=attempt,term=term,serial=serial,peer=a[9],
            ready=a[10]=="1",both=a[11]=="1",reported=a[12]=="1"}
    elseif a[1]=="N" and #a==7 then
        local term,serial=Number(a[5],1,2147483647),Number(a[6],0,2147483647)
        if not term or not serial or (a[7]~="pending" and a[7]~="confirmed" and a[7]~="duplicate" and a[7]~="disputed"
            and a[7]~="forfeited" and a[7]~="replay") then return nil end
        return {kind="receipt",match=a[4],term=term,serial=serial,status=a[7]}
    end
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
            function x.Session(role,actor,scope)
                return R.OpenRegistrationSession(scope or s,actor or a,clock,resolve,x.Open(),role)
            end
            return x
        end
        local function Discover(x,w)
            for _,v in ipairs(assert(x.wire.Receive("player",assert(w.Query(x.h.guid))))) do assert(w.Receive("host",v)) end
        end
        Case(client.." lost join survives storage reopen and exact retry",function()
            local x=Fixture();local w,cache=x.Session("player")
            assert(w and cache and not x.Session("player",x.h))
            Discover(x,w)
            local j=assert(w.Join(x.h.guid,x.ad.id));local ack=assert(x.wire.Receive("player",j))[1]
            assert(w.PendingOwner()==x.h.guid and not x.Session("host"))
            assert(x.Open().ReadTournamentJournal().pending.op=="J")
            local next=assert(x.Session("player"));assert(next.Status().status=="pending" and next.Retry()==j and next.PendingOwner()==x.h.guid)
            assert(not next.Join(x.h.guid,x.ad.id) and not next.Query(x.h.guid))
            assert(next.Receive("host",ack) and next.Status().status=="registered" and not next.PendingOwner())
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
            local function Pull(prior,nonce)
                local f=assert(R.OpenPrivateProgressFetch(x.s,x.h.guid,x.ad.id,x.a.guid,nonce,x.clock,x.resolve,prior))
                local limit=0
                while not f.Snapshot() do
                    limit=limit+1;assert(limit<=530)
                    x.Advance()
                    local q=assert(f.Request())
                    local parts=assert(x.engine.Receive("player",q))
                    assert(not f.Receive("other",parts[1]))
                    for i=#parts,1,-1 do assert(f.Receive("host",parts[i])) end
                end
                return assert(f.Snapshot())
            end
            local received=Pull(nil,101)
            assert(received.source=="organizer-reported" and Equal(received.saved,initial))
            assert(not replica.Accept("player",1,initial))
            assert(replica.Accept("host",1,initial))
            local report={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="progress-game"}
            x.Advance();assert(x.engine.ReportBracket("player",report,1,x.h.guid))
            local saved=store.ReadTournamentJournal().bracket
            local nextReceived=Pull(received,102)
            assert(Equal(nextReceived.saved,saved) and nextReceived.control.term==1)
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
        Case(client.." replay consent survives reopen and stale controller cannot resume",function()
            local x,w,Req,m=StartCompetition()
            local owner=x.h.guid
            local p={event=x.ad.id,match=m.id,game=1,winner=x.a.guid,evidence="disputed-game"}
            x.Advance();assert(x.engine.ReportBracket("player",p,1,owner))
            p.winner=x.other.guid;assert(x.engine.ReportBracket("other",p,1,owner))
            local v=x.engine.BracketSnapshot()
            local q={event=x.ad.id,match=m.id,game=1,revision=v.dispute.revision}
            assert(not x.engine.ConsentReplay("host",q,1,owner))
            assert(not x.engine.ConsentReplay("player",q,2,owner))
            assert(x.engine.ConsentReplay("player",q,1,owner))
            local reopened=assert(x.Open())
            assert(reopened.BracketSnapshot().state=="disputed")
            assert(reopened.ConsentReplay("other",q,1,owner))
            assert(not x.engine.BracketSnapshot())
            p.attempt=1;p.evidence="new-game"
            x.Advance();assert(reopened.ReportBracket("player",p,1,owner))
            assert(reopened.ReportBracket("other",p,1,owner))
            assert(reopened.BracketSnapshot().champion==x.other.guid)
        end)
        Case(client.." finalization does not require eliminated semifinalists to remain online",function()
            local x=Fixture();local e=assert(Host(x.s,x.h,x.clock));local ad=assert(e.Publish(x.h.guid,x.draft))
            local players={}
            for i=1,4 do local a=Copy(x.a);a.guid="Player-1-F"..i;a.name="F"..i;players[i]=a;assert(e.Join(ad.id,a.guid,a)) end
            x.Advance(ad.draft.startAt-1800-x.clock())
            for _,a in ipairs(players) do assert(e.CheckIn(ad.id,a.guid)) end
            x.Advance(1800)
            local d=assert(ns.TournamentBracket.NewSimulated(x.s,x.h.guid,e.Save(),x.clock(),x.h.guid))
            for round=1,2 do
                for _,m in ipairs(d.Snapshot().rounds[round]) do
                    local p={event=ad.id,match=m.id,game=1,winner=m.a,evidence=m.id..":final"}
                    assert(d.Report(m.a,p));assert(d.Report(m.b,p))
                end
            end
            local v=d.Snapshot();local saved=d.Save();local final=v.rounds[2][1]
            local rec=ns.TournamentRecovery;local control=rec.InitialControl(saved)
            assert(not rec.FinalRecord(client,x.h.guid,saved,control,x.clock(),{[final.a]=saved}))
            assert(rec.FinalRecord(client,x.h.guid,saved,control,x.clock(),{[final.a]=saved,[final.b]=saved}).champion==final.a)
            local bad=Copy(saved);bad.startedAt=bad.startedAt+1
            local copies={[final.a]=saved,[final.b]=saved}
            for _,a in ipairs(players) do if not copies[a.guid] then copies[a.guid]=bad;break end end
            assert(not rec.FinalRecord(client,x.h.guid,saved,control,x.clock(),copies))
        end)
        local function MatchFixture(x,m)
            local owner=x.h.guid
            local g=assert(x.engine.AssignMatch("host",m.id,"game-alpha",1))
            local function Idle(rev,last)
                return {scope="SIMULATED",client=client,state="idle",revision=rev,last=last}
            end
            local function Challenge(who,peer,rev,ranked)
                return {scope="SIMULATED",client=client,state="challenge",revision=rev,
                    challenge={opponent={guid=peer},time=10,direction=who==x.a.guid and "outgoing" or "incoming",kind="standard",rankedWidget=ranked}}
            end
            local function Accepted(who,peer,rev,cycle)
                return {scope="SIMULATED",client=client,state="accepted",revision=rev,
                    active={opponent={guid=peer},player={guid=who},acceptedAt=11,id=cycle,
                        direction=who==x.a.guid and "outgoing" or "incoming",kind="standard",rankedWidget=false}}
            end
            local function Result(peer,rev,cycle,outcome)
                return Idle(rev,{scope="SIMULATED",client=client,id=cycle,opponent={guid=peer},acceptedAt=11,endedAt=20,
                    kind="standard",outcome=outcome,endType="knockout",reason="matching_result_and_finish",
                    outcomeObserved=true,finishObserved=true,resultObserved=true,conflict=false,rankEligible=false})
            end
            local function ReadyBoth()
                assert(g.Consent("player",Idle(1,{id=6})))
                assert(g.Consent("other",Idle(1,{id=20})))
                assert(g.Observe("player",Challenge(x.a.guid,x.other.guid,2)))
                assert(g.Observe("other",Challenge(x.other.guid,x.a.guid,2)))
                assert(g.Observe("player",Accepted(x.a.guid,x.other.guid,3,7)))
                assert(g.Observe("other",Accepted(x.other.guid,x.a.guid,3,21)))
            end
            return g,Idle,Challenge,Accepted,Result,ReadyBoth
        end
        Case(client.." assigned tournament duel uses shared observations and separate scoring",function()
            local x,w,Req,m=StartCompetition()
            assert(not x.engine.AssignMatch("player",m.id,"spoof",1))
            assert(not x.engine.AssignMatch("host",m.id,"stale",2))
            local g,Idle,Challenge,Accepted,Result,ReadyBoth=MatchFixture(x,m)
            assert(not x.engine.AssignMatch("host",m.id,"duplicate",1))
            assert(g.Snapshot().rankEligible==false and g.Snapshot().mode=="tournament")
            assert(not g.Observe("host",Idle(1)))
            ReadyBoth();x.Advance()
            assert(g.Observe("player",Result(x.other.guid,4,7,"won")))
            assert(x.engine.BracketSnapshot().state=="running")
            assert(not g.Observe("player",Result(x.other.guid,5,7,"won")))
            assert(g.Observe("other",Result(x.a.guid,4,21,"lost")))
            assert(x.engine.BracketSnapshot().champion==x.a.guid)
            assert(not g.IsActive() and not x.engine.AssignMatch("host",m.id,"again",1))
            assert(not g.Observe("other",Result(x.a.guid,5,21,"lost")))
        end)
        Case(client.." unrelated ranked or unagreed duel cannot enter tournament bracket",function()
            local x,w,Req,m=StartCompetition()
            local g,Idle,Challenge,Accepted,Result=MatchFixture(x,m)
            assert(g.Consent("player",Idle(1,{id=6})))
            assert(not g.Observe("player",Challenge(x.a.guid,x.other.guid,2)))
            assert(not g.IsActive() and x.engine.BracketSnapshot().revision==0)
            g,Idle,Challenge,Accepted,Result=MatchFixture(x,m)
            assert(g.Consent("player",Idle(1,{id=6})));assert(g.Consent("other",Idle(1,{id=20})))
            assert(not g.Observe("player",Challenge(x.a.guid,x.other.guid,2,true)))
            assert(not g.IsActive())
            g,Idle,Challenge,Accepted,Result=MatchFixture(x,m)
            assert(g.Consent("player",Idle(1,{id=6})));assert(g.Consent("other",Idle(1,{id=20})))
            assert(not g.Observe("player",Challenge(x.a.guid,x.h.guid,2)))
            assert(not g.IsActive() and x.engine.BracketSnapshot().revision==0)
        end)
        Case(client.." stale duel cycle incomplete evidence and control change invalidate assignment",function()
            local x,w,Req,m=StartCompetition()
            local g,Idle,Challenge,Accepted,Result,ReadyBoth=MatchFixture(x,m)
            assert(g.Consent("player",Idle(1,{id=6})));assert(g.Consent("other",Idle(1,{id=20})))
            assert(g.Observe("player",Challenge(x.a.guid,x.other.guid,2)))
            assert(not g.Observe("player",Accepted(x.a.guid,x.other.guid,3,6)))
            assert(not g.IsActive())
            g,Idle,Challenge,Accepted,Result,ReadyBoth=MatchFixture(x,m);ReadyBoth()
            local incomplete=Result(x.other.guid,4,7,"won");incomplete.last.finishObserved=false
            assert(not g.Observe("player",incomplete) and not g.IsActive())
            assert(x.engine.BracketSnapshot().revision==0)
            g,Idle,Challenge,Accepted,Result,ReadyBoth=MatchFixture(x,m);ReadyBoth()
            assert(x.engine.Hold(x.h.guid,x.ad.id,1))
            assert(not g.Observe("player",Result(x.other.guid,4,7,"won")) and not g.IsActive())
            assert(x.engine.BracketSnapshot().revision==0)
        end)
        Case(client.." conflicting observed tournament outcomes remain disputed",function()
            local x,w,Req,m=StartCompetition()
            local g,Idle,Challenge,Accepted,Result,ReadyBoth=MatchFixture(x,m)
            ReadyBoth();x.Advance()
            assert(g.Observe("player",Result(x.other.guid,4,7,"won")))
            assert(g.Observe("other",Result(x.a.guid,4,21,"won")))
            assert(x.engine.BracketSnapshot().state=="disputed" and not x.engine.BracketSnapshot().champion)
            assert(not g.IsActive())
        end)
        local function Connected(x,m)
            local g=assert(x.engine.AssignMatch("host",m.id,"connected",1))
            local a=assert(ns.DuelDetection.NewSandbox(client,false))
            local b=assert(ns.DuelDetection.NewSandbox(client,false))
            local sep=client=="forever" and " " or "-"
            a.people.player={fullName="Alpha"..sep.."Home",guid=x.a.guid}
            a.people.target={fullName="Beta"..sep.."Other",guid=x.other.guid}
            b.people.player=a.people.target;b.people.target=a.people.player
            assert(g.ConnectSimulated("player",a.detector));assert(g.ConnectSimulated("other",b.detector))
            assert(a.detector.GetDiagnosticResources().subscriptions==1 and b.detector.GetDiagnosticResources().subscriptions==1)
            return g,a,b
        end
        Case(client.." connected detector sandboxes advance tournament and release listeners",function()
            local x,w,Req,m=StartCompetition()
            local g,a,b=Connected(x,m)
            a.Outgoing("target");b.Fire("DUEL_REQUESTED",a.people.player.fullName)
            a.Fire("CHAT_MSG_SYSTEM","Duel starting: 3");b.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
            assert(a.detector.GetSnapshot().active.duelMode=="tournament")
            assert(b.detector.GetSnapshot().active.duelMode=="tournament")
            local msg=a.people.player.fullName.." has defeated "..a.people.target.fullName.." in a duel"
            x.Advance()
            a.Fire("CHAT_MSG_SYSTEM",msg);a.Fire("DUEL_FINISHED")
            assert(a.detector.GetSnapshot().last.duelMode=="tournament")
            assert(a.detector.GetDiagnosticResources().subscriptions==0)
            b.Fire("DUEL_FINISHED");b.Fire("CHAT_MSG_SYSTEM",msg)
            assert(b.detector.GetDiagnosticResources().subscriptions==0 and not g.IsActive())
            assert(x.engine.BracketSnapshot().champion==x.a.guid)
            a.Outgoing("target");a.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
            assert(not a.detector.GetSnapshot().active.duelMode)
        end)
        Case(client.." hold detaches immediately and frozen duel remains tournament",function()
            local x,w,Req,m=StartCompetition();local g,a,b=Connected(x,m)
            a.Outgoing("target");b.Fire("DUEL_REQUESTED",a.people.player.fullName)
            a.Fire("CHAT_MSG_SYSTEM","Duel starting: 3");b.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
            assert(x.engine.Hold(x.h.guid,x.ad.id,1))
            assert(a.detector.GetDiagnosticResources().subscriptions==0 and b.detector.GetDiagnosticResources().subscriptions==0 and not g.IsActive())
            a.Fire("CHAT_MSG_SYSTEM",a.people.player.fullName.." has defeated "..a.people.target.fullName.." in a duel")
            a.Fire("DUEL_FINISHED")
            local last=a.detector.GetSnapshot().last
            assert(last.duelMode=="tournament" and last.rankEligible==false)
            assert(x.engine.BracketSnapshot().revision==0)
            local ctx={scope="PEER",client=client,me=x.a.guid,peer=x.other.guid,cycle=last.id,
                agreement={scope="PEER",state="candidate",candidate=true,rankEligible=false,session="a:b"}}
            last.scope="LOCAL";last.observedAt=1795622400
            assert(not ns.ResultConfirmation.MakePeerStatement(ctx,last))
            last.duelMode=nil
            assert(ns.ResultConfirmation.MakePeerStatement(ctx,last))
        end)
        Case(client.." wrong opponent and cancellation remove detector connections without rating leakage",function()
            local x,w,Req,m=StartCompetition();local g,a,b=Connected(x,m)
            local sep=client=="forever" and " " or "-"
            a.people.target={fullName="Gamma"..sep.."Other",guid="Player-1-GAMMA"}
            a.Outgoing("target")
            assert(not a.detector.GetSnapshot().challenge.duelMode)
            assert(a.detector.GetDiagnosticResources().subscriptions==0 and b.detector.GetDiagnosticResources().subscriptions==0)
            assert(not g.IsActive() and x.engine.BracketSnapshot().revision==0)
            g,a,b=Connected(x,m)
            assert(x.engine.Cancel(x.h.guid,x.ad.id))
            assert(a.detector.GetDiagnosticResources().subscriptions==0 and b.detector.GetDiagnosticResources().subscriptions==0)
            assert(not g.IsActive())
            a.Outgoing("target");a.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
            assert(not a.detector.GetSnapshot().active.duelMode)
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

local preview,catalog
local previewListeners={}
function R.SubscribePreview(fn)
    if type(fn)~="function" then return function()end end
    previewListeners[fn]=true
    return function()previewListeners[fn]=nil end
end
local function PreviewChanged()
    for fn in pairs(previewListeners) do
        local ok=pcall(fn)
        if not ok and ns.Diagnostics and ns.Diagnostics.Record then
            ns.Diagnostics.Record("Tournament preview callback","A local tournament listener failed")
        end
    end
end
local TEST_NAMES={"Ashwarden","Duskblade","Ironwill","Frostvale","Emberguard","Stormveil","Mooncrest","Thornheart",
    "Silveroak","Redspire","Shadowfen","Brightforge","Ravenward","Nightbloom","Dawnsteel","Stonewake",
    "Mistfall","Flamecrest","Oakshield","Wintermark","Goldthorn","Duskmantle","Skyrune","Sablewind",
    "Runehaven","Ashenwolf","Copperleaf","Wildspark","Starforge","Grimvale","Snowspire","Windborne"}
local function FillPreview(x,target)
    local d=x.engine.Ad().draft
    local count=x.engine.Ad().count
    local seed=x.seed or 0
    for i=count+1,math.min(target,d.capacity) do
        local a=Copy(x.scope)
        a.guid=string.format("Player-0-TESTBOT%02d",i)
        a.name=TEST_NAMES[(i+seed-1)%#TEST_NAMES+1]
        a.level=math.max(d.minLevel>0 and d.minLevel or 1,math.min(x.player.level,d.maxLevel>0 and d.maxLevel or 255))
        local ok=x.engine.Join(x.id,a.guid,a)
        if not ok then return false,"Test registration is closed or full." end
    end
    return true,"Test participants registered."
end
-- Explicit session-only rehearsal. The same bracket engine owns the draw
-- and score. No live transport, persistence, rating or detector arm here.
local function PreparePreview(s,h,a,d,n,mode,count)
    local x={key=P.Key(s),scope=Copy(s),now=n,role=mode=="join" and "player" or "host",host=h,player=a,
        mode=mode,seed=n%#TEST_NAMES}
    local clock=function()return x.now end
    x.engine=Host(s,h,clock);x.cache=Cache(s,clock)
    local ad,why=x.engine.Publish(h.guid,d)
    if not ad then return nil,why end
    x.id=ad.id
    if mode then
        local ok,why=FillPreview(x,count)
        if not ok then return nil,why end
        return x
    end
    local rival=Copy(s)
    rival.guid,rival.name="Player-0-TESTOPPONENT","Test opponent (local)"
    rival.level=math.max(d.minLevel>0 and d.minLevel or 1,math.min(a.level,d.maxLevel>0 and d.maxLevel or 255))
    if not x.engine.Join(ad.id,rival.guid,rival) then return nil,"Could not prepare the test opponent." end
    x.rival=rival;x.id=ad.id
    return x
end
local function StartPreviewBracket(x)
    if x.bracket then return false,"The test bracket has already started." end
    if x.mode~="host" and x.mode~="watch" and not x.joined then return false,"Join and check in as the test player first." end
    local cp=x.engine.Save()
    local checked=false
    for _,r in ipairs(cp.roster) do if r.guid==x.player.guid and r.checkedIn then checked=true end end
    if x.mode~="host" and x.mode~="watch" and not checked then return false,"Check in as the test player first." end
    local checkTime=math.max(x.now,cp.ad.draft.startAt-1800)
    -- The local host rehearsal may be started manually at/after the
    -- scheduled start. Its fixture check-ins still occur before the draw.
    if x.mode=="host" or x.mode=="join" then checkTime=math.min(checkTime,cp.ad.draft.startAt-1) end
    local clock=function()return checkTime end
    local candidate=Host(x.scope,x.host,clock,cp)
    if not candidate then return false,"Test check-in is unavailable." end
    for _,r in ipairs(cp.roster) do
        if r.guid~=x.player.guid and not candidate.CheckIn(x.id,r.guid) then return false,"Test check-in is unavailable." end
    end
    local start=math.max(x.now,cp.ad.draft.startAt)
    -- Candidate keeps the session clock after successful start.
    checkTime=start
    local bracket=ns.TournamentBracket and ns.TournamentBracket.NewSimulated(x.scope,x.host.guid,candidate.Save(),start,x.host.guid)
    if not bracket then return false,"The test bracket could not start." end
    x.engine=candidate;x.now=start;x.bracket=bracket
    return true,"Local test bracket started."
end
local function PreviewMatch(x,view)
    if not view or view.state~="running" then return nil end
    for _,round in ipairs(view.rounds) do
        for _,m in ipairs(round) do
            if m.state=="ready" and (m.a==x.player.guid or m.b==x.player.guid) then
                local first=m.a==x.player.guid
                local opponent=first and m.b or m.a
                local name="Unknown player"
                for _,r in ipairs(x.engine.Roster(x.host.guid)) do if r.guid==opponent then name=r.name;break end end
                return {id=m.id,round=m.round,roundCount=#view.rounds,opponent=name,
                    score=m.wins[first and 1 or 2],opponentScore=m.wins[first and 2 or 1],bestOf=view.bestOf}
            end
        end
    end
end
local function UpcomingRound(x,view)
    if x.role~="player" or not view or view.state~="running" or PreviewMatch(x,view) then return nil end
    for r=#view.rounds-1,1,-1 do
        for i,m in ipairs(view.rounds[r]) do
            if m.state=="done" and m.winner==x.player.guid then
                local nextMatch=view.rounds[r+1][math.ceil(i/2)]
                if nextMatch and nextMatch.state=="waiting" then
                    return {id=nextMatch.id,round=r+1,roundCount=#view.rounds}
                end
                return nil
            end
        end
    end
end
local function ReadyMatches(view)
    local rows={}
    if view and view.state=="running" then
        for _,round in ipairs(view.rounds) do
            for _,m in ipairs(round) do if m.state=="ready" and m.a and m.b then rows[#rows+1]=m end end
        end
    end
    return rows
end
local function FeaturedMatch(x,view)
    local ready=ReadyMatches(view)
    for _,m in ipairs(ready) do if m.id==x.featured then return m,ready end end
    return ready[1],ready
end
local function SelectedMatch(x,view)
    local pinned=x.demo and x.demo.match or x.offline and x.offline.match
    if pinned then for _,m in ipairs(ReadyMatches(view)) do if m.id==pinned then return m end end end
    if x.role=="player" and not x.broadcast then
        local own=PreviewMatch(x,view)
        if own then
            for _,m in ipairs(ReadyMatches(view)) do if m.id==own.id then return m end end
        end
    end
    return FeaturedMatch(x,view)
end
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...);if not ok then return nil end
    if type(issecretvalue)=="function" then local good,secret=pcall(issecretvalue,v);if not good or secret then return nil end end
    return v
end
local function Current()
    local key=P.Key(P.GetCurrent())
    if preview and key~=preview.key then preview=nil end
    if catalog and key~=catalog.key then catalog=nil end
    return preview
end
local function SyncHostedSchedule(x,server)
    if not x or x.mode~="host" or x.role~="host" or x.bracket then return nil end
    local ad=x.engine.Ad()
    if not ad or not Whole(server,1,4102444800) then return x.now end
    x.now=math.max(x.now,math.min(server,ad.draft.startAt))
    return x.now
end
function R.SyncHostPreviewClock(id)
    local x=Current()
    if not x or x.id~=id then return nil end
    return SyncHostedSchedule(x,Read(GetServerTime))
end
local function SyncPlayerSchedule(x,server)
    if not x or x.mode~="join" or x.role~="player" or not x.joined or x.bracket then return nil end
    if not Whole(server,1,4102444800) then return x.now end
    local last=x.scheduleServer
    if not last then x.scheduleServer=server;return x.now end
    local elapsed=math.max(0,server-last)
    x.scheduleServer=math.max(last,server)
    x.now=math.max(x.now,math.min(x.now+elapsed,x.engine.Ad().draft.startAt))
    return x.now
end
function R.SyncPlayerPreviewClock(id)
    local x=Current()
    if not x or x.id~=id then return nil end
    return SyncPlayerSchedule(x,Read(GetServerTime))
end
local function MakeCatalog(s,a,n,formatter)
    local data={key=P.Key(s),entries={}}
    local titles={"Duskblade Invitational","Iron Ring Cup","Emberfall Open","Stormcrest Championship"}
    local locations=s.faction=="Alliance" and {"Elwynn Forest","Dun Morogh","Westfall","Loch Modan"} or
        {"Durotar","Tirisfal Glades","Mulgore","The Barrens"}
    for i,size in ipairs({4,8,16,32}) do
        local d=T.DraftDefaults();d.name=titles[i];d.location=locations[i]
        -- UTC fixture scheduling relative to the actual session, not a fixed old date.
        d.startUTC=Read(formatter or date,"!%Y-%m-%d %H:%M",math.floor(n/60)*60+(i+2)*3600)
        d.capacity=size;d.bestOf=i%2==0 and 3 or 1
        d=T.ValidateDraft(s.client,d,n,s.region,s.ruleset,s.faction)
        if not d then return nil end
        local h=Copy(s);h.guid="Player-0-TESTORG"..i;h.name=TEST_NAMES[(i+11)%#TEST_NAMES+1]
        local x=PreparePreview(s,h,a,d,n,"join",math.max(2,size-1-(i%3)))
        if not x then return nil end
        data.entries[i]=x
    end
    return data
end
function R.OpenTestCatalog()
    if ns.TournamentSession and ns.TournamentSession.IsActive() then return false,"End the private network test first." end
    if Current() then return false,"End the active local test first." end
    local s=P.GetCurrent();local n=Read(GetServerTime);local level=Read(UnitLevel,"player")
    if not P.Key(s) or not Whole(n,1,4102444800) or not Whole(level,1,255) then return false,"Character or time unavailable." end
    local a=Copy(s);a.guid,a.name,a.level="Player-0-TESTPLAYER","You (local test)",level
    catalog=MakeCatalog(s,a,n)
    return catalog~=nil,catalog and "Choose a local test tournament." or "Could not prepare test tournaments."
end
-- Catalog clocks are frozen local rehearsal clocks, not real deadlines.
function R.TestCatalogTime()
    if not Current() and catalog and catalog.entries[1] then return catalog.entries[1].now end
end
function R.TestListings()
    if Current() or not catalog then return nil end
    local rows={}
    for i,x in ipairs(catalog.entries) do rows[i]=x.engine.Ad() end
    return rows
end
function R.JoinTestListing(index)
    if Current() or not catalog or not Whole(index,1,#catalog.entries) then return false,"Choose a test tournament." end
    local x=catalog.entries[index]
    local ok,why=x.engine.Join(x.id,x.player.guid,x.player)
    if not ok then return false,why end
    x.joined=true;preview=x;catalog=nil
    x.scheduleServer=Read(GetServerTime)
    return true,why
end
function R.WatchTestListing(index)
    if Current() or not catalog or not Whole(index,1,#catalog.entries) then return false,"Choose a test tournament." end
    local x=catalog.entries[index]
    x.role,x.mode,x.broadcast="spectator","watch",true
    local ok,why=StartPreviewBracket(x)
    if not ok then x.role,x.mode,x.broadcast="player","join",nil;return false,why end
    preview=x;catalog=nil;PreviewChanged()
    return true,"Watching local test tournament."
end
function R.PreviewState()
    local x=Current();if not x then return nil end
    if x.role=="host" then return "hosting" end
    if x.role=="spectator" then return "watching" end
    if x.bracket then
        local v=x.bracket.Snapshot()
        for _,round in ipairs(v.rounds) do
            for _,m in ipairs(round) do
                if m.state=="done" and not m.bye and (m.a==x.player.guid or m.b==x.player.guid)
                    and m.winner~=x.player.guid then return "eliminated" end
            end
        end
        return "competing"
    end
    return x.joined and "registered" or "preview-browse"
end
function R.PreviewHasBracket()
    local x=Current();return x~=nil and x.bracket~=nil
end
function R.CanCreatePreview()
    return Current()==nil and not (ns.TournamentSession and ns.TournamentSession.IsActive())
end
function R.StartPreview(d)
    if not R.CanCreatePreview() then return false,"End the current test first." end
    local s=P.GetCurrent();local n=Read(GetServerTime);local level=Read(UnitLevel,"player")
    if not P.Key(s) or not Whole(n,1,4102444800) or not Whole(level,1,255) then return false,"Character or time unavailable." end
    local h,a=Copy(s),Copy(s)
    h.guid,h.name="Player-0-TESTHOST","Local test organizer"
    a.guid,a.name,a.level="Player-0-TESTPLAYER","You (local test)",level
    local count=math.max(2,d.capacity-1-n%math.min(4,d.capacity-1))
    local x,why=PreparePreview(s,h,a,d,n,"host",count)
    if not x then return false,why end
    preview=x;catalog=nil
    return true,"Local test created with "..count.." simulated participants. Nothing sent to other players."
end
function R.EndPreview()
    preview=nil;catalog=nil;PreviewChanged()
end
function R.PreviewSnapshot()
    local x=Current();if not x then return nil end
    local server=Read(GetServerTime)
    SyncHostedSchedule(x,server);SyncPlayerSchedule(x,server)
    local ad=x.engine.Ad();x.cache.Accept(x.host.guid,ad)
    local rows=x.engine.Roster(x.host.guid);local member
    local names={}
    for _,r in ipairs(rows) do
        names[r.guid]=r.name
        if r.guid==x.player.guid then member=r end
    end
    local bracket=x.bracket and x.bracket.Snapshot()
    local featured,ready=FeaturedMatch(x,bracket)
    local chosen=SelectedMatch(x,bracket)
    local match=PreviewMatch(x,bracket)
    local opponent
    if match and x.role=="player" then
        for _,round in ipairs(bracket.rounds) do
            for _,m in ipairs(round) do if m.id==match.id then
                local peer=m.a==x.player.guid and m.b or m.a
                for _,r in ipairs(rows) do if r.guid==peer then opponent=Copy(r);break end end
            end end
        end
    end
    return {scope="SIMULATED",role=x.role,state=R.PreviewState(),event=ad,events=bracket and {} or x.cache.Browse(),
        roster=x.role=="host" and rows or nil,member=member,now=x.now,bracket=bracket,
        match=match,opponent=opponent,names=names,mode=x.mode,broadcast=x.broadcast==true,
        featured=featured and featured.id,selected=chosen and chosen.id,readyCount=#ready,
        demo=Copy(x.demo),offline=Copy(x.offline),upcoming=UpcomingRound(x,bracket)}
end
local function FixtureWinner(x,v,m)
    local game=m.wins[1]+m.wins[2]+1
    return (v.revision+game+x.seed)%3==0 and m.b or m.a
end
local function SimulatePreviewGame(x)
    local v=x.bracket.Snapshot()
    if v.state~="running" then return false,"The test bracket is not running." end
    local own=PreviewMatch(x,v)
    local match=SelectedMatch(x,v)
    if not match then return false,"No test match is ready." end
    local game=match.wins[1]+match.wins[2]+1
    local winner=FixtureWinner(x,v,match)
    local candidate=ns.TournamentBracket.OpenSimulated(x.scope,x.host.guid,x.bracket.Save())
    if not candidate then return false,"Test bracket unavailable." end
    local report={event=v.event,match=match.id,game=game,winner=winner,evidence="TEST:"..match.id..":"..game}
    local ok,why=candidate.Report(match.a,report)
    if not ok or why~="pending" then return false,"Test report unavailable." end
    ok,why=candidate.Report(match.b,report)
    if not ok or why~="confirmed" then return false,"Test result unavailable." end
    x.bracket=candidate
    local result
    local nextView=candidate.Snapshot()
    local names={}
    for _,row in ipairs(x.engine.Roster(x.host.guid)) do names[row.guid]=row.name end
    for _,round in ipairs(nextView.rounds) do
        for _,m in ipairs(round) do
            if m.id==match.id then
                local personal=own and match.id==own.id and x.role=="player" and not x.broadcast
                local first=personal and m.a==x.player.guid or not personal and m.a==winner
                result={scope="SIMULATED",outcome=personal and winner~=x.player.guid and "lost" or "won",
                    opponent=personal and own.opponent or names[winner==m.a and m.b or m.a] or "Unknown player",
                    winnerName=names[winner] or "Unknown player",
                    score=m.wins[first and 1 or 2],opponentScore=m.wins[first and 2 or 1],
                    complete=m.state=="done",advanced=m.state=="done" and (not personal or m.winner==x.player.guid),
                    spectated=not personal,champion=nextView.champion and names[nextView.champion] or nil}
            end
        end
    end
    return true,"Simulated game confirmed. No rating changes.",result
end
-- Only explicit local fixture data. No health, damage or presence claim
-- about an actual character. A bounded UI driver advances the test clock.
local function StartDemo(x)
    if not x.bracket or x.demo or x.offline then return false,"A test match is already active." end
    local v=x.bracket.Snapshot();local m=SelectedMatch(x,v)
    if not m then return false,"No test match ready." end
    x.demo={match=m.id,elapsed=0,duration=8,winner=FixtureWinner(x,v,m)}
    return true,"Simulated match started."
end
local function AdvanceDemo(x)
    if not x.demo then return false,"No simulated match." end
    x.demo.elapsed=x.demo.elapsed+1
    if x.demo.elapsed<x.demo.duration then return true end
    local ok,why,result=SimulatePreviewGame(x)
    x.demo=nil
    if result then result.duration=8 end
    return ok,why,result
end
local function ObservePreview(x,states)
    local d=x.offline
    if not d or not x.bracket then return nil end
    local v=x.bracket.Snapshot()
    x.observed=x.observed or {}
    return ObserveGrace(x.observed,v,d.match,states,1,x.now,function(record)
        local b=ns.TournamentBracket.OpenSimulated(x.scope,x.host.guid,x.bracket.Save())
        if not b or not b.ForfeitOffline(record) then return false end
        x.bracket=b;return true
    end)
end
local function StartOffline(x)
    if not x.bracket or x.demo or x.offline then return false,"Finish the current test first." end
    local v=x.bracket.Snapshot();local m=SelectedMatch(x,v)
    if not m then return false,"No ready test match." end
    local loser=m.a==x.player.guid and m.b or m.b==x.player.guid and m.a or m.b
    local other=loser==m.a and m.b or m.a
    x.graceSequence=(x.graceSequence or 0)+1
    x.offline={match=m.id,player=loser,other=other,remaining=300,sequence=x.graceSequence}
    local o=ObservePreview(x,{[loser]="offline",[other]="online"})
    if not o then x.offline=nil;return false,"Test disconnect unavailable." end
    x.offline.remaining=o.remaining
    o.sequence=x.offline.sequence
    return true,"Simulated disconnect - five minute grace started.",nil,o
end
local function AdvanceOffline(x,seconds)
    local d=x.offline
    if not d then return false,"No disconnect test." end
    -- Explicit simulated time advance, with contiguous observations no
    -- more than ten seconds apart, through the same grace policy.
    while seconds>0 and x.offline do
        local step=math.min(10,seconds);seconds=seconds-step;x.now=x.now+step
        local o=ObservePreview(x,{[d.player]="offline",[d.other]="online"})
        if not o then x.offline=nil;return false,"Test observation interrupted." end
        d.remaining=o.remaining
        if o.notice=="forfeited" then
            o.sequence=d.sequence
            x.offline=nil;return true,"Simulated disconnect forfeit confirmed.",nil,o
        end
    end
    return true
end
local function StopOffline(x,connected)
    local d=x.offline
    if not d then return false,"No disconnect test." end
    local o=ObservePreview(x,{[d.player]=connected and "online" or "unknown",[d.other]="online"})
    if o then o.sequence=d.sequence end
    x.offline=nil
    return true,connected and "Simulated player reconnected." or "Test observation interrupted.",nil,o
end
function R.CancelBroadcastFixture()
    local x=Current()
    if not x then return end
    x.demo=nil
    if x.offline then StopOffline(x,false) end
end
local function PreviewAction(action)
    local x=Current();if not x then return false,"No local test tournament." end
    local server=Read(GetServerTime)
    SyncHostedSchedule(x,server);SyncPlayerSchedule(x,server)
    if action=="start-demo" then return StartDemo(x) end
    if action=="tick-demo" then return AdvanceDemo(x) end
    if action=="disconnect" then return StartOffline(x) end
    if action=="tick-grace" then return AdvanceOffline(x,1) end
    if action=="advance-grace" then return AdvanceOffline(x,60) end
    if action=="reconnect" then return StopOffline(x,true) end
    if x.demo or x.offline then return false,"Finish the current test first." end
    if action=="host" or action=="player" then
        if x.mode then return false,"This local test keeps your tournament role." end
        x.role=action;return true
    end
    if action=="broadcast" and x.bracket then
        x.broadcast=not x.broadcast;return true,x.broadcast and "Broadcast view." or "Personal view."
    end
    if (action=="feature-next" or action=="feature-prev") and x.role=="host" and x.bracket then
        local featured,ready=FeaturedMatch(x,x.bracket.Snapshot())
        if not featured or #ready<2 then return false,"Only one match is ready." end
        for i,m in ipairs(ready) do if m.id==featured.id then
            local offset=action=="feature-next" and 1 or -1
            x.featured=ready[(i-1+offset)%#ready+1].id
            return true,"Featured match changed."
        end end
    end
    if action=="fill" and x.mode=="host" and not x.bracket then return FillPreview(x,x.engine.Ad().draft.capacity) end
    if action=="start-bracket" and x.mode=="join" and x.role=="player" then return StartPreviewBracket(x) end
    if action=="simulate-game" and x.bracket then return SimulatePreviewGame(x) end
    if action=="cancel" and x.role=="host" then local ok,why=x.engine.Cancel(x.id,x.host.guid);if ok then R.EndPreview() end;return ok,why end
    if action=="start-bracket" and x.role=="host" then return StartPreviewBracket(x) end
    if x.bracket then return false,"The local test has already started." end
    if x.role~="player" then return false,"Switch to player preview first." end
    if action=="checkin-time" and x.joined then x.now=math.max(x.now,x.engine.Ad().draft.startAt-1800);return true,"Local test clock advanced." end
    if action=="join" then local ok,why=x.engine.Join(x.id,x.player.guid,x.player);if ok then x.joined=true end;return ok,why end
    if action=="leave" then
        local ok,why=x.engine.Leave(x.id,x.player.guid)
        if ok then x.joined=false;if x.mode=="join" then R.EndPreview() end end
        return ok,why
    end
    if action=="checkin" then return x.engine.CheckIn(x.id,x.player.guid) end
    return false,"Action unavailable."
end
function R.PreviewAction(action)
    local ok,why,result,notice=PreviewAction(action)
    if ok and preview then PreviewChanged() end
    return ok,why,result,notice
end
function R.RunPlayerPreviewSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    for _,client in ipairs({"forever","retail"}) do
        local ok,err=pcall(function()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400
            local h,a=Copy(s),Copy(s)
            h.guid,h.name="Player-0-TESTHOST","Test organizer"
            a.guid,a.name,a.level="Player-0-TESTPLAYER","You (local test)",30
            local d=T.DraftDefaults();d.name="Test Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.bestOf=3
            d=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            local x=assert(PreparePreview(s,h,a,d,n))
            assert(x.engine.Ad().count==1 and not x.bracket and not StartPreviewBracket(x))
            assert(x.engine.Join(x.id,a.guid,a));x.joined=true
            assert(not StartPreviewBracket(x) and x.now==n and not x.bracket)
            x.now=d.startAt-1800;assert(x.engine.CheckIn(x.id,a.guid))
            assert(StartPreviewBracket(x) and x.now==d.startAt)
            local v=x.bracket.Snapshot();local m=assert(PreviewMatch(x,v))
            assert(v.scope=="SIMULATED" and m.score==0 and m.opponentScore==0 and m.bestOf==3 and m.opponent==x.rival.name)
            assert(not StartPreviewBracket(x) and not x.engine.Leave(x.id,a.guid))
            v.rounds={};assert(PreviewMatch(x,x.bracket.Snapshot()))
        end)
        if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..client.." player rehearsal / bracket / ready match"..(ok and "" or ": "..tostring(err)))
    end
    return p,f
end
function R.RunShowcaseSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    for _,client in ipairs({"forever","retail"}) do
        local ok,err=pcall(function()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local n=1795622400;local h,a=Copy(s),Copy(s)
            h.guid,h.name="Player-0-TESTHOST","Organizer"
            a.guid,a.name,a.level="Player-0-TESTPLAYER","You (local test)",30
            local d=T.DraftDefaults();d.name="Test Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.capacity=8
            d=assert(T.ValidateDraft(client,d,n,s.region,s.ruleset,s.faction))
            local x=assert(PreparePreview(s,h,a,d,n,"host",5))
            assert(x.engine.Ad().count==5 and not x.joined)
            assert(FillPreview(x,8) and x.engine.Ad().count==8)
            assert(StartPreviewBracket(x))
            assert(#x.bracket.Snapshot().slots==8 and not PreviewMatch(x,x.bracket.Snapshot()))
            local y=assert(PreparePreview(s,h,a,d,n,"join",6))
            assert(y.engine.Join(y.id,a.guid,a));y.joined=true
            assert(not StartPreviewBracket(y));y.now=d.startAt-1800
            assert(y.engine.CheckIn(y.id,a.guid) and StartPreviewBracket(y))
            local v=y.bracket.Snapshot()
            local found=0
            for _,g in ipairs(v.slots) do if g then found=found+1 end end
            assert(found==7 and y.role=="player")
            local own
            for i=1,7 do
                own=PreviewMatch(y,y.bracket.Snapshot())
                if own then break end
                local ok,why,result=SimulatePreviewGame(y)
                assert(ok and result and result.spectated,why)
            end
            assert(own,"Expected an assigned local player match")
            local ok,why,result=SimulatePreviewGame(y)
            assert(ok and result and result.scope=="SIMULATED",why)
            assert(result.opponent==own.opponent and result.complete==true)
            assert((result.outcome=="won" and result.score==1 and result.opponentScore==0 and result.advanced)
                or (result.outcome=="lost" and result.score==0 and result.opponentScore==1 and not result.advanced))

            local rows=assert(MakeCatalog(s,a,n,date or os and os.date))
            assert(#rows.entries==4)
            for i,e in ipairs(rows.entries) do
                local ad=e.engine.Ad()
                assert(P.Matches(s,ad) and ad.count<ad.draft.capacity and ad.draft.capacity==2^(i+1))
            end
            local games=0
            while x.bracket.Snapshot().state=="running" do
                assert(SimulatePreviewGame(x));games=games+1;assert(games<=7)
            end
            assert(games==7 and x.bracket.Snapshot().champion)
            assert(not SimulatePreviewGame(x))
            local z=assert(PreparePreview(s,h,a,d,n,"host",4))
            assert(StartPreviewBracket(z))
            local view=z.bracket.Snapshot()
            local first,ready=FeaturedMatch(z,view)
            assert(first and #ready>=2)
            z.featured=ready[2].id
            assert(SelectedMatch(z,view).id==ready[2].id)
            z.broadcast=true;assert(SelectedMatch(z,view).id==ready[2].id)
            assert(StartDemo(z) and z.demo.match==ready[2].id)
            for i=1,7 do assert(AdvanceDemo(z)) end
            local ok2,why2,outcome2=AdvanceDemo(z)
            assert(ok2 and outcome2 and outcome2.spectated and outcome2.duration==8,why2)
            assert(not z.demo)
            local good,_,_,notice=StartOffline(z)
            assert(good and notice.notice=="started" and z.offline.remaining==300)
            assert(AdvanceOffline(z,60) and z.offline.remaining==240)
            local ok3,_,_,notice2=StopOffline(z,true)
            assert(ok3 and notice2.notice=="reconnected" and not z.offline)
            assert(StartOffline(z))
            local ok4,_,_,notice3=AdvanceOffline(z,300)
            assert(ok4 and notice3.notice=="forfeited" and not z.offline)
        end)
        if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..client.." hosted and joined showcase draw"..(ok and "" or ": "..tostring(err)))
    end
    return p,f
end
function R.RunPrivateNetworkSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    for _,client in ipairs({"forever","retail"}) do
        local ok,err=pcall(function()
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local now=1795622400
            local function clock()return now end
            local function tick()now=now+1 end
            local actors={}
            for _,name in ipairs({"host","one","two"}) do local a=Copy(s);a.guid="Player-1-"..name:upper();a.name=name;a.level=30;actors[name]=a end
            local function resolve(sender)return actors[sender]end
            local roots={}
            local function Open(name,role)
                local r=roots[name] or {};roots[name]=r
                local d=ns.CompetitiveStorage.NewPrivateTournamentFixture(function()return r.account,r.character end,
                    function(a,c)r.account=a;r.character=c end,function()return client end,function()return actors[name].guid end)
                d.MarkLoaded()
                return R.OpenRegistrationSession(s,actors[name],clock,resolve,{
                    ReadTournamentJournal=d.ReadTournamentTestJournal,CommitTournamentJournal=d.CommitTournamentTestJournal},role)
            end
            local host=assert(Open("host","host"))
            local d=T.DraftDefaults();d.name="Private Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00";d.capacity=4;d.bestOf=1
            local ad=assert(host.Publish(assert(T.ValidateDraft(client,d,now,s.region,s.ruleset,s.faction))))
            local clients={}
            local function Exchange(name,w,body)
                tick()
                local replies=assert(host.Receive(name,assert(body)))
                for _,packet in ipairs(replies) do assert(w.Receive("host",packet)) end
            end
            for _,name in ipairs({"one","two"}) do
                local w=assert(Open(name,"player"));clients[name]=w
                Exchange(name,w,w.Query(actors.host.guid))
                Exchange(name,w,w.Join(actors.host.guid,ad.id))
            end
            now=ad.draft.startAt-1800
            for _,name in ipairs({"one","two"}) do Exchange(name,clients[name],clients[name].Action("C")) end
            now=ad.draft.startAt
            assert(host.StartBracket(actors.host.guid))
            local match
            for _,round in ipairs(host.BracketSnapshot().rounds) do for _,m in ipairs(round) do if m.state=="ready" then match=m end end end
            assert(match)
            local assignment=assert(host.PrivateAssign(match.id))
            assert(not host.PrivateAssign(match.id))
            local function MatchRequest(name,op,term,serial,outcome)
                local w=clients[name]
                local nonce=assert(w.ReserveProgress())
                local request=assert(R.PrivateMatchRequest(s,op,nonce,ad.id,match.id,term,serial,outcome))
                tick()
                local reply=assert(R.ReceivePrivateMatchRequest(s,host,name,request))
                return assert(R.DecodePrivateMatchReply(s,nonce,reply[1]))
            end
            for _,name in ipairs({"one","two"}) do
                local w=clients[name];local o=MatchRequest(name,"I")
                assert(o.serial==assignment.serial and not o.reported)
                assert(w.ArmPrivateSeat({event=ad.id,owner=ad.owner,peer=o.peer,match=o.match,game=o.game,
                    attempt=o.attempt,term=o.term,serial=o.serial,phase="armed"}))
                assert(MatchRequest(name,"K",o.term,o.serial).ready)
                if name=="one" then
                    tick();assert(not host.PrivateReport(name,ad.id,o.match,o.term,o.serial,"won"))
                end
            end
            assert(host.PrivateOffer().ready1 and host.PrivateOffer().ready2)
            assert(not host.PrivateReport("host",ad.id,match.id,assignment.term,assignment.serial,"won"))
            local winner=actors.one.guid
            for _,name in ipairs({"one","two"}) do
                local w=clients[name];assert(w.RecordPrivateSeat(winner))
                clients[name]=assert(Open(name,"player"))
                assert(clients[name].PrivateSeat().winner==winner)
                local receipt=MatchRequest(name,"U",assignment.term,assignment.serial,name=="one" and "won" or "lost")
                assert(receipt.status==(name=="one" and "pending" or "confirmed"))
                assert(clients[name].ClearPrivateSeat())
            end
            assert(host.BracketSnapshot().champion==winner and not host.PrivateOffer())
            tick();assert(host.PrivateReport("one",ad.id,match.id,assignment.term,assignment.serial,"won"))
            assert(not host.PrivateFinalize())
            for _,name in ipairs({"one","two"}) do
                local w=clients[name]
                local nonce=assert(w.ReserveProgress())
                local f=assert(R.OpenPrivateProgressFetch(s,ad.owner,ad.id,actors[name].guid,nonce,clock,resolve))
                while not f.Snapshot() do
                    tick();local parts=assert(host.Receive(name,assert(f.Request())))
                    for _,packet in ipairs(parts) do assert(f.Receive("host",packet)) end
                end
                local v=assert(f.Snapshot());assert(v.bracket.champion==winner)
                local seq=assert(w.ReserveProgress())
                local e=assert(R.OpenPrivateProgressEcho(s,actors[name],v,seq))
                local receipt
                while true do
                    local packet,last=e.Next();assert(packet);tick()
                    receipt=host.PrivateReceiveEcho(name,packet)
                    if last then break end
                    assert(not receipt)
                end
                assert(receipt and R.PrivateEchoReceipt(s,seq,v.control.term,v.bracket.revision,receipt[1]))
                if name=="one" then assert(not host.PrivateFinalize()) end
            end
            assert(host.PrivateFinalize())
            local reopened=assert(Open("host","host"));local history=reopened.PrivateHistory()
            assert(#history==1 and history[1].champion=="one" and history[1].scope=="PRIVATE_TEST")
            -- The shared validator accepts only the marked, complete LOCAL result.
            local ctx={scope="PRIVATE_TEST",client=client,me=winner,peer=actors.two.guid,cycle=1,
                agreement={scope="PRIVATE_TEST",state="candidate",candidate=true,rankEligible=false,session=ns.TournamentRecovery.PrivateSession(assignment)}}
            local r={scope="LOCAL",client=client,id=1,opponent={guid=actors.two.guid},rankEligible=false,kind="standard",
                duelMode="tournament",tournamentSession=ctx.agreement.session,reason="matching_result_and_finish",outcomeObserved=true,
                finishObserved=true,resultObserved=true,conflict=false,endType="knockout",outcome="won"}
            assert(ns.ResultConfirmation.MakePrivateTournamentStatement(ctx,r))
            r.tournamentSession="wrong:seat";assert(not ns.ResultConfirmation.MakePrivateTournamentStatement(ctx,r))
        end)
        if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | ISOLATED PRIVATE TEST | "..(ok and "PASS " or "FAIL ")..client.." registration to finalized archive"..(ok and "" or ": "..tostring(err)))
    end
    return pass,fail
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
ns.Diagnostics.Register("Tournament private network / isolated lifecycle QA","deep",function()
    local log={};local p,f=R.RunPrivateNetworkSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==2 and "PASS" or "FAIL",string.format("%d passed / %d failed (ISOLATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament showcase / isolated entry QA","deep",function()
    local log={};local p,f=R.RunShowcaseSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==2 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament player rehearsal / isolated match QA","deep",function()
    local log={};local p,f=R.RunPlayerPreviewSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==2 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
ns.Diagnostics.Register("Tournament host recovery / isolated checkpoint QA","deep",function()
    local log={};local p,f=R.RunHostRecoverySelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==72 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
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

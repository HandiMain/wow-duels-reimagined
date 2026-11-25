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
        or (a.state~="open" and a.state~="cancelled") then return nil end
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
    return D
end
-- Only complete, sender-bound, exact-community advertisements enter the cache.
-- Caller identities are fixture inputs, not proof of actual network origin.
local function Cache(s,clock)
    if not P.Key(s) then return nil end
    s=Copy(s);local D,rows={},{}
    local function Prune(n)
        for id,r in pairs(rows) do
            if not BlocksCreation(r.ad) and n>=r.ad.draft.startAt then rows[id]=nil end
        end
    end
    function D.Accept(sender,ad)
        local n=Now(clock)
        if not n or type(ad)~="table" or not P.Matches(s,ad) or ad.scope~="SIMULATED" or ad.version~=1
            or not Guid(sender) or ad.owner~=sender or not Name(ad.organizer) or not Whole(ad.publishedAt,1,n)
            or not Whole(ad.serial,1,2147483647) or not Whole(ad.revision,1,2147483647)
            or ad.id~=ID(sender,ad.publishedAt,ad.serial) or (ad.state~="open" and ad.state~="cancelled") then return false end
        local clean=Draft(s,ad.draft,ad.publishedAt)
        if not clean or not Whole(ad.count,0,clean.capacity) then return false end
        -- Never resurrect an expired advertisement. A known event may still
        -- receive its owner-authorized cancellation after the scheduled start.
        if n>=clean.startAt and not (ad.state=="cancelled" and rows[ad.id] and BlocksCreation(rows[ad.id].ad)) then return false end
        local expected={scope="SIMULATED",version=1,id=ad.id,owner=sender,organizer=ad.organizer,client=s.client,region=s.region,
            ruleset=s.ruleset,faction=s.faction,state=ad.state,publishedAt=ad.publishedAt,serial=ad.serial,revision=ad.revision,draft=clean,count=ad.count}
        if not Equal(ad,expected) then return false end
        Prune(n)
        local old=rows[ad.id]
        if old then
            if ad.revision<old.ad.revision or not Equal(old.ad.draft,clean) or old.ad.organizer~=ad.organizer
                or (old.ad.state=="cancelled" and ad.state~="cancelled")
                or (ad.revision==old.ad.revision and not Equal(old.ad,expected)) then return false end
        else
            local count=0
            for _,r in pairs(rows) do
                count=count+1
                if BlocksCreation(ad) and BlocksCreation(r.ad) and r.ad.owner==sender then return false end
            end
            if count>=64 then return false end
        end
        rows[ad.id]={ad=expected,seen=n};return true
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
            reply=Fragments(key,seq,EncodeAd(ad))
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
        if a[1]=="X" then
            if #a~=5 or a[4]~=pending.id or not Number(a[5],2,2147483647)
                or not commitment or commitment.owner~=actor.guid or commitment.id~=pending.id then return false end
            if not Persist(seq,nil,nil,"ack") then return false end
            pending=nil;commitment=nil
            return true,"cancelled"
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
        return true,ok and "confirmed" or "refused"
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
        return Host(s,h,clock,journal.checkpoint.host)
    end
    local function Save(engine,wire,action)
        if not Fresh() then return false end
        local snap=engine.Save()
        local candidate=Copy(journal)
        candidate.revision=candidate.revision+1
        if action=="host_open" then candidate.sequence=candidate.sequence+1 end
        candidate.checkpoint={host=snap,receipts=wire and wire.SaveReceipts() or {}}
        local a=snap.ad
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
        local e=Open();if not e then return nil end
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
    return f==0 and p==10 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
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

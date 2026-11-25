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
local function Host(s,h,clock)
    if not P.Key(s) or not Actor(s,h) then return nil end
    s,h=Copy(s),Copy(h)
    local D,event,roster,serial={},nil,{},0
    local function Count() local n=0;for _ in pairs(roster) do n=n+1 end;return n end
    local function Active(id,n) return event and event.id==id and event.state=="open" and n and n<event.draft.startAt end
    local function Bump() event.revision=event.revision+1 end
    function D.Ad() if event then local a=Copy(event);a.count=Count();return a end end
    function D.Publish(sender,d)
        local n=Now(clock)
        if sender~=h.guid or not n then return nil,"Organizer or time unavailable." end
        if event and event.state=="open" and n<event.draft.startAt then return nil,"Cancel the current event first." end
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
    local function Prune(n) for id,r in pairs(rows) do if n>=r.ad.draft.startAt then rows[id]=nil end end end
    function D.Accept(sender,ad)
        local n=Now(clock)
        if not n or type(ad)~="table" or not P.Matches(s,ad) or ad.scope~="SIMULATED" or ad.version~=1
            or not Guid(sender) or ad.owner~=sender or not Name(ad.organizer) or not Whole(ad.publishedAt,1,n)
            or not Whole(ad.serial,1,2147483647) or not Whole(ad.revision,1,2147483647)
            or ad.id~=ID(sender,ad.publishedAt,ad.serial) or (ad.state~="open" and ad.state~="cancelled") then return false end
        local clean=Draft(s,ad.draft,ad.publishedAt)
        if not clean or n>=clean.startAt or not Whole(ad.count,0,clean.capacity) then return false end
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
            local count=0;for _ in pairs(rows) do count=count+1 end
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
    return x.joined and "registered" or "idle"
end
function R.StartPreview(d)
    if Current() then return false,"End the current test first." end
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
if ns.Diagnostics then ns.Diagnostics.Register("Tournament registration / isolated host QA","deep",function()
    local log={};local p,f=R.RunSelfTest(function(line)log[#log+1]=line end)
    return f==0 and p==13 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end) end

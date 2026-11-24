local _,ns=...
-- Isolated peer merge model. Pages are logical tables, NOT wire packets.
-- No live sender, receiver, timestamps, persistence or rating authority.
local P={}
ns.LeaderboardSync=P
local VERSION,PAGE=1,16
local LIMIT=ns.MatchLedger.GetCapacity()
function P.GetPageLimit() return math.ceil(LIMIT/PAGE) end
local RULE="elo-trial-2"
local function Int(v,lo,hi) return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
local function Guid(v) return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil end
local function Token(v) return type(v)=="string" and #v<=32 and v:match("^[%w%-]+$")~=nil end
local function Array(v,max)
    if type(v)~="table" then return nil end
    local n=0;for k in pairs(v) do n=n+1;if not Int(k,1,max) or n>max then return nil end end
    for i=1,n do if v[i]==nil then return nil end end
    return n
end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Copy(t)
    local o={};for k,v in pairs(t) do o[k]=type(v)=="table" and Copy(v) or v end;return o
end
-- Stable ID partitions and two bounded rolling checksums, for comparison
-- hints only. Neither checksum authenticates evidence or proves completeness.
local GROUPS,H1,H2=128,2147483647,2147483629
local function Hash(h,text,mul,mod)
    for i=1,#text do h=(h*mul+text:byte(i))%mod end
    return (h*mul)%mod -- zero-byte field separator
end
local function Group(id) return Hash(1,id,131,H1)%GROUPS+1 end
local function GroupInfo(v)
    if type(v)~="table" or not Int(v.count,0,LIMIT) or not Int(v.a,0,H1-1)
        or not Int(v.b,0,H2-1) then return false end
    for k in pairs(v) do if k~="count" and k~="a" and k~="b" then return false end end
    if v.count==0 and (v.a~=1 or v.b~=1) then return false end
    return true
end
function P.GetGroupCount() return GROUPS end
function P.DeltaGroupSpec(group,expected)
    if not Int(group,1,GROUPS) or not GroupInfo(expected) or expected.count==0 then return nil end
    return table.concat({group,expected.count,expected.a,expected.b},",")
end
-- Check group membership and exact page size before the normal atomic merge.
function P.ValidateDeltaPage(group,expected,page)
    if not P.DeltaGroupSpec(group,expected) or type(page)~="table" then return false end
    local total=math.ceil(expected.count/PAGE)
    if page.total~=total or not Int(page.index,1,total) then return false end
    local n=Array(page.entries,PAGE)
    if n~=math.min(PAGE,expected.count-(page.index-1)*PAGE) then return false end
    for _,e in ipairs(page.entries) do
        if type(e)~="table" or type(e.id)~="string" or #e.id>220 or Group(e.id)~=group then return false end
    end
    return true
end
local function Less(a,b) return a[1]<b[1] or (a[1]==b[1] and a[2]<b[2]) end
local function Clocks(raw)
    local n=Array(raw,2);if not n or n==0 then return nil end
    local clean={}
    for i=1,n do
        local v=raw[i]
        if Array(v,2)~=2 or not Int(v[1],1,4102444800) or not Int(v[2],1,4102444800)
            or math.abs(v[1]-v[2])>5 then return nil end
        clean[i]={v[1],v[2]}
        if i==2 and not Less(clean[1],clean[2]) then return nil end
    end
    return clean
end
local function MergeClocks(a,b)
    local out={};for _,list in ipairs({a or {},b or {}}) do
        for _,v in ipairs(list) do
            local duplicate=false;for _,x in ipairs(out) do if Equal(x,v) then duplicate=true end end
            if not duplicate then out[#out+1]={v[1],v[2]} end
        end
    end
    table.sort(out,Less);while #out>2 do out[#out]=nil end
    return #out>0 and out or nil
end
-- For peer evidence, times are part of each original statement. The relay
-- cannot substitute a different clock pair without changing the claims.
local function PeerClocks(variants)
    local out
    for _,r in ipairs(variants) do out=MergeClocks(out,{{r.time1,r.time2}}) end
    return out
end
local function Validate(client,saved,scope)
    if type(saved)~="table" or saved.version~=VERSION or saved.scope~=scope or saved.client~=client
        or saved.rule~=RULE or type(saved.clocks)~="table" or type(saved.ledger)~="table" then return nil end
    local open=scope=="PEER" and ns.MatchLedger.OpenPeer or ns.MatchLedger.OpenSimulated
    local ledger=open(client,saved.ledger)
    if not ledger then return nil end
    local clean={version=VERSION,scope=scope,client=client,rule=RULE,ledger=ledger.Save(),clocks={}}
    for id,v in pairs(saved.clocks) do
        if not clean.ledger.entries[id] then return nil end
        local c=Clocks(v);if not c then return nil end;clean.clocks[id]=c
    end
    if scope=="PEER" then
        for id,variants in pairs(clean.ledger.entries) do
            if not Equal(clean.clocks[id],PeerClocks(variants)) then return nil end
        end
    end
    if not Equal(clean,saved) then return nil end
    return clean
end
local function Open(client,saved,epoch,scope)
    scope=scope or "SIMULATED"
    local open=scope=="PEER" and ns.MatchLedger.OpenPeer or ns.MatchLedger.OpenSimulated
    if client~="forever" and client~="retail" then return nil,"client" end
    if epoch~=nil and not ns.SeasonRules.Schedule(epoch,epoch) then return nil,"invalid_schedule" end
    local data
    if saved==nil then
        data={version=VERSION,scope=scope,client=client,rule=RULE,
            ledger=assert(open(client)).Save(),clocks={}}
    else data=Validate(client,saved,scope) end
    if not data then return nil,"invalid_store" end
    -- The ledger owns canonical records. Only incoming evidence is validated
    -- during a merge; the existing ledger is opened once per isolated node.
    local ledger=assert(open(client,data.ledger))
    data.ledger=nil
    local D={}
    local sortedIDs,deltaCache
    local revision=1
    local work={groups=0,records=0,indexed=0}
    local function Mark(id,added)
        if added then sortedIDs=nil end
        if deltaCache then
            local group=Group(id)
            if added then
                local ids=deltaCache.groups[group];ids[#ids+1]=id
            end
            deltaCache.dirty[group]=true;deltaCache.partial[group]=nil
        end
    end
    local function Merge(incoming)
        local records,stagedClocks={},{}
        for id,variants in pairs(incoming.ledger.entries) do
            for _,r in ipairs(variants) do records[#records+1]=r end
            stagedClocks[id]=MergeClocks(data.clocks[id],incoming.clocks[id])
        end
        local ok,why,changes=ledger.MergeBatch(records)
        if not ok then return false,why end
        local changed=why=="merged"
        for id,added in pairs(changes) do Mark(id,added) end
        if scope=="PEER" then
            for id in pairs(incoming.ledger.entries) do
                stagedClocks[id]=PeerClocks(ledger.ReadVariants(id))
            end
        end
        for id,clocks in pairs(stagedClocks) do
            if not Equal(data.clocks[id],clocks) then
                data.clocks[id]=clocks;changed=true
                Mark(id,false)
            end
        end
        if changed then revision=revision+1 end
        return true,changed and "merged" or "unchanged"
    end
    function D.GetEvidenceRevision() return revision end
    -- Direct fixture observation: t1/t2 correspond to canonical player1/2.
    -- A two-clock fixture is not proof that either player really reported it.
    function D.Observe(record,t1,t2)
        local validate=scope=="PEER" and ns.ResultConfirmation.ValidatePeerRecord or ns.ResultConfirmation.ValidateSimulatedRecord
        local clean=validate(record)
        if not clean or clean.client~=client then return false,"invalid_record" end
        local clocks={}
        if scope=="PEER" then
            if t1~=clean.time1 or t2~=clean.time2 then return false,"invalid_time" end
        end
        if t1~=nil or t2~=nil then
            local c=Clocks({{t1,t2}});if not c then return false,"invalid_time" end;clocks[clean.id]=c
        end
        local l=assert(open(client));assert(l.Insert(clean))
        return Merge({ledger=l.Save(),clocks=clocks})
    end
    function D.Save() local saved=Copy(data);saved.ledger=ledger.Save();return saved end
    function D.MergeSaved(saved)
        local clean=Validate(client,saved,scope)
        if not clean then return false,"invalid_evidence" end
        return Merge(clean)
    end
    -- Cache only the canonical ID order; never retain exported record copies.
    local function IDs()
        if not sortedIDs then
            sortedIDs=ledger.ListIDs()
        end
        return sortedIDs
    end
    local function Page(token,index,ids,total)
        local page={version=VERSION,scope=scope,client=client,rule=RULE,token=token,index=index,total=total,entries={}}
        for j=(index-1)*PAGE+1,math.min(index*PAGE,#ids) do
            local id=ids[j];page.entries[#page.entries+1]={id=id,records=ledger.ReadVariants(id),
                clocks=data.clocks[id] and Copy(data.clocks[id]) or nil}
        end
        return page
    end
    -- One requested page, independently frozen. Different requests may see
    -- different snapshots; no global completeness claim.
    function D.ExportPage(token,index)
        if not Token(token) then return nil,"token" end
        local ids=IDs();local total=math.max(1,math.ceil(#ids/PAGE))
        if not Int(index,1,total) then return nil,"page" end
        return Page(token,index,ids,total)
    end
    function D.Export(token)
        if not Token(token) then return nil,"token" end
        local ids=IDs();local total=math.max(1,math.ceil(#ids/PAGE));local pages={}
        for i=1,total do pages[i]=Page(token,i,ids,total) end
        return pages
    end
    -- Prepare derived comparison work cooperatively. A mutation invalidates
    -- only the affected group, including any unfinished hash of that group.
    local function InitDelta()
        if not deltaCache then
            local groups,info={},{}
            for i=1,GROUPS do groups[i]={};info[i]={count=0,a=1,b=1} end
            deltaCache={groups=groups,info=info,dirty={},partial={},seed=IDs(),nextID=1}
        end
        return deltaCache
    end
    local function Partition(d,budget)
        local used=0
        while d.seed and d.nextID<=#d.seed and used<budget do
            local id=d.seed[d.nextID];local g=Group(id);local ids=d.groups[g]
            ids[#ids+1]=id;d.dirty[g]=true;d.nextID=d.nextID+1;used=used+1
        end
        if d.seed and d.nextID>#d.seed then d.seed=nil;d.nextID=nil end
        work.indexed=work.indexed+used
        return used
    end
    local function Refresh(d,g,budget)
        if not d.dirty[g] or budget==0 then return 0 end
        local ids=d.groups[g]
        local p=d.partial[g]
        if not p then
            table.sort(ids);p={nextID=1,row={count=#ids,a=1,b=1}};d.partial[g]=p
        end
        local row=p.row;local used=0
        while p.nextID<=#ids and used<budget do
            local id=ids[p.nextID]
            local function Add(field)
                row.a=Hash(row.a,field,131,H1)
                row.b=Hash(row.b,field,257,H2)
            end
            Add(id)
            local variants=ledger.ReadVariants(id)
            Add(tostring(#variants))
            for _,r in ipairs(variants) do Add(r.statement1);Add(r.statement2) end
            local clocks=data.clocks[id] or {}
            Add(tostring(#clocks))
            for _,c in ipairs(clocks) do Add(tostring(c[1]));Add(tostring(c[2])) end
            p.nextID=p.nextID+1;used=used+1
        end
        work.records=work.records+used
        if p.nextID>#ids then
            d.info[g]=row;d.dirty[g]=nil;d.partial[g]=nil;work.groups=work.groups+1
        end
        return used
    end
    local function Delta(group)
        local d=InitDelta()
        Partition(d,LIMIT)
        if group then Refresh(d,group,LIMIT)
        else for g=1,GROUPS do Refresh(d,g,LIMIT) end end
        return d
    end
    -- Explicit fixture work budget, NOT a time guarantee. Initial sorted ID
    -- extraction and per-group sorting are still synchronous. No timer.
    function D.PrepareDelta(budget)
        if not epoch or not Int(budget,1,64) then return nil,"invalid_budget" end
        local d=InitDelta()
        local used=Partition(d,budget)
        if not d.seed then
            for g=1,GROUPS do
                if used>=budget then break end
                used=used+Refresh(d,g,budget-used)
            end
        end
        return not d.seed and next(d.dirty)==nil,used
    end
    function D.GetDeltaWork() return Copy(work) end
    local function Context()
        if epoch then
            local descriptor=ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch)
            return descriptor and descriptor..(scope=="PEER" and "|P" or "")
        end
    end
    function D.DeltaSummary()
        local context=Context();if not context then return nil,"season_context_required" end
        return {version=1,scope=scope,context=context,groups=Copy(Delta().info)}
    end
    function D.PlanDelta(remote)
        local context=Context()
        if not context or type(remote)~="table" or remote.version~=1 or remote.scope~=scope
            or remote.context~=context or Array(remote.groups,GROUPS)~=GROUPS then return nil,"invalid_summary" end
        for k in pairs(remote) do if k~="version" and k~="scope" and k~="context" and k~="groups" then return nil,"invalid_summary" end end
        local total=0
        for _,g in ipairs(remote.groups) do
            if not GroupInfo(g) then return nil,"invalid_summary" end
            total=total+g.count;if total>LIMIT then return nil,"invalid_summary" end
        end
        local localInfo=Delta().info
        local plan={scope=scope,rankEligible=false,completeness="unknown",different=0,pulls={}}
        for i,g in ipairs(remote.groups) do
            if not Equal(g,localInfo[i]) then
                plan.different=plan.different+1
                -- A peer with no records in this group has nothing to supply.
                -- Reverse planning remains necessary for two-way convergence.
                if g.count>0 then plan.pulls[#plan.pulls+1]={group=i,expected=Copy(g),pages=math.ceil(g.count/PAGE)} end
            end
        end
        return plan
    end
    -- Refuse stale group requests before producing a page. A successful
    -- export is not a frozen multi-page session or proof of remote identity.
    -- Logical pages only; existing Receive validates every canonical record.
    function D.ExportDeltaPage(token,group,expected,index)
        if not Context() or not Token(token) or not Int(group,1,GROUPS)
            or not GroupInfo(expected) or expected.count==0 then return nil,"invalid_group" end
        local d=Delta(group)
        if not Equal(expected,d.info[group]) then return nil,"stale_group" end
        local total=math.ceil(expected.count/PAGE)
        if not Int(index,1,total) then return nil,"page" end
        return Page(token,index,d.groups[group],total)
    end
    -- Sender and request token are injected by a simulation, not authenticated
    -- WoW events. Accept only bounded pages; validate all before a merge.
    function D.Receive(page,sender,expected,token)
        if not Guid(sender) or sender~=expected or not Token(token) or type(page)~="table"
            or page.version~=VERSION or page.scope~=scope or page.client~=client or page.rule~=RULE or page.token~=token
            or not Int(page.total,1,math.ceil(LIMIT/PAGE)) or not Int(page.index,1,page.total) then return false,"invalid_page" end
        local n=Array(page.entries,PAGE)
        if not n or (page.index<page.total and n~=PAGE) or (n==0 and page.total~=1) then return false,"invalid_page" end
        local incoming={version=VERSION,scope=scope,client=client,rule=RULE,
            ledger={version=1,scope=scope,client=client,entries={}},clocks={}}
        local prior
        for _,e in ipairs(page.entries) do
            if type(e)~="table" or type(e.id)~="string" or #e.id>220 or (prior and e.id<=prior)
                or type(e.records)~="table" then return false,"invalid_entry" end
            for k in pairs(e) do if k~="id" and k~="records" and k~="clocks" then return false,"invalid_entry" end end
            prior=e.id;incoming.ledger.entries[e.id]=e.records;incoming.clocks[e.id]=e.clocks
        end
        for k in pairs(page) do
            if k~="version" and k~="scope" and k~="client" and k~="rule" and k~="token"
                and k~="index" and k~="total" and k~="entries" then return false,"invalid_page" end
        end
        local clean=Validate(client,incoming,scope);if not clean then return false,"invalid_evidence" end
        return Merge(clean)
    end
    local function Replay(rule,options)
        local s=ledger.Snapshot()
        local eligible=ledger.Save();local times={};local missing,conflict=0,0
        for _,r in ipairs(s.matched) do
            local c=data.clocks[r.id]
            if not c then missing=missing+1;eligible.entries[r.id]=nil
            elseif c[2] then conflict=conflict+1;eligible.entries[r.id]=nil
            else times[r.id]=math.max(c[1][1],c[1][2]) end
        end
        local replay=scope=="PEER" and ns.RatingEngine.ReplayPeer or ns.RatingEngine.ReplaySimulated
        local result,why=replay(client,eligible,times,rule,options)
        if not result then return nil,why end
        result.knownMatched=#s.matched;result.missingTime=missing;result.timeDisputed=conflict
        result.completeness="unknown";return result
    end
    function D.GetSeasonEpoch() return epoch end
    function D.GetScope() return scope end
    function D.Replay()
        if epoch then return nil,"season_context_required" end
        return Replay(RULE)
    end
    local function ReplaySeason(options)
        if epoch and (type(options)~="table" or options.epoch~=epoch) then return nil,"schedule_mismatch" end
        return Replay(ns.SeasonRules.BALANCED_ID,options)
    end
    function D.ReplaySeasonSimulated(options)
        if scope~="SIMULATED" then return nil,"wrong_scope" end
        return ReplaySeason(options)
    end
    function D.ReplaySeasonPeer(options)
        if scope~="PEER" then return nil,"wrong_scope" end
        return ReplaySeason(options)
    end
    return D
end
function P.OpenSimulated(client,saved) return Open(client,saved,nil,"SIMULATED") end
function P.OpenSeasonSimulated(client,epoch,saved)
    if epoch==nil then return nil,"invalid_schedule" end
    return Open(client,saved,epoch,"SIMULATED")
end
function P.OpenSeasonPeer(client,epoch,saved)
    if epoch==nil then return nil,"invalid_schedule" end
    return Open(client,saved,epoch,"PEER")
end
function P.GetSnapshot() return {scope="LOCAL",state="disabled",rankEligible=false,version=VERSION} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b,c="Player-1-AAA","Player-2-BBB","Player-3-CCC"
    for _,client in ipairs({"forever","retail"}) do
        local function Record(n,w,l)
            w=w or a;l=l or b;local x,y=w,l;if y<x then x,y=y,x end
            local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,
                player1=x,player2=y,winner=w,loser=l,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),
                statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
        end
        local function Node() return assert(Open(client)) end
        local function Send(src,dst,peer)
            for _,page in ipairs(assert(src.Export("request-1"))) do assert(dst.Receive(page,peer,peer,"request-1")) end
        end
        Case(client.." offline catch-up via third peer / convergence",function()
            local x,y,z=Node(),Node(),Node();x.Observe(Record(1),10,11);y.Observe(Record(2,b,c),20,20);z.Observe(Record(3,c,a),30,31)
            Send(x,y,a);Send(y,z,b);Send(z,y,c);Send(y,x,b)
            assert(Equal(x.Save(),y.Save()) and Equal(y.Save(),z.Save()) and Equal(x.Replay(),z.Replay()) and x.Replay().matched==3)
        end)
        Case(client.." duplicates and reverse page delivery",function()
            local x,y=Node(),Node();for i=1,33 do assert(x.Observe(Record(i),i,i))end
            local pages=x.Export("q");assert(#pages==3 and #pages[1].entries==16)
            for i=#pages,1,-1 do assert(y.Receive(pages[i],a,a,"q"));local ok,why=y.Receive(pages[i],a,a,"q");assert(ok and why=="unchanged")end
            assert(Equal(x.Save(),y.Save()) and Equal(x.Replay(),y.Replay()))
        end)
        Case(client.." missing page / later retry repairs",function()
            local x,y=Node(),Node();for i=1,17 do x.Observe(Record(i),i,i)end
            local pages=x.Export("q");assert(y.Receive(pages[2],a,a,"q"));assert(y.Replay().knownMatched==1 and y.Replay().completeness=="unknown")
            assert(y.Receive(pages[1],a,a,"q"));assert(Equal(x.Save(),y.Save()))
        end)
        Case(client.." snapshot pages frozen and isolated",function()
            local x,y=Node(),Node();x.Observe(Record(1),10,10);local pages=x.Export("q");x.Observe(Record(2),20,20)
            assert(y.Receive(pages[1],a,a,"q"));pages[1].entries[1].records[1].winner="bad";assert(y.Replay().matched==1 and x.Replay().matched==2)
        end)
        Case(client.." timestamp agreement and missing evidence",function()
            local x=Node();local r=Record(1);assert(x.Observe(r));assert(x.Replay().missingTime==1 and x.Replay().matched==0)
            assert(not x.Observe(r,10,16) and not x.Observe(r,10) and not x.Observe(r,10.5,11))
            assert(x.Observe(r,10,15));local s=x.Replay();assert(s.matched==1 and s.changes[1].time==15 and s.missingTime==0)
        end)
        Case(client.." conflicting clocks converge and exclude rating",function()
            local x,y,z=Node(),Node(),Node();local r=Record(1);x.Observe(r,20,21);y.Observe(r,10,11);z.Observe(r,30,30)
            Send(x,y,a);Send(y,z,b);Send(z,x,c);Send(x,y,a)
            assert(Equal(x.Save(),y.Save()) and Equal(x.Save(),z.Save()) and x.Replay().timeDisputed==1 and x.Replay().matched==0)
            assert(#x.Save().clocks[r.id]==2)
        end)
        Case(client.." outcome disputes relay even when offline",function()
            local x,y,z=Node(),Node(),Node();x.Observe(Record(1),10,10);y.Observe(Record(1,b,a),10,10)
            Send(x,y,a);Send(y,z,b);Send(z,x,c);assert(Equal(x.Save(),z.Save()) and x.Replay().disputed==1 and z.Replay().matched==0)
        end)
        Case(client.." delayed earlier match replays identically",function()
            local x,y=Node(),Node();x.Observe(Record(1),10,10);y.Observe(Record(2,b,c),20,20)
            local before=y.Replay();Send(x,y,a);Send(y,x,b);local after=y.Replay()
            assert(before.changes[1].winnerBefore~=after.changes[2].winnerBefore and Equal(x.Replay(),after))
        end)
        Case(client.." incompatible sender token client or rule refused",function()
            local x,y=Node(),Node();x.Observe(Record(1),10,10);local p=x.Export("q")[1];local before=y.Save()
            assert(not y.Receive(p,b,a,"q") and not y.Receive(p,a,a,"old"));p.rule="unknown";assert(not y.Receive(p,a,a,"q"));p.rule=RULE
            p.client=client=="forever" and "retail" or "forever";assert(not y.Receive(p,a,a,"q"));p.client=client;p.scope="LOCAL"
            assert(not y.Receive(p,a,a,"q") and Equal(before,y.Save()))
        end)
        Case(client.." malformed or oversized page atomic rejection",function()
            local x,y=Node(),Node();x.Observe(Record(1),10,10);x.Observe(Record(2),20,20);local p=x.Export("q")[1];local before=y.Save()
            p.entries[2].records[1].winner=c;assert(not y.Receive(p,a,a,"q") and Equal(before,y.Save()))
            p=x.Export("q")[1];p.entries[2].clocks={{10,99}};assert(not y.Receive(p,a,a,"q") and Equal(before,y.Save()))
            p=x.Export("q")[1];p.entries[17]=p.entries[1];assert(not y.Receive(p,a,a,"q") and Equal(before,y.Save()))
        end)
        Case(client.." saved snapshot reopen and strict validation",function()
            local x=Node();x.Observe(Record(1),10,11);local s=x.Save();local y=assert(Open(client,s));assert(Equal(x.Replay(),y.Replay()))
            s.version=2;assert(not Open(client,s));s.version=1;s.clocks.extra={{1,1}};assert(not Open(client,s));s=x.Save();s.ledger.entries[Record(1).id][1].extra=true;assert(not Open(client,s))
            assert(Equal(x.Replay(),y.Replay()))
        end)
        Case(client.." no live writes or global completeness claims",function()
            local x,y=Node(),Node();Send(x,y,a);assert(y.Replay().completeness=="unknown" and not y.Replay().rankEligible and #y.Replay().standings==0)
        end)
    end
    Case("live sync remains disabled",function()local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)end)
    return passed,failed
end

function P.RunPageSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    for _,client in ipairs({"forever","retail"}) do
        local function Record(n,reverse)
            local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,reverse and "lost" or "won","1"},"|"),
                statement2=table.concat({"1",client,s,b,a,reverse and "won" or "lost","2"},"|")}
        end
        Case(client.." single pages equal full export and isolated copies",function()
            local x=assert(Open(client));for i=1,17 do assert(x.Observe(Record(i),i,i)) end
            local pages=assert(x.Export("q"));assert(#pages==2)
            for i=1,#pages do assert(Equal(pages[i],x.ExportPage("q",i))) end
            local p=x.ExportPage("q",1);p.entries[1].records[1].winner="bad";p.entries[1].clocks[1][1]=0
            assert(Equal(pages[1],x.ExportPage("q",1)) and not x.ExportPage("q",3))
        end)
        Case(client.." page order updates after insertion and conflict",function()
            local x=assert(Open(client));assert(x.Observe(Record(2),2,2));local old=x.ExportPage("q",1)
            assert(x.Observe(Record(1),1,1));local current=x.ExportPage("q",1);assert(#old.entries==1 and #current.entries==2 and current.entries[1].id==Record(1).id)
            assert(x.Observe(Record(1,true),1,1));assert(#x.ExportPage("q",1).entries[1].records==2 and #current.entries[1].records==1)
            assert(Equal(x.Export("q")[1],x.ExportPage("q",1)))
        end)
        Case(client.." empty and invalid requests preserve evidence",function()
            local x=assert(Open(client));local old=x.Save();local p=x.ExportPage("q",1)
            assert(p.total==1 and #p.entries==0 and Equal(p,x.Export("q")[1]))
            for _,i in ipairs({0,2,1.5,"1"}) do assert(not x.ExportPage("q",i)) end
            assert(not x.ExportPage("bad|token",1) and not x.ExportPage("q",nil) and Equal(old,x.Save()))
        end)
    end
    Case("page optimization stays simulation only",function()local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)end)
    return passed,failed
end

function P.RunMergeSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    for _,client in ipairs({"forever","retail"}) do
        local function Record(n,reverse,cycle)
            local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,reverse and "lost" or "won",tostring(cycle or 1)},"|"),
                statement2=table.concat({"1",client,s,b,a,reverse and "won" or "lost","2"},"|")}
        end
        Case(client.." atomic batch equals sequential canonical insertion",function()
            local l=assert(ns.MatchLedger.OpenSimulated(client));local other=assert(ns.MatchLedger.OpenSimulated(client))
            local records={Record(1),Record(2),Record(1,true),Record(1,false,3),Record(2)}
            for _,r in ipairs(records)do other.Insert(r)end
            assert(l.MergeBatch(records));assert(Equal(l.Save(),other.Save()))
            local ok,why=l.MergeBatch(records);assert(ok and why=="unchanged")
            records[1].winner="bad";local saved=l.Save();assert(not l.MergeBatch(records) and Equal(saved,l.Save()))
        end)
        Case(client.." capacity and malformed batch rollback",function()
            local l=assert(ns.MatchLedger.OpenSimulated(client,nil,2));assert(l.Insert(Record(1)));local saved=l.Save()
            local ok,why=l.MergeBatch({Record(1,true),Record(2),Record(3)});assert(not ok and why=="capacity" and Equal(saved,l.Save()))
            assert(not l.MergeBatch({Record(2),[3]=Record(1,true)}) and Equal(saved,l.Save()))
            assert(l.MergeBatch({Record(1,true),Record(2)}));assert(#l.Snapshot().disputed==1 and #l.Snapshot().matched==1)
            local rows=l.ReadVariants(Record(1).id);rows[1].winner="bad";local ids=l.ListIDs();ids[1]="bad"
            assert(l.ReadVariants(Record(1).id)[1].winner~="bad" and l.ListIDs()[1]~="bad")
        end)
        Case(client.." clock-only merge, duplicate and dispute preserve replay",function()
            local x=assert(Open(client));local r=Record(1);assert(x.Observe(r));local saved=x.Save()
            local ok,why=x.Observe(r,100,100);assert(ok and why=="merged" and x.Replay().matched==1)
            ok,why=x.Observe(r,100,100);assert(ok and why=="unchanged")
            assert(x.Observe(r,101,101));assert(x.Replay().timeDisputed==1 and x.Replay().matched==0)
            assert(x.Observe(Record(1,true),100,100));assert(x.Replay().disputed==1)
            local reopened=assert(Open(client,x.Save()));assert(Equal(x.Save(),reopened.Save()) and Equal(x.Replay(),reopened.Replay()))
            assert(saved.clocks[r.id]==nil and #saved.ledger.entries[r.id]==1)
        end)
    end
    Case("batch merge stays simulation only",function()local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)end)
    return passed,failed
end

function P.RunDeltaSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    local epoch=1000
    for _,client in ipairs({"forever","retail"}) do
        local function Node() return assert(Open(client,nil,epoch)) end
        local function Record(i,reverse)
            local s="a-"..i..":b-"..i
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,reverse and "lost" or "won","1"},"|"),
                statement2=table.concat({"1",client,s,b,a,reverse and "won" or "lost","2"},"|")}
        end
        local function Pull(source,target)
            local plan=assert(target.PlanDelta(source.DeltaSummary()))
            local count=0
            for _,g in ipairs(plan.pulls) do
                for i=g.pages,1,-1 do
                    local page=assert(source.ExportDeltaPage("delta",g.group,g.expected,i))
                    count=count+#page.entries
                    assert(target.Receive(page,a,a,"delta"))
                end
            end
            return plan,count
        end
        Case(client.." equal histories need no pulls; copied summaries isolated",function()
            local x,y=Node(),Node()
            for i=1,24 do assert(x.Observe(Record(i),epoch+i,epoch+i)) end
            for i=24,1,-1 do assert(y.Observe(Record(i),epoch+i,epoch+i)) end
            local summary=x.DeltaSummary();assert(Equal(summary,y.DeltaSummary()))
            local p=assert(y.PlanDelta(summary));assert(p.different==0 and #p.pulls==0 and p.completeness=="unknown" and not p.rankEligible)
            summary.groups[1].a=0;assert(Equal(x.DeltaSummary(),y.DeltaSummary()))
        end)
        Case(client.." missing evidence converges with fewer records",function()
            local x,y=Node(),Node()
            for i=1,128 do
                local r=Record(i);assert(x.Observe(r,epoch+i,epoch+i))
                if i~=3 and i~=97 then assert(y.Observe(r,epoch+i,epoch+i)) end
            end
            local p,n=Pull(x,y)
            assert(p.different>=1 and p.different<=2 and n>=2 and n<128)
            assert(Equal(x.Save(),y.Save()) and #assert(y.PlanDelta(x.DeltaSummary())).pulls==0)
            assert(Equal(x.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+128}),y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+128})))
        end)
        Case(client.." equal counts with corrected outcomes and clocks detected",function()
            local x,y=Node(),Node();local r=Record(1)
            assert(x.Observe(r,epoch,epoch));assert(y.Observe(r,epoch,epoch))
            local old=x.DeltaSummary()
            assert(x.Observe(Record(1,true),epoch,epoch))
            assert(y.Observe(r,epoch+1,epoch+1))
            local plan=assert(y.PlanDelta(x.DeltaSummary()));assert(plan.different==1 and #plan.pulls==1)
            local g=plan.pulls[1]
            local stale,why=x.ExportDeltaPage("delta",g.group,old.groups[g.group],1)
            assert(not stale and why=="stale_group")
            Pull(x,y);Pull(y,x);assert(Equal(x.Save(),y.Save()))
            local replay=assert(x.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+1}));assert(replay.disputed==1 and replay.matched==0)
        end)
        Case(client.." incompatible malformed and stale summaries fail closed",function()
            local x,y=Node(),Node();assert(x.Observe(Record(1),epoch,epoch))
            local old=x.DeltaSummary();local plan=assert(y.PlanDelta(old));local g=plan.pulls[1]
            assert(not x.ExportDeltaPage("bad|token",g.group,g.expected,1))
            assert(not x.ExportDeltaPage("delta",g.group,g.expected,2))
            local remote=assert(Open(client,nil,epoch+1));assert(not remote.PlanDelta(old))
            local invalid=x.DeltaSummary();invalid.groups[1].count=LIMIT+1;assert(not y.PlanDelta(invalid))
            invalid=x.DeltaSummary();invalid.groups[1].extra=true;assert(not y.PlanDelta(invalid))
            invalid=x.DeltaSummary();invalid.groups[GROUPS]=nil;assert(not y.PlanDelta(invalid))
            invalid=x.DeltaSummary();invalid.context=invalid.context.."x";assert(not y.PlanDelta(invalid))
            assert(x.Observe(Record(1),epoch+1,epoch+1))
            assert(not x.ExportDeltaPage("delta",g.group,g.expected,1))
            assert(#assert(y.PlanDelta(x.DeltaSummary())).pulls==1)
            assert(#y.Save().ledger.entries==0 and next(y.Save().ledger.entries)==nil)
        end)
    end
    Case("delta comparisons remain isolated season simulations",function()
        local x=assert(Open("retail"))
        assert(not x.DeltaSummary() and not x.PlanDelta({}) and not x.ExportDeltaPage("delta",1,{count=1,a=1,b=1},1))
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
    end)
    return passed,failed
end

function P.RunDeltaCacheSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    local epoch=1000
    for _,client in ipairs({"forever","retail"}) do
        local function Record(i,reverse)
            local s="a-"..i..":b-"..i
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,reverse and "lost" or "won","1"},"|"),
                statement2=table.concat({"1",client,s,b,a,reverse and "won" or "lost","2"},"|")}
        end
        local function Node()
            local x=assert(Open(client,nil,epoch))
            for i=1,32 do assert(x.Observe(Record(i),epoch+i,epoch+i)) end
            return x
        end
        local function Parity(x)
            local fresh=assert(Open(client,x.Save(),epoch))
            assert(Equal(x.DeltaSummary(),fresh.DeltaSummary()))
            return x.GetDeltaWork()
        end
        Case(client.." warm summaries and duplicate merges perform no rehash",function()
            local x=Node();assert(x.GetDeltaWork().records==0)
            x.DeltaSummary();local initial=x.GetDeltaWork();assert(initial.records==32 and initial.groups>0)
            assert(x.Observe(Record(1),epoch+1,epoch+1))
            Parity(x);assert(Equal(initial,x.GetDeltaWork()))
            local copy=x.GetDeltaWork();copy.records=0;assert(Equal(initial,x.GetDeltaWork()))
        end)
        Case(client.." corrections and insertion rehash only affected groups",function()
            local x=Node();local before=x.DeltaSummary();local w=x.GetDeltaWork()
            local g=Group(Record(1).id)
            assert(x.Observe(Record(1),epoch+2,epoch+2))
            local after=x.DeltaSummary();local v=x.GetDeltaWork()
            assert(v.groups-w.groups==1 and v.records-w.records==before.groups[g].count)
            for i=1,GROUPS do if i~=g then assert(Equal(before.groups[i],after.groups[i])) end end
            assert(not Equal(before.groups[g],after.groups[g]))
            assert(x.Observe(Record(1,true),epoch+1,epoch+1))
            local u=Parity(x);assert(u.groups-v.groups==1 and u.records-v.records==after.groups[g].count)
            local new=Record(33);local ng=Group(new.id);local old=x.DeltaSummary().groups[ng].count
            assert(x.Observe(new,epoch+33,epoch+33))
            local z=Parity(x);assert(z.groups-u.groups==1 and z.records-u.records==old+1)
            assert(x.DeltaSummary().groups[ng].count==old+1)
        end)
        Case(client.." targeted exports and rejected pages preserve unaffected cache",function()
            local x=Node();local summary=x.DeltaSummary()
            local g=Group(Record(1).id)
            local other
            for i=2,32 do local k=Group(Record(i).id);if k~=g then other=i;break end end
            assert(other)
            local h=Group(Record(other).id)
            assert(x.Observe(Record(1,true),epoch+1,epoch+1))
            assert(x.Observe(Record(other,true),epoch+other,epoch+other))
            local w=x.GetDeltaWork()
            local page,why=x.ExportDeltaPage("cache",g,summary.groups[g],1)
            assert(not page and why=="stale_group")
            local v=x.GetDeltaWork();assert(v.groups-w.groups==1 and v.records-w.records==summary.groups[g].count)
            local saved=x.Save()
            assert(not x.Receive({},a,a,"cache"))
            assert(Equal(saved,x.Save()) and Equal(v,x.GetDeltaWork()))
            local z=Parity(x);assert(z.groups-v.groups==1 and z.records-v.records==summary.groups[h].count)
            local after=x.DeltaSummary();assert(x.ExportDeltaPage("cache",g,after.groups[g],1))
            assert(Equal(z,x.GetDeltaWork()))
        end)
    end
    Case("delta work is isolated and live gate unchanged",function()
        local x=assert(Open("retail"));assert(not x.DeltaSummary())
        assert(x.GetDeltaWork().records==0 and x.GetDeltaWork().groups==0)
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
    end)
    return pass,fail
end

function P.RunPreparationSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    local epoch=1000
    for _,client in ipairs({"forever","retail"}) do
        local function Record(i,reverse)
            local s="a-"..i..":b-"..i
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,a,b,reverse and "lost" or "won","1"},"|"),
                statement2=table.concat({"1",client,s,b,a,reverse and "won" or "lost","2"},"|")}
        end
        local function Node(n)
            local x=assert(Open(client,nil,epoch))
            for i=1,n do assert(x.Observe(Record(i),epoch+i,epoch+i)) end
            return x
        end
        local function Finish(x,budget)
            for _=1,256 do
                local before=x.GetDeltaWork()
                local ready,used=x.PrepareDelta(budget)
                local after=x.GetDeltaWork()
                assert(type(ready)=="boolean" and used<=budget and used==after.indexed-before.indexed+after.records-before.records)
                if ready then return end
                assert(used>0)
            end
            error("preparation did not finish")
        end
        Case(client.." bounded cold preparation and warm parity",function()
            local x=Node(32);assert(not x.PrepareDelta(0) and not x.PrepareDelta(65))
            Finish(x,7)
            local w=x.GetDeltaWork();assert(w.indexed==32 and w.records==32)
            local fresh=assert(Open(client,x.Save(),epoch))
            assert(Equal(x.DeltaSummary(),fresh.DeltaSummary()) and Equal(w,x.GetDeltaWork()))
            local ready,used=x.PrepareDelta(1);assert(ready and used==0)
        end)
        Case(client.." mutations during indexing and hashing preserve exact parity",function()
            local x=Node(32)
            local ready,used=x.PrepareDelta(1);assert(not ready and used==1)
            assert(x.Observe(Record(33),epoch+33,epoch+33))
            assert(x.Observe(Record(1,true),epoch+1,epoch+1))
            -- Finish initial indexing, then hash exactly one record.
            for _=1,31 do assert(select(2,x.PrepareDelta(1))==1) end
            assert(select(2,x.PrepareDelta(1))==1)
            assert(x.Observe(Record(1),epoch+2,epoch+2))
            assert(x.Observe(Record(34),epoch+34,epoch+34))
            Finish(x,3)
            local fresh=assert(Open(client,x.Save(),epoch))
            assert(Equal(x.DeltaSummary(),fresh.DeltaSummary()))
            assert(x.GetDeltaWork().indexed==32)
        end)
        Case(client.." evidence revision changes only after accepted canonical mutation",function()
            local x=Node(1);local r=x.GetEvidenceRevision()
            local ok,why=x.Observe(Record(1),epoch+1,epoch+1);assert(ok and why=="unchanged")
            assert(x.GetEvidenceRevision()==r and not x.Receive({},a,a,"prep"))
            assert(x.GetEvidenceRevision()==r)
            assert(x.Observe(Record(1),epoch+2,epoch+2) and x.GetEvidenceRevision()==r+1)
            assert(x.Observe(Record(1,true),epoch+1,epoch+1) and x.GetEvidenceRevision()==r+2)
        end)
    end
    Case("preparation remains fixture-only",function()
        local x=assert(Open("retail"));assert(not x.PrepareDelta(1))
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
    end)
    return pass,fail
end

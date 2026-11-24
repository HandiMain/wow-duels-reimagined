local _,ns=...
-- Isolated peer merge model. Pages are logical tables, NOT wire packets.
-- No live sender, receiver, timestamps, persistence or rating authority.
local P={}
ns.LeaderboardSync=P
local VERSION,LIMIT,PAGE=1,2048,16
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
local function Validate(client,saved)
    if type(saved)~="table" or saved.version~=VERSION or saved.scope~="SIMULATED" or saved.client~=client
        or saved.rule~=RULE or type(saved.clocks)~="table" or type(saved.ledger)~="table" then return nil end
    local ledger=ns.MatchLedger.OpenSimulated(client,saved.ledger)
    if not ledger then return nil end
    local clean={version=VERSION,scope="SIMULATED",client=client,rule=RULE,ledger=ledger.Save(),clocks={}}
    for id,v in pairs(saved.clocks) do
        if not clean.ledger.entries[id] then return nil end
        local c=Clocks(v);if not c then return nil end;clean.clocks[id]=c
    end
    if not Equal(clean,saved) then return nil end
    return clean
end
local function Open(client,saved,epoch)
    if client~="forever" and client~="retail" then return nil,"client" end
    if epoch~=nil and not ns.SeasonRules.Schedule(epoch,epoch) then return nil,"invalid_schedule" end
    local data
    if saved==nil then
        data={version=VERSION,scope="SIMULATED",client=client,rule=RULE,
            ledger=assert(ns.MatchLedger.OpenSimulated(client)).Save(),clocks={}}
    else data=Validate(client,saved) end
    if not data then return nil,"invalid_store" end
    -- The ledger owns canonical records. Only incoming evidence is validated
    -- during a merge; the existing ledger is opened once per isolated node.
    local ledger=assert(ns.MatchLedger.OpenSimulated(client,data.ledger))
    data.ledger=nil
    local D={}
    local sortedIDs
    local function Merge(incoming)
        local records,stagedClocks={},{}
        for id,variants in pairs(incoming.ledger.entries) do
            for _,r in ipairs(variants) do records[#records+1]=r end
            stagedClocks[id]=MergeClocks(data.clocks[id],incoming.clocks[id])
        end
        local ok,why=ledger.MergeBatch(records)
        if not ok then return false,why end
        local changed=why=="merged"
        for id,clocks in pairs(stagedClocks) do
            if not Equal(data.clocks[id],clocks) then data.clocks[id]=clocks;changed=true end
        end
        if not changed then return true,"unchanged" end
        sortedIDs=nil;return true,"merged"
    end
    -- Direct fixture observation: t1/t2 correspond to canonical player1/2.
    -- A two-clock fixture is not proof that either player really reported it.
    function D.Observe(record,t1,t2)
        local clean=ns.ResultConfirmation.ValidateSimulatedRecord(record)
        if not clean or clean.client~=client then return false,"invalid_record" end
        local clocks={}
        if t1~=nil or t2~=nil then
            local c=Clocks({{t1,t2}});if not c then return false,"invalid_time" end;clocks[clean.id]=c
        end
        local l=assert(ns.MatchLedger.OpenSimulated(client));assert(l.Insert(clean))
        return Merge({ledger=l.Save(),clocks=clocks})
    end
    function D.Save() local saved=Copy(data);saved.ledger=ledger.Save();return saved end
    -- Cache only the canonical ID order; never retain exported record copies.
    local function IDs()
        if not sortedIDs then
            sortedIDs=ledger.ListIDs()
        end
        return sortedIDs
    end
    local function Page(token,index,ids,total)
        local page={version=VERSION,scope="SIMULATED",client=client,rule=RULE,token=token,index=index,total=total,entries={}}
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
    -- Sender and request token are injected by a simulation, not authenticated
    -- WoW events. Accept only bounded pages; validate all before a merge.
    function D.Receive(page,sender,expected,token)
        if not Guid(sender) or sender~=expected or not Token(token) or type(page)~="table"
            or page.version~=VERSION or page.scope~="SIMULATED" or page.client~=client or page.rule~=RULE or page.token~=token
            or not Int(page.total,1,math.ceil(LIMIT/PAGE)) or not Int(page.index,1,page.total) then return false,"invalid_page" end
        local n=Array(page.entries,PAGE)
        if not n or (page.index<page.total and n~=PAGE) or (n==0 and page.total~=1) then return false,"invalid_page" end
        local incoming={version=VERSION,scope="SIMULATED",client=client,rule=RULE,
            ledger={version=1,scope="SIMULATED",client=client,entries={}},clocks={}}
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
        local clean=Validate(client,incoming);if not clean then return false,"invalid_evidence" end
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
        local result,why=ns.RatingEngine.ReplaySimulated(client,eligible,times,rule,options)
        if not result then return nil,why end
        result.knownMatched=#s.matched;result.missingTime=missing;result.timeDisputed=conflict
        result.completeness="unknown";return result
    end
    function D.GetSeasonEpoch() return epoch end
    function D.Replay()
        if epoch then return nil,"season_context_required" end
        return Replay(RULE)
    end
    function D.ReplaySeasonSimulated(options)
        if epoch and (type(options)~="table" or options.epoch~=epoch) then return nil,"schedule_mismatch" end
        return Replay(ns.SeasonRules.BALANCED_ID,options)
    end
    return D
end
function P.OpenSimulated(client,saved) return Open(client,saved) end
function P.OpenSeasonSimulated(client,epoch,saved)
    if epoch==nil then return nil,"invalid_schedule" end
    return Open(client,saved,epoch)
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

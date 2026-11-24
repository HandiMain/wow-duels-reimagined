local _,ns=...
-- Versioned, isolated storage model. No live SavedVariables or rating writes.
local P={}
ns.MatchLedger=P
local VERSION,LIMIT=1,2048
function P.GetSnapshot()
    return {scope="LOCAL",state="disabled",rankEligible=false,version=VERSION}
end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
local function Copy(t)
    local out={}
    for k,v in pairs(t) do out[k]=type(v)=="table" and Copy(v) or v end
    return out
end
local function Key(r) return r.statement1.."\n"..r.statement2 end
local function Open(client,stored,cap)
    if client~="forever" and client~="retail" then return nil,"client" end
    cap=cap or LIMIT
    local data={version=VERSION,scope="SIMULATED",client=client,entries={}}
    local count=0
    local function Validate(r)
        local clean=ns.ResultConfirmation.ValidateSimulatedRecord(r)
        if clean and clean.client==client then return clean end
    end
    if stored~=nil then
        if type(stored)~="table" or stored.version~=VERSION or stored.scope~="SIMULATED"
            or stored.client~=client or type(stored.entries)~="table" then return nil,"unsupported_store" end
        for id,variants in pairs(stored.entries) do
            count=count+1
            if count>cap or type(variants)~="table" or type(id)~="string" then return nil,"invalid_store" end
            local n=0
            for k in pairs(variants) do
                if k~=1 and k~=2 then return nil,"invalid_store" end
                n=n+1
            end
            if n<1 or not variants[1] or (n==2 and not variants[2]) then return nil,"invalid_store" end
            local a=Validate(variants[1]);local b=n==2 and Validate(variants[2]) or nil
            if not a or a.id~=id or (n==2 and (not b or b.id~=id or Key(a)>=Key(b))) then return nil,"invalid_store" end
            data.entries[id]={a,b}
        end
    end
    local D={}
    function D.Insert(r)
        local v=Validate(r)
        if not v then return false,"invalid_record" end
        local old=data.entries[v.id]
        if not old then
            if count>=cap then return false,"capacity" end
            data.entries[v.id]={v};count=count+1;return true,"inserted"
        end
        local k=Key(v)
        for _,prior in ipairs(old) do if Key(prior)==k then return false,"duplicate" end end
        -- Keep the lexically smallest two distinct statements as stable dispute
        -- evidence. No later variant can make a disputed ID eligible again.
        local variants={old[1],old[2]}
        variants[#variants+1]=v
        table.sort(variants,function(a,b)return Key(a)<Key(b) end)
        if #variants>2 then variants[3]=nil end
        data.entries[v.id]=variants
        return true,"disputed"
    end
    function D.Save() return Copy(data) end
    function D.Snapshot()
        local ids={}
        for id in pairs(data.entries) do ids[#ids+1]=id end
        table.sort(ids)
        local out={scope="SIMULATED",client=client,version=VERSION,rankEligible=false,matched={},disputed={}}
        for _,id in ipairs(ids) do
            local v=data.entries[id]
            if v[2] then out.disputed[#out.disputed+1]={id=id,evidence=Copy(v)}
            else out.matched[#out.matched+1]=Copy(v[1]) end
        end
        return out
    end
    return D
end
P.OpenSimulated=Open
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local function Record(client,n,reverse,cycle)
        local a,b="Player-1-AAA","Player-2-BBB"
        local session="alpha-"..n..":beta-"..n
        local x,y=reverse and "lost" or "won",reverse and "won" or "lost"
        local r={scope="SIMULATED",version="1",client=client,session=session,
            id=client.."|"..a.."|"..b.."|"..session,player1=a,player2=b,
            winner=reverse and b or a,loser=reverse and a or b,endType="knockout",rankEligible=false,
            statement1=table.concat({"1",client,session,a,b,x,tostring(cycle or 7)},"|"),
            statement2=table.concat({"1",client,session,b,a,y,"12"},"|")}
        return assert(ns.ResultConfirmation.ValidateSimulatedRecord(r))
    end
    local function Equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    for _,client in ipairs({"forever","retail"}) do
        Case(client.." insert and canonical data",function()
            local d=assert(Open(client));local r=Record(client,1);assert(d.Insert(r))
            local s=d.Snapshot();assert(#s.matched==1 and #s.disputed==0 and Equal(s.matched[1],r) and not s.rankEligible)
        end)
        Case(client.." duplicate insert idempotent",function()
            local d=assert(Open(client));local r=Record(client,1);assert(d.Insert(r));local ok,why=d.Insert(r)
            assert(not ok and why=="duplicate" and #d.Snapshot().matched==1)
        end)
        Case(client.." late conflicting record excludes match",function()
            local d=assert(Open(client));local r=Record(client,1);assert(d.Insert(r));assert(d.Insert(Record(client,1,true)))
            local s=d.Snapshot();assert(#s.matched==0 and #s.disputed==1 and #s.disputed[1].evidence==2)
            assert(not d.Insert(r));assert(#d.Snapshot().disputed==1)
        end)
        Case(client.." deterministic merge order and bounded disputes",function()
            local a,b,c=Record(client,1),Record(client,1,true),Record(client,1,false,8)
            local x,y=assert(Open(client)),assert(Open(client));x.Insert(a);x.Insert(b);x.Insert(c)
            y.Insert(c);y.Insert(b);y.Insert(a);assert(Equal(x.Save(),y.Save()))
            assert(#x.Snapshot().disputed[1].evidence==2)
        end)
        Case(client.." save reopen and duplicate protection",function()
            local d=assert(Open(client));local r=Record(client,1);d.Insert(r);d.Insert(Record(client,2))
            d.Insert(Record(client,2,true));local saved=d.Save();local reopened=assert(Open(client,saved))
            assert(Equal(saved,reopened.Save()) and not reopened.Insert(r));assert(#reopened.Snapshot().disputed==1)
        end)
        Case(client.." corrupt or future storage preserved",function()
            local d=assert(Open(client));d.Insert(Record(client,1));local saved=d.Save();saved.version=2
            local before=Copy(saved);assert(not Open(client,saved) and Equal(saved,before))
            saved.version=1;saved.entries.bad={};before=Copy(saved);assert(not Open(client,saved) and Equal(saved,before))
        end)
        Case(client.." corrupted statements and derived fields rejected",function()
            local d=assert(Open(client));local r=Record(client,1);r.winner=r.loser;assert(not d.Insert(r))
            r=Record(client,1);r.statement2=r.statement1;assert(not d.Insert(r));assert(#d.Snapshot().matched==0)
        end)
        Case(client.." live and cross client isolation",function()
            local d=assert(Open(client));local other=client=="forever" and "retail" or "forever"
            assert(not d.Insert(Record(other,1)));local r=Record(client,1);r.scope="LOCAL";assert(not d.Insert(r))
            local q=assert(Open(other));q.Insert(Record(other,1));assert(not Open(client,q.Save()))
        end)
        Case(client.." snapshot and storage alias isolation",function()
            local d=assert(Open(client));local r=Record(client,1);d.Insert(r);r.winner="changed"
            local saved=d.Save();local reopened=assert(Open(client,saved));saved.entries[r.id][1].winner="changed"
            local s=reopened.Snapshot();s.matched[1].winner="changed";assert(reopened.Snapshot().matched[1].winner~= "changed")
            assert(d.Snapshot().matched[1].winner~= "changed")
        end)
        Case(client.." capacity rejects without eviction",function()
            local d=assert(Open(client,nil,1));d.Insert(Record(client,1));local before=d.Save()
            local ok,why=d.Insert(Record(client,2));assert(not ok and why=="capacity" and Equal(before,d.Save()))
            assert(d.Insert(Record(client,1,true)) and #d.Snapshot().disputed==1)
        end)
        Case(client.." stable listing across insert order",function()
            local a,b=Record(client,1),Record(client,2);local x,y=assert(Open(client)),assert(Open(client))
            x.Insert(a);x.Insert(b);y.Insert(b);y.Insert(a);assert(Equal(x.Snapshot(),y.Snapshot()))
        end)
        Case(client.." invalid persisted variant order rejected",function()
            local d=assert(Open(client));local r=Record(client,1);d.Insert(r);d.Insert(Record(client,1,true))
            local saved=d.Save();local v=saved.entries[r.id];v[1],v[2]=v[2],v[1];assert(not Open(client,saved))
        end)
    end
    Case("live ledger remains disabled",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
        s.state="changed";assert(P.GetSnapshot().state=="disabled")
    end)
    return passed,failed
end

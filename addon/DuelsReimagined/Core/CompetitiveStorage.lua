local _,ns=...
-- Storage lifecycle only. No match, history or rating writes. The explicit
-- probe is development metadata, never a simulated or real duel record.
local P={}
ns.CompetitiveStorage=P
local VERSION,MAX=1,2147483647
local function Client(k) return k=="forever" or k=="retail" end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Count(v)
    return type(v)=="number" and v>=0 and v<=MAX and v==math.floor(v)
end
local function Root(raw,kind,owner)
    if raw==nil then return {version=VERSION,kind=kind,owner=owner,clients={}} end
    if type(raw)~="table" or raw.version~=VERSION or raw.kind~=kind or raw.owner~=owner
        or type(raw.clients)~="table" then return nil end
    for k in pairs(raw) do
        if k~="version" and k~="kind" and k~="owner" and k~="clients" then return nil end
    end
    local clean={version=VERSION,kind=kind,owner=owner,clients={}}
    for k,v in pairs(raw.clients) do
        if not Client(k) or type(v)~="table" or not Count(v.probe) then return nil end
        for field in pairs(v) do if field~="probe" then return nil end end
        clean.clients[k]={probe=v.probe}
    end
    return clean
end
-- Injected storage access for isolated tests. Never cache SavedVariables tables.
local function Build(read,write,client,identity)
    local D,loaded={},false
    function D.MarkLoaded() loaded=true end
    local function Pair()
        if not loaded then return nil,nil,nil,"not_loaded" end
        local k=client();if not Client(k) then return nil,nil,nil,"unsupported_client" end
        local owner=identity();if not Guid(owner) then return nil,nil,nil,"identity_unavailable" end
        local a,c=read()
        local aa,cc=Root(a,"account"),Root(c,"character",owner)
        if not aa or not cc then return nil,nil,nil,"invalid_or_unsupported_storage" end
        return aa,cc,k
    end
    local function N(root,k) return root.clients[k] and root.clients[k].probe or 0 end
    function D.Snapshot()
        local a,c,k,why=Pair()
        if not a then return {scope="LOCAL",state="unavailable",reason=why,rankEligible=false} end
        return {scope="LOCAL",state="ready",version=VERSION,client=k,accountProbe=N(a,k),characterProbe=N(c,k),rankEligible=false}
    end
    function D.Probe()
        local a,c,k,why=Pair()
        if not a then return false,why end
        local x,y=N(a,k),N(c,k)
        if x>=MAX or y>=MAX then return false,"capacity" end
        a.clients[k]={probe=x+1};c.clients[k]={probe=y+1}
        -- Both roots validated first. No changes on rejection; replace only
        -- our two dedicated roots, never the existing preferences database.
        write(a,c)
        return true
    end
    return D
end
local live=Build(function() return _G.DuelsReimaginedCompetitiveDB,_G.DuelsReimaginedCharacterDB end,
    function(a,c) _G.DuelsReimaginedCompetitiveDB=a;_G.DuelsReimaginedCharacterDB=c end,
    function() return ns.Client.Kind() end,
    function()
        local id=ns.Group and ns.Group.ReadPlayerIdentity("player")
        return id and id.guid
    end)
P.MarkLoaded=live.MarkLoaded
P.GetSnapshot=live.Snapshot
P.RunPersistenceProbe=live.Probe
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,alt="Player-1-AAA","Player-2-BBB"
    for _,client in ipairs({"forever","retail"}) do
        local other=client=="forever" and "retail" or "forever"
        local function Fixture()
            local f={client=client,owner=me,writes=0}
            function f.open(load)
                local d=Build(function()return f.a,f.c end,function(a,c)f.a=a;f.c=c;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end)
                if load~=false then d.MarkLoaded() end
                return d
            end
            return f
        end
        Case(client.." before load and read-only defaults",function()
            local f=Fixture();local d=f.open(false);assert(d.Snapshot().reason=="not_loaded" and not d.Probe())
            d.MarkLoaded();local s=d.Snapshot();assert(s.state=="ready" and s.accountProbe==0 and s.characterProbe==0 and f.writes==0 and f.a==nil and f.c==nil)
        end)
        Case(client.." explicit probe and simulated reload",function()
            local f=Fixture();local d=f.open();assert(d.Probe());local s=f.open().Snapshot();assert(s.accountProbe==1 and s.characterProbe==1 and f.writes==1)
            assert(f.open().Probe());s=d.Snapshot();assert(s.accountProbe==2 and s.characterProbe==2)
        end)
        Case(client.." character switching and return",function()
            local f=Fixture();local d=f.open();assert(d.Probe());local saved=f.c;f.c=nil;f.owner=alt
            local s=f.open().Snapshot();assert(s.accountProbe==1 and s.characterProbe==0)
            assert(f.open().Probe());f.c=saved;f.owner=me;s=f.open().Snapshot();assert(s.accountProbe==2 and s.characterProbe==1)
        end)
        Case(client.." mismatched character root rejected",function()
            local f=Fixture();local d=f.open();d.Probe();local a,c=f.a,f.c;f.owner=alt
            assert(not d.Probe() and d.Snapshot().state=="unavailable" and f.a==a and f.c==c and f.writes==1)
        end)
        Case(client.." client partition separation",function()
            local f=Fixture();local d=f.open();d.Probe();f.client=other;local s=d.Snapshot();assert(s.accountProbe==0 and s.characterProbe==0)
            d.Probe();d.Probe();f.client=client;s=d.Snapshot();assert(s.accountProbe==1 and s.characterProbe==1)
            f.client=other;s=d.Snapshot();assert(s.accountProbe==2 and s.characterProbe==2)
        end)
        Case(client.." unknown schema preserved",function()
            local f=Fixture();local d=f.open();d.Probe();f.a.version=2;local a,c=f.a,f.c
            assert(not d.Probe() and f.a==a and f.c==c and f.a.version==2 and f.writes==1)
        end)
        Case(client.." corrupt character refuses both writes",function()
            local f=Fixture();local d=f.open();d.Probe();f.c.clients[client].probe=-1;local a,c=f.a,f.c
            assert(not d.Probe() and f.a==a and f.c==c and f.a.clients[client].probe==1 and f.writes==1)
        end)
        Case(client.." unknown fields not silently stripped",function()
            local f=Fixture();local d=f.open();d.Probe();f.a.clients[client].records={}
            assert(not d.Probe() and type(f.a.clients[client].records)=="table" and f.writes==1)
        end)
        Case(client.." unavailable identity and unsupported client",function()
            local f=Fixture();local d=f.open();f.owner=nil;assert(not d.Probe());f.owner=me;f.client="unsupported"
            assert(not d.Probe() and f.writes==0)
        end)
        Case(client.." bounded counters and independent snapshots",function()
            local f=Fixture();local d=f.open();d.Probe();local s=d.Snapshot();s.accountProbe=99;assert(d.Snapshot().accountProbe==1)
            f.c.clients[client].probe=MAX;assert(not d.Probe() and f.a.clients[client].probe==1 and f.writes==1)
        end)
    end
    Case("live SavedVariables untouched by isolated storage QA",function()
        -- The fixture engine never uses the live writer.
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.rankEligible==false)
    end)
    return passed,failed
end

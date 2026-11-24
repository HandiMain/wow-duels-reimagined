local _,ns=...
-- Live metadata and isolated durable record transactions. No live match writes.
local P={}
ns.CompetitiveStorage=P
local VERSION,MAX=2,2147483647
local function Client(k) return k=="forever" or k=="retail" end
local function Guid(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
local function Count(v)
    return type(v)=="number" and v>=0 and v<=MAX and v==math.floor(v)
end
-- One persisted ledger; season metadata adds only calendar and clock evidence.
local function SeasonNode(client,ledger,season)
    local rules=ns.SeasonRules
    if type(season)~="table" or season.version~=1 or season.rule~=rules.BALANCED_ID
        or not rules.Schedule(season.epoch,season.epoch) or type(season.clocks)~="table" or type(ledger)~="table" then return nil end
    for k in pairs(season) do if k~="version" and k~="rule" and k~="epoch" and k~="clocks" then return nil end end
    return ns.LeaderboardSync.OpenSimulated(client,{version=1,scope="SIMULATED",client=client,
        rule=ns.CompetitiveRules.ID,ledger=ledger,clocks=season.clocks})
end
local function Root(raw,kind,owner,scope)
    local clean={version=VERSION,kind=kind,owner=owner,scope=scope,clients={}}
    if raw==nil then return clean end
    if type(raw)~="table" or (raw.version~=1 and raw.version~=VERSION) or raw.kind~=kind
        or raw.owner~=owner or type(raw.clients)~="table" then return nil end
    local legacy=raw.version==1
    if (legacy and raw.scope~=nil) or (not legacy and raw.scope~=scope) then return nil end
    for k in pairs(raw) do
        if k~="version" and k~="kind" and k~="owner" and k~="clients" and k~="scope" then return nil end
    end
    for k,v in pairs(raw.clients) do
        if not Client(k) or type(v)~="table" or not Count(v.probe) then return nil end
        local part={probe=v.probe}
        if kind=="character" then
            if not legacy and not Count(v.runCounter) then return nil end
            part.runCounter=legacy and 0 or v.runCounter
        end
        for field in pairs(v) do
            if field~="probe" and not (not legacy and kind=="character" and field=="runCounter")
                and not (not legacy and scope=="SIMULATED" and ((kind=="account" and (field=="ledger" or field=="season"))
                    or (kind=="character" and field=="history"))) then return nil end
        end
        -- Only private simulation roots can contain simulated records.
        if scope=="SIMULATED" and not legacy then
            if kind=="account" and v.ledger~=nil then
                local ledger=ns.MatchLedger.OpenSimulated(k,v.ledger)
                if not ledger then return nil end
                part.ledger=ledger.Save()
            elseif kind=="character" and v.history~=nil then
                local empty=ns.MatchLedger.OpenSimulated(k)
                local history=ns.PersonalHistory.OpenSimulated(k,owner,empty,v.history)
                if not history then return nil end
                part.history=history.Save()
                for _,src in ipairs(part.history.observations) do
                    local n=tonumber(src.run:match("^run%-(%d+)$"))
                    if not Count(n) or n==0 or n>part.runCounter or src.run~="run-"..n then return nil end
                end
            end
        end
        if scope=="SIMULATED" and not legacy and kind=="account" and v.season~=nil then
            local node=SeasonNode(k,part.ledger,v.season)
            if not node then return nil end
            part.season={version=1,rule=v.season.rule,epoch=v.season.epoch,clocks=node.Save().clocks}
        end
        clean.clients[k]=part
    end
    return clean
end
-- Injected storage access for isolated tests. Never cache SavedVariables tables.
local function Build(read,write,client,identity,scope)
    scope=scope or "LOCAL"
    local D,loaded={},false
    function D.MarkLoaded() loaded=true end
    local function Pair()
        if not loaded then return nil,nil,nil,"not_loaded" end
        local k=client();if not Client(k) then return nil,nil,nil,"unsupported_client" end
        local owner=identity();if not Guid(owner) then return nil,nil,nil,"identity_unavailable" end
        local a,c=read()
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",owner,scope)
        if not aa or not cc then return nil,nil,nil,"invalid_or_unsupported_storage" end
        return aa,cc,k,nil,type(a)=="table" and a.version==VERSION and type(c)=="table" and c.version==VERSION
    end
    local function N(root,k) return root.clients[k] and root.clients[k].probe or 0 end
    function D.Snapshot()
        local a,c,k,why,prepared=Pair()
        if not a then return {scope=scope,state="unavailable",reason=why,rankEligible=false} end
        return {scope=scope,state="ready",version=VERSION,prepared=prepared,client=k,accountProbe=N(a,k),characterProbe=N(c,k),rankEligible=false}
    end
    function D.Probe()
        local a,c,k,why=Pair()
        if not a then return false,why end
        local x,y=N(a,k),N(c,k)
        if x>=MAX or y>=MAX then return false,"capacity" end
        a.clients[k]=a.clients[k] or {probe=0};c.clients[k]=c.clients[k] or {probe=0,runCounter=0}
        a.clients[k].probe=x+1;c.clients[k].probe=y+1
        -- Both roots validated first. No changes on rejection; replace only
        -- our two dedicated roots, never the existing preferences database.
        write(a,c)
        return true
    end
    function D.Prepare()
        local a,c,k,why,prepared=Pair()
        if not a then return false,why end
        if not prepared then write(a,c) end
        return true
    end
    -- Private fixture transaction: reopen from validated data every time;
    -- write only canonical record sources after successful edit. No live path.
    local function Records(a,c,k)
        local ap=a.clients[k] or {probe=0}
        local cp=c.clients[k] or {probe=0,runCounter=0}
        local ledger=ns.MatchLedger.OpenSimulated(k,ap.ledger)
        if not ledger then return end
        local history=ns.PersonalHistory.OpenSimulated(k,c.owner,ledger,cp.history)
        if not history then return end
        return ledger,history,ap,cp
    end
    function D.ReadRecords()
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local l,h,_,cp=Records(a,c,k);if not l then return nil,"invalid_records" end
        return {scope=scope,ledger=l.Snapshot(),history=h.Snapshot(),runCounter=cp.runCounter}
    end
    function D.UpdateRecords(newRun,edit)
        if scope~="SIMULATED" then return false,"disabled" end
        local a,c,k,why=Pair();if not a then return false,why end
        local l,h,ap,cp=Records(a,c,k);if not l then return false,"invalid_records" end
        if newRun then
            if cp.runCounter>=MAX then return false,"capacity" end
            cp.runCounter=cp.runCounter+1
        end
        local run=cp.runCounter>0 and "run-"..cp.runCounter or nil
        local ok,accept=pcall(edit,l,h,run)
        if not ok or accept~=true then return false,"edit_rejected" end
        ap.ledger=l.Save();cp.history=h.Save();a.clients[k]=ap;c.clients[k]=cp
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,run
    end
    -- Private storage transaction: same account ledger, no second history/rating database.
    function D.UpdateSeasonEvidence(epoch,record,t1,t2)
        if scope~="SIMULATED" then return false,"disabled" end
        local rules=ns.SeasonRules
        if not rules.Schedule(epoch,epoch) then return false,"invalid_schedule" end
        local a,c,k,why=Pair();if not a then return false,why end
        local ap=a.clients[k] or {probe=0}
        if ap.season and ap.season.epoch~=epoch then return false,"schedule_mismatch" end
        local ledger=ap.ledger or assert(ns.MatchLedger.OpenSimulated(k)).Save()
        local season=ap.season or {version=1,rule=rules.BALANCED_ID,epoch=epoch,clocks={}}
        local node=SeasonNode(k,ledger,season);if not node then return false,"invalid_season" end
        local ok,status=node.Observe(record,t1,t2);if not ok then return false,status end
        if ap.season and status=="unchanged" then return true,status end
        local saved=node.Save()
        ap.ledger=saved.ledger;ap.season={version=1,rule=season.rule,epoch=epoch,clocks=saved.clocks};a.clients[k]=ap
        local aa,cc=Root(a,"account",nil,scope),Root(c,"character",c.owner,scope)
        if not aa or not cc then return false,"invalid_records" end
        write(aa,cc);return true,status
    end
    function D.ReadSeasonArchive(asOf)
        if scope~="SIMULATED" then return nil,"disabled" end
        local a,c,k,why=Pair();if not a then return nil,why end
        local ap=a.clients[k];if not ap or not ap.season then return nil,"no_archive" end
        local node=SeasonNode(k,ap.ledger,ap.season);if not node then return nil,"invalid_season" end
        local result,err=node.ReplaySeasonSimulated({epoch=ap.season.epoch,asOf=asOf})
        if not result then return nil,err end
        result.character=c.owner;return result
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
P.PrepareSchema=live.Prepare
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
            local f=Fixture();local d=f.open();d.Probe();f.a.version=3;local a,c=f.a,f.c
            assert(not d.Probe() and f.a==a and f.c==c and f.a.version==3 and f.writes==1)
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

function P.RunRecordSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,peer,alt="Player-1-AAA","Player-2-BBB","Player-3-CCC"
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={owner=me,client=client,writes=0}
            function f.open()
                local d=Build(function()return f.a,f.c end,function(a,c)f.a=a;f.c=c;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                d.MarkLoaded();return d
            end
            return f
        end
        local function Observation(n,out)
            return {scope="SIMULATED",client=client,id=n,kind="standard",opponent={guid=peer},acceptedAt=10,endedAt=20,
                outcome=out or "won",endType="knockout",reason="matching_result_and_finish",outcomeObserved=true,
                finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
        end
        local function Agreement()
            return {scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session="a-1:b-1"}
        end
        local function Record(reverse)
            local session=Agreement().session
            local x,y=reverse and "lost" or "won",reverse and "won" or "lost"
            return {scope="SIMULATED",version="1",client=client,session=session,id=client.."|"..me.."|"..peer.."|"..session,
                player1=me,player2=peer,winner=reverse and peer or me,loser=reverse and me or peer,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,session,me,peer,x,"1"},"|"),statement2=table.concat({"1",client,session,peer,me,y,"2"},"|")}
        end
        Case(client.." v1 migration preserves counters / explicit prepare",function()
            local f=Fixture("LOCAL");f.a={version=1,kind="account",clients={[client]={probe=4}}}
            f.c={version=1,kind="character",owner=me,clients={[client]={probe=2}}}
            local d=f.open();assert(not d.Snapshot().prepared and f.writes==0);assert(d.Prepare());assert(d.Prepare())
            local s=f.open().Snapshot();assert(s.prepared and s.version==2 and s.accountProbe==4 and s.characterProbe==2 and f.writes==1)
        end)
        Case(client.." record roundtrip / local run IDs survive reopen",function()
            local f=Fixture();local d=f.open();assert(d.UpdateRecords(true,function(l,h,run) assert(run=="run-1");return h.Observe(run,Observation(1),Agreement()) end))
            assert(f.open().UpdateRecords(false,function(l,h,run) assert(run=="run-1" and not h.Observe(run,Observation(1),Agreement()));return l.Insert(Record()) end))
            local s=f.open().ReadRecords();assert(s.history.categories.matched.total==1 and s.history.overall.total==1 and #s.ledger.matched==1)
            assert(f.open().UpdateRecords(true,function(l,h,run) assert(run=="run-2");return h.Observe(run,Observation(1,"lost")) end))
            s=f.open().ReadRecords();assert(s.runCounter==2 and s.history.overall.total==2 and s.history.overall.winRate==0.5)
        end)
        Case(client.." late dispute persists across reopen",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run) assert(h.Observe(run,Observation(1),Agreement()));return l.Insert(Record()) end))
            assert(f.open().UpdateRecords(false,function(l)return l.Insert(Record(true)) end))
            local s=f.open().ReadRecords();assert(#s.ledger.disputed==1 and s.history.categories.disputed.total==1 and s.history.categories.matched.total==0 and s.history.overall.wins==1)
        end)
        Case(client.." account ledger shared / character history isolated",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run)assert(h.Observe(run,Observation(1),Agreement()));return l.Insert(Record())end))
            local saved=f.c;f.c=nil;f.owner=alt;local s=f.open().ReadRecords();assert(#s.ledger.matched==1 and s.history.overall.total==0 and s.runCounter==0)
            f.c=saved;f.owner=me;assert(f.open().ReadRecords().history.overall.total==1)
        end)
        Case(client.." invalid saved evidence and rejected edit preserve roots",function()
            local f=Fixture();assert(f.open().UpdateRecords(true,function(l,h,run)return h.Observe(run,Observation(1))end))
            local a,c=f.a,f.c;assert(not f.open().UpdateRecords(true,function()error("fixture")end));assert(f.a==a and f.c==c and f.writes==1)
            c.clients[client].history.observations[1].result.extra=true
            assert(not f.open().ReadRecords() and not f.open().UpdateRecords(true,function()return true end) and f.c==c and f.a==a)
        end)
        Case(client.." live gate rejects fixtures and record operations",function()
            local f=Fixture("LOCAL");local d=f.open();assert(d.Prepare());assert(not d.ReadRecords() and not d.UpdateRecords(true,function()error("must not run")end))
            local sim=Fixture();assert(sim.open().UpdateRecords(true,function(l,h,run)return h.Observe(run,Observation(1))end))
            f.a=sim.a;f.c=sim.c;assert(d.Snapshot().state=="unavailable" and not d.Prepare() and f.writes==1)
        end)
        Case(client.." invalid run token and unknown outcome roundtrip",function()
            local f=Fixture();assert(not f.open().UpdateRecords(true,function(l,h)return h.Observe("run-99",Observation(1))end));assert(f.writes==0)
            assert(f.open().UpdateRecords(true,function(l,h,run)local r=Observation(1);r.finishObserved=false;return h.Observe(run,r)end))
            local s=f.open().ReadRecords();assert(s.history.overall.unknown==1 and s.history.overall.wins==0)
        end)
    end
    Case("live status remains non-ranking",function()assert(P.GetSnapshot().rankEligible==false)end)
    return passed,failed
end

function P.RunArchiveSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local me,b,c,d="Player-1-AAA","Player-2-BBB","Player-3-CCC","Player-4-DDD"
    local epoch=100;local boundary=epoch+ns.SeasonRules.DURATION
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(scope)
            local f={owner=me,client=client,writes=0}
            function f.open()
                local x=Build(function()return f.a,f.c end,function(a,z)f.a=a;f.c=z;f.writes=f.writes+1 end,
                    function()return f.client end,function()return f.owner end,scope or "SIMULATED")
                x.MarkLoaded();return x
            end
            return f
        end
        local function Record(n,w,l)
            local x,y=w,l;if y<x then x,y=y,x end;local s="a-"..n..":b-"..n
            return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..x.."|"..y.."|"..s,
                player1=x,player2=y,winner=w,loser=l,endType="knockout",rankEligible=false,
                statement1=table.concat({"1",client,s,x,y,x==w and "won" or "lost","1"},"|"),
                statement2=table.concat({"1",client,s,y,x,y==w and "won" or "lost","2"},"|")}
        end
        local function Add(f,n,w,l,t) local r=Record(n,w,l);assert(f.open().UpdateSeasonEvidence(epoch,r,t,t));return r end
        Case(client.." archive absent read only and live gate",function()
            local f=Fixture();local r,why=f.open().ReadSeasonArchive(epoch);assert(not r and why=="no_archive" and f.writes==0)
            local live=Fixture("LOCAL");assert(not live.open().ReadSeasonArchive(epoch) and not live.open().UpdateSeasonEvidence(epoch,Record(1,me,b),epoch,epoch) and live.writes==0)
        end)
        Case(client.." archive reload rollover and rating progression",function()
            local f=Fixture();for i=1,3 do Add(f,i,me,b,epoch+i) end;Add(f,4,me,c,105);Add(f,5,me,d,106)
            local s=assert(f.open().ReadSeasonArchive(106));local rating=s.players[me].rating;local peak=s.players[me].peakRating
            assert(s.players[me].wins==5 and not s.players[me].rank.provisional and s.character==me)
            Add(f,6,me,b,boundary);s=assert(f.open().ReadSeasonArchive(boundary));local p=s.history[1].players[me]
            assert(s.season==2 and p.rating==rating and p.peakRating==peak and p.wins==5 and #s.changes==6 and s.changes[6].season==2 and s.players[me].credit==4)
            local writes=f.writes;s.history[1].players[me].rating=99999;s.changes[1].gain=0
            local again=assert(f.open().ReadSeasonArchive(boundary));assert(again.history[1].players[me].rating==rating and again.changes[1].gain==100 and f.writes==writes)
        end)
        Case(client.." late evidence rebuilds archived ratings",function()
            local f=Fixture();Add(f,2,me,c,boundary);local before=assert(f.open().ReadSeasonArchive(boundary));assert(not before.history[1])
            Add(f,1,me,b,epoch);local after=assert(f.open().ReadSeasonArchive(boundary));assert(after.history[1].players[me].rating==1100 and after.changes[2].winnerBefore~=before.changes[1].winnerBefore)
            assert(f.open().UpdateSeasonEvidence(epoch,Record(1,b,me),epoch,epoch));local disputed=assert(f.open().ReadSeasonArchive(boundary));assert(disputed.disputed==1 and not disputed.history[1] and disputed.changes[1].winnerBefore==1000)
        end)
        Case(client.." missing and disputed clocks persist",function()
            local f=Fixture();local r=Record(1,me,b);assert(f.open().UpdateSeasonEvidence(epoch,r));local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.missingTime==1 and #s.changes==0)
            assert(f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch));s=assert(f.open().ReadSeasonArchive(boundary));assert(s.history[1].players[me].rating==1100)
            assert(f.open().UpdateSeasonEvidence(epoch,r,epoch+1,epoch+1));s=assert(f.open().ReadSeasonArchive(boundary));assert(s.timeDisputed==1 and not s.history[1] and #s.changes==0)
        end)
        Case(client.." duplicate and schedule mismatch do not write",function()
            local f=Fixture();local r=Add(f,1,me,b,epoch);local a,z=f.a,f.c
            local ok,why=f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch);assert(ok and why=="unchanged" and f.writes==1 and f.a==a and f.c==z)
            assert(not f.open().UpdateSeasonEvidence(epoch+1,r,epoch,epoch) and not f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch+6) and not f.open().ReadSeasonArchive(epoch-1) and f.writes==1)
        end)
        Case(client.." account ledger shared and client partition isolated",function()
            local f=Fixture();Add(f,1,me,b,epoch);local old=f.c;f.c=nil;f.owner=c
            local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.character==c and s.history[1].players[c]==nil and s.history[1].players[me].rating==1100)
            f.client=client=="forever" and "retail" or "forever";assert(not f.open().ReadSeasonArchive(boundary));f.client=client;f.owner=me;f.c=old;assert(f.open().ReadSeasonArchive(boundary).character==me)
        end)
        Case(client.." existing records shared and malformed archive preserved",function()
            local f=Fixture();local r=Add(f,1,me,b,epoch);assert(f.open().UpdateRecords(false,function(l)return l.Insert(Record(2,me,c))end))
            local s=assert(f.open().ReadSeasonArchive(boundary));assert(s.missingTime==1 and #s.changes==1 and #f.open().ReadRecords().ledger.matched==2)
            local a,z,writes=f.a,f.c,f.writes;local part=a.clients[client];part.season.clocks.fake={{epoch,epoch}}
            assert(not f.open().ReadSeasonArchive(boundary) and not f.open().UpdateSeasonEvidence(epoch,r,epoch,epoch) and f.a==a and f.c==z and f.writes==writes)
        end)
    end
    Case("archive live data remains disabled",function()assert(P.GetSnapshot().scope=="LOCAL" and not P.GetSnapshot().rankEligible)end)
    return passed,failed
end

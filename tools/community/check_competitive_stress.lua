-- Offline stress suite: no live APIs or SavedVariables, no timing-based PASS gate.
local root=(arg and arg[1] or "addon/DuelsReimagined").."/Core/"
local ns={}
for _,name in ipairs({"CompetitiveScope","PeerAgreement","ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol"}) do
    assert(loadfile(root..name..".lua"))("DuelsReimagined",ns)
end
local sp,sf=ns.CompetitiveScope.RunSelfTest(print)
assert(sp==7 and sf==0,"competitive population QA")
local pp,pf=ns.CompetitiveStorage.RunPopulationSelfTest(print)
assert(pp==9 and pf==0,"scoped ranked storage and wire QA")
-- Reuse the isolated tournament model in the existing CI runner.
ns.Client={Kind=function()return "forever" end,IsSupported=function()return true end}
assert(loadfile(root.."TournamentState.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."TournamentRecovery.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."TournamentRegistration.lua"))("DuelsReimagined",ns)
local cp,cf=ns.TournamentState.RunCalendarSelfTest(print)
assert(cp==5 and cf==0,"calendar scheduling QA")
local tp,tf=ns.TournamentRegistration.RunSelfTest(print)
assert(tp==17 and tf==0,"tournament registration QA")
local ep,ef=ns.TournamentRegistration.RunExchangeSelfTest(print)
assert(ep==10 and ef==0,"tournament exchange QA")
local jp,jf=ns.TournamentRegistration.RunRecoverySelfTest(print)
assert(jp==10 and jf==0,"tournament recovery QA failed")
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Measure(fn)
    collectgarbage("collect");local start=os.clock();local value=fn()
    return value,(os.clock()-start)*1000
end
local epoch=100000
local limit=ns.MatchLedger.GetCapacity()
assert(limit==8192 and ns.PersonalHistory.GetCapacity()==8192 and ns.LeaderboardSync.GetPageLimit()==512)
local function Record(client,i)
    local a="Player-1-"..string.format("%03d",(i-1)%64+1)
    local b="Player-1-"..string.format("%03d",(i+math.floor((i-1)/64))%64+1)
    if a==b then b="Player-1-065" end
    if a>b then a,b=b,a end
    local s="a-"..i..":b-"..i;local win=i%3~=0
    return {scope="SIMULATED",version="1",client=client,session=s,id=client.."|"..a.."|"..b.."|"..s,
        player1=a,player2=b,winner=win and a or b,loser=win and b or a,endType="knockout",rankEligible=false,
        statement1=table.concat({"1",client,s,a,b,win and "won" or "lost","1"},"|"),
        statement2=table.concat({"1",client,s,b,a,win and "lost" or "won","1"},"|")}
end
for _,client in ipairs({"forever","retail"}) do
    local sourceLedger=assert(ns.MatchLedger.OpenSimulated(client));local clocks={}
    for i=1,limit do local r=Record(client,i);assert(sourceLedger.Insert(r));local t=epoch+i*4000;clocks[r.id]={{t,t}} end
    local saved={version=1,scope="SIMULATED",client=client,rule=ns.CompetitiveRules.ID,ledger=sourceLedger.Save(),clocks=clocks}
    local source=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,saved))
    local asOf=epoch+limit*4000
    local opts={epoch=epoch,asOf=asOf}
    local replay,replayMS=Measure(function()return assert(source.ReplaySeasonSimulated(opts))end)
    assert(replay.matched==limit and replay.history[1] and replay.season==math.floor(limit*4000/ns.SeasonRules.DURATION)+1 and not replay.rankEligible)
    local old,oldMS=Measure(function()
        return assert(source.Export("stress"))
    end)
    local new,newMS=Measure(function()
        local pages={};for i=1,limit/16 do pages[i]=assert(source.ExportPage("stress",i))end;return pages
    end)
    assert(Equal(old,new),"page parity")
    local receiver=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch));local frames,bytes=0,0
    local _,syncMS=Measure(function()
        local q=assert(ns.SyncProtocol.NewRequester(client,receiver,"stress"));local r=assert(ns.SyncProtocol.NewResponder(client,source))
        local a,b="Player-1-AAA","Player-2-BBB";local t=0
        for page=math.floor(limit/16),1,-1 do
            assert(r.Begin(assert(q.Begin(a,page,t)),b,b,t));local packets={}
            while true do local msg=r.Next(t);if not msg then break end;assert(#msg+3<=240);packets[#packets+1]=msg;frames=frames+1;bytes=bytes+#msg+3;t=t+0.5 end
            for i=#packets,1,-1 do local ok,why=q.Receive(packets[i],a,t);assert(ok,why);if i==1 then assert(why=="page_complete")end end
            t=t+2
        end
    end)
    assert(Equal(source.Save(),receiver.Save()) and Equal(replay,receiver.ReplaySeasonSimulated(opts)),"full capacity convergence")
    local r=Record(client,limit+1);local ok,why=receiver.Observe(r,asOf,asOf)
    assert(not ok and why=="capacity" and Equal(source.Save(),receiver.Save()),"capacity must reject without loss")
    -- Five missing records: actual simulated summary/group packets, including
    -- request bytes and tag allowance. No real network timing or delivery.
    local partial=source.Save()
    for i=1,5 do local id=Record(client,i).id;partial.ledger.entries[id]=nil;partial.clocks[id]=nil end
    local behind=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,partial))
    local q=assert(ns.SyncProtocol.NewRequester(client,behind,"delta-stress"))
    local r=assert(ns.SyncProtocol.NewResponder(client,source))
    local a,b="Player-1-AAA","Player-2-BBB"
    local t,deltaFrames,deltaBytes=0,0,0
    local function Transfer(msg,status)
        assert(#msg+3<=240);deltaBytes=deltaBytes+#msg+3;deltaFrames=deltaFrames+1
        assert(r.Begin(msg,b,b,t))
        local packets={}
        while true do
            local body=r.Next(t);if not body then break end
            assert(#body+3<=240);packets[#packets+1]=body
            deltaFrames=deltaFrames+1;deltaBytes=deltaBytes+#body+3;t=t+0.5
        end
        local value
        for i=#packets,1,-1 do
            local ok,why,v=q.Receive(packets[i],a,t);assert(ok,why)
            if i==1 then assert(why==status);value=v end
        end
        t=t+2;return value
    end
    -- Exercise budgeted cold preparation on both full-size ledgers before
    -- the wire operation. The existing synchronous fallback is retained.
    local function Prepare(node,expected)
        local calls,work=0,0
        while true do
            local ready,used=node.PrepareDelta(32)
            assert(type(ready)=="boolean" and used<=32)
            calls=calls+1;work=work+used
            if ready then break end
            assert(used>0 and calls<=1024)
        end
        assert(work==2*expected)
        return calls
    end
    local sourceCalls=Prepare(source,limit)
    local behindCalls=Prepare(behind,limit-5)
    print(string.format("%s: budgeted cold preparation %d/%d calls, 32 record operations max per call; PASS",client,sourceCalls,behindCalls))
    local plan=Transfer(assert(q.BeginSummary(a,t)),"summary_complete")
    assert(plan.different>=1 and plan.different<=5)
    local cold=behind.GetDeltaWork();assert(cold.records==limit-5)
    local compared=0
    for _,g in ipairs(plan.pulls) do
        compared=compared+g.expected.count
        for i=g.pages,1,-1 do Transfer(assert(q.BeginDelta(a,g.group,g.expected,i,t)),"page_complete") end
    end
    assert(compared>=5 and compared<limit and Equal(source.Save(),behind.Save()))
    local final=Transfer(assert(q.BeginSummary(a,t)),"summary_complete")
    assert(final.different==0 and #final.pulls==0 and Equal(replay,behind.ReplaySeasonSimulated(opts)))
    local warm=behind.GetDeltaWork()
    assert(warm.groups-cold.groups==plan.different and warm.records-cold.records==compared)
    local fresh=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,behind.Save()))
    assert(Equal(fresh.DeltaSummary(),behind.DeltaSummary()))
    assert(behind.GetDeltaWork().records==warm.records)
    print(string.format("%s: incremental comparison rehashed %d of %d records across %d groups; cold rebuild parity PASS",client,warm.records-cold.records,limit,warm.groups-cold.groups))
    -- Delta includes requests and final summary; full bytes are response-only,
    -- so this comparison is conservative.
    assert(deltaBytes<bytes)
    print(string.format("%s: five missing matches; %d differing groups; %d logical records; %d delta packets / %d bytes versus full response-only %d bytes; exact convergence PASS",client,plan.different,compared,deltaFrames,deltaBytes,bytes))
    -- Exercise durable private roots at the expanded capacity, not just node memory.
    local owner="Player-1-AAA"
    local roots={version=2,kind="account",scope="SIMULATED",clients={[client]={probe=0,ledger=saved.ledger,
        season={version=1,rule=ns.SeasonRules.BALANCED_ID,epoch=epoch,clocks=saved.clocks}}}}
    local char=nil
    local writes=0
    local function OpenStorage()
        local d=ns.CompetitiveStorage.NewSimulated(function()return roots,char end,
            function(a,c)roots=a;char=c;writes=writes+1 end,function()return client end,function()return owner end)
        d.MarkLoaded();return d
    end
    local d=OpenStorage()
    local stored=assert(d.ReadSeasonArchive(asOf));stored.character=nil;assert(Equal(stored,replay),"large archive reopen")
    local function Observation(i)
        return {scope="SIMULATED",client=client,id=i,kind="standard",opponent={guid="Player-2-BBB"},
            acceptedAt=i,endedAt=i+1,outcome="won",endType="knockout",reason="matching_result_and_finish",
            outcomeObserved=true,finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
    end
    local personal=ns.PersonalHistory.GetCapacity()
    assert(d.UpdateRecords(true,function(_,h,run)
        for i=1,personal do assert(h.Observe(run,Observation(i))) end
        local ok,why=h.Observe(run,Observation(personal+1));assert(not ok and why=="capacity")
        return true
    end))
    local stats=assert(OpenStorage().ReadRecords());assert(stats.history.overall.wins==personal and #stats.history.history==personal)
    local first=Record(client,1)
    first.winner,first.loser=first.loser,first.winner
    first.statement1,first.statement2=first.statement1:gsub("|won|","|lost|"),first.statement2:gsub("|lost|","|won|")
    assert(OpenStorage().UpdateSeasonEvidence(epoch,first,epoch+4000,epoch+4000))
    local corrected=assert(OpenStorage().ReadSeasonArchive(asOf))
    assert(corrected.disputed==1 and corrected.matched==limit-1 and corrected.history[1] and #corrected.changes==limit-1)
    assert(corrected.changes[1].id~=first.id and writes==2)
    assert(#assert(OpenStorage().ReadRecords()).history.history==personal)
    local savedAccount,savedChar=roots,char
    assert(not OpenStorage().UpdateSeasonEvidence(epoch,Record(client,limit+1),asOf,asOf) and roots==savedAccount and char==savedChar and writes==2)
    -- Lossless compact representation at maximum fixture size. Estimate a
    -- consistent serialized table payload, not WoW's actual disk or heap bytes.
    local function Size(v)
        if type(v)=="string" then return #string.format("%q",v) end
        if type(v)~="table" then return #tostring(v) end
        local n=2
        for k,x in pairs(v) do n=n+Size(k)+Size(x)+4 end
        return n
    end
    local expandedBytes=Size(roots.clients[client].ledger)
    assert(OpenStorage().CompactEvidence() and writes==3)
    local compactBytes=Size(roots.clients[client].ledger)
    assert(compactBytes<expandedBytes and roots.clients[client].ledger.version==2)
    assert(Equal(corrected,OpenStorage().ReadSeasonArchive(asOf)))
    local view=assert(OpenStorage().OpenCompetitiveView(asOf))
    local profile=assert(view.Profile(first.player1))
    local summary=assert(view.ProfileSummary(first.player1))
    assert(profile.stats.games==summary.stats.games and summary.stats.progression==nil)
    local p=view.Progression(first.player1,corrected.season,0,100)
    assert(p.total==#profile.stats.progression)
    local board=view.Leaderboard(corrected.season,0,100,"","wins")
    assert(board.total==board.knownRanked and Equal(board,view.Leaderboard(corrected.season,0,100,"","wins")))
    assert(view.Personal().overall.wins==personal and writes==3)
    print(string.format("%s: compact ledger estimated serialized payload %d -> %d bytes; full replay parity and paginated read view PASS",client,expandedBytes,compactBytes))
    print(string.format("%s: %d records; %d personal observations; %d pages; %d frames; %d bytes; full export once %.2f ms; all requested pages %.2f ms; replay %.2f ms; wire processing %.2f ms; archive reopen and historical correction PASS",client,limit,personal,limit/16,frames,bytes,oldMS,newMS,replayMS,syncMS))
end

-- Multiple independent peers with disjoint histories and late corrections.
-- Each catch-up is driven through the real simulated packet lifecycle.
for _,client in ipairs({"forever","retail"}) do
    local function Node() return assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch)) end
    local a,b,c=Node(),Node(),Node()
    for i=1,384 do
        local r=Record(client,i);local t=epoch+i*4000
        local node=({a,b,c})[(i-1)%3+1];assert(node.Observe(r,t,t))
    end
    -- B knows a conflicting outcome for a match owned by A. C has a
    -- conflicting clock for one owned by B. Neither is a trusted authority.
    local first=Record(client,1)
    first.winner,first.loser=first.loser,first.winner
    first.statement1,first.statement2=first.statement1:gsub("|won|","|lost|"),first.statement2:gsub("|lost|","|won|")
    assert(b.Observe(first,epoch+4000,epoch+4000))
    assert(c.Observe(Record(client,2),epoch+8001,epoch+8001))
    local tick,seq,packetCount=0,0,0
    local from,to="Player-1-AAA","Player-2-BBB"
    local function Pull(source,target,mode)
        seq=seq+1
        local q=assert(ns.SyncProtocol.NewCatchupSimulated(client,target,"multi-"..seq,from,mode))
        local r=assert(ns.SyncProtocol.NewResponder(client,source))
        for _=1,10000 do
            local st=q.GetStatus()
            if st.state~="working" then
                assert(st.state=="summary_agrees" or st.state=="differences_remaining" or st.state=="audit_received",st.state)
                assert(st.restarts==0 and st.completeness=="unknown")
                return st
            end
            local msg,why=q.Poll(tick)
            if msg then
                assert(#msg+3<=240);packetCount=packetCount+1
                assert(r.Begin(msg,to,to,tick))
                local packets={}
                while true do
                    local body=r.Next(tick);if not body then break end
                    assert(#body+3<=240);packets[#packets+1]=body
                    packetCount=packetCount+1;tick=tick+0.5
                end
                for i=#packets,1,-1 do assert(q.Receive(packets[i],from,tick)) end
                tick=tick+2
            else
                assert(why=="preparing" or why=="backoff",why)
                tick=tick+2
            end
        end
        error("multi-peer catch-up exceeded fixture step limit")
    end
    Pull(a,b,"delta");Pull(b,c,"delta");Pull(c,a,"audit");Pull(c,b,"delta")
    assert(Equal(a.Save(),b.Save()) and Equal(b.Save(),c.Save()),"multi-peer union")
    local opts={epoch=epoch,asOf=epoch+384*4000}
    local result=assert(a.ReplaySeasonSimulated(opts))
    assert(result.knownMatched==383 and result.disputed==1 and result.timeDisputed==1 and result.matched==382)
    assert(Equal(result,b.ReplaySeasonSimulated(opts)) and Equal(result,c.ReplaySeasonSimulated(opts)))
    local steady=Pull(a,b,"delta");assert(steady.state=="summary_agrees" and steady.pages==0 and steady.requests==1)
    local audit=Pull(a,b,"audit");assert(audit.state=="audit_received" and audit.pages==24)
    assert(Equal(a.Save(),b.Save()))
    print(string.format("%s: three peers, 384 unique matches, late outcome/clock disputes, relay, steady-state and exact audit; %d simulated packets; PASS",client,packetCount))
end

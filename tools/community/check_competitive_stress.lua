-- Offline stress suite: no live APIs or SavedVariables, no timing-based PASS gate.
local root=(arg and arg[1] or "addon/DuelsReimagined").."/Core/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol"}) do
    assert(loadfile(root..name..".lua"))("DuelsReimagined",ns)
end
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
    -- Logical catch-up with five missing records, not wire traffic measurement.
    local partial=source.Save()
    for i=1,5 do local id=Record(client,i).id;partial.ledger.entries[id]=nil;partial.clocks[id]=nil end
    local behind=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,partial))
    local plan=assert(behind.PlanDelta(source.DeltaSummary()))
    assert(plan.different>=1 and plan.different<=5)
    local compared=0
    for _,g in ipairs(plan.pulls) do
        for i=g.pages,1,-1 do
            local page=assert(source.ExportDeltaPage("delta",g.group,g.expected,i))
            compared=compared+#page.entries
            assert(behind.Receive(page,"Player-1-AAA","Player-1-AAA","delta"))
        end
    end
    assert(compared>=5 and compared<limit and Equal(source.Save(),behind.Save()))
    assert(#assert(behind.PlanDelta(source.DeltaSummary())).pulls==0)
    assert(Equal(replay,behind.ReplaySeasonSimulated(opts)))
    print(string.format("%s: five missing matches, %d differing groups, %d logical records transferred versus %d full records; exact convergence PASS",client,plan.different,compared,limit))
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
    print(string.format("%s: %d records; %d personal observations; %d pages; %d frames; %d bytes; full export once %.2f ms; all requested pages %.2f ms; replay %.2f ms; wire processing %.2f ms; archive reopen and historical correction PASS",client,limit,personal,limit/16,frames,bytes,oldMS,newMS,replayMS,syncMS))
end

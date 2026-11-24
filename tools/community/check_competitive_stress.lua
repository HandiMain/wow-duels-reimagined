-- Offline stress suite: no live APIs or SavedVariables, no timing-based PASS gate.
local root=(arg and arg[1] or "addon/DuelsReimagined").."/Core/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol"}) do
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
local limit=2048
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
    assert(replay.matched==limit and replay.history[1] and replay.season==2 and not replay.rankEligible)
    local old,oldMS=Measure(function()
        local pages={};for i=1,limit/16 do pages[i]=assert(source.Export("stress"))[i] end;return pages
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
    print(string.format("%s: %d records; %d pages; %d frames; %d bytes; full export %.2f ms; single page %.2f ms; replay %.2f ms; wire transfer %.2f ms; PASS",client,limit,limit/16,frames,bytes,oldMS,newMS,replayMS,syncMS))
end

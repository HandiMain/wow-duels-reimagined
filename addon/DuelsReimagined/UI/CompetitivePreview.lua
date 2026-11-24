local _,ns=...
-- DEVELOPMENT PREVIEW ONLY. These fixtures are not player records, never
-- access SavedVariables or real identities, and use the existing replay.
local P={}
ns.CompetitivePreview=P
local names={"Shadowpriest","Voidreign","Frostblade","Pyrelord","Nightveil","Grimhex","Lightwarden","Felborne","Thundercall","Mindscar","Hawkeye","Stoneguard","Arcanist","Zerathian","Velmora","Kalthiris","Draevyn","Vexalor","Seryndris","Myrren"}
local classes={"PRIEST","PRIEST","MAGE","MAGE","ROGUE","DEATHKNIGHT","PALADIN","WARLOCK","SHAMAN","PRIEST","HUNTER","WARRIOR","MAGE","ROGUE","MAGE","PRIEST","PALADIN","WARRIOR","PALADIN","ROGUE"}
local realms={"Silvermoon","Silvermoon","Tarren Mill","Stormrage","Ragnaros","Draenor","Silvermoon","Outland","Draenor","Twisting Nether","Stormrage","Defias Brotherhood","Kazzak"}
local surnames={"Duskwalker","Nightfall","Frostborn","Emberwind","Shadowblade","Grimforge","Lightbringer","Felthorn","Stormcaller","Mindweaver"}
local function Guid(i) return string.format("Player-99-DR%04d",i) end
local function Build(client)
    assert(client=="retail" or client=="forever")
    local epoch=1700000000
    local duration=ns.SeasonRules.DURATION
    local asOf=epoch+2*duration+61*86400
    local node=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
    local ids,metadata,localRows={},{},{}
    for i,name in ipairs(names) do
        local id=Guid(i);ids[i]=id
        local realm=client=="retail" and realms[(i-1)%#realms+1] or nil
        metadata[id]={scope="SIMULATED",client=client,guid=id,name=name,
            fullName=realm and name.."-"..realm or name.." "..surnames[(i-1)%#surnames+1],
            realm=realm,class=classes[i],faction=i%3==0 and "Horde" or "Alliance",observedAt=asOf}
    end
    local me=ids[1];local cycle=0
    local function Match(i,j,win,t)
        cycle=cycle+1
        local a,b=ids[i],ids[j];if b<a then a,b=b,a end
        local winner=ids[win];local s="preview-"..cycle..":duel-"..cycle
        local x=table.concat({"1",client,s,a,b,a==winner and "won" or "lost",tostring(cycle)},"|")
        local y=table.concat({"1",client,s,b,a,b==winner and "won" or "lost",tostring(cycle)},"|")
        local r=assert(ns.ResultConfirmation.DecodeStatementsSimulated(client,x,y))
        assert(node.Observe(r,t,t))
        if a==me or b==me then
            localRows[#localRows+1]={cycle=cycle,peer=a==me and b or a,outcome=winner==me and "won" or "lost",
                session=s,matchID=r.id,duration=54+(cycle*17)%94,time=t}
        end
    end
    -- Round-robin opponent rotation, deterministic outcomes and actual UTC
    -- fixture chronology. No random state or fake persisted ratings.
    for season=1,3 do
        local order={}
        for i=1,#ids do order[i]=i end
        for round=1,38 do
            local t=epoch+(season-1)*duration+(round-1)*math.floor(60*86400/38)+3600
            for slot=1,#ids/2 do
                local i,j=order[slot],order[#ids-slot+1]
                local function Strength(n) return n==2 and 100 or n==1 and 67 or 82-n*3 end
                local chance=math.max(8,math.min(92,50+Strength(i)-Strength(j)))
                local roll=(round*37+i*19+j*13+season*29)%100
                Match(i,j,roll<chance and i or j,t+slot*60)
            end
            local last=table.remove(order);table.insert(order,2,last)
        end
    end
    -- Extra same-pair duels exercise zero-credit practice. A late conflicting
    -- statement and a missing peer confirmation exercise honest history states.
    for i=1,8 do Match(1,3,1,asOf-1200+i*90) end
    local disputed=localRows[#localRows-8]
    local a,b=me,disputed.peer;if b<a then a,b=b,a end
    local winner=disputed.outcome=="won" and disputed.peer or me
    local x=table.concat({"1",client,disputed.session,a,b,a==winner and "won" or "lost",tostring(disputed.cycle)},"|")
    local y=table.concat({"1",client,disputed.session,b,a,b==winner and "won" or "lost",tostring(disputed.cycle)},"|")
    assert(node.Observe(assert(ns.ResultConfirmation.DecodeStatementsSimulated(client,x,y)),disputed.time,disputed.time))
    cycle=cycle+1
    localRows[#localRows+1]={cycle=cycle,peer=ids[5],outcome="won",session="pending-"..cycle..":duel-"..cycle,duration=94}
    local saved=node.Save()
    local ledger=assert(ns.MatchLedger.OpenSimulated(client,saved.ledger))
    local history=assert(ns.PersonalHistory.OpenSimulated(client,me,ledger))
    local function Observe(row)
        local r={scope="SIMULATED",client=client,id=row.cycle,kind="standard",opponent={guid=row.peer},
            acceptedAt=0,endedAt=row.duration,outcome=row.outcome,endType="knockout",
            reason="matching_result_and_finish",outcomeObserved=true,finishObserved=true,resultObserved=true,conflict=false,rankEligible=false}
        local ag=row.session and {scope="SIMULATED",state="candidate",candidate=true,rankEligible=false,session=row.session} or nil
        assert(history.Observe("run-1",r,ag))
    end
    -- A small number of ordinary duels appear among recent rated matches.
    local extra={}
    for i,row in ipairs(localRows) do
        if i>#localRows-10 and i%3==0 then
            cycle=cycle+1
            local e={cycle=cycle,peer=ids[(i%18)+2],outcome=i%2==0 and "won" or "lost",duration=72+i%43}
            Observe(e);extra[#extra+1]=e
        end
        Observe(row)
    end
    local roots={version=2,kind="account",scope="SIMULATED",clients={[client]={probe=0,ledger=saved.ledger,
        identities=metadata,season={version=1,rule=ns.SeasonRules.BALANCED_ID,epoch=epoch,clocks=saved.clocks}}}}
    local char={version=2,kind="character",scope="SIMULATED",owner=me,clients={[client]={probe=0,runCounter=1,history=history.Save()}}}
    local store=ns.CompetitiveStorage.NewSimulated(function()return roots,char end,function()error("preview is read-only")end,
        function()return client end,function()return me end)
    store.MarkLoaded()
    local view=assert(store.OpenCompetitiveView(asOf))
    local replay=assert(store.ReadSeasonArchive(asOf))
    local change={}
    for _,r in ipairs(replay.changes) do change[r.id]=r end
    local personal=view.Personal()
    local matches={}
    for i=#personal.history,1,-1 do
        local row=personal.history[i]
        local r=row.matchID and change[row.matchID]
        local category=row.category
        if category=="matched" and r then category=r.weight>0 and "Ranked" or "Practice"
        elseif category=="matched" then category="Unconfirmed"
        else category=category:sub(1,1):upper()..category:sub(2) end
        local before,after,delta
        if r and row.category=="matched" then
            local win=r.winner==me
            before=win and r.winnerBefore or r.loserBefore
            after=win and r.winnerAfter or r.loserAfter
            delta=after-before
        end
        matches[#matches+1]={id=row.id,identity=metadata[row.opponent],peer=row.opponent,
            category=category,outcome=row.outcome,duration=row.duration,before=before,after=after,delta=delta,
            time=r and r.time,confirmed=row.category=="matched"}
    end
    return {scope="SIMULATED",rankEligible=false,client=client,me=me,view=view,identities=metadata,
        asOf=asOf,epoch=epoch,current=view.Status().season,personal=personal.overall,matches=matches}
end
P.Build=Build
local cached
function P.Get()
    local client=ns.Client.Kind()
    if not cached or cached.client~=client then cached=Build(client) end
    return cached
end

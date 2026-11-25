local _,ns=...
-- Single-elimination domain; simulated input only. No live duel results,
-- storage, timers, communication, ratings or coordinator privileges.
local B={};ns.TournamentBracket=B
local P=ns.CompetitiveScope
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
    return type(v)=="number" and v>=lo and v<=hi and v==math.floor(v)
end
local function Token(v)
    return type(v)=="string" and #v>0 and #v<=96 and v:match("^[%w%-_:]+$")~=nil
end
local function Canonical(scope,owner,snapshot,now)
    if not P.Key(scope) or not Whole(now,1,4102444800) then return nil end
    local c=ns.TournamentRegistration.ValidateHostCheckpoint(scope.client,owner,{host=snapshot,receipts={}})
    if not c or not P.Matches(scope,c.host.ad) or c.host.ad.state~="open" or now<c.host.ad.draft.startAt then return nil end
    local entrants={}
    for _,m in ipairs(c.host.roster) do if m.checkedIn then entrants[#entrants+1]=m.guid end end
    if #entrants<2 then return nil end
    return c.host,entrants
end
-- Frozen canonical GUID order + event-derived seed. Not cryptographic or
-- proof of an unbiased organizer; no reroll control is exposed here.
local function Draw(id,entrants,size)
    local seed=1
    for i=1,#id do seed=(seed*131+id:byte(i))%2147483647 end
    if seed==0 then seed=1 end
    local pool=Copy(entrants)
    for i=#pool,2,-1 do
        seed=(seed*48271)%2147483647
        local j=seed%i+1;pool[i],pool[j]=pool[j],pool[i]
    end
    local order={1,2}
    while #order<size do
        local n=#order*2+1;local next={}
        for _,v in ipairs(order) do next[#next+1]=v;next[#next+1]=n-v end
        order=next
    end
    local slots={}
    for i,v in ipairs(order) do slots[i]=pool[v] or false end
    return slots
end
local function Engine(scope,owner,snapshot,now)
    local cp,entrants=Canonical(scope,owner,snapshot,now)
    if not cp then return nil end
    local ad=cp.ad
    local slots=Draw(ad.id,entrants,ad.draft.capacity)
    local rounds,byID={},{}
    local count=#slots/2
    while count>=1 do
        local r=#rounds+1;rounds[r]={}
        for i=1,count do
            local m={id="R"..r.."M"..i,round=r,index=i,state="waiting",wins={0,0},games={}}
            rounds[r][i]=m;byID[m.id]=m
        end
        count=count/2
    end
    local journal,used,paused={}, {},false
    local needed=math.floor(ad.draft.bestOf/2)+1
    local function Refresh()
        for r,round in ipairs(rounds) do
            for i,m in ipairs(round) do
                if m.state=="waiting" then
                    local a,b,ready
                    if r==1 then a,b=slots[2*i-1],slots[2*i];ready=true
                    else
                        local x,y=rounds[r-1][2*i-1],rounds[r-1][2*i]
                        ready=x.state=="done" and y.state=="done"
                        if ready then a,b=x.winner,y.winner end
                    end
                    if ready then
                        m.a=a;m.b=b
                        if a and b then m.state="ready"
                        else m.state="done";m.winner=a or b or false;m.bye=true end
                    end
                end
            end
        end
    end
    Refresh()
    local D={}
    function D.Snapshot()
        local final=rounds[#rounds][1]
        return {scope="SIMULATED",event=ad.id,owner=owner,sourceRevision=ad.revision,
            capacity=ad.draft.capacity,bestOf=ad.draft.bestOf,slots=Copy(slots),rounds=Copy(rounds),
            state=paused and "disputed" or final.state=="done" and "completed" or "running",
            champion=not paused and final.state=="done" and final.winner or nil,
            revision=#journal}
    end
    function D.Save()
        return {version=1,scope="SIMULATED",checkpoint=Copy(cp),startedAt=now,reports=Copy(journal)}
    end
    function D.Report(sender,report)
        if type(report)~="table" or report.event~=ad.id or type(report.match)~="string"
            or not Whole(report.game,1,ad.draft.bestOf) or not Token(report.evidence) then return false end
        local m=byID[report.match]
        if not m or not m.a or not m.b or (sender~=m.a and sender~=m.b)
            or (report.winner~=m.a and report.winner~=m.b) then return false end
        local record={sender=sender,event=ad.id,match=m.id,game=report.game,winner=report.winner,evidence=report.evidence}
        local input={event=ad.id,match=m.id,game=report.game,winner=report.winner,evidence=report.evidence}
        if not Equal(input,report) then return false end
        local game=m.games[report.game]
        local prior=game and game.reports[sender]
        if prior and Equal(prior,record) then return true,"duplicate" end
        if paused then return false end
        local gameKey=m.id..":"..report.game
        if used[report.evidence] and used[report.evidence]~=gameKey then return false end
        -- A contradictory report about an already accepted game freezes
        -- advancement; never silently rewrites a champion or awards.
        if prior then
            journal[#journal+1]=record;paused=true;return true,"disputed"
        end
        if m.state~="ready" or report.game~=m.wins[1]+m.wins[2]+1 then return false end
        if not game then game={reports={}};m.games[report.game]=game end
        game.reports[sender]=record;used[report.evidence]=gameKey;journal[#journal+1]=record
        local a,b=game.reports[m.a],game.reports[m.b]
        if not a or not b then return true,"pending" end
        if a.winner~=b.winner or a.evidence~=b.evidence then paused=true;return true,"disputed" end
        local side=a.winner==m.a and 1 or 2
        game.winner=a.winner;m.wins[side]=m.wins[side]+1
        if m.wins[side]==needed then m.state="done";m.winner=a.winner;Refresh() end
        return true,"confirmed"
    end
    -- Series forfeits are not played duel results.
    local function Forfeit(m,loser,reason,record)
        journal[#journal+1]=record
        m.state="done";m.winner=loser==m.a and m.b or m.a
        m.forfeit={loser=loser,reason=reason};Refresh()
        return true,"forfeited"
    end
    function D.Withdraw(sender,request)
        if paused or type(request)~="table" or request.event~=ad.id then return false end
        local m=byID[request.match]
        if not m or not m.a or not m.b or (sender~=m.a and sender~=m.b)
            or not Equal(request,{event=ad.id,match=m.id}) then return false end
        if m.forfeit and m.forfeit.reason=="withdrawn" and m.forfeit.loser==sender then return true,"duplicate" end
        if m.state~="ready" then return false end
        return Forfeit(m,sender,"withdrawn",{kind="withdraw",sender=sender,event=ad.id,match=m.id})
    end
    -- Only the observation adapter may establish continuous absence.
    -- Replay checks structure, not actual network presence.
    function D.ForfeitOffline(record)
        if paused or type(record)~="table" or record.event~=ad.id or record.revision~=#journal
            or not Whole(record.since,now,4102444500) or not Whole(record.at,record.since+300,4102444800) then return false end
        local m=byID[record.match]
        if not m or m.state~="ready" or (record.loser~=m.a and record.loser~=m.b)
            or not Equal(record,{kind="offline",event=ad.id,match=m.id,revision=#journal,loser=record.loser,since=record.since,at=record.at}) then return false end
        return Forfeit(m,record.loser,"offline",Copy(record))
    end
    return D
end
function B.NewSimulated(scope,owner,snapshot,now,sender)
    if sender~=owner then return nil end
    return Engine(scope,owner,snapshot,now)
end
function B.OpenSimulated(scope,owner,saved)
    if type(saved)~="table" or saved.version~=1 or saved.scope~="SIMULATED" or type(saved.reports)~="table" then return nil end
    local n=0
    for k in pairs(saved.reports) do
        n=n+1;if n>342 or not Whole(k,1,342) then return nil end
    end
    local d=Engine(scope,owner,saved.checkpoint,saved.startedAt)
    if not d then return nil end
    for i=1,n do
        local r=saved.reports[i]
        if type(r)~="table" then return nil end
        local ok,why
        if r.kind=="offline" then ok,why=d.ForfeitOffline(r)
        elseif r.kind=="withdraw" then ok,why=d.Withdraw(r.sender,{event=r.event,match=r.match})
        else ok,why=d.Report(r.sender,{event=r.event,match=r.match,game=r.game,winner=r.winner,evidence=r.evidence}) end
        if not ok or why=="duplicate" then return nil end
    end
    if Equal(d.Save(),saved) then return d end
end
function B.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture(size,count,best)
            local s={client=client,region="EU",ruleset=client=="forever" and "pvp" or "retail",faction="Alliance"}
            local T=ns.TournamentState
            local owner="Player-1-HOST";local stamp=1795622400
            local d=T.DraftDefaults();d.name="Bracket Cup";d.location="Meeting place";d.startUTC="2026-11-25 18:00"
            d.capacity=size;d.bestOf=best
            d=assert(T.ValidateDraft(client,d,stamp,s.region,s.ruleset,s.faction))
            local a=Copy(s);a.scope="SIMULATED";a.version=1;a.id=owner..":"..stamp..":1";a.owner=owner
            a.organizer="Organizer";a.state="open";a.publishedAt=stamp;a.serial=1;a.revision=1+2*count;a.draft=d;a.count=count
            local rows={}
            for i=1,count do rows[i]={guid=string.format("Player-1-P%02d",i),name="Player "..i,level=30,checkedIn=true} end
            local cp={ad=a,roster=rows}
            return s,owner,cp,d.startAt
        end
        local function Ready(d)
            for _,round in ipairs(d.Snapshot().rounds) do
                for _,m in ipairs(round) do if m.state=="ready" then return m end end
            end
        end
        local function Report(d,m,g,w,e,sender)
            return d.Report(sender,{event=d.Snapshot().event,match=m.id,game=g,winner=w,evidence=e})
        end
        local function Finish(d)
            local played=0
            while true do
                local m=Ready(d);if not m then break end
                local game=m.wins[1]+m.wins[2]+1;local e=m.id..":"..game
                assert(Report(d,m,game,m.a,e,m.a));assert(Report(d,m,game,m.a,e,m.b))
                played=played+1;assert(played<=155)
            end
            return played
        end
        Case(client.." all capacities and sparse byes produce one champion",function()
            for _,size in ipairs({4,8,16,32}) do
                for _,n in ipairs({2,math.floor(size/2)+1,size}) do
                    local s,h,cp,now=Fixture(size,n,1)
                    local d=assert(B.NewSimulated(s,h,cp,now,h));local view=d.Snapshot()
                    assert(#view.slots==size and not view.champion)
                    local seen={};local actual=0
                    for _,g in ipairs(view.slots) do if g then assert(not seen[g]);seen[g]=true;actual=actual+1 end end
                    assert(actual==n and Finish(d)==n-1)
                    local final=d.Snapshot();assert(final.state=="completed" and seen[final.champion])
                end
            end
        end)
        Case(client.." frozen draw refuses early start, foreign scope and organizer spoof",function()
            local s,h,cp,now=Fixture(8,5,1)
            assert(not B.NewSimulated(s,h,cp,now-1,h))
            assert(not B.NewSimulated(s,h,cp,now,cp.roster[1].guid))
            local wrong=Copy(s);wrong.faction="Horde";assert(not B.NewSimulated(wrong,h,cp,now,h))
            local d=assert(B.NewSimulated(s,h,cp,now,h))
            assert(Equal(d.Snapshot(),assert(B.NewSimulated(s,h,cp,now,h)).Snapshot()))
            cp.roster[1].checkedIn=false
            assert(not Equal(d.Save().checkpoint,cp))
            for i=2,#cp.roster do cp.roster[i].checkedIn=false end
            assert(not B.NewSimulated(s,h,cp,now,h))
        end)
        Case(client.." best-of 1 3 5 requires both reports and correct game order",function()
            for _,best in ipairs({1,3,5}) do
                local s,h,cp,now=Fixture(4,4,best)
                local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
                assert(not Report(d,m,1,m.a,"fake",h))
                assert(not Report(d,m,2,m.a,"future",m.a))
                assert(Report(d,m,1,m.a,"first",m.a))
                assert(d.Snapshot().rounds[1][1].wins[1]==0)
                local ok,why=Report(d,m,1,m.a,"first",m.a);assert(ok and why=="duplicate")
                assert(Report(d,m,1,m.a,"first",m.b))
                local next=Ready(d)
                if best>1 then assert(next.id==m.id and next.wins[1]==1) else assert(next.id~=m.id) end
                assert(Finish(d)==3*(math.floor(best/2)+1)-1)
            end
        end)
        Case(client.." evidence replay and premature advancement refused",function()
            local s,h,cp,now=Fixture(4,4,1)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            assert(Report(d,m,1,m.a,"same",m.a));assert(Report(d,m,1,m.a,"same",m.b))
            local next=Ready(d);assert(not Report(d,next,1,next.a,"same",next.a))
            local final=d.Snapshot().rounds[2][1]
            assert(not d.Report(m.a,{event=cp.ad.id,match=final.id,game=1,winner=m.a,evidence="premature"}))
            assert(not d.Snapshot().champion)
        end)
        Case(client.." contradictory reports freeze all progression and champion",function()
            local s,h,cp,now=Fixture(4,4,1)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            assert(Report(d,m,1,m.a,"same",m.a));assert(Report(d,m,1,m.b,"same",m.b))
            assert(d.Snapshot().state=="disputed" and not d.Snapshot().champion)
            assert(not Report(d,m,1,m.a,"same",m.b))
            assert(Equal(d.Snapshot(),assert(B.OpenSimulated(s,h,d.Save())).Snapshot()))
            d=assert(B.NewSimulated(s,h,cp,now,h));Finish(d);assert(d.Snapshot().champion)
            assert(Report(d,m,1,m.b,m.id..":1",m.a))
            assert(d.Snapshot().state=="disputed" and not d.Snapshot().champion)
        end)
        Case(client.." deciding fifth game and no extra game after series victory",function()
            local s,h,cp,now=Fixture(4,4,5)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            for g=1,5 do
                local winner=g%2==1 and m.a or m.b
                local token="game:"..g
                assert(Report(d,m,g,winner,token,m.a));assert(Report(d,m,g,winner,token,m.b))
                local view=d.Snapshot().rounds[1][1]
                if g<5 then assert(view.state=="ready" and not view.winner)
                else assert(view.state=="done" and view.winner==m.a and view.wins[1]==3 and view.wins[2]==2) end
            end
            assert(not Report(d,m,6,m.a,"extra",m.a))
            assert(Equal(d.Snapshot(),assert(B.OpenSimulated(s,h,d.Save())).Snapshot()))
        end)
        Case(client.." byes evenly distributed and nonchecked entrants excluded",function()
            local s,h,cp,now=Fixture(16,12,1)
            for i=10,12 do cp.roster[i].checkedIn=false end
            local d=assert(B.NewSimulated(s,h,cp,now,h));local v=d.Snapshot()
            local real,byes=0,0
            for _,m in ipairs(v.rounds[1]) do
                if m.state=="ready" then real=real+1 else assert(m.bye and m.winner);byes=byes+1 end
            end
            assert(real==1 and byes==7)
            for _,g in ipairs(v.slots) do
                if g then assert(g~=cp.roster[10].guid and g~=cp.roster[11].guid and g~=cp.roster[12].guid) end
            end
            assert(Finish(d)==8)
        end)
        Case(client.." offline series forfeit refuses early or stale evidence and replays",function()
            local s,h,cp,now=Fixture(4,4,5)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            local q={kind="offline",event=cp.ad.id,match=m.id,revision=0,loser=m.b,since=now,at=now+299}
            assert(not d.ForfeitOffline(q))
            q.at=now+300;q.revision=1;assert(not d.ForfeitOffline(q))
            q.revision=0;assert(d.ForfeitOffline(q))
            local v=d.Snapshot().rounds[1][1]
            assert(v.winner==m.a and v.forfeit.reason=="offline" and v.wins[1]==0 and next(v.games)==nil)
            assert(not d.ForfeitOffline(q))
            assert(Equal(d.Snapshot(),assert(B.OpenSimulated(s,h,d.Save())).Snapshot()))
        end)
        Case(client.." voluntary withdrawal cannot be submitted by organizer",function()
            local s,h,cp,now=Fixture(4,4,3)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            local q={event=cp.ad.id,match=m.id}
            assert(not d.Withdraw(h,q));assert(d.Withdraw(m.b,q))
            local ok,why=d.Withdraw(m.b,q);assert(ok and why=="duplicate")
            local v=d.Snapshot().rounds[1][1]
            assert(v.winner==m.a and v.forfeit.reason=="withdrawn" and v.wins[1]==0)
            assert(not Report(d,m,1,m.a,"late",m.a))
            assert(Equal(d.Snapshot(),assert(B.OpenSimulated(s,h,d.Save())).Snapshot()))
        end)
        Case(client.." replay restores pending series and rejects corrupted records",function()
            local s,h,cp,now=Fixture(8,6,5)
            local d=assert(B.NewSimulated(s,h,cp,now,h));local m=Ready(d)
            assert(Report(d,m,1,m.a,"pending",m.a))
            local saved=d.Save();local reopened=assert(B.OpenSimulated(s,h,saved))
            assert(Equal(d.Snapshot(),reopened.Snapshot()))
            assert(Report(reopened,m,1,m.a,"pending",m.b))
            local bad=Copy(saved);bad.reports[1].sender=h;assert(not B.OpenSimulated(s,h,bad))
            bad=Copy(saved);bad.reports[2]=Copy(bad.reports[1]);assert(not B.OpenSimulated(s,h,bad))
            bad=Copy(saved);bad.checkpoint.roster[1].level=0;assert(not B.OpenSimulated(s,h,bad))
            saved.reports[1].winner=h;assert(Equal(d.Snapshot(),assert(B.OpenSimulated(s,h,d.Save())).Snapshot()))
            Finish(reopened);assert(reopened.Snapshot().champion)
        end)
    end
    return p,f
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament brackets / isolated competition QA","deep",function()
        local log={};local p,f=B.RunSelfTest(function(line)log[#log+1]=line end)
        return p==20 and f==0 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
    end)
end

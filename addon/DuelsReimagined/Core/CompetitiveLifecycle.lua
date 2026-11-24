local _,ns=...
-- Integration QA only. Uses the existing subsystem owners with private
-- clocks, detector sandboxes, transport queues and in-memory saved roots.
local P={}
ns.CompetitiveLifecycle=P
function P.GetSnapshot() return {scope="LOCAL",state="disabled",rankEligible=false} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    local epoch=1000
    for _,client in ipairs({"forever","retail"}) do
        local function Fixture()
            local now=100
            local sep=client=="forever" and " " or "-"
            local names={"Alpha"..sep.."Home","Beta"..sep.."Other"}
            local ids={a,b}
            local f={peers={},discovery={},agreement={},queue={}}
            for i=1,2 do
                local j=3-i
                local x=ns.DuelDetection.NewSandbox(client,false)
                x.people.player={fullName=names[i],guid=ids[i]}
                x.people.target={fullName=names[j],guid=ids[j]}
                local peer={box=x,writes=0}
                function peer.open()
                    local d=ns.CompetitiveStorage.NewSimulated(function()return peer.account,peer.character end,
                        function(aa,cc)peer.account=aa;peer.character=cc;peer.writes=peer.writes+1 end,
                        function()return client end,function()return ids[i] end)
                    d.MarkLoaded();return d
                end
                f.peers[i]=peer
                f.discovery[i]=assert(ns.OpponentDiscovery.NewSimulated({scope="SIMULATED",kind=client,
                    now=function()return now end,home=function()return "Home" end,noncePrefix="peer-"..i,
                    identity=function(unit)return x.people[unit]end,available=function()return true end,
                    send=function(body,target)
                        assert(target==names[j]);f.queue[#f.queue+1]={to=j,from=i,body=body};return true
                    end,after=function()end}))
            end
            function f.discover()
                assert(f.discovery[1].Probe("target") and f.discovery[2].Probe("target"))
                local i=1
                while i<=#f.queue do
                    assert(i<=4,"unexpected discovery loop")
                    local q=f.queue[i];f.discovery[q.to].Receive(q.body,names[q.from]);i=i+1
                end
                assert(#f.queue==4)
                for k=1,2 do assert(f.discovery[k].GetSnapshot().state=="compatible") end
                f.queue={}
            end
            function f.challenge()
                f.peers[1].box.Outgoing("target")
                f.peers[2].box.Fire("DUEL_REQUESTED",names[1])
                for k=1,2 do assert(f.peers[k].box.detector.GetSnapshot().state=="challenge") end
            end
            function f.agree(dropFinal,badBuild)
                local descriptor=assert(ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch))
                for k=1,2 do
                    local i=k;local j=3-i
                    local d=f.discovery[i].GetSnapshot()
                    local s=f.peers[i].box.detector.GetSnapshot()
                    local remote=badBuild and descriptor.."x" or descriptor
                    if not ns.CompetitiveIntegrity.CompareSeasonSimulated(client,epoch,remote).compatible then return false end
                    f.agreement[i]=ns.PeerAgreement.NewSimulated(client,"peer-"..i,function()return now end,
                        function()return true end,function(body,target)
                            assert(target==d.opponent.key)
                            f.queue[#f.queue+1]={to=j,from=i,body=body};return true
                        end)
                    f.peers[i].discovery={state=d.state,protocol=d.protocol,guid=d.opponent.guid,key=d.opponent.key,expiresAt=d.expiresAt}
                    f.peers[i].challenge={state=s.state,me=ids[i],peer=s.challenge.opponent.guid,
                        direction=s.challenge.direction,kind=s.challenge.kind}
                end
                assert(f.agreement[2].Begin(f.peers[2].challenge,f.peers[2].discovery,true))
                assert(f.agreement[1].Begin(f.peers[1].challenge,f.peers[1].discovery,true))
                local i=1
                while i<=#f.queue do
                    assert(i<=3,"unexpected agreement loop")
                    local q=f.queue[i]
                    if not(dropFinal and i==3) then
                        f.agreement[q.to].Receive(q.body,f.peers[q.to].discovery.key)
                    end
                    i=i+1
                end
                assert(#f.queue==3);f.queue={}
                return true
            end
            function f.countdown()
                for i=1,2 do
                    local x=f.peers[i].box
                    x.Fire("CHAT_MSG_SYSTEM","Duel starting: 3")
                    local s=x.detector.GetSnapshot();assert(s.active)
                    if f.agreement[i] then f.agreement[i].Freeze(s.active.opponent.guid,true) end
                end
            end
            function f.finish(mode)
                for i=1,2 do
                    local peer=f.peers[i];local x=peer.box
                    x.Advance(4)
                    local winner=mode=="conflict" and names[i] or names[1]
                    local loser=winner==names[1] and names[2] or names[1]
                    local msg=mode=="retreat" and (loser.." has fled from "..winner.." in a duel") or (winner.." has defeated "..loser.." in a duel")
                    if i==1 then x.Fire("DUEL_FINISHED");x.Fire("CHAT_MSG_SYSTEM",msg)
                    else x.Fire("CHAT_MSG_SYSTEM",msg);x.Fire("DUEL_FINISHED") end
                    peer.result=assert(x.detector.GetSnapshot().last)
                    peer.candidate=f.agreement[i] and f.agreement[i].Snapshot() or nil
                    assert(peer.open().UpdateRecords(true,function(_,h,run)return h.Observe(run,peer.result,peer.candidate)end))
                end
            end
            function f.settle(dropSecond)
                local p,q=f.peers[1],f.peers[2]
                if not p.candidate or not p.candidate.candidate then return "unranked" end
                local collector=ns.ResultConfirmation.NewSimulated(client,p.candidate.session,a,b)
                for i=1,2 do
                    local peer=f.peers[i]
                    local statement=ns.ResultConfirmation.MakeSimulatedStatement({scope="SIMULATED",client=client,
                        me=ids[i],peer=ids[3-i],cycle=peer.result.id,agreement=peer.candidate},peer.result)
                    if statement and not(dropSecond and i==2) then assert(collector.Receive(statement,ids[i])) end
                end
                collector.Close();local snapshot=collector.Snapshot()
                if snapshot.record then
                    for i=1,2 do assert(f.peers[i].open().UpdateSeasonEvidence(epoch,snapshot.record,epoch+10,epoch+11)) end
                end
                return snapshot.state,snapshot.record
            end
            function f.stats(i) return assert(f.peers[i].open().ReadRecords()).history end
            function f.archive(i) return f.peers[i].open().ReadSeasonArchive(epoch+11) end
            return f
        end
        Case(client.." full lifecycle and peer replay convergence",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish()
            assert(f.stats(1).categories.pending.total==1 and not f.archive(1))
            local state,record=f.settle();assert(state=="matched" and record.winner==a and not record.rankEligible)
            for i=1,2 do
                local s=assert(f.archive(i));assert(s.players[a].rating==1100 and s.players[b].rating==909 and s.matched==1 and not s.rankEligible)
                assert(f.stats(i).overall.total==1 and f.stats(i).categories.matched.total==1)
                assert(s.players[a].rank.provisional and s.changes[1].gain==100)
            end
            -- Season-aware fixture wire binds evidence to the balanced policy and calendar.
            local part=f.peers[1].account.clients[client]
            local source=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch,{version=1,scope="SIMULATED",client=client,
                rule=ns.CompetitiveRules.ID,ledger=part.ledger,clocks=part.season.clocks}))
            local target=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            local req=ns.SyncProtocol.NewRequester(client,target,"integration")
            local res=ns.SyncProtocol.NewResponder(client,source)
            local request=assert(req.Begin(a,1,0));assert(request:match('^Q|2|'));assert(res.Begin(request,b,b,0))
            local t=0
            while true do
                local body,peer=res.Next(t);if not body then break end
                assert(peer==b and #body+3<=240 and body:match('^R|2|'));assert(req.Receive(body,a,t));t=t+0.5;assert(t<120)
            end
            local remote=assert(target.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+11}))
            assert(remote.matched==1 and remote.players[a].rating==1100 and remote.players[b].rating==909 and remote.completeness=="unknown")
            local writes=f.peers[1].writes
            local ok,why=f.peers[1].open().UpdateSeasonEvidence(epoch,record,epoch+10,epoch+11)
            assert(ok and why=="unchanged" and f.peers[1].writes==writes)
            local past=assert(f.peers[1].open().ReadSeasonArchive(epoch+ns.SeasonRules.DURATION))
            assert(past.history[1].players[a].rating==1100 and #past.standings==0)
        end)
        Case(client.." absent addon keeps personal stats only",function()
            local f=Fixture();f.challenge();f.countdown();f.finish();assert(f.settle()=="unranked")
            assert(f.stats(1).categories.unranked.wins==1 and f.stats(2).categories.unranked.losses==1 and not f.archive(1))
        end)
        Case(client.." missing final agreement cannot settle",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree(true));f.countdown();f.finish()
            assert(f.settle()=="unconfirmed" and f.stats(1).categories.pending.total==1 and f.stats(2).categories.unranked.total==1 and not f.archive(1))
        end)
        Case(client.." incompatible build leaves duel unranked",function()
            local f=Fixture();f.discover();f.challenge();assert(not f.agree(false,true));f.countdown();f.finish()
            assert(f.settle()=="unranked" and f.stats(1).categories.unranked.wins==1 and not f.archive(1))
        end)
        Case(client.." retreat remains personal only",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish("retreat")
            assert(f.settle()=="unconfirmed" and f.stats(1).overall.theyFled==1 and f.stats(2).overall.fled==1 and not f.archive(1))
        end)
        Case(client.." conflicting or missing outcome cannot alter ratings",function()
            local f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish("conflict")
            assert(f.settle()=="disputed" and f.stats(1).overall.wins==1 and f.stats(2).overall.wins==1 and not f.archive(1))
            f=Fixture();f.discover();f.challenge();assert(f.agree());f.countdown();f.finish()
            assert(f.settle(true)=="unconfirmed" and f.stats(1).categories.pending.total==1 and not f.archive(1))
        end)
    end
    Case("integration remains simulation only",function()
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible)
    end)
    return passed,failed
end

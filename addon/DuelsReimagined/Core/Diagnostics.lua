local _,ns=...
-- Shared diagnostic provider engine. Read-only scans; exports are explicit.
local D={}
ns.Diagnostics=D
local providers,ids,incidents,last={},{},{},nil
local running=false
local pendingAudit
local preparedAudit
local lastHealthyComplete
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function SafeText(v,limit)
    v=Plain(v)
    if type(v)~="string" then return "unavailable" end
    return v:gsub("[%z\1-\8\11\12\14-\31]",""):sub(1,limit or 1200)
end
local function Clock()
    if type(debugprofilestop)=="function" then
        local ok,v=pcall(debugprofilestop)
        if ok and type(Plain(v))=="number" then return v end
    end
    return nil
end
local function Stamp()
    return type(date)=="function" and date("%Y-%m-%d %H:%M:%S") or "session"
end
local function Copy(t)
    if type(t)~="table" then return t end
    local out={}
    for k,v in pairs(t) do out[k]=Copy(v) end
    return out
end
function D.Register(id,profile,fn)
    if type(id)~="string" or ids[id] or type(fn)~="function" or
        (profile~="health" and profile~="deep") then return false end
    ids[id]=true
    providers[#providers+1]={id=id,profile=profile,run=fn}
    return true
end
local function Assert(v,why) if not v then error(why,2) end end
local function Check(id,profile,fn) D.Register(id,profile,fn) end
function D.Record(kind,message)
    kind=SafeText(kind,60); message=SafeText(message,1800)
    for _,item in ipairs(incidents) do
        if item.kind==kind and item.message==message then
            item.count=item.count+1; item.latest=Stamp(); return
        end
    end
    incidents[#incidents+1]={kind=kind,message=message,count=1,latest=Stamp()}
    if #incidents>32 then table.remove(incidents,1) end
end
function D.GetIncidents() return Copy(incidents) end
function D.ClearIncidents() incidents={} end
-- Observe attributable protected actions here; opt-in native capture is
-- owned by DiagnosticAudit and preserves the previous error handler.
local driver=CreateFrame("Frame")
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN","LUA_WARNING"}) do
    pcall(driver.RegisterEvent,driver,event)
end
driver:SetScript("OnEvent",function(_,event,a,b)
    local name=Plain(a)
    if type(name)~="string" then return end
    if event=="LUA_WARNING" then
        if name:lower():find("duelsreimagined",1,true) then D.Record(event,name) end
    elseif name=="DuelsReimagined" then D.Record(event,SafeText(b)) end
end)
local function ImportErrors()
    local bg,why,reader=ns.DiagnosticAudit.BugGrabberAPI()
    if not bg then
        return "SKIP",why=="incompatible" and "BugGrabber public reader incompatible." or
            "BugGrabber not loaded; native capture is optional."
    end
    local ok,items=pcall(reader,bg)
    if not ok or type(Plain(items))~="table" then return "SKIP","BugGrabber history unavailable." end
    local found,older=0,0
    local session
    if type(bg.GetSessionId)=="function" then
        local good,value=pcall(bg.GetSessionId,bg)
        if good then session=Plain(value) end
    end
    for _,e in pairs(items) do
        if type(Plain(e))=="table" then
            local m,stack=SafeText(e.message,1800),SafeText(e.stack,3000)
            if (m.." "..stack):lower():find("duelsreimagined",1,true) then
                if type(session)=="number" and Plain(e.session)~=session then
                    older=older+1
                else
                found=found+1
                -- Do not inflate counts by reimporting the same cached error.
                local msg=m.."\n"..stack:sub(1,1200)
                msg=msg:sub(1,1800)
                local seen=false
                for _,item in ipairs(incidents) do
                    if item.kind=="BugGrabber" and item.message==msg then seen=true;break end
                end
                if not seen then D.Record("BugGrabber",msg) end
                end
            end
        end
    end
    local paused=false
    if type(bg.IsPaused)=="function" then
        local good,value=pcall(bg.IsPaused,bg);paused=good and Plain(value)==true
    end
    return (found>0 or paused) and "WARN" or "PASS",
        tostring(found).." attributable current-session cached error(s); "..older..
        " older error(s) excluded. "..(paused and "Collector paused. " or "")..
        "Database read only; not proof of no uncaught errors."
end
Check("Client and API profile","health",function()
    local k=ns.Client.Kind()
    Assert(k=="forever" or k=="retail","unsupported client")
    return "PASS",k
end)
Check("Module ownership / load order","health",function()
    for _,key in ipairs({"Client","Settings","Group","DuelDetection","DuelSelfTest",
        "Communication","Presence","OpponentDiscovery","PeerAgreement","ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","RatingEngine","LeaderboardSync","SyncProtocol","CompetitiveIntegrity","SeasonRules","CompetitiveLifecycle","Style","Motion","Widgets","Window","Search",
        "Header","Navigation","Options","AddonStatus","AccessIcons","BlizzardLanding"}) do
        Assert(type(ns[key])=="table",key.." missing")
    end
    return "PASS","Shared core/UI owners loaded."
end)
Check("Detector capability and state","health",function()
    local d=ns.DuelDetection.GetSnapshot()
    Assert(d.scope=="LOCAL","live scope invalid")
    Assert(not d.last or d.last.rankEligible==false,"ranking unexpectedly enabled")
    Assert(#d.trace<=24,"trace bound exceeded")
    local flags={}
    for _,k in ipairs({"request","finish","system","world","death","outgoing","countdown","knockout","retreat"}) do
        flags[#flags+1]=k.."="..tostring(d.capabilities[k]==true)
    end
    return d.state=="unavailable" and "WARN" or "PASS",
        d.state.." / "..d.reason.."; "..table.concat(flags,", ")
end)
Check("Group roster snapshot","health",function()
    local g=ns.Group.GetSnapshot()
    Assert(type(g.members)=="table" and type(g.revision)=="number","invalid roster")
    Assert(#g.members<=40,"roster exceeds raid limit")
    return g.complete and "PASS" or "SKIP",g.mode.."; members="..#g.members.."; complete="..tostring(g.complete)
end)
Check("Addon presence snapshot","health",function()
    local p=ns.Presence.GetSnapshot()
    local counts={}
    for _,m in ipairs(p.members) do
        local status=m.status
        Assert(status=="confirmed" or status=="checking" or status=="unknown" or
            status=="self" or status=="offline","unknown presence status")
        counts[status]=(counts[status] or 0)+1
    end
    return p.transport=="ready" and "PASS" or "SKIP",
        "Transport="..tostring(p.transport).."; confirmed="..(counts.confirmed or 0)..
        "; unknown="..(counts.unknown or 0).."; no messages sent."
end)
Check("Opponent discovery / eligibility gate","health",function()
    local p=ns.OpponentDiscovery.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.rankEligible==false,"discovery must not enable ranking")
    return "PASS",p.state.." / "..p.reason.."; live peer delivery not verified."
end)
Check("Peer agreement / live gate","health",function()
    local p=ns.PeerAgreement.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"agreement live gate unexpectedly enabled")
    return "PASS","Simulation only; no live agreement, no rating writes."
end)
Check("Result confirmation / live gate","health",function()
    local p=ns.ResultConfirmation.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"result confirmation live gate unexpectedly enabled")
    return "PASS","Simulation only; no live settlement or rating writes."
end)
Check("Match ledger / live gate","health",function()
    local p=ns.MatchLedger.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"ledger live gate unexpectedly enabled")
    return "PASS","Versioned simulated storage only; no live SavedVariables or rating writes."
end)
Check("Personal history / live gate","health",function()
    local p=ns.PersonalHistory.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"history live gate unexpectedly enabled")
    return "PASS","Simulation only; no live history or statistics writes."
end)
Check("Competitive storage / lifecycle gate","health",function()
    local p=ns.CompetitiveStorage.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.rankEligible==false,"storage must not enable ranking")
    if p.state~="ready" then
        return p.reason=="identity_unavailable" and "SKIP" or "FAIL","Storage unavailable: "..tostring(p.reason).."; data preserved."
    end
    return "PASS","Read-only schema v"..p.version..(p.prepared and " prepared" or " preparation pending").."; account probe="..p.accountProbe.."; character probe="..p.characterProbe.."; match writes disabled."
end)
Check("Rating engine / live gate","health",function()
    local p=ns.RatingEngine.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"rating live gate unexpectedly enabled")
    return "PASS","Experimental "..p.rule.."; no live rating or rank writes."
end)
Check("Competitive rules / live gate","health",function()
    local p=ns.CompetitiveRules.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"competitive rules live gate unexpectedly enabled")
    return "PASS","Experimental "..p.rule.."; no live eligibility or rating changes."
end)
Check("Leaderboard sync / live gate","health",function()
    local p=ns.LeaderboardSync.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"sync live gate unexpectedly enabled")
    return "PASS","Logical simulation pages v"..p.version.."; no live sync or rating writes."
end)
Check("Sync protocol / live gate","health",function()
    local p=ns.SyncProtocol.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"sync protocol live gate unexpectedly enabled")
    return "PASS","Simulation wire v"..p.version.."; no live network or rating writes."
end)
Check("Competitive integrity / live gate","health",function()
    local p=ns.CompetitiveIntegrity.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false and p.originVerified==false and p.build,"integrity compatibility gate unavailable")
    return "PASS","Advertised build "..p.build:sub(1,12).."; no live compatibility enforcement or file attestation."
end)
Check("Season rules / live gate","health",function()
    local p=ns.SeasonRules.GetSnapshot()
    Assert(p.scope=="LOCAL" and p.state=="disabled" and p.rankEligible==false,"season live gate unexpectedly enabled")
    return "PASS","Experimental "..p.rule.."; no live calendar, rankings or archive writes."
end)
Check("Settings / defaults / bounds","health",function()
    local S=ns.Settings
    Assert(S.GetDefault("autoPeekMoving")==true,"Peek default changed")
    for _,key in ipairs({"autoPeekMoving","reduceMotion","showTooltips","showGameMenuButton","showInCompartment"}) do
        Assert(type(S.Get(key))=="boolean",key.." invalid")
    end
    local mode=S.Get("iconMode")
    Assert(mode=="minimap" or mode=="widget" or mode=="both" or mode=="none","invalid icon mode")
    for _,v in ipairs({{"minimapSize",24,64},{"widgetSize",24,128},{"minimapTransparency",0,.9},
        {"widgetTransparency",0,.9},{"menuScale",S.MIN_SCALE,S.MAX_SCALE},
        {"fontScale",S.MIN_FONT_SCALE,S.MAX_FONT_SCALE}}) do
        local n=S.Get(v[1]);Assert(type(n)=="number" and n>=v[2] and n<=v[3],v[1].." outside bounds")
    end
    Assert(#S.GetWarGamesArenaFavorites()<=32,"favorites bound")
    return "PASS","Validated current normalized settings; no preferences changed."
end)
Check("War Games client gate and setup","health",function()
    if not ns.Client.IsRetail() then
        Assert(ns.WarGames==nil,"Retail module loaded on Forever")
        return "SKIP","Retail-only by design."
    end
    local W=ns.WarGames;Assert(W,"War Games missing")
    local maps=W.GetMaps();Assert(#maps>0,"no arena list")
    for _,key in ipairs({"player","host"}) do
        local cfg=W.GetConfig(key)
        Assert(cfg and maps[cfg.map],"invalid arena selection")
        Assert(cfg.bracket==2 or cfg.bracket==3 or cfg.bracket==5,"invalid bracket")
        Assert(type(cfg.tournamentRules)=="boolean","invalid rules toggle")
    end
    Assert(ns.WarGamesArenaPicker and type(ns.WarGamesArenaPicker.Open)=="function","picker absent")
    return "PASS",#maps.." reference maps; both setup pages valid. Availability not verified."
end)
Check("Launcher / icon runtime","health",function()
    local a=ns.AccessIcons.GetRuntimeState()
    Assert(a.animationOwner=="UI/Motion.lua","unexpected animation owner")
    Assert(a.minimapSize==ns.Settings.Get("minimapSize"),"minimap size mismatch")
    Assert(a.widgetSize==ns.Settings.Get("widgetSize"),"widget size mismatch")
    return "PASS","Mode="..a.mode.."; minimap="..a.minimapSize.."; widget="..a.widgetSize
end)
Check("Opponent discovery / isolated protocol QA","deep",function()
    local log={}
    local p,f=ns.OpponentDiscovery.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==13 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Peer agreement / isolated protocol QA","deep",function()
    local log={}
    local p,f=ns.PeerAgreement.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==21 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Result confirmation / isolated record QA","deep",function()
    local log={}
    local p,f=ns.ResultConfirmation.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==21 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Match ledger / isolated storage QA","deep",function()
    local log={}
    local p,f=ns.MatchLedger.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==25 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Personal history / isolated statistics QA","deep",function()
    local log={}
    local p,f=ns.PersonalHistory.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==25 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive storage / isolated lifecycle QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveStorage.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==21 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive storage / isolated record roundtrip QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveStorage.RunRecordSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==15 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Rating engine / isolated replay QA","deep",function()
    local log={}
    local p,f=ns.RatingEngine.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==25 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive rules / isolated anti-farming QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveRules.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==19 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated peer convergence QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==25 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Sync protocol / isolated packet QA","deep",function()
    local log={}
    local p,f=ns.SyncProtocol.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==23 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive integrity / isolated compatibility QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveIntegrity.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==13 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Season rules / isolated season QA","deep",function()
    local log={}
    local p,f=ns.SeasonRules.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==23 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Season rules / isolated rating balance QA","deep",function()
    local log={}
    local p,f=ns.SeasonRules.RunBalanceSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==14 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive storage / isolated seasonal archive QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveStorage.RunArchiveSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==15 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Competitive lifecycle / integrated simulation QA","deep",function()
    local log={}
    local p,f=ns.CompetitiveLifecycle.RunSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==13 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Sync protocol / isolated seasonal compatibility QA","deep",function()
    local log={}
    local p,f=ns.SyncProtocol.RunSeasonSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==13 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated page export QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunPageSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==7 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated atomic batch merge QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunMergeSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==7 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Sync protocol / isolated expanded capacity QA","deep",function()
    local log={}
    local p,f=ns.SyncProtocol.RunCapacitySelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==5 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated delta comparison QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunDeltaSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==9 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Sync protocol / isolated delta packet QA","deep",function()
    local log={}
    local p,f=ns.SyncProtocol.RunDeltaWireSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==9 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated incremental comparison QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunDeltaCacheSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==7 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Leaderboard sync / isolated cooperative preparation QA","deep",function()
    local log={}
    local p,f=ns.LeaderboardSync.RunPreparationSelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==7 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Sync protocol / isolated recovery session QA","deep",function()
    local log={}
    local p,f=ns.SyncProtocol.RunRecoverySelfTest(function(line) log[#log+1]=line end)
    return f==0 and p==9 and "PASS" or "FAIL",
        string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
end)
Check("Search registry","deep",function()
    local S=ns.Search
    local seen={}
    for _,id in ipairs(S.order) do
        Assert(not seen[id] and S.entries[id] and type(S.entries[id].activate)=="function","invalid search entry")
        seen[id]=true
    end
    Assert(#S.Query("diagnostics")>0,"diagnostics missing from search")
    return "PASS",#S.order.." unique registered actions."
end)
Check("Snapshot copy / identity isolation","deep",function()
    local d=ns.DuelDetection.GetSnapshot()
    local rev=d.revision;d.revision=-1;d.trace[1]=nil
    Assert(ns.DuelDetection.GetSnapshot().revision==rev,"live snapshot mutable")
    local g=ns.Group.GetSnapshot();local n=g.revision;g.revision=-1
    Assert(ns.Group.GetSnapshot().revision==n,"roster snapshot mutable")
    return "PASS","Independent snapshots; no live mutations."
end)
Check("Incident history / Lua error integration","health",function()
    return ImportErrors()
end)
Check("Native Lua error capture","health",function()
    return ns.DiagnosticAudit.ErrorCoverage()
end)
Check("Owned UI geometry and texture sources","deep",function()
    return ns.DiagnosticAudit.UIAudit()
end)
Check("Addon memory and CPU metrics","deep",function()
    return ns.DiagnosticAudit.Performance()
end)
local function Fingerprint()
    local d=ns.DuelDetection.GetSnapshot()
    local g=ns.Group.GetSnapshot()
    local parts={d.scope,d.state,tostring(d.revision),tostring(g.revision)}
    for _,k in ipairs({"autoPeekMoving","reduceMotion","iconMode","minimapSize","widgetSize","menuScale","fontScale"}) do
        parts[#parts+1]=tostring(ns.Settings.Get(k))
    end
    return table.concat(parts,"|")
end
function D.GetLast() return Copy(last) end
function D.IsRunning() return running or pendingAudit~=nil end
local function Add(result,id,status,detail,ms)
    result.rows[#result.rows+1]={id=id,status=status,detail=SafeText(detail,16000),ms=ms}
    result.counts[status]=(result.counts[status] or 0)+1
end
function D.Run(mode)
    if D.IsRunning() then return nil,"Already running" end
    running=true
    local r={mode=mode=="complete" and "complete" or "health",stamp=Stamp(),rows={},counts={}}
    local start=Clock()
    local function Scan(profile,prefix)
        for _,p in ipairs(providers) do
            if p.profile==profile then
                local t=Clock()
                local ok,status,detail
                if p.id=="Owned UI geometry and texture sources" and preparedAudit then
                    ok,status,detail=true,preparedAudit.status,preparedAudit.detail
                else ok,status,detail=pcall(p.run) end
                if not ok then detail=SafeText(status);status="FAIL";D.Record("Check "..p.id,detail) end
                if status~="PASS" and status~="WARN" and status~="SKIP" and status~="FAIL" then
                    status="FAIL";detail="Invalid provider return"
                end
                local done=Clock()
                local ms=t and done and done-t or nil
                if p.id=="Owned UI geometry and texture sources" and preparedAudit then ms=preparedAudit.ms end
                Add(r,prefix..p.id,status,detail,ms)
            end
        end
    end
    local ok,err=pcall(function()
        Scan("health","Health / ")
        if r.mode=="complete" then
            Scan("deep","Deep Health / ")
            local before=Fingerprint()
            local motionBefore=ns.Motion.GetRuntimeState()
            local resourcesBefore,coveredBefore=ns.DiagnosticAudit.Resources()
            local log={}
            local t=Clock()
            local passed,failed=ns.DuelSelfTest.Run(function(line)
                log[#log+1]=SafeText(line,500)
            end,true)
            local done=Clock()
            Add(r,"Developer QA / isolated duel suite",failed==0 and "PASS" or "FAIL",
                string.format("%d passed / %d failed (SIMULATED)\n",passed,failed)..table.concat(log,"\n"),
                t and done and done-t or nil)
            local same=Fingerprint()==before
            Add(r,"Isolation / live state fingerprint",same and "PASS" or "FAIL",
                same and "Live detector, roster revisions and selected settings unchanged." or "Live state changed.")
            local motionAfter=ns.Motion.GetRuntimeState()
            local unchanged=motionBefore.active==motionAfter.active and motionBefore.driver==motionAfter.driver
            Add(r,"Leak Sentinel / shared animation probe",unchanged and "PASS" or "FAIL",
                "Active tweens before="..motionBefore.active.."; after="..motionAfter.active..
                ". QA is synchronous and must not start live animations.")
            local resourcesAfter,coveredAfter=ns.DiagnosticAudit.Resources()
            local unchangedResources,changes=ns.DiagnosticAudit.CompareResources(resourcesBefore,resourcesAfter)
            Add(r,"Leak Sentinel / owned frame, region, timer and subscriber counts",
                not unchangedResources and "FAIL" or (coveredBefore and coveredAfter and "PASS" or "SKIP"),
                ns.DiagnosticAudit.ResourceText(resourcesAfter)..(unchangedResources and
                    "\nTracked counts unchanged during QA." or "\nChanged:\n"..changes))
            Add(r,"Leak Sentinel / remaining resource coverage","SKIP",
                "Anonymous frames outside known roots, uninstrumented UI timers and repeated real interactions are not certified.")
            Scan("health","Final Health / ")
            Add(r,"Static package / Lua syntax","SKIP","Source file syntax and TOC validation are CI-only; not readable from WoW Lua.")
            Add(r,"Live gameplay / multiplayer","SKIP","Requires real players. Simulated results never prove Blizzard event delivery.")
        end
        local d=ns.DuelDetection.GetSnapshot()
        r.trace={}
        for _,entry in ipairs(d.trace) do
            r.trace[#r.trace+1]=string.format("%.2f %s / %s",entry.time or 0,entry.state,entry.reason)
        end
        r.incidents=D.GetIncidents()
        if #r.incidents>0 then Add(r,"Incident ledger","WARN",#r.incidents.." distinct incident(s); review advanced report.") end
    end)
    if not ok then Add(r,"Diagnostics coordinator","FAIL",SafeText(err));D.Record("Coordinator",SafeText(err)) end
    local done=Clock()
    r.ms=start and done and done-start or nil
    if preparedAudit and r.ms then r.ms=r.ms+preparedAudit.ms end
    r.batched=preparedAudit~=nil
    preparedAudit=nil
    r.status=r.counts.FAIL and "FAIL" or r.counts.WARN and "WARN" or "PASS"
    r.previous=last and last.status or "none"
    if r.mode=="complete" and ns.DiagnosticAudit then
        local ok,status,detail=pcall(function()
            local baseline=ns.Settings.GetDiagnosticBaseline(ns.Client.Kind()) or lastHealthyComplete
            return ns.DiagnosticAudit.CompareBaseline(r,baseline)
        end)
        Add(r,"Regression Intelligence / baseline",ok and status or "FAIL",ok and detail or SafeText(status))
        r.status=r.counts.FAIL and "FAIL" or r.counts.WARN and "WARN" or "PASS"
        if r.status=="PASS" then lastHealthyComplete=Copy(r) end
    end
    if ns.DiagnosticAudit then r.release=ns.DiagnosticAudit.ReleaseGate(r) end
    last=r
    running=false
    if ns.DiagnosticAudit then ns.DiagnosticAudit.MarkScanEnd() end
    return Copy(r)
end
function D.CancelPending()
    pendingAudit=nil
end
function D.RunAsync(mode,callback,progress)
    if D.IsRunning() then return false,"Already running" end
    if mode~="complete" or not C_Timer or type(C_Timer.After)~="function" then
        local r,err=D.Run(mode);callback(r,err);return true
    end
    local job={step=ns.DiagnosticAudit.BeginUIAudit(),ms=0}
    pendingAudit=job
    local function Next()
        if pendingAudit~=job then return end
        local start=Clock()
        local ok,done,status,detail=pcall(job.step)
        local finish=Clock()
        if start and finish then job.ms=job.ms+finish-start end
        if not ok then done,status,detail=true,"FAIL",SafeText(done) end
        if done then
            pendingAudit=nil
            preparedAudit={status=status,detail=detail,ms=job.ms}
            local r,err=D.Run(mode)
            preparedAudit=nil
            callback(r,err)
        else
            C_Timer.After(0,Next)
        end
    end
    if progress then progress("Scanning UI in small batches...") end
    C_Timer.After(0,Next)
    return true
end
function D.BuildReport(result,advanced)
    if not result then return "No report yet. Click Run Full Scan to check the addon." end
    local r=result
    local lines={"Duels Reimagined Diagnostics | "..r.stamp,
        "Runtime "..r.mode.." | "..r.status.." | "..ns.Client.Kind(),
        string.format("PASS %d | WARN %d | FAIL %d | SKIP %d",r.counts.PASS or 0,
            r.counts.WARN or 0,r.counts.FAIL or 0,r.counts.SKIP or 0),
        "Previous scan: "..r.previous,
        "Release Gate: "..(r.release or "Not evaluated"),
        "Learning receipt: "..r.mode.." scan, "..#r.rows.." checks; previous status "..r.previous..".",
        "Changes under test: native capture, resource counts, UI audit, baseline comparison, performance and release gate.",
        "Evidence: each row below names its check; skipped checks remain unverified.",
        "No automated repair; live records and preferences are not modified by scans.",
        r.ms and string.format("Measured work: %.2f ms (%s)",r.ms,r.batched and "batched UI plus atomic QA; excludes wait" or "synchronous checks") or "Timing unavailable",
        "Runtime evidence only; not a source-code or multiplayer certification.",""}
    for _,row in ipairs(r.rows) do
        lines[#lines+1]=row.status.." | "..row.id..(row.ms and string.format(" (%.2f ms)",row.ms) or "")
        if advanced or row.status=="FAIL" or row.status=="WARN" or row.status=="SKIP" then lines[#lines+1]=row.detail end
    end
    if advanced then
        lines[#lines+1]="\nLOCAL DUEL TRANSITIONS (no player names)"
        for _,v in ipairs(r.trace or {}) do lines[#lines+1]=v end
        lines[#lines+1]="\nINCIDENTS (may include error paths; review before sharing)"
        for _,v in ipairs(r.incidents or {}) do
            lines[#lines+1]=v.kind.." x"..v.count.." | "..v.latest.."\n"..v.message
        end
    end
    local report=table.concat(lines,"\n")
    return #report>98304 and report:sub(1,98260).."\n[Report truncated at storage limit]" or report
end

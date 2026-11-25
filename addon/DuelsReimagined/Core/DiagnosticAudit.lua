local _,ns=...
local A={}
ns.DiagnosticAudit=A
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Plain(v) end
end
local function Number(v)
    return type(v)=="number" and v==v and v>=0 and v<math.huge and v or nil
end
local function Text(v)
    v=Plain(v);return type(v)=="string" and v or ""
end

-- Opt-in session capture. Forward to the prior handler, never suppress errors
-- or replace another addon's subsequently installed handler.
local capture
-- BugGrabber 12.1.1 exposes GetDB, GetSessionId and IsPaused.
-- The presence of its global alone is not evidence that the API is readable.
function A.BugGrabberAPI()
    local bg=Plain(_G.BugGrabber)
    if type(bg)~="table" then return nil,"absent" end
    local ok,reader=pcall(function() return bg.GetDB or bg.GetErrors end)
    if not ok or type(reader)~="function" then return nil,"incompatible" end
    return bg,"available",reader
end
function A.CaptureState()
    local bg,why=A.BugGrabberAPI()
    if bg then return "external" end
    if why=="incompatible" then return "external_unknown" end
    if not capture or not capture.enabled then return "off" end
    return Call(geterrorhandler)==capture.wrapper and "active" or "replaced"
end
function A.StopCapture()
    if not capture then return true end
    local old=capture
    old.enabled=false
    if Call(geterrorhandler)==old.wrapper then
        if not pcall(seterrorhandler,old.previous) then return false end
    end
    capture=nil
    return true
end
function A.StartCapture()
    local bg,why=A.BugGrabberAPI()
    if bg or why=="incompatible" then return false,"External error collector detected; leaving its handler untouched." end
    if A.CaptureState()=="active" then return true,"Capture already active." end
    if capture then A.StopCapture() end
    local previous=Call(geterrorhandler)
    if type(previous)~="function" or type(seterrorhandler)~="function" then
        return false,"Client error-handler API unavailable."
    end
    local state={previous=previous,enabled=true,busy=false}
    state.wrapper=function(msg)
        if state.busy then return end
        state.busy=true
        local _,external=A.BugGrabberAPI()
        if state.enabled and external=="absent" then
            pcall(function()
                local m=Text(msg)
                if m:lower():gsub("\\","/"):find("duelsreimagined/",1,true) then
                    local stack=Text(Call(debugstack,2,12,4))
                    ns.Diagnostics.Record("Native Lua error",m:sub(1,1000).."\n"..stack:sub(1,750))
                end
            end)
        end
        local ok,result=pcall(state.previous,msg)
        state.busy=false
        if ok then return result end
        -- An error handler must not recursively invoke itself.
        if type(print)=="function" then print("Duels Reimagined: previous Lua error handler failed.") end
    end
    local ok=pcall(seterrorhandler,state.wrapper)
    if not ok or Call(geterrorhandler)~=state.wrapper then
        state.enabled=false
        return false,"Client refused the error handler."
    end
    capture=state
    return true,"Native capture active for this session."
end
function A.ErrorCoverage()
    local state=A.CaptureState()
    if state=="active" then return "PASS","Native handler active; forwards existing handler. Only path-attributable errors captured." end
    if state=="external" then return "SKIP","BugGrabber public reader available; its capture ownership is preserved." end
    if state=="external_unknown" then return "SKIP","BugGrabber global exists but its API is incompatible; handler ownership left untouched." end
    if state=="replaced" then return "WARN","Another addon replaced the native handler." end
    return "SKIP","Native capture is off. Start Capture to record later Lua errors."
end

local roots={"DuelsReimaginedWindow","DuelsReimaginedDiagnosticsWindow",
    "DuelsReimaginedBlizzardSettingsPanel","DuelsReimaginedMinimapButton","DuelsReimaginedAccessWidget","DuelsReimaginedArenaPicker","DuelsReimaginedPlayerCard"}
-- Retail includes War Games; previous 20k ceiling truncated the audit.
local LIMIT=32000
local pageRoots={}
function A.RegisterUIRoot(label,frame)
    if type(label)=="string" and frame then pageRoots[frame]=label end
end
local function Inspect(check,slice)
    local processed=0
    local function Budget()
        if not slice then return end
        processed=processed+1
        if processed>=150 then processed=0;coroutine.yield() end
    end
    local r={frames=0,regions=0,visible=0,textureSources=0,unknownTextures=0,
        problems={},missingRoots=0,limited=false,unreadable=0,pages={}}
    local seen={}
    local function Issue(label,msg)
        if #r.problems<30 then r.problems[#r.problems+1]=label..": "..msg end
    end
    local function Walk(f,label,isRoot,page)
        if not f or seen[f] then return end
        Budget()
        page=pageRoots[f] or page or label
        if not r.pages[page] then r.pages[page]={frames=0,regions=0,textures=0,fonts=0} end
        local bucket=r.pages[page]
        if r.frames+r.regions>=LIMIT then r.limited=true;return end
        seen[f]=true;r.frames=r.frames+1;bucket.frames=bucket.frames+1
        local visible=Call(f.IsVisible,f)==true
        if visible then
            r.visible=r.visible+1
            if check then
                local width,height=Number(Call(f.GetWidth,f)),Number(Call(f.GetHeight,f))
                if not width or not height then r.unreadable=r.unreadable+1
                else
                    local kind=Call(f.GetObjectType,f)
                    local control=isRoot or kind=="Button" or kind=="EditBox"
                    if control and (width==0 or height==0) then Issue(label,"visible root/control has zero dimension") end
                    if control and Call(f.GetNumPoints,f)==0 then Issue(label,"visible root/control has no anchor") end
                end
            end
        end
        -- Count-only snapshots avoid allocating/inspecting thousands of regions.
        local count=not check and Number(Call(f.GetNumRegions,f))
        if count then
            r.regions=r.regions+count;bucket.regions=bucket.regions+count
            if r.frames+r.regions>=LIMIT then r.limited=true end
        elseif type(f.GetRegions)=="function" then
            local ok,regions=pcall(function()return {f:GetRegions()} end)
            if ok then
                for _,region in ipairs(regions) do
                    if r.frames+r.regions>=LIMIT then r.limited=true;break end
                    if not seen[region] then
                        Budget()
                        seen[region]=true;r.regions=r.regions+1;bucket.regions=bucket.regions+1
                        local objectType=check and Call(region.GetObjectType,region)
                        if objectType=="Texture" then bucket.textures=bucket.textures+1
                        elseif objectType=="FontString" then bucket.fonts=bucket.fonts+1 end
                        if objectType=="Texture" and Call(region.IsVisible,region)==true then
                            local texture,atlas=Call(region.GetTexture,region),Call(region.GetAtlas,region)
                            if texture~=nil or atlas~=nil then r.textureSources=r.textureSources+1
                            else r.unknownTextures=r.unknownTextures+1 end
                            if type(atlas)=="string" and #atlas>0 and C_Texture and C_Texture.GetAtlasInfo then
                                local ok,info=pcall(C_Texture.GetAtlasInfo,atlas)
                                if ok and Plain(info)==nil then Issue(label,"unresolved atlas "..atlas) end
                            end
                        end
                    end
                end
            else r.unreadable=r.unreadable+1 end
        end
        if type(f.GetChildren)=="function" and not r.limited then
            local ok,children=pcall(function()return {f:GetChildren()} end)
            if ok then
                for i,child in ipairs(children) do Walk(child,label.."/"..i,false,page);if r.limited then break end end
            else r.unreadable=r.unreadable+1 end
        end
    end
    -- Attribute nested roots to the nearest registered page, never double count.
    for _,name in ipairs(roots) do
        local root=_G[name]
        if root then Walk(root,name,true)
        elseif name~="DuelsReimaginedArenaPicker" or ns.Client.IsRetail() then r.missingRoots=r.missingRoots+1 end
    end
    return r
end
local function FormatAudit(r)
    local pages={}
    for name,v in pairs(r.pages) do pages[#pages+1]={name=name,v=v} end
    table.sort(pages,function(x,y)
        if x.v.regions==y.v.regions then return x.name<y.name end
        return x.v.regions>y.v.regions
    end)
    local breakdown={"\nOwned page breakdown (non-overlapping; hidden included):"}
    for _,entry in ipairs(pages) do
        local v=entry.v
        breakdown[#breakdown+1]=string.format("%s: %d frames, %d regions, %d textures, %d font strings",
            entry.name,v.frames,v.regions,v.textures,v.fonts)
    end
    local detail=string.format("%d frames, %d regions, %d visible frames, %d texture sources, %d unclassified textures, %d unreadable, %d roots absent.",
        r.frames,r.regions,r.visible,r.textureSources,r.unknownTextures,r.unreadable,r.missingRoots)
    detail=detail..table.concat(breakdown,"\n")
    if r.limited then detail=detail.."\nObject limit reached ("..LIMIT.."); coverage incomplete." end
    if #r.problems>0 then return "WARN",detail.."\n"..table.concat(r.problems,"\n") end
    if r.limited or r.unreadable>0 or r.frames==0 or r.missingRoots>0 then
        return "SKIP",detail.." Partial traversal; visual/pixel validation not performed."
    end
    return "PASS",detail.." Visible root/control geometry and readable atlas references checked; texture presence does not prove image loading."
end
function A.UIAudit()
    return FormatAudit(Inspect(true))
end
-- Yield only outside protected calls. Each slice processes at most 150
-- objects; scheduler exists only for an explicitly requested scan.
function A.BeginUIAudit()
    local co=coroutine.create(function() return FormatAudit(Inspect(true,true)) end)
    return function()
        local ok,status,detail=coroutine.resume(co)
        if not ok then return true,"FAIL",Text(status) end
        if coroutine.status(co)=="dead" then return true,status,detail end
        return false
    end
end
function A.Resources()
    local r=Inspect(false)
    local out={frames=r.frames,regions=r.regions}
    local complete=not r.limited and r.unreadable==0 and r.missingRoots==0
    for _,name in ipairs({"DuelDetection","Group","Presence","Communication","OpponentDiscovery","PeerAgreement","ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","RatingEngine","LeaderboardSync","SyncProtocol","CompetitiveIntegrity","SeasonRules","CompetitiveLifecycle","WarGames","DuelHUD","Notifications","DuelCountdown","EditMode","CountdownAudio","DuelResult","TournamentSession"}) do
        local owner=ns[name]
        if owner and owner.GetDiagnosticResources then
            for k,n in pairs(owner.GetDiagnosticResources()) do out[name.."."..k]=n end
        elseif name~="WarGames" or ns.Client.IsRetail() then complete=false end
    end
    return out,complete
end
function A.CompareResources(before,after)
    local changes,keys={},{}
    for k in pairs(before) do keys[k]=true end
    for k in pairs(after) do keys[k]=true end
    for k in pairs(keys) do
        if before[k]~=after[k] then changes[#changes+1]=k..": "..tostring(before[k]).." -> "..tostring(after[k]) end
    end
    table.sort(changes)
    return #changes==0,table.concat(changes,"\n")
end
function A.ResourceText(values)
    local lines={}
    for k,v in pairs(values) do lines[#lines+1]=k.."="..tostring(v) end
    table.sort(lines)
    return table.concat(lines,", ")
end
local memorySamples={}
local lastScanEnd
function A.MarkScanEnd() lastScanEnd=Number(Call(GetTime)) end
function A.SampleMemory()
    local now=Number(Call(GetTime))
    local prior=memorySamples[#memorySamples]
    if not now then return false,"Session clock unavailable." end
    if ns.Diagnostics.IsRunning() then return false,"Finish diagnostics first." end
    if lastScanEnd and now-lastScanEnd<5 then return false,"Wait at least 5 seconds after a scan to sample memory." end
    if prior and now-prior.time<15 then return false,"Wait 15 seconds between manual memory samples." end
    if type(UpdateAddOnMemoryUsage)~="function" then return false,"Memory refresh API unavailable." end
    local start=Number(Call(debugprofilestop))
    local ok=pcall(UpdateAddOnMemoryUsage)
    local kb=ok and Number(Call(GetAddOnMemoryUsage,"DuelsReimagined"))
    local finish=Number(Call(debugprofilestop))
    if not kb then return false,"Client memory measurement unavailable." end
    memorySamples[#memorySamples+1]={time=now,kb=kb,ms=start and finish and finish-start or nil}
    if #memorySamples>8 then table.remove(memorySamples,1) end
    return true,"Memory sample captured. Compare repeated quiet samples; not proof of a leak."
end
function A.MemoryText()
    local last=memorySamples[#memorySamples]
    if not last then return "Memory: not manually sampled this session. Use Sample Memory." end
    local first=memorySamples[1]
    local now=Number(Call(GetTime))
    local lines={string.format("Memory: %.1f KiB (manual cached sample, age %s)",last.kb,
        now and string.format("%.0f s",math.max(0,now-last.time)) or "unknown"),
        string.format("Quiet-sample history: %d/8; delta from oldest: %+.1f KiB",#memorySamples,last.kb-first.kb)}
    for i,v in ipairs(memorySamples) do
        lines[#lines+1]=string.format("Sample %d: %.1f KiB%s",i,v.kb,
            v.ms and string.format(" (refresh %.2f ms)",v.ms) or "")
    end
    lines[#lines+1]="Samples are spaced and taken outside scans; GC and game activity can change memory. No leak verdict."
    return table.concat(lines,"\n")
end
function A.Performance()
    local lines={}
    -- The native memory refresh is expensive and cannot be time-sliced.
    -- Never invoke it in the periodic monitor or Complete Check.
    local metrics=Enum and Enum.AddOnProfilerMetric
    local fn=C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric
    local recent
    for _,key in ipairs({"SessionAverageTime","RecentAverageTime","EncounterAverageTime","LastTime","PeakTime"}) do
        local id=metrics and metrics[key]
        local v=id~=nil and Number(Call(fn,"DuelsReimagined",id))
        if v then
            lines[#lines+1]=string.format("%s: %.4f ms",key,v)
            if key=="RecentAverageTime" then recent=v end
        end
    end
    local fps=Number(Call(GetFramerate))
    if recent and fps and fps>0 then
        lines[#lines+1]=string.format("Recent CPU: %.2f%% of current frame-time budget (estimate)",recent*fps/10)
    end
    local available=#lines>0
    lines[#lines+1]=A.MemoryText()
    return available and "PASS" or "SKIP",table.concat(lines,"\n")..
        "\nClient-reported CPU sample; memory is refreshed manually only. No profiler reset or performance threshold certification."
end
function A.CompareBaseline(current,baseline)
    if not baseline then return "SKIP","No matching complete baseline. Save a healthy Complete Check first." end
    local old,new={},{}
    for _,r in ipairs(baseline.rows) do if r.id~="Regression Intelligence / baseline" then old[r.id]=r.status end end
    for _,r in ipairs(current.rows) do if r.id~="Regression Intelligence / baseline" then new[r.id]=r.status end end
    local lines,regressions={},0
    for id,status in pairs(old) do
        local n=new[id]
        if n~=status then
            lines[#lines+1]=id..": "..status.." -> "..(n or "NOT RUN")
            if status=="PASS" and n~="PASS" then regressions=regressions+1 end
        end
    end
    for id,status in pairs(new) do if not old[id] then lines[#lines+1]="NEW "..id..": "..status end end
    table.sort(lines)
    return regressions>0 and "WARN" or "PASS",
        "Compared with "..baseline.stamp.."; "..regressions.." previous PASS checks no longer pass. "..(#lines==0 and "No status changes." or "\n"..table.concat(lines,"\n"))
end
function A.ReleaseGate(r)
    local c=r and r.counts or {}
    if (c.FAIL or 0)>0 or (c.WARN or 0)>0 then return "BLOCKED: runtime warnings/failures require review." end
    if not r or r.mode~="complete" then return "NOT READY: run Complete Check." end
    return "DEVELOPMENT CHECKS PASS; RELEASE BLOCKED: CI, full visual/resource coverage and real Retail/Forever multiplayer evidence require separate verification."
end

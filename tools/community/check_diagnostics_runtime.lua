-- Mock diagnostic provider/report contracts; not a live UI test.
local function Check(ok,why) if not ok then error(why,2) end end
local ns={Client={Kind=function() return "forever" end,IsRetail=function() return false end}}
local driver
CreateFrame=function()
    driver={events={},scripts={}}
    function driver:RegisterEvent(event) self.events[event]=true end
    function driver:SetScript(key,fn) self.scripts[key]=fn end
    return driver
end
local t=0
debugprofilestop=function() t=t+1;return t end
issecretvalue=function()return false end
local original=_G.DuelsReimaginedDB
_G.DuelsReimaginedDB={autoPeekMoving=false,unrelated="keep"}
assert(loadfile("addon/DuelsReimagined/Core/Settings.lua"))("DuelsReimagined",ns)
local S=ns.Settings
Check(#S.GetDiagnosticReports()==0,"empty export history")
for i=1,4 do Check(S.SaveDiagnosticReport("test"..i,"report"..i),"save report") end
local reports=S.GetDiagnosticReports()
Check(#reports==3 and reports[1].text=="report4" and reports[3].text=="report2","bounded recent reports")
reports[1].text="changed"
Check(S.GetDiagnosticReports()[1].text=="report4","copy isolation")
Check(not S.SaveDiagnosticReport("test",string.rep("a",98305)),"oversize rejected")
local baseline={stamp="fixture",mode="complete",rows={{id="first",status="PASS"},{id="pending",status="SKIP"}}}
Check(S.SaveDiagnosticBaseline("forever",baseline),"save healthy baseline")
Check(not S.GetDiagnosticBaseline("retail"),"client baseline isolation")
baseline.rows[1].status="FAIL"
Check(not S.SaveDiagnosticBaseline("forever",baseline),"reject failing baseline")
Check(S.GetDiagnosticBaseline("forever").rows[1].status=="PASS","preserve healthy baseline")
S.ClearDiagnosticReports()
Check(#S.GetDiagnosticReports()==0 and _G.DuelsReimaginedDB.unrelated=="keep","clear only reports")
Check(S.GetDiagnosticBaseline("forever")~=nil,"clearing reports preserves baseline")
_G.DuelsReimaginedDB=original

assert(loadfile("addon/DuelsReimagined/Core/Diagnostics.lua"))("DuelsReimagined",ns)
local D=ns.Diagnostics
assert(loadfile("addon/DuelsReimagined/Core/DiagnosticAudit.lua"))("DuelsReimagined",ns)
local A=ns.DiagnosticAudit
local calls=0
Check(D.Register("fixture","health",function()calls=calls+1;return "PASS","fixture" end),"provider registration")
Check(not D.Register("fixture","health",function()end),"duplicate provider rejected")
D.Register("broken fixture","health",function()error("expected failure")end)
driver.scripts.OnEvent(driver,"ADDON_ACTION_BLOCKED","OtherAddon","ignored")
Check(#D.GetIncidents()==0,"other addon incident ignored")
driver.scripts.OnEvent(driver,"ADDON_ACTION_BLOCKED","DuelsReimagined","fixture")
driver.scripts.OnEvent(driver,"ADDON_ACTION_BLOCKED","DuelsReimagined","fixture")
Check(D.GetIncidents()[1].count==2,"incident deduplication")
local result=D.Run("health")
Check(result.status=="FAIL" and calls==1 and not D.IsRunning(),"isolated provider failure and runner cleanup")
local report=D.BuildReport(result,true)
Check(report:find("broken fixture",1,true) and report:find("expected failure",1,true),"report includes failure evidence")
local again=D.Run("health")
Check(again.previous=="FAIL" and calls==2,"repeat / previous summary")
result.status="changed"
Check(D.GetLast().status=="FAIL","last result copy")
D.ClearIncidents()
Check(#D.GetIncidents()==0,"session ledger clear")
-- Explicit capture forwards both unrelated and attributable errors; restore
-- only our own handler. Fixtures never install a real WoW error handler.
local oldGet,oldSet,oldBG=geterrorhandler,seterrorhandler,_G.BugGrabber
local forwarded=0
local originalHandler=function() forwarded=forwarded+1 end
local current=originalHandler
geterrorhandler=function() return current end
seterrorhandler=function(fn) current=fn end
_G.BugGrabber=nil
Check(A.StartCapture() and A.CaptureState()=="active","native capture starts")
current("Interface/AddOns/OtherAddon/Core.lua:1: fixture")
Check(#D.GetIncidents()==0 and forwarded==1,"unrelated error forwarded only")
current("Interface/AddOns/DuelsReimagined/Core.lua:1: fixture")
Check(#D.GetIncidents()==1 and forwarded==2,"attributable error captured and forwarded")
Check(A.StopCapture() and current==originalHandler,"restore original handler")
Check(A.StartCapture(),"restart capture")
local other=function() end
current=other
Check(A.CaptureState()=="replaced" and A.StopCapture() and current==other,"never replace newer handler")
_G.BugGrabber={}
Check(not A.StartCapture(),"defer to BugGrabber")
geterrorhandler,seterrorhandler,_G.BugGrabber=oldGet,oldSet,oldBG
-- Actual BugGrabber v12.1.1 API: GetDB, GetSessionId, IsPaused.
local oldBG2=_G.BugGrabber
local cache={
    {message="Interface/AddOns/DuelsReimagined/Core.lua:1: old",session=1,counter=1},
    {message="Interface/AddOns/DuelsReimagined/Core.lua:2: current",session=2,counter=1},
    {message="Interface/AddOns/Other/Core.lua:1: unrelated",session=2,counter=1},
}
_G.BugGrabber=setmetatable({}, {__index={
    GetDB=function()return cache end,
    GetSessionId=function()return 2 end,
    IsPaused=function()return false end,
}})
Check(A.CaptureState()=="external","GetDB collector recognized")
local bg,why,reader=A.BugGrabberAPI()
Check(bg and why=="available" and reader(bg)==cache,"read actual public database")
D.ClearIncidents()
D.Run("health")
local imported=0
for _,item in ipairs(D.GetIncidents()) do
    if item.kind=="BugGrabber" then
        imported=imported+1
        Check(item.message:find("current",1,true),"only current-session attributable errors")
    end
end
Check(imported==1 and #cache==3,"collector import is read only")
_G.BugGrabber={}
Check(A.CaptureState()=="external_unknown","incompatible global explicitly marked")
Check(not A.StartCapture(),"unknown external handler preserved")
_G.BugGrabber=oldBG2

-- No expensive refresh from normal sampling; manual history is bounded.
local oldTime,oldRefresh,oldMemory=GetTime,UpdateAddOnMemoryUsage,GetAddOnMemoryUsage
local now,refreshes=100,0
GetTime=function()return now end
UpdateAddOnMemoryUsage=function()refreshes=refreshes+1 end
GetAddOnMemoryUsage=function()return 5000+refreshes end
A.Performance();A.Performance()
Check(refreshes==0,"periodic CPU never refreshes memory")
A.MarkScanEnd()
Check(not A.SampleMemory(),"reject immediate post-scan sample")
now=106
Check(A.SampleMemory() and refreshes==1,"manual refresh")
Check(not A.SampleMemory() and refreshes==1,"manual refresh throttled")
now=122
Check(A.SampleMemory() and refreshes==2,"second spaced sample")
Check(A.MemoryText():find("+1.0 KiB",1,true),"memory comparison")
A.Performance()
Check(refreshes==2,"report uses cached memory")
GetTime,UpdateAddOnMemoryUsage,GetAddOnMemoryUsage=oldTime,oldRefresh,oldMemory

-- Batched walk and page buckets with mock frame tree. No real UI mutation.
local oldRoot=_G.DuelsReimaginedWindow
local function Node(regions,children,kind)
    return {GetRegions=function()return unpack(regions or {})end,
        GetNumRegions=function()return #(regions or {})end,
        GetChildren=function()return unpack(children or {})end,
        GetObjectType=function()return kind or "Frame" end,
        IsVisible=function()return false end}
end
local regions={}
for i=1,320 do regions[i]=Node(nil,nil,i%2==0 and "Texture" or "FontString") end
local page=Node(regions)
_G.DuelsReimaginedWindow=Node({}, {page})
A.RegisterUIRoot("Fixture page",page)
A.RegisterDeferredUIRoot("Deferred fixture")
local step=A.BeginUIAudit()
local done,st,report=step()
Check(not done,"audit actually yields")
local slices=1
while not done do done,st,report=step();slices=slices+1;Check(slices<20,"audit terminates") end
Check(report:find("Fixture page: 1 frames, 320 regions, 160 textures, 160 font strings",1,true),"page counts correct")
Check(report:find("Deferred views at audit start (not visually inspected): Deferred fixture",1,true),"explicit deferred coverage")
A.RegisterUIRoot("Deferred fixture",page)
local _,audit=A.UIAudit()
Check(not audit:find("Deferred views at audit start",1,true),"constructed root clears deferred status")
_G.DuelsReimaginedWindow=oldRoot

local equal,detail=A.CompareResources({frames=2,timers=1},{frames=2,timers=2})
Check(not equal and detail:find("timers",1,true),"resource difference detected")
Check(A.CompareResources({frames=2},{frames=2}),"unchanged resources")
local status=A.CompareBaseline({rows={{id="a",status="FAIL"}}},{stamp="fixture",rows={{id="a",status="PASS"}}})
Check(status=="WARN","regression surfaced")
Check(A.CompareBaseline({rows={{id="a",status="PASS"}}},{stamp="fixture",rows={{id="a",status="PASS"}}})=="PASS","matching baseline")
Check(A.CompareBaseline({rows={}},nil)=="SKIP","missing baseline is not pass")
Check(A.ReleaseGate({mode="complete",counts={PASS=1}}):find("RELEASE BLOCKED",1,true),"runtime never certifies release")
Check(A.ReleaseGate({mode="complete",counts={FAIL=1}}):find("BLOCKED",1,true),"failed runtime gate")
print("Diagnostics provider, native capture, baseline, resource and storage contracts: PASS")

-- Full scan runner: cooperate between providers/cases without changing the
-- existing protected check contract. Mock only final isolation collaborators.
ns.DuelDetection={GetSnapshot=function()return {scope="LOCAL",state="idle",revision=1,trace={}} end}
ns.Group={GetSnapshot=function()return {revision=1} end}
ns.Motion={GetRuntimeState=function()return {active=0,driver=false} end}
ns.DuelSelfTest={Run=function()return 1,0 end}
local prevAudit,prevResources=A.BeginUIAudit,A.Resources
A.BeginUIAudit=function()return function()return true,"PASS","fixture" end end
A.Resources=function()return {},true end
local queued={}
C_Timer={After=function(_,fn)queued[#queued+1]=fn end}
local steps,callbacks=0,0
D.Register("cooperative fixture","deep",function(yield)
    for i=1,4 do steps=steps+1;yield() end
    return "PASS","all four cases"
end,true)
local function Next() local fn=table.remove(queued,1);Check(fn~=nil,"scheduled slice");fn() end
Check(D.RunAsync("complete",function()callbacks=callbacks+1 end),"start async")
Check(D.IsRunning() and not D.RunAsync("complete",function()end),"reject overlap")
local limit=0
while steps<1 do Next();limit=limit+1;Check(limit<500,"fixture reached") end
Check(steps==1 and callbacks==0,"first case yields")
D.CancelPending();Check(not D.IsRunning(),"cancel releases runner")
while #queued>0 do Next() end
Check(steps==1 and callbacks==0,"cancel prevents stale callback and remaining work")
steps=0
local complete
Check(D.RunAsync("complete",function(r)complete=r;callbacks=callbacks+1 end),"restart")
limit=0
while #queued>0 do
    local before=steps;Next();Check(steps-before<=1,"one cooperative case per slice")
    limit=limit+1;Check(limit<500,"scan terminates")
end
Check(steps==4 and callbacks==1 and complete and not D.IsRunning(),"complete after restart")
local found
for _,row in ipairs(complete.rows) do if row.id=="Deep Health / cooperative fixture" then found=row end end
Check(found and found.status=="PASS" and found.ms and complete.peakSlice,"timing and evidence preserved")
A.BeginUIAudit,A.Resources=prevAudit,prevResources
print("Cooperative diagnostics: PASS (one case per slice, overlap refusal, cancellation, restart, report and timing)")

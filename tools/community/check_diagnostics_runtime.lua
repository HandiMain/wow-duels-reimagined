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

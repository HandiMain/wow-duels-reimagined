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
S.ClearDiagnosticReports()
Check(#S.GetDiagnosticReports()==0 and _G.DuelsReimaginedDB.unrelated=="keep","clear only reports")
_G.DuelsReimaginedDB=original

assert(loadfile("addon/DuelsReimagined/Core/Diagnostics.lua"))("DuelsReimagined",ns)
local D=ns.Diagnostics
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
print("Diagnostics provider and storage contracts: PASS")

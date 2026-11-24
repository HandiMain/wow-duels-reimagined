local _,ns=...
local Style,Widgets=ns.Style,ns.Widgets
local C=Style.color
local View={}
ns.DiagnosticsUI=View
local frame
local function Build()
    frame=CreateFrame("Frame","DuelsReimaginedDiagnosticsWindow",UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetSize(760,560)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Style.Skin(frame,C.nav,{corner=11,edge=C.goldDim,shine=.12,shade=.12})
    Style.Plate(frame,"shellCopper",{corner=20,layer="ARTWORK",sublevel=1})
    local title=Style.Text(frame,"DIAGNOSTICS",24,C.pale,nil,"display")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-15)
    local drag=CreateFrame("Frame",nil,frame)
    drag:SetPoint("TOPLEFT",frame,"TOPLEFT",15,-5)
    drag:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-45,-5)
    drag:SetHeight(42)
    drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() frame:StartMoving() end)
    drag:SetScript("OnDragStop",function() frame:StopMovingOrSizing() end)
    local close=ns.Header.CreateCloseButton(frame)
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-12,-12)
    close:SetScript("OnClick",function() frame:Hide() end)
    local status=Style.Text(frame,"Runtime health and Developer QA",13,C.text)
    status:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-51)
    local StopMonitor
    local function Button(label,x,y,w,plate,fn)
        local b=Style.Action(frame,label,"footer",{plate=plate or "dark",tooltip=false})
        b:SetSize(w,30);b:SetPoint("TOPLEFT",frame,"TOPLEFT",x,-y)
        b:SetScript("OnClick",function(...)
            if ns.Diagnostics.IsRunning() then status:SetText("Complete Check is running. Close to cancel.");return end
            if label~="Performance" and StopMonitor then StopMonitor() end
            fn(...)
        end);return b
    end
    local scroll=CreateFrame("ScrollFrame",nil,frame)
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-156)
    scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,84)
    scroll:EnableMouseWheel(true)
    Style.Skin(scroll,C.body,{corner=8,edge=C.border,shine=.08,shade=.08})
    local box=CreateFrame("EditBox",nil,scroll)
    box:SetMultiLine(true);box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall);box:SetTextInsets(8,8,8,8)
    box:SetWidth(685);box:SetHeight(350)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus();frame:Hide() end)
    box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    scroll:SetScrollChild(box)
    local text=""
    local updating=false
    local function Fit()
        -- Multi-line EditBox grows to its text automatically. It has no
        -- FontString:GetStringHeight API; let ScrollFrame measure its range.
        box:SetWidth(math.max(100,scroll:GetWidth()-22))
    end
    local bar=Widgets.ScrollBar(scroll,function()
        return scroll:GetHeight(),box:GetHeight(),scroll:GetVerticalScroll()
    end,function(v) scroll:SetVerticalScroll(v) end)
    local function SetText(v)
        text=v;updating=true
        box:SetText(v);box:SetCursorPosition(0);box:ClearFocus()
        Fit();scroll:SetVerticalScroll(0);bar:Refresh()
        updating=false
    end
    box:SetScript("OnTextChanged",function(self)
        if not updating and self:GetText()~=text then
            updating=true;self:SetText(text);self:ClearFocus();updating=false
        end
    end)
    scroll:SetScript("OnSizeChanged",function() Fit();bar:Refresh() end)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(box:GetHeight()-scroll:GetHeight(),
            scroll:GetVerticalScroll()-delta*48)));bar:Refresh()
    end)
    scroll:SetScript("OnVerticalScroll",function() bar:Refresh() end)
    scroll:SetScript("OnScrollRangeChanged",function() bar:Refresh() end)
    local advanced=false
    local function Render()
        local r=ns.Diagnostics.GetLast()
        status:SetText(r and ("Last run: "..r.status.."  |  "..r.mode.."  |  "..r.stamp) or "Run a health check or complete QA.")
        SetText(ns.Diagnostics.BuildReport(r,advanced))
    end
    local function Run(mode)
        local ok,err=ns.Diagnostics.RunAsync(mode,function(r,why)
            if r then Render() else status:SetText(why or "Check unavailable") end
        end,function(message) status:SetText(message) end)
        if not ok then status:SetText(err or "Check unavailable") end
    end
    Button("Run Health Check",20,78,164,"dark",function() Run("health") end)
    Button("Run Complete Check",192,78,190,"gold",function() Run("complete") end)
    local toggle
    toggle=Button("Advanced Report",390,78,160,"dark",function()
        advanced=not advanced
        toggle.label:SetText(advanced and "Summary" or "Advanced Report");Render()
    end)
    -- Separate developer tools row. No extra permanent driver.
    local monitor=false
    local ticker
    local perf
    StopMonitor=function()
        if ticker then ticker:Cancel();ticker=nil end
        monitor=false
        if perf then perf.label:SetText("Performance") end
    end
    local function Sample()
        local state,detail=ns.DiagnosticAudit.Performance()
        status:SetText("Performance | "..state)
        SetText(detail)
    end
    perf=Button("Performance",20,116,164,"dark",function()
        if monitor then StopMonitor();Render();return end
        monitor=true
        perf.label:SetText("Stop Monitor");Sample()
        if C_Timer and C_Timer.NewTicker then
            ticker=C_Timer.NewTicker(5,function()
                if frame:IsVisible() and monitor then Sample() else StopMonitor() end
            end)
        end
    end)
    Button("Error Capture",192,116,164,"dark",function()
        StopMonitor()
        local a=ns.DiagnosticAudit
        local ok,detail
        if a.CaptureState()=="active" then ok=a.StopCapture();detail=ok and "Native capture stopped." or "Handler restore failed."
        else ok,detail=a.StartCapture() end
        status:SetText(detail)
    end)
    Button("Save Baseline",364,116,174,"gold",function()
        StopMonitor()
        local r=ns.Diagnostics.GetLast()
        if not r or r.mode~="complete" or r.status~="PASS" then
            status:SetText("Run a healthy Complete Check before saving.");return
        end
        local ok=ns.Settings.SaveDiagnosticBaseline(ns.Client.Kind(),r)
        status:SetText(ok and "Healthy baseline saved for this client." or "Baseline not saved.")
    end)
    Button("Release Gate",546,116,194,"dark",function()
        StopMonitor()
        status:SetText("Release readiness")
        SetText(ns.DiagnosticAudit.ReleaseGate(ns.Diagnostics.GetLast()))
    end)
    local savedIndex=0
    local confirmClear=false
    Button("Incident Log",558,78,182,"dark",function()
        local lines={"Session incidents (addon-attributable only)"}
        for _,i in ipairs(ns.Diagnostics.GetIncidents()) do
            lines[#lines+1]=i.kind.." x"..i.count.." | "..i.latest.."\n"..i.message
        end
        if #lines==1 then lines[#lines+1]="No incidents captured; not proof of no Lua errors." end
        status:SetText("Session incident history");SetText(table.concat(lines,"\n"))
    end)
    local bottom=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    bottom:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",20,55)
    bottom:SetText("Ctrl+C copies selected text. Memory refresh is manual.")
    local sample=Button("Sample Memory",0,0,156,"dark",function()
        local ok,detail=ns.DiagnosticAudit.SampleMemory()
        status:SetText(detail)
        if ok then local _,report=ns.DiagnosticAudit.Performance();SetText(report) end
    end)
    sample:ClearAllPoints();sample:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,46)
    local function Footer(label,x,w,plate,fn)
        local b=Button(label,x,0,w,plate,fn)
        b:ClearAllPoints();b:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",x,16)
        return b
    end
    Footer("Select Report",20,126,"dark",function() box:SetFocus();box:HighlightText() end)
    Footer("Save Report",154,126,"gold",function()
        local r=ns.Diagnostics.GetLast()
        if not r then status:SetText("Run a check first.");return end
        local ok=ns.Settings.SaveDiagnosticReport(r.stamp,ns.Diagnostics.BuildReport(r,true))
        status:SetText(ok and "Saved. /reload or logout writes DuelsReimaginedDB.lua." or "Report not saved.")
    end)
    Footer("Saved Reports",288,136,"dark",function()
        local reports=ns.Settings.GetDiagnosticReports()
        if #reports==0 then status:SetText("No saved reports.");return end
        savedIndex=savedIndex%#reports+1
        status:SetText("Saved "..savedIndex.."/"..#reports.." | "..reports[savedIndex].label)
        SetText(reports[savedIndex].text)
    end)
    Footer("Latest",432,82,"dark",Render)
    local clear
    clear=Footer("Clear Saved",522,96,"dark",function()
        if not confirmClear then
            confirmClear=true;clear.label:SetText("Confirm")
            status:SetText("Click Confirm to delete only saved diagnostic reports.")
            return
        end
        ns.Settings.ClearDiagnosticReports()
        confirmClear=false;clear.label:SetText("Clear Saved");savedIndex=0
        Render();status:SetText("Saved diagnostic reports cleared.")
    end)
    Footer("Close",626,114,"hall",function() frame:Hide() end)
    frame:SetScript("OnHide",function()
        ns.Diagnostics.CancelPending()
        StopMonitor()
        confirmClear=false;clear.label:SetText("Clear Saved")
        box:ClearFocus();frame:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow",function() advanced=false;toggle.label:SetText("Advanced Report");Render() end)
    if type(UISpecialFrames)=="table" then table.insert(UISpecialFrames,"DuelsReimaginedDiagnosticsWindow") end
end
function View.Open()
    if not frame then Build() end
    local scale=math.min(1,(UIParent:GetWidth()-30)/760,(UIParent:GetHeight()-30)/560)
    frame:SetScale(math.max(.35,scale))
    frame:Show();frame:Raise()
end
ns.Search.Register("diagnostics:open","Diagnostics","Addon Status",
    "Health scan, Developer QA, incident log, Lua runtime report",View.Open)

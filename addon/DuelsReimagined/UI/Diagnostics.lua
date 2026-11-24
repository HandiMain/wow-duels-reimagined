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
    local status=Style.Text(frame,"Run a full scan, then copy the report to share with support.",13,C.text)
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
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-120)
    scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,66)
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
    -- Players get the complete technical report without choosing a mode.
    local advanced=true
    local toggle
    local toolsOpen=false
    local tools={}
    local function Tool(label,x,y,w,plate,fn)
        local b=Button(label,x,y,w,plate,fn)
        tools[#tools+1]=b
        b:Hide()
        return b
    end
    local function Render()
        if toggle then toggle.label:SetText(advanced and "Summary" or "Full Report") end
        local r=ns.Diagnostics.GetLast()
        status:SetText(r and ("Scan finished: "..r.status.."  |  "..r.stamp) or
            "Run a full scan, then copy the report to share with support.")
        SetText(r and ns.Diagnostics.BuildReport(r,advanced) or
            "No report yet. Click Run Full Scan to check the addon.")
    end
    local function Run(mode)
        local ok,err=ns.Diagnostics.RunAsync(mode,function(r,why)
            if r then Render() else status:SetText(why or "Check unavailable") end
        end,function(message) status:SetText(message) end)
        if not ok then status:SetText(err or "Check unavailable") end
    end
    Button("Run Full Scan",20,78,220,"gold",function()
        advanced=true
        SetText("Running full diagnostics. Please keep this window open.")
        Run("complete")
    end)
    local disclosure
    local function SetTools(open)
        toolsOpen=open
        for _,b in ipairs(tools) do b:SetShown(open) end
        disclosure.label:SetText(open and "Hide Developer Tools" or "Developer Tools")
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",20,open and -234 or -120)
        scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,66)
        if not open then
            advanced=true
            if toggle then toggle.label:SetText("Summary") end
        end
        Fit();bar:Refresh()
    end
    disclosure=Button("Developer Tools",546,78,194,"dark",function()
        SetTools(not toolsOpen)
        Render()
    end)
    Tool("Quick Health",20,116,174,"dark",function() Run("health") end)
    toggle=Tool("Summary",202,116,174,"dark",function()
        advanced=not advanced
        toggle.label:SetText(advanced and "Summary" or "Full Report");Render()
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
    perf=Tool("Performance",384,116,174,"dark",function()
        if monitor then StopMonitor();Render();return end
        monitor=true
        perf.label:SetText("Stop Monitor");Sample()
        if C_Timer and C_Timer.NewTicker then
            ticker=C_Timer.NewTicker(5,function()
                if frame:IsVisible() and monitor then Sample() else StopMonitor() end
            end)
        end
    end)
    Tool("Error Capture",566,116,174,"dark",function()
        StopMonitor()
        local a=ns.DiagnosticAudit
        local ok,detail
        if a.CaptureState()=="active" then ok=a.StopCapture();detail=ok and "Native capture stopped." or "Handler restore failed."
        else ok,detail=a.StartCapture() end
        status:SetText(detail)
    end)
    Tool("Save Baseline",20,154,174,"dark",function()
        StopMonitor()
        local r=ns.Diagnostics.GetLast()
        if not r or r.mode~="complete" or r.status~="PASS" then
            status:SetText("Run a healthy Complete Check before saving.");return
        end
        local ok=ns.Settings.SaveDiagnosticBaseline(ns.Client.Kind(),r)
        status:SetText(ok and "Healthy baseline saved for this client." or "Baseline not saved.")
    end)
    Tool("Release Gate",202,154,174,"dark",function()
        StopMonitor()
        status:SetText("Release readiness")
        SetText(ns.DiagnosticAudit.ReleaseGate(ns.Diagnostics.GetLast()))
    end)
    local savedIndex=0
    local confirmClear=false
    Tool("Incident Log",384,154,174,"dark",function()
        local lines={"Session incidents (addon-attributable only)"}
        for _,i in ipairs(ns.Diagnostics.GetIncidents()) do
            lines[#lines+1]=i.kind.." x"..i.count.." | "..i.latest.."\n"..i.message
        end
        if #lines==1 then lines[#lines+1]="No incidents captured; not proof of no Lua errors." end
        status:SetText("Session incident history");SetText(table.concat(lines,"\n"))
    end)
    local bottom=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    bottom:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",20,49)
    bottom:SetText("Copy Report selects the text. Press Ctrl+C, then review before sharing.")
    Tool("Sample Memory",566,154,174,"dark",function()
        local ok,detail=ns.DiagnosticAudit.SampleMemory()
        status:SetText(detail)
        if ok then local _,report=ns.DiagnosticAudit.Performance();SetText(report) end
    end)
    local function Footer(label,x,w,plate,fn)
        local b=Button(label,x,0,w,plate,fn)
        b:ClearAllPoints();b:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",x,16)
        return b
    end
    Footer("Copy Report",20,174,"dark",function()
        if not toolsOpen then
            if not ns.Diagnostics.GetLast() then status:SetText("Run Full Scan first.");return end
            advanced=true;Render()
        end
        box:SetFocus();box:HighlightText()
        status:SetText("Report selected. Press Ctrl+C to copy, then paste into your message.")
    end)
    Tool("Save Report",20,192,174,"dark",function()
        local r=ns.Diagnostics.GetLast()
        if not r then status:SetText("Run a check first.");return end
        local ok=ns.Settings.SaveDiagnosticReport(r.stamp,ns.Diagnostics.BuildReport(r,true))
        status:SetText(ok and "Saved. /reload or logout writes DuelsReimaginedDB.lua." or "Report not saved.")
    end)
    Tool("Saved Reports",202,192,174,"dark",function()
        local reports=ns.Settings.GetDiagnosticReports()
        if #reports==0 then status:SetText("No saved reports.");return end
        savedIndex=savedIndex%#reports+1
        status:SetText("Saved "..savedIndex.."/"..#reports.." | "..reports[savedIndex].label)
        SetText(reports[savedIndex].text)
    end)
    Tool("Latest",384,192,174,"dark",Render)
    local clear
    clear=Tool("Clear Saved",566,192,174,"dark",function()
        if not confirmClear then
            confirmClear=true;clear.label:SetText("Confirm")
            status:SetText("Click Confirm to delete only saved diagnostic reports.")
            return
        end
        ns.Settings.ClearDiagnosticReports()
        confirmClear=false;clear.label:SetText("Clear Saved");savedIndex=0
        Render();status:SetText("Saved diagnostic reports cleared.")
    end)
    -- Closing is always available, including while a batched scan is running.
    local closeFooter=Footer("Close",626,114,"hall",function() frame:Hide() end)
    closeFooter:SetScript("OnClick",function() frame:Hide() end)
    frame:SetScript("OnHide",function()
        ns.Diagnostics.CancelPending()
        StopMonitor()
        confirmClear=false;clear.label:SetText("Clear Saved")
        box:ClearFocus();frame:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow",function()
        advanced=true
        SetTools(false)
        Render()
    end)
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

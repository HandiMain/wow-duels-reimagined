local _,ns=...
-- Presentation only. The existing TournamentState draft store and registration
-- preview retain exclusive ownership of validation, dates and publication.
local H={};ns.TournamentHost=H
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local T=ns.TournamentState
local chrome=ns.TournamentBrowse.Chrome
local function PlainText(v,empty)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return empty end
    end
    if type(v)~="string" or not v:match("%S") then return empty end
    -- A preview is not a rich-text renderer. Never interpret typed escapes.
    return (v:gsub("|","||"):gsub("[%c]"," "))
end
function H.Project(form,times)
    local f=form or {}
    local lo=PlainText(f.minLevel,"Any")
    local hi=PlainText(f.maxLevel,"Any")
    return {
        name=PlainText(f.name,"Tournament name not entered"),
        location=PlainText(f.location,"Location not entered"),
        format="1v1 · Single elimination",
        capacity=f.capacity and tostring(f.capacity).." players" or "Not selected",
        series=f.bestOf and "Best of "..f.bestOf or "Not selected",
        levels=lo=="Any" and hi=="Any" and "Any level" or "Level "..lo.." – "..hi,
        rules=PlainText(f.rules,"None specified"),
        starts=times and times.starts or "Select date & time",
        closes=times and times.closes or "Not scheduled",
    }
end
-- Fixed content density; resizing distributes space or stacks whole panels.
function H.Geometry(width)
    local base,wide,scale=chrome.LayoutWidth(width,1170)
    local top=wide and 78 or 132
    local bodyH=420
    local available=base-24
    local a=wide and math.floor(available*.332) or base
    local b=wide and math.floor(available*.372) or base
    local c=wide and available-a-b or base
    local x2,y2=wide and a+12 or 0,wide and top or top+bodyH+12
    local x3,y3=wide and a+b+24 or 0,wide and top or y2+bodyH+12
    local footerY=y3+bodyH+12
    local footerH=wide and 72 or 100
    return {wide=wide,base=base,scale=scale,top=top,bodyH=bodyH,a=a,b=b,c=c,
        x2=x2,y2=y2,x3=x3,y3=y3,footerY=footerY,footerH=footerH,total=footerY+footerH}
end
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,size,color,align)
    local f=S.Text(p,"",size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(true);return f
end
local function Text(f,p,x,y,w,h,value,min)
    At(f,p,x,y,w,h)
    if min and S.ConstrainText then S.ConstrainText(f,w,h,min) end
    f:SetText(value or "")
end
local function Section(parent,title,icon,bright)
    local p=chrome.Panel(parent,bright)
    p.heading=Label(p,24,C.pale)
    p.heading:SetText(title)
    p.icon=chrome.Art(p,icon)
    p.line=S.Fill(p,C.goldDim,"BORDER");p.line:SetAlpha(.55)
    return p
end
local function Header(p,w)
    At(p.icon,p,13,9,31,30);At(p.heading,p,53,5,w-65,42)
    if S.ConstrainText then S.ConstrainText(p.heading,w-65,42,18) end
    At(p.line,p,13,48,w-26,1)
end
local choiceOptions={fontSize=18,feedback={hoverAlpha=.55,downAlpha=.82,downHover=.88,clickAlpha=.86,corner=9}}
function H.New(parent,callbacks)
    local f=CreateFrame("Frame",nil,parent);f:Hide()
    local community=chrome.NewCommunity(f)
    local details=Section(f,"Host Tournament","flag",false)
    local rules=Section(f,"Format & Rules","swords",false)
    local summary=Section(f,"Tournament Summary","logo",true)
    local footer=chrome.Panel(f,false)
    local defaults=T.DraftDefaults()
    local controls,choices={},{}
    local selectedUTC=defaults.startUTC or ""
    local displayedKey,scope,geometry
    local feedback=Label(footer,16,C.pale)
    local footerIcon=chrome.Art(footer,7)
    local status="Local test only – no online publishing."
    local refreshSummary
    local function ReadForm()
        local form={}
        for key,control in pairs(controls) do
            if control.calendar then form[key]=selectedUTC
            elseif control.choice then form[key]=choices[key]
            else form[key]=control.box:GetText() end
        end
        return form
    end
    local function PaintStatus()
        if geometry then
            local g=geometry
            local message=status=="Local test only – no online publishing." and status or
                "Local test only – no online publishing.\n"..status
            Text(feedback,footer,45,7,g.wide and g.base-540 or g.base-60,g.wide and 58 or 46,message,13)
        end
    end
    local function SetStatus(value)
        status=value;PaintStatus()
    end
    local function Dirty()
        SetStatus("Unsaved changes. Drafts stay in this session only.")
        if refreshSummary then refreshSummary() end
    end
    local function Field(p,key,caption,limit,help,icon)
        local label=Label(p,17,C.pale);label:SetText(caption)
        -- Like the shared header search: paint the housing on a parent,
        -- then initialize the native input font before registering it for
        -- subsequent theme changes. Host is created after the first theme pass.
        local housing=CreateFrame("Frame",nil,p)
        S.Skin(housing,C.body,{corner=8,edge=C.border,shine=.16,shade=.20})
        local box=CreateFrame("EditBox",nil,housing)
        box:SetAllPoints(housing)
        box:SetAutoFocus(false);box:SetMultiLine(false);box:SetMaxLetters(limit)
        local fontPath,fontSize,flags=label:GetFont()
        local scale=ns.Settings and ns.Settings.Get("fontScale") or 1
        if not box:SetFont(fontPath or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18*scale,flags or "") then
            box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18*scale,"")
        end
        box:SetTextColor(unpack(C.text));box:SetJustifyH("LEFT")
        box:SetTextInsets(9,9,0,0);S.BindFont(box,18,false,C.text)
        box:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
        box:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
        box:SetScript("OnHide",function(self)self:ClearFocus()end)
        box:SetScript("OnTextChanged",function(_,userInput)if userInput then Dirty() end end)
        box:SetText(defaults[key] or "")
        controls[key]={label=label,box=box,housing=housing,parent=p,icon=icon and chrome.Art(p,icon)}
        ns.Tooltips.Bind(box,{title=caption,detail=help})
        return box
    end
    local function Choice(p,key,caption,options,icon)
        local label=Label(p,17,C.pale);label:SetText(caption)
        local box,value=W.ChoiceControl(p,226,choiceOptions)
        local selected=defaults[key]
        local function Select(k)
            selected=k;choices[key]=k
            for _,o in ipairs(options) do if o.key==k then value:SetText(o.label);break end end
        end
        Select(selected)
        box:SetScript("OnClick",function()
            W.OpenChoices(box,options,selected,function(k)Select(k);Dirty()end)
        end)
        controls[key]={label=label,box=box,parent=p,choice=true,icon=icon and chrome.Art(p,icon)}
    end
    local function ClearFocus()
        for _,control in pairs(controls) do
            if not control.choice and not control.calendar then control.box:ClearFocus() end
        end
    end
    Field(details,"name","Tournament name",60,"Name shown to participants. Plain text only; no links.","flag")
    Field(details,"location","World duel location",100,"Describe the meeting place. No automatic teleport or arena.","location")
    local startLabel=Label(details,17,C.pale);startLabel:SetText("Start date & time (local)")
    local startButton,startText=W.ChoiceControl(details,226,choiceOptions)
    startText:SetText("Select date & time")
    controls.startUTC={label=startLabel,box=startButton,parent=details,calendar=true,icon=chrome.Art(details,1)}
    startButton:SetScript("OnClick",function()
        ClearFocus()
        if not W.OpenCalendar(startButton,T,selectedUTC,choices.closeBefore,function(utc)selectedUTC=utc;Dirty()end) then
            SetStatus("Your local calendar is unavailable. Try again later.")
        end
    end)
    ns.Tooltips.Bind(startButton,{title="Start date & time",detail="Choose the start in your local time. Registration deadline updates automatically."})
    Choice(details,"closeBefore","Registration closes",{
        {key=0,label="At start"},{key=15,label="15 min before"},{key=30,label="30 min before"},{key=60,label="60 min before"}},2)
    local format=Label(rules,18,C.text)
    Choice(rules,"capacity","Maximum players",{{key=4,label="4 players"},{key=8,label="8 players"},
        {key=16,label="16 players"},{key=32,label="32 players"}},"players")
    Choice(rules,"bestOf","Match series",{{key=1,label="Best of 1"},{key=3,label="Best of 3"},{key=5,label="Best of 5"}},"swords")
    Field(rules,"minLevel","Min. level (optional)",3,"Leave blank for no minimum. Eligibility checks come with registration.")
    Field(rules,"maxLevel","Max. level (optional)",3,"Leave blank for no maximum. Eligibility checks come with registration.")
    Field(rules,"rules","Additional rules (optional)",160,"Plain text rules for the organizer to enforce; not automatically detected.",6)
    local ruleHint=Label(rules,15,C.muted)
    local scheduleHint=Label(details,15,C.muted)
    local backdrop=chrome.Art(summary,"landscape","ARTWORK")
    backdrop:SetAlpha(.24)
    local summaryRows={}
    local summaryKeys={"name","location","format","capacity","series","levels","starts","closes","rules"}
    local icons={"logo","location","swords","players","swords",5,1,2,6}
    for i,key in ipairs(summaryKeys) do
        summaryRows[i]={key=key,icon=chrome.Art(summary,icons[i]),label=Label(summary,i==1 and 21 or 18,i==1 and C.pale or C.text)}
    end
    local divider=S.Fill(summary,C.goldDim,"BORDER");divider:SetAlpha(.45)
    refreshSummary=function()
        if not geometry then return end
        local form=ReadForm()
        local times=T.GetSchedulePreview(selectedUTC,choices.closeBefore)
        startText:SetText(times and times.starts or "Select date & time")
        local m=H.Project(form,times)
        local w=geometry.c
        backdrop:SetShown(form.location=="Elwynn Forest" and scope and scope.faction=="Alliance")
        for i,row in ipairs(summaryRows) do
            local y=57+(i-1)*36+(i>=7 and 7 or 0)
            local height=i==9 and 45 or 34
            local value=m[row.key]
            if row.key=="starts" then value="Starts: "..value
            elseif row.key=="closes" then value="Registration: "..value
            elseif row.key=="rules" then value="Rules: "..value end
            Text(row.label,summary,50,y,w-63,height,value,i==1 and 15 or 13)
            At(row.icon,summary,15,y+5,25,24)
        end
        Text(scheduleHint,details,15,365,geometry.a-30,42,times and
            "Registration ends "..times.closes.." (local)" or "Choose a start time to preview your schedule.",13)
    end
    local testStart=chrome.Action(footer,false,21)
    local save=chrome.Action(footer,true,23)
    testStart.label:SetText("Test Publishing");save.label:SetText("Save Draft")
    ns.Tooltips.Bind(save,{title="Save Draft",detail="Validate and keep this draft in your current session. It will not be published."})
    ns.Tooltips.Bind(testStart,{title="Test Publishing",detail="Rehearse a local tournament. No other players will see it."})
    local function SaveForm()
        local form=ReadForm();ClearFocus();W.CloseChoices()
        local record,why=T.SaveDraft(form,displayedKey)
        displayedKey=callbacks.refreshCommunity()
        scope=ns.CompetitiveScope.GetCurrent()
        if geometry then
            chrome.PaintCommunity(community,scope or {},geometry.base,geometry.wide)
            refreshSummary()
        end
        SetStatus(record and "Draft saved for this session. Not published." or why or "Unable to save draft.")
        return record
    end
    save:SetScript("OnClick",SaveForm)
    testStart:SetScript("OnClick",function()
        local record=SaveForm();if not record then return end
        local ok,why=ns.TournamentRegistration.StartPreview(record)
        if ok then callbacks.published() else SetStatus(why or "Unable to start test.") end
    end)
    local function FieldAt(key,x,y,w)
        local v=controls[key];local pad=v.icon and 30 or 0
        if v.icon then At(v.icon,v.parent,x,y+2,23,23) end
        At(v.label,v.parent,x+pad,y,w-pad,27)
        if S.ConstrainText then S.ConstrainText(v.label,w-pad,27,14) end
        At(v.housing or v.box,v.parent,x,y+29,w,40)
    end
    local function Cleanup() W.CloseChoices();ClearFocus() end
    f:HookScript("OnHide",Cleanup)
    local D={}
    function D.Hide() if f:IsShown() then f:Hide() end end
    function D.Show(width,currentScope,key)
        geometry=H.Geometry(width)
        local g=geometry;scope=currentScope or {};displayedKey=key
        f:SetScale(g.scale);At(f,parent,0,0,g.base,g.total);f:Show()
        chrome.PaintCommunity(community,scope,g.base,g.wide)
        At(details,f,0,g.top,g.a,g.bodyH);Header(details,g.a)
        At(rules,f,g.x2,g.y2,g.b,g.bodyH);Header(rules,g.b)
        At(summary,f,g.x3,g.y3,g.c,g.bodyH);Header(summary,g.c)
        At(backdrop,summary,g.c-165,50,160,g.bodyH-56)
        At(divider,summary,14,275,g.c-28,1)
        for i,key in ipairs({"name","location","startUTC","closeBefore"}) do FieldAt(key,14,58+(i-1)*77,g.a-28) end
        Text(format,rules,14,53,g.b-28,30,"Single elimination · 1v1 world duels",15)
        local half=math.floor((g.b-38)/2)
        FieldAt("capacity",14,91,half);FieldAt("bestOf",24+half,91,g.b-half-38)
        FieldAt("minLevel",14,176,half);FieldAt("maxLevel",24+half,176,g.b-half-38)
        FieldAt("rules",14,261,g.b-28)
        Text(ruleHint,rules,14,341,g.b-28,68,"Level limits are checked at registration. Additional rules are reviewed by the organizer.",13)
        At(footer,f,0,g.footerY,g.base,g.footerH)
        At(footerIcon,footer,13,14,25,25)
        local by=g.wide and 12 or 52
        At(testStart,footer,g.base-470,by,220,46)
        At(save,footer,g.base-236,by,222,46)
        PaintStatus();refreshSummary()
        return g.total*g.scale
    end
    return D
end
function H.RunSelfTest()
    local m=H.Project({},nil)
    assert(m.name=="Tournament name not entered" and m.levels=="Any level" and m.starts=="Select date & time")
    local a={name="Cup",location="Elwynn Forest",capacity=16,bestOf=3,minLevel="70",maxLevel="80",rules="No potions"}
    local v=H.Project(a,{starts="2026-11-26 20:00",closes="2026-11-26 19:45"})
    assert(v.name=="Cup" and v.location==a.location and v.capacity=="16 players" and v.series=="Best of 3")
    assert(v.levels=="Level 70 – 80" and v.rules=="No potions" and v.closes=="2026-11-26 19:45")
    a.name="|Htest|h";a.bestOf=5;a.maxLevel=""
    v=H.Project(a,nil);assert(v.name=="||Htest||h" and v.series=="Best of 5" and v.levels=="Level 70 – Any")
    for _,width in ipairs({480,610,759,849,850,940,1170,1400}) do
        local g=H.Geometry(width)
        assert(g.scale==.80 and math.abs(g.base*g.scale-width)<.001 and g.total==g.footerY+g.footerH)
        assert(g.x3+g.c<=g.base and g.x2+g.b<=g.base)
        assert(g.footerY>=g.y3+g.bodyH)
        if g.wide then assert(g.y2==g.top and g.y3==g.top and g.x2>=g.a and g.x3>=g.x2+g.b and g.a>=360 and g.b>=400 and g.c>=330)
        else assert(g.y2>=g.top+g.bodyH and g.y3>=g.y2+g.bodyH) end
    end
    return true
end

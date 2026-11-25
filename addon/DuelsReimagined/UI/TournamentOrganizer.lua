local _,ns=...
local O={};ns.TournamentOrganizer=O
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local chrome=ns.TournamentBrowse.Chrome
local green={.55,.94,.36,1};local amber={1,.75,.26,1};local red={1,.35,.30,1}
local function Clock(n)
    n=math.max(0,math.floor(n or 0))
    return string.format("%02d:%02d:%02d",math.floor(n/3600),math.floor(n/60)%60,n%60)
end
function O.Project(p,query,filter)
    if not p or p.scope~="SIMULATED" or p.role~="host" or not p.event or not p.event.draft then return end
    local d=p.event.draft;local now=p.now
    local bracket=p.bracket
    local complete=bracket and bracket.state=="completed"
    local checking=not bracket and now>=d.startAt-1800 and now<d.startAt
    local registration=not bracket and now<d.registrationClosesAt
    local ready=not bracket and now>=d.startAt
    local stage=complete and 5 or bracket and 4 or ready and 3 or checking and 2 or 1
    local m={stage=stage,registration=registration,checking=checking,ready=ready,rows={},checked=0,notices={},actions={},complete=complete}
    m.state=complete and "Tournament complete" or bracket and (bracket.state=="disputed" and "Result disputed" or "Matches in progress") or ready and "Ready to start" or registration and (checking and "Registration & check-in open" or "Registration open") or checking and "Check-in open" or "Registration closed"
    m.timerLabel=bracket and (complete and "FINAL RESULTS" or "READY MATCHES") or ready and "SCHEDULED START REACHED" or registration and "REGISTRATION CLOSES IN" or "TOURNAMENT STARTS IN"
    m.timer=bracket and (complete and "Completed" or tostring(p.readyCount or 0)) or ready and "Ready" or Clock((registration and d.registrationClosesAt or d.startAt)-now)
    query=(query or ""):lower()
    for _,r in ipairs(p.roster or {}) do
        if r.checkedIn then m.checked=m.checked+1 end
        local offline=p.offline and p.offline.player==r.guid
        local status=offline and "Offline" or r.checkedIn and "Checked in" or "Registered"
        local key=offline and "offline" or r.checkedIn and "checked" or "registered"
        if (not filter or filter=="all" or filter==key) and r.name:lower():find(query,1,true) then
            m.rows[#m.rows+1]={guid=r.guid,name=r.name,level=r.level,status=status,key=key}
        end
    end
    if p.offline then m.notices[#m.notices+1]={text=(p.names and p.names[p.offline.player] or "Participant").." disconnected · "..Clock(p.offline.remaining).." remaining",kind="warning"} end
    if bracket and bracket.dispute then m.notices[#m.notices+1]={text="A match result needs review.",kind="warning"} end
    if complete then m.notices[#m.notices+1]={text="Champion: "..(p.names and p.names[bracket.champion] or "Unavailable"),kind="info"}
    elseif bracket then
        local featured
        for _,round in ipairs(bracket.rounds or {}) do for _,match in ipairs(round) do if match.id==p.featured then featured=match end end end
        if featured then m.notices[#m.notices+1]={text="Featured: "..(p.names[featured.a] or "Unknown").." vs "..(p.names[featured.b] or "Unknown"),kind="info"} end
        m.notices[#m.notices+1]={text=tostring(p.readyCount or 0).." matches ready.",kind="info"}
    else
        m.notices[#m.notices+1]={text=ready and "Scheduled start reached. Start the test bracket when ready." or checking and "Check-in is open." or "Check-in opens in "..Clock(d.startAt-1800-now)..".",kind="info"}
        m.notices[#m.notices+1]={text=math.max(0,d.capacity-p.event.count).." slots remaining ("..p.event.count.." / "..d.capacity..").",kind="info"}
    end
    local function Add(key,label,enabled,reason,primary,test)
        m.actions[#m.actions+1]={key=key,label=label,enabled=enabled==true,reason=reason,primary=primary,test=test}
    end
    Add("brackets","Open Bracket",bracket~=nil,"The bracket has not been drawn.",true)
    local busy=p.demo or p.offline
    if not bracket then
        Add("start-bracket","Start Test Bracket",(p.mode=="host" and p.event.count>=2) or (p.member and p.member.checkedIn==true),"At least two participants or the required check-in are needed.",false,true)
        if p.mode=="host" and p.event.count<d.capacity then Add("fill","Fill Remaining Slots",registration,"Registration has closed.",false,true) end
    elseif bracket.state=="running" then
        Add("simulate-game","Simulate Next Game",not busy and p.selected~=nil,"Finish the current test first.",false,true)
        if (p.readyCount or 0)>1 then
            Add("feature-prev","Previous Featured Match",not busy,"Finish the current test first.",false,true)
            Add("feature-next","Next Featured Match",not busy,"Finish the current test first.",false,true)
        end
        Add("broadcast",p.broadcast and "Exit Broadcast" or "Broadcast View",not busy,"Finish the current test first.",false,true)
    end
    if not p.mode then Add("player","Player Preview",not busy,"Finish the current test first.",false,true) end
    Add("cancel","Cancel Test",not busy,"Finish the current test first.",false,true)
    return m
end
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,size,color,align)
    local t=S.Text(p,"",size,color or C.text);t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(true);return t
end
local function Text(t,p,x,y,w,h,value,color,min)
    At(t,p,x,y,w,h);if S.ConstrainText then S.ConstrainText(t,w,h,min or 13) end
    t:SetText(value or "");if color then t:SetTextColor(unpack(color)) end
end
local function RichPanel(p,kind,corner)
    local f=CreateFrame("Frame",nil,p)
    f.plate=S.Plate(f,kind or "organizerPanel",{corner=corner or 12,layer="BACKGROUND",sublevel=0})
    return f
end
local function Panel(p,title,icon)
    local f=RichPanel(p,"organizerPanel",12)
    f.heading=Label(f,23,C.pale);f.heading:SetText(title)
    f.icon=chrome.Art(f,icon)
    f.line=S.Fill(f,C.goldDim,"BORDER");f.line:SetAlpha(.48)
    return f
end
local function Heading(f,w,caption)
    At(f.icon,f,12,9,30,28);Text(f.heading,f,49,4,w-62,39,caption or f.heading:GetText(),C.pale,17)
    At(f.line,f,12,46,w-24,1)
end
local filters={{key="all",label="All Participants"},{key="registered",label="Registered"},{key="checked",label="Checked in"},{key="offline",label="Offline"}}
function O.New(parent,callbacks)
    local f=CreateFrame("Frame",nil,parent);f:Hide()
    local community=chrome.NewCommunity(f)
    local heading=Label(f,29,C.pale);local headingIcon=chrome.Art(f,"swords")
    local hero=RichPanel(f,"organizerHero",13);local logo=chrome.Art(hero,"logo")
    local heroLaurel=chrome.Art(hero,"laurelR");heroLaurel:SetAlpha(.12)
    local heroLaurel2=chrome.Art(hero,"laurelL");heroLaurel2:SetAlpha(.12)
    local title=Label(hero,32,C.pale)
    local detail={}
    for i,icon in ipairs({"location","swords","players",1,2}) do detail[i]={icon=chrome.Art(hero,icon),text=Label(hero,19,C.text)} end
    local clock=RichPanel(hero,"organizerClockNeutral",13)
    local clockRule=S.Fill(clock,C.goldDim,"BORDER");clockRule:SetAlpha(.52)
    local state=Label(clock,24,green,"CENTER");local timerLabel=Label(clock,16,C.muted,"CENTER")
    local timer=Label(clock,35,C.pale,"CENTER")
    local l=chrome.Art(clock,"laurelL");local r=chrome.Art(clock,"laurelR")
    local stages=RichPanel(f,"organizerPanel",12);local stageTitle=Label(stages,22,C.pale)
    local stageRows,links={},{}
    for i=1,3 do links[i]=S.Fill(stages,C.goldDim,"ARTWORK");links[i]:SetAlpha(.6) end
    for i,name in ipairs({"Registration","Check-in","Bracket","Live Matches"}) do
        local frame=RichPanel(stages,"organizerStageIdle",16)
        stageRows[i]={frame=frame,title=Label(frame,19,C.pale,"CENTER"),status=Label(frame,14,C.muted,"CENTER"),name=name,
            light=chrome.Art(frame,"statusLight")}
    end
    local roster=Panel(f,"Participant Roster","players")
    local filter=chrome.Action(roster,false,17,true)
    local arrow=filter:CreateTexture(nil,"ARTWORK");arrow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\FoldDown.png");ns.Chrome.Sharp(arrow)
    local searchHousing=chrome.Panel(roster,false)
    local search=CreateFrame("EditBox",nil,searchHousing);search:SetAllPoints(searchHousing)
    search:SetAutoFocus(false);search:SetMaxLetters(60);search:SetTextInsets(9,9,0,0)
    search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",17,"");search:SetTextColor(unpack(C.text));S.BindFont(search,17,false,C.text)
    search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    search:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local placeholder=Label(searchHousing,16,C.muted);placeholder:SetText("Search players...")
    local headers={Label(roster,16,C.muted),Label(roster,16,C.muted,"CENTER"),Label(roster,16,C.muted)}
    local list=CreateFrame("Frame",nil,roster);list:EnableMouseWheel(true)
    local rows={}
    local rowHeight=37
    local rowCount=7
    for i=1,rowCount do
        local b=CreateFrame("Button",nil,list);b:RegisterForClicks("LeftButtonUp")
        local stripe=S.Fill(b,C.goldDim,"BACKGROUND");stripe:SetAlpha(i%2==0 and .10 or .025)
        local hover=S.Fill(b,C.selected);hover:SetAlpha(0)
        b:SetScript("OnEnter",function()ns.Motion.Fade(hover,.5,.12)end)
        b:SetScript("OnLeave",function()ns.Motion.Fade(hover,0,.12)end)
        W.PressFeedback(b,hover)
        local line=S.Fill(b,C.goldDim,"BORDER");line:SetAlpha(.3)
        rows[i]={button=b,name=Label(b,19,C.text),level=Label(b,18,C.text,"CENTER"),
            status=Label(b,17,C.text),dot=chrome.Art(b,"statusLight"),line=line}
    end
    local empty=Label(list,19,C.muted,"CENTER")
    local summary=Label(roster,16,C.muted)
    local actions=Panel(f,"Organizer Actions","flag")
    local buttons={}
    for i=1,7 do
        buttons[i]=chrome.Action(actions,i==1,18)
        if i==1 then buttons[i].plate:SetStyle("gold") end
    end
    local notices=Panel(f,"Alerts & Notices",2)
    local noticeRows={}
    for i=1,4 do noticeRows[i]={dot=chrome.Art(notices,"statusLight"),label=Label(notices,17,C.text)} end
    local footer=Label(f,17,C.muted,"CENTER")
    local model,current,offset,filterKey,query={rows={}},nil,0,"all",""
    local clockTimer
    local function StopClock() if clockTimer then clockTimer:Cancel();clockTimer=nil end end
    local listW=650
    local eventId,confirm
    local renderRows
    local function SetOffset(value)
        offset=math.max(0,math.min(math.max(0,#(model.rows or {})-rowCount)*rowHeight,value or 0))
        if renderRows then renderRows() end
    end
    local bar=W.ScrollBar(list,function()
        return rowCount*rowHeight,math.max(rowCount,#(model.rows or {}))*rowHeight,offset
    end,SetOffset)
    local function Reproject()
        if not current then return end
        model=O.Project(current,query,filterKey);SetOffset(offset);bar:Refresh()
    end
    renderRows=function()
        if not current or type(model)~="table" then return end
        local first=math.floor(offset/rowHeight)
        for i,row in ipairs(rows) do
            local item=model.rows[first+i]
            row.button:SetShown(item~=nil)
            if item then
                local b=row.button
                At(b,list,0,(i-1)*rowHeight,listW-15,rowHeight)
                Text(row.name,b,10,0,listW*.52-14,rowHeight,item.name,C.text)
                Text(row.level,b,listW*.52,0,listW*.13,rowHeight,tostring(item.level or "—"),C.text)
                local color=item.key=="offline" and red or item.key=="checked" and green or amber
                At(row.dot,b,listW*.69,8,20,20);row.dot:SetVertexColor(unpack(color))
                Text(row.status,b,listW*.69+23,0,listW*.31-45,rowHeight,item.status,color)
                At(row.line,b,6,rowHeight-1,listW-29,1)
                b:SetScript("OnClick",function()search:ClearFocus();W.CloseChoices();callbacks.profile(item)end)
            end
        end
        empty:SetShown(#model.rows==0);Text(empty,list,10,0,listW-30,rowCount*rowHeight,"No matching participants.")
    end
    local function Wheel(_,delta) SetOffset(offset-delta*rowHeight);bar:Refresh() end
    list:SetScript("OnMouseWheel",Wheel)
    for _,row in ipairs(rows) do row.button:EnableMouseWheel(true);row.button:SetScript("OnMouseWheel",Wheel) end
    search:SetScript("OnTextChanged",function(self)
        query=self:GetText() or "";placeholder:SetShown(query=="")
        offset=0;Reproject()
    end)
    filter:SetScript("OnClick",function()
        search:ClearFocus()
        W.OpenChoices(filter,filters,filterKey,function(key)
            filterKey=key;offset=0
            for _,item in ipairs(filters) do if item.key==key then filter.label:SetText(item.label) end end
            Reproject()
        end)
    end)
    filter.label:SetText("All Participants")
    local function Cleanup()
        StopClock()
        search:ClearFocus();W.CloseChoices()
        if ns.CompetitiveUI then ns.CompetitiveUI.CloseTournamentPlayerCard() end
        confirm=nil
    end
    f:HookScript("OnHide",Cleanup)
    local D={}
    function D.Hide() StopClock();if f:IsShown() then f:Hide() end;current=nil end
    local function ArmClock()
        if clockTimer or not current or current.bracket or model.ready or current.mode~="host" or
            not f:IsVisible() or not C_Timer or type(C_Timer.NewTimer)~="function" then return end
        clockTimer=C_Timer.NewTimer(1,function()
            clockTimer=nil
            if not f:IsVisible() or not current or current.bracket then return end
            local now=ns.TournamentRegistration.SyncHostPreviewClock(current.event.id)
            if not now then return end
            if now~=current.now then
                current.now=now
                local nextModel=O.Project(current,query,filterKey)
                if nextModel.stage~=model.stage or nextModel.registration~=model.registration or nextModel.checking~=model.checking then
                    if callbacks.refresh then callbacks.refresh() end
                    return
                end
                model=nextModel
                timer:SetText(model.timer)
                for i,item in ipairs(model.notices) do
                    if noticeRows[i] then noticeRows[i].label:SetText(item.text) end
                end
            end
            ArmClock()
        end)
    end
    function D.Show(p,width,scope,feedback)
        if eventId~=p.event.id then
            eventId=p.event.id;offset=0;filterKey="all";query="";confirm=nil;search:SetText("");filter.label:SetText("All Participants")
            if ns.CompetitiveUI then ns.CompetitiveUI.CloseTournamentPlayerCard() end
        end
        current=p;model=O.Project(p,query,filterKey)
        local wide=width>=760;local base=wide and 1170 or 640;local scale=width/base
        local top=wide and 78 or 132
        local heroY=top+45;local heroH=wide and 166 or 248
        local stageY=heroY+heroH+12;local stageH=wide and 68 or 128
        local bodyY=stageY+stageH+12
        local left=wide and 676 or base;local right=wide and base-left-12 or base
        local ax=wide and left+12 or 0;local ay=wide and bodyY or bodyY+385
        local actionH=62+math.ceil(#model.actions/2)*43
        local noteY=ay+actionH+12;local noteH=174
        local bottom=math.max(bodyY+373,noteY+noteH)
        local total=bottom+47
        f:SetScale(scale);At(f,parent,0,0,base,total);f:Show()
        chrome.PaintCommunity(community,scope or {},base,wide)
        At(headingIcon,f,3,top+4,36,32);Text(heading,f,49,top,base-55,42,"Organizer Control Center",C.pale,20)
        At(hero,f,0,heroY,base,heroH);At(logo,hero,16,15,124,112)
        At(heroLaurel,hero,4,12,52,heroH-24);At(heroLaurel2,hero,101,12,52,heroH-24)
        local d=p.event.draft;local times=ns.TournamentState.GetSchedulePreview(d.startUTC,d.closeBefore)
        local detailsW=wide and base-520 or base-160
        Text(title,hero,155,3,detailsW,42,d.name,C.pale,21)
        local vals={d.location,"Single elimination (Best of "..d.bestOf..")",p.event.count.." / "..d.capacity.." Players",
            "Starts: "..(times and times.starts or d.startUTC.." UTC"),
            "Registration closes: "..(times and times.closes or "Unavailable")}
        for i,row in ipairs(detail) do
            local x,y=155,44+(i-1)*23
            if wide and i==3 then x=470;y=67 end
            if wide and i>=4 then y=y-23 end
            At(row.icon,hero,x,y+2,20,20);Text(row.text,hero,x+28,y,wide and (i==2 and 275 or i==3 and 180 or detailsW-28) or detailsW-28,23,vals[i],C.text,14)
        end
        local cx=wide and base-375 or 16;local cy=wide and 18 or 170;local cw=wide and 356 or base-32;local ch=wide and 130 or 64
        At(clock,hero,cx,cy,cw,ch)
        clock.plate:SetStyle((model.registration or model.checking) and "organizerClockGreen" or "organizerClockNeutral")
        At(clockRule,clock,14,42,cw-28,1);clockRule:SetShown(wide)
        if wide then
            Text(state,clock,10,4,cw-20,38,model.state,(model.registration or model.checking) and green or C.pale,17)
            Text(timerLabel,clock,15,45,cw-30,27,model.timerLabel)
            Text(timer,clock,40,70,cw-80,52,model.timer,C.pale,22)
            At(l,clock,12,76,28,38);At(r,clock,cw-40,76,28,38)
        else
            Text(state,clock,10,2,cw*.47,30,model.state,C.pale)
            Text(timerLabel,clock,10,33,cw*.47,24,model.timerLabel)
            Text(timer,clock,cw*.49,3,cw*.49,58,model.timer,C.pale,22)
            l:Hide();r:Hide()
        end
        l:SetShown(wide);r:SetShown(wide)
        At(stages,f,0,stageY,base,stageH)
        Text(stageTitle,stages,12,8,wide and 174 or base-24,wide and 52 or 31,"Tournament Stage",C.pale,16)
        local start=wide and 192 or 12;local sw=(base-start-12-3*10)/4
        local labels={model.registration and "Open" or "Closed",p.bracket and "Complete" or model.ready and "Closed" or model.checking and "Open" or "Not open",p.bracket and "Drawn" or model.ready and "Ready to draw" or "Not drawn",model.complete and "Complete" or p.bracket and "In progress" or "Not started"}
        for i,row in ipairs(stageRows) do
            local active=(i==1 and model.registration) or (i==2 and model.checking) or model.stage==i
            local done=not active and model.stage>i
            local style=active and "organizerStageActive" or done and "organizerStageDone" or "organizerStageIdle"
            local y=wide and 8 or 42
            At(row.frame,stages,start+(i-1)*(sw+10),y,sw,wide and 52 or 72)
            row.frame.plate:SetStyle(style)
            At(row.light,row.frame,5,16,19,19);row.light:SetVertexColor(unpack(active and green or done and C.gold or C.muted))
            Text(row.title,row.frame,23,1,sw-28,28,row.name,active and green or C.pale,13)
            Text(row.status,row.frame,23,28,sw-28,22,labels[i],active and green or C.muted,12)
            if i<4 then At(links[i],stages,start+i*sw+(i-1)*10,y+25,10,2);links[i]:SetAlpha((done or active) and .9 or .35) end
        end
        At(roster,f,0,bodyY,left,373);Heading(roster,left,"Participant Roster ("..p.event.count.." / "..d.capacity..")")
        local compact=wide and width>=900
        local filterW=compact and 162 or math.floor(left*.43)
        local filterX=compact and left-358 or 12
        local filterY=compact and 8 or 54
        local searchW=left-filterX-filterW-22
        if compact then Text(roster.heading,roster,49,4,filterX-57,39,"Participant Roster ("..p.event.count.." / "..d.capacity..")",C.pale,15) end
        At(filter,roster,filterX,filterY,filterW,34)
        At(arrow,filter,filterW-24,9,16,16)
        At(searchHousing,roster,filterX+filterW+10,filterY,searchW,34)
        At(placeholder,searchHousing,9,0,searchW-18,34);placeholder:SetShown(query=="")
        listW=left-24
        local headerY=compact and 52 or 90
        Text(headers[1],roster,22,headerY,listW*.52-10,22,"Player")
        Text(headers[2],roster,12+listW*.52,headerY,listW*.13,22,"Level")
        Text(headers[3],roster,12+listW*.69,headerY,listW*.29,22,"Status")
        At(list,roster,12,headerY+22,listW,rowCount*rowHeight)
        SetOffset(offset);bar:Refresh()
        -- Keep the roster count in the heading; all 32 rows are reachable.
        At(actions,f,ax,ay,right,actionH);Heading(actions,right)
        local bw=(right-34)/2
        for i,b in ipairs(buttons) do
            local action=model.actions[i];b:SetShown(action~=nil)
            if action then
                local label=action.key=="cancel" and confirm==p.event.id and "Confirm Cancel" or action.label
                b.label:SetText(label);b:SetEnabled(action.enabled);b:SetAlpha(action.enabled and 1 or .5)
                At(b,actions,12+((i-1)%2)*(bw+10),54+math.floor((i-1)/2)*43,bw,37)
                b.reason=action.reason;b.caption=label
                if not b.bound then b.bound=true;ns.Tooltips.Bind(b,function(owner)
                    if not owner:IsEnabled() then return {title=owner.caption,disabled=owner.reason} end
                end) end
                b:SetScript("OnClick",function()
                    search:ClearFocus();W.CloseChoices()
                    if action.key=="cancel" and confirm~=p.event.id then confirm=p.event.id;b.label:SetText("Confirm Cancel");return end
                    confirm=nil;callbacks.action(action.key)
                end)
            end
        end
        At(notices,f,ax,noteY,right,noteH);Heading(notices,right)
        local messages={}
        for _,v in ipairs(model.notices) do messages[#messages+1]=v end
        if feedback and feedback~="" then messages[#messages+1]={text=feedback,kind="info"} end
        if #messages==0 then messages[1]={text="No current alerts.",kind="info"} end
        for i,row in ipairs(noticeRows) do
            local item=messages[i];row.dot:SetShown(item~=nil);row.label:SetShown(item~=nil)
            if item then
                At(row.dot,notices,13,52+(i-1)*29,19,19)
                row.dot:SetVertexColor(unpack(item.kind=="warning" and red or C.gold))
                Text(row.label,notices,40,48+(i-1)*29,right-52,29,item.text,C.text,13)
            end
        end
        Text(footer,f,0,bottom+6,base,36,"LOCAL TEST  ·  Test controls are temporary. The schedule follows server time until the start.",C.muted,13)
        if current.bracket or model.ready then StopClock() else ArmClock() end
        return total*scale
    end
    return D
end
function O.RunSelfTest()
    assert(not O.Project(nil))
    local p={scope="SIMULATED",role="host",now=100,event={id="test",count=2,draft={capacity=4,startAt=4000,registrationClosesAt=3100}},roster={
        {guid="a",name="Mooncrest",level=13,checkedIn=true},{guid="b",name="Thornheart",level=13,checkedIn=false}},names={a="Mooncrest",b="Thornheart"},mode="host"}
    local m=O.Project(p,"","all");assert(m.registration and m.stage==1 and m.checked==1 and #m.rows==2)
    assert(#O.Project(p,"moon","all").rows==1 and #O.Project(p,"","checked").rows==1)
    p.now=2300;assert(O.Project(p).registration and O.Project(p).checking)
    assert(O.Project(p).timer=="00:13:20")
    p.now=3100;assert(not O.Project(p).registration and O.Project(p).checking and O.Project(p).timer=="00:15:00")
    p.now=4000;assert(O.Project(p).ready and O.Project(p).timer=="Ready")
    p.now=2300
    p.bracket={state="running",rounds={}};p.offline={player="b",remaining=120}
    m=O.Project(p,"","offline");assert(#m.rows==1 and m.rows[1].guid=="b" and m.stage==4)
    p.bracket={state="completed",champion="a"};p.offline=nil;assert(O.Project(p).complete)
    return true
end

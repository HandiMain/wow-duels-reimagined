local _,ns=...
-- One tournament view inside the shared window; no gameplay or network calls.
local U={};ns.TournamentUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local T=ns.TournamentState
local R=ns.TournamentRegistration
local Population=ns.CompetitiveScope
local root=CreateFrame("Frame",nil,ns.Window.content)
root:SetAllPoints(ns.Window.content);root:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Tournaments",root) end
function U.PaintEmblem(t)
    -- Reuse an existing authored medal/emblem crop, no new asset dependency.
    t:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelAchievementArt.png")
    t:SetTexCoord(778/1024,890/1024,154/1024,234/1024)
    ns.Chrome.Sharp(t)
end
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y)
    f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,txt,size,color,align)
    local f=S.Text(p,txt,size,color)
    f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(true)
    return f
end
local function TextAt(f,p,x,y,w,h)
    Place(f,p,x,y,w,h)
end
local function Panel(p,caption)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=9,edge=C.goldDim,light=C.goldDim,dark=C.window,shade=.12,shine=.11,rim=.82})
    f.heading=Label(f,caption,18,C.pale)
    local line=S.Fill(f,C.goldDim,"BORDER")
    line:ClearAllPoints();line:SetPoint("TOPLEFT",f,"TOPLEFT",12,-38)
    line:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-38);line:SetHeight(1);line:SetAlpha(.55)
    return f
end
local function Header(f,w) TextAt(f.heading,f,12,6,w-24,28) end
local function Button(p,label,key,primary)
    local b=S.Action(p,label,"footer",{plate=primary and "hall" or "dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    b:SetScript("OnClick",function()
        if ns.Navigation then ns.Navigation.SelectKey("tournaments",key) end
    end)
    ns.Tooltips.Bind(b,{title=label,detail="Open this tournament page."})
    return b
end
local title=Label(root,"TOURNAMENTS",27,C.pale)
title:SetPoint("TOPLEFT",root,"TOPLEFT",70,-15)
local emblem=root:CreateTexture(nil,"ARTWORK");U.PaintEmblem(emblem)
emblem:SetSize(43,36);emblem:SetPoint("TOPLEFT",root,"TOPLEFT",24,-15)
local subtitle=Label(root,"Community 1v1 duel tournaments",13,C.text)
subtitle:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-4)
-- Width is assigned by the shared page layout below.
local scroll=CreateFrame("ScrollFrame",nil,root)
scroll:SetPoint("TOPLEFT",root,"TOPLEFT",24,-133)
scroll:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-28,15)
scroll:EnableMouseWheel(true)
local canvas=CreateFrame("Frame",nil,scroll);canvas:SetSize(800,500);scroll:SetScrollChild(canvas)
-- One read-only community strip for host, browsing, and future event details.
local community=Panel(canvas,"Tournament community")
community:Hide()
local labels,values={},{}
local titles={"Game client","Region","Ruleset","Faction"}
for index,caption in ipairs(titles) do
    labels[index]=Label(community,caption,11,C.muted)
    values[index]=Label(community,"Unavailable",15,C.pale)
end
local communityNote=Label(community,"Automatically detected. These settings cannot be changed.",12,C.muted)
local displayedKey
local function RefreshCommunity()
    local s=Population.GetCurrent()
    local modes={normal="PvE",pvp="PvP",rp="RP",["rp-pvp"]="RP-PvP",hardcore="Hardcore",retail="Standard"}
    values[1]:SetText(s.client=="retail" and "Retail" or s.client=="forever" and "Forever" or "Unavailable")
    values[2]:SetText(s.region=="EU" and "Europe (EU)" or s.region=="US" and "Americas (US)" or "Unavailable")
    values[3]:SetText(modes[s.ruleset] or "Unavailable")
    values[4]:SetText(s.faction or "Unavailable")
    local color=s.faction=="Alliance" and {0.40,0.67,1,1} or s.faction=="Horde" and {1,0.39,0.32,1} or C.pale
    values[4]:SetTextColor(unpack(color))
    displayedKey=Population.Key(s)
    communityNote:SetText(displayedKey and "Automatically detected. Only this community can participate." or
        "Community unavailable or unsupported. Hosting and joining are unavailable.")
    return displayedKey
end
local function LayoutCommunity(w)
    local cols=w>=600 and 4 or 2
    local rows=4/cols
    local h=80+rows*44
    Place(community,canvas,0,0,w,h);Header(community,w)
    local cell=(w-24)/cols
    for index=1,4 do
        local x=12+((index-1)%cols)*cell
        local y=43+math.floor((index-1)/cols)*44
        TextAt(labels[index],community,x,y,cell-6,16)
        TextAt(values[index],community,x,y+16,cell-6,25)
    end
    TextAt(communityNote,community,12,43+rows*44,w-24,32)
    return h+12
end
local pages={}
local function Page(key)
    local f=CreateFrame("Frame",nil,canvas);f:SetAllPoints(canvas);f:Hide();pages[key]=f;return f
end
local overview=Page("overview")
local overviewView,privateControlsTop
local browse=Page("browse")
local list=Panel(browse,"Browse Tournaments")
list.detail=Label(list,"No tournaments discovered.",17,C.muted,"CENTER")
list.note=Label(list,"Tournament discovery is not active yet.",13,C.muted,"CENTER")
local info=Panel(browse,"Tournament Details")
info.detail=Label(info,"Select a tournament to view its details and rules.",15,C.muted,"CENTER")
local host=Page("host")
local manage=Panel(host,"Tournament details")
local eventRules=Panel(host,"Format & rules")
local draftFooter=Panel(host,"Save your draft")
local defaults=T.DraftDefaults()
local form,controls,choices={}, {}, {}
local status=Label(draftFooter,"Drafts are kept until you reload or log out. Publishing is not available yet.",13,C.muted)
local refreshSchedule
local function Dirty()
    status:SetText("Unsaved changes. Drafts stay in this session only.")
    if refreshSchedule then refreshSchedule() end
end
local function Field(parent,key,caption,limit,help)
    local label=Label(parent,caption,13,C.pale)
    local box=CreateFrame("EditBox",nil,parent)
    box:SetAutoFocus(false);box:SetMultiLine(false);box:SetMaxLetters(limit)
    box:SetTextInsets(9,9,0,0)
    S.BindFont(box,13,false,C.text)
    S.Skin(box,C.body,{corner=8,edge=C.border,shine=.15,shade=.2})
    box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    box:SetScript("OnHide",function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged",function(self,userInput) if userInput then Dirty() end end)
    box:SetText(defaults[key] or "")
    controls[key]={label=label,box=box,parent=parent}
    ns.Tooltips.Bind(box,{title=caption,detail=help})
    return box
end
local function Choice(parent,key,caption,options)
    local label=Label(parent,caption,13,C.pale)
    local box,value=W.ChoiceControl(parent,226)
    local selected=defaults[key]
    local function Select(k)
        selected=k;choices[key]=k
        for _,o in ipairs(options) do if o.key==k then value:SetText(o.label);break end end
    end
    Select(selected)
    box:SetScript("OnClick",function()
        W.OpenChoices(box,options,selected,function(k) Select(k);Dirty() end)
    end)
    controls[key]={label=label,box=box,parent=parent,choice=true}
    return box
end
Field(manage,"name","Tournament name",60,"Name shown to participants. Plain text only; no links.")
Field(manage,"location","World duel location",100,"Describe the meeting place. No automatic teleport or arena.")
local startLabel=Label(manage,"Start date & time (local)",13,C.pale)
local startButton,startText=W.ChoiceControl(manage,226)
local selectedUTC=""
startText:SetText("Select date & time")
controls.startUTC={label=startLabel,box=startButton,parent=manage,calendar=true}
startButton:SetScript("OnClick",function()
    for _,control in pairs(controls) do
        if not control.choice and not control.calendar then control.box:ClearFocus() end
    end
    if not W.OpenCalendar(startButton,T,selectedUTC,choices.closeBefore,function(utc)
        selectedUTC=utc;Dirty()
    end) then status:SetText("Your local calendar is unavailable. Try again later.") end
end)
ns.Tooltips.Bind(startButton,{title="Start date & time",detail="Choose the start in your local time. Registration deadline updates automatically."})
Choice(manage,"closeBefore","Registration closes",{
    {key=0,label="At start"},{key=15,label="15 min before"},{key=30,label="30 min before"},{key=60,label="60 min before"}})
local localSchedule=Label(manage,"Select the tournament start date and time.",12,C.muted)
refreshSchedule=function()
    local result=T.GetSchedulePreview(selectedUTC,choices.closeBefore)
    startText:SetText(result and result.starts or "Select date & time")
    if result then
        localSchedule:SetText("Start: "..result.starts.." (local)\nRegistration closes: "..result.closes.." (local)")
    else
        localSchedule:SetText("Select a date and time to see the registration deadline.")
    end
end
local format=Label(eventRules,"Single elimination · 1v1 world duels",14,C.text)
Choice(eventRules,"capacity","Maximum players",{
    {key=4,label="4 players"},{key=8,label="8 players"},{key=16,label="16 players"},{key=32,label="32 players"}})
Choice(eventRules,"bestOf","Match series",{
    {key=1,label="Best of 1"},{key=3,label="Best of 3"},{key=5,label="Best of 5"}})
Field(eventRules,"minLevel","Minimum level (optional)",3,"Leave blank for no minimum. Eligibility checks come with registration.")
Field(eventRules,"maxLevel","Maximum level (optional)",3,"Leave blank for no maximum. Eligibility checks come with registration.")
Field(eventRules,"rules","Additional rules (optional)",160,"Plain text rules for the organizer to enforce; not automatically detected.")
local ruleHint=Label(eventRules,"Level limits are checked in the local test. Additional rules are reviewed by the organizer.",12,C.muted)
local testStart=S.Action(draftFooter,"Test Publishing","footer",{plate="dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
local save=S.Action(draftFooter,"Save Draft","footer",{plate="hall",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
ns.Tooltips.Bind(save,{title="Save Draft",detail="Validate and keep this draft in your current session. It will not be published."})
local function SaveForm()
    for key,control in pairs(controls) do
        if control.calendar then form[key]=selectedUTC
        elseif control.choice then form[key]=choices[key]
        else form[key]=control.box:GetText();control.box:ClearFocus() end
    end
    W.CloseChoices()
    local record,why=T.SaveDraft(form,displayedKey)
    RefreshCommunity()
    status:SetText(record and "Draft saved for this session. Not published." or why)
    return record
end
save:SetScript("OnClick",SaveForm)
ns.Tooltips.Bind(testStart,{title="Test Publishing",detail="Rehearse a local tournament. No other players will see it."})
testStart:SetScript("OnClick",function()
    local record=SaveForm();if not record then return end
    local ok,why=R.StartPreview(record)
    if ok then
        if not (ns.Navigation and ns.Navigation.SelectKey("tournaments","manage")) then U.Show("manage") end
    else status:SetText(why) end
end)
host:HookScript("OnHide",function()
    W.CloseChoices()
    for _,control in pairs(controls) do if not control.choice and not control.calendar then control.box:ClearFocus() end end
end)
local function FieldAt(key,x,y,width)
    local v=controls[key]
    Place(v.label,v.parent,x,y,width,22)
    Place(v.box,v.parent,x,y+24,width,30)
end
local function LayoutHost(w)
    local wide=w>=700
    local a=wide and math.floor((w-12)*.49) or w
    local b=wide and w-a-12 or w
    local h1,h2=365,350
    local x2,y2=wide and a+12 or 0,wide and 0 or h1+12
    Place(manage,host,0,0,a,h1);Header(manage,a)
    FieldAt("name",12,45,a-24)
    FieldAt("location",12,105,a-24)
    FieldAt("startUTC",12,165,a-24)
    FieldAt("closeBefore",12,225,a-24)
    TextAt(localSchedule,manage,12,283,a-24,66)
    Place(eventRules,host,x2,y2,b,h2);Header(eventRules,b)
    TextAt(format,eventRules,12,43,b-24,28)
    local half=math.floor((b-34)/2)
    FieldAt("capacity",12,80,half)
    FieldAt("bestOf",22+half,80,b-half-34)
    FieldAt("minLevel",12,140,half)
    FieldAt("maxLevel",22+half,140,b-half-34)
    FieldAt("rules",12,200,b-24)
    TextAt(ruleHint,eventRules,12,264,b-24,80)
    local footerY=math.max(h1,y2+h2)+12
    Place(draftFooter,host,0,footerY,w,138);Header(draftFooter,w)
    TextAt(status,draftFooter,12,42,w-24,48)
    Place(save,draftFooter,math.max(12,w-152),96,140,30)
    Place(testStart,draftFooter,12,96,math.max(1,math.min(160,w-178)),30)
    return footerY+138
end
local championPage=Page("champions")
local archive=Panel(championPage,"Hall of Champions")
archive.detail=Label(archive,"No completed tournaments recorded.",15,C.muted,"CENTER")
local mine=Page("my-tournament")
local myPanel=Panel(mine,"My Tournament")
myPanel.detail=Label(myPanel,"No active tournament.",15,C.muted,"CENTER")
local brackets=Page("brackets")
local bracketPanel=Panel(brackets,"Brackets")
bracketPanel.detail=Label(bracketPanel,"No tournament bracket available.",15,C.muted,"CENTER")
local bracketView
-- Explicit rehearsal views. Normal browsing never contains test events.
local organizer=Page("manage")
local hostTest=Panel(organizer,"Local test - Organizer")
local hostSummary=Label(hostTest,"",15,C.text)
local hostRoster=Label(hostTest,"",14,C.pale)

local function Action(parent,label,fn)
    local b=S.Action(parent,label,"footer",{plate="dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    b:SetScript("OnClick",fn);return b
end
local feedback=""
local lastTestID
local active
local function Switch(key)
    if not (ns.Navigation and ns.Navigation.SelectKey("tournaments",key)) then U.Show(key) end
end
local function Run(action,key)
    local p=action=="simulate-game" and R.PreviewSnapshot()
    local ok,why
    if (action=="disconnect" or action=="feature-next" or action=="feature-prev" or action=="broadcast")
        and ns.DuelCountdown.IsTournamentPreviewRunning() then
        feedback="Wait for the test countdown to finish.";U.Show(active or "overview");return
    end
    if (action=="disconnect" or action=="advance-grace" or action=="reconnect") and not ns.DuelHUD.IsTournamentHUDActive() then
        feedback="Show the tournament HUD and finish combat first.";U.Show(active or "overview");return
    end
    if p and p.bracket and p.bracket.state=="running" and ns.DuelHUD.IsTournamentHUDActive() then
        ok,why=ns.TournamentHUD.RequestGame()
    elseif p and p.bracket and p.bracket.state=="running" then ok,why=false,"Show the tournament HUD and finish combat first."
    else
        local result,notice
        ok,why,result,notice=R.PreviewAction(action)
        if notice and ns.Notifications and ns.Notifications.OnTournamentGrace then ns.Notifications.OnTournamentGrace(notice) end
        if result and ns.DuelResult then ns.DuelResult.ShowTournamentPreview(result) end
    end
    feedback=why or ""
    if ok and action=="cancel" and ns.Notifications then ns.Notifications.ClearTournamentPreview() end
    if ok and key then Switch(key) else U.Show(active or "overview") end
end
local hostPlayer=Action(hostTest,"Player Preview",function()
    local p=R.PreviewSnapshot()
    if p then Run("player",p.member and "my-tournament" or "browse") else Switch("overview") end
end)
local hostStart=Action(hostTest,"Start Test Bracket",function()Run("start-bracket","brackets")end)
local hostFill=Action(hostTest,"Fill Remaining Slots",function()Run("fill")end)
local hostSim=Action(hostTest,"Simulate Next Game",function()Run("simulate-game","brackets")end)
local hostCancel=Action(hostTest,"Cancel Test",function()Run("cancel","host")end)
local featurePrev=Action(hostTest,"Previous featured match",function()Run("feature-prev")end)
local featureNext=Action(hostTest,"Next featured match",function()Run("feature-next")end)
local listRow=CreateFrame("Frame",nil,list)
S.Skin(listRow,C.body,{corner=8,edge=C.goldDim,shine=.12,shade=.18})
local listRowText=Label(listRow,"",14,C.pale,"CENTER");listRowText:SetAllPoints(listRow)
local selectedListing=1
local catalogRows={}
for i=1,4 do
    local index=i
    catalogRows[i]=Action(list,"",function()
        selectedListing=index;feedback="";U.Show("browse")
    end)
end
local openCatalog=Action(list,"Browse Test Tournaments",function()
    local ok,why=R.OpenTestCatalog();feedback=why or "";selectedListing=1
    U.Show("browse")
end)
local join=Action(info,"Test Join",function()
    if R.TestListings() then
        local ok,why=R.JoinTestListing(selectedListing);feedback=why or ""
        if ok then Switch("my-tournament") else U.Show("browse") end
    else Run("join","my-tournament") end
end)
local watch=Action(info,"Watch Test Tournament",function()
    local ok,why=R.WatchTestListing(selectedListing);feedback=why or ""
    if ok then Switch("brackets") else U.Show("browse") end
end)
local browseHost=Action(info,"Organizer View",function()Run("host","manage")end)
local check=Action(myPanel,"Test Check-in",function()Run("checkin")end)
local advance=Action(myPanel,"Test Check-in Time",function()Run("checkin-time")end)
local leave=Action(myPanel,"Leave Test",function()Run("leave","browse")end)
local myHost=Action(myPanel,"Organizer View",function()Run("host","manage")end)
local sampleStart=Action(myPanel,"Simulate Tournament Start",function()Run("start-bracket","brackets")end)
local sampleGame=Action(myPanel,"Simulate Next Game",function()Run("simulate-game","brackets")end)
local bracketGame=Action(bracketPanel,"Simulate Next Game",function()Run("simulate-game")end)
local broadcast=Action(bracketPanel,"Broadcast view",function()Run("broadcast")end)
local testDisconnect=Action(bracketPanel,"Test disconnect",function()Run("disconnect")end)
local testAdvance=Action(bracketPanel,"Advance test 1 min",function()Run("advance-grace")end)
local testReconnect=Action(bracketPanel,"Test reconnect",function()Run("reconnect")end)
local matchNotice=Action(myPanel,"Preview Match Notification",function()
    local ok,why=ns.Notifications.PreviewTournamentReady()
    feedback=ok and "Match notification shown." or why or "Notification unavailable."
    U.Show("my-tournament")
end)
local function EndTest()
    R.EndPreview()
    if ns.DuelResult then ns.DuelResult.ClearTournamentPreview() end
    if ns.Notifications then ns.Notifications.ClearTournamentPreview() end
    feedback="";Switch("overview")
end
local function OverviewAction(action)
    if action=="end-test" then EndTest();return end
    local private=ns.TournamentSession and ns.TournamentSession.IsActive()
    if private then
        if action=="checkin" then
            local ok,why=ns.TournamentSession.Command("checkin")
            feedback=why or (ok and "Request submitted." or "Check-in unavailable.")
        end
        if action=="details" or action=="manage" or action=="checkin" then
            U.Show("overview")
            if privateControlsTop then U.SetPageScroll(nil,privateControlsTop) end
            return
        end
    end
    if action=="details" then action="my-tournament" end
    if action=="checkin" then Run("checkin","overview");return end
    if T.IsPageAvailable(action) then Switch(action) end
end
local privatePanel,privateDetail,privateButtons,privateFeedback,privateConfirm
local privateBack
local function LayoutPrivate(model,w,y)
    if not privatePanel then
        privatePanel=Panel(overview,"Private Tournament Test")
        privateDetail=Label(privatePanel,"",14,C.text)
        privateButtons={}
        for i=1,12 do
            local button=Action(privatePanel,"",function()end)
            button:Hide();privateButtons[i]=button
        end
    end
    local cols=w>=520 and 2 or 1
    local detailH=model.active and 144 or 86
    local rows=math.ceil(#model.actions/cols)
    local height=48+detailH+rows*38+14
    Place(privatePanel,overview,0,y,w,height);Header(privatePanel,w);privatePanel:Show()
    TextAt(privateDetail,privatePanel,12,42,w-24,detailH)
    privateDetail:SetText(model.detail..(privateFeedback and "\n"..privateFeedback or ""))
    if privateConfirm and privateConfirm.context~=model.context then privateConfirm=nil end
    local bw=(w-24-(cols-1)*8)/cols
    for i,button in ipairs(privateButtons) do
        local action=model.actions[i]
        button:SetShown(action~=nil)
        if action then
            local command,label=action.command,action.label
            local confirmed=privateConfirm and privateConfirm.command==command and privateConfirm.context==model.context
            button.label:SetText(confirmed and "Confirm: "..label or label)
            Place(button,privatePanel,12+(i-1)%cols*(bw+8),46+detailH+math.floor((i-1)/cols)*38,bw,30)
            button:SetScript("OnClick",function()
                if command=="view-bracket" then privateConfirm=nil;Switch("brackets");return end
                if action.confirm and not (privateConfirm and privateConfirm.command==command and privateConfirm.context==model.context) then
                    privateConfirm={command=command,context=model.context}
                    U.Show("overview");return
                end
                privateConfirm=nil
                local ok,why=ns.TournamentSession.Command(command)
                privateFeedback=why or (ok and "Request submitted." or "Request unavailable.")
                U.Show("overview")
            end)
        end
    end
    return height
end
local function Describe(ad)
    local d=ad.draft
    local times=T.GetSchedulePreview(d.startUTC,d.closeBefore)
    local schedule=times and times.starts.." (your local time)" or d.startUTC.." UTC"
    local deadline=times and times.closes or (d.closeBefore==0 and "At start (UTC)" or d.closeBefore.." minutes before start")
    local levels=(d.minLevel>0 and tostring(d.minLevel) or "Any").." - "..(d.maxLevel>0 and tostring(d.maxLevel) or "Any")
    return d.name.."\n"..d.location.."\n"..schedule.."\nRegistration closes: "..deadline..
        "\nSingle elimination - Best of "..d.bestOf.."\nPlayers: "..ad.count.." / "..d.capacity..
        "\nLevels: "..levels.."\nRules: "..(d.rules~="" and d.rules or "None specified")
end
local function RefreshTest()
    local p=R.PreviewSnapshot()
    local listings=R.TestListings()
    local id=p and p.event.id
    if id~=lastTestID then feedback="";lastTestID=id end
    local hosting=p and p.role=="host"
    local player=p and p.role=="player"
    hostTest:SetShown(not not hosting)
    local canCreate=R.CanCreatePreview()
    manage:SetShown(canCreate);eventRules:SetShown(canCreate);draftFooter:SetShown(canCreate)
    if p or listings then subtitle:SetText("LOCAL TEST - Nothing is published online") end
    listRow:SetShown(not not (player and p.events[1]))
    openCatalog:SetShown(not p and not listings)
    for i,b in ipairs(catalogRows) do
        local ad=listings and listings[i]
        b:SetShown(ad~=nil)
        if ad then
            b.label:SetText((i==selectedListing and "> " or "")..ad.draft.name.."  "..ad.count.."/"..ad.draft.capacity)
        end
    end
    join:SetShown(not not (listings and listings[selectedListing] or player and p.events[1] and not p.member))
    browseHost:SetShown(not not (player and not p.mode))
    watch:SetShown(not not listings)
    local started=p and p.bracket~=nil
    check:SetShown(not not (player and p.member and not started and not p.member.checkedIn))
    advance:SetShown(not not (player and p.member and not started and p.now<p.event.draft.startAt-1800))
    leave:SetShown(not not (player and p.member and not started))
    matchNotice:SetShown(not not (player and p.match))
    hostStart:SetShown(not not (hosting and not started))
    hostStart:SetEnabled(not not (hosting and not started and (p.mode=="host" and p.event.count>=2 or p.member and p.member.checkedIn)))
    hostPlayer:SetShown(not not (hosting and not p.mode))
    hostFill:SetShown(not not (hosting and p.mode=="host" and not started and p.event.count<p.event.draft.capacity))
    hostSim:SetShown(not not (hosting and started and p.bracket.state=="running"))
    sampleStart:SetShown(not not (player and p.mode=="join" and not started and p.member and p.member.checkedIn))
    sampleGame:SetShown(not not (player and started and p.bracket.state=="running"))
    bracketGame:SetShown(not not (started and p.bracket.state=="running"))
    broadcast:SetShown(not not (started and p.bracket.state=="running"))
    local fixtureReady=started and p.bracket.state=="running" and p.selected
    local busy=started and (p.demo or p.offline)
    hostSim:SetEnabled(not busy);sampleGame:SetEnabled(not busy)
    broadcast:SetEnabled(not busy)
    testDisconnect:SetShown(not not (fixtureReady and not p.demo and not p.offline))
    testAdvance:SetShown(not not (fixtureReady and p.offline))
    testReconnect:SetShown(not not (fixtureReady and p.offline))
    bracketGame:SetEnabled(not not (fixtureReady and not p.demo and not p.offline))
    if started then broadcast.label:SetText(p.broadcast and "Exit broadcast" or "Broadcast view") end
    local feature=hosting and started and p.bracket.state=="running" and p.readyCount>1
    featurePrev:SetShown(not not feature);featureNext:SetShown(not not feature)
    featurePrev:SetEnabled(not busy);featureNext:SetEnabled(not busy)
    myHost:SetShown(not not (player and not p.mode))
    if not started and bracketView and not (ns.TournamentSession and ns.TournamentSession.IsActive() and ns.TournamentSession.GetProjection()) then bracketView.Hide() end
    if hosting then
        local model=ns.TournamentHUD.Project(p)
        hostSummary:SetText(Describe(p.event)..(model and model.matchID and "\n\nFeatured: "..model.left.." vs "..model.right or ""))
        local lines={"Registered participants"}
        for _,r in ipairs(p.roster) do lines[#lines+1]=r.name.." - Level "..r.level..(r.checkedIn and " - Checked in" or " - Registered") end
        if #p.roster==0 then lines[#lines+1]="No registered participants." end
        hostRoster:SetText(table.concat(lines,"\n")..(feedback~="" and "\n"..feedback or ""))
        if p.bracket and p.bracket.champion then
            hostSummary:SetText(Describe(p.event).."\n\nSimulated champion: "..(p.names[p.bracket.champion] or "Unknown"))
        end
    end
    if player then
        local ad=p.events[1]
        list.detail:SetText(ad and "" or "No open test tournaments.")
        list.note:SetText("Local rehearsal only. Real discovery is not active.")
        if ad then
            listRowText:SetText(ad.draft.name.."  -  "..ad.count.." / "..ad.draft.capacity)
            info.detail:SetText(Describe(ad).."\nOrganizer: "..ad.organizer.."\n"..feedback)
        else info.detail:SetText("Registration is closed for this test event. Return to the organizer.") end
        if p.match then
            local m=p.match
            myPanel.detail:SetText("LOCAL TEST - No real duel or rating changes\n\n"..p.event.draft.name.."\n"..
                (m.round==m.roundCount and "Final" or "Round "..m.round).." - Best of "..m.bestOf.."\n\n"..
                "Your next opponent\n"..m.opponent.."\n\nSeries score: "..m.score.." - "..m.opponentScore..
                "\n\nMatch ready - local rehearsal only.\n"..feedback)
        elseif p.member then
            local summary=p.bracket and (p.bracket.champion and "Simulated champion: "..(p.names[p.bracket.champion] or "Unknown") or p.state=="eliminated" and "Eliminated - follow the remaining matches." or "Waiting for the next match.") or (p.member.checkedIn and "Checked in" or "Registered")
            myPanel.detail:SetText(Describe(p.event).."\n"..summary.."\n"..feedback)
        end
    elseif listings then
        local ad=listings[selectedListing]
        list.detail:SetText("")
        list.note:SetText("Local test tournaments only. Choose a tournament to inspect or join.")
        info.detail:SetText(Describe(ad).."\nOrganizer: "..ad.organizer.."\n"..feedback)
    else
        list.detail:SetText("No tournaments discovered.")
        list.note:SetText("Tournament discovery is not active yet.")
        info.detail:SetText(feedback~="" and feedback or "Select a tournament to view its details and rules.")
        myPanel.detail:SetText("No active tournament.")
    end
    return p
end
local function MaxScroll() return math.max(0,canvas:GetHeight()-scroll:GetHeight()) end
local function SetOffset(v)
    scroll:SetVerticalScroll(math.max(0,math.min(MaxScroll(),tonumber(v) or 0)))
end
local bar=W.ScrollBar(root,function()
    return scroll:GetHeight(),canvas:GetHeight(),scroll:GetVerticalScroll()
end,SetOffset)
bar:ClearAllPoints()
bar:SetPoint("TOPLEFT",scroll,"TOPRIGHT",4,0);bar:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",4,0)
local function LayoutBrowse(w,wide,top,p,listings)
    local height
        local h=math.max((p or listings) and 490 or 250,scroll:GetHeight()-top)
        if wide then
            local left=math.floor((w-12)*.53)
            Place(list,browse,0,0,left,h);Header(list,left)
            Place(info,browse,left+12,0,w-left-12,h);Header(info,w-left-12)
            TextAt(list.detail,list,12,60,left-24,60)
            TextAt(list.note,list,12,122,left-24,52)
            TextAt(info.detail,info,12,60,w-left-36,90)
            Place(openCatalog,list,12,180,left-24,30)
            if listings then
                for i,b in ipairs(catalogRows) do Place(b,list,12,48+(i-1)*40,left-24,34) end
                TextAt(list.note,list,12,216,left-24,58)
                TextAt(info.detail,info,12,48,w-left-36,h-100)
                Place(join,info,12,h-76,w-left-36,28)
                Place(watch,info,12,h-40,w-left-36,28)
            elseif p then
                Place(listRow,list,12,48,left-24,46)
                TextAt(info.detail,info,12,48,w-left-36,h-132)
                Place(join,info,12,h-76,w-left-36,28)
                Place(browseHost,info,12,h-40,w-left-36,28)
            end
            height=h
        else
            local listH=listings and 288 or 232
            Place(list,browse,0,0,w,listH);Header(list,w)
            TextAt(list.detail,list,12,60,w-24,60);TextAt(list.note,list,12,122,w-24,52)
            Place(openCatalog,list,12,184,w-24,30)
            local infoH=(p or listings) and 490 or 190
            Place(info,browse,0,listH+12,w,infoH);Header(info,w)
            TextAt(info.detail,info,12,48,w-24,(p or listings) and 350 or 100)
            if listings then
                for i,b in ipairs(catalogRows) do Place(b,list,12,48+(i-1)*40,w-24,34) end
                TextAt(list.note,list,12,216,w-24,58)
                Place(join,info,12,infoH-76,w-24,28)
                Place(watch,info,12,infoH-40,w-24,28)
            elseif p then
                Place(listRow,list,12,48,w-24,46)
                Place(join,info,12,infoH-76,w-24,28)
                Place(browseHost,info,12,infoH-40,w-24,28)
            end
            height=listH+12+infoH
        end
    return height
end
local function LayoutOverview(w,p,listings,private)
    local privateActive=private and private.active
    local projection=p or (privateActive and ns.TournamentSession.GetOverviewProjection()) or nil
    if privateActive then subtitle:SetText("PRIVATE NETWORK TEST - No rating changes") end
    if not overviewView then overviewView=ns.TournamentOverview.New(overview,OverviewAction) end
    local model=ns.TournamentOverview.Project(projection,listings~=nil)
    local function Can(action)
        if not action then return false end
        if privateActive and (action=="details" or action=="manage" or action=="checkin") then return true end
        if action=="checkin" then return projection and projection.member and not projection.member.checkedIn end
        if action=="details" then return T.IsPageAvailable("my-tournament") end
        return T.IsPageAvailable(action)
    end
    local height=overviewView.Show(model,w,Can,p~=nil or listings~=nil,U.RefreshActive)
    privateControlsTop=nil
    if private then
        privateControlsTop=height+12
        height=privateControlsTop+LayoutPrivate(private,w,privateControlsTop)
    end
    return height
end
local function Layout()
    local w=math.max(1,scroll:GetWidth()-1)
    subtitle:SetWidth(math.max(1,root:GetWidth()-170))
    local wide=w>=640
    local height
    local p=RefreshTest()
    local listings=R.TestListings()
    local private=ns.TournamentSession and ns.TournamentSession.GetControlModel()
    local privateProjection=private and private.active and ns.TournamentSession.GetProjection()
    if privatePanel then privatePanel:Hide() end
    if privateBack then privateBack:Hide() end
    if p or listings then communityNote:SetText("Local test only. Community settings are automatically detected.") end
    local showCommunity=active=="host" or active=="manage" or active=="browse" or active=="my-tournament" or active=="brackets"
    community:SetShown(showCommunity)
    local top=showCommunity and LayoutCommunity(w) or 0
    if active and pages[active] then
        local page=pages[active]
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT",canvas,"TOPLEFT",0,-top)
        page:SetPoint("BOTTOMRIGHT",canvas,"BOTTOMRIGHT",0,0)
    end
    if active~="overview" and overviewView then overviewView.Hide() end
    if active=="overview" then
        height=LayoutOverview(w,p,listings,private)
    elseif active=="brackets" and privateProjection then
        local h=math.max(320,scroll:GetHeight()-top)
        Place(bracketPanel,brackets,0,0,w,h);Header(bracketPanel,w)
        if not bracketView then bracketView=ns.BracketView.New(bracketPanel) end
        bracketPanel.detail:SetShown(not bracketView.Show(privateProjection,w,h-40))
        bracketPanel.detail:SetText("Organizer bracket snapshot unavailable.")
        TextAt(bracketPanel.detail,bracketPanel,20,54,w-40,h-90)
        if not privateBack then privateBack=Action(bracketPanel,"Tournament controls",function()Switch("overview")end) end
        Place(privateBack,bracketPanel,12,h-34,w-24,28);privateBack:Show()
        subtitle:SetText("PRIVATE NETWORK TEST - Organizer snapshot")
        height=h
    elseif active=="browse" then
        height=LayoutBrowse(w,wide,top,p,listings)
    elseif active=="host" then
        height=LayoutHost(w)
    elseif active=="manage" then
        if p and p.role=="host" then
            local rosterH=math.max(120,24*(#p.roster+2))
            local y=340+rosterH
            height=y+(p.bracket and p.readyCount>1 and 158 or 122)
            Place(hostTest,organizer,0,0,w,height);Header(hostTest,w)
            TextAt(hostSummary,hostTest,12,44,w-24,280)
            hostRoster:SetJustifyV("TOP")
            TextAt(hostRoster,hostTest,12,332,w-24,rosterH)
            Place(hostStart,hostTest,12,y,w-24,28)
            Place(hostSim,hostTest,12,y,w-24,28)
            Place(hostFill,hostTest,12,y+36,w-24,28)
            Place(hostPlayer,hostTest,12,y+36,w-24,28)
            Place(hostCancel,hostTest,12,y+72,w-24,28)
            local half=math.max(1,(w-30)/2)
            Place(featurePrev,hostTest,12,y+108,half,28)
            Place(featureNext,hostTest,18+half,y+108,half,28)
        else height=1 end
    else
        local f=active=="champions" and archive or active=="my-tournament" and myPanel or bracketPanel
        if active and f then
            local h=math.max(200,scroll:GetHeight()-top)
            Place(f,pages[active],0,0,w,h);Header(f,w)
            if p and active=="my-tournament" then
                h=math.max(h,550);Place(f,pages[active],0,0,w,h)
                TextAt(f.detail,f,12,44,w-24,h-196)
                Place(matchNotice,f,12,h-72,w-24,28)
                Place(sampleStart,f,12,h-108,w-24,28)
                Place(sampleGame,f,12,h-36,w-24,28)
                Place(advance,f,12,h-144,w-24,28)
                Place(check,f,12,h-108,w-24,28)
                Place(leave,f,12,h-72,w-24,28)
                Place(myHost,f,12,h-36,w-24,28)
            elseif active=="brackets" and p and p.bracket then
                h=math.max(h,320);Place(f,pages[active],0,0,w,h)
                -- Board remains above the separate fixture controls.
                local bw=math.max(1,(w-36)/3)
                Place(bracketGame,bracketPanel,12,h-34,bw,26)
                Place(broadcast,bracketPanel,18+bw,h-34,bw,26)
                Place(testDisconnect,bracketPanel,24+2*bw,h-34,bw,26)
                Place(testAdvance,bracketPanel,12,h-64,bw,26)
                Place(testReconnect,bracketPanel,18+bw,h-64,bw,26)
                if not bracketView then bracketView=ns.BracketView.New(bracketPanel) end
                f.detail:SetShown(not bracketView.Show(p,w,h-68))
                f.detail:SetText("Bracket unavailable.")
                TextAt(f.detail,f,20,54,w-40,h-68)
            else
                if active=="brackets" then
                    if bracketView then bracketView.Hide() end
                    f.detail:SetText("No tournament bracket available.");f.detail:Show()
                end
                TextAt(f.detail,f,20,54,w-40,100)
            end
            height=h
        end
    end
    canvas:SetSize(w,math.max(1,(height or 1)+top))
    SetOffset(scroll:GetVerticalScroll())
    bar:Refresh()
end
function U.Show(key)
    if active=="host" and key~="host" then W.CloseChoices() end
    if not key then
        if bracketView then bracketView.Hide() end
        if overviewView then overviewView.Hide() end
        privateConfirm=nil
        active=nil;root:Hide();return
    end
    if not T.IsPageAvailable(key) then key="overview" end
    if key~="brackets" and bracketView then bracketView.Hide() end
    active=key
    RefreshCommunity()
    if key=="host" then refreshSchedule() end
    for k,f in pairs(pages) do f:SetShown(k==active) end
    local snapshot=T.GetSnapshot()
    local client=snapshot.client
    local modeNames={normal="PvE",pvp="PvP",rp="RP",["rp-pvp"]="RP-PvP",hardcore="Hardcore"}
    local label=client=="retail" and "Retail" or client=="forever" and "Forever" or "Unavailable"
    if snapshot.region then label=label.." "..snapshot.region else label=label.." (region unavailable)" end
    if client=="forever" then label=label.." / "..(modeNames[snapshot.ruleset] or "ruleset unavailable") end
    subtitle:SetText("1v1 world duels  |  "..label)
    root:Show();SetOffset(0);Layout()
end
function U.RefreshActive()
    if active and root:IsShown() then Layout() end
end
function U.GetPageScroll() return scroll:GetVerticalScroll() end
function U.SetPageScroll(_,offset) SetOffset(offset);bar:Refresh() end
scroll:SetScript("OnMouseWheel",function(_,d)
    if active=="host" then W.CloseChoices() end
    SetOffset(scroll:GetVerticalScroll()-d*42);bar:Refresh()
end)
scroll:HookScript("OnSizeChanged",function()
    if active=="host" then W.CloseChoices() end
    if active then Layout() end
end)
root:HookScript("OnShow",function() if active then RefreshCommunity();Layout() end end)

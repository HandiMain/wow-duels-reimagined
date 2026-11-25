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
local browseView
local host=Page("host")
local hostView
local function LayoutHost(w)
    if not R.CanCreatePreview() then
        if hostView then hostView.Hide() end
        return 1
    end
    if not hostView then
        hostView=ns.TournamentHost.New(host,{
            refreshCommunity=RefreshCommunity,
            published=function()
                if not (ns.Navigation and ns.Navigation.SelectKey("tournaments","manage")) then U.Show("manage") end
            end})
    end
    return hostView.Show(w,Population.GetCurrent(),displayedKey)
end
local championPage=Page("champions")
local archive=Panel(championPage,"Hall of Champions")
archive.detail=Label(archive,"No completed tournaments recorded.",15,C.muted,"CENTER")
local mine=Page("my-tournament")
local myView
local brackets=Page("brackets")
local bracketPanel=Panel(brackets,"Brackets")
bracketPanel.detail=Label(bracketPanel,"No tournament bracket available.",15,C.muted,"CENTER")
local bracketView
-- Explicit rehearsal views. Normal browsing never contains test events.
local organizer=Page("manage")
local organizerView

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
local bracketGame=Action(bracketPanel,"Simulate Next Game",function()Run("simulate-game")end)
local broadcast=Action(bracketPanel,"Broadcast view",function()Run("broadcast")end)
local testDisconnect=Action(bracketPanel,"Test disconnect",function()Run("disconnect")end)
local testAdvance=Action(bracketPanel,"Advance test 1 min",function()Run("advance-grace")end)
local testReconnect=Action(bracketPanel,"Test reconnect",function()Run("reconnect")end)
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
    local canCreate=R.CanCreatePreview()
    if hostView and not canCreate then hostView.Hide() end
    if p or listings then subtitle:SetText("LOCAL TEST - Nothing is published online") end
    local started=p and p.bracket~=nil
    bracketGame:SetShown(not not (started and p.bracket.state=="running"))
    broadcast:SetShown(not not (started and p.bracket.state=="running"))
    local fixtureReady=started and p.bracket.state=="running" and p.selected
    local busy=started and (p.demo or p.offline)
    broadcast:SetEnabled(not busy)
    testDisconnect:SetShown(not not (fixtureReady and not p.demo and not p.offline))
    testAdvance:SetShown(not not (fixtureReady and p.offline))
    testReconnect:SetShown(not not (fixtureReady and p.offline))
    bracketGame:SetEnabled(not not (fixtureReady and not p.demo and not p.offline))
    if started then broadcast.label:SetText(p.broadcast and "Exit broadcast" or "Broadcast view") end
    if not started and bracketView and not (ns.TournamentSession and ns.TournamentSession.IsActive() and ns.TournamentSession.GetProjection()) then bracketView.Hide() end
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
local function BrowseAction(kind,entry)
    if kind=="open" then
        local ok,why=R.OpenTestCatalog();feedback=why or "";U.Show("browse");return
    end
    if not entry then return end
    local listings=R.TestListings()
    if listings then
        local ad=listings[entry.index]
        if not ad or ad.id~=entry.id or ad.revision~=entry.ad.revision then feedback="Tournament details changed. Select it again.";U.RefreshActive();return end
        local ok,why
        if kind=="join" then ok,why=R.JoinTestListing(entry.index)
        elseif kind=="bracket" then ok,why=R.WatchTestListing(entry.index) end
        feedback=why or ""
        if ok then Switch(kind=="join" and "my-tournament" or "brackets") else U.RefreshActive() end
        return
    end
    local p=R.PreviewSnapshot()
    if not p or p.event.id~=entry.id or p.event.revision~=entry.ad.revision then return end
    if kind=="join" and p.role=="player" and not p.member then Run("join","my-tournament")
    elseif kind=="bracket" and p.bracket then Switch("brackets")
    elseif kind=="bracket" and p.role=="player" and not p.mode then Run("host","manage") end
end
local function LayoutBrowse(w,p,listings)
    if not browseView then browseView=ns.TournamentBrowse.New(browse,BrowseAction,U.RefreshActive) end
    local rows=listings or (p and p.role=="player" and p.events) or {}
    return browseView.Show({rows=rows,now=listings and R.TestCatalogTime() or p and p.now,
        scope=Population.GetCurrent(),catalog=listings~=nil,preview=p~=nil,
        canJoin=listings~=nil or p and p.role=="player" and not p.member,
        organizer=p and p.role=="player" and not p.mode,hasBracket=p and p.bracket~=nil,
        canOpenTest=not p and not listings and R.CanCreatePreview(),feedback=feedback,
        context=listings and "catalog" or p and p.event.id or "empty"},w)
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
    local showCommunity=active=="brackets"
    community:SetShown(showCommunity)
    local top=showCommunity and LayoutCommunity(w) or 0
    if active and pages[active] then
        local page=pages[active]
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT",canvas,"TOPLEFT",0,-top)
        page:SetPoint("BOTTOMRIGHT",canvas,"BOTTOMRIGHT",0,0)
    end
    if active~="overview" and overviewView then overviewView.Hide() end
    if active~="browse" and browseView then browseView.Hide() end
    if active~="host" and hostView then hostView.Hide() end
    if active~="manage" and organizerView then organizerView.Hide() end
    if active~="my-tournament" and myView then myView.Hide() end
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
        height=LayoutBrowse(w,p,listings)
    elseif active=="host" then
        height=LayoutHost(w)
    elseif active=="my-tournament" then
        if p and p.role=="player" and p.member then
            if not myView then
                myView=ns.TournamentPlayer.New(mine,{
                    refresh=U.RefreshActive,
                    action=function(command)
                        if command=="brackets" then Switch("brackets")
                        elseif command=="leave" then Run("leave","browse")
                        elseif command=="host" then Run("host","manage")
                        elseif command=="start-bracket" or command=="simulate-game" then Run(command,"brackets")
                        elseif command=="notice" then
                            local ok,why=ns.Notifications.PreviewTournamentReady()
                            feedback=ok and "Match notification shown." or why or "Notification unavailable."
                            U.RefreshActive()
                        else Run(command) end
                    end,
                    profile=function()
                        local current=R.PreviewSnapshot()
                        if current and current.role=="player" and current.opponent then
                            ns.CompetitiveUI.OpenTournamentPlayerCard(current.opponent,current.event.draft.name,current.scope)
                        end
                    end,
                })
            end
            height=myView.Show(p,w,Population.GetCurrent(),feedback)
        else
            if myView then myView.Hide() end
            height=1
        end
    elseif active=="manage" then
        if p and p.role=="host" then
            if not organizerView then
                organizerView=ns.TournamentOrganizer.New(organizer,{
                    refresh=U.RefreshActive,
                    action=function(command)
                        if command=="brackets" then Switch("brackets")
                        elseif command=="player" then
                            local current=R.PreviewSnapshot()
                            if current then Run("player",current.member and "my-tournament" or "browse") end
                        elseif command=="cancel" then Run("cancel","host")
                        elseif command=="start-bracket" or command=="simulate-game" then Run(command,"brackets")
                        else Run(command) end
                    end,
                    profile=function(row)
                        local current=R.PreviewSnapshot()
                        if not current or current.role~="host" then return end
                        for _,member in ipairs(current.roster or {}) do
                            if member.guid==row.guid then
                                ns.CompetitiveUI.OpenTournamentPlayerCard(member,current.event.draft.name,current.scope)
                                return
                            end
                        end
                    end,
                })
            end
            height=organizerView.Show(p,w,Population.GetCurrent(),feedback)
        else
            if organizerView then organizerView.Hide() end
            height=1
        end
    else
        local f=active=="champions" and archive or bracketPanel
        if active and f then
            local h=math.max(200,scroll:GetHeight()-top)
            Place(f,pages[active],0,0,w,h);Header(f,w)
            if active=="brackets" and p and p.bracket then
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
    if (active=="host" or active=="browse" or active=="manage") and key~=active then W.CloseChoices() end
    if not key then
        if bracketView then bracketView.Hide() end
        if overviewView then overviewView.Hide() end
        if browseView then browseView.Hide() end
        if hostView then hostView.Hide() end
        if organizerView then organizerView.Hide() end
        if myView then myView.Hide() end
        privateConfirm=nil
        active=nil;root:Hide();return
    end
    if not T.IsPageAvailable(key) then key="overview" end
    if key~="brackets" and bracketView then bracketView.Hide() end
    active=key
    RefreshCommunity()
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
    if active=="host" or active=="browse" or active=="manage" then W.CloseChoices() end
    SetOffset(scroll:GetVerticalScroll()-d*42);bar:Refresh()
end)
scroll:HookScript("OnSizeChanged",function()
    if active=="host" or active=="browse" or active=="manage" then W.CloseChoices() end
    if active then Layout() end
end)
root:HookScript("OnShow",function() if active then RefreshCommunity();Layout() end end)

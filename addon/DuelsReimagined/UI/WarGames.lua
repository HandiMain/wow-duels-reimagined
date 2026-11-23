local _, ns = ...
-- Retail-only War Games view; Core/WarGames is the sole gameplay/API owner.
local Style, Chrome, Window = ns.Style, ns.Chrome, ns.Window
local Engine, Widgets = ns.WarGames, ns.Widgets
local C = Style.color
local View = {}
ns.WarGamesUI = View

local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:Hide()
local active = "player"
local unsubscribe
local openMenu
local messages = {}

-- Reuse the same house icon atlas as Navigation and Addon Status.
local symbol = Chrome.Icon(root, "Hall")
symbol:SetSize(37, 37)
symbol:SetPoint("TOPLEFT", root, "TOPLEFT", 24, -16)
local title = Style.Text(root, "WAR GAMES", 28, C.pale, nil, "display")
title:SetPoint("TOPLEFT", root, "TOPLEFT", 70, -16)
local tagline = Style.Text(root,
    "Private arena challenges and spectating  |  Retail only", 13, C.text)
tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 25, -147)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -30, 14)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(850, 485)
scroll:SetScrollChild(canvas)
local function Panel(y, height, heading)
    local frame = CreateFrame("Frame", nil, canvas)
    frame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -y)
    frame:SetSize(800, height)
    Style.Skin(frame, C.body, {corner=9, edge=C.goldDim,
        light=C.goldDim, dark=C.window, shade=0.12, shine=0.11, rim=0.82})
    local label = Style.Text(frame, heading, 19, C.pale, nil, "display")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -11)
    local headingRule = Style.Fill(frame, C.goldDim, "BORDER")
    headingRule:ClearAllPoints()
    headingRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -43)
    headingRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -17, -43)
    headingRule:SetHeight(1)
    headingRule:SetAlpha(0.52)
    frame.heading = label
    return frame
end
local function Text(parent, caption, x, y, size, color)
    local s = Style.Text(parent, caption, size or 13, color or C.text)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    s:SetWordWrap(false)
    return s
end
local function Action(parent, caption, width, height)
    local b = Style.Action(parent, caption, "footer", {
        fill=C.button, edge=C.gold, light=C.goldDim,
        dark=C.window, hover=C.selected, text=C.pale,
    })
    b:SetSize(width, height)
    return b
end
local function Small(parent, caption, width)
    local b = Style.Action(parent, caption, "footer", {
        fill=C.nav, edge=C.goldDim, light=C.goldDim,
        dark=C.window, hover=C.selected, text=C.text,
    })
    b:SetSize(width, 30)
    return b
end

-- Reuse the exact Options font-menu controls and virtual scrolling.
-- The popup owner lives in Widgets; this page only supplies real choices.
local function CaptainPicker(parent, slot, page)
    local button=Widgets.ChoiceControl(parent, 235)
    ns.Tooltips.Bind(button, {
        title="Battle.net captain",
        detail="Choose a Battle.net friend. Online dots are shown only when Blizzard reports their status.",
    })
    button:SetScript("OnClick",function(self)
        local entries={
            {key=0, label="Clear captain", detail="Leave this team captain unselected."},
        }
        local friends=Engine.GetFriends()
        for _, friend in ipairs(friends) do
            entries[#entries+1]={
                key=friend.id, label=friend.displayName,
                online=friend.online, onlineSource=friend.onlineSource,
            }
        end
        if #friends==0 then
            entries[#entries+1]={
                key=-1,label="No Battle.net friends available",disabled=true,
                detail="Add a Battle.net friend before choosing a captain.",
            }
        end
        local cfg=Engine.GetConfig(page)
        local id=page=="player" and cfg.captain or
            slot==1 and cfg.captain1 or cfg.captain2
        Widgets.OpenChoices(self, entries, id or 0, function(key)
            local captainID=key
            if captainID==0 then captainID=nil end
            Engine.SelectCaptain(page,slot,captainID)
        end)
    end)
    return button
end

-- Panels belong to canvas and are hidden as a set when the page switches.
local playerSetup = Panel(0,258,"YOUR TEAM")
local playerForm = Panel(0,252,"MATCH SETUP")
local hostForm = Panel(0,236,"HOST / SPECTATE")
local hostStatus = Panel(0,76,"MATCH STATUS")
local arenaStatus = Panel(0,76,"MATCH STATUS")
local playerTeam = Panel(0,300,"YOUR TEAM")
local enemyTeam = Panel(0,300,"ENEMY TEAM")
local hostTeam1 = Panel(0,258,"TEAM 1  •  5 FIGHTERS")
local hostTeam2 = Panel(0,258,"TEAM 2  •  5 FIGHTERS")
-- Neutral, distinct dark metallic bands; never faction artwork.
local function TeamBand(panel, tone)
    local band = Style.Fill(panel, tone, "BACKGROUND")
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT",panel,"TOPLEFT",2,-2)
    band:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-2,-2)
    band:SetHeight(40)
    band:SetAlpha(0.60)
    panel.heading:ClearAllPoints()
    panel.heading:SetPoint("TOP",panel,"TOP",0,-11)
    panel.heading:SetJustifyH("CENTER")
end
TeamBand(hostTeam1, C.selected)
TeamBand(hostTeam2, C.track)
local vs = Style.Text(canvas,"VS",28,C.gold,nil,"display")
local matchHint = Text(arenaStatus,
    "Only information revealed by Blizzard is shown.",18,47,12,C.muted)
local waiting = Text(hostStatus,
    "Spectator rosters remain unknown until verified.",18,47,12,C.muted)
local msgPlayer = Text(playerForm,"",18,226,12,C.muted)
msgPlayer:SetPoint("TOPRIGHT",playerForm,"TOPRIGHT",-18,-226)
local msgHost = Text(hostForm,"",18,207,12,C.muted)
msgHost:SetPoint("TOPRIGHT",hostForm,"TOPRIGHT",-18,-207)
msgHost:SetJustifyH("CENTER")
msgHost:SetWordWrap(true)
local statusDivider = Style.Fill(hostForm, C.goldDim, "BORDER")
statusDivider:ClearAllPoints()
statusDivider:SetPoint("TOPLEFT",hostForm,"TOPLEFT",18,-193)
statusDivider:SetPoint("TOPRIGHT",hostForm,"TOPRIGHT",-18,-193)
statusDivider:SetHeight(1)
statusDivider:SetAlpha(0.65)

-- Engine owns the exact team size; the view is never limited to three.
local function Roster(parent, slots)
    local rows={}
    for i=1,slots do
        local f=CreateFrame("Frame",nil,parent)
        f:SetPoint("TOPLEFT",parent,"TOPLEFT",15,-48-(i-1)*39)
        f:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-15,-48-(i-1)*39)
        f:SetHeight(38)
        local bg=Style.Fill(f,i%2==1 and C.nav or C.body)
        bg:SetAlpha(i%2==1 and 0.83 or 0.45)
        local icon=f:CreateTexture(nil,"ARTWORK")
        icon:SetSize(25,25)
        icon:SetPoint("LEFT",f,"LEFT",7,0)
        Chrome.Sharp(icon)
        local name=Style.Text(f,"Awaiting player...",13,C.muted)
        name:SetPoint("LEFT",icon,"RIGHT",12,0)
        local role
        if parent==hostTeam1 or parent==hostTeam2 then
            role=Style.Text(f,"CAPTAIN",11,C.gold)
            role:SetPoint("RIGHT",f,"RIGHT",-11,0)
            role:Hide()
            name:SetPoint("RIGHT",role,"LEFT",-8,0)
        else
            name:SetPoint("RIGHT",f,"RIGHT",-9,0)
        end
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        rows[i]={frame=f,icon=icon,name=name,role=role}
    end
    return rows
end
local setupRows = Roster(playerSetup,5)
local ownArenaRows = Roster(playerTeam,5)
local enemyRows = Roster(enemyTeam,5)
local hostRows1 = Roster(hostTeam1,5)
local hostRows2 = Roster(hostTeam2,5)

local function SetRow(row, info, placeholder)
    local name = info and info.name
    local class = info and info.classFile
    row.name:SetText(name or placeholder or "Awaiting player...")
    local c=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then row.name:SetTextColor(c.r,c.g,c.b)
    elseif name then row.name:SetTextColor(unpack(C.text))
    else row.name:SetTextColor(unpack(C.muted)) end
    local uv = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if uv then
        row.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        row.icon:SetTexCoord(unpack(uv))
    else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetTexCoord(0,1,0,1)
    end
end
local function FillRows(rows, members, size, placeholder)
    for i,row in ipairs(rows) do
        row.frame:SetShown(i<=size)
        if i<=size then
            local member=members and members[i]
            SetRow(row,member,placeholder)
            if row.role then row.role:SetShown(i==1 and member~=nil) end
        end
    end
end

local playerTeamInfo = Text(playerSetup,"Blizzard party / raid roster",18,19,12,C.muted)
playerTeamInfo:ClearAllPoints()
playerTeamInfo:SetPoint("TOPRIGHT",playerSetup,"TOPRIGHT",-18,-19)
playerTeamInfo:SetJustifyH("RIGHT")
local playerBrackets={}
local hostBrackets={}
local function Brackets(parent,page,y,store)
    local heading=Text(parent,"Bracket",19,y,13,C.text)
    for i,bracket in ipairs(Engine.Brackets) do
        local b=Small(parent,bracket.."v"..bracket,76)
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",126+(i-1)*84,-y+6)
        local choiceTint=Style.Fill(b,C.selected,"ARTWORK")
        choiceTint:SetAllPoints(b)
        choiceTint:SetAlpha(0)
        b.choiceTint=choiceTint
        b:SetScript("OnClick",function() Engine.SelectBracket(page,bracket) end)
        store[i]=b
    end
    return heading
end
Brackets(playerForm,"player",53,playerBrackets)
local hostBracketLabel = Brackets(hostForm,"host",63,hostBrackets)
hostBracketLabel:SetText("Match Format")

local playerCaptainLabel=Text(playerForm,"Opposing captain",19,102,13)
local playerCaptain=CaptainPicker(playerForm,1,"player")
playerCaptain:SetPoint("TOPLEFT",playerForm,"TOPLEFT",162,-99)
local playerMapLabel=Text(playerForm,"Arena",19,148,13)
local playerMap = Widgets.ChoiceControl(playerForm,235)
playerMap:SetPoint("TOPLEFT",playerForm,"TOPLEFT",162,-143)
local playerSend=Action(playerForm,"Send Challenge",180,34)
playerSend:SetPoint("TOPLEFT",playerForm,"TOPLEFT",416,-174)

local hostCaptain1Label=Text(hostForm,"Team 1 Captain",17,60,13)
local hostCaptain1=CaptainPicker(hostForm,1,"host")
local hostCaptain2Label=Text(hostForm,"Team 2 Captain",271,60,13)
local hostCaptain2=CaptainPicker(hostForm,2,"host")
local hostMapLabel=Text(hostForm,"Arena",525,60,13)
local hostMap=Widgets.ChoiceControl(hostForm,209)
local hostSend=Action(hostForm,"Request Spectator Match",260,36)
hostSend:SetPoint("TOP",hostForm,"TOP",0,-142)

local function SelectMap(page,anchor)
    local entries={}
    for index, map in ipairs(Engine.GetMaps()) do
        entries[#entries+1]={key=index,label=map.name,
            detail=map.clientReported and "Reported by this Retail client." or
                "Arena reference. Blizzard determines War Game availability."}
    end
    local cfg=Engine.GetConfig(page)
    Widgets.OpenChoices(anchor,entries,cfg and cfg.map,function(index)
        Engine.SelectMap(page,index)
    end)
end
playerMap:SetScript("OnClick",function(self) SelectMap("player",self) end)
hostMap:SetScript("OnClick",function(self) SelectMap("host",self) end)
ns.Tooltips.Bind(playerSend,function()
    return {title="Send Challenge",
        detail=Engine.GetReason("player") or
            "Ask Blizzard to challenge the selected captain's team. Entry is not guaranteed."}
end)
ns.Tooltips.Bind(hostSend,function()
    return {title="Request Spectator Match",
        detail=Engine.GetReason("host") or
            "Ask Blizzard to arrange a match for two team captains. Spectator entry is not guaranteed."}
end)
playerSend:SetScript("OnClick",function()
    local _, reason=Engine.Request("player")
    messages.player=reason
    View.Refresh()
end)
hostSend:SetScript("OnClick",function()
    local _, reason=Engine.Request("host")
    messages.host=reason
    View.Refresh()
end)

-- Reserve a real gutter BEFORE painting panels, not after the scrollbar
-- overlaps them. The full scroll viewport width includes the 12px track
-- and its hit area (and a small visual breathing gap).
local SCROLL_LEFT, SCROLL_RIGHT, SCROLLBAR_GUTTER = 25, 30, 22
local function UsableCanvasWidth()
    -- The first OnShow can precede the ScrollFrame's width propagation.
    -- root is anchored to the already-sized main content, so computing
    -- from its anchors works on first display AND on later resizes.
    local width = root:GetWidth()
    if not width or width < 1 then width = Window.content:GetWidth() end
    return math.max(1, width-SCROLL_LEFT-SCROLL_RIGHT-SCROLLBAR_GUTTER)
end

-- Panel geometry stays inside the usable canvas, whether the track is
-- visible, hidden, or being dragged, at the default or resized window.
local function Position(frame,x,y,w,h)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,-y)
    frame:SetSize(w,h)
end
local function Layout()
    local w=UsableCanvasWidth()
    canvas:SetWidth(w)
    local inArena=Engine.InArena()
    local half=(w-72)/2
    local secondX=w-half
    if active=="player" then
        if inArena then
            Position(playerTeam,0,0,half,258)
            Position(enemyTeam,secondX,0,half,258)
            Position(arenaStatus,0,274,w,78)
            vs:ClearAllPoints()
            vs:SetPoint("CENTER",canvas,"TOP",0,-145)
            canvas:SetHeight(366)
        else
            local size=Engine.GetConfig("player").bracket
            local teamHeight=63+39*size
            Position(playerForm,0,0,w,252)
            Position(playerSetup,0,268,w,teamHeight)
            canvas:SetHeight(280+teamHeight)
            playerSend:ClearAllPoints()
            playerSend:SetPoint("TOP",playerForm,"TOP",0,-185)
        end
    elseif inArena then
        Position(hostTeam1,0,0,half,258)
        Position(hostTeam2,secondX,0,half,258)
        Position(hostStatus,0,274,w,78)
        vs:ClearAllPoints()
        vs:SetPoint("CENTER",canvas,"TOP",0,-145)
        canvas:SetHeight(366)
    else
        Position(hostForm,0,0,w,236)
        -- Four aligned columns prevent labels and captain selectors from
        -- colliding at the default and minimum supported window sizes.
        local gap=12
        local col=(w-36-3*gap)/4
        local x={18,18+col+gap,18+2*(col+gap),18+3*(col+gap)}
        local function At(control,left,top,width)
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT",hostForm,"TOPLEFT",left,-top)
            if width then control:SetWidth(width) end
        end
        At(hostBracketLabel,x[1],60)
        At(hostMapLabel,x[2],60)
        At(hostCaptain1Label,x[3],60)
        At(hostCaptain2Label,x[4],60)
        local bracketWidth=(col-8)/3
        for i,button in ipairs(hostBrackets) do
            At(button,x[1]+(i-1)*(bracketWidth+4),85,bracketWidth)
        end
        At(hostMap,x[2],85,col)
        At(hostCaptain1,x[3],85,col)
        At(hostCaptain2,x[4],85,col)
        Position(hostTeam1,0,253,half,258)
        Position(hostTeam2,secondX,253,half,258)
        vs:ClearAllPoints()
        vs:SetPoint("CENTER",canvas,"TOP",0,-399)
        canvas:SetHeight(524)
    end
    local max=math.max(0,canvas:GetHeight()-scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,math.min(max,scroll:GetVerticalScroll())))
end
local scrollbar=Widgets.ScrollBar(scroll,function()
    return scroll:GetHeight(),canvas:GetHeight(),scroll:GetVerticalScroll()
end,function(offset) scroll:SetVerticalScroll(offset) end)
scroll:SetScript("OnMouseWheel",function(self,delta)
    local max=math.max(0,canvas:GetHeight()-self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max,
        self:GetVerticalScroll()-delta*42)))
    scrollbar:Refresh()
end)
scroll:SetScript("OnVerticalScroll",function() scrollbar:Refresh() end)
scroll:SetScript("OnSizeChanged",function()
    if root:IsShown() then Layout(); scrollbar:Refresh() end
end)
root:HookScript("OnSizeChanged",function()
    if root:IsShown() then Layout(); scrollbar:Refresh() end
end)

function View.Refresh()
    if not root:IsShown() then return end
    local inArena=Engine.InArena()
    local c=Engine.GetConfig(active)
    if not c then return end
    local cfgPlayer=Engine.GetConfig("player")
    local cfgHost=Engine.GetConfig("host")
    for i,button in ipairs(playerBrackets) do
        local chosen=Engine.Brackets[i]==cfgPlayer.bracket
        button.label:SetTextColor(unpack(chosen and C.pale or C.text))
        button.choiceTint:SetAlpha(chosen and 0.48 or 0)
    end
    for i,button in ipairs(hostBrackets) do
        local chosen=Engine.Brackets[i]==cfgHost.bracket
        button.label:SetTextColor(unpack(chosen and C.pale or C.text))
        button.choiceTint:SetAlpha(chosen and 0.48 or 0)
    end
    local playerOther=Engine.GetCaptain("player",1)
    local hostA=Engine.GetCaptain("host",1)
    local hostB=Engine.GetCaptain("host",2)
    playerCaptain.label:SetText(playerOther and playerOther.displayName or
        "Choose opposing captain")
    hostCaptain1.label:SetText(hostA and hostA.displayName or "Team 1 captain")
    hostCaptain2.label:SetText(hostB and hostB.displayName or "Team 2 captain")
    local maps=Engine.GetMaps()
    local selectedPlayerMap=maps[cfgPlayer.map]
    local selectedHostMap=maps[cfgHost.map]
    playerMap.label:SetText(selectedPlayerMap and selectedPlayerMap.name or "Choose arena")
    hostMap.label:SetText(selectedHostMap and selectedHostMap.name or "Choose arena")
    local team=Engine.GetTeam()
    local own=team.complete and not team.stale and team.members or {}
    FillRows(setupRows,own,math.min(5,cfgPlayer.bracket))
    FillRows(ownArenaRows,own,math.min(5,cfgPlayer.bracket))
    FillRows(enemyRows,Engine.GetOpponents(),math.min(5,cfgPlayer.bracket),
        "Awaiting opponent...")
    local first, second = {}, {}
    if hostA then first[1]={name=hostA.displayName} end
    if hostB then second[1]={name=hostB.displayName} end
    FillRows(hostRows1,first,math.min(5,cfgHost.bracket))
    FillRows(hostRows2,second,math.min(5,cfgHost.bracket))
    hostTeam1.heading:SetText("TEAM 1  •  "..cfgHost.bracket.." FIGHTERS")
    hostTeam2.heading:SetText("TEAM 2  •  "..cfgHost.bracket.." FIGHTERS")
    local playerReason=Engine.GetReason("player")
    local hostReason=Engine.GetReason("host")
    playerSend:SetEnabled(not playerReason)
    hostSend:SetEnabled(not hostReason)
    playerSend:SetAlpha(playerReason and 0.48 or 1)
    hostSend:SetAlpha(hostReason and 0.48 or 1)
    msgPlayer:SetText(messages.player or playerReason or
        "Challenge requests require the opposing captain to accept.")
    msgHost:SetText(messages.host or hostReason or
        "Captains and full team lists are not automatically shared with spectators.")
    playerTeamInfo:SetText(team.complete and
        (#team.members.." group members detected") or
        "Group information unavailable")
    waiting:SetText(inArena and
        "In arena. Team rosters are shown only when verified." or
        (messages.host or "Waiting for an arena. Requests do not confirm entry."))
    playerSetup:SetShown(active=="player" and not inArena)
    playerForm:SetShown(active=="player" and not inArena)
    playerTeam:SetShown(active=="player" and inArena)
    enemyTeam:SetShown(active=="player" and inArena)
    arenaStatus:SetShown(active=="player" and inArena)
    hostForm:SetShown(active=="host" and not inArena)
    hostTeam1:SetShown(active=="host")
    hostTeam2:SetShown(active=="host")
    hostStatus:SetShown(active=="host" and inArena)
    vs:SetShown(inArena or active=="host")

    Layout()
    scrollbar:Refresh()
end
local function Visible(tab)
    if active~=tab then Widgets.CloseChoices() end
    active=tab
    root:Show()
    View.Refresh()
end
function View.Show(tab)
    if tab~="player" and tab~="host" then root:Hide(); return end
    Visible(tab)
end
function View.GetPageScroll() return scroll:GetVerticalScroll() end
function View.SetPageScroll(_,value)
    if type(value)~="number" then value=0 end
    scroll:SetVerticalScroll(math.max(0,value))
    scrollbar:Refresh()
end
root:SetScript("OnShow",function()
    if not unsubscribe then unsubscribe=Engine.Subscribe(View.Refresh) end
    Engine.Refresh()
    -- One single next-frame reflow resolves first-show order where anchors
    -- are not yet measured. No timers loop or stay active while hidden.
    if C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(0,function()
            if root:IsShown() then Layout(); scrollbar:Refresh() end
        end)
    end
end)
root:SetScript("OnHide",function()
    if unsubscribe then unsubscribe(); unsubscribe=nil end
    Widgets.CloseChoices()
    ns.Tooltips.Hide(nil,true)
end)
ns.Search.Register("wargames:challenge","Send War Game Challenge",
    "War Games","Prepare a private arena match for your group",
    function() if ns.Navigation then ns.Navigation.SelectKey("wargames","player") end end,
    function() return ns.Client.IsRetail() end)
ns.Search.Register("wargames:spectate","Host / Spectate War Game",
    "War Games","Choose two captains and arrange a spectator War Game",
    function() if ns.Navigation then ns.Navigation.SelectKey("wargames","host") end end,
    function() return ns.Client.IsRetail() end)

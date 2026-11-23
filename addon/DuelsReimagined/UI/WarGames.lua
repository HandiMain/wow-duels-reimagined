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

local symbol = root:CreateTexture(nil, "ARTWORK")
symbol:SetTexture("Interface\\Icons\\Achievement_Arena_2v2_7")
symbol:SetSize(37, 37)
symbol:SetPoint("TOPLEFT", root, "TOPLEFT", 24, -16)
local title = Style.Text(root, "WAR GAMES", 28, C.pale, nil, "display")
title:SetPoint("TOPLEFT", root, "TOPLEFT", 70, -16)
local tagline = Style.Text(root, "Private arena challenges and spectating  |  Retail only", 13, C.text)
tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
local retail = Style.Text(root, "RETAIL ONLY", 12, C.gold)
retail:SetPoint("TOPRIGHT", root, "TOPRIGHT", -25, -24)
local rule = Chrome.Divider(root, 800, 14)
rule:SetPoint("TOPLEFT", root, "TOPLEFT", 23, -125)
rule:SetPoint("TOPRIGHT", root, "TOPRIGHT", -23, -125)

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

-- One short-lived chooser, owned by this page. It creates no Blizzard menus,
-- focus-stealing EditBoxes or permanent updates, and works for many friends.
local menu = CreateFrame("Frame", nil, root)
menu:SetSize(270, 220)
menu:SetFrameLevel(root:GetFrameLevel()+28)
Style.Skin(menu, C.nav, { corner=8, edge=C.gold, rim=0.96 })
menu:Hide()
local choices = {}
local menuPrev = Small(menu, "Previous", 112)
menuPrev:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 13, 10)
local menuNext = Small(menu, "Next", 112)
menuNext:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -13, 10)
local choicePage, choiceItems, chosen
local function DrawChoices()
    local start = (choicePage-1)*5
    for i=1,5 do
        local b = choices[i]
        local item = choiceItems[start+i]
        if item then
            b.label:SetText(item.label)
            b.item = item
            b:Show()
        else
            b:Hide()
        end
    end
    menuPrev:SetEnabled(choicePage>1)
    menuNext:SetEnabled(start+5<#choiceItems)
end
for i=1,5 do
    local button = Small(menu, "", 242)
    button:SetHeight(27)
    button:SetPoint("TOP", menu, "TOP", 0, -10-(i-1)*31)
    button:SetScript("OnClick", function(self)
        if self.item and chosen then chosen(self.item) end
        menu:Hide()
    end)
    choices[i]=button
end
menuPrev:SetScript("OnClick", function()
    choicePage=math.max(1,choicePage-1); DrawChoices()
end)
menuNext:SetScript("OnClick", function()
    choicePage=math.min(math.ceil(#choiceItems/5), choicePage+1)
    DrawChoices()
end)
menu:SetScript("OnHide", function() openMenu=nil end)
local function Choose(anchor, items, callback)
    if openMenu==anchor then menu:Hide(); return end
    choiceItems=items
    choicePage=1
    chosen=callback
    openMenu=anchor
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
    DrawChoices()
    menu:Show()
end
local function CaptainPicker(parent, slot, page)
    local button = Small(parent, "Select Battle.net captain", 235)
    ns.Tooltips.Bind(button, {
        title="Battle.net captain",
        detail="Choose an existing Battle.net friend. Blizzard requires real Battle.net IDs for spectator hosting."
    })
    button:SetScript("OnClick", function(self)
        local entries={}
        for _, friend in ipairs(Engine.GetFriends()) do
            entries[#entries+1] = {
                label=friend.displayName, id=friend.id,
            }
        end
        if #entries==0 then
            entries[1]={label="No Battle.net friends available", id=nil}
        end
        Choose(self,entries,function(item)
            if item.id then Engine.SelectCaptain(page,slot,item.id) end
        end)
    end)
    return button
end

-- Panels belong to canvas and are hidden as a set when the page switches.
local playerSetup = Panel(0,175,"YOUR TEAM")
local playerForm = Panel(192,243,"MATCH SETUP")
local playerArena = Panel(0,344,"ARENA MATCH")
local hostForm = Panel(0,173,"HOST / SPECTATE")
local hostStatus = Panel(454,62,"MATCH STATUS")
local arenaStatus = Panel(305,66,"MATCH STATUS")
local playerTeam = Panel(0,300,"YOUR TEAM")
local enemyTeam = Panel(0,300,"ENEMY TEAM")
local hostTeam1 = Panel(183,252,"TEAM 1  •  5 FIGHTERS")
local hostTeam2 = Panel(183,252,"TEAM 2  •  5 FIGHTERS")
local vs = Style.Text(canvas,"VS",28,C.gold,nil,"display")
local matchHint = Text(arenaStatus,"Only confirmed Blizzard opponent information is shown.",20,43,12,C.muted)
local waiting = Text(hostStatus,"Waiting for an arena. A submitted request is not proof of entry.",20,39,12,C.muted)
local msgPlayer = Text(playerForm,"",18,216,12,C.muted)
local msgHost = Text(hostForm,"",18,150,12,C.muted)

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
        name:SetPoint("RIGHT",f,"RIGHT",-9,0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        rows[i]={frame=f,icon=icon,name=name}
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
        if i<=size then SetRow(row,members and members[i],placeholder) end
    end
end

local playerTeamInfo = Text(playerSetup,"Blizzard party / raid roster",18,43,12,C.muted)
local playerBrackets={}
local hostBrackets={}
local function Brackets(parent,page,y,store)
    local heading=Text(parent,"Bracket",19,y,13,C.text)
    for i,bracket in ipairs(Engine.Brackets) do
        local b=Small(parent,bracket.."v"..bracket,76)
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",126+(i-1)*84,-y+6)
        b:SetScript("OnClick",function() Engine.SelectBracket(page,bracket) end)
        store[i]=b
    end
end
Brackets(playerForm,"player",43,playerBrackets)
Brackets(hostForm,"host",16,hostBrackets)

local playerCaptainLabel=Text(playerForm,"Opposing captain",19,102,13)
local playerCaptain=CaptainPicker(playerForm,1,"player")
playerCaptain:SetPoint("TOPLEFT",playerForm,"TOPLEFT",162,-99)
local playerMapLabel=Text(playerForm,"Arena",19,148,13)
local playerMap = Small(playerForm,"Choose arena",235)
playerMap:SetPoint("TOPLEFT",playerForm,"TOPLEFT",162,-143)
local playerSend=Action(playerForm,"Send Challenge",180,34)
playerSend:SetPoint("TOPLEFT",playerForm,"TOPLEFT",416,-174)

local hostCaptain1Label=Text(hostForm,"Team 1 Captain",17,58,13)
local hostCaptain1=CaptainPicker(hostForm,1,"host")
hostCaptain1:SetPoint("TOPLEFT",hostForm,"TOPLEFT",15,-77)
local hostCaptain2Label=Text(hostForm,"Team 2 Captain",271,58,13)
local hostCaptain2=CaptainPicker(hostForm,2,"host")
hostCaptain2:SetPoint("TOPLEFT",hostForm,"TOPLEFT",269,-77)
local hostMapLabel=Text(hostForm,"Arena",525,58,13)
local hostMap=Small(hostForm,"Choose arena",209)
hostMap:SetPoint("TOPLEFT",hostForm,"TOPLEFT",523,-77)
local hostSend=Action(hostForm,"Request Spectator Match",215,34)
hostSend:SetPoint("TOP",hostForm,"TOP",0,-115)

local function SelectMap(page,anchor)
    local entries={}
    for index, map in ipairs(Engine.Maps) do
        entries[#entries+1]={label=map.name, id=index}
    end
    Choose(anchor, entries, function(item) Engine.SelectMap(page,item.id) end)
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

-- Panel layout adjusts to current canvas width. The list is scrollable at
-- 1050x650 minimum size; no controls spill over the outer window.
local function Position(frame,x,y,w,h)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,-y)
    frame:SetSize(w,h)
end
local function Layout()
    local w=math.max(1,scroll:GetWidth()-5)
    canvas:SetWidth(w)
    local half=math.max(245,(w-42)/2)
    local inArena=Engine.InArena()
    if active=="player" then
        if inArena then
            Position(playerTeam,0,0,half,299)
            Position(enemyTeam,w-half,0,half,299)
            Position(arenaStatus,0,312,w,63)
            vs:ClearAllPoints()
            vs:SetPoint("CENTER",canvas,"TOP",0,-144)
            canvas:SetHeight(390)
        else
            Position(playerSetup,0,0,w,173)
            Position(playerForm,0,187,w,243)
            canvas:SetHeight(448)
            playerSend:ClearAllPoints()
            playerSend:SetPoint("TOPRIGHT",playerForm,"TOPRIGHT",-18,-175)
        end
    elseif inArena then
        Position(hostTeam1,0,0,half,252)
        Position(hostTeam2,w-half,0,half,252)
        Position(hostStatus,0,272,w,62)
        vs:ClearAllPoints()
        vs:SetPoint("CENTER",canvas,"TOP",0,-146)
        canvas:SetHeight(354)
    else
        Position(hostForm,0,0,w,173)
        Position(hostTeam1,0,184,half,252)
        Position(hostTeam2,w-half,184,half,252)
        Position(hostStatus,0,451,w,62)
        vs:ClearAllPoints()
        vs:SetPoint("CENTER",canvas,"TOP",0,-306)
        canvas:SetHeight(528)
    end
    local max=math.max(0,canvas:GetHeight()-scroll:GetHeight())
    scroll:SetVerticalScroll(math.min(max,scroll:GetVerticalScroll()))
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
scroll:SetScript("OnSizeChanged",function() Layout(); scrollbar:Refresh() end)

function View.Refresh()
    if not root:IsShown() then return end
    local inArena=Engine.InArena()
    local c=Engine.GetConfig(active)
    if not c then return end
    local cfgPlayer=Engine.GetConfig("player")
    local cfgHost=Engine.GetConfig("host")
    for i,button in ipairs(playerBrackets) do
        button.label:SetTextColor(unpack(Engine.Brackets[i]==cfgPlayer.bracket
            and C.pale or C.text))
    end
    for i,button in ipairs(hostBrackets) do
        button.label:SetTextColor(unpack(Engine.Brackets[i]==cfgHost.bracket
            and C.pale or C.text))
    end
    local playerOther=Engine.GetCaptain("player",1)
    local hostA=Engine.GetCaptain("host",1)
    local hostB=Engine.GetCaptain("host",2)
    playerCaptain.label:SetText(playerOther and playerOther.displayName or
        "Choose opposing captain")
    hostCaptain1.label:SetText(hostA and hostA.displayName or "Team 1 captain")
    hostCaptain2.label:SetText(hostB and hostB.displayName or "Team 2 captain")
    playerMap.label:SetText(Engine.Maps[cfgPlayer.map].name)
    hostMap.label:SetText(Engine.Maps[cfgHost.map].name)
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
    hostStatus:SetShown(active=="host")
    vs:SetShown(inArena or active=="host")
    if openMenu then menu:Hide() end
    Layout()
    scrollbar:Refresh()
end
local function Visible(tab)
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
end)
root:SetScript("OnHide",function()
    if unsubscribe then unsubscribe(); unsubscribe=nil end
    menu:Hide()
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

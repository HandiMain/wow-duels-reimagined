local _, ns = ...

-- Addon Status is a shared Retail/Forever *view*, not a roster or network
-- engine. The independent owners remain Core/Group and Core/Presence.
local Style, Chrome, Window = ns.Style, ns.Chrome, ns.Window
local Presence, Group, Widgets = ns.Presence, ns.Group, ns.Widgets
local C = Style.color
local Status = {}
ns.AddonStatus = Status

local root = CreateFrame("Frame", nil, Window.content)
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Addon Status",root) end
root:SetAllPoints(Window.content)
root:EnableMouse(false)
root:Hide()

local emblem = Chrome.Icon(root, "Community")
emblem:SetSize(34, 34)
emblem:SetPoint("TOPLEFT", root, "TOPLEFT", 25, -16)
local mark = Style.Fill(root, C.gold, "OVERLAY")
mark:ClearAllPoints()
mark:SetSize(7, 7)
mark:SetPoint("BOTTOMRIGHT", emblem, "BOTTOMRIGHT", -1, 1)

local heading = Style.Text(root, "Addon Status", 27, C.pale, nil, "display")
heading:SetPoint("TOPLEFT", root, "TOPLEFT", 69, -17)
local subtitle = Style.Text(root,
    "See which party or raid members are using Duels Reimagined.", 13, C.text)
subtitle:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
local divider = Chrome.Divider(root, 500, 14)
divider:SetPoint("TOPLEFT", root, "TOPLEFT", 24, -121)
divider:SetPoint("TOPRIGHT", root, "TOPRIGHT", -25, -121)

-- A real scroll viewport supports full raids and smaller window dimensions.
-- The entire painted table is a single centered, responsive panel.
local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 24, -152)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -24, 90)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(740, 250)
scroll:SetScrollChild(canvas)
local panel = CreateFrame("Frame", nil, canvas)
panel:SetPoint("TOP", canvas, "TOP", 0, 0)
panel:SetSize(740, 250)
Style.Skin(panel, C.window, {
    corner=9, edge=C.goldDim, light=C.goldDim, dark=C.window,
    shine=0.08, shade=0.06, rim=0.66,
})
local partyIcon = Chrome.Icon(panel, "Community")
partyIcon:SetSize(31, 31)
partyIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", 19, -13)
local panelHeading = Style.Text(panel, "Your Party", 21, C.pale, nil, "display")
panelHeading:SetPoint("LEFT", partyIcon, "RIGHT", 9, 0)
local panelDetail = Style.Text(panel, "", 12, C.muted)
panelDetail:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -23)
panelDetail:SetJustifyH("RIGHT")

local columns = CreateFrame("Frame", nil, panel)
columns:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -65)
columns:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -13, -65)
columns:SetHeight(39)
Style.Fill(columns, C.nav)
Style.Border(columns, C.goldDim)
local columnName = Style.Text(columns, "PLAYER", 13, C.gold)
local columnState = Style.Text(columns, "ADDON STATUS", 13, C.gold)
local columnVersion = Style.Text(columns, "VERSION", 13, C.gold)
columnName:SetPoint("LEFT", columns, "LEFT", 58, 0)

local rows = {}
local ROW_HEIGHT = 46
local function Row(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    local fill = Style.Fill(row, index % 2 == 1 and C.body or C.nav)
    fill:SetAlpha(index % 2 == 1 and 0.92 or 0.48)
    local line = row:CreateTexture(nil, "BORDER")
    line:SetColorTexture(unpack(C.goldDim))
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetAlpha(0.27)
    local portrait = row:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(28, 28)
    portrait:SetPoint("LEFT", row, "LEFT", 24, 0)
    Chrome.Sharp(portrait)
    local name = Style.Text(row, "", 14, C.text)
    name:SetPoint("LEFT", row, "LEFT", 66, 0)
    name:SetWordWrap(false)
    local dot = row:CreateTexture(nil, "ARTWORK")
    dot:SetSize(12, 12)
    local state = Style.Text(row, "", 13, C.text)
    state:SetWordWrap(false)
    local version = Style.Text(row, "", 12, C.muted)
    version:SetWordWrap(false)
    row.portrait, row.name, row.dot, row.state, row.version =
        portrait, name, dot, state, version
    ns.Tooltips.Bind(row, function(self)
        local data = self.member
        if not data then return end
        local descriptions = {
            self="This is your game client.",
            confirmed="This player replied to a Duels Reimagined addon check.",
            checking="Waiting for a reply. Silence does not prove the addon is absent.",
            unknown="The player's addon has not been confirmed.",
            offline="Blizzard reports this group member is offline.",
        }
        return { title=data.fullName or data.name or "Player",
            detail=descriptions[data.status] or descriptions.unknown,
            anchor="RIGHT" }
    end)
    rows[index] = row
    return row
end

local empty = Style.Text(panel, "", 15, C.muted)
empty:SetJustifyH("CENTER")
empty:SetWordWrap(true)
empty:SetPoint("TOP", columns, "BOTTOM", 0, -38)

local note = Style.Text(root,
    "No response does not mean the addon is missing.", 13, C.text)
note:SetJustifyH("CENTER")
note:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 32, 65)
note:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -32, 65)
note:SetWordWrap(false)

local check = Style.Action(root, "Check Again", "footer", {
    fill=C.button, edge=C.gold, light=C.goldDim,
    dark=C.window, hover=C.selected, text=C.pale,
})
check:SetSize(196, 36)
check:SetPoint("BOTTOMRIGHT", root, "BOTTOM", -6, 20)
local diagnostics=Style.Action(root,"Diagnostics","footer",{plate="dark"})
diagnostics:SetSize(196,36)
diagnostics:SetPoint("BOTTOMLEFT",root,"BOTTOM",6,20)
diagnostics:SetScript("OnClick",function() ns.DiagnosticsUI.Open() end)
if check.SetMotionScriptsWhileDisabled then
    check:SetMotionScriptsWhileDisabled(true)
end
local lastMessage
ns.Tooltips.Bind(check, function()
    local snap = Presence.GetSnapshot()
    if snap.mode ~= "party" and snap.mode ~= "raid" then
        return { title="Check Again",
            detail="Join a party or raid to check other members." }
    end
    if not snap.complete then
        return { title="Check Again",
            detail="Wait until the group roster is available." }
    end
    if snap.transport ~= "ready" then
        return { title="Check Again",
            detail="Blizzard's addon communication is " ..
                (snap.transport or "unavailable") .. ". Try again later." }
    end
    return { title="Check Again",
        detail="Ask group members running Duels Reimagined to reply. " ..
            "Checks are rate-limited, and an unanswered request proves nothing." }
end)

local SCROLL_STEP = 42
local function ClampScroll()
    local maximum = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    local value = math.max(0, math.min(maximum, scroll:GetVerticalScroll()))
    scroll:SetVerticalScroll(value)
end
local scrollbar = Widgets.ScrollBar(scroll, function()
    return scroll:GetHeight(), canvas:GetHeight(), scroll:GetVerticalScroll()
end, function(offset)
    scroll:SetVerticalScroll(offset)
end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(0, canvas:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maximum,
        self:GetVerticalScroll() - delta * SCROLL_STEP)))
    scrollbar:Refresh()
end)
scroll:SetScript("OnVerticalScroll", function() scrollbar:Refresh() end)

local function Layout()
    local width = math.max(1, scroll:GetWidth())
    local display = math.max(310, math.min(920, width - 18))
    panel:SetWidth(display)
    canvas:SetWidth(width)
    local statusX = math.floor(display * 0.46)
    local versionX = math.floor(display * 0.79)
    columnState:ClearAllPoints()
    columnState:SetPoint("LEFT", columns, "LEFT", statusX - 13, 0)
    columnVersion:ClearAllPoints()
    columnVersion:SetPoint("LEFT", columns, "LEFT", versionX - 13, 0)
    for _, row in ipairs(rows) do
        row:SetWidth(display - 26)
        row.name:SetWidth(math.max(65, statusX - 93))
        row.dot:ClearAllPoints()
        row.dot:SetPoint("LEFT", row, "LEFT", statusX - 13, 0)
        row.state:ClearAllPoints()
        row.state:SetPoint("LEFT", row, "LEFT", statusX + 7, 0)
        row.state:SetWidth(math.max(80, versionX - statusX - 31))
        row.version:ClearAllPoints()
        row.version:SetPoint("LEFT", row, "LEFT", versionX - 13, 0)
        row.version:SetWidth(math.max(55, display - versionX - 28))
    end
    empty:SetWidth(math.max(180, display - 60))
    ClampScroll()
    scrollbar:Refresh()
end

local colors = {
    confirmed={ 0.46, 0.85, 0.44 },
    checking={ 0.96, 0.71, 0.25 },
    unknown={ 0.62, 0.64, 0.68 },
    offline={ 0.49, 0.49, 0.51 },
    self={ 0.92, 0.73, 0.35 },
}
local statusNames = {
    confirmed="Confirmed", checking="Checking...",
    unknown="Not confirmed", offline="Offline", self="This client",
}
local function DrawRow(row, member, index)
    row.member = member
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 13,
        -105 - (index - 1) * ROW_HEIGHT)
    local iconUV = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.classFile or ""]
    if iconUV then
        row.portrait:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        row.portrait:SetTexCoord(unpack(iconUV))
    else
        row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.portrait:SetTexCoord(0, 1, 0, 1)
    end
    row.name:SetText(member.status == "self" and "You" or
        (member.name or "Unknown player"))
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile or ""]
    if classColor and member.status ~= "self" then
        row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        row.name:SetTextColor(unpack(C.gold))
    end
    local color = colors[member.status] or colors.unknown
    row.dot:SetColorTexture(unpack(color))
    row.state:SetText(statusNames[member.status] or "Not confirmed")
    row.state:SetTextColor(unpack(color))
    row.version:SetText(member.version or
        ((member.status == "self" or member.status == "confirmed")
            and "Not reported" or "—"))
    row:Show()
end

local function Refresh()
    if not root:IsShown() then return end
    local snap = Presence.GetSnapshot()
    local hasGroup = snap.mode == "party" or snap.mode == "raid"
    local count = hasGroup and snap.complete and #snap.members or 0
    panelHeading:SetText(snap.mode == "raid" and "Your Raid" or
        snap.mode == "party" and "Your Party" or "Your Group")
    panelDetail:SetText(count > 0 and (count .. " MEMBERS") or "")
    columns:SetShown(count > 0)
    if not hasGroup then
        empty:SetText("Join a party or raid to check which members use Duels Reimagined.")
    elseif not snap.complete then
        empty:SetText("Group information is temporarily unavailable. " ..
            "Wait for Blizzard to refresh the roster.")
    elseif count == 0 then
        empty:SetText("No group members were reported.")
    else
        empty:SetText("")
    end
    empty:SetShown(count == 0)
    for i = 1, count do DrawRow(Row(i), snap.members[i], i) end
    for i = count + 1, #rows do rows[i]:Hide() end
    panel:SetHeight(count > 0 and (120 + count * ROW_HEIGHT) or 240)
    canvas:SetHeight(panel:GetHeight() + 6)
    local canCheck = hasGroup and snap.complete and snap.transport == "ready"
    check:SetEnabled(canCheck)
    check:SetAlpha(canCheck and 1 or 0.48)
    if not hasGroup then
        note:SetText("Group detection works on Retail and Forever.")
    elseif not snap.complete then
        note:SetText("The group roster must be readable before checking.")
    elseif snap.transport == "restricted" then
        note:SetText("Blizzard is restricting addon messages here. Try outside PvP.")
    elseif snap.transport ~= "ready" then
        note:SetText("Addon communication is unavailable: " .. tostring(snap.transport))
    else
        note:SetText(lastMessage or "No response does not mean the addon is missing.")
    end
    Layout()
end

local function CheckNow()
    local accepted, reason = Presence.CheckNow()
    if accepted then
        lastMessage = "Check sent. Waiting for group members to respond."
    elseif reason == "cooldown" then
        lastMessage = "Already checked recently. Try again in a moment."
    elseif reason == "restricted" then
        lastMessage = "Blizzard is restricting addon communication here."
    else
        lastMessage = "Check unavailable: " .. (reason or "unknown reason")
    end
    Refresh()
end
check:SetScript("OnClick", CheckNow)

local unsubscribe
root:SetScript("OnShow", function()
    lastMessage = nil
    if not unsubscribe then
        unsubscribe = Presence.Subscribe(Refresh)
    end
    Refresh()
end)
root:SetScript("OnHide", function()
    if unsubscribe then unsubscribe(); unsubscribe = nil end
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
end)
scroll:SetScript("OnSizeChanged", function() Layout() end)

function Status.Show(on)
    root:SetShown(on == true)
end
function Status.Refresh() Refresh() end
function Status.GetPageScroll(page)
    return page == "status" and scroll:GetVerticalScroll() or 0
end
function Status.SetPageScroll(page, offset)
    if page ~= "status" then return end
    scroll:SetVerticalScroll(math.max(0, offset or 0))
    ClampScroll()
    scrollbar:Refresh()
end

ns.Search.Register("addonstatus:check", "Check Again", "Addon Status",
    "Ask your group which players are using Duels Reimagined",
    function()
        if ns.Navigation then ns.Navigation.SelectKey("addonstatus", "status") end
        CheckNow()
    end,
    function()
        local snap = Presence.GetSnapshot()
        return (snap.mode == "party" or snap.mode == "raid")
            and snap.complete and snap.transport == "ready"
    end)

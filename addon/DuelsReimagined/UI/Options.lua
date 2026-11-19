local _, ns = ...
local Style = ns.Style
local C = Style.color
local Settings = ns.Settings
local Theme = ns.Theme
local Window = ns.Window

local Options = {}
ns.Options = Options

local panel = CreateFrame("Frame", nil, Window.content)
panel:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 46, -143)
panel:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -46, 38)
Style.Fill(panel, C.nav)
Style.Border(panel, C.goldDim)
panel:Hide()

local heading = Style.Text(panel, "Appearance", 20, C.pale)
heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -20)
local description = Style.Text(panel, "Choose how Duels Reimagined matches your interface.", 13, C.muted)
description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)

local availability = Style.Text(panel, "", 13, C.muted)
availability:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -31)

local entries = {}

local function MakeSwitch(label, detail, key, y)
    local button = CreateFrame("Button", nil, panel)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, y)
    button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, y)
    button:SetHeight(61)

    local plate = Style.Fill(button, C.body)
    local outline = button:CreateTexture(nil, "BORDER")
    outline:SetColorTexture(unpack(C.goldDim))
    outline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    outline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    outline:SetHeight(1)

    local name = Style.Text(button, label, 15, C.text)
    name:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -9)
    local note = Style.Text(button, detail, 12, C.muted)
    note:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
    note:SetPoint("RIGHT", button, "RIGHT", -65, 0)
    note:SetJustifyH("LEFT")

    local square = CreateFrame("Frame", nil, button)
    square:SetSize(30, 23)
    square:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    Style.Fill(square, C.rail)
    Style.Border(square, C.goldDim)

    local state = Style.Text(square, "", 18, C.pale)
    state:SetPoint("CENTER")

    button:SetScript("OnClick", function()
        if not Theme.IsAvailable() then return end
        Settings.Set(key, not Settings.Get(key))
    end)
    button:SetScript("OnEnter", function()
        if Theme.IsAvailable() then plate:SetColorTexture(unpack(C.hover)) end
    end)
    button:SetScript("OnLeave", function()
        plate:SetColorTexture(unpack(C.body))
    end)

    entries[#entries + 1] = { button = button, label = name, state = state, key = key }
end

MakeSwitch("Match EllesmereUI colors",
    "Use EllesmereUI's panel and accent colors. Duels branding stays ours.",
    "matchColors", -118)
MakeSwitch("Match EllesmereUI font",
    "Use EllesmereUI's chosen interface font.",
    "matchFont", -186)

function Options.Refresh()
    local ready = Theme.IsAvailable()
    availability:SetText(ready
        and "EllesmereUI matching is available."
        or "Matching unavailable. Install EllesmereUI and enable third-party skins there.")
    availability:SetTextColor(ready and 0.44 or 0.72,
        ready and 0.86 or 0.65, ready and 0.60 or 0.58, 1)
    for _, entry in ipairs(entries) do
        entry.button:EnableMouse(ready)
        entry.label:SetTextColor(unpack(ready and C.text or C.muted))
        entry.state:SetText(Settings.Get(entry.key) and "ON" or "OFF")
        entry.state:SetTextColor(unpack(ready and C.gold or C.muted))
    end
end

function Options.Show(visible)
    panel:SetShown(visible)
    if visible then Options.Refresh() end
end

Options.Refresh()

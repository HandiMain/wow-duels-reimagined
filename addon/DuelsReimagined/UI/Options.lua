local _, ns = ...
local Style, Widgets = ns.Style, ns.Widgets
local C = Style.color
local Settings, Theme, Window = ns.Settings, ns.Theme, ns.Window

local Options = {}
ns.Options = Options

local panel = CreateFrame("Frame", nil, Window.content)
panel:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 46, -143)
panel:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -46, 38)
Style.Fill(panel, C.nav)
Style.Border(panel, C.goldDim)
ns.Chrome.Panel(panel)
panel:Hide()

local heading = Style.Text(panel, "Appearance", 20, C.pale)
heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -20)
local description = Style.Text(panel,
    "Choose how Duels Reimagined matches your interface.", 13, C.muted)
description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)

local availability = Style.Text(panel, "", 13, C.muted)
availability:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -28)

local unavailable = "EllesmereUI matching is unavailable. Enable EllesmereUI and its third-party skinning support."
local rows = {}

local function AddToggle(key, label, descriptionText, top)
    local row = Widgets.ToggleRow(panel, label, descriptionText, function(value)
        Settings.Set(key, value)
    end)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, top)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, top)
    rows[#rows + 1] = { key = key, widget = row }
end

AddToggle("matchColors", "Match EllesmereUI colors",
    "Use EllesmereUI's accent and panel colors, keeping our dueling identity.", -112)
AddToggle("matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -189)

function Options.Refresh()
    local ready = Theme.IsAvailable()
    availability:SetText(ready and "EllesmereUI matching is available." or
        "EllesmereUI is unavailable. Matching controls are disabled.")
    availability:SetTextColor(
        ready and 0.46 or 0.73, ready and 0.86 or 0.65,
        ready and 0.60 or 0.58, 1)

    for _, entry in ipairs(rows) do
        local widget = entry.widget
        widget:RefreshColors()
        widget:SetAvailable(ready, unavailable)
        widget:SetChecked(Settings.Get(entry.key))
    end
end

function Options.Show(visible)
    panel:SetShown(visible)
    if visible then Options.Refresh() end
end

-- Restore saved settings once the entire visual hierarchy exists.
ns.Theme.Refresh()

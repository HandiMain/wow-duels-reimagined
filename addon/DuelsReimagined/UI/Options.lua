local _, ns = ...
local Style, Widgets, Motion = ns.Style, ns.Widgets, ns.Motion
local C, Settings = Style.color, ns.Settings
local Theme, Window = ns.Theme, ns.Window

-- Both preferences pages live in one Options owner. New toggle rows are
-- registered with global Search when created; nothing is indexed twice.
local Options = {}
ns.Options = Options

local function Panel(height)
    local panel = CreateFrame("Frame", nil, Window.content)
    panel:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 34, -112)
    panel:SetPoint("TOPRIGHT", Window.content, "TOPRIGHT", -34, -112)
    panel:SetHeight(height)
    Style.Fill(panel, C.nav)
    Style.Border(panel, C.goldDim)
    ns.Chrome.Panel(panel)
    panel:Hide()
    return panel
end

local appearance = Panel(245)
local interface = Panel(215)

local function Text(panel, title, subtitle)
    local heading = Style.Text(panel, title, 18, C.pale)
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -16)
    local detail = Style.Text(panel, subtitle, 12, C.muted)
    detail:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    return detail
end

local appearanceDescription = Text(appearance, "Appearance",
    "Choose how Duels Reimagined matches your interface.")
local availability = Style.Text(appearance, "", 12, C.muted)
availability:SetPoint("TOPLEFT", appearanceDescription, "BOTTOMLEFT", 0, -17)

local interfaceDescription = Text(interface, "Window behavior",
    "Keep the world visible while the dueling hall is open.")

local info = Style.Text(interface,
    "Hold the eye in the header to peek temporarily. Fold keeps the header visible.",
    12, C.muted)
info:SetPoint("TOPLEFT", interface, "TOPLEFT", 20, -165)
info:SetPoint("RIGHT", interface, "RIGHT", -20, 0)
info:SetJustifyH("LEFT")

local unavailable = "Enable EllesmereUI and its third-party skinning support to use this setting."
local rows = {}

local function AddToggle(panel, pageKey, key, name, detail, top, requiresEllesmere)
    local row = Widgets.ToggleRow(panel, name, detail, function(value)
        Settings.Set(key, value)
    end)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, top)
    rows[#rows + 1] = { key = key, widget = row, needsEllesmere = requiresEllesmere }

    -- A new Options row becomes searchable at the same place it is defined.
    ns.Search.Register("setting:" .. key, name,
        "Options / " .. (pageKey == "options" and "Appearance" or "Interface"),
        detail, function()
            if ns.Navigation and ns.Navigation.SelectKey then
                ns.Navigation.SelectKey("options", pageKey)
            end
            Motion.Stop(row.hover, 0.34)
            Motion.Fade(row.hover, 0, 0.72)
        end)
    return row
end

AddToggle(appearance, "options", "matchColors", "Match EllesmereUI colors",
    "Use EllesmereUI's accent and panel colors, keeping our dueling identity.",
    -93, true)
AddToggle(appearance, "options", "matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -153, true)
AddToggle(interface, "interface", "autoPeekMoving", "Automatic Peek while moving",
    "Fade the window when your character starts moving; restore it when you stop.",
    -98, false)

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
        widget:SetAvailable(not entry.needsEllesmere or ready,
            entry.needsEllesmere and unavailable or nil)
        widget:SetChecked(Settings.Get(entry.key))
    end
end

function Options.Show(pageKey)
    appearance:SetShown(pageKey == "options")
    interface:SetShown(pageKey == "interface")
    if pageKey == "options" or pageKey == "interface" then
        Options.Refresh()
    end
end

-- Restore persisted settings after all screens, widgets and search entries exist.
Theme.Refresh()

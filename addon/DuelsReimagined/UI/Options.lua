local _, ns = ...
local Style, Widgets, Motion = ns.Style, ns.Widgets, ns.Motion
local C, Settings = Style.color, ns.Settings
local Theme, Window, Fonts = ns.Theme, ns.Window, ns.Fonts

local Options = {}
ns.Options = Options

-- Polestar/Ellesmere-style pages scroll only when the available window height
-- requires it. Each screen owns its widgets; no duplicate option registry.
local function Panel(height)
    local scroll = CreateFrame("ScrollFrame", nil, Window.content)
    scroll:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 34, -112)
    scroll:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -34, 27)
    scroll:EnableMouseWheel(true)
    local panel = CreateFrame("Frame", nil, scroll)
    panel:SetSize(690, height)
    scroll:SetScrollChild(panel)
    scroll:SetScript("OnSizeChanged", function(self, width)
        panel:SetWidth(math.max(1, width or 1))
        local bottom = math.max(0, panel:GetHeight() - self:GetHeight())
        if self:GetVerticalScroll() > bottom then self:SetVerticalScroll(bottom) end
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local bottom = math.max(0, panel:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(bottom,
            self:GetVerticalScroll() - delta * 42)))
        Widgets.CloseChoices()
    end)
    Style.Fill(panel, C.nav)
    Style.Border(panel, C.goldDim)
    panel.scrollOwner = scroll
    scroll:Hide()
    return panel
end

local appearance = Panel(245)
local interface = Panel(604)

local function Section(panel, title, subtitle, top)
    local heading = Style.Text(panel, title, 18, C.pale)
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
    local detail = Style.Text(panel, subtitle, 12, C.muted)
    detail:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    return detail
end

local appearanceDescription = Section(appearance, "Appearance",
    "Choose how Duels Reimagined matches your interface.", -16)
local availability = Style.Text(appearance, "", 12, C.muted)
availability:SetPoint("TOPLEFT", appearanceDescription, "BOTTOMLEFT", 0, -17)
Section(interface, "Window behavior",
    "Keep the world visible while the dueling hall is open.", -16)

local unavailable = "Enable EllesmereUI and its third-party skinning support to use this setting."
local rows = {}

local function RegisterOption(key, name, detail, pageKey, widget)
    ns.Search.Register("setting:" .. key, name,
        "Options / " .. (pageKey == "options" and "Appearance" or "Interface"),
        detail, function()
            if ns.Navigation and ns.Navigation.SelectKey then
                ns.Navigation.SelectKey("options", pageKey)
            end
            if widget and widget.hover then
                Motion.Stop(widget.hover, 0.34)
                Motion.Fade(widget.hover, 0, 0.72)
            end
        end)
end

local function AddToggle(panel, pageKey, key, name, detail, top, requiresEllesmere)
    local row = Widgets.ToggleRow(panel, name, detail,
        function(value) Settings.Set(key, value) end,
        function() Settings.Reset(key) end)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, top)
    rows[#rows + 1] = { key = key, widget = row, needsEllesmere = requiresEllesmere }
    RegisterOption(key, name, detail, pageKey, row)
    return row
end

AddToggle(appearance, "options", "matchColors", "Match EllesmereUI colors",
    "Use EllesmereUI's accent and panel colors, keeping our dueling identity.",
    -93, true)
AddToggle(appearance, "options", "matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -153, true)
AddToggle(interface, "interface", "autoPeekMoving", "Automatic Peek while moving",
    "Fade the window during movement; restore it when you stop.", -82, false)
AddToggle(interface, "interface", "reduceMotion", "Reduce motion",
    "Shorten or skip UI animation while retaining visual feedback.", -148, false)

Section(interface, "Typography", "Choose text appearance independently of window scale.", -229)

local fontChoice = Widgets.ChoiceRow(interface, "Interface font",
    "Blizzard by default; includes fonts registered with SharedMedia.",
    function(key) Settings.Set("fontChoice", key) end,
    function() Settings.Reset("fontChoice") end, false)
fontChoice:SetPoint("TOPLEFT", interface, "TOPLEFT", 20, -301)
fontChoice:SetPoint("TOPRIGHT", interface, "TOPRIGHT", -20, -301)
RegisterOption("fontChoice", "Interface font",
    "Choose a Blizzard or LibSharedMedia font for the addon", "interface", fontChoice)

local fontScale = Widgets.SliderRow(interface, "Text size",
    "Adjust text size without changing the menu scale.",
    0.9, 1.15, 0.05,
    function(v) Settings.Set("fontScale", v) end,
    function() Settings.Reset("fontScale") end)
fontScale:SetPoint("TOPLEFT", interface, "TOPLEFT", 20, -385)
fontScale:SetPoint("TOPRIGHT", interface, "TOPRIGHT", -20, -385)
RegisterOption("fontScale", "Text size",
    "Change interface font scale between 90 and 115 percent", "interface", fontScale)

local outlineChoices = {
    { key = "default", label = "Default" },
    { key = "none", label = "None" },
    { key = "outline", label = "Outline" },
    { key = "thick", label = "Thick Outline" },
}
local fontOutline = Widgets.ChoiceRow(interface, "Text outline",
    "Use the original style, or choose a clearer outline.",
    function(key) Settings.Set("fontOutline", key) end,
    function() Settings.Reset("fontOutline") end, true)
fontOutline:SetPoint("TOPLEFT", interface, "TOPLEFT", 20, -469)
fontOutline:SetPoint("TOPRIGHT", interface, "TOPRIGHT", -20, -469)
RegisterOption("fontOutline", "Text outline",
    "Choose default, none, outline or thick outline", "interface", fontOutline)

local info = Style.Text(interface,
    "Hold the eye to Peek. Fold leaves the header visible. Font matching is controlled under Appearance.",
    12, C.muted)
info:SetPoint("TOPLEFT", interface, "TOPLEFT", 20, -565)
info:SetPoint("RIGHT", interface, "RIGHT", -20, 0)
info:SetJustifyH("LEFT")

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
        widget:SetModified(Settings.IsModified(entry.key))
    end
    local matching = ready and Settings.Get("matchFont")
    fontChoice:SetChoices(Fonts.GetChoices(), Settings.Get("fontChoice"),
        matching and "Managed by EllesmereUI" or nil)
    fontChoice:SetAvailable(not matching,
        "Disable Match EllesmereUI font under Appearance to choose a manual font.")
    fontChoice:SetModified(Settings.IsModified("fontChoice"))
    fontChoice.resetIcon:SetVertexColor(unpack(C.gold))
    fontScale:SetValue(Settings.Get("fontScale"))
    fontScale:SetModified(Settings.IsModified("fontScale"))
    fontScale:RefreshColors()
    fontOutline:SetChoices(outlineChoices, Settings.Get("fontOutline"))
    fontOutline:SetAvailable(true)
    fontOutline:SetModified(Settings.IsModified("fontOutline"))
    fontOutline.resetIcon:SetVertexColor(unpack(C.gold))
end

function Options.Show(pageKey)
    Widgets.CloseChoices()
    appearance.scrollOwner:SetShown(pageKey == "options")
    interface.scrollOwner:SetShown(pageKey == "interface")
    if pageKey == "options" or pageKey == "interface" then Options.Refresh() end
end

Window.frame:HookScript("OnHide", Widgets.CloseChoices)
Theme.Refresh()

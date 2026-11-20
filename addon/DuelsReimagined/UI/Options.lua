local _, ns = ...
local Style, Widgets, Motion = ns.Style, ns.Widgets, ns.Motion
local C, Settings = Style.color, ns.Settings
local Theme, Window, Fonts = ns.Theme, ns.Window, ns.Fonts

local Options = {}
ns.Options = Options

-- One scroll owner per Options page. Only section cards get outlines; the
-- scroll content itself is transparent, so separate groups do not blend into
-- one giant panel. The same shared thumb supports smaller window sizes.
local function Page(contentHeight)
    local scroll = CreateFrame("ScrollFrame", nil, Window.content)
    scroll:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 26, -98)
    scroll:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -26, 17)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(690, contentHeight)
    scroll:SetScrollChild(content)
    local function Clamp()
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        if scroll:GetVerticalScroll() > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        end
    end
    local bar = Widgets.ScrollBar(scroll,
        function()
            return scroll:GetHeight(), content:GetHeight(),
                scroll:GetVerticalScroll()
        end,
        function(value)
            scroll:SetVerticalScroll(value)
        end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width or 1))
        if content.Relayout then content:Relayout(content:GetWidth()) end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        Clamp()
        bar:Refresh()
    end)
    scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxScroll,
            self:GetVerticalScroll() - delta * 48)))
        bar:Refresh()
        Widgets.CloseChoices()
    end)
    scroll:HookScript("OnShow", function()
        if content.Relayout then content:Relayout(content:GetWidth()) end
        Clamp()
        bar:Refresh()
    end)
    scroll:Hide()
    content.scrollOwner, content.scrollBar = scroll, bar
    return content
end

local function Card(page, y, height)
    local card = CreateFrame("Frame", nil, page)
    card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    card:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -y)
    card:SetHeight(height)
    Style.Skin(card, C.nav, { corner=11, edge=C.border, shine=0.25, shade=0.25 })
    card.scrollOwner, card.scrollTop = page.scrollOwner, y
    return card
end

local appearance = Page(303)
local interface = Page(1055)

local appearanceCard = Card(appearance, 0, 292)
local behaviorCard = Card(interface, 0, 325)
local typographyCard = Card(interface, 339, 306)
local accessCard = Card(interface, 659, 382)

local function Section(card, title, subtitle, top)
    local heading = Style.Text(card, title, 18, C.pale)
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 20, top)
    local detail = Style.Text(card, subtitle, 12, C.muted)
    detail:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    return detail
end

local appearanceDescription = Section(appearanceCard, "Appearance",
    "Choose a complete look, with optional EllesmereUI matching.", -16)
local availability = Style.Text(appearanceCard, "", 12, C.muted)
availability:SetJustifyH("LEFT")
availability:SetWordWrap(true)
availability:SetPoint("TOPLEFT", appearanceCard, "TOPLEFT", 20, -264)
Section(behaviorCard, "Window behavior",
    "Keep the world visible while the dueling hall is open.", -16)
Section(typographyCard, "Typography",
    "Choose text appearance independently of window scale.", -18)
Section(accessCard, "Minimap button",
    "Choose your minimap button or floating widget.", -18)

local unavailable = "Enable EllesmereUI and its third-party skinning support to use this setting."
local rows = {}

local function MarkPosition(row, card, top)
    row.optionsScroll, row.optionsY = card.scrollOwner, card.scrollTop - top
    return row
end

-- Search must reveal the target in scrollable pages, not merely select a page
-- while the relevant row remains below the viewport.
local function RegisterOption(key, name, detail, pageKey, widget)
    ns.Search.Register("setting:" .. key, name,
        "Options / " .. (pageKey == "options" and "Appearance" or "Interface"),
        detail, function()
            if ns.Navigation and ns.Navigation.SelectKey then
                ns.Navigation.SelectKey("options", pageKey)
            end
            if widget and widget.optionsScroll then
                local sf, top = widget.optionsScroll, widget.optionsY or 0
                local current, height = sf:GetVerticalScroll(), sf:GetHeight()
                if top < current + 18 or top + widget:GetHeight() > current + height - 18 then
                    local maxScroll = math.max(0,
                        sf:GetScrollChild():GetHeight() - height)
                    sf:SetVerticalScroll(math.max(0,
                        math.min(maxScroll, top - 46)))
                end
                if widget.hover then
                    Motion.Stop(widget.hover, 0.34)
                    Motion.Fade(widget.hover, 0, 0.72)
                end
            end
        end)
end

local function AddToggle(card, pageKey, key, name, detail, top, requiresEllesmere)
    local row = Widgets.ToggleRow(card, name, detail,
        function(value) Settings.Set(key, value) end,
        function() Settings.Reset(key) end)
    row:SetPoint("TOPLEFT", card, "TOPLEFT", 20, top)
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -20, top)
    MarkPosition(row, card, top)
    rows[#rows + 1] = { key = key, widget = row, needsEllesmere = requiresEllesmere }
    RegisterOption(key, name, detail, pageKey, row)
    return row
end

local themeChoice = Widgets.ChoiceRow(appearanceCard, "Color theme",
    "Recolor the whole addon, including panels, tabs, text and buttons.",
    function(key) Settings.Set("uiTheme", key) end,
    function() Settings.Reset("uiTheme") end, false)
themeChoice:SetPoint("TOPLEFT", appearanceCard, "TOPLEFT", 20, -61)
themeChoice:SetPoint("TOPRIGHT", appearanceCard, "TOPRIGHT", -20, -61)
MarkPosition(themeChoice, appearanceCard, -61)
RegisterOption("uiTheme", "Color theme",
    "Choose a Duels color theme when EllesmereUI color matching is off", "options", themeChoice)

local matchColorsRow = AddToggle(appearanceCard, "options", "matchColors", "Match EllesmereUI colors",
    "Override all color roles with EllesmereUI's accent and panel palette.",
    -131, true)
local matchFontRow = AddToggle(appearanceCard, "options", "matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -191, true)
local autoPeekRow = AddToggle(behaviorCard, "interface", "autoPeekMoving", "Automatic Peek while moving",
    "Fade the window during movement; restore it when you stop.", -64, false)
local reduceMotionRow = AddToggle(behaviorCard, "interface", "reduceMotion", "Reduce motion",
    "Shorten or skip UI animation while retaining visual feedback.", -119, false)
local tooltipsRow = AddToggle(behaviorCard, "interface", "showTooltips", "Show addon tooltips",
    "Show helpful descriptions when hovering over Duels controls.", -174, false)
local reminderRow = AddToggle(behaviorCard, "interface", "patchNotesReminder", "New patch reminder",
    "Show a subtle unread dot on Patch Notes when a new update is published.",
    -229, false)

local fontChoice = Widgets.ChoiceRow(typographyCard, "Interface font",
    "Blizzard by default; includes fonts registered with SharedMedia.",
    function(key) Settings.Set("fontChoice", key) end,
    function() Settings.Reset("fontChoice") end, false)
fontChoice:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -64)
fontChoice:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -64)
MarkPosition(fontChoice, typographyCard, -64)
RegisterOption("fontChoice", "Interface font",
    "Choose a Blizzard or LibSharedMedia font for the addon", "interface", fontChoice)

local fontScale = Widgets.SliderRow(typographyCard, "Text size",
    "Adjust text size without changing the menu scale.",
    Settings.MIN_FONT_SCALE, Settings.MAX_FONT_SCALE, Settings.FONT_SCALE_STEP,
    function(v) Settings.Set("fontScale", v) end,
    function() Settings.Reset("fontScale") end)
fontScale:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -131)
fontScale:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -131)
MarkPosition(fontScale, typographyCard, -131)
RegisterOption("fontScale", "Text size",
    "Change interface font scale between 75 and 150 percent", "interface", fontScale)

local outlineChoices = {
    { key = "default", label = "Default" },
    { key = "none", label = "None" },
    { key = "outline", label = "Outline" },
    { key = "thick", label = "Thick Outline" },
}
local fontOutline = Widgets.ChoiceRow(typographyCard, "Text outline",
    "Use the original style, or choose a clearer outline.",
    function(key) Settings.Set("fontOutline", key) end,
    function() Settings.Reset("fontOutline") end, true)
fontOutline:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -202)
fontOutline:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -202)
MarkPosition(fontOutline, typographyCard, -202)
RegisterOption("fontOutline", "Text outline",
    "Choose default, none, outline or thick outline", "interface", fontOutline)

-- BurstFX access behavior: one shared owner controls minimap and widget.
local accessModes = {
    { key = "minimap", label = "Minimap" },
    { key = "widget", label = "Widget" },
    { key = "both", label = "Both" },
    { key = "none", label = "Hidden" },
}
local iconMode = Widgets.ChoiceRow(accessCard, "Icon mode",
    "Show a minimap button, movable widget, both, or neither.",
    function(value) Settings.Set("iconMode", value) end,
    function() Settings.Reset("iconMode") end, true)
iconMode:SetPoint("TOPLEFT", accessCard, "TOPLEFT", 20, -64)
iconMode:SetPoint("TOPRIGHT", accessCard, "TOPRIGHT", -20, -64)
MarkPosition(iconMode, accessCard, -64)
RegisterOption("iconMode", "Icon mode",
    "Choose minimap, floating widget, both, or hidden", "interface", iconMode)
RegisterOption("minimapButton", "Minimap button",
    "Configure minimap button and floating widget", "interface", iconMode)

local widgetSize = Widgets.SliderRow(accessCard, "Widget size",
    "Size of the movable floating icon (24 to 128 pixels).",
    Settings.MIN_WIDGET_SIZE, Settings.MAX_WIDGET_SIZE, Settings.WIDGET_SIZE_STEP,
    function(value) Settings.Set("widgetSize", value) end,
    function()
        Settings.Reset("widgetSize")
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    end,
    function(value) return math.floor(value + 0.5) .. " px" end, true)
widgetSize:SetPoint("TOPLEFT", accessCard, "TOPLEFT", 20, -131)
widgetSize:SetPoint("TOPRIGHT", accessCard, "TOPRIGHT", -20, -131)
MarkPosition(widgetSize, accessCard, -131)
RegisterOption("widgetSize", "Widget size",
    "Resize the floating access widget", "interface", widgetSize)

local widgetTransparency = Widgets.SliderRow(accessCard, "Widget transparency",
    "Fade the floating widget when you are not hovering over it.",
    0, Settings.MAX_WIDGET_TRANSPARENCY, 0.05,
    function(value) Settings.Set("widgetTransparency", value) end,
    function()
        Settings.Reset("widgetTransparency")
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    end, nil, true)
widgetTransparency:SetPoint("TOPLEFT", accessCard, "TOPLEFT", 20, -200)
widgetTransparency:SetPoint("TOPRIGHT", accessCard, "TOPRIGHT", -20, -200)
MarkPosition(widgetTransparency, accessCard, -200)
RegisterOption("widgetTransparency", "Widget transparency",
    "Set idle opacity of the floating access icon", "interface", widgetTransparency)

local compartmentToggle = AddToggle(accessCard, "interface",
    "showInCompartment", "Show in AddOn Compartment",
    "Include Duels in Blizzard's AddOn Compartment list (requires /reload).",
    -267, false)
-- Not every WoW client provides the compartment. Hide the action in that
-- case, and explain its unavailable state through the existing row tooltip.
rows[#rows].needsCompartment = true

local resetAccess = Style.Action(accessCard, "Reset icon positions")
resetAccess:SetSize(200, 34)
resetAccess:SetPoint("BOTTOMRIGHT", accessCard, "BOTTOMRIGHT", -22, 16)
resetAccess:SetScript("OnClick", function() Settings.ResetAccessPositions() end)
ns.Tooltips.Bind(resetAccess, {
    title = "Reset icon positions",
    detail = "Restore the minimap button angle and the floating widget's position."
})
RegisterOption("resetIconPositions", "Reset icon positions",
    "Return the minimap and floating widget to their default locations",
    "interface", resetAccess)
MarkPosition(resetAccess, accessCard, -332)
local accessHint = Style.Text(accessCard,
    "Drag either icon to move it. If both are hidden, type /duels to open this window.",
    12, C.muted)
accessHint:SetPoint("BOTTOMLEFT", accessCard, "BOTTOMLEFT", 20, 20)
accessHint:SetPoint("RIGHT", resetAccess, "LEFT", -18, 0)
accessHint:SetJustifyH("LEFT")

-- Interaction help belongs directly beneath its Window behavior controls.
local behaviorInfo = Style.Text(behaviorCard,
    "Hold the eye to Peek. Fold leaves the header visible.",
    12, C.muted)
behaviorInfo:SetPoint("TOPLEFT", behaviorCard, "TOPLEFT", 20, -297)
behaviorInfo:SetPoint("RIGHT", behaviorCard, "RIGHT", -20, 0)
behaviorInfo:SetJustifyH("LEFT")

-- The font-matching hint stays with the font choices, not with Peek/Fold.
local fontInfo = Style.Text(typographyCard,
    "Font matching is controlled under Appearance.",
    12, C.muted)
fontInfo:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -281)
fontInfo:SetPoint("RIGHT", typographyCard, "RIGHT", -20, 0)
fontInfo:SetJustifyH("LEFT")

-- One responsive content layout owner, adapted from the row-pair behavior
-- inspected in Polestar_Options/UI/Options.lua. The original option widgets
-- keep their Settings callbacks, tooltips, reset behavior and scrollbar.
-- Only their positions and presentation change as the scroll width changes.
-- At compact widths we retain ONE readable column; at wider widths we pair
-- appropriate controls in TWO columns. No constant OnUpdate work.
local COLUMN_BREAKPOINT = 630
local COLUMN_GAP, ROW_GAP, SECTION_GAP = 12, 8, 14

local function LayoutPage(page, groups, width)
    width = math.max(1, width or page:GetWidth())
    if width <= 1 then return end
    local two = width >= COLUMN_BREAKPOINT
    local sectionY = 0
    for _, group in ipairs(groups) do
        local card = group.card
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -sectionY)
        card:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -sectionY)
        local usable = math.max(1, width - 58)
        local half = math.max(1, math.floor((usable - COLUMN_GAP) / 2))
        local y, pending, firstHeight = 65, false, 0

        local function Place(entry, x, cellWidth, paired)
            local widget = entry.widget
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", card, "TOPLEFT", 20 + x, -y)
            widget:SetWidth(cellWidth)
            if widget.LayoutForWidth then
                widget:LayoutForWidth(cellWidth, paired)
            elseif entry.height then
                widget:SetHeight(entry.height)
            end
            -- Search targets are derived from LIVE positions after resize,
            -- not the old static -y numbers assigned during initial setup.
            if widget.optionsScroll then
                widget.optionsY = sectionY + y
            end
            return entry.height or widget:GetHeight()
        end

        for _, entry in ipairs(group.entries) do
            if not two or entry.wide then
                if pending then
                    y = y + firstHeight + ROW_GAP
                    pending = false
                end
                y = y + Place(entry, 0, usable, false) + ROW_GAP
            elseif pending then
                local height = Place(entry, half + COLUMN_GAP, half, true)
                y = y + math.max(firstHeight, height) + ROW_GAP
                pending = false
            else
                firstHeight = Place(entry, 0, half, true)
                pending = true
            end
        end
        if pending then y = y + firstHeight + ROW_GAP end
        if group.footer then y = group.footer(card, sectionY, y, usable) end
        card:SetHeight(y + 13)
        sectionY = sectionY + y + 13 + SECTION_GAP
    end
    page:SetHeight(math.max(sectionY, page.scrollOwner:GetHeight()))
    if page.scrollOwner.UpdateScrollChildRect then
        page.scrollOwner:UpdateScrollChildRect()
    end
    page.scrollBar:Refresh()
end

local function FooterNote(label, card, y, width)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -y)
    label:SetWidth(width)
    label:SetHeight(28)
    return y + 30
end

local appearanceGroups = {
    { card = appearanceCard, entries = {
        { widget = themeChoice, wide = true },
        -- The meaning of a disabled/enabled picker lives right under it.
        { widget = availability, wide = true, height = 38 },
        { widget = matchColorsRow },
        { widget = matchFontRow },
    }},
}
local interfaceGroups = {
    { card = behaviorCard, entries = {
        { widget = autoPeekRow }, { widget = reduceMotionRow },
        { widget = tooltipsRow }, { widget = reminderRow },
    }, footer = function(card, _, y, usable)
        return FooterNote(behaviorInfo, card, y, usable)
    end },
    { card = typographyCard, entries = {
        { widget = fontChoice }, { widget = fontScale },
        { widget = fontOutline },
    }, footer = function(card, _, y, usable)
        return FooterNote(fontInfo, card, y, usable)
    end },
    { card = accessCard, entries = {
        { widget = iconMode }, { widget = widgetSize },
        { widget = widgetTransparency }, { widget = compartmentToggle },
    }, footer = function(card, sectionY, y, usable)
        resetAccess:ClearAllPoints()
        resetAccess:SetPoint("TOPRIGHT", card, "TOPRIGHT", -20, -y)
        resetAccess.optionsY = sectionY + y
        resetAccess:SetWidth(math.min(190, usable))
        accessHint:ClearAllPoints()
        accessHint:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -(y + 40))
        accessHint:SetWidth(usable)
        accessHint:SetHeight(34)
        return y + 78
    end },
}
function appearance:Relayout(width) LayoutPage(self, appearanceGroups, width) end
function interface:Relayout(width) LayoutPage(self, interfaceGroups, width) end
appearance:Relayout(appearance:GetWidth())
interface:Relayout(interface:GetWidth())

-- During a live slider drag repaint only its reset/modified indicator.
-- A full Refresh would programmatically reassign the active thumb.
function Options.RefreshAccessModified()
    widgetSize:SetModified(Settings.IsModified("widgetSize"))
    widgetTransparency:SetModified(Settings.IsModified("widgetTransparency"))
end

function Options.Refresh()
    local ready = Theme.IsAvailable()
    local matchedColors = ready and Settings.Get("matchColors") == true
    themeChoice:SetChoices(Style.ThemeChoices(), Settings.Get("uiTheme"),
        matchedColors and "Managed by EllesmereUI" or nil)
    themeChoice:SetAvailable(not matchedColors,
        "Disable Match EllesmereUI colors to choose a Duels color theme.")
    themeChoice:SetModified(Settings.IsModified("uiTheme"))
    themeChoice.resetIcon:SetVertexColor(unpack(C.gold))
    local compartmentAvailable = AddonCompartmentFrame and
        type(AddonCompartmentFrame.RegisterAddon) == "function"
    if not ready then
        availability:SetText("Duels theme is active. EllesmereUI is unavailable, so its color and font matching are disabled.")
    elseif matchedColors then
        availability:SetText("EllesmereUI controls the interface colors. Disable color matching below to choose a Duels theme.")
    else
        availability:SetText("Duels theme colors are active. Enable Match EllesmereUI colors below to use its palette instead.")
    end
    availability:SetTextColor(unpack(C.muted))
    for _, entry in ipairs(rows) do
        local widget = entry.widget
        widget:RefreshColors()
        local canUse = (not entry.needsEllesmere or ready) and
            (not entry.needsCompartment or compartmentAvailable)
        widget:SetAvailable(canUse,
            entry.needsEllesmere and unavailable or
            (entry.needsCompartment and not compartmentAvailable and
                "The AddOn Compartment is unavailable on this WoW client." or nil))
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
    iconMode:SetChoices(accessModes, Settings.Get("iconMode"))
    iconMode:SetAvailable(true)
    iconMode:SetModified(Settings.IsModified("iconMode"))
    widgetSize:SetValue(Settings.Get("widgetSize"))
    widgetSize:SetModified(Settings.IsModified("widgetSize"))
    widgetSize:RefreshColors()
    widgetTransparency:SetValue(Settings.Get("widgetTransparency"))
    widgetTransparency:SetModified(Settings.IsModified("widgetTransparency"))
    widgetTransparency:RefreshColors()
    local mode = Settings.Get("iconMode")
    local hasWidget = mode == "widget" or mode == "both"
    widgetSize:SetAvailable(hasWidget)
    widgetTransparency:SetAvailable(hasWidget)
    -- Disabled sliders must still explain how to make them available.
    widgetSize.description:SetText(hasWidget and
        "Size of the movable floating icon (24 to 128 pixels)." or
        "Choose Widget or Both in Icon mode to change widget size.")
    widgetTransparency.description:SetText(hasWidget and
        "Fade the floating widget when you are not hovering over it." or
        "Choose Widget or Both in Icon mode to change transparency.")
    resetAccess:SetEnabled(true)
    appearance.scrollBar:Refresh()
    interface.scrollBar:Refresh()
end

function Options.Show(pageKey)
    Widgets.CloseChoices()
    appearance.scrollOwner:SetShown(pageKey == "options")
    interface.scrollOwner:SetShown(pageKey == "interface")
    if pageKey == "options" then appearance:Relayout(appearance:GetWidth()) end
    if pageKey == "interface" then interface:Relayout(interface:GetWidth()) end
    if pageKey == "options" or pageKey == "interface" then Options.Refresh() end
end

Window.frame:HookScript("OnHide", Widgets.CloseChoices)
Theme.Refresh()

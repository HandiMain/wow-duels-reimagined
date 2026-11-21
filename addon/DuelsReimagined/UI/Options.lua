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
    -- Leave a comfortable gap below the page subtitle, even with a short card.
    scroll:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 26, -153)
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

-- The approved icon/title/subtitle/motif artwork is alpha-only. Render it
-- DIRECTLY over the card body's near-black fill. The former ambient PNG
-- painted the unwanted light-brown rectangle behind the entire header.
-- One cardBody 9-slice is still the only border owner; no header fill,
-- duplicate frame, font substitution, or stretched center slice.
local BANNER_ART = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelOptionsSoftArt.png"
local BANNER_ATLAS_W, BANNER_ATLAS_H = 2048, 256
local BANNER_CELL_W, BANNER_CELL_H = 640, 80
local BANNER_LEFT, BANNER_RIGHT = 438, 160
local bannerIndices = {
    appearance = 0,
    motion = 1,
    access = 2,
    minimap = 3,
    typography = 4,
    notifications = 5,
}

local function Card(page, y, height)
    local card = CreateFrame("Frame", nil, page)
    card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    card:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -y)
    card:SetHeight(height)
    Style.Plate(card, "cardBody", { corner=15 })

    -- The banner is inset past the card's existing gold rim. It has NO
    -- baked strokes: only artwork/title/subtitle/motif can paint here.
    local headingBand = CreateFrame("Frame", nil, card)
    headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -6)
    headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -6)
    headingBand:SetHeight(62)
    headingBand:EnableMouse(false)
    if headingBand.SetClipsChildren then headingBand:SetClipsChildren(true) end
    card.optionsBand = headingBand

    -- A single native divider links the banner to the real settings body.
    -- The frame's existing 9-slice alone owns all four outside edges.
    local divider = Style.Fill(card, C.goldDim, "ARTWORK")
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -72)
    divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -72)
    divider:SetHeight(1)
    divider:SetAlpha(0.60)
    card.scrollOwner, card.scrollTop = page.scrollOwner, y
    return card
end

local appearance = Page(130)
local interface = Page(740)

-- Every preference stays on the SAME Interface page and uses the existing
-- whole-card responsive layout. No extra tab or separate settings owner.
local appearanceCard = Card(appearance, 0, 165)
local behaviorCard = Card(interface, 0, 100)
local gameAccessCard = Card(interface, 108, 100)
local accessCard = Card(interface, 216, 174)
local typographyCard = Card(interface, 398, 143)
local notificationsCard = Card(interface, 549, 100)

-- Same header renderer on Appearance and Interface. Gold labels, icons,
-- and motifs remain the approved source pixels. The middle stays empty and
-- dark; there is deliberately NO separate backdrop beneath the artwork.
local function Section(card, key, title, help, extra)
    local index = assert(bannerIndices[key], "Unknown Duels Options banner")
    local band = card.optionsBand
    local header = CreateFrame("Frame", nil, band)
    header:SetAllPoints(band)
    header:EnableMouse(true)

    local spriteX = (index % 2) * BANNER_CELL_W
    local spriteY = math.floor(index / 2) * BANNER_CELL_H
    local function Slice(fromX, toX)
        local piece = header:CreateTexture(nil, "ARTWORK", nil, 4)
        piece:SetTexture(BANNER_ART)
        piece:SetTexCoord(
            (spriteX + fromX) / BANNER_ATLAS_W,
            (spriteX + toX) / BANNER_ATLAS_W,
            spriteY / BANNER_ATLAS_H,
            (spriteY + BANNER_CELL_H) / BANNER_ATLAS_H)
        if ns.Chrome and ns.Chrome.Sharp then ns.Chrome.Sharp(piece) end
        return piece
    end
    -- Two independent textures for sharp artwork at any card width.
    -- There is no center strip to magnify or truncate the approved design.
    local left = Slice(0, BANNER_LEFT)
    local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)
    -- Keep a real two-pixel breathing space above/below the bitmap:
    -- formerly the subtitle descenders sat against the 50px clip edge.
    left:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -2)
    right:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -2)

    local function FitSlices(self)
        local width = math.max(1, self:GetWidth())
        local height = math.max(1, self:GetHeight())
        local scale = math.min(math.max(1, height - 4) / BANNER_CELL_H,
            math.max(0.01, (width - 12) / (BANNER_LEFT + BANNER_RIGHT)))
        left:SetSize(math.max(1, BANNER_LEFT * scale),
            math.max(1, BANNER_CELL_H * scale))
        right:SetSize(math.max(1, BANNER_RIGHT * scale),
            math.max(1, BANNER_CELL_H * scale))
    end
    header:SetScript("OnSizeChanged", FitSlices)
    FitSlices(header)

    -- Baked titles still have accessible, current explanatory tooltips.
    -- No fake row controls; do not attach handlers to texture regions.
    ns.Tooltips.Bind(header, {
        title = title,
        detail = help .. (extra and (" " .. extra) or ""),
        anchor = "RIGHT",
    })
    card.optionsHeading = header
    return header
end

local appearanceDescription = Section(appearanceCard, "appearance", "Appearance",
    "Duel Hall is our permanent design; optional font matching is available.")
local availability = Style.Text(appearanceCard, "", 12, C.muted)
availability:SetJustifyH("LEFT")
availability:SetWordWrap(true)
availability:SetPoint("TOPLEFT", appearanceCard, "TOPLEFT", 20, -131)
Section(behaviorCard, "motion", "Window & Motion",
    "Control how Duels moves, fades and responds while you play.",
    "Hold the eye to Peek. Fold leaves the header visible.")
Section(gameAccessCard, "access", "Game Access",
    "Choose where to open Duels from Blizzard's interface.",
    "The Escape menu button uses Blizzard's normal look unless EllesmereUI skins it.")
Section(accessCard, "minimap", "Minimap & Widget",
    "Choose your minimap button or floating widget.",
    "Drag either icon to move it. If both are hidden, type /duels to open this window.")
Section(typographyCard, "typography", "Typography",
    "Choose text appearance independently of window scale.",
    "Font matching is controlled under Appearance.")
Section(notificationsCard, "notifications", "Notifications & Help",
    "Choose which hints and update reminders Duels shows.",
    "These controls do not change gameplay notifications.")

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
            -- BurstFX's 2-pulse destination outline: it follows the same
            -- real widget/search target and cancels the previous pulse.
            if widget and ns.Feedback then ns.Feedback.PulseTarget(widget) end
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

local matchFontRow = AddToggle(appearanceCard, "options", "matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -61, true)
local autoPeekRow = AddToggle(behaviorCard, "interface", "autoPeekMoving", "Automatic Peek while moving",
    "Fade the window during movement; restore it when you stop.", -64, false)
local reduceMotionRow = AddToggle(behaviorCard, "interface", "reduceMotion", "Reduce motion",
    "Shorten or skip UI animation while retaining visual feedback.", -119, false)
local tooltipsRow = AddToggle(notificationsCard, "interface", "showTooltips", "Show addon tooltips",
    "Show helpful descriptions when hovering over Duels controls.", -64, false)
local reminderRow = AddToggle(notificationsCard, "interface", "patchNotesReminder", "New patch reminder",
    "Show a subtle unread dot on Patch Notes when a new update is published.",
    -119, false)
local gameMenuRow = AddToggle(gameAccessCard, "interface", "showGameMenuButton", "Show Escape menu button",
    "Add Duels Reimagined to Blizzard's Escape menu. Uses Blizzard's normal look unless EllesmereUI skins that menu.",
    -64, false)

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
    "Resize the floating access widget; hover to show a live widget preview",
    "interface", widgetSize)

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
-- Miniatures are anchored to our own window, without changing any setting
-- or intercepting the live slider. Both rows can show the same preview.
if ns.Feedback then
    ns.Feedback.BindWidgetPreview(widgetSize)
    ns.Feedback.BindWidgetPreview(widgetTransparency)
    ns.Feedback.NewBadge(widgetSize, "widget-preview-v1", true)
end

local compartmentToggle = AddToggle(gameAccessCard, "interface",
    "showInCompartment", "Show in AddOn Compartment",
    "Include Duels in Blizzard's AddOn Compartment list (requires /reload).",
    -119, false)
-- Not every WoW client provides the compartment. Hide the action in that
-- case, and explain its unavailable state through the existing row tooltip.
rows[#rows].needsCompartment = true

local resetAccess = Style.Action(accessCard, "Reset icon positions")
resetAccess:SetSize(200, 34)
resetAccess:SetPoint("BOTTOMRIGHT", accessCard, "BOTTOMRIGHT", -22, 16)
resetAccess:SetScript("OnClick", function()
    Settings.ResetAccessPositions()
    if ns.Feedback then
        ns.Feedback.ConfirmAction(resetAccess, "Positions restored")
    end
end)
ns.Tooltips.Bind(resetAccess, {
    title = "Reset icon positions",
    detail = "Restore the minimap button angle and the floating widget's position."
})
RegisterOption("resetIconPositions", "Reset icon positions",
    "Return the minimap and floating widget to their default locations",
    "interface", resetAccess)
MarkPosition(resetAccess, accessCard, -332)
-- One responsive card-layout owner. Keep all controls inside their original
-- section card; change the number of CARDS per row, never the settings order
-- inside a card. At compact widths stack complete cards. At wider widths,
-- two Interface cards fit side by side; Appearance's lone card stays full width.
-- Polestar's section-height measurement informed this approach; no source
-- copied, and all Settings/Search/scroll/tooltip owners remain unchanged.
local CARD_BREAKPOINT = 720
local CARD_GAP, SECTION_GAP, ROW_GAP = 14, 8, 1
local BANNER_HEIGHT = 62
local ROW_TOP = 80

local function LayoutPage(page, groups, width)
    width = math.max(1, width or page:GetWidth())
    if width <= 1 then return end
    local largeText = (Settings.Get("fontScale") or 1) > 1.20
    -- Each half-card must still be wide enough for a label AND its control.
    -- A page with only one card (Appearance) always uses the full width.
    local twoCards = #groups > 1 and
        width >= (largeText and 1080 or CARD_BREAKPOINT)
    local columns = twoCards and 2 or 1
    local fullWidth = math.max(1, width - 18)
    local cardWidth = columns == 2 and
        math.floor((fullWidth - CARD_GAP) / 2) or fullWidth
    local usable = math.max(1, cardWidth - 40)
    local sectionY, tallest = 0, 0
    local isAppearance = page == appearance
    -- Native, concept-extracted banners follow the same compact/stacked grid.
    local rowGap = largeText and 4 or (isAppearance and 4 or ROW_GAP)

    for index, group in ipairs(groups) do
        local column = (index - 1) % columns
        if index > 1 and column == 0 then
            sectionY = sectionY + tallest + SECTION_GAP
            tallest = 0
        end
        local card = group.card
        local cardX = column * (cardWidth + CARD_GAP)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", page, "TOPLEFT", cardX, -sectionY)
        card:SetWidth(cardWidth)
        -- At 125-150% text, trade density for fully readable rows.
        if card.optionsBand then
            card.optionsBand:SetHeight(BANNER_HEIGHT)
        end

        local y = largeText and 94 or ROW_TOP
        for _, entry in ipairs(group.entries) do
            local widget = entry.widget
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -y)
            widget:SetWidth(usable)
            -- Appearance's font-status explanation grows with font size.
            if widget == availability then
                entry.height = math.max(26,
                    math.ceil(widget:GetStringHeight() or 18) + 8)
            end
            -- Keep one setting per line in each intact card. Large fonts
            -- fall back to the original descriptive row layout.
            if widget.LayoutForWidth then
                widget:LayoutForWidth(usable, not largeText)
            elseif entry.height then
                widget:SetHeight(entry.height)
            end
            if isAppearance and not largeText then
                widget:SetHeight(widget:GetHeight() + 6)
            end
            if widget.optionsScroll then
                -- Search follows the card into its new grid row on resize.
                widget.optionsY = sectionY + y
            end
            y = y + widget:GetHeight() + rowGap
        end
        if group.footer then y = group.footer(card, sectionY, y, usable) end
        local cardHeight = y + (isAppearance and 10 or 6)
        card:SetHeight(cardHeight)
        tallest = math.max(tallest, cardHeight)
    end

    local contentHeight = sectionY + tallest + 6
    -- Avoid a full-height phantom scrollbar from fractional UI scaling.
    local viewHeight = page.scrollOwner:GetHeight()
    page:SetHeight(contentHeight > viewHeight + 1 and contentHeight or
        math.max(1, viewHeight - 0.5))
    if page.scrollOwner.UpdateScrollChildRect then
        page.scrollOwner:UpdateScrollChildRect()
    end
    -- A wide layout can become shorter than the previous narrow scroll
    -- extent; reset only out-of-bounds scroll, not the chosen page.
    local maxScroll = math.max(0,
        page:GetHeight() - page.scrollOwner:GetHeight())
    if page.scrollOwner:GetVerticalScroll() > maxScroll then
        page.scrollOwner:SetVerticalScroll(maxScroll)
    end
    page.scrollBar:Refresh()
end

local appearanceGroups = {
    { card = appearanceCard, entries = {
        { widget = matchFontRow },
        { widget = availability, height = 26 },
    }},
}
local interfaceGroups = {
    { card = behaviorCard, entries = {
        { widget = autoPeekRow }, { widget = reduceMotionRow },
    }},
    { card = gameAccessCard, entries = {
        { widget = gameMenuRow }, { widget = compartmentToggle },
    }},
    { card = accessCard, entries = {
        { widget = iconMode }, { widget = widgetSize },
        { widget = widgetTransparency },
    }, footer = function(card, sectionY, y, usable)
        local buttonY = y + 4
        resetAccess:ClearAllPoints()
        resetAccess:SetPoint("TOPRIGHT", card, "TOPRIGHT", -20, -buttonY)
        resetAccess.optionsY = sectionY + buttonY
        resetAccess:SetWidth(math.min(190, usable))
        return buttonY + resetAccess:GetHeight()
    end },
    { card = typographyCard, entries = {
        { widget = fontChoice }, { widget = fontScale },
        { widget = fontOutline },
    }},
    { card = notificationsCard, entries = {
        { widget = tooltipsRow }, { widget = reminderRow },
    }},
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
    -- The widget sliders already update live. Repaint only the noninteractive
    -- miniature; never replace an in-progress thumb/slider value.
    if ns.Feedback then ns.Feedback.RefreshWidgetPreview() end
end

function Options.Refresh()
    local ready = Theme.IsAvailable()
    local compartmentAvailable = AddonCompartmentFrame and
        type(AddonCompartmentFrame.RegisterAddon) == "function"
    if not ready then
        availability:SetText("Duel Hall colors are fixed. Font matching requires EllesmereUI.")
    elseif Settings.Get("matchFont") then
        availability:SetText("Using EllesmereUI's font. Duel Hall colors and artwork stay unchanged.")
    else
        availability:SetText("Duel Hall colors are fixed. Enable font matching to use EllesmereUI's font.")
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
    if ns.Feedback then ns.Feedback.RefreshWidgetPreview() end
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
    -- Font scaling can change the one/two-column breakpoint without
    -- changing window dimensions. Keep the adaptive layout in sync.
    appearance:Relayout(appearance:GetWidth())
    interface:Relayout(interface:GetWidth())
    appearance.scrollBar:Refresh()
    interface.scrollBar:Refresh()
end

-- Navigation only requests positions; this module remains the single owner
-- of both Options scroll frames, and clamps restored offsets after reflow.
local function ScrollPage(key)
    if key == "options" then return appearance end
    if key == "interface" then return interface end
end
function Options.GetPageScroll(pageKey)
    local page = ScrollPage(pageKey)
    return page and page.scrollOwner:GetVerticalScroll() or 0
end
function Options.SetPageScroll(pageKey, offset)
    local page = ScrollPage(pageKey)
    if not page or type(offset) ~= "number" then return end
    local owner = page.scrollOwner
    page:Relayout(page:GetWidth())
    local limit = math.max(0, page:GetHeight() - owner:GetHeight())
    owner:SetVerticalScroll(math.max(0, math.min(limit, offset)))
    page.scrollBar:Refresh()
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

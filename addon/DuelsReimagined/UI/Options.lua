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

-- The approved gold icon/title/subtitle/motif artwork now has genuinely
-- cleaned alpha. A brown source strip ALSO exists inside the original
-- cardBody 9-slice's upper edge. Card() masks only its interior inset while
-- leaving the perimeter texture and its corners intact; no separate banner
-- backdrop or stretched center slice is needed.
local BANNER_ART = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelOptionsBanner.png"
local COMPLETE_PALETTE = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelPaletteMarks.tga"
local BANNER_ATLAS_W, BANNER_ATLAS_H = 2048, 256
local BANNER_CELL_W, BANNER_CELL_H = 640, 80
local BANNER_LEFT, BANNER_RIGHT = 112, 160
local BANNER_REFERENCE_WIDTH = 598 -- retain original artwork scale, not its lettering
local bannerIndices = {
    appearance = 0,
    motion = 1,
    access = 2,
    minimap = 3,
    typography = 4,
    notifications = 5,
    widget = 0,
    widgetNotifications = 0,
    countdown = 0,
}
local bannerSubtitles = {
    appearance="FONT MATCHING & VISUAL IDENTITY",
    motion="MOVEMENT, BEHAVIOR & PERFORMANCE",
    access="GAME MENU & ADDON INTEGRATION",
    minimap="MINIMAP & FLOATING ACCESS ICON",
    typography="INTERFACE FONT & TEXT STYLING",
    notifications="TOOLTIPS, REMINDERS & GUIDANCE",
    widget="POSITION, SIZE & BEHAVIOR",
    widgetNotifications="ALERTS, SOUNDS & PREVIEWS",
    countdown="DUEL START & COUNTDOWN",
}

local function Card(page, y, height)
    local card = CreateFrame("Frame", nil, page)
    card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    card:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -y)
    card:SetHeight(height)
    Style.Plate(card, "cardBody", { corner=15 })

    -- The brown band was baked into the top of the cardBody 9-slice atlas,
    -- NOT into the old banner gradient alone. The shared plate retains the
    -- approved copper outer rim, but this inset, near-black underlay hides
    -- the source's sepia top fill without covering those outside gold edges.
    -- BORDER sublevel 5 draws above cardBody's sublevel 4 and below ALL
    -- interactive rows, titles, icons and gold decorative text.
    local cleanTop = card:CreateTexture(nil, "BORDER", nil, 5)
    cleanTop:SetColorTexture(unpack(C.window))
    cleanTop:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -5)
    cleanTop:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, -5)
    cleanTop:SetHeight(21)

    -- The banner is inset past the card's existing gold rim. It has NO
    -- baked strokes: only artwork/title/subtitle/motif can paint here.
    local headingBand = CreateFrame("Frame", nil, card)
    headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -6)
    headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -6)
    headingBand:SetHeight(72)
    headingBand:EnableMouse(false)
    -- The fixed artwork includes full-height glyphs and subtitle descenders;
    -- clipping this frame cuts letters at some render scales.
    if headingBand.SetClipsChildren then headingBand:SetClipsChildren(false) end
    card.optionsBand = headingBand

    -- A single native divider links the banner to the real settings body.
    -- The frame's existing 9-slice alone owns all four outside edges.
    local divider = Style.Fill(card, C.goldDim, "ARTWORK")
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -82)
    divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -82)
    divider:SetHeight(1)
    divider:SetAlpha(0.60)
    card.scrollOwner, card.scrollTop = page.scrollOwner, y
    return card
end

local appearance = Page(130)
local interface = Page(740)
local widgetPage = Page(480)
local combatVisuals = Page(180)
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Options / Appearance",appearance.scrollOwner) end
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Options / Interface",interface.scrollOwner) end

-- Four subcategories, one Options owner and one responsive layout.
local appearanceCard = Card(appearance, 0, 165)
local behaviorCard = Card(interface, 0, 100)
local gameAccessCard = Card(interface, 108, 100)
local accessCard = Card(interface, 216, 174)
local typographyCard = Card(interface, 398, 143)
local notificationsCard = Card(interface, 549, 100)
local hudCard = Card(widgetPage, 0, 290)
local hudNotificationsCard = Card(widgetPage, 298, 340)
local countdownCard = Card(combatVisuals, 0, 180)
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Options / Combat Visuals",combatVisuals.scrollOwner) end
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Options / Widget",widgetPage.scrollOwner) end

-- One header renderer for all Options pages: live font labels, gold icon
-- art and motifs, without a separate backdrop.
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
    -- Use only the icon and decorative motif slices. Never draw the old
    -- atlas lettering: all eight titles/subtitles are live shared fonts.
    local left = Slice(0, BANNER_LEFT)
    local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)
    local isAppearance = key == "appearance"
    local nativeWidget = key == "widget" or key == "widgetNotifications" or key == "minimap" or key == "countdown"
    local nativeMotif
    if isAppearance then
        left:Hide()
        local palette = header:CreateTexture(nil, "ARTWORK", nil, 6)
        palette:SetTexture(COMPLETE_PALETTE)
        palette:SetSize(37, 37)
        palette:SetPoint("CENTER", header, "LEFT", 50, 0)
        local motifPalette = header:CreateTexture(nil, "ARTWORK", nil, 6)
        motifPalette:SetTexture(COMPLETE_PALETTE)
        motifPalette:SetSize(33, 33)
        motifPalette:SetPoint("CENTER", header, "RIGHT", -69, 0)
        ns.Chrome.Sharp(palette);ns.Chrome.Sharp(motifPalette)
        card.appearancePalette, card.appearanceMotifPalette = palette, motifPalette
    elseif nativeWidget then
        left:Hide();right:Hide()
        local kind=key=="widgetNotifications" and "notifications" or key=="minimap" and "launcher" or key=="countdown" and "countdown" or "widget"
        local nativeIcon=ns.Chrome.WidgetGlyph(header,kind,34)
        nativeIcon:SetPoint("CENTER",header,"LEFT",50,0)
        nativeMotif=ns.Chrome.WidgetGlyph(header,kind,46)
        nativeMotif:SetPoint("RIGHT",header,"RIGHT",-19,0)
        nativeMotif:SetAlpha(.38)
    end
    left:SetPoint("LEFT", header, "LEFT", 0, 0)
    right:SetPoint("RIGHT", header, "RIGHT", 0, 0)

    local name = Style.Text(header, title, 20, C.pale)
    local sub = Style.Text(header, bannerSubtitles[key], 10, C.muted)
    name:SetWordWrap(false);sub:SetWordWrap(false)
    name:SetShadowColor(0,0,0,.85);name:SetShadowOffset(1,-1)
    sub:SetShadowColor(0,0,0,.8);sub:SetShadowOffset(1,-1)
    name:SetPoint("TOPLEFT",header,"TOPLEFT",88,-10)
    sub:SetPoint("TOPLEFT",header,"TOPLEFT",88,-42)
    card.optionsTitle,card.optionsSubtitle=name,sub

    local function FitSlices(self)
        local width = math.max(1, self:GetWidth())
        local height = math.max(1, self:GetHeight())
        local scale = math.min(math.max(1, height - 8) / BANNER_CELL_H,
            math.max(0.01, (width - 24) / BANNER_REFERENCE_WIDTH))
        left:SetSize(math.max(1, BANNER_LEFT * scale),
            math.max(1, BANNER_CELL_H * scale))
        right:SetSize(math.max(1, BANNER_RIGHT * scale),
            math.max(1, BANNER_CELL_H * scale))
        local motifWidth=nativeWidget and 75 or math.max(100,BANNER_RIGHT*scale)
        local showMotif=width-88-motifWidth>=190
        right:SetShown(not nativeWidget and showMotif)
        if nativeMotif then nativeMotif:SetShown(showMotif) end
        if isAppearance then card.appearanceMotifPalette:SetShown(showMotif) end
        local room=math.max(1,width-88-(showMotif and motifWidth or 8))
        name:SetSize(room,30);sub:SetSize(room,19)
        Style.ConstrainText(name,room,30,9)
        Style.ConstrainText(sub,room,19,7)
    end
    header:SetScript("OnSizeChanged", FitSlices)
    FitSlices(header)

    -- All live headings retain their original tooltips.
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
Section(accessCard, "minimap", "Minimap & Launcher",
    "Choose your minimap button or floating access icon.",
    "Drag either icon to move it. If both are hidden, type /duels to open this window.")
Section(typographyCard, "typography", "Typography",
    "Choose text appearance independently of window scale.",
    "Font matching is controlled under Appearance.")
Section(notificationsCard, "notifications", "Notifications & Help",
    "Choose which hints and notifications Duels shows.",
    "Patch reminders and shared addon tooltips.")
Section(hudCard, "widget", "Duel Widget",
    "Customize the independent duel companion.")
Section(hudNotificationsCard, "widgetNotifications", "Notifications",
    "Choose the notifications attached to your duel companion.",
    "Notification audio follows Blizzard's Effects volume.")
Section(countdownCard,"countdown","Duel Countdown",
    "Show a cinematic countdown when a duel begins.",
    "The fight cue follows the observed Blizzard countdown; reduced motion is respected.")

local unavailable = "Enable EllesmereUI and its third-party skinning support to use this setting."
local rows = {}

local function MarkPosition(row, card, top)
    row.optionsScroll, row.optionsY = card.scrollOwner, card.scrollTop - top
    return row
end

-- Search must reveal the target in scrollable pages, not merely select a page
-- while the relevant row remains below the viewport.
local function RegisterOption(key, name, detail, pageKey, widget, available)
    ns.Search.Register("setting:" .. key, name,
        "Options / " .. (pageKey == "options" and "Appearance" or pageKey == "widget" and "Widget" or pageKey == "combatvisuals" and "Combat Visuals" or "Interface"),
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
            -- our earlier addon's 2-pulse destination outline: it follows the same
            -- real widget/search target and cancels the previous pulse.
            if widget and ns.Feedback then ns.Feedback.PulseTarget(widget) end
        end, available)
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
local hudEnabledRow=AddToggle(hudCard,"widget","duelHUDEnabled","Show Duel Widget",
    "Show the independent duel companion, separate from the floating access icon.",-90,false)
local hudLockRow=AddToggle(hudCard,"widget","duelHUDLocked","Lock position",
    "Prevent moving the duel companion by its header.",-119,false)
local hudAdaptiveRow=AddToggle(hudCard,"widget","duelHUDAdaptive","Adaptive layout",
    "Automatically resize as the duel state changes. Off keeps a fixed height.",-148,false)
local hudStatsRow=AddToggle(hudCard,"widget","duelHUDSessionStats","Show session statistics",
    "Show recorded duels, wins, losses and confirmed rating changes. Live recording must be enabled.",-178,false)
local countdownRow=AddToggle(countdownCard,"combatvisuals","duelCountdownVisual","Show duel countdown",
    "Animate the numbers and FIGHT! when a duel starts. Works independently of the Duel Widget.",-90,false)
local countdownPreview=Style.Action(countdownCard,"Preview countdown","footer")
countdownPreview:SetHeight(30)
MarkPosition(countdownPreview,countdownCard,-125)
countdownPreview:SetScript("OnClick",function()
    local ok,why=ns.DuelCountdown.Preview()
    if not ok and ns.Feedback then ns.Feedback.Toast(why,countdownPreview) end
end)
RegisterOption("previewDuelCountdown","Preview countdown","Play the countdown animation without starting a duel","combatvisuals",countdownPreview)
local consentRow
if ns.CompetitiveStorage and ns.CompetitiveStorage.PeerEpoch() then
    consentRow = AddToggle(behaviorCard,"interface","competitiveConsent","Allow competitive duel exchange",
        "Opt in to compatible peer agreements before the countdown. Never accepts a duel automatically.",-229,false)
end
local warConsentRow
if ns.WarGames and ns.WarGames.PeerTestingEnabled() then
    warConsentRow=AddToggle(behaviorCard,"interface","warGamesConsent","War Games captain exchange",
        "Allow selected captains to exchange match setup and current readiness. Does not accept or send challenges.",-284,false)
end
local tooltipsRow = AddToggle(notificationsCard, "interface", "showTooltips", "Show addon tooltips",
    "Show helpful descriptions when hovering over Duels controls.", -64, false)
local reminderRow = AddToggle(notificationsCard, "interface", "patchNotesReminder", "New patch reminder",
    "Show a subtle unread dot on Patch Notes when a new update is published.",
    -119, false)
local notifyRow=AddToggle(hudNotificationsCard,"widget","notificationEnabled","Show notifications",
    "Show cards while the Duel HUD is visible or folded. Hiding the HUD disables notifications. Never interrupts duels or combat.",-174,false)
local notifySoundRow=AddToggle(hudNotificationsCard,"widget","notificationSounds","Notification sounds",
    "Play your notification sound through Blizzard's Effects channel.",-230,false)
local notifyPreview=Style.Action(hudNotificationsCard,"Preview update notification","footer")
notifyPreview:SetHeight(30)
MarkPosition(notifyPreview,hudNotificationsCard,-284)
notifyPreview:SetScript("OnClick",function()
    if ns.Notifications then
        local ok,why=ns.Notifications.Preview()
        if not ok and ns.Feedback then ns.Feedback.Toast(why,notifyPreview) end
    end
end)
RegisterOption("previewUpdateNotification","Preview update notification",
    "Preview the update card and its sound without inventing a real release.","widget",notifyPreview)
local promotionPreview=Style.Action(hudNotificationsCard,"Preview rank promotion","footer")
promotionPreview:SetHeight(30)
MarkPosition(promotionPreview,hudNotificationsCard,-322)
promotionPreview:SetScript("OnClick",function()
    if ns.Notifications then
        local ok,why=ns.Notifications.PreviewPromotion()
        if not ok and ns.Feedback then ns.Feedback.Toast(why,promotionPreview) end
    end
end)
RegisterOption("previewRankPromotion","Preview rank promotion",
    "Simulate a promotion without changing ranks, rating or duel history.","widget",promotionPreview)
local achievementPreview=Style.Action(hudNotificationsCard,"Preview achievement notification","footer")
achievementPreview:SetHeight(30)
MarkPosition(achievementPreview,hudNotificationsCard,-360)
achievementPreview:SetScript("OnClick",function()
    if ns.Notifications then
        local ok,why=ns.Notifications.PreviewAchievement()
        if not ok and ns.Feedback then ns.Feedback.Toast(why,achievementPreview) end
    end
end)
RegisterOption("previewAchievement","Preview achievement notification",
    "Preview the achievement card and sound without awarding points.","widget",achievementPreview)
local warningPreview=Style.Action(hudNotificationsCard,"Preview warning notification","footer")
warningPreview:SetHeight(30)
MarkPosition(warningPreview,hudNotificationsCard,-398)
warningPreview:SetScript("OnClick",function()
    if ns.Notifications then
        local ok,why=ns.Notifications.PreviewWarning()
        if not ok and ns.Feedback then ns.Feedback.Toast(why,warningPreview) end
    end
end)
RegisterOption("previewWarning","Preview warning notification",
    "Preview the compact warning card without changing duel results.","widget",warningPreview)
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

-- our earlier addon access behavior: one shared owner controls minimap and widget.
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

local function HasMinimap()
    local mode = Settings.Get("iconMode")
    return mode == "minimap" or mode == "both"
end
local function HasWidget()
    local mode = Settings.Get("iconMode")
    return mode == "widget" or mode == "both"
end
local minimapSize = Widgets.SliderRow(accessCard, "Minimap icon size",
    "Resize the minimap icon (24 to 64 pixels).",
    Settings.MIN_MINIMAP_SIZE, Settings.MAX_MINIMAP_SIZE, Settings.MINIMAP_SIZE_STEP,
    function(value) Settings.Set("minimapSize", value) end,
    function()
        Settings.Reset("minimapSize")
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    end,
    function(value) return math.floor(value + 0.5) .. " px" end, true)
MarkPosition(minimapSize, accessCard, -131)
RegisterOption("minimapSize", "Minimap icon size",
    "Resize the minimap button live.", "interface", minimapSize, HasMinimap)
local minimapTransparency = Widgets.SliderRow(accessCard, "Minimap transparency",
    "Fade the minimap icon when you are not hovering over it.",
    0, Settings.MAX_MINIMAP_TRANSPARENCY, 0.05,
    function(value) Settings.Set("minimapTransparency", value) end,
    function()
        Settings.Reset("minimapTransparency")
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    end, nil, true)
MarkPosition(minimapTransparency, accessCard, -200)
RegisterOption("minimapTransparency", "Minimap transparency",
    "Set idle opacity of the minimap icon.", "interface", minimapTransparency, HasMinimap)

local widgetSize = Widgets.SliderRow(accessCard, "Floating icon size",
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
RegisterOption("widgetSize", "Floating icon size",
    "Resize the floating access widget; hover to show a live widget preview",
    "interface", widgetSize, HasWidget)

local hudScale=Widgets.SliderRow(hudCard,"Widget scale",
    "Resize the duel companion, from 80% to 120%.",
    .8,1.2,.05,function(v) Settings.Set("duelHUDScale",v) end,
    function() Settings.Reset("duelHUDScale") end,
    function(v) return math.floor(v*100+.5).."%" end,true)
MarkPosition(hudScale,hudCard,-178)
RegisterOption("duelHUDScale","Duel Widget scale","Size of the duel companion","widget",hudScale)
local hudOpacity=Widgets.SliderRow(hudCard,"Widget opacity",
    "Set idle opacity (30–100%). Hovering or dueling restores full visibility.",
    .3,1,.05,function(v) Settings.Set("duelHUDOpacity",v) end,
    function() Settings.Reset("duelHUDOpacity") end,nil,true)
MarkPosition(hudOpacity,hudCard,-210)
RegisterOption("duelHUDOpacity","Duel Widget opacity","Set the idle transparency of the duel companion","widget",hudOpacity)
local resetHUD=Style.Action(hudCard,"Reset widget position","footer")
resetHUD:SetHeight(30)
MarkPosition(resetHUD,hudCard,-248)
resetHUD:SetScript("OnClick",function()
    Settings.ResetDuelHUDPosition()
    if ns.Feedback then ns.Feedback.ConfirmAction(resetHUD,"Position restored") end
end)
RegisterOption("resetDuelHUDPosition","Reset Duel Widget position","Restore the duel companion's position","widget",resetHUD)
local sessionPreviewButton=Style.Action(hudCard,"Preview session statistics","footer")
sessionPreviewButton:SetHeight(30)
MarkPosition(sessionPreviewButton,hudCard,-280)
sessionPreviewButton:SetScript("OnClick",function()
    local ok,why=ns.DuelHUD.ToggleSessionPreview()
    if not ok and ns.Feedback then ns.Feedback.Toast(why,sessionPreviewButton) end
end)
RegisterOption("previewSessionStats","Preview session statistics","Show simulated session numbers without recording a duel","widget",sessionPreviewButton)
local resetSession=Style.Action(hudCard,"Reset session statistics","footer")
resetSession:SetHeight(30)
MarkPosition(resetSession,hudCard,-312)
resetSession:SetScript("OnClick",function()
    local ok,why=ns.DuelHUD.ResetSession()
    if ok and ns.Feedback then ns.Feedback.ConfirmAction(resetSession,"Session reset")
    elseif ns.Feedback then ns.Feedback.Toast(why,resetSession) end
end)
ns.Tooltips.Bind(resetSession,{title="Reset session statistics",detail="Start a new session without deleting match history.",disabled="Duel recording not enabled yet."})
RegisterOption("resetSessionStats","Reset session statistics","Start a new session without deleting history","widget",resetSession,function() return ns.CompetitiveStorage.LocalRecordingEnabled() end)
local widgetTransparency = Widgets.SliderRow(accessCard, "Floating icon transparency",
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
RegisterOption("widgetTransparency", "Floating icon transparency",
    "Set idle opacity of the floating access icon", "interface", widgetTransparency, HasWidget)
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
-- other UI addons's section-height measurement informed this approach; no source
-- copied, and all Settings/Search/scroll/tooltip owners remain unchanged.
local CARD_BREAKPOINT = 720
local CARD_GAP, SECTION_GAP, ROW_GAP = 14, 8, 1
local BANNER_HEIGHT = 72
local ROW_TOP = 90

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
    -- Native, artwork-extracted banners follow the same compact/stacked grid.
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

        local y = largeText and 104 or ROW_TOP
        for _, entry in ipairs(group.entries) do
            local widget = entry.widget
            local visible = not entry.visible or entry.visible()
            widget:SetShown(visible)
            if visible then
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
        { widget = iconMode },
        { widget = minimapSize, visible = HasMinimap },
        { widget = minimapTransparency, visible = HasMinimap },
        { widget = widgetSize, visible = HasWidget },
        { widget = widgetTransparency, visible = HasWidget },
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
local widgetGroups = {
    { card = hudCard, entries = {
        { widget = hudEnabledRow }, { widget = hudLockRow }, { widget = hudAdaptiveRow },
        { widget = hudScale }, { widget = hudOpacity }, { widget = resetHUD, height=30 },
        { widget = hudStatsRow }, { widget = sessionPreviewButton, height=30 }, { widget = resetSession, height=30 },
    }},
    { card = hudNotificationsCard, entries = {
        { widget = notifyRow }, { widget = notifySoundRow }, { widget = notifyPreview, height=30 },
        { widget = promotionPreview, height=30 }, { widget = achievementPreview, height=30 }, { widget = warningPreview, height=30 },
    }},
}
if consentRow then interfaceGroups[1].entries[#interfaceGroups[1].entries+1]={widget=consentRow} end
if warConsentRow then interfaceGroups[1].entries[#interfaceGroups[1].entries+1]={widget=warConsentRow} end
function appearance:Relayout(width) LayoutPage(self, appearanceGroups, width) end
function interface:Relayout(width) LayoutPage(self, interfaceGroups, width) end
function widgetPage:Relayout(width) LayoutPage(self, widgetGroups, width) end
local combatGroups={{card=countdownCard,entries={{widget=countdownRow},{widget=countdownPreview,height=30}}}}
function combatVisuals:Relayout(width) LayoutPage(self,combatGroups,width) end
appearance:Relayout(appearance:GetWidth())
interface:Relayout(interface:GetWidth())
widgetPage:Relayout(widgetPage:GetWidth())
    combatVisuals:Relayout(combatVisuals:GetWidth())

-- During a live slider drag repaint only its reset/modified indicator.
-- A full Refresh would programmatically reassign the active thumb.
function Options.RefreshAccessModified()
    minimapSize:SetModified(Settings.IsModified("minimapSize"))
    minimapTransparency:SetModified(Settings.IsModified("minimapTransparency"))
    widgetSize:SetModified(Settings.IsModified("widgetSize"))
    widgetTransparency:SetModified(Settings.IsModified("widgetTransparency"))
    -- The widget sliders already update live. Repaint only the noninteractive
    -- miniature; never replace an in-progress thumb/slider value.
    if ns.Feedback then ns.Feedback.RefreshWidgetPreview() end
end

function Options.RefreshHUDModified()
    for _,entry in ipairs({{hudScale,"duelHUDScale"},{hudOpacity,"duelHUDOpacity"}}) do
        local row,key=entry[1],entry[2]
        if not row:IsDragging() then row:SetValue(Settings.Get(key)) end
        row:SetModified(Settings.IsModified(key))
    end
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
    minimapSize:SetValue(Settings.Get("minimapSize"))
    minimapSize:SetModified(Settings.IsModified("minimapSize"))
    minimapSize:RefreshColors()
    minimapTransparency:SetValue(Settings.Get("minimapTransparency"))
    minimapTransparency:SetModified(Settings.IsModified("minimapTransparency"))
    minimapTransparency:RefreshColors()
    widgetSize:SetValue(Settings.Get("widgetSize"))
    widgetSize:SetModified(Settings.IsModified("widgetSize"))
    widgetSize:RefreshColors()
    widgetTransparency:SetValue(Settings.Get("widgetTransparency"))
    widgetTransparency:SetModified(Settings.IsModified("widgetTransparency"))
    widgetTransparency:RefreshColors()
    Options.RefreshHUDModified()
    hudScale:RefreshColors();hudOpacity:RefreshColors()
    if ns.Feedback then ns.Feedback.RefreshWidgetPreview() end
    local hasWidget, hasMinimap = HasWidget(), HasMinimap()
    minimapSize:SetAvailable(hasMinimap)
    minimapTransparency:SetAvailable(hasMinimap)
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
    resetSession:SetEnabled(ns.CompetitiveStorage.LocalRecordingEnabled())
    -- Font scaling can change the one/two-column breakpoint without
    -- changing window dimensions. Keep the adaptive layout in sync.
    appearance:Relayout(appearance:GetWidth())
    interface:Relayout(interface:GetWidth())
    widgetPage:Relayout(widgetPage:GetWidth())
    combatVisuals:Relayout(combatVisuals:GetWidth())
    appearance.scrollBar:Refresh()
    interface.scrollBar:Refresh()
    widgetPage.scrollBar:Refresh()
    combatVisuals.scrollBar:Refresh()
end

-- Navigation only requests positions; this module remains the single owner
-- of both Options scroll frames, and clamps restored offsets after reflow.
local function ScrollPage(key)
    if key == "options" then return appearance end
    if key == "interface" then return interface end
    if key == "widget" then return widgetPage end
    if key == "combatvisuals" then return combatVisuals end
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
    widgetPage.scrollOwner:SetShown(pageKey == "widget")
    combatVisuals.scrollOwner:SetShown(pageKey == "combatvisuals")
    local page=ScrollPage(pageKey)
    if page then page:Relayout(page:GetWidth());Options.Refresh() end
end

Window.frame:HookScript("OnHide", Widgets.CloseChoices)
Theme.Refresh()

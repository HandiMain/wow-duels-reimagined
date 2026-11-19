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
    scroll:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 34, -112)
    scroll:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -34, 27)
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
    Style.Fill(card, C.nav)
    Style.Border(card, C.goldDim)
    card.scrollOwner, card.scrollTop = page.scrollOwner, y
    return card
end

local appearance = Page(255)
local interface = Page(656)

local appearanceCard = Card(appearance, 0, 245)
local behaviorCard = Card(interface, 0, 225)
local typographyCard = Card(interface, 243, 397)

local function Section(card, title, subtitle, top)
    local heading = Style.Text(card, title, 18, C.pale)
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 20, top)
    local detail = Style.Text(card, subtitle, 12, C.muted)
    detail:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    return detail
end

local appearanceDescription = Section(appearanceCard, "Appearance",
    "Choose how Duels Reimagined matches your interface.", -16)
local availability = Style.Text(appearanceCard, "", 12, C.muted)
availability:SetPoint("TOPLEFT", appearanceDescription, "BOTTOMLEFT", 0, -17)
Section(behaviorCard, "Window behavior",
    "Keep the world visible while the dueling hall is open.", -16)
Section(typographyCard, "Typography",
    "Choose text appearance independently of window scale.", -18)

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

AddToggle(appearanceCard, "options", "matchColors", "Match EllesmereUI colors",
    "Use EllesmereUI's accent and panel colors, keeping our dueling identity.",
    -93, true)
AddToggle(appearanceCard, "options", "matchFont", "Match EllesmereUI font",
    "Use your selected EllesmereUI interface font.", -153, true)
AddToggle(behaviorCard, "interface", "autoPeekMoving", "Automatic Peek while moving",
    "Fade the window during movement; restore it when you stop.", -82, false)
AddToggle(behaviorCard, "interface", "reduceMotion", "Reduce motion",
    "Shorten or skip UI animation while retaining visual feedback.", -148, false)

local fontChoice = Widgets.ChoiceRow(typographyCard, "Interface font",
    "Blizzard by default; includes fonts registered with SharedMedia.",
    function(key) Settings.Set("fontChoice", key) end,
    function() Settings.Reset("fontChoice") end, false)
fontChoice:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -88)
fontChoice:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -88)
MarkPosition(fontChoice, typographyCard, -88)
RegisterOption("fontChoice", "Interface font",
    "Choose a Blizzard or LibSharedMedia font for the addon", "interface", fontChoice)

local fontScale = Widgets.SliderRow(typographyCard, "Text size",
    "Adjust text size without changing the menu scale.",
    Settings.MIN_FONT_SCALE, Settings.MAX_FONT_SCALE, Settings.FONT_SCALE_STEP,
    function(v) Settings.Set("fontScale", v) end,
    function() Settings.Reset("fontScale") end)
fontScale:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -174)
fontScale:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -174)
MarkPosition(fontScale, typographyCard, -174)
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
fontOutline:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -258)
fontOutline:SetPoint("TOPRIGHT", typographyCard, "TOPRIGHT", -20, -258)
MarkPosition(fontOutline, typographyCard, -258)
RegisterOption("fontOutline", "Text outline",
    "Choose default, none, outline or thick outline", "interface", fontOutline)

local info = Style.Text(typographyCard,
    "Hold the eye to Peek. Fold leaves the header visible. Font matching is controlled under Appearance.",
    12, C.muted)
info:SetPoint("TOPLEFT", typographyCard, "TOPLEFT", 20, -355)
info:SetPoint("RIGHT", typographyCard, "RIGHT", -20, 0)
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
    appearance.scrollBar:Refresh()
    interface.scrollBar:Refresh()
end

function Options.Show(pageKey)
    Widgets.CloseChoices()
    appearance.scrollOwner:SetShown(pageKey == "options")
    interface.scrollOwner:SetShown(pageKey == "interface")
    if pageKey == "options" or pageKey == "interface" then Options.Refresh() end
end

Window.frame:HookScript("OnHide", Widgets.CloseChoices)
Theme.Refresh()

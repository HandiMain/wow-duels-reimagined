local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

-- Shared option and icon-button widgets; one owner for all related behavior.
local Widgets = {}
ns.Widgets = Widgets

local texPath = "Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\"
local SLIDE_TIME = 0.16
local OFF = { 0.31, 0.36, 0.42 }
local DISABLED = { 0.30, 0.32, 0.35 }

local function PaintToggle(key, position)
    local row = key.owner
    local p = math.max(0, math.min(1, position))
    row.progress = p

    -- Recompute all visuals from state each time, never multiply old tint.
    local start = row.available and OFF or DISABLED
    local finish = row.available and C.gold or DISABLED
    local r = start[1] + (finish[1] - start[1]) * p
    local g = start[2] + (finish[2] - start[2]) * p
    local b = start[3] + (finish[3] - start[3]) * p
    row.track:SetVertexColor(r, g, b, 1)
    local thumbTone = row.available and 1 or 0.78
    row.thumb:SetVertexColor(thumbTone, thumbTone, thumbTone, 1)

    row.thumb:ClearAllPoints()
    row.thumb:SetPoint("LEFT", row.track, "LEFT", 3 + 21 * p, 0)
end

local methods = {}
function methods:SetChecked(value, immediate)
    local state = value and true or false
    if self.initialized and self.checked == state then
        PaintToggle(self.slideKey, self.progress)
        return
    end
    self.checked = state
    local dest = state and 1 or 0
    Motion.Value(self.slideKey, self.progress or 0, dest,
        (not self.initialized or immediate) and 0 or SLIDE_TIME, PaintToggle)
    self.initialized = true
end

function methods:SetAvailable(value, reason)
    local available = value and true or false
    self.available = available
    self.unavailableReason = reason
    self:SetAlpha(available and 1 or 0.58)
    Motion.Stop(self.hover, 0)
    PaintToggle(self.slideKey, self.progress)
    self.resetButton:SetEnabled(self.modified and available)
    self.resetButton:SetAlpha(available and 1 or 0.42)
end

function methods:SetModified(value)
    self.modified = value and true or false
    self.modDot:SetShown(self.modified)
    self.resetButton:SetShown(self.modified)
    self.resetButton:SetEnabled(self.modified and self.available)
    self.resetButton:SetAlpha(self.available and 1 or 0.42)
end

function methods:RefreshColors()
    -- Always repaint from the central theme, including mid-transition.
    PaintToggle(self.slideKey, self.progress)
    self.divider:SetColorTexture(unpack(C.goldDim))
    self.divider:SetAlpha(0.24)
    self.name:SetTextColor(unpack(C.text))
    self.resetIcon:SetVertexColor(unpack(C.gold))
    self.description:SetTextColor(unpack(C.muted))
end

local function ToggleEnter(row)
    if row.available then
        Motion.Fade(row.hover, 0.22, 0.14)
    end
end

local function ToggleLeave(row)
    Motion.Fade(row.hover, 0, 0.18)
end

function Widgets.ToggleRow(parent, label, description, onToggle, onReset)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(56)
    row:RegisterForClicks("LeftButtonUp")
    row.available = true
    row.checked = false
    row.progress = 0
    row.onToggle = onToggle
    row.onReset = onReset
    row.slideKey = { owner = row }

    row.hover = Chrome.Texture(row, "Selection", 0, "BACKGROUND")
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    row.divider:SetHeight(1)

    row.name = Style.Text(row, label, 15, C.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -7)
    row.description = Style.Text(row, description, 12, C.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.description:SetPoint("RIGHT", row, "RIGHT", -93, 0)
    row.description:SetJustifyH("LEFT")

    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetTexture(texPath .. "ToggleTrack.tga")
    row.track:SetSize(43, 21)
    row.track:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    Chrome.Sharp(row.track)

    row.thumb = row:CreateTexture(nil, "OVERLAY")
    row.thumb:SetTexture(texPath .. "ToggleThumb.tga")
    row.thumb:SetSize(16, 16)
    Chrome.Sharp(row.thumb)

    row.modDot = Style.Text(row, "•", 14, C.gold)
    row.modDot:SetPoint("RIGHT", row.name, "LEFT", -5, 0)
    row.modDot:Hide()
    local reset = CreateFrame("Button", nil, row)
    reset:SetSize(19, 19)
    reset:SetPoint("RIGHT", row.track, "LEFT", -9, 0)
    reset:RegisterForClicks("LeftButtonUp")
    local icon = reset:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(reset)
    icon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Polestar\\reset.tga")
    Chrome.Sharp(icon)
    row.resetButton, row.resetIcon = reset, icon
    reset:Hide()
    reset:SetScript("OnClick", function()
        if row.onReset and row.available then row.onReset() end
    end)
    ns.Tooltips.Bind(reset, {
        title = "Reset " .. label,
        detail = "Restore the default value for this setting.",
        anchor = "RIGHT",
    })

    for name, fn in pairs(methods) do row[name] = fn end
    row:SetScript("OnClick", function(self)
        if self.available and self.onToggle then self.onToggle(not self.checked) end
    end)
    row:SetScript("OnEnter", ToggleEnter)
    row:SetScript("OnLeave", ToggleLeave)
    Widgets.PressFeedback(row, row.hover)
    ns.Tooltips.Bind(row, function()
        return {
            title = label,
            detail = row.available and description or
                (row.unavailableReason or description),
            anchor = "RIGHT",
        }
    end)
    row:RefreshColors()
    row:SetModified(false)
    return row
end
 

-- Shared pressed-state feedback. Existing hover and click handlers remain
-- authoritative; this merely adds a short response to a real mouse press.
function Widgets.PressFeedback(button, region)
    if not button or not region or button._duelsPressBound then return end
    button._duelsPressBound = true
    button:HookScript("OnMouseDown", function(self, mouse)
        if mouse == "LeftButton" and (not self.IsEnabled or self:IsEnabled()) then
            Motion.Fade(region, 0.4, Motion.Duration("quick"))
        end
    end)
    button:HookScript("OnMouseUp", function(self, mouse)
        if mouse == "LeftButton" then
            local over = self.IsMouseOver and self:IsMouseOver()
            Motion.Fade(region, over and 0.20 or 0, Motion.Duration("quick"))
        end
    end)
    button:HookScript("OnHide", function() Motion.Stop(region, 0) end)
end

-- A light-weight universal reset affordance for future non-toggle widgets.
function Widgets.AttachModified(row, anchor, onReset)
    local dot = Style.Text(row, "•", 14, C.gold)
    dot:SetPoint("RIGHT", row.name, "LEFT", -5, 0)
    dot:Hide()
    local reset = CreateFrame("Button", nil, row)
    reset:SetSize(19, 19)
    reset:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
    reset:RegisterForClicks("LeftButtonUp")
    local tex = reset:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(reset)
    tex:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Polestar\\reset.tga")
    Chrome.Sharp(tex)
    reset:SetScript("OnClick", function()
        if row.available and onReset then onReset() end
    end)
    ns.Tooltips.Bind(reset, {
        title = "Reset " .. (row.name:GetText() or "setting"),
        detail = "Restore the default value for this setting.",
        anchor = "RIGHT",
    })
    reset:Hide()
    row.modDot, row.resetButton, row.resetIcon = dot, reset, tex
    function row:SetModified(changed)
        self.modified = changed and true or false
        dot:SetShown(self.modified)
        reset:SetShown(self.modified)
        reset:SetEnabled(self.modified and self.available)
        reset:SetAlpha(self.available and 1 or 0.4)
    end
    row:SetModified(false)
end

local openChoicePopup
local choiceCounter = 0
local clickCatcher
function Widgets.CloseChoices()
    if openChoicePopup then openChoicePopup:Hide(); openChoicePopup = nil end
    if clickCatcher then clickCatcher:Hide() end
end
local function ChoiceCatcher()
    if clickCatcher then return clickCatcher end
    local parent = ns.Window.frame
    clickCatcher = CreateFrame("Button", nil, parent)
    clickCatcher:SetAllPoints(parent)
    clickCatcher:SetFrameLevel(parent:GetFrameLevel() + 54)
    clickCatcher:EnableMouse(true)
    clickCatcher:SetScript("OnMouseDown", Widgets.CloseChoices)
    clickCatcher:Hide()
    return clickCatcher
end

-- Reusable compact picker for SharedMedia fonts, outlines, and later Options.
-- Popup rows scroll rather than opening hundreds of Blizzard dropdown frames.
function Widgets.ChoiceRow(parent, caption, detail, onChoose, onReset, above)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(74)
    row.available = true
    row.name = Style.Text(row, caption, 15, C.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -9)
    row.description = Style.Text(row, detail, 12, C.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -5)
    row.description:SetPoint("RIGHT", row, "RIGHT", -262, 0)
    row.description:SetJustifyH("LEFT")
    local control = CreateFrame("Button", nil, row)
    control:SetSize(226, 30)
    control:SetPoint("RIGHT", row, "RIGHT", -8, -1)
    control:RegisterForClicks("LeftButtonUp")
    Style.Fill(control, C.body)
    Style.Border(control, C.goldDim)
    local valueText = Style.Text(control, "", 12, C.text)
    valueText:SetPoint("LEFT", control, "LEFT", 9, 0)
    valueText:SetPoint("RIGHT", control, "RIGHT", -25, 0)
    valueText:SetJustifyH("LEFT")
    local arrow = control:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Header\\FoldDown.png")
    arrow:SetSize(17, 17)
    arrow:SetPoint("RIGHT", control, "RIGHT", -7, 0)
    Chrome.Sharp(arrow)
    Widgets.AttachModified(row, control, onReset)
    local hover = Style.Fill(control, C.goldDim)
    hover:SetAlpha(0)
    control:SetScript("OnEnter", function()
        Motion.Fade(hover, 0.18, Motion.Duration("quick"))
    end)
    control:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, Motion.Duration("quick"))
    end)
    Widgets.PressFeedback(control, hover)
    ns.Tooltips.Bind(control, function()
        return { title = caption,
            detail = row.available and detail or
                (row.disabledReason or detail),
            anchor = "LEFT" }
    end)
    -- Escape should dismiss the picker before the main Duels window.
    choiceCounter = choiceCounter + 1
    local popupName = "DuelsReimaginedChoicePopup" .. choiceCounter
    local popup = CreateFrame("Frame", popupName, ns.Window.frame)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, popupName)
    end
    popup:SetSize(238, 234)
    popup:SetFrameLevel(ns.Window.frame:GetFrameLevel() + 55)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    if above then
        popup:SetPoint("BOTTOMRIGHT", control, "TOPRIGHT", 0, 4)
    else
        popup:SetPoint("TOPRIGHT", control, "BOTTOMRIGHT", 0, -4)
    end
    Style.Fill(popup, C.nav)
    Style.Border(popup, C.goldDim)
    local items, offset = {}, 0
    local pageSize, scrollBar = 7, nil
    local function Render()
        local choices = row.choices or {}
        offset = math.max(0, math.min(offset, math.max(0, #choices - pageSize)))
        for i, entry in ipairs(items) do
            local opt = choices[offset + i]
            entry.button:SetShown(opt ~= nil)
            if opt then
                entry.label:SetText(opt.label)
                entry.label:SetTextColor(unpack(opt.key == row.selected and C.gold or C.text))
            end
        end
        popup:SetHeight(12 + math.min(pageSize, #choices) * 31)
        if scrollBar then scrollBar:Refresh() end
    end
    for i = 1, pageSize do
        local b = CreateFrame("Button", nil, popup)
        b:SetHeight(29)
        b:SetPoint("TOPLEFT", popup, "TOPLEFT", 6, -6 - (i - 1) * 31)
        b:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -21, -6 - (i - 1) * 31)
        b:RegisterForClicks("LeftButtonUp")
        local label = Style.Text(b, "", 12, C.text)
        label:SetPoint("LEFT", b, "LEFT", 6, 0)
        label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        local glow = Style.Fill(b, C.goldDim)
        glow:SetAlpha(0)
        b:SetScript("OnEnter", function() Motion.Fade(glow, 0.24, 0.12) end)
        b:SetScript("OnLeave", function() Motion.Fade(glow, 0, 0.12) end)
        b:SetScript("OnClick", function()
            local option = (row.choices or {})[offset + i]
            Widgets.CloseChoices()
            if option and onChoose then onChoose(option.key) end
        end)
        Widgets.PressFeedback(b, glow)
        ns.Tooltips.Bind(b, function()
            local choice = (row.choices or {})[offset + i]
            if not choice then return end
            return { title = choice.label,
                detail = "Choose this value for " .. caption .. ".",
                anchor = "LEFT" }
        end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta)
            local handler = popup:GetScript("OnMouseWheel")
            if handler then handler(popup, delta) end
        end)
        items[i] = { button = b, label = label }
    end
    popup:SetScript("OnMouseWheel", function(_, delta)
        local num = #(row.choices or {})
        offset = math.max(0, math.min(math.max(0, num - pageSize),
            offset - (delta > 0 and 2 or -2)))
        Render()
    end)
    popup:SetScript("OnHide", function()
        if openChoicePopup == popup then openChoicePopup = nil end
        if clickCatcher then clickCatcher:Hide() end
    end)
    -- Same draggable scrollbar machinery as the Options pages, fed by the
    -- picker’s virtualized 31px rows. Never create a second scroll engine.
    scrollBar = Widgets.ScrollBar(popup,
        function()
            local n = #(row.choices or {})
            return math.min(pageSize, n) * 31, n * 31, offset * 31
        end,
        function(value)
            local n = #(row.choices or {})
            offset = math.max(0, math.min(math.max(0, n - pageSize),
                math.floor(value / 31 + 0.5)))
            Render()
        end)
    popup:Hide()
    control:SetScript("OnClick", function()
        if not row.available then return end
        if popup:IsShown() then Widgets.CloseChoices(); return end
        Widgets.CloseChoices()
        offset = 0
        Render()
        -- Re-anchor for current window size/scroll position. At smaller
        -- resolutions the menu opens upward instead of leaving the screen.
        popup:ClearAllPoints()
        local below = control:GetBottom()
        if above or (below and below < popup:GetHeight() + 16) then
            popup:SetPoint("BOTTOMRIGHT", control, "TOPRIGHT", 0, 4)
        else
            popup:SetPoint("TOPRIGHT", control, "BOTTOMRIGHT", 0, -4)
        end
        openChoicePopup = popup
        ChoiceCatcher():Show()
        popup:Show()
    end)
    function row:SetChoices(choices, selected, displayOverride)
        self.choices = choices or {}
        self.selected = selected
        local label = displayOverride
        if not label then
            for _, choice in ipairs(self.choices) do
                if choice.key == selected then label = choice.label; break end
            end
        end
        valueText:SetText(label or "Blizzard Default")
        if popup:IsShown() then Render() end
    end
    function row:SetAvailable(enabled, reason)
        self.available = enabled and true or false
        control:SetEnabled(self.available)
        self:SetAlpha(self.available and 1 or 0.62)
        self.resetButton:SetEnabled(self.modified and self.available)
        self.resetButton:SetAlpha(self.available and 1 or 0.4)
        self.disabledReason = reason
        if not self.available and popup:IsShown() then Widgets.CloseChoices() end
    end
    row:EnableMouse(true)
    -- The parent receives hover events when a disabled dropdown cannot.
    row:SetScript("OnEnter", function(self)
        if not self.available then
            ns.Tooltips.Show(self, {
                title = caption,
                detail = self.disabledReason or detail,
                anchor = "RIGHT",
            })
        end
    end)
    row:SetScript("OnLeave", function(self) ns.Tooltips.Hide(self) end)
    row:HookScript("OnHide", function(self) ns.Tooltips.Hide(self, true) end)
    row.control = control
    row.popup = popup
    return row
end

function Widgets.SliderRow(parent, caption, detail, minVal, maxVal, step, onCommit, onReset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(72)
    row.available = true
    row.name = Style.Text(row, caption, 15, C.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -10)
    row.description = Style.Text(row, detail, 12, C.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("RIGHT", row, "RIGHT", -262, 0)
    local slider = CreateFrame("Slider", nil, row)
    slider:SetSize(172, 24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:EnableMouseWheel(true)
    slider:SetPoint("RIGHT", row, "RIGHT", -55, 0)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.23, 0.26, 0.3, 1)
    track:SetPoint("LEFT", slider, "LEFT")
    track:SetPoint("RIGHT", slider, "RIGHT")
    track:SetHeight(2)
    local filled = slider:CreateTexture(nil, "ARTWORK")
    filled:SetColorTexture(unpack(C.gold))
    filled:SetPoint("LEFT", track, "LEFT")
    filled:SetHeight(2)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(texPath .. "SliderThumb.tga")
    thumb:SetSize(14, 14)
    Chrome.Sharp(thumb)
    slider:SetThumbTexture(thumb)
    local percent = Style.Text(row, "100%", 12, C.text)
    percent:SetPoint("LEFT", slider, "RIGHT", 9, 0)
    Widgets.AttachModified(row, slider, onReset)
    local pending, dragging
    local function Paint(v)
        local clean = math.max(minVal, math.min(maxVal,
            math.floor(v / step + 0.5) * step))
        filled:SetWidth(math.max(1, slider:GetWidth() *
            (clean - minVal) / (maxVal - minVal)))
        percent:SetText(math.floor(clean * 100 + 0.5) .. "%")
        return clean
    end
    slider:SetScript("OnValueChanged", function(_, value, fromUser)
        local clean = Paint(value)
        if fromUser or dragging then pending = clean end
    end)
    slider:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then dragging = true end
    end)
    slider:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= "LeftButton" then return end
        dragging = false
        local nextVal = pending or Paint(slider:GetValue())
        pending = nil
        if onCommit then onCommit(nextVal) end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        local nextVal = Paint(slider:GetValue() + (delta > 0 and step or -step))
        slider:SetValue(nextVal)
        pending = nil
        if onCommit then onCommit(nextVal) end
    end)
    function row:SetValue(v)
        pending = nil
        slider:SetValue(v)
        Paint(v)
    end
    function row:SetAvailable(yes)
        self.available = yes and true or false
        slider:SetEnabled(self.available)
        self:SetAlpha(self.available and 1 or 0.6)
    end
    ns.Tooltips.Bind(slider, function()
        return { title = caption,
            detail = (detail or "") .. " Current: " ..
                math.floor((slider:GetValue() or 1) * 100 + 0.5) ..
                "%. Drag or use the mouse wheel to adjust.",
            anchor = "LEFT" }
    end)
    row.slider = slider
    row.fill = filled
    function row:RefreshColors()
        filled:SetColorTexture(unpack(C.gold))
        self.resetIcon:SetVertexColor(unpack(C.gold))
    end
    row:RefreshColors()
    return row
end


-- Polestar-reference scroll behavior, independently implemented for Duels.
-- A thin draggable thumb appears only for overflow; its only OnUpdate exists
-- during an actual mouse drag and is always cleared on mouse up/hide.
-- A single reusable component serves regular ScrollFrames and dropdown lists.
function Widgets.ScrollBar(parent, metrics, setOffset)
    local bar = CreateFrame("Button", nil, parent)
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -5)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 5)
    bar:SetFrameLevel(parent:GetFrameLevel() + 2)
    bar:RegisterForClicks("LeftButtonUp")
    local track = Style.Fill(bar, C.goldDim, "BACKGROUND")
    track:SetAlpha(0.20)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(C.gold))
    thumb:SetWidth(4)
    thumb:SetHeight(24)
    bar.Thumb = thumb
    local dragging, startY, startScroll = false, 0, 0

    function bar:Refresh()
        local view, content, offset = metrics()
        view, content, offset = math.max(0, view or 0),
            math.max(0, content or 0), math.max(0, offset or 0)
        local range = math.max(0, content - view)
        local span = math.max(1, self:GetHeight())
        self.range, self.span = range, span
        if range <= 0 or view <= 0 or span <= 1 then
            self:Hide()
            return
        end
        local thumbH = math.max(24, span * view / content)
        thumbH = math.min(span, thumbH)
        local free = math.max(0, span - thumbH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", self, "TOP", 0,
            -free * math.min(1, offset / range))
        self.free = free
        self:Show()
    end

    local function StopDrag(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        thumb:SetWidth(self:IsMouseOver() and 6 or 4)
    end
    bar:SetScript("OnMouseDown", function(self, mouse)
        if mouse ~= "LeftButton" or not self:IsShown() then return end
        local _, y = GetCursorPosition()
        local scale = math.max(0.01, self:GetEffectiveScale())
        startY = y / scale
        local _, _, offset = metrics()
        startScroll = offset or 0
        dragging = true
        thumb:SetWidth(6)
        self:SetScript("OnUpdate", function()
            if not dragging then return end
            local free, range = self.free or 0, self.range or 0
            if free <= 0 or range <= 0 then return end
            local _, cursorY = GetCursorPosition()
            local delta = startY - cursorY / math.max(0.01, self:GetEffectiveScale())
            setOffset(math.max(0, math.min(range,
                startScroll + delta * range / free)))
            self:Refresh()
        end)
    end)
    bar:SetScript("OnMouseUp", StopDrag)
    bar:SetScript("OnHide", StopDrag)
    bar:SetScript("OnEnter", function() thumb:SetWidth(6) end)
    bar:SetScript("OnLeave", function(self)
        if not dragging then thumb:SetWidth(4) end
    end)
    ns.Tooltips.Bind(bar, {
        title = "Scroll",
        detail = "Drag to scroll this list, or use the mouse wheel.",
        anchor = "LEFT",
    })
    bar:Hide()
    return bar
end

local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

-- Shared option and icon-button widgets; one owner for all related behavior.
local Widgets = {}
ns.Widgets = Widgets

local texPath = "Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\"
local SLIDE_TIME = 0.16
-- Rounded 2:1 track and circular knob use our existing RGBA artwork.
-- Shared by every settings toggle, including EllesmereUI matching controls.
local TOGGLE_W, TOGGLE_H, TOGGLE_KNOB, TOGGLE_PAD = 40, 20, 16, 2
local OFF = { 0.60, 0.59, 0.62 }
local DISABLED = { 0.30, 0.32, 0.35 }

local function PaintToggle(key, position)
    local row = key.owner
    local p = math.max(0, math.min(1, position))
    row.progress = p

    -- Recompute all visuals from state each time, never multiply old tint.
    local start = row.available and OFF or DISABLED
    local finish = row.available and C.red or DISABLED
    local r = start[1] + (finish[1] - start[1]) * p
    local g = start[2] + (finish[2] - start[2]) * p
    local b = start[3] + (finish[3] - start[3]) * p
    row.track:SetVertexColor(r, g, b, 1)
    local thumbTone = row.available and 1 or 0.78
    row.thumb:SetVertexColor(thumbTone, thumbTone, thumbTone, 1)

    row.thumb:ClearAllPoints()
    local travel = TOGGLE_W - TOGGLE_KNOB - TOGGLE_PAD * 2
    row.thumb:SetPoint("LEFT", row.track, "LEFT", TOGGLE_PAD + travel * p, 0)
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
    row:SetHeight(54)
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
    row.track:SetSize(TOGGLE_W, TOGGLE_H)
    row.track:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    Chrome.Sharp(row.track)

    row.thumb = row:CreateTexture(nil, "OVERLAY")
    row.thumb:SetTexture(texPath .. "ToggleThumb.tga")
    row.thumb:SetSize(TOGGLE_KNOB, TOGGLE_KNOB)
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
    icon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Controls\\reset.tga")
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
    -- Layout changes only the presentation; the toggle remains the same
    -- full-row click target, SavedVariables owner and animation.
    function row:LayoutForWidth(width, compact)
        -- other UI addons-like dense compact rows: title and toggle are always
        -- visible, while its full explanation remains available on hover.
        self:SetHeight(compact and 28 or 54)
        self.name:ClearAllPoints()
        self.name:SetPoint("TOPLEFT", self, "TOPLEFT", 1, compact and -6 or -7)
        self.name:SetWidth(math.max(70, width - (compact and 66 or 93)))
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
        self.description:SetWidth(math.max(70, width - 93))
        self.description:SetHeight(29)
        self.description:SetShown(not compact)
    end
    row:RefreshColors()
    row:SetModified(false)
    return row
end
 

-- One interactive-state owner for all addon buttons, based on other UI addons's
-- short mouse-depth response. Uses our ONE Motion driver (event-driven only).
-- Hover/selected layers are owned by the caller; this creates a separate
-- temporary gold sheen for press/release so selected state never flickers.
function Widgets.PressFeedback(button, hover, opts)
    if not button or button._duelsPressBound then return end
    opts = opts or {}
    button._duelsPressBound = true
    local flash = Style.SkinMask(button, C.gold, "shine", "OVERLAY", -1,
        opts.corner or 9, opts.inset or 2)
    flash:SetAlpha(0)
    button._duelsPressFlash = flash
    local down = false
    local function Enabled(self)
        return self.available ~= false and
            (not self.IsEnabled or self:IsEnabled())
    end
    button:HookScript("OnMouseDown", function(self, mouse)
        if mouse ~= "LeftButton" or not Enabled(self) then return end
        down = true
        Motion.Stop(flash, opts.downAlpha or 0.44)
        if hover then Motion.Fade(hover, opts.downHover or 0.40, 0.06) end
    end)
    button:HookScript("OnMouseUp", function(self, mouse)
        if mouse ~= "LeftButton" then return end
        down = false
        Motion.Fade(flash, 0, Motion.Duration("normal"))
        if hover then
            local over = Enabled(self) and self.IsMouseOver and self:IsMouseOver()
            Motion.Fade(hover, over and (opts.hoverAlpha or 0.24) or 0,
                Motion.Duration("quick"))
        end
    end)
    button:HookScript("OnClick", function(self, mouse)
        if mouse ~= "LeftButton" or not Enabled(self) or
            (self.IsVisible and not self:IsVisible()) then return end
        -- A brief release glint is visible AFTER the completed click. A
        -- distinct highlight persists only where selection owns it.
        Motion.Stop(flash, opts.clickAlpha or 0.50)
        Motion.Fade(flash, 0, Motion.Duration("gentle"))
    end)
    button:HookScript("OnLeave", function()
        if down then
            down = false
            Motion.Fade(flash, 0, Motion.Duration("quick"))
        end
    end)
    button:HookScript("OnHide", function()
        down = false
        Motion.Stop(flash, 0)
        if hover then Motion.Stop(hover, 0) end
    end)
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
    tex:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Controls\\reset.tga")
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
local function ChoiceCatcher(owner)
    local parent=owner or ns.Window.frame
    if not clickCatcher then
        clickCatcher=CreateFrame("Button",nil,parent)
        clickCatcher:EnableMouse(true)
        clickCatcher:SetScript("OnMouseDown",Widgets.CloseChoices)
        clickCatcher:Hide()
    end
    clickCatcher:SetParent(parent)
    clickCatcher:ClearAllPoints()
    clickCatcher:SetAllPoints(parent)
    clickCatcher:SetFrameStrata(parent:GetFrameStrata())
    clickCatcher:SetFrameLevel(parent:GetFrameLevel()+54)
    return clickCatcher
end

-- Reuse the exact Options dropdown plate, arrow and motion in War Games
-- without adding another style or a second scrolling engine.
function Widgets.ChoiceControl(parent, width)
    local control = CreateFrame("Button", nil, parent)
    control:SetSize(width or 226, 30)
    control:RegisterForClicks("LeftButtonUp")
    Style.Skin(control, C.body, {
        corner=9, edge=C.border, shine=0.22, shade=0.22,
    })
    local valueText = Style.Text(control, "", 12, C.text)
    valueText:SetPoint("LEFT", control, "LEFT", 9, 0)
    valueText:SetPoint("RIGHT", control, "RIGHT", -25, 0)
    valueText:SetJustifyH("LEFT")
    valueText:SetWordWrap(false)
    local arrow = control:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\FoldDown.png")
    arrow:SetSize(17, 17)
    arrow:SetPoint("RIGHT", control, "RIGHT", -7, 0)
    Chrome.Sharp(arrow)
    local hover = Style.Fill(control, C.goldDim)
    hover:SetAlpha(0)
    control:SetScript("OnEnter", function()
        Motion.Fade(hover, 0.18, Motion.Duration("quick"))
    end)
    control:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, Motion.Duration("quick"))
    end)
    Widgets.PressFeedback(control, hover)
    control.label, control.arrow = valueText, arrow
    return control, valueText
end

-- One shared popup for transient picks such as an arena or Battle.net
-- captain. Looks and scrolls like the Options > Interface font menu.
-- Rows may carry an optional boolean .online; unknown shows no indicator.
local warChoiceMenu
function Widgets.OpenChoices(anchor, choices, selected, onChoose, owner)
    if not anchor or type(choices) ~= "table" or
        type(onChoose) ~= "function" then return end
    if not warChoiceMenu then
        choiceCounter = choiceCounter + 1
        local name = "DuelsReimaginedChoicePopup" .. choiceCounter
        local popup = CreateFrame("Frame", name, ns.Window.frame)
        if type(UISpecialFrames) == "table" then
            table.insert(UISpecialFrames, name)
        end
        popup:SetFrameLevel(ns.Window.frame:GetFrameLevel()+55)
        popup:SetSize(274, 229)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:EnableMouseWheel(true)
        Style.Skin(popup, C.nav, {
            corner=10, edge=C.border, shine=0.28, shade=0.20,
        })
        local rowHeight, visible = 31, 7
        local entries, offset = {}, 0
        local options, selectedKey, callback, currentAnchor = {}, nil, nil, nil
        local scrollbar

        local function Render()
            local n = #options
            offset = math.max(0, math.min(offset, math.max(0, n-visible)))
            for i, row in ipairs(entries) do
                local option = options[offset+i]
                row.button:SetShown(option ~= nil)
                if option then
                    row.option = option
                    row.label:SetText(option.label or "")
                    row.label:SetTextColor(unpack(option.key == selectedKey
                        and C.gold or C.text))
                    local status = option.online
                    row.dot:SetShown(type(status) == "boolean")
                    if type(status) == "boolean" then
                        if status then row.dot:SetColorTexture(0.31, 0.83, 0.38)
                        else row.dot:SetColorTexture(0.82, 0.30, 0.30) end
                    end
                    row.button:SetEnabled(not option.disabled)
                    row.button:SetAlpha(option.disabled and 0.48 or 1)
                else
                    row.option = nil
                end
            end
            popup:SetHeight(12+math.max(1,math.min(visible,n))*rowHeight)
            if scrollbar then scrollbar:Refresh() end
        end

        for i=1,visible do
            local button = CreateFrame("Button", nil, popup)
            button:SetHeight(29)
            button:SetPoint("TOPLEFT",popup,"TOPLEFT",6,-6-(i-1)*rowHeight)
            button:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-21,-6-(i-1)*rowHeight)
            button:RegisterForClicks("LeftButtonUp")
            local dot = button:CreateTexture(nil, "ARTWORK")
            dot:SetSize(8,8)
            dot:SetPoint("LEFT",button,"LEFT",7,0)
            dot:Hide()
            local label = Style.Text(button,"",12,C.text)
            label:SetPoint("LEFT",dot,"RIGHT",8,0)
            label:SetPoint("RIGHT",button,"RIGHT",-6,0)
            label:SetWordWrap(false)
            local glow = Style.Skin(button,C.hover,{
                corner=9, edge=C.goldDim, shine=0.14, shade=0.11, alpha=0,
            })
            button:SetScript("OnEnter",function()
                Motion.Fade(glow,0.24,0.12)
            end)
            button:SetScript("OnLeave",function()
                Motion.Fade(glow,0,0.12)
            end)
            Widgets.PressFeedback(button,glow)
            button:SetScript("OnClick",function()
                local option=options[offset+i]
                if not option or option.disabled then return end
                local fn=callback
                Widgets.CloseChoices()
                if fn then fn(option.key) end
            end)
            button:EnableMouseWheel(true)
            button:SetScript("OnMouseWheel",function(_, delta)
                local handler=popup:GetScript("OnMouseWheel")
                if handler then handler(popup,delta) end
            end)
            ns.Tooltips.Bind(button,function()
                local option=options[offset+i]
                if not option then return end
                local detail=option.detail
                if type(option.online)=="boolean" then
                    local service=option.onlineSource or "Battle.net"
                    detail=(option.online and "Online" or "Offline") ..
                        " ("..service..")"
                end
                return { title=option.label or "Selection",
                         detail=detail or "Choose this option.",
                         anchor="LEFT" }
            end)
            entries[i]={button=button,label=label,dot=dot}
        end
        popup:SetScript("OnMouseWheel",function(_, delta)
            local n=#options
            offset=math.max(0,math.min(math.max(0,n-visible),
                offset-(delta>0 and 2 or -2)))
            Render()
        end)
        scrollbar=Widgets.ScrollBar(popup,function()
            local n=#options
            return math.min(visible,n)*rowHeight,n*rowHeight,offset*rowHeight
        end,function(value)
            offset=math.max(0,math.min(math.max(0,#options-visible),
                math.floor(value/rowHeight+0.5)))
            Render()
        end)
        popup:SetScript("OnHide",function()
            if openChoicePopup==popup then openChoicePopup=nil end
            if clickCatcher then clickCatcher:Hide() end
            currentAnchor=nil
        end)
        function popup:Open(target, list, key, action, owner)
            if currentAnchor==target and popup:IsShown() then
                Widgets.CloseChoices()
                return
            end
            Widgets.CloseChoices()
            local host=owner or ns.Window.frame
            popup:SetParent(host)
            popup:SetFrameStrata(host:GetFrameStrata())
            popup:SetFrameLevel(host:GetFrameLevel()+55)
            options=list
            selectedKey=key
            callback=action
            currentAnchor=target
            offset=0
            Render()
            popup:ClearAllPoints()
            local bottom=target:GetBottom()
            local right=target:GetRight()
            local limit=host:GetRight()
            local rightAlign=not right or not limit or right+15>limit-274
            if bottom and bottom<popup:GetHeight()+16 then
                popup:SetPoint(rightAlign and "BOTTOMRIGHT" or "BOTTOMLEFT",
                    target,rightAlign and "TOPRIGHT" or "TOPLEFT",0,4)
            else
                popup:SetPoint(rightAlign and "TOPRIGHT" or "TOPLEFT",
                    target,rightAlign and "BOTTOMRIGHT" or "BOTTOMLEFT",0,-4)
            end
            openChoicePopup=popup
            ChoiceCatcher(host):Show()
            popup:Show()
        end
        warChoiceMenu=popup
        popup:Hide()
    end
    warChoiceMenu:Open(anchor,choices,selected,onChoose,owner)
end

-- Reusable compact picker for SharedMedia fonts, outlines, and later Options.
-- Popup rows scroll rather than opening hundreds of Blizzard dropdown frames.
function Widgets.ChoiceRow(parent, caption, detail, onChoose, onReset, above, fontSamples)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(66)
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
    Style.Skin(control, C.body, { corner=9, edge=C.border, shine=0.22, shade=0.22 })
    local function ChoiceLabel(owner)
        if not fontSamples then return Style.Text(owner,"",12,C.text) end
        -- Never bind samples to Style/Theme; they have a face of their own.
        local fs=owner:CreateFontString(nil,"OVERLAY")
        fs:SetJustifyH("LEFT");fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(false)
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        fs:SetHeight(26)
        fs:SetTextColor(unpack(C.text))
        ns.Fonts.PaintSample(fs,"default","",14,190)
        return fs
    end
    local valueText = ChoiceLabel(control)
    local valueWidth=192
    local function PaintValue()
        local label=row.displayOverride
        if not label then
            for _,choice in ipairs(row.choices or {}) do
                if choice.key==row.selected then label=choice.label;break end
            end
        end
        label=label or "Blizzard Default"
        if fontSamples then
            ns.Fonts.PaintSample(valueText,row.displayOverride and "default" or row.selected,label,14,valueWidth)
            valueText:SetTextColor(unpack(C.text))
        else valueText:SetText(label) end
    end
    valueText:SetPoint("LEFT", control, "LEFT", 9, 0)
    valueText:SetPoint("RIGHT", control, "RIGHT", -25, 0)
    valueText:SetJustifyH("LEFT")
    local arrow = control:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\FoldDown.png")
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
    Style.Skin(popup, C.nav, { corner=10, edge=C.border, shine=0.28, shade=0.20 })
    local items, offset = {}, 0
    local pageSize, scrollBar = 7, nil
    local function Render()
        local choices = row.choices or {}
        offset = math.max(0, math.min(offset, math.max(0, #choices - pageSize)))
        for i, entry in ipairs(items) do
            local opt = choices[offset + i]
            entry.button:SetShown(opt ~= nil)
            if opt then
                if fontSamples then ns.Fonts.PaintSample(entry.label,opt.key,opt.label,16,194)
                else entry.label:SetText(opt.label) end
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
        local label = ChoiceLabel(b)
        label:SetPoint("LEFT", b, "LEFT", 6, 0)
        label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        local glow = Style.Skin(b, C.hover, { corner=9,
            edge=C.goldDim, shine=0.14, shade=0.11, alpha=0 })
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
        self.displayOverride=displayOverride
        PaintValue()
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
        if not self.available or self.compact then
            ns.Tooltips.Show(self, {
                title = caption,
                detail = not self.available and (self.disabledReason or detail) or detail,
                anchor = "RIGHT",
            })
        end
    end)
    row:SetScript("OnLeave", function(self) ns.Tooltips.Hide(self) end)
    row:HookScript("OnHide", function(self) ns.Tooltips.Hide(self, true) end)
    row.control = control
    row.popup = popup
    function row:LayoutForWidth(width, compact)
        self.compact = compact
        self:SetHeight(compact and 32 or 66)
        self.name:ClearAllPoints()
        self.name:SetPoint("TOPLEFT", self, "TOPLEFT",
            1, compact and -7 or -7)
        self.name:SetWidth(math.max(76, width - (compact and 167 or 10)))
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
        self.description:SetWidth(math.max(70, width - 262))
        self.description:SetHeight(30)
        self.description:SetShown(not compact)
        control:ClearAllPoints()
        local controlWidth=compact and math.max(112,math.min(140,width-165)) or 226
        control:SetWidth(controlWidth)
        control:SetPoint("RIGHT", self, "RIGHT", -8, -1)
        if fontSamples then
            valueWidth=controlWidth-34
            PaintValue()
        end
    end
    return row
end

function Widgets.SliderRow(parent, caption, detail, minVal, maxVal, step, onCommit, onReset, formatValue, live)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(64)
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
    track:SetColorTexture(unpack(C.track))
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
    local pending, dragging, programmatic, lastLive
    local function CommitLive(value)
        if lastLive == value then return end
        lastLive = value
        if onCommit then onCommit(value) end
    end
    local function Paint(v)
        local clean = math.max(minVal, math.min(maxVal,
            math.floor(v / step + 0.5) * step))
        filled:SetWidth(math.max(1, slider:GetWidth() *
            (clean - minVal) / (maxVal - minVal)))
        percent:SetText(formatValue and formatValue(clean) or
            (math.floor(clean * 100 + 0.5) .. "%"))
        return clean
    end
    slider:SetScript("OnValueChanged", function(_, value, fromUser)
        local clean = Paint(value)
        -- Existing slider mode commits on mouse release. Only explicitly
        -- opted-in widget controls stream stepped updates while dragging.
        if programmatic or not (fromUser or dragging) then return end
        pending = clean
        if live then CommitLive(clean) end
    end)
    slider:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then
            dragging = true
            lastLive = nil
        end
    end)
    slider:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= "LeftButton" then return end
        dragging = false
        local nextVal = pending or Paint(slider:GetValue())
        pending = nil
        if live then CommitLive(nextVal)
        elseif onCommit then onCommit(nextVal) end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        local nextVal = Paint(slider:GetValue() + (delta > 0 and step or -step))
        programmatic = true
        slider:SetValue(nextVal)
        programmatic = false
        pending = nil
        if live then
            lastLive = nil
            CommitLive(nextVal)
        elseif onCommit then onCommit(nextVal) end
    end)
    function row:SetValue(v)
        programmatic = true
        pending = nil
        slider:SetValue(v)
        programmatic = false
        Paint(v)
    end
    function row:IsDragging() return dragging and true or false end
    function row:SetAvailable(yes)
        self.available = yes and true or false
        slider:SetEnabled(self.available)
        self:SetAlpha(self.available and 1 or 0.6)
    end
    ns.Tooltips.Bind(slider, function()
        return { title = caption,
            detail = (row.description:GetText() or detail or "") .. " Current: " ..
                (formatValue and formatValue(slider:GetValue()) or
                    (math.floor((slider:GetValue() or 1) * 100 + 0.5) .. "%")) ..
                ". Drag or use the mouse wheel to adjust.",
            anchor = "LEFT" }
    end)
    -- Compact rows hide long descriptions; hovering the row itself
    -- still reveals the full text using the existing addon tooltip owner.
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.compact then
            ns.Tooltips.Show(self, { title = caption,
                detail = self.description:GetText() or detail, anchor = "RIGHT" })
        end
    end)
    row:SetScript("OnLeave", function(self) ns.Tooltips.Hide(self) end)
    row:HookScript("OnHide", function(self) ns.Tooltips.Hide(self, true) end)
    row.slider = slider
    row.fill = filled
    function row:RefreshColors()
        track:SetColorTexture(unpack(C.track))
        filled:SetColorTexture(unpack(C.gold))
        self.resetIcon:SetVertexColor(unpack(C.gold))
    end
    function row:LayoutForWidth(width, compact)
        self.compact = compact
        self:SetHeight(compact and 32 or 64)
        self.name:ClearAllPoints()
        self.name:SetPoint("TOPLEFT", self, "TOPLEFT",
            1, compact and -7 or -8)
        self.name:SetWidth(math.max(76, width - (compact and 185 or 10)))
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
        self.description:SetWidth(math.max(70, width - 262))
        self.description:SetHeight(29)
        self.description:SetShown(not compact)
        slider:ClearAllPoints()
        if compact then
            slider:SetWidth(math.max(75, math.min(112, width - 165)))
        else
            slider:SetWidth(172)
        end
        slider:SetPoint("RIGHT", self, "RIGHT", -55, 0)
        -- Recompute the fill if the column width changes while visible.
        Paint(slider:GetValue())
    end
    row:RefreshColors()
    return row
end


-- other UI addons-reference scroll behavior, independently implemented for Duels.
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
        thumb:SetColorTexture(unpack(C.gold))
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

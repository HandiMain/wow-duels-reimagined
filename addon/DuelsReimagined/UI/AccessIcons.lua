local _, ns = ...

-- Adapted from Handi's BurstFX minimap/access-widget architecture.
-- ONE owner for both entry points; saved values live only in Core/Settings.
-- No quick-actions menus, patch notes, burst detection, or combat effects.
local Settings, Motion, Tooltips = ns.Settings, ns.Motion, ns.Tooltips
local Access = {}
ns.AccessIcons = Access

local ICON = "Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp"
local EDGE, MINIMAP_SIZE = 8, 36
local IDLE_DELAY, IDLE_ALPHA = 4, 0.60
local loginReady = false
local iconMode
local miniButton, widgetButton
local draggingMinimap, pendingMinimapAngle
local placedX, placedY
local lastMiniWanted = false
local compartmentRegistered = false

local SHAPE = {
    ROUND = {true,true,true,true},
    SQUARE = {false,false,false,false},
    ["CORNER-TOPLEFT"] = {false,false,false,true},
    ["CORNER-TOPRIGHT"] = {false,false,true,false},
    ["CORNER-BOTTOMLEFT"] = {false,true,false,false},
    ["CORNER-BOTTOMRIGHT"] = {true,false,false,false},
    ["SIDE-LEFT"] = {false,true,false,true},
    ["SIDE-RIGHT"] = {true,false,true,false},
    ["SIDE-TOP"] = {false,false,true,true},
    ["SIDE-BOTTOM"] = {true,true,false,false},
    ["TRICORNER-TOPLEFT"] = {false,true,true,true},
    ["TRICORNER-TOPRIGHT"] = {true,false,true,true},
    ["TRICORNER-BOTTOMLEFT"] = {true,true,false,true},
    ["TRICORNER-BOTTOMRIGHT"] = {true,true,true,false},
}

local function SafeNumber(value)
    return type(value) == "number" and value == value and
        (not issecretvalue or not issecretvalue(value))
end

local function Mode()
    return Settings.Get("iconMode") or "minimap"
end

local function SmoothStep(t)
    return t * t * (3 - 2 * t)
end

-- Shared animation driver is UI/Motion.lua. Never create an OnUpdate loop
-- for hovering, clicking or idling; only the minimap drag briefly polls.
local function AnimateScale(root, target, duration)
    Motion.Value(root, root:GetScale(), target, duration,
        function(region, value) region:SetScale(value) end)
end

local function BuildFace(button)
    local face = CreateFrame("Frame", nil, button)
    face:SetPoint("CENTER", button, "CENTER")
    face:SetSize(button:GetWidth(), button:GetHeight())
    face:EnableMouse(false)
    face:SetFrameLevel(button:GetFrameLevel() + 1)

    local glow = face:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ICON)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.88, 0.59, 0.34)
    glow:SetAlpha(0.035)

    local ring = face:CreateTexture(nil, "BORDER")
    ring:SetTexture(ICON)
    ring:SetPoint("CENTER")
    ring:SetBlendMode("ADD")
    ring:SetVertexColor(0.82, 0.62, 0.38)
    ring:SetAlpha(0.10)

    local mark = face:CreateTexture(button:GetName() .. "Icon", "ARTWORK")
    mark:SetPoint("CENTER")
    mark:SetTexture(ICON)
    button.Icon = mark

    local highlight = face:CreateTexture(nil, "OVERLAY")
    highlight:SetPoint("CENTER")
    highlight:SetTexture(ICON)
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.77, 0.52)
    highlight:SetAlpha(0.02)

    -- Reuse BurstFX's masked one-shot sweep when masks are supported.
    local sweep = face:CreateTexture(nil, "OVERLAY")
    sweep:SetColorTexture(1, 0.89, 0.70, 1)
    sweep:SetSize(7, 42)
    sweep:SetBlendMode("ADD")
    if sweep.SetRotation then sweep:SetRotation(math.rad(-18)) end
    sweep:SetAlpha(0)
    sweep:Hide()
    if face.CreateMaskTexture and sweep.AddMaskTexture then
        local mask = face:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        mask:SetPoint("CENTER")
        mask:SetSize(30, 30)
        sweep:AddMaskTexture(mask)
    end

    local style = {
        face = face, glow = glow, ring = ring, icon = mark,
        highlight = highlight, sweep = sweep,
    }
    local function Size(size)
        face:SetSize(size, size)
        glow:SetSize(size * 1.48, size * 1.48)
        ring:SetSize(size * 1.22, size * 1.22)
        local glyph = math.max(18, math.floor(size * 0.82 + 0.5))
        mark:SetSize(glyph, glyph)
        highlight:SetSize(glyph, glyph)
        sweep:SetHeight(size)
    end
    style.Size = Size
    Size(button:GetWidth())
    return style
end

local function Sweep(style)
    local sweep = style.sweep
    Motion.Stop(sweep, 0)
    sweep:Show()
    Motion.Value(sweep, 0, 1, 0.28, function(region, progress)
        local v = SmoothStep(progress)
        region:ClearAllPoints()
        region:SetPoint("CENTER", style.face, "CENTER", -20 + 40 * v, 0)
        region:SetAlpha(math.sin(math.pi * progress) * 0.40)
        if progress >= 1 then region:Hide() end
    end)
end

local function Hover(button, on)
    local style = button.duelsFace
    button.duelsHovering = on and true or false
    AnimateScale(style.face, on and 1.08 or 1, 0.18)
    Motion.Fade(style.glow, on and 0.18 or 0.035, 0.18)
    Motion.Fade(style.ring, on and 0.30 or 0.10, 0.18)
    Motion.Fade(style.highlight, on and 0.30 or 0.02, 0.18)
    if on then Sweep(style) end
end

local function Press(button, on)
    local style = button.duelsFace
    AnimateScale(style.face, on and 0.95 or
        (button.duelsHovering and 1.08 or 1), 0.08)
    if not on then
        Motion.Stop(style.highlight, 0.34)
        Motion.Fade(style.highlight, button.duelsHovering and 0.30 or 0.02, 0.28)
    end
end

local function Wake(button)
    button.duelsIdleToken = (button.duelsIdleToken or 0) + 1
    Motion.Fade(button, 1, 0.16)
end

local function IdleMinimap()
    if not miniButton then return end
    local button = miniButton
    button.duelsIdleToken = (button.duelsIdleToken or 0) + 1
    local token = button.duelsIdleToken
    if not loginReady or not button:IsShown() or button.duelsHovering or
        button.duelsDragging then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(IDLE_DELAY, function()
            if button.duelsIdleToken == token and button:IsShown() and
                not button.duelsHovering and not button.duelsDragging then
                Motion.Fade(button, IDLE_ALPHA, 0.30)
            end
        end)
    else
        Motion.Fade(button, IDLE_ALPHA, 0.30)
    end
end

local function WidgetOpacity()
    if not widgetButton then return end
    local button = widgetButton
    local target = (button.duelsHovering or button.duelsDragging) and 1
        or (1 - (Settings.Get("widgetTransparency") or 0))
    Motion.Fade(button, target, 0.18)
end

local function Toggle()
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
    if ns.Window and ns.Window.Toggle then ns.Window.Toggle() end
end

local function ConnectClick(button, isWidget)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self)
        Wake(self)
        Hover(self, true)
        if isWidget then WidgetOpacity() end
    end)
    button:SetScript("OnLeave", function(self)
        Hover(self, false)
        if isWidget then WidgetOpacity() else IdleMinimap() end
    end)
    button:SetScript("OnMouseDown", function(self, mouse)
        if mouse ~= "LeftButton" then return end
        self.duelsDraggedThisPress = false
        Press(self, true)
    end)
    button:SetScript("OnMouseUp", function(self, mouse)
        if mouse == "LeftButton" then Press(self, false) end
    end)
    button:SetScript("OnClick", function(self, which)
        if which ~= "LeftButton" or self.duelsDraggedThisPress then return end
        Toggle()
    end)
    button:HookScript("OnHide", function(self)
        self.duelsIdleToken = (self.duelsIdleToken or 0) + 1
        local face = self.duelsFace
        Motion.Stop(self, 1)
        Motion.Stop(face.face, 1)
        Motion.Stop(face.glow, 0.035)
        Motion.Stop(face.ring, 0.10)
        Motion.Stop(face.highlight, 0.02)
        Motion.Stop(face.sweep, 0)
        face.sweep:Hide()
        self.duelsHovering = false
        self.duelsDragging = false
    end)
    -- Bind after all explicit hover handlers; SetScript after HookScript
    -- previously replaced the shared tooltip hook.
    Tooltips.Bind(button, function()
        local opened = ns.Window and ns.Window.frame and ns.Window.frame:IsShown()
        return {
            title = "Duels Reimagined",
            detail = (opened and "Left-click: Close the window." or
                "Left-click: Open the window.") .. "\n" ..
                (isWidget and "Drag: Move the floating widget." or
                    "Drag: Move around the minimap."),
            outsideWindow = true,
            anchor = "LEFT",
        }
    end)
end

-- Polestar/Ellesmere collector interoperability: minimap addons discover
-- named Button children of Minimap and may adopt them into their own flyout.
-- When adopted, Duels must stop owning placement/visibility. This replaces
-- BurstFX's separate UIParent container only for the minimap button.
miniButton = CreateFrame("Button", "DuelsReimaginedMinimapButton", Minimap or UIParent)
miniButton:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
miniButton:SetFrameStrata("MEDIUM")
miniButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 8)
miniButton.duelsFace = BuildFace(miniButton)
ConnectClick(miniButton, false)
miniButton:Hide()

-- The movable access widget can be shown instead of, or alongside, Minimap.
widgetButton = CreateFrame("Button", "DuelsReimaginedAccessWidget", UIParent)
widgetButton:SetSize(42, 42)
widgetButton:SetFrameStrata("MEDIUM")
widgetButton:SetFrameLevel(35)
widgetButton:SetMovable(true)
widgetButton:SetClampedToScreen(true)
widgetButton.duelsFace = BuildFace(widgetButton)
ConnectClick(widgetButton, true)
widgetButton:Hide()

Access.minimapButton = miniButton
Access.widgetButton = widgetButton

local function RoundedQuadrant(shape, c, s)
    local entries = SHAPE[shape] or SHAPE.ROUND
    local quadrant = c >= 0 and (s > 0 and 3 or 1)
        or (s > 0 and 4 or 2)
    return entries[quadrant]
end

local function OwnsMinimapPlacement()
    if not Minimap or miniButton:GetParent() ~= Minimap then return false end
    if placedX == nil then return true end
    local point, relative, relativePoint, x, y = miniButton:GetPoint(1)
    return point == "CENTER" and relative == Minimap and
        relativePoint == "CENTER" and SafeNumber(x) and SafeNumber(y)
        and math.abs(x - placedX) < 1 and math.abs(y - placedY) < 1
end

local function PositionMinimap(angle)
    if not Minimap or
        (not draggingMinimap and not OwnsMinimapPlacement()) then return end
    angle = angle or Settings.Get("minimapAngle") or 225
    local r = math.rad(angle)
    local c, s = math.cos(r), math.sin(r)
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    if not SafeNumber(w) or w <= 0 then w = 140 end
    if not SafeNumber(h) or h <= 0 then h = w end
    local hx, hy = w / 2 + EDGE, h / 2 + EDGE
    local shape = "ROUND"
    if type(GetMinimapShape) == "function" then
        local ok, value = pcall(GetMinimapShape)
        if ok and type(value) == "string" then shape = string.upper(value) end
    end
    local x, y
    if RoundedQuadrant(shape, c, s) then
        x, y = c * hx, s * hy
    else
        local d = math.max(math.abs(c) / hx, math.abs(s) / hy, 0.001)
        x, y = c / d, s / d
    end
    miniButton:ClearAllPoints()
    miniButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    placedX, placedY = x, y
end

local function WidgetPosition()
    local x, y = Settings.GetWidgetPosition()
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    if SafeNumber(screenW) and SafeNumber(screenH) and screenW > 0 then
        local width = widgetButton:GetWidth()
        local halfW = math.max(width / 2, screenW / 2)
        local halfH = math.max(width / 2, screenH / 2)
        x = math.max(-halfW + width / 2, math.min(halfW - width / 2, x))
        y = math.max(-halfH + width / 2, math.min(halfH - width / 2, y))
    end
    widgetButton:ClearAllPoints()
    widgetButton:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function CursorAngle()
    if not Minimap or not GetCursorPosition then return nil end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not SafeNumber(mx) or not SafeNumber(my) or
        not SafeNumber(cx) or not SafeNumber(cy) or
        not SafeNumber(scale) or scale <= 0 then return nil end
    local atan = math.atan2
    if not atan then return nil end
    return math.deg(atan(cy / scale - my, cx / scale - mx)) % 360
end

miniButton:SetScript("OnDragStart", function(self)
    if not OwnsMinimapPlacement() then return end
    self.duelsDragging = true
    self.duelsDraggedThisPress = true
    pendingMinimapAngle = Settings.Get("minimapAngle")
    Wake(self)
    Press(self, false)
    Tooltips.Hide(self, true)
    draggingMinimap = true
    self:SetScript("OnUpdate", function()
        local angle = CursorAngle()
        if angle then
            pendingMinimapAngle = angle
            PositionMinimap(angle)
        end
    end)
end)
miniButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    draggingMinimap = false
    self.duelsDragging = false
    if pendingMinimapAngle then Settings.SetMinimapAngle(pendingMinimapAngle) end
    pendingMinimapAngle = nil
    PositionMinimap()
    if not self.duelsHovering then IdleMinimap() end
end)
miniButton:HookScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
    draggingMinimap = false
end)

widgetButton:SetScript("OnDragStart", function(self)
    self.duelsDragging = true
    self.duelsDraggedThisPress = true
    Wake(self)
    Tooltips.Hide(self, true)
    Press(self, false)
    self:StartMoving()
    WidgetOpacity()
end)
widgetButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.duelsDragging = false
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if SafeNumber(x) and SafeNumber(y) and
        SafeNumber(cx) and SafeNumber(cy) then
        Settings.SetWidgetPosition(x - cx, y - cy)
    end
    WidgetPosition()
    WidgetOpacity()
end)
widgetButton:HookScript("OnHide", function(self)
    if self.duelsDragging then self:StopMovingOrSizing() end
end)

function Access.Refresh()
    iconMode = Mode()
    widgetButton:SetSize(Settings.Get("widgetSize"), Settings.Get("widgetSize"))
    widgetButton.duelsFace.Size(Settings.Get("widgetSize"))
    PositionMinimap()
    WidgetPosition()
    local miniVisible = loginReady and Minimap and Minimap:IsShown()
        and (iconMode == "minimap" or iconMode == "both")
    if not miniVisible then
        miniButton:Hide()
    elseif not lastMiniWanted then
        -- A collector may have hidden this still-Minimap-parented button
        -- for its flyout. Avoid fighting its visibility on every Refresh.
        miniButton:Show()
    end
    lastMiniWanted = miniVisible and true or false
    widgetButton:SetShown(loginReady and
        (iconMode == "widget" or iconMode == "both"))
    if miniVisible then IdleMinimap() end
    WidgetOpacity()
end

function Access.ResetPositions()
    Settings.ResetAccessPositions()
end

function Access.GetRuntimeState()
    return {
        mode = Mode(), minimapShown = miniButton:IsShown(),
        widgetShown = widgetButton:IsShown(),
        widgetSize = Settings.Get("widgetSize"),
        widgetTransparency = Settings.Get("widgetTransparency"),
        minimapAngle = Settings.Get("minimapAngle"),
        animationOwner = "UI/Motion.lua", leftClick = "Window.Toggle",
        rightClickMenu = false, patchNotes = false,
        collectorOwned = Minimap and not OwnsMinimapPlacement() or false,
        compartmentEnabled = Settings.Get("showInCompartment"),
        compartmentRegistered = compartmentRegistered,
    }
end

-- Applies only on login after SavedVariables load. No unsupported runtime
-- unregister; toggling this preference requires Reload UI (BurstFX pattern).
Settings.RegisterReloadRequired("showInCompartment")
local function RegisterCompartment()
    if compartmentRegistered or not Settings.Get("showInCompartment") or
        not AddonCompartmentFrame or
        not AddonCompartmentFrame.RegisterAddon then return end
    local okay = pcall(function()
        AddonCompartmentFrame:RegisterAddon({
            text = "Duels Reimagined", icon = ICON,
            notCheckable = true,
            func = function() Toggle() end,
        })
    end)
    compartmentRegistered = okay
end

if Minimap and Minimap.HookScript then
    Minimap:HookScript("OnHide", function()
        if OwnsMinimapPlacement() then
            miniButton:Hide()
            -- An actual minimap visibility transition is ours to restore.
            lastMiniWanted = false
        end
    end)
    Minimap:HookScript("OnShow", function() if loginReady then Access.Refresh() end end)
    Minimap:HookScript("OnSizeChanged", function()
        if loginReady and not draggingMinimap then PositionMinimap() end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UI_SCALE_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        loginReady = true
        RegisterCompartment()
    end
    if loginReady then Access.Refresh() end
end)

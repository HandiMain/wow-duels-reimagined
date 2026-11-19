local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

local Window = {}
ns.Window = Window

local frame = CreateFrame("Frame", "DuelsReimaginedWindow", UIParent)
frame:SetSize(1300, 946)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()

-- The window's visible interior is inset from the decorative rim. The root
-- frame itself has NO backdrop, so dark pixels cannot bleed outside the metal.
local inset = 10
local interior = CreateFrame("Frame", nil, frame)
interior:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
interior:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
Style.Fill(interior, C.window)
Window.frame = frame

local function Drag(handle)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
end

-- These bands span the entire window, not individual navigation columns.
local header = CreateFrame("Frame", nil, frame)
header:SetHeight(112)
header:SetPoint("TOPLEFT", interior, "TOPLEFT")
header:SetPoint("TOPRIGHT", interior, "TOPRIGHT")
Style.Fill(header, C.header)
Drag(header)

local footer = CreateFrame("Frame", nil, frame)
footer:SetHeight(52)
footer:SetPoint("BOTTOMLEFT", interior, "BOTTOMLEFT")
footer:SetPoint("BOTTOMRIGHT", interior, "BOTTOMRIGHT")
Style.Fill(footer, C.footer)

local body = CreateFrame("Frame", nil, frame)
body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
local rail = CreateFrame("Frame", nil, body)
rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
rail:SetWidth(88)
Style.Fill(rail, C.rail)
Window.rail = rail

local nav = CreateFrame("Frame", nil, body)
nav:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
nav:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", 0, 0)
nav:SetWidth(244)
Style.Fill(nav, C.nav)
Window.nav = nav

local main = CreateFrame("Frame", nil, body)
main:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
main:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
Window.main = main

local content = CreateFrame("Frame", nil, main)
content:SetAllPoints(main)
Style.Fill(content, C.body)
Window.content = content

Window.chromeSeams = Chrome.Shell(frame, header, footer, rail, nav, content)
Window.header, Window.footer, Window.body = header, footer, body

-- Approved two-faction logo: one authored texture, no duplicated text or crest.
-- The PNG canvas is power-of-two with transparent padding. Crop only the
-- padding via UVs; preserve the original artwork's proportions in the header.
local brandLogo = header:CreateTexture(nil, "ARTWORK")
brandLogo:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\DuelsReimagined-HeaderLogo.png")
brandLogo:SetSize(280, 85)
brandLogo:SetPoint("LEFT", header, "LEFT", 18, 0)
brandLogo:SetTexCoord(62 / 1024, 962 / 1024, 119 / 512, 393 / 512)
Chrome.Sharp(brandLogo)

local Settings = ns.Settings
local scaleCaption = Style.Text(header, "Menu Scale", 12, C.muted)
scaleCaption:SetPoint("RIGHT", header, "RIGHT", -223, 0)

local scale = CreateFrame("Slider", nil, header)
scale:SetSize(80, 20)
scale:SetOrientation("HORIZONTAL")
scale:SetMinMaxValues(Settings.MIN_SCALE, Settings.MAX_SCALE)
scale:SetValueStep(Settings.SCALE_STEP)
if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
scale:EnableMouseWheel(true)
scale:SetPoint("LEFT", scaleCaption, "RIGHT", 15, 0)

local scaleTrack = scale:CreateTexture(nil, "BACKGROUND")
scaleTrack:SetColorTexture(0.23, 0.26, 0.30, 1)
scaleTrack:SetPoint("LEFT", scale, "LEFT")
scaleTrack:SetPoint("RIGHT", scale, "RIGHT")
scaleTrack:SetHeight(2)

local scaleFill = scale:CreateTexture(nil, "ARTWORK")
scaleFill:SetColorTexture(unpack(C.gold))
scaleFill:SetPoint("LEFT", scaleTrack, "LEFT")
scaleFill:SetHeight(2)

local scaleThumb = scale:CreateTexture(nil, "OVERLAY")
scaleThumb:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\SliderThumb.tga")
scaleThumb:SetSize(14, 14)
Chrome.Sharp(scaleThumb)
scale:SetThumbTexture(scaleThumb)

local scalePercent = Style.Text(header, "100%", 12, C.text)
scalePercent:SetPoint("LEFT", scale, "RIGHT", 10, 0)
Window.scaleCaption = scaleCaption
Window.scaleSlider = scale
Window.scalePercent = scalePercent

-- Menu Scale gets the same modified marker and per-setting reset as Options.
local scaleDot = Style.Text(header, "•", 13, C.gold)
scaleDot:SetPoint("RIGHT", scaleCaption, "LEFT", -4, 0)
local scaleReset = CreateFrame("Button", nil, header)
scaleReset:SetSize(18, 18)
scaleReset:SetPoint("RIGHT", scaleDot, "LEFT", -2, 0)
scaleReset:RegisterForClicks("LeftButtonUp")
local scaleResetIcon = scaleReset:CreateTexture(nil, "ARTWORK")
scaleResetIcon:SetAllPoints(scaleReset)
scaleResetIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Polestar\\reset.tga")
Chrome.Sharp(scaleResetIcon)
scaleReset:SetScript("OnClick", function()
    Settings.Reset("menuScale")
    if GameTooltip then GameTooltip:Hide() end
end)
scaleReset:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Reset Menu Scale to 100%", 1, 0.84, 0.57)
    GameTooltip:Show()
end)
scaleReset:SetScript("OnLeave", function(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)
Window.scaleReset = scaleReset
function Window.RefreshScaleMarker()
    local changed = Settings.IsModified("menuScale")
    scaleDot:SetShown(changed)
    scaleReset:SetShown(changed)
end

local function RoundScale(value)
    return Settings.NormalizeScale(value)
end

local pendingScale
local draggingScale = false
local function PaintScale(value)
    local v = RoundScale(value)
    scaleFill:SetWidth(math.max(1, scale:GetWidth() * (v - Settings.MIN_SCALE) / (Settings.MAX_SCALE - Settings.MIN_SCALE)))
    scalePercent:SetText(math.floor(v * 100 + 0.5) .. "%")
end

-- Match Polestar's 1300 x 946 physical-pixel default while respecting
-- UIParent scaling, the menu-scale preference and screen-safe margins.
-- The window is not resized continuously while the scale slider is dragged.
local BASE_WIDTH, BASE_HEIGHT, EDGE = 1300, 946, 16

-- A single geometry calculation owns defaults, resize bounds and screen-fit.
-- Use client UI units, so saved dimensions also respect Menu Scale.
local function WindowGeometry(menuScale)
    local parentH, parentW = UIParent:GetHeight(), UIParent:GetWidth()
    local physicalH
    if type(GetPhysicalScreenSize) == "function" then
        local _, h = GetPhysicalScreenSize()
        physicalH = h
    end
    local ppu = (type(physicalH) == "number" and physicalH > 0
        and parentH and parentH > 0) and physicalH / parentH or 1
    local growth = math.max(1,
        math.floor((physicalH or 0) / 1440 * 20 + 0.5) / 20)
    local maxW = math.max(1, math.floor(parentW / menuScale - 2 * EDGE))
    local maxH = math.max(1, math.floor(parentH / menuScale - 2 * EDGE))
    local minW, minH = math.min(1050, maxW), math.min(650, maxH)
    local defW = math.max(minW, math.min(maxW, math.floor(BASE_WIDTH * growth / ppu + 0.5)))
    local defH = math.max(minH, math.min(maxH, math.floor(BASE_HEIGHT * growth / ppu + 0.5)))
    return defW, defH, minW, minH, maxW, maxH
end

frame:SetResizable(true)
local function FitWindowToScreen(menuScale)
    local dw, dh, minW, minH, maxW, maxH = WindowGeometry(menuScale)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(minW, minH) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
    local savedW, savedH = Settings.GetWindowSize()
    frame:SetSize(math.max(minW, math.min(maxW, savedW or dw)),
        math.max(minH, math.min(maxH, savedH or dh)))
end

function Window.DefaultSize()
    return WindowGeometry(Settings.Get("menuScale") or 1)
end

function Window.CommitResize()
    local w, h = math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
    local defaultW, defaultH = Window.DefaultSize()
    if math.abs(w - defaultW) <= 2 and math.abs(h - defaultH) <= 2 then
        Settings.SetWindowSize(nil)
    else
        Settings.SetWindowSize(w, h)
    end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

function Window.ResetSize()
    Settings.SetWindowSize(nil)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end

function Window.ResetWindow()
    Settings.SetWindowSize(nil)
    Settings.Reset("menuScale")
    Window.ApplyScale(Settings.Get("menuScale") or 1)
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

function Window.IsDefault()
    return not Settings.HasWindowSize() and not Settings.IsModified("menuScale")
end

function Window.ApplyScale(value)
    local v = RoundScale(value)
    pendingScale = nil
    frame:SetScale(v)
    FitWindowToScreen(v)
    if ns.Header and ns.Header.AfterWindowResized then
        ns.Header.AfterWindowResized()
    end
    scale:SetValue(v)
    PaintScale(v)
    Window.RefreshScaleMarker()
end

scale:SetScript("OnMouseDown", function(_, mouse)
    if mouse == "LeftButton" then draggingScale = true end
end)
scale:SetScript("OnValueChanged", function(_, value, userInput)
    PaintScale(value)
    if userInput or draggingScale then pendingScale = RoundScale(value) end
    -- Deliberately do not call SetScale here: the slider must not move mid-drag.
end)
scale:SetScript("OnMouseUp", function(_, mouse)
    draggingScale = false
    if mouse == "RightButton" then
        pendingScale = nil
        Settings.Set("menuScale", 1)
        Window.ApplyScale(Settings.Get("menuScale") or 1)
        return
    end
    if mouse ~= "LeftButton" then return end
    local value = pendingScale or RoundScale(scale:GetValue())
    pendingScale = nil
    Settings.Set("menuScale", value)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)
scale:SetScript("OnMouseWheel", function(_, delta)
    draggingScale = false
    pendingScale = nil
    local value = RoundScale((Settings.Get("menuScale") or 1)
        + (delta > 0 and Settings.SCALE_STEP or -Settings.SCALE_STEP))
    Settings.Set("menuScale", value)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)
scale:SetScript("OnHide", function()
    draggingScale = false
    pendingScale = nil
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)

function Window.RefreshTheme()
    scaleFill:SetColorTexture(unpack(C.gold))
    scaleResetIcon:SetVertexColor(unpack(C.gold))
    -- This authored artwork remains legible under optional EllesmereUI colors.
    if Window.resizeGrip then Window.resizeGrip.icon:SetVertexColor(1, 1, 1) end
end

Window.ApplyScale(Settings.Get("menuScale") or 1)

-- One resize owner, regardless of active page. Persist once on mouse release.
local grip = CreateFrame("Button", nil, frame)
-- A 34x34 hit area sits INSIDE the bottom-right corner, clear of Close.
grip:SetSize(34, 34)
grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
grip:SetFrameLevel(frame:GetFrameLevel() + 45)
grip:RegisterForClicks("RightButtonUp")
local gripIcon = grip:CreateTexture(nil, "ARTWORK")
gripIcon:SetAllPoints(grip)
-- The new corner supplies the always-visible grip artwork. This separate
-- glow layer provides responsive feedback without a second overlapping icon.
gripIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Frame\\ResizeGripHighlight.png")
gripIcon:SetVertexColor(1, 1, 1)
gripIcon:SetAlpha(0)
Chrome.Sharp(gripIcon)
grip.icon = gripIcon
local sizing = false
grip:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" or (ns.Header and ns.Header.IsFolded()) then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    sizing = true
    frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" or not sizing then return end
    sizing = false
    frame:StopMovingOrSizing()
    Window.CommitResize()
end)
grip:SetScript("OnClick", function(_, button)
    if button == "RightButton" then Window.ResetSize() end
end)
grip:SetScript("OnEnter", function(self)
    Motion.Fade(gripIcon, 0.95, 0.12)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to resize", 1, 0.84, 0.57)
        GameTooltip:AddLine("Right-click: restore default dimensions.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
end)
grip:SetScript("OnLeave", function(self)
    Motion.Fade(gripIcon, 0, 0.18)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)
grip:SetScript("OnHide", function()
    if sizing then
        sizing = false
        frame:StopMovingOrSizing()
    end
end)
Window.resizeGrip = grip
function Window.SetSizingEnabled(on)
    if not on and sizing then
        sizing = false
        frame:StopMovingOrSizing()
    end
    frame:SetResizable(on and true or false)
    grip:SetShown(on and true or false)
    -- Fold also swaps the decorative grip back to a non-resizable corner.
    -- Otherwise the artwork would advertise an unavailable interaction.
    if Chrome.SetResizeCorner then Chrome.SetResizeCorner(on) end
end

local close = Style.Action(footer, "Close", "footer")
close:SetSize(120, 30)
-- Centered vertically, with safe padding from the actual interior boundary.
close:SetPoint("RIGHT", footer, "RIGHT", -32, 0)
close:SetScript("OnClick", function() frame:Hide() end)

local title = Style.Text(content, "Welcome to the Hall", 25, C.pale, true)
title:SetPoint("TOP", content, "TOP", 0, -27)
local titleRule = Chrome.Divider(content, 346, 16)
titleRule:SetPoint("TOP", title, "BOTTOM", 0, -7)
local subtitle = Style.Text(content, "Your dueling journey starts here.", 13, C.muted)
subtitle:SetPoint("TOP", titleRule, "BOTTOM", 0, -8)

local watermark = content:CreateTexture(nil, "BORDER")
watermark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Watermark.png")
watermark:SetSize(242, 220)
watermark:SetPoint("CENTER", content, "CENTER", 0, -3)
-- Trim uneven transparent padding without stretching the emblem.
watermark:SetTexCoord(0.085, 0.98, 0.055, 0.975)
watermark:SetAlpha(0.68)
watermark:EnableMouse(false)

local emptyHeading = Style.Text(content, "No duels recorded yet", 20, C.pale)
emptyHeading:SetPoint("BOTTOM", content, "BOTTOM", 0, 142)
local emptyDetail = Style.Text(content, "Your recent activity will appear here.", 13, C.muted)
emptyDetail:SetPoint("TOP", emptyHeading, "BOTTOM", 0, -8)
function Window.ShowPage(page)
    title:SetText(page.title or "")
    subtitle:SetText(page.subtitle or "")
    emptyHeading:SetText(page.emptyTitle or "")
    emptyDetail:SetText(page.emptyDetail or "")
    local isOptions = page.key == "options" or page.key == "interface"
    watermark:SetShown(not isOptions)
    emptyHeading:SetShown(not isOptions)
    emptyDetail:SetShown(not isOptions)
    if ns.Options then ns.Options.Show(isOptions and page.key or nil) end
    if frame:IsShown() then
        Motion.Stop(content, 0.68)
        Motion.Fade(content, 1, 0.19)
    end
end

frame:SetScript("OnHide", function()
    Motion.Stop(frame, 1)
    Motion.Stop(content, 1)
end)

function Window.Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        -- Recompute the physical-pixel footprint if resolution or UI scale changed.
        Window.ApplyScale(Settings.Get("menuScale") or 1)
        frame:SetAlpha(0.25)
        frame:Show()
        frame:Raise()
        Motion.Fade(frame, 1, 0.22)
    end
end

if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedWindow")
end

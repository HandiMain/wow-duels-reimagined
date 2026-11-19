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
header:SetHeight(82)
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

Chrome.Shell(frame, header, footer, rail, nav, content)

local brandIcon = header:CreateTexture(nil, "ARTWORK")
brandIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp")
brandIcon:SetSize(67, 67)
brandIcon:SetPoint("LEFT", header, "LEFT", 20, 0)

local brandTop = Style.Text(header, "DUELS", 27, C.pale, true)
brandTop:SetPoint("TOPLEFT", header, "TOPLEFT", 134, -14)
local brandBottom = Style.Text(header, "R E I M A G I N E D", 11, C.gold, true)
brandBottom:SetPoint("TOPLEFT", brandTop, "BOTTOMLEFT", 2, -5)

local Settings = ns.Settings
local scaleCaption = Style.Text(header, "Menu Scale", 12, C.muted)
scaleCaption:SetPoint("RIGHT", header, "RIGHT", -223, 0)

local scale = CreateFrame("Slider", nil, header)
scale:SetSize(116, 20)
scale:SetOrientation("HORIZONTAL")
scale:SetMinMaxValues(0.85, 1.15)
scale:SetValueStep(0.05)
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

local function RoundScale(value)
    return math.max(0.85, math.min(1.15,
        math.floor(value * 20 + 0.5) / 20))
end

local pendingScale
local draggingScale = false
local function PaintScale(value)
    local v = RoundScale(value)
    scaleFill:SetWidth(math.max(1, 116 * (v - 0.85) / 0.30))
    scalePercent:SetText(math.floor(v * 100 + 0.5) .. "%")
end

-- Match Polestar's 1300 x 946 physical-pixel default while respecting
-- UIParent scaling, the menu-scale preference and screen-safe margins.
-- The window is not resized continuously while the scale slider is dragged.
local BASE_WIDTH, BASE_HEIGHT, EDGE = 1300, 946, 16

local function FitWindowToScreen(menuScale)
    local parentH, parentW = UIParent:GetHeight(), UIParent:GetWidth()
    local physicalH
    if type(GetPhysicalScreenSize) == "function" then
        local _, h = GetPhysicalScreenSize()
        physicalH = h
    end
    local pixelsPerUnit = (type(physicalH) == "number" and physicalH > 0
        and parentH and parentH > 0) and physicalH / parentH or 1
    -- Polestar enlarges its default footprint in 5% steps above 1440p.
    local growth = math.max(1,
        math.floor((physicalH or 0) / 1440 * 20 + 0.5) / 20)
    local desiredW = math.floor(BASE_WIDTH * growth / pixelsPerUnit + 0.5)
    local desiredH = math.floor(BASE_HEIGHT * growth / pixelsPerUnit + 0.5)
    local limitW = math.max(1, math.floor(parentW / menuScale - 2 * EDGE))
    local limitH = math.max(1, math.floor(parentH / menuScale - 2 * EDGE))
    frame:SetSize(math.min(desiredW, limitW), math.min(desiredH, limitH))
end

function Window.ApplyScale(value)
    local v = RoundScale(value)
    pendingScale = nil
    frame:SetScale(v)
    FitWindowToScreen(v)
    scale:SetValue(v)
    PaintScale(v)
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
        + (delta > 0 and 0.05 or -0.05))
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
end

Window.ApplyScale(Settings.Get("menuScale") or 1)

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
    title:SetText(page.title)
    subtitle:SetText(page.subtitle)
    emptyHeading:SetText(page.emptyTitle)
    emptyDetail:SetText(page.emptyDetail)
    local isOptions = page.key == "options"
    watermark:SetShown(not isOptions)
    emptyHeading:SetShown(not isOptions)
    emptyDetail:SetShown(not isOptions)
    if ns.Options then ns.Options.Show(isOptions) end
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

local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

local Window = {}
ns.Window = Window

local frame = CreateFrame("Frame", "DuelsReimaginedWindow", UIParent)
frame:SetSize(1100, 660)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()
Style.Fill(frame, C.window)
Style.Border(frame, C.goldDim, 2)
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
header:SetHeight(90)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
Style.Fill(header, C.header)
Drag(header)

local footer = CreateFrame("Frame", nil, frame)
footer:SetHeight(56)
footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
Style.Fill(footer, C.header)

local body = CreateFrame("Frame", nil, frame)
body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
local rail = CreateFrame("Frame", nil, body)
rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
rail:SetWidth(108)
Style.Fill(rail, C.rail)
Window.rail = rail

local nav = CreateFrame("Frame", nil, body)
nav:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
nav:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", 0, 0)
nav:SetWidth(232)
Style.Fill(nav, C.nav)
Window.nav = nav

local main = CreateFrame("Frame", nil, body)
main:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
main:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
Style.Fill(main, C.body)
Window.main = main

local content = CreateFrame("Frame", nil, main)
content:SetAllPoints(main)
Style.Fill(content, C.body)
Window.content = content

Chrome.Shell(frame, header, footer, rail, nav, content)

local brandIcon = header:CreateTexture(nil, "ARTWORK")
brandIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp")
brandIcon:SetSize(75, 75)
brandIcon:SetPoint("LEFT", header, "LEFT", 16, 0)

local brandTop = Style.Text(header, "DUELS", 30, C.pale, true)
brandTop:SetPoint("TOPLEFT", header, "TOPLEFT", 137, -17)
local brandBottom = Style.Text(header, "R E I M A G I N E D", 12, C.gold, true)
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

function Window.ApplyScale(value)
    local v = RoundScale(value)
    pendingScale = nil
    frame:SetScale(v)
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

local close = Style.Action(footer, "Close")
close:SetSize(112, 32)
close:SetPoint("RIGHT", footer, "RIGHT", -30, 0)
close:SetScript("OnClick", function() frame:Hide() end)

local title = Style.Text(content, "Welcome to the Hall", 28, C.pale, true)
title:SetPoint("TOP", content, "TOP", 0, -34)
local titleRule = content:CreateTexture(nil, "ARTWORK")
titleRule:SetColorTexture(unpack(C.goldDim))
titleRule:SetSize(365, 1)
titleRule:SetPoint("TOP", title, "BOTTOM", 0, -16)
local subtitle = Style.Text(content, "Your dueling journey starts here.", 15, C.muted)
subtitle:SetPoint("TOP", titleRule, "BOTTOM", 0, -16)

local watermark = content:CreateTexture(nil, "BORDER")
watermark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp")
watermark:SetSize(255, 255)
watermark:SetPoint("CENTER", content, "CENTER", 0, -2)
watermark:SetAlpha(0.115)
watermark:EnableMouse(false)

local emptyHeading = Style.Text(content, "No duels recorded yet", 22, C.pale)
emptyHeading:SetPoint("BOTTOM", content, "BOTTOM", 0, 103)
local emptyDetail = Style.Text(content, "Your recent activity will appear here.", 14, C.muted)
emptyDetail:SetPoint("TOP", emptyHeading, "BOTTOM", 0, -8)
local action = Style.Action(content, "View My Record")
action:SetSize(230, 37)
action:SetPoint("TOP", emptyDetail, "BOTTOM", 0, -24)
Window.action = action

function Window.ShowPage(page)
    title:SetText(page.title)
    subtitle:SetText(page.subtitle)
    emptyHeading:SetText(page.emptyTitle)
    emptyDetail:SetText(page.emptyDetail)
    local isOptions = page.key == "options"
    watermark:SetShown(not isOptions)
    emptyHeading:SetShown(not isOptions)
    emptyDetail:SetShown(not isOptions)
    action:SetShown(not isOptions and page.action and true or false)
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
        frame:SetAlpha(0.25)
        frame:Show()
        frame:Raise()
        Motion.Fade(frame, 1, 0.22)
    end
end

if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedWindow")
end

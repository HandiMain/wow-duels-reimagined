local _, ns = ...
local Style = ns.Style
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

-- The header is the only drag surface. No keyboard or chat input is intercepted.
local function MakeDraggable(parent)
    parent:EnableMouse(true)
    parent:RegisterForDrag("LeftButton")
    parent:SetScript("OnDragStart", function() frame:StartMoving() end)
    parent:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
end

local footer = CreateFrame("Frame", nil, frame)
footer:SetHeight(48)
footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
Style.Fill(footer, C.footer)
local footerRule = Style.Rule(footer, "TOPLEFT", footer, "TOPLEFT", 1096, 1, C.goldDim)
footerRule:SetAlpha(0.75)
local footerText = Style.Text(footer, "Duels Reimagined", 12, C.muted)
footerText:SetPoint("LEFT", footer, "LEFT", 25, 0)
local close = Style.Action(footer, "Close")
close:SetSize(100, 28)
close:SetPoint("RIGHT", footer, "RIGHT", -18, 0)
close:SetScript("OnClick", function() frame:Hide() end)

local rail = CreateFrame("Frame", nil, frame)
rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
rail:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
rail:SetWidth(108)
Style.Fill(rail, C.rail)
Style.Rule(rail, "TOPRIGHT", rail, "TOPRIGHT", 1, 608, C.goldDim):SetAlpha(0.5)
Window.rail = rail

local nav = CreateFrame("Frame", nil, frame)
nav:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
nav:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", 0, 0)
nav:SetWidth(232)
Style.Fill(nav, C.nav)
Style.Rule(nav, "TOPRIGHT", nav, "TOPRIGHT", 1, 608, C.goldDim):SetAlpha(0.5)
Window.nav = nav

local main = CreateFrame("Frame", nil, frame)
main:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
main:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
Style.Fill(main, C.body)
Window.main = main

local brandIcon = rail:CreateTexture(nil, "ARTWORK")
brandIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp")
brandIcon:SetSize(64, 64)
brandIcon:SetPoint("TOP", rail, "TOP", 0, -14)

local brandTop = Style.Text(nav, "DUELS", 26, C.pale, true)
brandTop:SetPoint("TOPLEFT", nav, "TOPLEFT", 20, -24)
local brandBottom = Style.Text(nav, "REIMAGINED", 14, C.gold, true)
brandBottom:SetPoint("TOPLEFT", brandTop, "BOTTOMLEFT", 0, -3)
local brandRule = Style.Rule(nav, "TOPLEFT", nav, "TOPLEFT", 232, 1, C.goldDim)
brandRule:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -94)
MakeDraggable(nav)

local railDivider = Style.Rule(rail, "TOPLEFT", rail, "TOPLEFT", 108, 1, C.goldDim)
railDivider:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, -94)

local header = CreateFrame("Frame", nil, main)
header:SetHeight(94)
header:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
header:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
Style.Fill(header, C.header)
MakeDraggable(header)
local headerRule = header:CreateTexture(nil, "ARTWORK")
headerRule:SetColorTexture(unpack(C.goldDim))
headerRule:SetHeight(1)
headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

local scaleCaption = Style.Text(header, "Menu Scale", 12, C.muted)
scaleCaption:SetPoint("TOPRIGHT", header, "TOPRIGHT", -241, -34)
local scale = CreateFrame("Slider", nil, header)
scale:SetSize(112, 20)
scale:SetOrientation("HORIZONTAL")
scale:SetMinMaxValues(0.85, 1.15)
scale:SetValueStep(0.05)
scale:SetPoint("LEFT", scaleCaption, "RIGHT", 14, 0)
local scaleTrack = scale:CreateTexture(nil, "BACKGROUND")
scaleTrack:SetColorTexture(unpack(C.goldDim))
scaleTrack:SetPoint("LEFT", scale, "LEFT", 0, 0)
scaleTrack:SetPoint("RIGHT", scale, "RIGHT", 0, 0)
scaleTrack:SetHeight(3)
local scaleThumb = scale:CreateTexture(nil, "OVERLAY")
scaleThumb:SetColorTexture(unpack(C.gold))
scaleThumb:SetSize(11, 18)
scale:SetThumbTexture(scaleThumb)
local scalePercent = Style.Text(header, "100%", 12, C.text)
scalePercent:SetPoint("LEFT", scale, "RIGHT", 10, 0)
scale:SetScript("OnValueChanged", function(_, value)
    local rounded = math.floor(value * 20 + 0.5) / 20
    frame:SetScale(rounded)
    scalePercent:SetText(math.floor(rounded * 100 + 0.5) .. "%")
end)
scale:SetValue(1)

local xButton = CreateFrame("Button", nil, header)
xButton:SetSize(30, 30)
xButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -12, -12)
local xText = Style.Text(xButton, "X", 18, C.gold)
xText:SetPoint("CENTER")
xButton:SetScript("OnEnter", function() xText:SetTextColor(1, 0.35, 0.28) end)
xButton:SetScript("OnLeave", function() xText:SetTextColor(unpack(C.gold)) end)
xButton:SetScript("OnClick", function() frame:Hide() end)

local content = CreateFrame("Frame", nil, main)
content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
Window.content = content

local title = Style.Text(content, "Welcome to the Hall", 28, C.pale)
title:SetPoint("TOP", content, "TOP", 0, -35)
local titleRule = content:CreateTexture(nil, "ARTWORK")
titleRule:SetColorTexture(unpack(C.goldDim))
titleRule:SetHeight(1)
titleRule:SetWidth(350)
titleRule:SetPoint("TOP", title, "BOTTOM", 0, -17)
local subtitle = Style.Text(content, "Your dueling journey starts here.", 15, C.muted)
subtitle:SetPoint("TOP", titleRule, "BOTTOM", 0, -16)

local watermark = content:CreateTexture(nil, "BACKGROUND", nil, 1)
watermark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsReimagined-AddonIcon.blp")
watermark:SetSize(260, 260)
watermark:SetPoint("CENTER", content, "CENTER", 0, -25)
watermark:SetAlpha(0.095)

local emptyHeading = Style.Text(content, "No duels recorded yet", 23, C.pale)
emptyHeading:SetPoint("BOTTOM", content, "BOTTOM", 0, 100)
local emptyDetail = Style.Text(content, "Your recent activity will appear here.", 14, C.muted)
emptyDetail:SetPoint("TOP", emptyHeading, "BOTTOM", 0, -8)
local action = Style.Action(content, "View My Record")
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
end

function Window.Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame:Raise()
    end
end

if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedWindow")
end

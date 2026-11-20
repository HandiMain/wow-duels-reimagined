local _, ns = ...
-- Small UI-only feedback layer. All transitions use the existing Motion owner,
-- all persistent discovery acknowledgements go through Settings, and nothing
-- here updates gameplay, networking, character data or minimap positioning.
local Style, Motion, Settings = ns.Style, ns.Motion, ns.Settings
local C, Window = Style.color, ns.Window
local Feedback = {}
ns.Feedback = Feedback

local function Later(seconds, callback)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, callback) end
end

-- Two nonintrusive pulses around the exact setting found by Search/Patch Notes.
-- One target at a time; stale animation cancels when a different item is opened.
local targetLines = setmetatable({}, { __mode = "k" })
local activeTarget
local function Lines(target)
    if targetLines[target] then return targetLines[target] end
    local result = {}
    for i = 1, 4 do
        local tex = Style.Fill(target, C.gold, "OVERLAY")
        tex:ClearAllPoints()
        tex:SetAlpha(0)
        if i == 1 then
            tex:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
            tex:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
            tex:SetHeight(2)
        elseif i == 2 then
            tex:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
            tex:SetHeight(2)
        elseif i == 3 then
            tex:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
            tex:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)
            tex:SetWidth(2)
        else
            tex:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
            tex:SetWidth(2)
        end
        result[#result + 1] = tex
    end
    targetLines[target] = result
    target:HookScript("OnHide", function(self)
        Motion.Stop(self)
        for _, tex in ipairs(result) do tex:SetAlpha(0) end
    end)
    return result
end
local function ClearTarget(target)
    if not target then return end
    Motion.Stop(target)
    local lines = targetLines[target]
    if lines then for _, tex in ipairs(lines) do tex:SetAlpha(0) end end
end
function Feedback.PulseTarget(target)
    if not target or not target:IsShown() then return false end
    if activeTarget and activeTarget ~= target then ClearTarget(activeTarget) end
    activeTarget = target
    local lines = Lines(target)
    if Settings.Get("reduceMotion") then
        for _, tex in ipairs(lines) do tex:SetAlpha(0.70) end
        local marked = (target.duelsPulseToken or 0) + 1
        target.duelsPulseToken = marked
        Later(0.32, function()
            if target.duelsPulseToken == marked then ClearTarget(target) end
        end)
    else
        Motion.Value(target, 0, 1, 0.96, function(_, progress)
            local alpha = 0.88 * math.sin(progress * math.pi * 2)^2
            for _, tex in ipairs(lines) do tex:SetAlpha(alpha) end
            if progress >= 1 and activeTarget == target then activeTarget = nil end
        end)
    end
    return true
end

-- A single reusable, non-blocking toast inside the existing Duels window.
local toast = CreateFrame("Frame", nil, Window.frame)
toast:SetSize(284, 43)
toast:SetPoint("TOP", Window.content, "TOP", 0, -88)
toast:SetFrameLevel(Window.frame:GetFrameLevel() + 43)
toast:EnableMouse(false)
Style.Skin(toast, C.nav, { corner=9, edge=C.goldDim, shine=0.22, shade=0.24 })
local toastLabel = Style.Text(toast, "", 13, C.text)
toastLabel:SetPoint("CENTER")
toastLabel:SetWidth(266)
toastLabel:SetJustifyH("CENTER")
toast:Hide()
local toastToken = 0
function Feedback.Toast(message)
    if type(message) ~= "string" or message == "" or not Window.frame:IsShown() then return end
    toastToken = toastToken + 1
    local token = toastToken
    toastLabel:SetText(message)
    Motion.Stop(toast, 1)
    toast:Show()
    Later(1.8, function()
        if token ~= toastToken then return end
        Motion.Fade(toast, 0, 0.22)
        Later(0.25, function()
            if token == toastToken then toast:Hide() end
        end)
    end)
end

-- Action confirmation changes only the original real button's label.
local actionTokens = setmetatable({}, {__mode="k"})
function Feedback.ConfirmAction(button, message)
    if not button or not button.label or type(message) ~= "string" then return false end
    if button.duelsOriginalLabel == nil then
        button.duelsOriginalLabel = button.label:GetText()
    end
    local token = (actionTokens[button] or 0) + 1
    actionTokens[button] = token
    button.label:SetText(message)
    Later(1.45, function()
        if actionTokens[button] ~= token then return end
        button.label:SetText(button.duelsOriginalLabel)
        button.duelsOriginalLabel = nil
    end)
    return true
end

-- Feature NEW labels apply to real, newly-added controls only.
local badges = {}
function Feedback.NewBadge(parent, id, nearTitle)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(31, 15)
    if nearTitle and parent.name then
        badge:SetPoint("LEFT", parent.name, "LEFT", 112, 0)
    else
        badge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 6, 7)
    end
    Style.Fill(badge, C.gold)
    local text = Style.Text(badge, "NEW", 10, C.buttonText)
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    badges[id] = badge
    badge:SetShown(not Settings.HasSeenDiscovery(id))
    return badge
end
function Feedback.RefreshDiscovery()
    for id, badge in pairs(badges) do
        badge:SetShown(not Settings.HasSeenDiscovery(id))
    end
end
function Feedback.Acknowledge(id)
    Settings.MarkDiscoverySeen(id)
end

-- A faithful miniature of the EXISTING DR widget (not a fake gameplay UI).
local preview = CreateFrame("Frame", nil, Window.frame)
preview:SetSize(208, 114)
preview:SetFrameLevel(Window.frame:GetFrameLevel() + 40)
preview:EnableMouse(false)
Style.Skin(preview, C.nav, { corner=9, edge=C.goldDim, shine=0.21, shade=0.18 })
local title = Style.Text(preview, "WIDGET PREVIEW", 12, C.gold)
title:SetPoint("TOPLEFT", preview, "TOPLEFT", 13, -10)
local badgeIcon = preview:CreateTexture(nil, "ARTWORK")
badgeIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsDRIcon.png")
badgeIcon:SetPoint("LEFT", preview, "LEFT", 19, -6)
local previewInfo = Style.Text(preview, "", 12, C.text)
previewInfo:SetPoint("LEFT", preview, "LEFT", 102, -6)
previewInfo:SetWidth(92)
previewInfo:SetJustifyH("LEFT")
preview:Hide()
function Feedback.HidePreview() preview:Hide() end
function Feedback.ShowWidgetPreview(row)
    if not Window.frame:IsShown() or not row or not row:IsShown() or
        not row.available then return end
    local mode = Settings.Get("iconMode")
    if mode ~= "widget" and mode ~= "both" then return end
    -- Geometry belongs to the real option row and never mutates its slider.
    local size = math.min(67, Settings.Get("widgetSize"))
    badgeIcon:SetSize(size, size)
    badgeIcon:SetAlpha(math.max(0.10, 1 - Settings.Get("widgetTransparency")))
    previewInfo:SetText(math.floor(Settings.Get("widgetSize") + 0.5) ..
        " px\n" .. math.floor(Settings.Get("widgetTransparency") * 100 + 0.5) ..
        "% fade")
    preview:ClearAllPoints()
    preview:SetPoint("BOTTOMRIGHT", Window.content, "BOTTOMRIGHT", -20, 18)
    preview:Show()
    Feedback.Acknowledge("widget-preview-v1")
end
function Feedback.BindWidgetPreview(row)
    if not row then return end
    row:HookScript("OnEnter", function() Feedback.ShowWidgetPreview(row) end)
    row:HookScript("OnLeave", Feedback.HidePreview)
    row:HookScript("OnHide", Feedback.HidePreview)
    if row.slider then
        row.slider:HookScript("OnEnter", function() Feedback.ShowWidgetPreview(row) end)
        row.slider:HookScript("OnLeave", Feedback.HidePreview)
    end
end
Window.frame:HookScript("OnHide", function()
    toastToken = toastToken + 1
    Motion.Stop(toast, 1)
    toast:Hide()
    Feedback.HidePreview()
    ClearTarget(activeTarget)
    activeTarget = nil
end)

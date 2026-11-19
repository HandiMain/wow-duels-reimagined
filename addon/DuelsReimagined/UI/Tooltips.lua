local _, ns = ...

-- Shared, addon-only UI help. Do not hook or reskin Blizzard GameTooltip.
-- One frame, one motion owner, one set of theme-aware fonts/colors.
local Style, Motion = ns.Style, ns.Motion
local C = Style.color
local Tooltips = {}
ns.Tooltips = Tooltips

local WIDTH, PAD, GAP = 268, 11, 6
local activeOwner

local tip = CreateFrame("Frame", nil, UIParent)
tip:SetFrameStrata("TOOLTIP")
tip:SetFrameLevel(160)
tip:SetClampedToScreen(true)
tip:EnableMouse(false)
tip:SetSize(WIDTH, 48)
Style.Fill(tip, C.nav)
Style.Border(tip, C.goldDim, 1)

local heading = Style.Text(tip, "", 15, C.pale, true)
heading:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, -PAD)
heading:SetWidth(WIDTH - PAD * 2)
heading:SetJustifyH("LEFT")
heading:SetWordWrap(true)

local description = Style.Text(tip, "", 12, C.muted)
description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
description:SetWidth(WIDTH - PAD * 2)
description:SetJustifyH("LEFT")
description:SetWordWrap(true)
if description.SetSpacing then description:SetSpacing(2) end
tip:SetAlpha(0)
tip:Hide()

local function Value(value, owner)
    if type(value) ~= "function" then return value end
    local ok, result = pcall(value, owner)
    if ok then return result end
end

local function Content(owner, source)
    local data = Value(source, owner)
    if type(data) == "string" then return data end
    if type(data) ~= "table" then return end
    local title = Value(data.title, owner)
    local body = Value(data.detail, owner)
    local disabled = Value(data.disabled, owner)
    if type(disabled) == "string" and disabled ~= "" and
        (data.unavailable or (owner.IsEnabled and not owner:IsEnabled())) then
        body = disabled
    end
    if type(title) ~= "string" or title == "" then return end
    if type(body) ~= "string" or body == "" then body = nil end
    return title, body, data.anchor
end

function Tooltips.Enabled()
    -- A missing saved entry means enabled; no separate tooltip preference
    -- cache is allowed to drift from the central Settings owner.
    return not ns.Settings or ns.Settings.Get("showTooltips") ~= false
end

function Tooltips.Show(owner, source)
    if not Tooltips.Enabled() then
        Tooltips.Hide(nil, true)
        return
    end
    if not owner or not owner.IsShown or not owner:IsShown() then return end
    if ns.Window and ns.Window.frame and not ns.Window.frame:IsShown() then return end
    local title, body, anchor = Content(owner, source)
    if not title then return end
    Motion.Stop(tip, tip:GetAlpha())
    activeOwner = owner
    heading:SetText(title)
    description:SetText(body or "")
    description:SetShown(body ~= nil)

    -- Measure only after Show; font heights can be stale when hidden.
    local parentScale = math.max(0.01, UIParent:GetEffectiveScale())
    local ownerScale = math.max(0.01, owner:GetEffectiveScale())
    tip:SetScale(math.max(0.25, math.min(2, ownerScale / parentScale)))
    tip:Show()
    tip:SetAlpha(0)
    local hTitle = math.max(19, heading:GetStringHeight() or 19)
    local hDetail = body and math.max(15, description:GetStringHeight() or 15) or 0
    tip:SetSize(WIDTH, PAD * 2 + hTitle + (body and 5 + hDetail or 0))
    tip:ClearAllPoints()
    if anchor == "RIGHT" then
        tip:SetPoint("LEFT", owner, "RIGHT", GAP, 0)
    elseif anchor == "LEFT" then
        tip:SetPoint("RIGHT", owner, "LEFT", -GAP, 0)
    else
        local ownerTop, screenTop = owner:GetTop(), UIParent:GetTop()
        local extent = (tip:GetHeight() + GAP) * tip:GetEffectiveScale() / ownerScale
        if ownerTop and screenTop and
            not (issecretvalue and (issecretvalue(ownerTop) or issecretvalue(screenTop))) and
            ownerTop + extent > screenTop then
            tip:SetPoint("TOP", owner, "BOTTOM", 0, -GAP)
        else
            tip:SetPoint("BOTTOM", owner, "TOP", 0, GAP)
        end
    end
    Motion.Fade(tip, 1, Motion.Duration("quick"))
end

local function FadedOut(_, alpha)
    tip:SetAlpha(alpha)
    if alpha <= 0.001 and not activeOwner then tip:Hide() end
end

function Tooltips.Hide(owner, instant)
    if owner and activeOwner ~= owner then return end
    activeOwner = nil
    if not tip:IsShown() then return end
    if instant then
        Motion.Stop(tip, 0)
        tip:Hide()
    else
        Motion.Value(tip, tip:GetAlpha(), 0, Motion.Duration("quick"), FadedOut)
    end
end

function Tooltips.Refresh(owner)
    local who = activeOwner
    if who and (not owner or owner == who) and who._duelsTooltipInfo then
        Tooltips.Show(who, who._duelsTooltipInfo)
    end
end

-- Rebind updates descriptions without stacking duplicate hooks.
-- Shared widget factories call this, as should future manually-built buttons.
function Tooltips.Bind(region, info)
    if not region or not region.HookScript then return end
    region._duelsTooltipInfo = info
    if region._duelsTooltipBound then return end
    region._duelsTooltipBound = true
    region:HookScript("OnEnter", function(self)
        Tooltips.Show(self, self._duelsTooltipInfo)
    end)
    region:HookScript("OnLeave", function(self) Tooltips.Hide(self) end)
    region:HookScript("OnHide", function(self) Tooltips.Hide(self, true) end)
    region:HookScript("OnMouseDown", function(self) Tooltips.Hide(self, true) end)
end

function Tooltips.Owner() return activeOwner end

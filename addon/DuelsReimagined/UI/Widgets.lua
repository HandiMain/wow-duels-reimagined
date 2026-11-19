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
end

function methods:RefreshColors()
    -- Always repaint from the central theme, including mid-transition.
    PaintToggle(self.slideKey, self.progress)
    self.divider:SetColorTexture(unpack(C.goldDim))
    self.divider:SetAlpha(0.24)
    self.name:SetTextColor(unpack(C.text))
    self.description:SetTextColor(unpack(C.muted))
end

local function ToggleEnter(row)
    if row.available then
        Motion.Fade(row.hover, 0.22, 0.14)
    elseif row.unavailableReason and GameTooltip then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.unavailableReason, 1, 0.81, 0.52, 1, true)
        GameTooltip:Show()
    end
end

local function ToggleLeave(row)
    Motion.Fade(row.hover, 0, 0.18)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

function Widgets.ToggleRow(parent, label, description, onToggle)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(72)
    row:RegisterForClicks("LeftButtonUp")
    row.available = true
    row.checked = false
    row.progress = 0
    row.onToggle = onToggle
    row.slideKey = { owner = row }

    row.hover = Chrome.Texture(row, "Selection", 0, "BACKGROUND")
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    row.divider:SetHeight(1)

    row.name = Style.Text(row, label, 15, C.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -13)
    row.description = Style.Text(row, description, 12, C.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.description:SetPoint("RIGHT", row, "RIGHT", -77, 0)
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

    for name, fn in pairs(methods) do row[name] = fn end
    row:SetScript("OnClick", function(self)
        if self.available and self.onToggle then self.onToggle(not self.checked) end
    end)
    row:SetScript("OnEnter", ToggleEnter)
    row:SetScript("OnLeave", ToggleLeave)
    row:RefreshColors()
    return row
end

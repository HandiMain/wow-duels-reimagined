local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

-- Shared option controls, independent of the EllesmereUI integration.
local Widgets = {}
ns.Widgets = Widgets

local texPath = "Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\"
local SLIDE_TIME = 0.19

local function PaintThumb(key, p)
    local row = key.owner
    row.progress = p
    row.trackOn:SetAlpha(p)
    row.thumb:ClearAllPoints()
    row.thumb:SetPoint("LEFT", row.trackOff, "LEFT", 2 + 25 * p, 0)
    local off = 0.83
    row.thumb:SetVertexColor(
        off + (1 - off) * p,
        off + (0.95 - off) * p,
        off + (0.79 - off) * p, 1)
end

local methods = {}

function methods:SetChecked(value, immediate)
    local nextValue = value and true or false
    local destination = nextValue and 1 or 0
    if self.initialized and self.checked == nextValue then return end
    self.checked = nextValue
    if not self.initialized or immediate then
        Motion.Value(self.slideKey, self.progress or 0, destination, 0, PaintThumb)
    else
        Motion.Value(self.slideKey, self.progress or 0, destination, SLIDE_TIME, PaintThumb)
    end
    self.initialized = true
end

function methods:SetAvailable(available, reason)
    self.available = available and true or false
    self.unavailableReason = reason
    self:SetAlpha(self.available and 1 or 0.58)
    Motion.Fade(self.hover, 0, 0)
end

function methods:RefreshColors()
    local r, g, b = unpack(C.gold)
    self.trackOn:SetVertexColor(r, g, b, 1)
    -- The inactive surface stays neutral so the accent remains meaningful.
    self.trackOff:SetVertexColor(0.30, 0.36, 0.44, 1)
    self.divider:SetColorTexture(unpack(C.goldDim))
    self.divider:SetAlpha(0.24)
    self.name:SetTextColor(unpack(C.text))
    self.description:SetTextColor(unpack(C.muted))
end

local function Enter(row)
    if row.available then
        Motion.Fade(row.hover, 0.22, 0.15)
    elseif row.unavailableReason and GameTooltip then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.unavailableReason, 1, 0.81, 0.52, 1, true)
        GameTooltip:Show()
    end
end

local function Leave(row)
    Motion.Fade(row.hover, 0, 0.19)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function Click(row)
    if not row.available then return end
    if row.onToggle then row.onToggle(not row.checked) end
end

-- One reusable row with a capsule switch. Text, hit area and animation remain
-- real WoW regions; the track and knob are individually replaceable textures.
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
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.divider:SetHeight(1)

    row.name = Style.Text(row, label, 15, C.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -13)
    row.description = Style.Text(row, description, 12, C.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.description:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.description:SetJustifyH("LEFT")

    row.trackOff = row:CreateTexture(nil, "ARTWORK")
    row.trackOff:SetTexture(texPath .. "ToggleTrack.tga")
    row.trackOff:SetSize(48, 24)
    row.trackOff:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    row.trackOn = row:CreateTexture(nil, "OVERLAY")
    row.trackOn:SetTexture(texPath .. "ToggleTrack.tga")
    row.trackOn:SetAllPoints(row.trackOff)
    row.trackOn:SetAlpha(0)

    row.thumb = row:CreateTexture(nil, "OVERLAY")
    row.thumb:SetTexture(texPath .. "ToggleThumb.tga")
    row.thumb:SetSize(19, 19)

    for name, fn in pairs(methods) do row[name] = fn end
    row:RefreshColors()
    PaintThumb(row.slideKey, 0)

    row:SetScript("OnClick", Click)
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    return row
end

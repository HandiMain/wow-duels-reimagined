local _, ns = ...

local Style = {}
ns.Style = Style

Style.color = {
    gold = { 0.78, 0.61, 0.35, 1 },
    goldDim = { 0.40, 0.31, 0.20, 1 },
    red = { 0.63, 0.20, 0.20, 1 },
    pale = { 0.95, 0.88, 0.73, 1 },
    text = { 0.88, 0.86, 0.82, 1 },
    muted = { 0.65, 0.65, 0.67, 1 },
    window = { 0.038, 0.045, 0.057, 0.98 },
    rail = { 0.057, 0.060, 0.071, 1 },
    nav = { 0.069, 0.074, 0.086, 1 },
    body = { 0.050, 0.057, 0.068, 1 },
    header = { 0.065, 0.072, 0.086, 1 },
    footer = { 0.065, 0.064, 0.073, 1 },
    selected = { 0.25, 0.095, 0.10, 0.90 },
    hover = { 0.16, 0.14, 0.14, 0.85 },
    button = { 0.23, 0.105, 0.105, 1 },
}

function Style.Fill(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetColorTexture(unpack(color))
    return texture
end

function Style.Rule(parent, anchor1, relative, anchor2, width, height, color)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetColorTexture(unpack(color or Style.color.goldDim))
    texture:SetPoint(anchor1, relative, anchor2)
    texture:SetSize(width, height)
    return texture
end

function Style.Border(parent, color, thickness)
    local c = color or Style.color.goldDim
    local w = thickness or 1
    local top = parent:CreateTexture(nil, "BORDER")
    top:SetColorTexture(unpack(c))
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    top:SetHeight(w)
    local bottom = parent:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(unpack(c))
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(w)
    local left = parent:CreateTexture(nil, "BORDER")
    left:SetColorTexture(unpack(c))
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(w)
    local right = parent:CreateTexture(nil, "BORDER")
    right:SetColorTexture(unpack(c))
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(w)
end

function Style.Text(parent, value, size, color, outline)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 14, outline and "OUTLINE" or "")
    local c = color or Style.color.text
    label:SetTextColor(unpack(c))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(value or "")
    return label
end

function Style.Action(parent, caption)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(204, 36)
    local bg = Style.Fill(button, Style.color.button)
    Style.Border(button, Style.color.goldDim)
    local label = Style.Text(button, caption, 15, Style.color.pale)
    label:SetPoint("CENTER")
    button:SetScript("OnEnter", function()
        bg:SetColorTexture(0.34, 0.14, 0.14, 1)
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(unpack(Style.color.button))
    end)
    return button
end

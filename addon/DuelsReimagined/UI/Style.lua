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
    footer = { 0.065, 0.072, 0.086, 1 },
    selected = { 0.25, 0.095, 0.10, 0.90 },
    hover = { 0.16, 0.14, 0.14, 0.85 },
    button = { 0.23, 0.105, 0.105, 1 },
}

local colorTextures = {}
local fontStrings = {}

local function RegisterTexture(region, color)
    for token, value in pairs(Style.color) do
        if value == color then
            colorTextures[#colorTextures + 1] = { region = region, token = token }
            break
        end
    end
end

local function RegisterFont(label, size, color, outline)
    local token
    for name, value in pairs(Style.color) do
        if value == color then token = name; break end
    end
    fontStrings[#fontStrings + 1] = {
        label = label, token = token, size = size, outline = outline
    }
end

function Style.Fill(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetColorTexture(unpack(color))
    RegisterTexture(texture, color)
    return texture
end

function Style.Rule(parent, anchor1, relative, anchor2, width, height, color)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetColorTexture(unpack(color or Style.color.goldDim))
    RegisterTexture(texture, color or Style.color.goldDim)
    texture:SetPoint(anchor1, relative, anchor2)
    texture:SetSize(width, height)
    return texture
end

function Style.Border(parent, color, thickness)
    local c = color or Style.color.goldDim
    local w = thickness or 1
    local top = parent:CreateTexture(nil, "BORDER")
    top:SetColorTexture(unpack(c))
    RegisterTexture(top, c)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    top:SetHeight(w)
    local bottom = parent:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(unpack(c))
    RegisterTexture(bottom, c)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(w)
    local left = parent:CreateTexture(nil, "BORDER")
    left:SetColorTexture(unpack(c))
    RegisterTexture(left, c)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(w)
    local right = parent:CreateTexture(nil, "BORDER")
    right:SetColorTexture(unpack(c))
    RegisterTexture(right, c)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(w)
end

-- EditBoxes and other font-bearing controls use the same centralized
-- font repaint logic as FontStrings (including optional EllesmereUI fonts).
function Style.BindFont(region, size, outline)
    RegisterFont(region, size or 13, nil, outline)
end

function Style.Text(parent, value, size, color, outline)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 14, outline and "OUTLINE" or "")
    local c = color or Style.color.text
    label:SetTextColor(unpack(c))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(value or "")
    RegisterFont(label, size or 14, color or Style.color.text, outline)
    return label
end

function Style.Action(parent, caption, variant)
    local footer = variant == "footer"
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(footer and 112 or 204, footer and 32 or 36)
    Style.Fill(button, footer and Style.color.footer or Style.color.button)

    -- Render the approved button frame ABOVE its solid-color fallback.
    -- This avoids the bare text/plain red rectangle seen in Retail.
    ns.Chrome.Texture(button, footer and "ButtonFooter" or "Button",
        1, "ARTWORK")
    local hover = ns.Chrome.Texture(button, "Selection", 0, "ARTWORK")
    local label = Style.Text(button, caption, 15, Style.color.pale)
    label:SetPoint("CENTER")
    button:SetScript("OnEnter", function()
        ns.Motion.Fade(hover, footer and 0.14 or 0.21, 0.17)
    end)
    button:SetScript("OnLeave", function()
        ns.Motion.Fade(hover, 0, 0.21)
    end)
    button:SetScript("OnMouseDown", function()
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, -1)
    end)
    button:SetScript("OnMouseUp", function()
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
    end)
    return button
end


-- A single appearance owner repaints all shared UI primitives when themes change.
local defaultColors = {}
for name, value in pairs(Style.color) do defaultColors[name] = { unpack(value) } end

local function SetColor(name, r, g, b, a)
    local target = Style.color[name]
    target[1], target[2], target[3], target[4] = r, g, b, a or 1
end

function Style.ApplyTheme(accent, panel, fontPath)
    for name, default in pairs(defaultColors) do SetColor(name, unpack(default)) end

    if accent then
        local r, g, b = unpack(accent)
        SetColor("gold", r, g, b)
        SetColor("goldDim", r * 0.5, g * 0.5, b * 0.5)
    end
    if panel then
        local r, g, b = unpack(panel)
        local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        local factor = luma > 0.16 and 0.16 / luma or 1
        r, g, b = r * factor, g * factor, b * factor
        SetColor("window", r * 0.80, g * 0.80, b * 0.80, 0.98)
        SetColor("rail", r * 0.93, g * 0.93, b * 0.93)
        SetColor("nav", r, g, b)
        SetColor("body", r * 0.82, g * 0.82, b * 0.82)
        SetColor("header", r * 1.04, g * 1.04, b * 1.04)
        SetColor("footer", r * 1.04, g * 1.04, b * 1.04)
    end

    for _, item in ipairs(colorTextures) do
        item.region:SetColorTexture(unpack(Style.color[item.token]))
    end
    for _, item in ipairs(fontStrings) do
        local fs = item.label
        local path = fontPath or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local ok = fs:SetFont(path, item.size, item.outline and "OUTLINE" or "")
        if not ok and fontPath then
            fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
                item.size, item.outline and "OUTLINE" or "")
        end
        if item.token then fs:SetTextColor(unpack(Style.color[item.token])) end
    end
end

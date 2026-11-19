local _, ns = ...
local Style, C = ns.Style, ns.Style.color

-- A single owner for decorative artwork and shared window separators.
local Chrome = {}
ns.Chrome = Chrome

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
local metal = art .. "Frame\\"
local textureNames = {
    Selection = "Selection.png",
    SelectionRail = "SelectionRail.png",
    Button = "ButtonPrimary.png",
    ButtonFooter = "ButtonFooter.png",
}

function Chrome.Sharp(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return texture
end

function Chrome.Texture(parent, name, alpha, layer)
    local file = textureNames[name]
    if not file then return nil end
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetTexture(art .. file)
    tex:SetAllPoints(parent)
    tex:SetAlpha(alpha or 1)
    return Chrome.Sharp(tex)
end

function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(art .. "Icon" .. name .. ".png")
    return Chrome.Sharp(tex)
end

function Chrome.Divider(parent, width, height)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(art .. "Divider.png")
    tex:SetSize(width or 220, height or 15)
    return Chrome.Sharp(tex)
end

function Chrome.Shell(frame, header, footer, rail, nav)
    -- ONE outer rim, no additional drawn borders or backdrop-sized images.
    -- It frames the inset content rather than lying on top of an oversized fill.
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)

    local function Art(host, file, layer)
        local tex = host:CreateTexture(nil, layer or "ARTWORK")
        tex:SetTexture(metal .. file .. ".png")
        return Chrome.Sharp(tex)
    end

    local function Strip(file, first, second, vertical)
        local tex = Art(rim, file)
        tex:SetPoint(first, rim, first)
        tex:SetPoint(second, rim, second)
        if vertical then tex:SetWidth(16) else tex:SetHeight(16) end
    end

    Strip("TrimTop", "TOPLEFT", "TOPRIGHT", false)
    Strip("TrimBottom", "BOTTOMLEFT", "BOTTOMRIGHT", false)
    Strip("TrimLeft", "TOPLEFT", "BOTTOMLEFT", true)
    Strip("TrimRight", "TOPRIGHT", "BOTTOMRIGHT", true)

    for _, corner in ipairs({
        { "TL", "TOPLEFT" }, { "TR", "TOPRIGHT" },
        { "BL", "BOTTOMLEFT" }, { "BR", "BOTTOMRIGHT" },
    }) do
        local tex = Art(rim, "Corner" .. corner[1], "OVERLAY")
        tex:SetSize(64, 64)
        tex:SetPoint(corner[2], rim, corner[2])
    end

    -- A separate, thinner inset metallic divider set, still owned here.
    -- All seams are rendered in one overlay so adjacent panel fills cannot
    -- hide the ends of the strips or their joining diamonds.
    local seams = CreateFrame("Frame", nil, frame)
    seams:SetAllPoints(frame)
    seams:SetFrameLevel(frame:GetFrameLevel() + 12)
    seams:EnableMouse(false)

    local function Horizontal(host, edge)
        local tex = Art(seams, "InnerDividerH")
        local left = edge .. "LEFT"
        local right = edge .. "RIGHT"
        tex:SetPoint("LEFT", host, left)
        tex:SetPoint("RIGHT", host, right)
        tex:SetHeight(12)
    end

    local function Vertical(host)
        local tex = Art(seams, "InnerDividerV")
        tex:SetPoint("TOP", host, "TOPRIGHT")
        tex:SetPoint("BOTTOM", host, "BOTTOMRIGHT")
        tex:SetWidth(12)
    end

    Horizontal(header, "BOTTOM")
    Horizontal(footer, "TOP")
    Vertical(rail)
    Vertical(nav)

    -- Four shared junction pieces connect the header/footer seams to the
    -- two navigation column dividers. No extra border owner or duplicate line.
    for _, host in ipairs({ rail, nav }) do
        for _, anchor in ipairs({ "TOPRIGHT", "BOTTOMRIGHT" }) do
            local tex = Art(seams, "InnerJunction", "OVERLAY")
            tex:SetSize(18, 18)
            tex:SetPoint("CENTER", host, anchor)
        end
    end
    return seams
end

-- Options already owns its background and single inner-panel outline.
function Chrome.Panel() end

-- All main surfaces are Style.Fill regions and follow the central theme owner.
function Chrome.Refresh() end

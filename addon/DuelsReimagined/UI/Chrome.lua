local _, ns = ...
local Style, C = ns.Style, ns.Style.color

-- One owner for source artwork and the window's border/separators.
-- Full-panel screenshots were intentionally removed: each panel has one flat fill.
local Chrome = {}
ns.Chrome = Chrome

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
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
    Chrome.Sharp(tex)
    return tex
end

function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(art .. "Icon" .. name .. ".png")
    Chrome.Sharp(tex)
    return tex
end

function Chrome.Divider(parent, width, height)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(art .. "Divider.png")
    tex:SetSize(width or 220, height or 15)
    Chrome.Sharp(tex)
    return tex
end

function Chrome.Shell(frame, header, footer, rail, nav)
    -- The frame has ONE border owner. Its eight separate PNGs are the only
    -- outer frame artwork: four continuous strips plus four corner ornaments.
    -- Never add a second Style.Border or a page-sized border wallpaper.
    local metal = art .. "Frame\\"
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)

    local function Strip(filename, anchorA, anchorB, vertical)
        local tex = rim:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(metal .. filename .. ".png")
        tex:SetPoint(anchorA, rim, anchorA, 0, 0)
        tex:SetPoint(anchorB, rim, anchorB, 0, 0)
        if vertical then tex:SetWidth(16) else tex:SetHeight(16) end
        Chrome.Sharp(tex)
    end

    Strip("TrimTop", "TOPLEFT", "TOPRIGHT", false)
    Strip("TrimBottom", "BOTTOMLEFT", "BOTTOMRIGHT", false)
    Strip("TrimLeft", "TOPLEFT", "BOTTOMLEFT", true)
    Strip("TrimRight", "TOPRIGHT", "BOTTOMRIGHT", true)

    -- Corner PNGs contain only decorative metal, never backdrop pixels or
    -- the close icon. They sit flush with the same frame that owns the strips.
    for _, corner in ipairs({
        { "TL", "TOPLEFT" }, { "TR", "TOPRIGHT" },
        { "BL", "BOTTOMLEFT" }, { "BR", "BOTTOMRIGHT" },
    }) do
        local tex = rim:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(metal .. "Corner" .. corner[1] .. ".png")
        tex:SetSize(64, 64)
        tex:SetPoint(corner[2], rim, corner[2], 0, 0)
        Chrome.Sharp(tex)
    end

    local function Separator(host, point1, point2, vertical)
        local line = Style.Fill(host, C.goldDim, "ARTWORK")
        line:ClearAllPoints()
        line:SetPoint(point1, host, point1, 0, 0)
        line:SetPoint(point2, host, point2, 0, 0)
        if vertical then line:SetWidth(1) else line:SetHeight(1) end
        line:SetAlpha(0.40)
    end

    Separator(header, "BOTTOMLEFT", "BOTTOMRIGHT", false)
    Separator(footer, "TOPLEFT", "TOPRIGHT", false)
    Separator(rail, "TOPRIGHT", "BOTTOMRIGHT", true)
    Separator(nav, "TOPRIGHT", "BOTTOMRIGHT", true)
end

-- Options already owns its shared flat background and one independent outline.
function Chrome.Panel() end

-- All surviving surfaces are registered with Style.Fill, which repaints on
-- EllesmereUI theme changes. No second PNG-tint state is necessary.
function Chrome.Refresh() end

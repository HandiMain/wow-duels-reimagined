local _, ns = ...
local Style, C = ns.Style, ns.Style.color
local Chrome = {}
ns.Chrome = Chrome

-- Apart from the established small icons / DR mark, our chrome is now made
-- from inexpensive one-pixel UI textures. Every part follows Style tokens.
local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
function Chrome.Sharp(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex
end

function Chrome.Texture(parent, name, alpha, layer)
    local color = name == "SelectionRail" and C.tabActive or
        name == "Selection" and C.selected or
        name == "Button" and C.button or
        name == "ButtonFooter" and C.button or C.hover
    local tex = Style.Fill(parent, color, layer or "BACKGROUND")
    tex:SetAlpha(alpha or 1)
    return tex
end

-- Compatibility for old callers; no bitmap end caps or stretched graphics.
function Chrome.SlicedButton(parent)
    local ground = Style.Fill(parent, C.button)
    Style.Border(parent, C.gold, 1)
    return ground
end

function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(art .. "Icon" .. name .. ".png")
    return Chrome.Sharp(tex)
end

function Chrome.Divider(parent, width, height)
    -- Shared line + diamond, assembled from 1px strips. No image required.
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 220, height or 15)
    local left = Style.Fill(f, C.goldDim, "ARTWORK")
    left:ClearAllPoints()
    left:SetPoint("LEFT", f, "LEFT")
    left:SetPoint("RIGHT", f, "CENTER", -8, 0)
    left:SetHeight(1)
    local right = Style.Fill(f, C.goldDim, "ARTWORK")
    right:ClearAllPoints()
    right:SetPoint("LEFT", f, "CENTER", 8, 0)
    right:SetPoint("RIGHT", f, "RIGHT")
    right:SetHeight(1)
    local stone = Style.Fill(f, C.gold, "OVERLAY")
    stone:ClearAllPoints()
    stone:SetSize(6,6)
    stone:SetPoint("CENTER")
    if stone.SetRotation then stone:SetRotation(math.pi/4) end
    return f
end

function Chrome.SetResizeCorner(available)
    -- The corner remains physically resizable through Window.resizeGrip.
    -- No theme-locked corner texture is needed to switch its state.
end

function Chrome.Shell(frame, header, footer, rail, nav)
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)
    Style.SkinMask(rim, C.shellEdge, "rim", "ARTWORK", 1, 12, 0)
    Style.SkinMask(rim, C.headerText, "shine", "ARTWORK", 0, 12, 2):SetAlpha(0.10)
    local seams = CreateFrame("Frame", nil, frame)
    seams:SetAllPoints(frame)
    seams:SetFrameLevel(frame:GetFrameLevel() + 12)
    seams:EnableMouse(false)

    local function Line(frame, parent, first, second, vertical, color)
        local t = Style.Fill(frame, color or C.goldDim, "OVERLAY")
        t:ClearAllPoints()
        t:SetPoint(first, parent, first)
        t:SetPoint(second, parent, second)
        if vertical then t:SetWidth(1) else t:SetHeight(1) end
        return t
    end
    Line(seams, header, "BOTTOMLEFT", "BOTTOMRIGHT", false, C.shellEdge)
    Line(seams, rail, "BOTTOMLEFT", "BOTTOMRIGHT", false, C.shellEdge)
    Line(seams, footer, "TOPLEFT", "TOPRIGHT", false, C.shellEdge)
    Line(seams, nav, "TOPRIGHT", "BOTTOMRIGHT", true, C.border)

    -- Tiny corner insets suggest the selected concept without texture art.
    for _, edge in ipairs({
        {"TOPLEFT", 4, -4}, {"TOPRIGHT", -4, -4},
        {"BOTTOMLEFT", 4, 4}, {"BOTTOMRIGHT", -4, 4},
    }) do
        local cap = Style.Fill(rim, C.gold, "OVERLAY")
        cap:ClearAllPoints()
        cap:SetSize(5,5)
        cap:SetPoint(edge[1], rim, edge[1], edge[2], edge[3])
        if cap.SetRotation then cap:SetRotation(math.pi/4) end
    end
    return seams
end

function Chrome.Panel(parent, fill, opts)
    return Style.Skin(parent, fill or C.nav, opts)
end
function Chrome.Refresh() end

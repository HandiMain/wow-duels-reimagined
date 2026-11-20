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

-- Fixed-color, user-approved icon artwork. The four 64px atlas cells
-- contain transparent glyphs only; no button backing or theme masks.
-- Shared textures retain their own colors on any Duels/Ellesmere theme.
local NAV_ICON_ATLAS = "Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsNavigationAtlas.png"
local NAV_ICON_UV = {
    Hall       = { 0,   0.5, 0,   0.5 },
    Community  = { 0.5, 1,   0,   0.5 },
    PatchNotes = { 0,   0.5, 0.5, 1 },
    Options    = { 0.5, 1,   0.5, 1 },
}
function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    local uv = NAV_ICON_UV[name]
    if uv then
        tex:SetTexture(NAV_ICON_ATLAS)
        tex:SetTexCoord(unpack(uv))
        tex:SetVertexColor(1, 1, 1, 1)
    else
        -- Preserve legacy fallback for future, as-yet unapproved icons.
        tex:SetTexture(art .. "Icon" .. name .. ".png")
    end
    return Chrome.Sharp(tex)
end

-- All thin decorative rules share one pixel-stable renderer. A historical
-- 1-UI-unit SetColorTexture line would become sub-pixel at fractional window
-- positions, blinking while dragging a resize corner. Use two *physical*
-- pixels with softer alpha and snap the white-tinted rule to the pixel grid.
-- The same theme tokens (C.goldDim/C.gold) drive the divider under all
-- titles and inside Community cards / sidebar.
local pixelDividers = {}
local HAIRLINE_IMAGE = "Interface\\Buttons\\WHITE8X8"

local function PixelAlign(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(true) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

function Chrome.Divider(parent, width, height)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 220, height or 15)

    local left = Style.TintedImage(f, HAIRLINE_IMAGE, C.goldDim, "ARTWORK")
    left:SetPoint("LEFT", f, "LEFT")
    left:SetPoint("RIGHT", f, "CENTER", -8, 0)
    left:SetAlpha(0.66)
    PixelAlign(left)
    local right = Style.TintedImage(f, HAIRLINE_IMAGE, C.goldDim, "ARTWORK")
    right:SetPoint("LEFT", f, "CENTER", 8, 0)
    right:SetPoint("RIGHT", f, "RIGHT")
    right:SetAlpha(0.66)
    PixelAlign(right)

    local stone = Style.Fill(f, C.gold, "OVERLAY")
    stone:ClearAllPoints()
    stone:SetSize(6, 6)
    stone:SetPoint("CENTER")
    if stone.SetRotation then stone:SetRotation(math.pi / 4) end

    local entry = {frame=f, left=left, right=right}
    pixelDividers[#pixelDividers + 1] = entry
    local function SyncThickness()
        local px = Style.Pixel(f, 2)
        left:SetHeight(px)
        right:SetHeight(px)
    end
    SyncThickness()
    -- No OnUpdate: the Window scale / theme refresh explicitly repaints
    -- physical pixel thickness; the two lines automatically follow points.
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
function Chrome.Refresh()
    for _, entry in ipairs(pixelDividers) do
        local pixels = Style.Pixel(entry.frame, 2)
        entry.left:SetHeight(pixels)
        entry.right:SetHeight(pixels)
    end
end

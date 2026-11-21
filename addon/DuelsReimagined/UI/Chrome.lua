local _, ns = ...
local Style, C = ns.Style, ns.Style.color
local Chrome = {}
ns.Chrome = Chrome

-- Apart from the established small icons / DR mark, our chrome is now made
-- from inexpensive one-pixel UI textures. Every part follows Style tokens.
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

-- Fixed-color, user-approved icon artwork. The four 64px atlas cells
-- contain transparent glyphs only; no button backing or theme masks.
-- Shared textures retain their own colors on any Duels/Ellesmere theme.
local NAV_ICON_ATLAS = "Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsNavigationAtlas.png"
local NAV_ICON_UV = {
    Hall       = { 0,   0.5, 0,   0.5 },
    -- Crop only the ornamental line above the figures (atlas rows 0..18).
    -- Actual community glyph pixels are unchanged and still fully visible.
    Community  = { 0.5, 1, 19/128, 0.5 },
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
        -- Unknown future navigation keys use a Blizzard placeholder instead
        -- of referencing deleted legacy one-image-per-icon artwork.
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
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
local CORNER_ART = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCornerJewel.tga"

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

    local stone = f:CreateTexture(nil, "OVERLAY")
    stone:SetTexture(CORNER_ART)
    stone:SetSize(17, 17)
    stone:SetPoint("CENTER")
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

function Chrome.Shell(frame, header, footer, rail, nav)
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)
    -- Single sculpted copper frame. No oversized diamonds or duplicate
    -- gold rectangle strips: this transparent 9-slice owns the perimeter.
    Style.Plate(rim, "shellCopper", {
        corner=27, layer="ARTWORK", sublevel=1,
    })
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
    Line(seams, footer, "TOPLEFT", "TOPRIGHT", false, C.shellEdge)
    Line(seams, rail, "TOPRIGHT", "BOTTOMRIGHT", true, C.shellEdge)
    Line(seams, nav, "BOTTOMLEFT", "BOTTOMRIGHT", false, C.goldDim)

    -- The border's modest chamfer is integrated into its one texture.
    -- The separate four 31-pixel ornaments and duplicate edge glows were
    -- removed to match the approved restrained metallic frame.
    return seams
end

function Chrome.Refresh()
    for _, entry in ipairs(pixelDividers) do
        local pixels = Style.Pixel(entry.frame, 2)
        entry.left:SetHeight(pixels)
        entry.right:SetHeight(pixels)
    end
end

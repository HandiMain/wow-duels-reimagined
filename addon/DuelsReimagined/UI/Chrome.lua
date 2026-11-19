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
    -- A single, continuous frame border. No second rim, trim strips or
    -- corner screenshots that can overlap or introduce an unwanted X.
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)

    local function Edge(top, bottom, left, right, horizontal)
        local line = Style.Fill(rim, C.goldDim, "ARTWORK")
        line:ClearAllPoints()
        if horizontal then
            line:SetPoint(top, frame, top, 0, 0)
            line:SetPoint(bottom, frame, bottom, 0, 0)
            line:SetHeight(2)
        else
            line:SetPoint(left, frame, left, 0, 0)
            line:SetPoint(right, frame, right, 0, 0)
            line:SetWidth(2)
        end
        return line
    end

    Edge("TOPLEFT", "TOPRIGHT", nil, nil, true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, nil, true)
    Edge(nil, nil, "TOPLEFT", "BOTTOMLEFT", false)
    Edge(nil, nil, "TOPRIGHT", "BOTTOMRIGHT", false)

    local function Separator(host, point1, point2, vertical)
        local t = Style.Fill(host, C.goldDim, "ARTWORK")
        t:ClearAllPoints()
        t:SetPoint(point1, host, point1, 0, 0)
        t:SetPoint(point2, host, point2, 0, 0)
        if vertical then t:SetWidth(1) else t:SetHeight(1) end
        t:SetAlpha(0.43)
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

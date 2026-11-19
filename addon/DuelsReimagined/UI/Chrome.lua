local _, ns = ...
local Style, C = ns.Style, ns.Style.color

-- Only this module knows where the authored visuals are stored.
local Chrome = {}
ns.Chrome = Chrome

local concept = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
local legacy = "Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\"
local textureNames = {
    Header = "SurfaceHeader",
    Footer = "SurfaceFooter",
    Rail = "SurfaceRail",
    Nav = "SurfaceNav",
    Content = "SurfaceContent",
    Selection = "Selection",
    SelectionRail = "SelectionRail",
    Button = "ButtonPrimary",
    ButtonFooter = "ButtonFooter",
}
local themed = {}

function Chrome.Sharp(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return texture
end

function Chrome.Texture(parent, name, alpha, layer, token)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    local authored = textureNames[name]
    tex:SetTexture(authored and (concept .. authored .. ".png") or
        (legacy .. name .. ".tga"))
    tex:SetAllPoints(parent)
    tex:SetAlpha(alpha or 1)
    Chrome.Sharp(tex)
    if token then
        themed[#themed + 1] = { tex = tex, token = token }
    end
    return tex
end

function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(concept .. "Icon" .. name .. ".png")
    Chrome.Sharp(tex)
    return tex
end

-- Shared decorative rule with the concept's centered diamond and lighting.
function Chrome.Divider(parent, width, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(concept .. "Divider.png")
    line:SetSize(width or 220, height or 15)
    Chrome.Sharp(line)
    return line
end

function Chrome.Corners(parent)
    for _, spec in ipairs({
        { "TL", "TOPLEFT", 0, 0 },
        { "TR", "TOPRIGHT", 0, 0 },
        { "BL", "BOTTOMLEFT", 0, 0 },
        { "BR", "BOTTOMRIGHT", 0, 0 },
    }) do
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(concept .. "Corner" .. spec[1] .. ".png")
        t:SetSize(46, 46)
        t:SetPoint(spec[2], parent, spec[2], spec[3], spec[4])
        Chrome.Sharp(t)
    end
end

function Chrome.Shell(frame, header, footer, rail, nav, content)
    -- Art occupies BORDER, above base flat fills, below live labels/controls.
    Chrome.Texture(header, "Header", 1, "BORDER", "header")
    Chrome.Texture(footer, "Footer", 1, "BORDER", "footer")
    Chrome.Texture(rail, "Rail", 1, "BORDER", "rail")
    Chrome.Texture(nav, "Nav", 1, "BORDER", "nav")
    Chrome.Texture(content, "Content", 1, "BORDER", "body")

    -- Keep structural lines separate from the artwork and the click regions.
    local function Seam(parent, side, vertical)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(unpack(C.goldDim))
        t:SetAlpha(0.38)
        if vertical then
            t:SetPoint("TOP" .. side, parent, "TOP" .. side)
            t:SetPoint("BOTTOM" .. side, parent, "BOTTOM" .. side)
            t:SetWidth(1)
        else
            t:SetPoint(side .. "LEFT", parent, side .. "LEFT")
            t:SetPoint(side .. "RIGHT", parent, side .. "RIGHT")
            t:SetHeight(1)
        end
    end
    Seam(header, "BOTTOM", false)
    Seam(footer, "TOP", false)
    Seam(rail, "RIGHT", true)
    Seam(nav, "RIGHT", true)

    local rim = CreateFrame("Frame", nil, frame)
    rim:SetAllPoints(frame)
    rim:SetFrameLevel(frame:GetFrameLevel() + 20)
    rim:EnableMouse(false)
    local function Trim(file, corners, dimension, offset)
        local t = rim:CreateTexture(nil, "ARTWORK")
        t:SetTexture(legacy .. file .. ".tga")
        t:SetPoint(corners[1], frame, corners[1],
            corners[1]:find("RIGHT") and -offset or offset,
            corners[1]:find("BOTTOM") and offset or -offset)
        t:SetPoint(corners[2], frame, corners[2],
            corners[2]:find("RIGHT") and -offset or offset,
            corners[2]:find("BOTTOM") and offset or -offset)
        if dimension == "h" then t:SetHeight(7) else t:SetWidth(7) end
        return t
    end
    Trim("TrimH", {"TOPLEFT", "TOPRIGHT"}, "h", 7)
    Trim("TrimH", {"BOTTOMLEFT", "BOTTOMRIGHT"}, "h", 7)
    Trim("TrimV", {"TOPLEFT", "BOTTOMLEFT"}, "v", 7)
    Trim("TrimV", {"TOPRIGHT", "BOTTOMRIGHT"}, "v", 7)
    Chrome.Corners(rim)
end

function Chrome.Panel(panel)
    Chrome.Texture(panel, "Nav", 0.92, "BORDER", "nav")
end

function Chrome.Refresh()
    local matching = ns.Settings and ns.Settings.Get("matchColors")
        and ns.Theme and ns.Theme.IsAvailable()
    for _, entry in ipairs(themed) do
        if matching then
            local color = C[entry.token]
            entry.tex:SetVertexColor(
                math.min(1, 0.77 + color[1]),
                math.min(1, 0.77 + color[2]),
                math.min(1, 0.77 + color[3]), 1)
        else
            entry.tex:SetVertexColor(1, 1, 1, 1)
        end
    end
end

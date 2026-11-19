local _, ns = ...
local Style = ns.Style
local C = Style.color

local Chrome = {}
ns.Chrome = Chrome

local path = "Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\"
local themed = {}

function Chrome.Texture(parent, name, alpha, layer, token)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetTexture(path .. name .. ".tga")
    tex:SetAllPoints(parent)
    tex:SetAlpha(alpha or 1)
    if token then
        themed[#themed + 1] = { tex = tex, token = token }
    end
    return tex
end

function Chrome.Icon(parent, name)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\" .. name .. ".tga")
    return tex
end

function Chrome.Corners(parent, offset)
    local inset = offset or 0
    local specs = {
        { "TL", "TOPLEFT", inset, -inset },
        { "TR", "TOPRIGHT", -inset, -inset },
        { "BL", "BOTTOMLEFT", inset, inset },
        { "BR", "BOTTOMRIGHT", -inset, inset },
    }
    for _, spec in ipairs(specs) do
        local tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(path .. "Corner" .. spec[1] .. ".tga")
        tex:SetSize(48, 48)
        tex:SetPoint(spec[2], parent, spec[2], spec[3], spec[4])
    end
end

function Chrome.Shell(frame, header, footer, rail, nav, content)
    Chrome.Texture(header, "Header", 0.94, "BACKGROUND", "header")
    Chrome.Texture(footer, "Footer", 0.94, "BACKGROUND", "footer")
    Chrome.Texture(rail, "Rail", 0.92, "BACKGROUND", "rail")
    Chrome.Texture(nav, "Nav", 0.92, "BACKGROUND", "nav")
    Chrome.Texture(content, "Content", 0.94, "BACKGROUND", "body")

    local function Edge(host, at, vertical, w, h, color)
        local t = host:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(unpack(color))
        t:SetPoint(at, host, at, 0, 0)
        if vertical then t:SetWidth(w); t:SetHeight(h)
        else t:SetHeight(h); t:SetWidth(w) end
        t:SetAlpha(0.52)
        return t
    end

    -- Modular metallic trim, with separate corner pieces over the joins.
    local rimLayer = CreateFrame("Frame", nil, frame)
    rimLayer:SetAllPoints(frame)
    rimLayer:SetFrameLevel(frame:GetFrameLevel() + 20)
    rimLayer:EnableMouse(false)
    local top = rimLayer:CreateTexture(nil, "ARTWORK")
    top:SetTexture(path .. "TrimH.tga")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -2)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -2)
    top:SetHeight(7)
    local bottom = rimLayer:CreateTexture(nil, "ARTWORK")
    bottom:SetTexture(path .. "TrimH.tga")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 7, 2)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 2)
    bottom:SetHeight(7)
    local left = rimLayer:CreateTexture(nil, "ARTWORK")
    left:SetTexture(path .. "TrimV.tga")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -7)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 7)
    left:SetWidth(7)
    local right = rimLayer:CreateTexture(nil, "ARTWORK")
    right:SetTexture(path .. "TrimV.tga")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -7)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 7)
    right:SetWidth(7)

    -- Structural edges are independent of the panel artwork, not baked into it.
    Edge(header, "BOTTOMLEFT", false, 1100, 2, C.goldDim)
    Edge(footer, "TOPLEFT", false, 1100, 2, C.goldDim)
    Edge(rail, "TOPRIGHT", true, 1, 520, C.goldDim)
    Edge(nav, "TOPRIGHT", true, 1, 520, C.goldDim)

    Chrome.Corners(rimLayer)
end

function Chrome.Panel(panel)
    Chrome.Texture(panel, "Nav", 0.62, "BACKGROUND", "nav")
end

function Chrome.Refresh()
    local matching = ns.Settings and ns.Settings.Get("matchColors")
        and ns.Theme and ns.Theme.IsAvailable()
    for _, entry in ipairs(themed) do
        if matching then
            local c = C[entry.token]
            entry.tex:SetVertexColor(
                math.min(1.3, 0.76 + c[1] * 2.7),
                math.min(1.3, 0.76 + c[2] * 2.7),
                math.min(1.3, 0.76 + c[3] * 2.7), 1)
        else
            entry.tex:SetVertexColor(1, 1, 1, 1)
        end
    end
end

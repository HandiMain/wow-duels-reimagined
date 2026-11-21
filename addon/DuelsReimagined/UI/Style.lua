local _, ns = ...

-- ONE look owner for the entire addon. Every color is a semantic token;
-- no page, theme or integration makes an independent paint engine.
local Style = {}
ns.Style = Style

local function Hex(code)
    return {
        tonumber(code:sub(1, 2), 16) / 255,
        tonumber(code:sub(3, 4), 16) / 255,
        tonumber(code:sub(5, 6), 16) / 255, 1,
    }
end

-- Duel Hall is the single, user-approved house look. Keep one semantic
-- palette and one repaint owner; future looks can join this registry later.
-- Reference: approved in-game concept (2026-11-21), not legacy preview skins.
local schemes = {
    duelhall = {
        gold="E5B460", goldDim="A17A47", red="BE2820",
        pale="F0D59A", text="EEE7DE", muted="B7ADA2",
        window="171615", rail="141313", nav="1B1918",
        body="141312", header="100F0E", footer="100F0E",
        selected="543412", hover="39251C", button="65130F",
        shellEdge="BD9558", border="6C5035",
        tabActive="704A13", tabText="FFE9B9", tabMuted="D9CBB7",
        headerText="F2E9DA", headerMuted="BDB2A3",
        footerText="EFE4D4", footerMuted="ACA197",
        buttonText="FFF0C3", track="5F5150",
    },
}
local choices = { { key = "duelhall", label = "Duel Hall (Default)" } }
function Style.ThemeChoices() return choices end
function Style.IsTheme(key) return key == "duelhall" end

-- Stable table identities are important. Registered widgets hold references
-- to these colors and repaint in place on live look changes.
Style.color = {}
for token, code in pairs(schemes.duelhall) do Style.color[token] = Hex(code) end
local C = Style.color
local colorTextures, fontStrings, pixelEdges = {}, {}, {}

function Style.Pixel(region, physicalPixels)
    local scale = region and region.GetEffectiveScale and region:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    return (physicalPixels or 1) / scale
end

function Style.RefreshPixelEdges()
    for _, entry in ipairs(pixelEdges) do
        local unit = Style.Pixel(entry.parent, entry.pixels)
        for _, region in ipairs(entry.horizontal) do region:SetHeight(unit) end
        for _, region in ipairs(entry.vertical) do region:SetWidth(unit) end
    end
end

local function RegisterTexture(region, color, mode)
    for token, value in pairs(C) do
        if value == color then
            colorTextures[#colorTextures+1] = { region=region, token=token, mode=mode }
            return
        end
    end
end

local function RegisterFont(label, size, color, outline, role)
    local token
    for name, value in pairs(C) do if value == color then token = name; break end end
    fontStrings[#fontStrings+1] = {
        label=label, token=token, size=size, outline=outline, role=role,
    }
end

function Style.Fill(parent, color, layer)
    local region = parent:CreateTexture(nil, layer or "BACKGROUND")
    region:SetAllPoints(parent)
    region:SetColorTexture(unpack(color))
    RegisterTexture(region, color)
    return region
end

-- A tiny neutral icon shares the same live tint registry as all other skins.
function Style.TintedImage(parent, path, color, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(path)
    tex:SetVertexColor(unpack(color))
    RegisterTexture(tex, color, "vertex")
    return tex
end

function Style.Rule(parent, anchor1, relative, anchor2, width, height, color)
    local region = parent:CreateTexture(nil, "ARTWORK")
    local c = color or C.goldDim
    region:SetColorTexture(unpack(c))
    RegisterTexture(region, c)
    region:SetPoint(anchor1, relative, anchor2)
    region:SetSize(width, height)
    return region
end

function Style.Border(parent, color, thickness)
    local c, physical = color or C.border, thickness or 1
    local w = Style.Pixel(parent, physical)
    local edges = {}
    for _, spec in ipairs({
        { "TOPLEFT", "TOPRIGHT", true },
        { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false },
        { "TOPRIGHT", "BOTTOMRIGHT", false },
    }) do
        local edge = parent:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(unpack(c))
        RegisterTexture(edge, c)
        edge:SetPoint(spec[1], parent, spec[1])
        edge:SetPoint(spec[2], parent, spec[2])
        if spec[3] then edge:SetHeight(w) else edge:SetWidth(w) end
        edges[#edges+1] = edge
    end
    pixelEdges[#pixelEdges+1] = {
        parent=parent, pixels=physical,
        horizontal={edges[1], edges[2]}, vertical={edges[3], edges[4]},
    }
end


-- Neutral 128x128 TGA atlas: four 64x64 alpha masks (solid, sheen,
-- lower shade and beveled rim). All RGB is WHITE. These are geometry only:
-- the theme owner supplies every color through vertex tint on each repaint.
local SKIN_ATLAS = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\NeutralMasks.tga"
local masks = {
    face = { 0, 0 }, shine = { 64, 0 },
    shade = { 0, 64 }, rim = { 64, 64 },
}
local cuts = { 0, 16, 48, 64 }

-- Nine-slice geometry keeps soft corners a constant physical UI size when
-- a panel or tab grows. Every piece is a normal non-interactive texture on
-- its existing owner, so no child frame can cover icons or mouse targets.
function Style.SkinMask(parent, color, mask, layer, sublevel, corner, inset)
    local origin = masks[mask]
    assert(origin, "Unknown Duels skin mask: " .. tostring(mask))
    corner = corner or 11
    inset = inset or 0
    local tiles = {}
    for y = 1, 3 do
        for x = 1, 3 do
            local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 1)
            tex:SetTexture(SKIN_ATLAS)
            tex:SetTexCoord(
                (origin[1] + cuts[x]) / 128, (origin[1] + cuts[x + 1]) / 128,
                (origin[2] + cuts[y]) / 128, (origin[2] + cuts[y + 1]) / 128)
            tex:SetVertexColor(unpack(color))
            RegisterTexture(tex, color, "vertex")
            tiles[#tiles + 1] = tex
        end
    end
    local tl, t, tr, l, m, r, bl, b, br = unpack(tiles)
    tl:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    tl:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    tr:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    bl:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    br:SetSize(corner, corner)

    t:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    t:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    t:SetHeight(corner)
    b:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT")
    b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    b:SetHeight(corner)
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    l:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    l:SetWidth(corner)
    r:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT")
    r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    r:SetWidth(corner)
    m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")

    local group = { regions=tiles, alpha=1 }
    function group:SetAlpha(alpha)
        self.alpha = math.max(0, math.min(1, alpha or 0))
        for _, tex in ipairs(self.regions) do tex:SetAlpha(self.alpha) end
    end
    function group:GetAlpha() return self.alpha end
    return group
end

-- A single skin primitive for tab selections, action buttons, content
-- surfaces, Options cards, Community cards and Patch Notes panels.
-- It also exposes the standard GetAlpha/SetAlpha contract used by Motion,
-- preserving existing hover, pressed and selected-state animations.
-- Restrained second metal lip: pixel-width bevel lines, all theme-bound.
-- Unlike a stretched bitmap these anchors follow resizing and UI scale.
function Style.ForgedEdge(parent, opts)
    opts = opts or {}
    local inset = opts.inset or 3
    local amount = opts.alpha or 0.72
    local function Edge(color, alpha, points, vertical)
        local tex = Style.Fill(parent, color, "ARTWORK")
        tex:ClearAllPoints()
        for _, point in ipairs(points) do
            tex:SetPoint(unpack(point))
        end
        if vertical then
            tex:SetWidth(Style.Pixel(parent, 1))
        else
            tex:SetHeight(Style.Pixel(parent, 1))
        end
        tex:SetAlpha(alpha)
        return tex
    end
    Edge(opts.light or C.gold, amount, {
        {"TOPLEFT",parent,"TOPLEFT",inset,-inset},
        {"TOPRIGHT",parent,"TOPRIGHT",-inset,-inset}
    }, false)
    Edge(opts.dark or C.goldDim, amount*0.75, {
        {"BOTTOMLEFT",parent,"BOTTOMLEFT",inset,inset},
        {"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-inset,inset}
    }, false)
    Edge(opts.dark or C.goldDim, amount*0.60, {
        {"TOPLEFT",parent,"TOPLEFT",inset,-inset},
        {"BOTTOMLEFT",parent,"BOTTOMLEFT",inset,inset}
    }, true)
    Edge(opts.light or C.gold, amount*0.36, {
        {"TOPRIGHT",parent,"TOPRIGHT",-inset,-inset},
        {"BOTTOMRIGHT",parent,"BOTTOMRIGHT",-inset,inset}
    }, true)
end

function Style.Skin(parent, fill, opts)
    opts = opts or {}
    local corner, inset = opts.corner or 11, opts.inset or 0
    local face = Style.SkinMask(parent, fill, "face", "BACKGROUND", 1, corner, inset)
    local shine = Style.SkinMask(parent, opts.light or C.headerText,
        "shine", "BACKGROUND", 2, corner, inset)
    local shade = Style.SkinMask(parent, opts.dark or C.window,
        "shade", "BACKGROUND", 3, corner, inset)
    local rim = Style.SkinMask(parent, opts.edge or C.goldDim,
        "rim", "BORDER", 0, corner, inset)
    local strengths = {
        1, opts.shine == nil and 0.40 or opts.shine,
        opts.shade == nil and 0.28 or opts.shade,
        opts.rim == nil and 0.8 or opts.rim,
    }
    local groups = { face, shine, shade, rim }
    local skin = { alpha=1, groups=groups }
    function skin:SetAlpha(a)
        self.alpha = math.max(0, math.min(1, a or 0))
        for i, part in ipairs(self.groups) do
            part:SetAlpha(self.alpha * strengths[i])
        end
    end
    function skin:GetAlpha() return self.alpha end
    skin:SetAlpha(opts.alpha == nil and 1 or opts.alpha)
    return skin
end

-- Purpose-built texture atlas pieces, authored independently from the
-- approved screenshot. Each surface is a 9-slice so corners keep their
-- sculpted depth at different window sizes; buttons and labels stay native.
-- Concept-derived artwork supplied by the project owner (2026-11-21).
-- Sprite boundaries refer to the actual approved screenshot extraction, not
-- imagined brush strokes. The native Lua state and controls still own input.
local PLATE_ROOT = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\"
local CONCEPT_ATLAS = PLATE_ROOT .. "DuelExactAtlas.png"
local PLATES = {
    -- Procedural hall is kept ONLY for generic red controls (Close, header X).
    -- The primary Hall destination has its own literal concept-image region.
    hall = { path=PLATE_ROOT .. "DuelHallPlaque.tga", w=256, h=128, cutX=30, cutY=28 },
    gold = { path=CONCEPT_ATLAS, w=256, h=64, cutX=24, cutY=16,
        atlasX=256, atlasY=0, atlasW=512, atlasH=256 },
    dark = { path=CONCEPT_ATLAS, w=256, h=64, cutX=24, cutY=16,
        atlasX=256, atlasY=64, atlasW=512, atlasH=256 },
    cardBody = { path=CONCEPT_ATLAS, w=256, h=128, cutX=20, cutY=18,
        atlasX=0, atlasY=128, atlasW=512, atlasH=256 },
    cardHeading = { path=CONCEPT_ATLAS, w=256, h=64, cutX=22, cutY=12,
        atlasX=256, atlasY=128, atlasW=512, atlasH=256 },
}
local CONCEPT_REGIONS = {
    hall = { 0, 0.5, 0, 0.5 },
    corner = { 0.5, 0.625, 0.75, 1 },
}
function Style.ConceptImage(parent, region, layer, sublevel)
    local coords = assert(CONCEPT_REGIONS[region],
        "Unknown extracted concept region: " .. tostring(region))
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 1)
    tex:SetTexture(CONCEPT_ATLAS)
    tex:SetTexCoord(unpack(coords))
    return tex
end

function Style.Plate(parent, kind, opts)
    opts = opts or {}
    local data = assert(PLATES[kind], "Unknown Duel Hall plate: " .. tostring(kind))
    local corner = opts.corner or 11
    local inset = opts.inset or 0
    local tiles = {}
    local function Coord(spec, x, y)
        local xs = { 0, spec.cutX, spec.w-spec.cutX, spec.w }
        local ys = { 0, spec.cutY, spec.h-spec.cutY, spec.h }
        local u, v = spec.atlasX or 0, spec.atlasY or 0
        local aw, ah = spec.atlasW or spec.w, spec.atlasH or spec.h
        return (u+xs[x])/aw, (u+xs[x+1])/aw,
            (v+ys[y])/ah, (v+ys[y+1])/ah
    end
    for y = 1, 3 do
        for x = 1, 3 do
            local tex = parent:CreateTexture(nil, opts.layer or "BORDER", nil,
                opts.sublevel or 4)
            tex:SetTexture(data.path)
            tex:SetTexCoord(Coord(data, x, y))
            tiles[#tiles+1] = { tex=tex, x=x, y=y }
        end
    end
    local tl,t,tr,l,m,r,bl,b,br =
        tiles[1].tex,tiles[2].tex,tiles[3].tex,
        tiles[4].tex,tiles[5].tex,tiles[6].tex,
        tiles[7].tex,tiles[8].tex,tiles[9].tex
    tl:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset); tl:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset); tr:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset); bl:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset); br:SetSize(corner, corner)
    t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("TOPRIGHT", tr, "TOPLEFT"); t:SetHeight(corner)
    b:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT"); b:SetHeight(corner)
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMLEFT", bl, "TOPLEFT"); l:SetWidth(corner)
    r:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT"); r:SetWidth(corner)
    m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    local group = {}
    function group:SetStyle(newKind)
        local spec = assert(PLATES[newKind], "Unknown Duel Hall plate")
        for _, tile in ipairs(tiles) do
            tile.tex:SetTexture(spec.path)
            tile.tex:SetTexCoord(Coord(spec, tile.x, tile.y))
        end
    end
    function group:SetAlpha(value)
        for _, tile in ipairs(tiles) do tile.tex:SetAlpha(value) end
    end
    return group
end

function Style.LitBand(parent, base, opts)
    opts = opts or {}
    Style.Fill(parent, base)
    -- Short low-alpha strips are supported by both target clients and
    -- repaint live. No permanent OnUpdate or client-specific gradient API.
    local top = opts.light or C.headerText
    for i = 1, 7 do
        local strip = Style.Fill(parent, top)
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i - 1) * 5))
        strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((i - 1) * 5))
        strip:SetHeight(5)
        strip:SetAlpha((opts.brightness or 0.08) * (8 - i) / 7)
    end
    local bottom = Style.Fill(parent, opts.dark or C.window)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
    bottom:SetHeight(6)
    bottom:SetAlpha(0.28)
    local line = Style.Fill(parent, opts.edge or C.goldDim, "BORDER")
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetAlpha(0.47)
end

function Style.BindFont(region, size, outline, color)
    -- Explicit text role allows the dark header's search box to stay legible
    -- even when EllesmereUI applies a light content-panel palette.
    RegisterFont(region, size or 13, color or C.text, outline)
end

function Style.Text(parent, value, size, color, outline, role)
    local label = parent:CreateFontString(nil, "OVERLAY")
    local defaultPath = role == "display" and "Fonts\\MORPHEUS.TTF" or
        (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    if not label:SetFont(defaultPath, size or 14, outline and "OUTLINE" or "") then
        label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
            size or 14, outline and "OUTLINE" or "")
    end
    local c = color or C.text
    label:SetTextColor(unpack(c))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(value or "")
    RegisterFont(label, size or 14, c, outline, role)
    return label
end

-- Interactive buttons own native text/callbacks; only the decorative relief
-- uses nine-sliced art, never image-based labels or hit targets.
-- Optional fixed-brand palette keeps a specific action independent of theme
-- recoloring while reusing this shared button's input/motion/tooltip owner.
function Style.Action(parent, caption, variant, palette)
    local footer = variant == "footer"
    local community = variant == "community"
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(footer and 112 or 204, footer and 32 or 36)
    button:RegisterForClicks("LeftButtonUp")
    -- Raised, theme-tintable capsule by default. A private landing palette
    -- passes ALL paint roles explicitly, including the hidden gloss/shade,
    -- so EllesmereUI and theme refresh cannot silently recolor the buttons.
    local hover
    if palette then
        Style.Skin(button, palette.fill, {
            corner=11, edge=palette.edge, light=palette.light,
            dark=palette.dark, shine=0.28, shade=0.20, rim=0.88,
        })
        hover = Style.Skin(button, palette.hover, {
            corner=11, edge=palette.edge, light=palette.light,
            dark=palette.dark, shine=0.20, shade=0.10, rim=0.70,
            alpha=0,
        })
    else
        Style.Skin(button, C.button, {
            corner=footer and 7 or 9, edge=C.gold, shine=0.52, shade=0.42, rim=0.97,
        })
        Style.ForgedEdge(button, { inset=3, alpha=0.52 })
        if footer then
            -- Actual red, independently painted Close plate: all button
            -- text and callbacks remain separate and dynamic.
            Style.Plate(button, "hall", { corner=9 })
        end
        hover = Style.Skin(button, C.gold, {
            corner=11, edge=C.headerText, shine=0.36, shade=0.17, rim=0.74,
            alpha=0,
        })
    end
    local label = Style.Text(button, caption, 15,
        palette and palette.text or C.buttonText)
    label:SetPoint("CENTER")
    button:SetScript("OnEnter", function()
        ns.Motion.Fade(hover, 0.20, 0.16)
    end)
    button:SetScript("OnLeave", function()
        ns.Motion.Fade(hover, 0, 0.18)
    end)
    button:SetScript("OnMouseDown", function()
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, -1)
    end)
    button:SetScript("OnMouseUp", function()
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
    end)
    if ns.Widgets and ns.Widgets.PressFeedback then
        ns.Widgets.PressFeedback(button, hover)
    end
    if ns.Tooltips then
        ns.Tooltips.Bind(button, { title = caption,
            detail = "Click to activate this action." })
    end
    button.label = label
    return button
end

local function SetColor(name, r, g, b, a)
    local target = C[name]
    if not target then return end
    target[1], target[2], target[3], target[4] = r, g, b, a or 1
end
local function Mix(a, b, amount)
    return {
        a[1] * (1-amount) + b[1] * amount,
        a[2] * (1-amount) + b[2] * amount,
        a[3] * (1-amount) + b[3] * amount,
    }
end
local function Luma(c)
    return 0.2126*c[1] + 0.7152*c[2] + 0.0722*c[3]
end
local function Put(name, v)
    SetColor(name, v[1], v[2], v[3], v[4])
end
local WHITE, BLACK = {1,1,1}, {0,0,0}
local function FromTheme()
    local selected = ns.Settings and ns.Settings.Get("uiTheme") or "duelhall"
    for name, hex in pairs(schemes[selected] or schemes.duelhall) do
        Put(name, Hex(hex))
    end
end

-- A theme changes backgrounds, text, borders, tabs, controls and buttons.
-- EllesmereUI's OPTIONAL public colors override those same roles rather
-- than repainting only one or two lines. Contrast follows dark/light panels.
function Style.ApplyTheme(accent, panel, fontPath)
    FromTheme()
    if panel then
        local light = Luma(panel) >= 0.48
        local ink = light and {0.18,0.18,0.20} or {0.92,0.92,0.94}
        local muted = light and {0.36,0.36,0.40} or {0.71,0.73,0.77}
        local ground = Mix(panel, light and WHITE or BLACK, light and 0.045 or 0.06)
        local alt = Mix(panel, light and BLACK or WHITE, light and 0.06 or 0.09)
        for _, key in ipairs({ "window","header","footer","rail" }) do Put(key, ground) end
        for _, key in ipairs({ "nav","body" }) do Put(key, alt) end
        Put("text", ink)
        Put("pale", ink)
        Put("muted", muted)
        Put("headerText", ink)
        Put("footerText", ink)
        Put("tabText", ink)
        Put("tabMuted", muted)
        Put("headerMuted", muted)
        Put("footerMuted", muted)
        Put("border", Mix(panel, ink, 0.22))
        Put("goldDim", Mix(panel, ink, 0.27))
        Put("selected", Mix(alt, ink, 0.11))
        Put("hover", Mix(alt, ink, 0.075))
        Put("track", Mix(panel, ink, 0.32))
    end
    if accent then
        local a = Mix(accent, (Luma(accent) < 0.32 and WHITE or BLACK),
            Luma(accent) < 0.32 and 0.14 or 0.06)
        for _, key in ipairs({ "gold","red","button","tabActive" }) do Put(key, a) end
        Put("shellEdge", Mix(a, C.header, 0.28))
        -- Selected rows retain a readable surface, not full-strength accent.
        Put("selected", Mix(C.body, a, 0.20))
        Put("hover", Mix(C.body, a, 0.11))
        Put("buttonText", Luma(a) >= 0.53 and BLACK or WHITE)
    end
    for _, entry in ipairs(colorTextures) do
        local value = C[entry.token]
        -- WoW may overwrite a texture's alpha while changing its color.
        -- Preserve transient hover/selected/gloss opacity across theme
        -- changes, including palettes received from EllesmereUI.
        local opacity = entry.region:GetAlpha()
        if entry.mode == "vertex" then
            entry.region:SetVertexColor(unpack(value))
        else
            entry.region:SetColorTexture(unpack(value))
        end
        entry.region:SetAlpha(opacity)
    end
    local scale = ns.Settings and ns.Settings.Get("fontScale") or 1
    local mode = ns.Settings and ns.Settings.Get("fontOutline") or "default"
    for _, entry in ipairs(fontStrings) do
        local fs = entry.label
        local path = fontPath or
            (entry.role == "display" and "Fonts\\MORPHEUS.TTF") or
            STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local size = entry.size * scale
        local outline = entry.outline and "OUTLINE" or ""
        if mode == "none" then outline = ""
        elseif mode == "outline" then outline = "OUTLINE"
        elseif mode == "thick" then outline = "THICKOUTLINE" end
        local ok = fs:SetFont(path, size, outline)
        if not ok then
            fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, outline)
        end
        if entry.token then fs:SetTextColor(unpack(C[entry.token])) end
    end
end

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
-- Reference: approved in-game artwork (2026-11-21), not legacy preview skins.
local duelHall = {
        -- Source-matched near-black + gilt, not the former sepia/brown wash.
        gold="E7B53D", goldDim="986E38", red="BB1712",
        pale="FFDA8B", text="F4F1EB", muted="B8B6B4",
        window="0F1011", rail="0D0E0F", nav="171719",
        body="101112", header="090A0B", footer="090A0B",
        selected="5B3706", hover="2D251B", button="690D09",
        shellEdge="B88A48", border="4F4132",
        tabActive="744800", tabText="FFF0D0", tabMuted="DDD7CB",
        headerText="F7F5F0", headerMuted="BFC0BF",
        footerText="F4F1EB", footerMuted="A7A9AA",
        buttonText="FFE6B5", track="4F5052",
}

-- Stable table identities are important. Registered widgets hold references
-- to these colors and repaint in place on live look changes.
Style.color = {}
for token, code in pairs(duelHall) do Style.color[token] = Hex(code) end
local C = Style.color
local colorTextures, fontStrings, pixelEdges = {}, {}, {}
-- Shared bounded-label measurement; no permanent OnUpdate or duplicate font engine.
local function FitLabelFont(entry)
    local fit = entry.fit
    if not fit then return end
    local fs = entry.label
    local face, size, flags = fs:GetFont()
    if not face or not size then return end
    local room = math.max(1, fit.button:GetWidth() - fit.left - fit.right - 3)
    local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
    if not measure then return end
    local current = size
    while current > fit.minimum and measure(fs) > room do
        current = math.max(fit.minimum, current - 0.75)
        if not fs:SetFont(face, current, flags or "") then break end
    end
end

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
    -- Large window canvases must not scale the 64px shine/shade masks
    -- across hundreds of pixels: their quantized rows become horizontal
    -- bands. Keep the rounded face/rim, with short edge fades and a neutral
    -- solid center. This is deliberately opt-in: small interactive controls
    -- retain their established 9-slice lighting and feedback.
    if opts.smooth then
        strengths[2], strengths[3] = 0, 0
        local function EdgeFade(top, height, bright, alpha)
            local tex = parent:CreateTexture(nil, "BACKGROUND", nil, 4)
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetVertexColor(1, 1, 1, 1)
            local edge = corner + inset
            if top then
                tex:SetPoint("TOPLEFT", parent, "TOPLEFT", edge, -inset)
                tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -edge, -inset)
            else
                tex:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", edge, inset)
                tex:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, inset)
            end
            tex:SetHeight(height)
            if tex.SetGradient and CreateColor then
                local r = bright and 1 or 0
                local lit = CreateColor(r, r, r, alpha)
                local clear = CreateColor(r, r, r, 0)
                -- WoW gradient arguments are bottom color then top color.
                tex:SetGradient("VERTICAL", top and clear or lit,
                    top and lit or clear)
            else
                -- Unsupported clients get an even, line-free dark fill.
                tex:Hide()
            end
        end
        EdgeFade(true, 112, true, 0.024)
        EdgeFade(false, 88, false, 0.045)
    end
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

-- One reusable live feedback surface ABOVE 9-sliced painted buttons.
-- The older Style.Skin overlays lived in BACKGROUND/BORDER and were hidden
-- by the approved ARTWORK-level artwork plaque. All hover/selected colors
-- now stay visible while native buttons and icons retain their input owner.
function Style.FeedbackOverlay(parent, opts)
    opts = opts or {}
    local corner, inset = opts.corner or 10, opts.inset or 2
    local sheen = Style.SkinMask(parent, opts.fill or C.gold,
        "shine", "OVERLAY", 0, corner, inset)
    local edge = Style.SkinMask(parent, opts.edge or C.gold,
        "rim", "OVERLAY", 1, corner, inset)
    local region = { alpha=0 }
    function region:SetAlpha(value)
        self.alpha = math.max(0, math.min(1, value or 0))
        sheen:SetAlpha(self.alpha * (opts.shine or 0.65))
        edge:SetAlpha(self.alpha * (opts.rim or 0.90))
    end
    function region:GetAlpha() return self.alpha end
    region:SetAlpha(opts.alpha or 0)
    return region
end

-- Purpose-built texture atlas pieces, authored independently from the
-- approved screenshot. Each surface is a 9-slice so corners keep their
-- sculpted depth at different window sizes; buttons and labels stay native.
-- Artwork-derived artwork supplied by the project owner (2026-11-21).
-- Sprite boundaries refer to the actual approved screenshot extraction, not
-- imagined brush strokes. The native Lua state and controls still own input.
local PLATE_ROOT = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\"
local PLATE_ATLAS = PLATE_ROOT .. "DuelAtlas.png"
local PLATES = {
    -- A dedicated, power-of-two copper rim with a transparent center:
    -- 9-sliced on ONE non-interactive frame, not repeated corner stamps.
    shellCopper = { path=PLATE_ROOT .. "DuelFrameRim.png",
        w=512, h=512, cutX=56, cutY=56 },
    -- Procedural hall is kept ONLY for generic red controls (Close, header X).
    -- The primary Hall destination has its own literal artwork-image region.
    hall = { path=PLATE_ROOT .. "DuelHallButton.tga", w=256, h=128, cutX=30, cutY=28 },
    gold = { path=PLATE_ATLAS, w=256, h=64, cutX=24, cutY=16,
        atlasX=256, atlasY=0, atlasW=512, atlasH=256 },
    dark = { path=PLATE_ATLAS, w=256, h=64, cutX=24, cutY=16,
        atlasX=256, atlasY=64, atlasW=512, atlasH=256 },
    cardBody = { path=PLATE_ATLAS, w=256, h=128, cutX=20, cutY=18,
        atlasX=0, atlasY=128, atlasW=512, atlasH=256 },
    cardHeading = { path=PLATE_ATLAS, w=256, h=64, cutX=22, cutY=12,
        atlasX=256, atlasY=128, atlasW=512, atlasH=256 },
}
local PLATE_REGIONS = {
    hall = { 0, 0.5, 0, 0.5 },
    corner = { 0.5, 0.625, 0.75, 1 },
}
function Style.PlateImage(parent, region, layer, sublevel)
    local coords = assert(PLATE_REGIONS[region],
        "Unknown extracted artwork region: " .. tostring(region))
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 1)
    tex:SetTexture(PLATE_ATLAS)
    tex:SetTexCoord(unpack(coords))
    -- Avoid forcing fractional extracted-image pixels onto a second grid.
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
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
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
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
    -- A stepped stack of seven 5px strips produced visible horizontal
    -- seams across the header and footer. One native gradient per edge
    -- gives the same restrained relief without banding or ongoing updates.
    local function Fade(top, height, color, strength)
        local tex = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(1, 1, 1, 1)
        if top then
            tex:SetPoint("TOPLEFT", parent, "TOPLEFT")
            tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
        else
            tex:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
            tex:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
        end
        tex:SetHeight(height)
        if tex.SetGradient and CreateColor then
            local lit = CreateColor(color[1], color[2], color[3], strength)
            local clear = CreateColor(color[1], color[2], color[3], 0)
            tex:SetGradient("VERTICAL", top and clear or lit,
                top and lit or clear)
        else
            tex:Hide()
        end
    end
    Fade(true, 35, opts.light or C.headerText,
        (opts.brightness or 0.08) * 0.5)
    Fade(false, 12, opts.dark or C.window, 0.16)
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

-- Footer, action, and category labels share one source of truth for their
-- live font bounds. A font change refits; an on-size event refits. Selected,
-- hover, disabled, and click behavior remain owned by the original Button.
function Style.ConstrainButtonLabel(button, label, left, right, minimum)
    left, right = left or 8, right or 8
    label:SetWordWrap(false)
    local function Anchor(y)
        label:ClearAllPoints()
        label:SetPoint("LEFT", button, "LEFT", left, y or 0)
        label:SetPoint("RIGHT", button, "RIGHT", -right, y or 0)
    end
    Anchor(0)
    for _, entry in ipairs(fontStrings) do
        if entry.label == label then
            entry.fit = { button=button, left=left, right=right,
                minimum=minimum or 9 }
            FitLabelFont(entry)
            button:HookScript("OnSizeChanged", function()
                local path, _, flags = label:GetFont()
                local scale = ns.Settings and ns.Settings.Get("fontScale") or 1
                if path then label:SetFont(path, entry.size * scale, flags or "") end
                FitLabelFont(entry)
            end)
            break
        end
    end
    return Anchor
end

-- Interactive buttons own native text/callbacks; only the decorative relief
-- uses nine-sliced art, never image-based labels or hit targets.
-- Optional fixed-brand palette keeps a specific action independent of theme
-- recoloring while reusing this shared button's input/motion/tooltip owner.
function Style.Action(parent, caption, variant, palette)
    local footer = variant == "footer"
    local community = variant == "community"
    -- Art-backed Community buttons still use this one interaction owner,
    -- but their exact approved image supplies the one visible frame/rim.
    local communityArt = variant == "community-art"
    -- The landing page paints a shaped plate and uses image-matched feedback.
    -- Its native button still shares labels, click and font sizing with Action.
    local landingArt = variant == "landing-art"
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(footer and 112 or 204, footer and 32 or 36)
    button:RegisterForClicks("LeftButtonUp")
    -- Raised, theme-tintable capsule by default. A private landing palette
    -- passes ALL paint roles explicitly, including the hidden gloss/shade,
    -- so EllesmereUI and theme refresh cannot silently recolor the buttons.
    local hover
    -- An optional house plate keeps themed modal actions visually identical
    -- to the existing footer Close button. All other callers keep their
    -- current Skin/Plate choice and the SAME input, label and motion owner.
    if palette and palette.plate then
        button.plate = Style.Plate(button, palette.plate, { corner=footer and 9 or 11 })
    elseif palette then
        Style.Skin(button, palette.fill, {
            corner=11, edge=palette.edge, light=palette.light,
            dark=palette.dark, shine=0.28, shade=0.20, rim=0.88,
        })
    elseif footer then
        Style.Plate(button, "hall", { corner=9 })
    elseif not communityArt and not landingArt then
        Style.Skin(button, C.button, {
            corner=9, edge=C.gold, shine=0.52, shade=0.42, rim=0.97,
        })
    end
    if not landingArt then
        hover = Style.FeedbackOverlay(button, {
            corner=footer and 10 or 11, inset=2,
            fill=palette and palette.hover or C.gold,
            edge=palette and palette.edge or C.gold,
            shine=0.58, rim=0.78,
        })
    end
    local label = Style.Text(button, caption, 15,
        palette and palette.text or C.buttonText)
    local placeLabel = Style.ConstrainButtonLabel(button, label, 9, 9, 9)
    label:SetJustifyH("CENTER")
    if not landingArt then
        button:SetScript("OnEnter", function()
            ns.Motion.Fade(hover, 0.20, 0.16)
        end)
        button:SetScript("OnLeave", function()
            ns.Motion.Fade(hover, 0, 0.18)
        end)
    end
    button:SetScript("OnMouseDown", function() placeLabel(-1) end)
    button:SetScript("OnMouseUp", function() placeLabel(0) end)
    if not landingArt and ns.Widgets and ns.Widgets.PressFeedback then
        ns.Widgets.PressFeedback(button, hover)
    end
    -- The fixed landing calls-to-action already identify themselves; avoid
    -- the boxed help tooltip obscuring their illustration on hover.
    if not landingArt and ns.Tooltips and
        not (palette and palette.tooltip == false) then
        ns.Tooltips.Bind(button, { title = caption,
            detail = "Click to activate this action." })
    end
    button.label = label
    return button
end

-- One permanent Duel Hall palette. Font repaint may run after the optional
-- EllesmereUI font changes, but it cannot tint our panels or copper artwork.
function Style.ApplyTheme(fontPath)
    for name, hex in pairs(duelHall) do
        local value, target = Hex(hex), C[name]
        target[1], target[2], target[3], target[4] = unpack(value)
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
        FitLabelFont(entry)
    end
end

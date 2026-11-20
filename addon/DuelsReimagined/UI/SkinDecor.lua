local _, ns = ...
-- Premium visual skins only. No extra navigation, settings, or state owner.
-- Two design families: crafted Hall (ivory, forest, moonstone) and arena
-- steel (slate). Obsidian & Ember intentionally keeps the verified baseline.
local Style, Settings = ns.Style, ns.Settings
local C = Style.color
local Decor = {}
ns.SkinDecor = Decor

local motifs = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelsPremiumMotifs.png"
local materialAtlas = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelsPremiumMaterialAtlas.png"
local materialRows = {ivory=0, verdant=1, slate=2, moonstone=3}
local profiles = {
    ember = { family = "baseline", radius = 1, uv = nil },
    ivory = { family = "hall", radius = 1.14,
        uv = {0.5, 1, 0, 0.5}, trim = 0.84, jewel = 0.78, motif = 0.66, material = 0.97 },
    verdant = { family = "hall", radius = 1.10,
        uv = {0, 0.5, 0, 0.5}, trim = 0.77, jewel = 0.62, motif = 0.75, material = 0.98 },
    slate = { family = "arena", radius = 0.60,
        uv = {0, 0.5, 0.5, 1}, trim = 0.96, jewel = 0.73, motif = 0.64, material = 0.96 },
    moonstone = { family = "hall", radius = 1.24,
        uv = {0.5, 1, 0.5, 1}, trim = 0.83, jewel = 0.81, motif = 0.70, material = 0.97 },
}
local sizes = {
    shell=154, header=76, rail=96, utility=78, nav=94,
    content=200, card=78, navButton=34,
}
local placements = {
    shell="BOTTOMRIGHT", header="TOPLEFT", rail="TOPRIGHT",
    utility="BOTTOMRIGHT", nav="BOTTOMRIGHT", content="BOTTOMRIGHT",
    card="BOTTOMRIGHT", navButton="TOPRIGHT",
}
local parts = {}
local masks = setmetatable({}, {__mode = "k"})

function Decor.Profile()
    local key = Settings.Get("uiTheme")
    return profiles[key] or profiles.ember
end

function Decor.Family()
    return Decor.Profile().family
end

-- SharedMedia and EllesmereUI font selections override this automatically.
function Decor.HeadingFont(size)
    if size < 20 or Decor.Family() ~= "hall" or
        Settings.Get("fontChoice") ~= "default" then return nil end
    return "Fonts\\MORPHEUS.TTF"
end

-- Style.SkinMask owns the nine-slice geometry. We adjust ONLY its corner
-- dimensions when the player switches between the two visual families.
-- Anchors stay the same, so controls retain their real hit area and layout.
function Decor.RegisterMask(group, original)
    masks[group] = original
    local p = Decor.Profile()
    if group.SetCorner then
        group:SetCorner(math.max(4, math.floor(original * p.radius + 0.5)))
    end
end

local function Decoration(parent, role)
    local size = sizes[role]
    if not size then return end

    -- Original transparent glyphs. The source has no text and no painted
    -- backgrounds. Theme colors (including Ellesmere's public palette)
    -- tint them through Style's existing semantic color registry.
    local motif = Style.TintedImage(parent, motifs, C.goldDim, "BORDER")
    motif:SetSize(size, size)
    local anchor = placements[role]
    local x = anchor == "TOPLEFT" and 12 or -10
    local y = anchor == "TOPLEFT" and -10 or
        anchor == "TOPRIGHT" and -10 or 10
    motif:SetPoint(anchor, parent, anchor, x, y)
    motif:Hide()

    -- Actual skin-specific surface material. Panels get their own parchment,
    -- lacquer or engraved-steel layer, not a translucent ornament alone.
    -- Keep material BELOW the existing SkinMask rim and all text/controls.
    local material
    if role == "content" or role == "nav" or role == "card" then
        material = parent:CreateTexture(nil, "BORDER", nil, -2)
        material:SetTexture(materialAtlas)
        local inset = role == "card" and 5 or 8
        material:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
        material:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
        material:Hide()
    end

    -- Buttons get actual resting face/rim art. Selection/hover overlays are
    -- created AFTER this decoration, so their animations remain visible.
    local rest
    if role == "navButton" then
        rest = Style.Skin(parent, C.rail, {
            corner=10, edge=C.goldDim, light=C.headerText,
            shine=0.28, shade=0.24, rim=0.95, alpha=0,
        })
    end

    -- Hairlines are placed inside current surfaces, never under/over real
    -- text or the mouse target. An arena treatment is visibly crisper.
    local top = Style.Fill(parent, C.shellEdge, "BORDER")
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -5)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -5)
    top:SetHeight(1)
    top:Hide()

    local seal = Style.Fill(parent, C.gold, "BORDER")
    seal:ClearAllPoints()
    seal:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -13, -5)
    seal:SetSize(4, 4)
    if seal.SetRotation then seal:SetRotation(math.pi / 4) end
    seal:Hide()

    -- A continuous, raised perimeter is more visible than corner ornaments
    -- alone and matches each concept's carved/steel panel silhouette.
    -- It deliberately never extends into controls or changes hitboxes.
    local frameEdges
    if role == "content" or role == "nav" or role == "utility" or
        role == "card" or role == "shell" then
        frameEdges = {}
        local specs = {
            {"LEFT", "TOPLEFT", "BOTTOMLEFT", true},
            {"RIGHT", "TOPRIGHT", "BOTTOMRIGHT", true},
            {"BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT", false},
        }
        for _, spec in ipairs(specs) do
            local t = Style.Fill(parent, C.goldDim, "BORDER")
            t:ClearAllPoints()
            local shift = role == "card" and 4 or role == "shell" and 3 or 6
            if spec[1] == "LEFT" then
                t:SetPoint("TOPLEFT", parent, "TOPLEFT", shift, -shift)
                t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", shift, shift)
                t:SetWidth(2)
            elseif spec[1] == "RIGHT" then
                t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -shift, -shift)
                t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -shift, shift)
                t:SetWidth(2)
            else
                t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", shift, shift)
                t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -shift, shift)
                t:SetHeight(2)
            end
            t:Hide()
            frameEdges[#frameEdges + 1] = t
        end
    end

    local entry = { role=role, motif=motif, top=top, seal=seal,
        material=material, rest=rest, frameEdges=frameEdges }
    parts[#parts + 1] = entry
    return entry
end

local function Paint(entry, p)
    local motif, top, seal = entry.motif, entry.top, entry.seal
    local material, rest = entry.material, entry.rest
    if not p.uv then
        motif:Hide()
        top:Hide()
        seal:Hide()
        if material then material:Hide() end
        if rest then rest:SetAlpha(0) end
        if entry.frameEdges then
            for _, edge in ipairs(entry.frameEdges) do edge:Hide() end
        end
        return
    end
    local key = Settings.Get("uiTheme")
    if material and materialRows[key] then
        local x = entry.role == "content" and 0 or 0.5
        local y = materialRows[key] * 0.25
        material:SetTexCoord(x, x+0.5, y, y+0.25)
        -- When the player requests Ellesmere colors, the client palette
        -- remains the dominant paint while material still shows its texture.
        local matched = Settings.Get("matchColors") and
            ns.Theme and ns.Theme.IsAvailable and ns.Theme.IsAvailable()
        local visibleAlpha = matched and 0.16 or
            entry.role == "card" and 0.58 or
            entry.role == "nav" and 0.88 or 1
        material:SetAlpha(p.material * visibleAlpha)
        material:Show()
    end
    if rest then rest:SetAlpha(entry.role == "navButton" and 0.87 or 0) end
    if entry.frameEdges then
        for _, edge in ipairs(entry.frameEdges) do
            edge:SetAlpha(p.trim * (entry.role == "card" and 0.52 or 0.72))
            edge:Show()
        end
    end

    motif:SetTexCoord(unpack(p.uv))
    local subtle = entry.role == "content" and 0.83 or
        entry.role == "shell" and 0.72 or
        entry.role == "card" and 0.41 or 1
    motif:SetAlpha(p.motif * subtle)
    motif:Show()

    local trim = entry.role ~= "content" and entry.role ~= "navButton"
    top:SetShown(trim)
    seal:SetShown(trim)
    if trim then
        top:SetAlpha(p.trim * (entry.role == "card" and 0.62 or 1))
        top:SetHeight(p.family == "arena" and 3 or 2)
        seal:SetAlpha(p.jewel)
        if p.family == "arena" then
            seal:SetSize(6, 3)
        elseif p.family == "hall" then
            seal:SetSize(4, 4)
        end
    end
end

function Decor.Attach(parent, role)
    local entry = Decoration(parent, role)
    if entry then Paint(entry, Decor.Profile()) end
    return entry
end

function Decor.Refresh()
    local p = Decor.Profile()
    for group, corner in pairs(masks) do
        if group.SetCorner then
            group:SetCorner(math.max(4, math.floor(corner * p.radius + 0.5)))
        end
    end
    for _, entry in ipairs(parts) do
        Paint(entry, p)
    end
end

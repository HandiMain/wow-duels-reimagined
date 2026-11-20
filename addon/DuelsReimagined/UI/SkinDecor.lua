local _, ns = ...
-- Premium visual skins only. No extra navigation, settings, or state owner.
-- Two design families: crafted Hall (ivory, forest, moonstone) and arena
-- steel (slate). Obsidian & Ember intentionally keeps the verified baseline.
local Style, Settings = ns.Style, ns.Settings
local C = Style.color
local Decor = {}
ns.SkinDecor = Decor

local motifs = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelsPremiumMotifs.png"
local profiles = {
    ember = { family = "baseline", radius = 1, uv = nil },
    ivory = { family = "hall", radius = 1.14,
        uv = {0.5, 1, 0, 0.5}, trim = 0.53, jewel = 0.48, motif = 0.17 },
    verdant = { family = "hall", radius = 1.10,
        uv = {0, 0.5, 0, 0.5}, trim = 0.46, jewel = 0.30, motif = 0.21 },
    slate = { family = "arena", radius = 0.60,
        uv = {0, 0.5, 0.5, 1}, trim = 0.82, jewel = 0.30, motif = 0.16 },
    moonstone = { family = "hall", radius = 1.24,
        uv = {0.5, 1, 0.5, 1}, trim = 0.50, jewel = 0.64, motif = 0.20 },
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

    local entry = { role=role, motif=motif, top=top, seal=seal }
    parts[#parts + 1] = entry
    return entry
end

local function Paint(entry, p)
    local motif, top, seal = entry.motif, entry.top, entry.seal
    if not p.uv then
        motif:Hide()
        top:Hide()
        seal:Hide()
        return
    end
    motif:SetTexCoord(unpack(p.uv))
    local subtle = entry.role == "content" and 0.62 or
        entry.role == "shell" and 0.50 or
        entry.role == "card" and 0.38 or 1
    motif:SetAlpha(p.motif * subtle)
    motif:Show()

    local trim = entry.role ~= "content" and entry.role ~= "navButton"
    top:SetShown(trim)
    seal:SetShown(trim)
    if trim then
        top:SetAlpha(p.trim * (entry.role == "card" and 0.60 or 1))
        top:SetHeight(p.family == "arena" and 2 or 1)
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

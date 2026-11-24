local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion

-- A native Blizzard Settings launcher, not a second settings window.
-- Artwork 04 (approved 2026-11-23): the scenic painting, crest, static
-- wordmark, rule and two empty plated frames are separately authored
-- from the approved art. ALL clicks, titles, hover, press and tooltips
-- are WoW widgets, not part of an interactive screenshot.
local Landing = {}
ns.BlizzardLanding = Landing
local panel = CreateFrame("Frame", "DuelsReimaginedBlizzardSettingsPanel")
panel.name = "Duels Reimagined"
panel:Hide()
Landing.panel = panel

-- This page has one intentionally fixed faction palette. Neither EllesmereUI
-- nor changing main-window fonts recolors its Alliance/Horde background.
local LANDING_BG = { 12/255, 10/255, 13/255, 1 }
local LANDING_EDGE = { 125/255, 87/255, 53/255, 1 }
local LANDING_TEXT = { 240/255, 231/255, 215/255, 1 }
local BASE_W, BASE_H = 547, 267
local media = "Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Landing\\"

local surface = CreateFrame("Frame", nil, panel)
surface:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
surface:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
-- Exactly ONE thin, bronze frame owner. The interior art does not carry
-- the Blizzard Settings container, its toolbar, or any clickable labels.
Style.Skin(surface, LANDING_BG, {
    corner=9, edge=LANDING_EDGE, light=LANDING_EDGE,
    dark=LANDING_BG, shine=0, shade=0, rim=0.62,
})

-- Keep every source-space coordinate together; uniformly scale the entire
-- artwork and native click targets at runtime instead of independently
-- stretching the logo or cropping faction banners when the panel resizes.
local layout = CreateFrame("Frame", nil, surface)
layout:SetSize(BASE_W, BASE_H)
layout:SetPoint("CENTER", surface, "CENTER", 0, 0)

local battlefield = layout:CreateTexture(nil, "BACKGROUND", nil, 1)
battlefield:SetTexture(media .. "LandingBattlefield.jpg")
battlefield:SetAllPoints(layout)
battlefield:EnableMouse(false)
Chrome.Sharp(battlefield)

-- The original JPG has relatively abrupt edges between faction scenery and
-- its near-black center. Fade those edges into the same exact background
-- color, underneath all live lettering and buttons. No decorative re-crop
-- or second image layer can expose a seam when Blizzard Settings scales.
local function FadeFaction(x, width, leftAlpha, rightAlpha)
    local shade = layout:CreateTexture(nil, "BACKGROUND", nil, 2)
    shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    shade:SetSize(width, BASE_H)
    shade:SetPoint("TOPLEFT", layout, "TOPLEFT", x, 0)
    shade:EnableMouse(false)
    if shade.SetGradient and type(CreateColor) == "function" then
        shade:SetGradient("HORIZONTAL",
            CreateColor(LANDING_BG[1], LANDING_BG[2], LANDING_BG[3], leftAlpha),
            CreateColor(LANDING_BG[1], LANDING_BG[2], LANDING_BG[3], rightAlpha))
    else
        -- Forever/Retail compatibility: stepped alpha fallback where the
        -- native texture gradient API is unavailable. No animation/polling.
        shade:Hide()
        local steps = 24
        for step = 1, steps do
            local strip = layout:CreateTexture(nil, "BACKGROUND", nil, 2)
            local alpha = leftAlpha +
                (rightAlpha - leftAlpha) * ((step - 0.5) / steps)
            strip:SetColorTexture(LANDING_BG[1], LANDING_BG[2],
                LANDING_BG[3], alpha)
            strip:SetPoint("TOPLEFT", layout, "TOPLEFT",
                x + (step - 1) * width / steps, 0)
            strip:SetSize(width / steps + 0.1, BASE_H)
            strip:EnableMouse(false)
        end
    end
end
FadeFaction(90, 145, 0, 1)
local quietCenter = layout:CreateTexture(nil, "BACKGROUND", nil, 2)
quietCenter:SetColorTexture(LANDING_BG[1], LANDING_BG[2], LANDING_BG[3], 1)
quietCenter:SetPoint("TOPLEFT", layout, "TOPLEFT", 235, 0)
quietCenter:SetSize(78, BASE_H)
quietCenter:EnableMouse(false)
FadeFaction(313, 145, 1, 0)

local function SourceImage(filename, x, y, width, height, layer)
    local tex = layout:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(media .. filename)
    tex:SetSize(width, height)
    tex:SetPoint("TOPLEFT", layout, "TOPLEFT", x, -y)
    tex:EnableMouse(false)
    Chrome.Sharp(tex)
    return tex
end

-- Actual illustrated sword-and-laurel crest and the split red / ivory
-- DUELS REIMAGINED wordmark from the fourth approved artwork.
SourceImage("LandingCrest.png",    215, 3,   118, 70)
SourceImage("LandingWordmark.png", 139, 73,  272, 37)
SourceImage("LandingRule.png",     139, 110, 273, 21)

local subtitle = Style.Text(layout,
    "Your dueling companion in World of Warcraft.", 12, LANDING_TEXT)
subtitle:SetSize(380, 22)
subtitle:SetPoint("TOP", layout, "TOP", 0, -133)
subtitle:SetJustifyH("CENTER")
subtitle:SetJustifyV("MIDDLE")
subtitle:SetWordWrap(false)

-- Reuse the shared native Action control for text sizing and input. Its
-- landing-art variant opts out of the generic rectangular hover, press
-- mask and tooltip. The new hover glow uses the actual transparent plate
-- silhouette, so it can never draw a square over our beveled buttons.
local function PlatedButton(caption, art, x, y, width, height)
    local button = Style.Action(layout, caption, "landing-art")
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", layout, "TOPLEFT", x, -y)
    local plate = button:CreateTexture(nil, "ARTWORK", nil, 3)
    plate:SetTexture(media .. art)
    plate:SetAllPoints(button)
    plate:EnableMouse(false)
    Chrome.Sharp(plate)
    -- Same shaped artwork, softly additive: the bevel gets brighter on hover
    -- while everything outside the plate's alpha stays fully transparent.
    local glow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetTexture(media .. art)
    glow:SetAllPoints(button)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.73, 0.40, 1)
    glow:SetAlpha(0)
    glow:EnableMouse(false)
    Chrome.Sharp(glow)
    button:SetScript("OnEnter", function()
        Motion.Fade(glow, 0.23, Motion.Duration("normal"))
    end)
    button:SetScript("OnLeave", function()
        Motion.Fade(glow, 0, Motion.Duration("normal"))
    end)
    button:HookScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then Motion.Stop(glow, 0.42) end
    end)
    button:HookScript("OnMouseUp", function(self, mouse)
        if mouse == "LeftButton" then
            Motion.Fade(glow, self:IsMouseOver() and 0.23 or 0,
                Motion.Duration("quick"))
        end
    end)
    button:HookScript("OnHide", function()
        Motion.Stop(glow, 0)
    end)
    if button.label then
        button.label:SetTextColor(unpack(LANDING_TEXT))
        button.label:SetDrawLayer("OVERLAY", 3)
    end
    return button
end
local open = PlatedButton("Open Duels Reimagined",
    "LandingPrimary.png", 159, 157, 230, 44)
local community = PlatedButton("View Community",
    "LandingSecondary.png", 175, 200, 197, 40)
-- Small separate developer entry, below the two approved calls to action.
local diagnostics = Style.Action(layout,"Diagnostics","footer",{plate="dark",tooltip=false})
diagnostics:SetSize(128,23)
diagnostics:SetPoint("TOP",layout,"TOP",0,-240)
diagnostics:SetScript("OnClick",function() ns.DiagnosticsUI.Open() end)

local function Fit()
    local w = math.max(1, surface:GetWidth())
    local h = math.max(1, surface:GetHeight())
    -- 547 x 267 is the approved screenshot's *actual* content size.
    -- Scale art and hitboxes as one plane. The panel supplies letterbox fill
    -- for unusual aspect ratios; no image stretch or control dislocation.
    local scale = math.min(w / BASE_W, h / BASE_H)
    layout:SetScale(math.max(0.30, scale))
end
surface:SetScript("OnSizeChanged", Fit)

local function Notice(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcf84Duels Reimagined:|r " .. msg)
    end
end
local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end
local function Later(fn)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local function OpenDuels(section, page)
    -- The Blizzard Settings window must never be forcibly closed in combat.
    if InCombat() then
        Notice("Close Blizzard Settings after combat, then use /duels.")
        return
    end
    Later(function()
        if InCombat() then return end
        local settings = _G.SettingsPanel
        if settings and settings.IsShown and settings:IsShown() then
            if type(HideUIPanel) ~= "function" then
                Notice("Close Blizzard Settings, then use /duels.")
                return
            end
            HideUIPanel(settings)
        end
        local menu = _G.GameMenuFrame
        if menu and menu.IsShown and menu:IsShown() and
            type(HideUIPanel) == "function" then
            HideUIPanel(menu)
        end
        Later(function()
            if InCombat() then return end
            if settings and settings.IsShown and settings:IsShown() then
                Notice("Close Blizzard Settings, then use /duels.")
                return
            end
            if not ns.Window or not ns.Window.frame then return end
            if not ns.Window.frame:IsShown() then
                ns.Window.Toggle()
            else
                ns.Window.frame:Raise()
            end
            if ns.Header and ns.Header.IsFolded and ns.Header.IsFolded() then
                ns.Header.Fold(false)
            end
            if section and ns.Navigation and ns.Navigation.SelectKey then
                ns.Navigation.SelectKey(section, page)
            end
        end)
    end)
end

open:SetScript("OnClick", function() OpenDuels() end)
community:SetScript("OnClick", function()
    OpenDuels("community", "community")
end)

-- Both labels explain their action. Keep the landing unobscured by large
-- tooltip rectangles; the shared tooltip system is unchanged elsewhere.

panel:SetScript("OnShow", function()
    if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
    Fit()
    Motion.Stop(surface, 0.8)
    Motion.Fade(surface, 1, Motion.Duration("gentle"))
end)
panel:SetScript("OnHide", function()
    Motion.Stop(surface, 1)
    ns.Tooltips.Hide(nil, true)
end)

local registered = false
local function RegisterCategory()
    if registered then return end
    local api = _G.Settings
    if api and type(api.RegisterCanvasLayoutCategory) == "function" and
        type(api.RegisterAddOnCategory) == "function" then
        local ok, category = pcall(api.RegisterCanvasLayoutCategory,
            panel, "Duels Reimagined")
        if ok and category then
            local added = pcall(api.RegisterAddOnCategory, category)
            if added then
                Landing.category = category
                registered = true
                return
            end
        end
    end
    if type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
        registered = true
    end
end
local event = CreateFrame("Frame")
event:RegisterEvent("PLAYER_LOGIN")
event:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    RegisterCategory()
end)

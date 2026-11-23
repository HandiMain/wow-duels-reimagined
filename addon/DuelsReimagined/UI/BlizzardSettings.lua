local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion

-- A native Blizzard Settings launcher, not a second settings window.
-- Concept 04 (approved 2026-11-23): the scenic painting, crest, static
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
local media = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Landing\\"

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
-- DUELS REIMAGINED wordmark from the fourth approved concept.
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

-- Reuse the SHARED native action/feedback machinery. The empty decorative
-- plates were extracted individually and have their screenshot labels
-- removed so only a real WoW FontString provides the visible caption.
local function PlatedButton(caption, art, x, y, width, height)
    local button = Style.Action(layout, caption, "community-art")
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", layout, "TOPLEFT", x, -y)
    local plate = button:CreateTexture(nil, "ARTWORK", nil, 3)
    plate:SetTexture(media .. art)
    plate:SetAllPoints(button)
    plate:EnableMouse(false)
    Chrome.Sharp(plate)
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

ns.Tooltips.Bind(open, {
    title = "Open Duels Reimagined",
    detail = "Open the main Duels window, preserving your selected page.",
    outsideWindow = true,
})
ns.Tooltips.Bind(community, {
    title = "View Community",
    detail = "Open the Duelist's Circle inside Duels Reimagined.",
    outsideWindow = true,
})

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

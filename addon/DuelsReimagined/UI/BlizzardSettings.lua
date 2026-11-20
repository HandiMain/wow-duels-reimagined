local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion

-- Launcher only. The main Duels window remains the sole settings owner.
local Landing = {}
ns.BlizzardLanding = Landing
local panel = CreateFrame("Frame", "DuelsReimaginedBlizzardSettingsPanel")
panel.name = "Duels Reimagined"
panel:Hide()
Landing.panel = panel

-- The landing page is our one fixed charcoal-plum brand surface. These
-- private colors deliberately do NOT use Style.color, so changing Duels
-- themes or EllesmereUI cannot recolor the background, logo or page copy.
-- Sampled from the approved main-window header: #302B30.
local LANDING_BG = { 48/255, 43/255, 48/255, 1 }
local LANDING_EDGE = { 111/255, 95/255, 92/255, 1 }
local LANDING_GOLD = { 195/255, 154/255, 101/255, 1 }
local LANDING_PALE = { 244/255, 232/255, 228/255, 1 }
local LANDING_TEXT = { 239/255, 228/255, 225/255, 1 }
local LANDING_MUTED = { 197/255, 182/255, 185/255, 1 }
-- Identical gold to DUELS lettering, with dark ink for readable button text.
-- This is a local palette, never a new global theme or stored preference.
local LANDING_BUTTONS = {
    fill = LANDING_GOLD, edge = LANDING_PALE,
    light = LANDING_PALE, dark = LANDING_BG,
    hover = { 231/255, 190/255, 131/255, 1 },
    text = LANDING_BG,
}

local surface = CreateFrame("Frame", nil, panel)
surface:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
surface:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
Style.Skin(surface, LANDING_BG, {
    corner=12, edge=LANDING_EDGE, shine=0, shade=0, rim=0.70,
})

-- Use the EXACT same two letter masks/UVs as the main window header,
-- without theme registration. This is the ORIGINAL wordmark, not another
-- raster recreation or the deprecated detailed crest asset.
local layout = CreateFrame("Frame", nil, surface)
layout:SetSize(490, 405)
layout:SetPoint("CENTER", surface, "CENTER", 0, 6)
local logo = CreateFrame("Frame", nil, layout)
logo:SetSize(380, 380 / 4.65)
logo:SetPoint("TOP", layout, "TOP", 0, -70)
local BRAND_ATLAS = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\HeaderOption5TintAtlas.png"
local function LockedBrandBand(color, top, bottom)
    local tex = logo:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(BRAND_ATLAS)
    tex:SetVertexColor(unpack(color))
    tex:SetPoint("TOPLEFT", logo, "TOPLEFT", 0, -4)
    tex:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", 0, -4)
    tex:SetTexCoord(0, 1, top, bottom)
    Chrome.Sharp(tex)
end
LockedBrandBand(LANDING_GOLD, 0, 0.25)
LockedBrandBand(LANDING_PALE, 0.25, 0.50)

local subtitle = Style.Text(layout,
    "Your dueling companion in World of Warcraft.", 14, LANDING_TEXT)
subtitle:SetPoint("TOP", logo, "BOTTOM", 0, -16)
subtitle:SetPoint("LEFT", layout, "LEFT", 18, 0)
subtitle:SetPoint("RIGHT", layout, "RIGHT", -18, 0)
subtitle:SetHeight(42)
subtitle:SetWordWrap(true)
subtitle:SetJustifyH("CENTER")
subtitle:SetJustifyV("MIDDLE")
local divider = Chrome.Divider(layout, 304, 15)
divider:SetPoint("TOP", subtitle, "BOTTOM", 0, -7)

local open = Style.Action(layout, "Open Duels Reimagined", "community",
    LANDING_BUTTONS)
open:SetSize(360, 46)
open:SetPoint("TOP", divider, "BOTTOM", 0, -12)
local community = Style.Action(layout, "View Community", "footer",
    LANDING_BUTTONS)
community:SetSize(230, 38)
community:SetPoint("TOP", open, "BOTTOM", 0, -12)

-- The screenshot's example version number is not an actual release.
local build = Style.Text(surface, "Duels Reimagined  |  Test Build", 11, LANDING_MUTED)
build:SetPoint("BOTTOM", surface, "BOTTOM", 0, 23)
build:SetJustifyH("CENTER")

local function Fit()
    local w, h = math.max(1, surface:GetWidth()), math.max(1, surface:GetHeight())
    local scale = math.min(1, (w - 36) / 490, (h - 57) / 405)
    layout:SetScale(math.max(0.55, scale))
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
    -- Blizzard's SettingsPanel must never be forcibly closed in combat.
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

-- Reuse our tooltip owner outside the main window.
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
    -- EllesmereUI matching is already owned by Theme/Style. Refresh here
    -- to pick up appearances changed while Blizzard Settings was closed.
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

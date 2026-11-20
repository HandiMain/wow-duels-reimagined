local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color

-- Launcher only. The main Duels window remains the sole settings owner.
local Landing = {}
ns.BlizzardLanding = Landing
local panel = CreateFrame("Frame", "DuelsReimaginedBlizzardSettingsPanel")
panel.name = "Duels Reimagined"
panel:Hide()
Landing.panel = panel

local surface = CreateFrame("Frame", nil, panel)
surface:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
surface:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
Style.Fill(surface, C.body)
Style.Border(surface, C.goldDim, 1)

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
-- The original faction logo remains. Decorative outer edges are now drawn
-- by the shared, recolorable Style.Border instead of fixed gold corner PNGs.

local layout = CreateFrame("Frame", nil, surface)
layout:SetSize(490, 405)
layout:SetPoint("CENTER", surface, "CENTER", 0, 6)
local logo = layout:CreateTexture(nil, "ARTWORK")
logo:SetTexture(art .. "DuelsReimagined-HeaderLogoFlat.png")
logo:SetTexCoord(130 / 512, 382 / 512, 74 / 256, 182 / 256)
logo:SetSize(300, 300 * 108 / 252)
logo:SetPoint("TOP", layout, "TOP", 0, -6)
Chrome.Sharp(logo)

local subtitle = Style.Text(layout,
    "Your dueling companion in World of Warcraft.", 14, C.text)
subtitle:SetPoint("TOP", logo, "BOTTOM", 0, -20)
subtitle:SetPoint("LEFT", layout, "LEFT", 18, 0)
subtitle:SetPoint("RIGHT", layout, "RIGHT", -18, 0)
subtitle:SetHeight(42)
subtitle:SetWordWrap(true)
subtitle:SetJustifyH("CENTER")
subtitle:SetJustifyV("MIDDLE")
local divider = Chrome.Divider(layout, 304, 15)
divider:SetPoint("TOP", subtitle, "BOTTOM", 0, -12)

local open = Style.Action(layout, "Open Duels Reimagined", "community")
open:SetSize(360, 46)
open:SetPoint("TOP", divider, "BOTTOM", 0, -25)
local community = Style.Action(layout, "View Community", "footer")
community:SetSize(230, 38)
community:SetPoint("TOP", open, "BOTTOM", 0, -22)

-- The screenshot's example version number is not an actual release.
local build = Style.Text(surface, "Duels Reimagined  |  Test Build", 11, C.muted)
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

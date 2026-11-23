local _, ns = ...
local Style = ns.Style
local Settings = ns.Settings

local Theme = {}
ns.Theme = Theme

local skin

function Theme.IsAvailable()
    if type(skin) ~= "table" then return false end
    if type(skin.IsEnabled) == "function" then
        local ok, enabled = pcall(skin.IsEnabled)
        if not ok or not enabled then return false end
    end
    return true
end

function Theme.Refresh()
    local font
    if Theme.IsAvailable() and Settings.Get("matchFont") and
        type(skin.GetFont) == "function" then
        local ok, path = pcall(skin.GetFont)
        if ok and type(path) == "string" and path ~= "" then
            font = path
        end
    end

    -- EllesmereUI's active match takes priority over the saved manual pick.
    -- With no matching provider, the user's chosen SharedMedia font applies;
    -- otherwise Style falls back to Blizzard's locale-appropriate default.
    if not font and ns.Fonts and type(ns.Fonts.Resolve) == "function" then
        font = ns.Fonts.Resolve(Settings.Get("fontChoice"))
    end
    Style.ApplyTheme(font)
    if ns.Chrome then ns.Chrome.Refresh() end
    if ns.Window and ns.Window.RefreshTheme then ns.Window.RefreshTheme() end
    if ns.Navigation and ns.Navigation.RefreshSelection then
        ns.Navigation.RefreshSelection()
    end
    if ns.Options and ns.Options.Refresh then
        ns.Options.Refresh()
    end
    if ns.AddonStatus and ns.AddonStatus.Refresh then
        ns.AddonStatus.Refresh()
    end
    if ns.WarGamesUI and ns.WarGamesUI.Refresh then
        ns.WarGamesUI.Refresh()
    end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

-- Register only through the documented, optional third-party appearance API.
-- Never call S.Shell: it would remove the original Duels window artwork.
local eui = _G.EllesmereUI
if eui and type(eui.RegisterSkin) == "function" then
    pcall(eui.RegisterSkin, "DuelsReimagined", function(S)
        if type(S) ~= "table" then return end
        skin = S
        if type(S.OnLooksChanged) == "function" then
            pcall(S.OnLooksChanged, function()
                Theme.Refresh()
            end)
        end
        Theme.Refresh()
    end)
end

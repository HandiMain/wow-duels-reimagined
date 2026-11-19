local _, ns = ...
local Style, Motion, Settings, Window = ns.Style, ns.Motion, ns.Settings, ns.Window
local C, footer, frame = Style.color, Window.footer, Window.frame
local Footer = {}
ns.Footer = Footer
local iconBase = "Interface\\AddOns\\DuelsReimagined\\Media\\Polestar\\"

local function ShowTip(button, title, detail)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 0.84, 0.57)
    if detail then GameTooltip:AddLine(detail, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end
local function HideTip(button)
    if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local version = Style.Text(footer, "Version Test Build", 11, C.muted)
version:SetPoint("LEFT", footer, "LEFT", 22, 0)
local beta = CreateFrame("Frame", nil, footer)
beta:SetSize(48, 22)
beta:SetPoint("LEFT", version, "RIGHT", 9, 0)
Style.Fill(beta, C.nav)
Style.Border(beta, C.goldDim)
local betaLabel = Style.Text(beta, "BETA", 11, C.gold)
betaLabel:SetPoint("CENTER", beta, "CENTER")
betaLabel:SetJustifyH("CENTER")

local discord = CreateFrame("Button", nil, footer)
discord:SetSize(28, 28)
discord:SetPoint("LEFT", beta, "RIGHT", 11, 0)
discord:RegisterForClicks("LeftButtonUp")
local discordIcon = discord:CreateTexture(nil, "ARTWORK")
discordIcon:SetAllPoints(discord)
discordIcon:SetTexture(iconBase .. "discord.tga")
discordIcon:SetVertexColor(0.345, 0.396, 0.949)
ns.Chrome.Sharp(discordIcon)
discord:SetScript("OnEnter", function(self)
    discordIcon:SetVertexColor(0.52, 0.57, 1)
    ShowTip(self, "Duels Reimagined Discord", "Community invite: COMING SOON")
end)
discord:SetScript("OnLeave", function(self)
    discordIcon:SetVertexColor(0.345, 0.396, 0.949)
    HideTip(self)
end)

local function FooterButton(label, width, detail)
    local button = CreateFrame("Button", nil, footer)
    button:SetSize(width, 30)
    button:RegisterForClicks("LeftButtonUp")
    if button.SetMotionScriptsWhileDisabled then
        button:SetMotionScriptsWhileDisabled(true)
    end
    local hover = Style.Fill(button, C.goldDim)
    hover:SetAlpha(0)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(15, 15)
    icon:SetTexture(iconBase .. "reset.tga")
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    ns.Chrome.Sharp(icon)
    local title = Style.Text(button, label, 12, C.text)
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    button.icon, button.hover = icon, hover
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then Motion.Fade(hover, 0.28, 0.13) end
        local message = self:IsEnabled() and detail or
            (label == "Reload UI" and "No setting requires a reload." or
             "Window size and Menu Scale are already at their defaults.")
        ShowTip(self, label, message)
    end)
    button:SetScript("OnLeave", function(self)
        Motion.Fade(hover, 0, 0.13)
        HideTip(self)
    end)
    return button
end

local reset = FooterButton("Reset window", 132,
    "Restore default dimensions and 100% Menu Scale.")
reset:SetPoint("LEFT", discord, "RIGHT", 24, 0)
reset:SetScript("OnClick", function()
    if not Window.IsDefault() then Window.ResetWindow() end
end)

local reload = FooterButton("Reload UI", 110, "Apply a setting that requires a reload.")
reload:SetPoint("LEFT", reset, "RIGHT", 12, 0)
reload:SetScript("OnClick", function()
    if Settings.NeedsReload() and type(ReloadUI) == "function" then ReloadUI() end
end)

-- A real in-addon popup, but never an invented external invite.
local modal = CreateFrame("Frame", "DuelsReimaginedDiscordPopup", frame)
modal:SetAllPoints(frame)
modal:SetFrameLevel(frame:GetFrameLevel() + 65)
modal:EnableMouse(true)
Style.Fill(modal, { 0.015, 0.019, 0.025, 0.79 })
local dialog = CreateFrame("Frame", nil, modal)
dialog:SetSize(416, 202)
dialog:SetPoint("CENTER", frame, "CENTER")
dialog:SetFrameLevel(modal:GetFrameLevel() + 1)
dialog:EnableMouse(true)
Style.Fill(dialog, C.nav)
Style.Border(dialog, C.goldDim)
local logo = dialog:CreateTexture(nil, "ARTWORK")
logo:SetTexture(iconBase .. "discord.tga")
logo:SetSize(33, 33)
logo:SetPoint("TOP", dialog, "TOP", 0, -22)
logo:SetVertexColor(0.345, 0.396, 0.949)
ns.Chrome.Sharp(logo)
local heading = Style.Text(dialog, "Duels Reimagined Discord", 18, C.pale)
heading:SetPoint("TOP", logo, "BOTTOM", 0, -10)
heading:SetJustifyH("CENTER")
local message = Style.Text(dialog, "COMING SOON", 14, C.gold)
message:SetPoint("TOP", heading, "BOTTOM", 0, -7)
message:SetJustifyH("CENTER")
local close = Style.Action(dialog, "Close", "footer")
close:SetSize(112, 30)
close:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 16)
close:SetScript("OnClick", function() modal:Hide() end)
modal:SetScript("OnMouseDown", function() modal:Hide() end)
modal:Hide()
frame:HookScript("OnHide", function() modal:Hide() end)
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedDiscordPopup")
end
discord:SetScript("OnClick", function() modal:Show() end)

function Footer.Refresh()
    local resetReady, reloadReady = not Window.IsDefault(), Settings.NeedsReload()
    reset:SetEnabled(resetReady)
    reload:SetEnabled(reloadReady)
    reset:SetAlpha(resetReady and 1 or 0.36)
    reload:SetAlpha(reloadReady and 1 or 0.36)
    reset.icon:SetVertexColor(unpack(C.gold))
    reload.icon:SetVertexColor(unpack(C.gold))
    if not resetReady then Motion.Stop(reset.hover, 0) end
    if not reloadReady then Motion.Stop(reload.hover, 0) end
end
Footer.Refresh()
ns.Theme.Refresh()

-- Search uses the same enabled gates as the corresponding footer buttons.
ns.Search.Register("footer:discord", "Discord community", "Footer",
    "Open the Coming Soon community dialog", function() modal:Show() end)
ns.Search.Register("footer:reset-window", "Reset window", "Footer",
    "Restore window dimensions and menu scale defaults", function()
        if reset:IsEnabled() then Window.ResetWindow() end
    end)
ns.Search.Register("footer:reload-ui", "Reload UI", "Footer",
    "Reload only when a setting needs it", function()
        if reload:IsEnabled() and type(ReloadUI) == "function" then ReloadUI() end
    end)
ns.Search.Register("setting:menuScale", "Menu Scale", "Header",
    "Change size between 65 and 120 percent; right click to reset", function()
        if GameTooltip then
            GameTooltip:SetOwner(Window.scaleSlider, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Drag Menu Scale in the header.", 1, 0.84, 0.57)
            GameTooltip:Show()
        end
    end)

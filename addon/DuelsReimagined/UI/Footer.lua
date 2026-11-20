local _, ns = ...
local Style, Motion, Settings, Window = ns.Style, ns.Motion, ns.Settings, ns.Window
local C, footer, frame = Style.color, Window.footer, Window.frame
local Footer = {}
ns.Footer = Footer
local iconBase = "Interface\\AddOns\\DuelsReimagined\\Media\\Polestar\\"

local version = Style.Text(footer, "Version Test Build", 11, C.footerMuted)
version:SetPoint("LEFT", footer, "LEFT", 22, 0)
local beta = CreateFrame("Frame", nil, footer)
beta:SetSize(48, 22)
beta:SetPoint("LEFT", version, "RIGHT", 9, 0)
Style.Fill(beta, C.header)
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
discord:SetScript("OnEnter", function()
    discordIcon:SetVertexColor(0.52, 0.57, 1)
end)
discord:SetScript("OnLeave", function()
    discordIcon:SetVertexColor(0.345, 0.396, 0.949)
end)
ns.Tooltips.Bind(discord, {
    title = "Duels Reimagined Discord",
    detail = "Community invite is coming soon.",
})

local function FooterButton(label, width, detail)
    local button = CreateFrame("Button", nil, footer)
    button:SetSize(width, 30)
    button:RegisterForClicks("LeftButtonUp")
    if button.SetMotionScriptsWhileDisabled then
        button:SetMotionScriptsWhileDisabled(true)
    end
    local hover = Style.Skin(button, C.goldDim, {
        corner=9, edge=C.goldDim, shine=0.32, shade=0.20, alpha=0,
    })
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(15, 15)
    icon:SetTexture(iconBase .. "reset.tga")
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    ns.Chrome.Sharp(icon)
    local title = Style.Text(button, label, 12, C.footerText)
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    button.icon, button.hover = icon, hover
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then Motion.Fade(hover, 0.28, 0.13) end
     end)
    button:SetScript("OnLeave", function(self)
        Motion.Fade(hover, 0, 0.13)
    end)
    ns.Widgets.PressFeedback(button, hover)
    ns.Tooltips.Bind(button, function(self)
        return { title = label,
            detail = self:IsEnabled() and detail or
                (label == "Reload UI" and "No setting currently requires a reload." or
                 "Window size and Menu Scale are already at their defaults.") }
    end)
    return button
end

local reset = FooterButton("Reset window", 132,
    "Restore default dimensions and 100% Menu Scale.")
reset:SetPoint("LEFT", discord, "RIGHT", 24, 0)
reset:SetScript("OnClick", function()
    if not Window.IsDefault() then
        Window.ResetWindow()
        if ns.Feedback then ns.Feedback.Toast("Window layout restored", reset) end
    end
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
message:SetWidth(380)
message:SetJustifyH("CENTER")
message:SetWordWrap(true)

-- One existing popup owner now supports a safe, selectable GitHub URL.
-- The WoW client cannot open browsers or set the OS clipboard directly.
local linkText = ""
local copyBox = CreateFrame("EditBox", nil, dialog)
copyBox:SetSize(378, 32)
copyBox:SetAutoFocus(false)
copyBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
Style.BindFont(copyBox, 12)
copyBox:SetTextColor(unpack(C.text))
copyBox:SetJustifyH("CENTER")
copyBox:SetPoint("TOP", message, "BOTTOM", 0, -16)
copyBox:SetMaxLetters(256)
Style.Fill(copyBox, C.body)
Style.Border(copyBox, C.goldDim)
copyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
copyBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= linkText then self:SetText(linkText) end
end)
copyBox:Hide()
local close = Style.Action(dialog, "Close", "footer")
close:SetSize(112, 30)
close:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 16)
function Footer.ClosePopup()
    copyBox:ClearFocus()
    Motion.Stop(modal, 1)
    modal:Hide()
    ns.Tooltips.Hide(nil, true)
end
local function OpenDialog()
    if ns.Header and ns.Header.IsFolded and ns.Header.IsFolded() then return false end
    ns.Tooltips.Hide(nil, true)
    modal:SetAlpha(0)
    modal:Show()
    Motion.Fade(modal, 1, Motion.Duration("quick"))
    return true
end
function Footer.ShowPopup()
    dialog:SetHeight(202)
    logo:Show()
    heading:SetText("Duels Reimagined Discord")
    heading:ClearAllPoints()
    heading:SetPoint("TOP", logo, "BOTTOM", 0, -10)
    message:SetText("COMING SOON")
    copyBox:Hide()
    OpenDialog()
end
function Footer.ShowCommunityLink(title, url)
    if type(title) ~= "string" or type(url) ~= "string" then return end
    -- Only public links to this repository's GitHub issue forms are allowed.
    local prefix = "https://github.com/HandiMain/wow-duels-reimagined/issues/new?template="
    if url ~= prefix .. "bug-report.yml" and
       url ~= prefix .. "feature-request.yml" then return end
    dialog:SetHeight(218)
    logo:Hide()
    heading:SetText(title)
    heading:ClearAllPoints()
    heading:SetPoint("TOP", dialog, "TOP", 0, -30)
    message:SetText("Select the link, press Ctrl+C, then paste it into your browser.")
    copyBox:Show()
    linkText = url
    copyBox:SetText(url)
    if OpenDialog() then
        copyBox:SetFocus()
        copyBox:HighlightText()
    end
end
copyBox:SetScript("OnEscapePressed", Footer.ClosePopup)
copyBox:SetScript("OnEnterPressed", Footer.ClosePopup)
close:SetScript("OnClick", Footer.ClosePopup)
ns.Tooltips.Bind(close, {
    title = "Close dialog",
    detail = "Return to Duels Reimagined.",
})
modal:SetScript("OnMouseDown", Footer.ClosePopup)
modal:Hide()
frame:HookScript("OnHide", function() modal:Hide() end)
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedDiscordPopup")
end
discord:SetScript("OnClick", Footer.ShowPopup)

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
    "Open the Coming Soon community dialog", Footer.ShowPopup)
ns.Search.Register("footer:reset-window", "Reset window", "Footer",
    "Restore window dimensions and menu scale defaults", function()
        if reset:IsEnabled() then
            Window.ResetWindow()
            if ns.Feedback then ns.Feedback.Toast("Window layout restored", reset) end
        end
    end, function() return reset:IsEnabled() end)
ns.Search.Register("footer:reload-ui", "Reload UI", "Footer",
    "Reload only when a setting needs it", function()
        if reload:IsEnabled() and type(ReloadUI) == "function" then ReloadUI() end
    end, function() return reload:IsEnabled() end)
ns.Search.Register("setting:menuScale", "Menu Scale", "Header",
    "Change size between 65 and 120 percent; right click to reset", function()
        Window.HighlightMenuScale()
    end)

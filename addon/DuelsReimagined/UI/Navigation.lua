local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C, Window = Style.color, ns.Window

-- Navigation is a visual shell prototype, not a gameplay or record engine.
local sections = {
    { key = "hall", label = "Hall", icon = "Hall", pages = {
        { key = "overview", label = "Overview", title = "Welcome to the Hall",
          subtitle = "Your dueling journey starts here.",
          emptyTitle = "No duels recorded yet",
          emptyDetail = "Your recent activity will appear here." },
    } },
    { key = "community", label = "Community", icon = "Community", pages = {
        { key = "community", label = "The Duelist's Circle", community = true,
          title = "The Duelist's Circle", subtitle = "The people shaping Duels Reimagined." },
        { key = "contributors", label = "Contributors", community = true,
          title = "Contributors", subtitle = "Merged GitHub pull requests." },
        { key = "bug-hunters", label = "Bug Hunters", community = true,
          title = "Bug Hunters", subtitle = "Reports that led to verified fixes." },
        { key = "community-ideas", label = "Community Ideas", community = true,
          title = "Community Ideas", subtitle = "Suggestions that made it into the addon." },
        { key = "special-thanks", label = "Special Thanks", community = true,
          title = "Special Thanks", subtitle = "People we appreciate." },
    } },
    { key = "patchnotes", label = "Patch Notes", icon = "PatchNotes", pages = {} },
    { key = "options", label = "Options", icon = "Options", pages = {
        { key = "options", label = "Appearance", title = "Appearance",
          subtitle = "Make the interface your own." },
        { key = "interface", label = "Interface", title = "Interface",
          subtitle = "Control how the window behaves while you play." },
    } },
}

-- The version list is authored once in PatchNotesData.lua. Adding a version
-- creates a searchable sidebar subcategory without editing this module.
for _, section in ipairs(sections) do
    if section.key == "patchnotes" then
        for index, release in ipairs(ns.PatchNotesData or {}) do
            section.pages[#section.pages + 1] = {
                key = release.key,
                label = release.version .. " — " .. release.navTitle,
                patchNotes = true, title = release.title,
                subtitle = "DEMO: " .. release.summary,
                newest = index == 1,
            }
        end
    end
end

local railButtons, subButtons = {}, {}
local patchDot, patchPulse
local sectionTitle = Style.Text(Window.nav, "HALL", 18, C.pale, true)
sectionTitle:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 20, -24)
local subtitleRule = Chrome.Divider(Window.nav, 201, 12)
subtitleRule:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 19, -56)

local currentSection, currentPage

local function FadeSelection(item, active)
    Motion.Fade(item.selected, active and 0.94 or 0, 0.18)
    Motion.Fade(item.hover, 0, 0.13)
end

local function Select(sectionIndex, pageIndex, noMotion, repaintOnly)
    currentSection, currentPage = sectionIndex, pageIndex
    -- A theme repaint must NOT close Search, modal dialogs or reset pages.
    if not repaintOnly and ns.Header and ns.Header.CloseSearch then
        ns.Header.CloseSearch(true)
    end
    local section, page = sections[sectionIndex], sections[sectionIndex].pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))

    for i, item in ipairs(railButtons) do
        local on = i == sectionIndex
        if noMotion then
            item.selected:SetAlpha(on and 0.94 or 0)
        else
            FadeSelection(item, on)
        end
        item.bar:SetColorTexture(unpack(C.gold))
        item.bar:SetShown(on)
        item.label:SetTextColor(unpack(on and C.tabText or C.tabMuted))
        -- Keep the Hall's blue/red faction accents intact.
        item.icon:SetVertexColor(1, 1, 1, 1)
        item.icon:SetAlpha(on and 1 or 0.92)
    end
    for i, group in ipairs(subButtons) do
        for j, item in ipairs(group) do
            local visible = i == sectionIndex
            item.button:SetShown(visible)
            local active = visible and j == pageIndex
            if noMotion then
                item.selected:SetAlpha(active and 0.94 or 0)
            else
                FadeSelection(item, active)
            end
            item.bar:SetColorTexture(unpack(C.red))
            item.bar:SetShown(active)
            item.label:SetTextColor(unpack(active and C.pale or C.text))
        end
    end
    if repaintOnly then return end
    if ns.Footer and ns.Footer.ClosePopup then ns.Footer.ClosePopup() end
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
    Window.ShowPage(page)
end

local function AddOverlay(button, rail)
    -- No stretched selection art: every tab and row is recolorable in code.
    local selected = Style.Fill(button, rail and C.tabActive or C.selected, "BACKGROUND")
    selected:SetAlpha(0)
    local hover = Style.Fill(button, rail and C.gold or C.hover, "ARTWORK")
    hover:SetAlpha(0)
    if rail then Style.Border(button, C.goldDim, 1) end
    return selected, hover
end

for index, section in ipairs(sections) do
    local button = CreateFrame("Button", nil, Window.rail)
    button:SetSize(165, 44)
    button:SetPoint("LEFT", Window.rail, "LEFT", 25 + (index - 1) * 183, 0)
    local selected, hover = AddOverlay(button, true)
    local bar = button:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(unpack(C.gold))
    bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 0)
    bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 0)
    bar:SetHeight(3)
    local icon = section.key == "patchnotes" and
        button:CreateTexture(nil, "ARTWORK") or Chrome.Icon(button, section.icon)
    -- Each 128px square asset has the same transparent margin; none is stretched.
    icon:SetSize(27, 27)
    icon:SetPoint("LEFT", button, "LEFT", 19, 0)
    local label = Style.Text(button, string.upper(section.label), 14, C.tabMuted, true)
    label:SetPoint("LEFT", icon, "RIGHT", 11, 0)
    label:SetJustifyH("LEFT")
    if section.key == "patchnotes" then
        -- Matching original Duels artwork, not a generic Blizzard item icon.
        -- The upper-left atlas quadrant is the authored gold scroll crest.
        icon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\PatchNotesAtlas.tga")
        icon:SetTexCoord(0, 0.5, 0, 0.5)
        icon:SetSize(27, 27)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", button, "LEFT", 19, 0)
        label:SetText("PATCH")
        patchDot = CreateFrame("Frame", nil, button)
        patchDot:SetSize(9, 9)
        patchDot:SetPoint("TOPRIGHT", button, "TOPRIGHT", -8, -3)
        local jewel = Style.Fill(patchDot, C.gold, "OVERLAY")
        patchPulse = patchDot:CreateAnimationGroup()
        patchPulse:SetLooping("BOUNCE")
        local breathe = patchPulse:CreateAnimation("Alpha")
        breathe:SetFromAlpha(0.46)
        breathe:SetToAlpha(1)
        breathe:SetDuration(0.92)
        patchDot:SetScript("OnShow", function()
            if ns.Settings.Get("reduceMotion") then
                patchPulse:Stop()
                patchDot:SetAlpha(1)
            else
                patchPulse:Play()
            end
        end)
        patchDot:SetScript("OnHide", function()
            patchPulse:Stop()
            patchDot:SetAlpha(1)
        end)
        patchDot:Hide()
    end
    button:SetScript("OnClick", function() Select(index, 1) end)
    button:SetScript("OnEnter", function()
        if currentSection ~= index then Motion.Fade(hover, 0.58, 0.17) end
    end)
    button:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.21) end)
    ns.Widgets.PressFeedback(button, hover)
    ns.Tooltips.Bind(button, { title = section.label,
        detail = "Open the " .. section.label .. " section." })
    railButtons[index] = {
        button = button,
        selected = selected, hover = hover, bar = bar, icon = icon, label = label
    }

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(230, 43)
        sub:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 12, -(82 + (pageIndex - 1) * 46))
        sub:SetPoint("RIGHT", Window.nav, "RIGHT", -12, 0)
        local subSelected, subHover = AddOverlay(sub, false)
        local subBar = sub:CreateTexture(nil, "OVERLAY")
        subBar:SetColorTexture(unpack(C.red))
        subBar:SetPoint("TOPLEFT", sub, "TOPLEFT", 0, -5)
        subBar:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 0, 5)
        subBar:SetWidth(3)
        local text = Style.Text(sub, page.label, 15, C.text)
        text:SetPoint("LEFT", sub, "LEFT", 16, 0)
        sub:SetScript("OnClick", function() Select(index, pageIndex) end)
        sub:SetScript("OnEnter", function()
            if currentSection ~= index or currentPage ~= pageIndex then
                Motion.Fade(subHover, 0.48, 0.16)
            end
        end)
        sub:SetScript("OnLeave", function() Motion.Fade(subHover, 0, 0.20) end)
        ns.Widgets.PressFeedback(sub, subHover)
        ns.Tooltips.Bind(sub, {
            title = page.label,
            detail = page.subtitle or ("Open the " .. page.label .. " page.")
        })
        pages[#pages + 1] = {
            button = sub, selected = subSelected, hover = subHover, bar = subBar, label = text
        }
    end
    subButtons[index] = pages
end

-- Responsive tabs keep all four destinations usable even if the player
-- scales or resizes below the standard 1050-unit layout. No polling.
local function FitTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    if not w or w <= 0 then return end
    local pad = 25
    local slot = math.min(183, math.max(105, (w - pad * 2) / #railButtons))
    for i, item in ipairs(railButtons) do
        item.button:ClearAllPoints()
        item.button:SetPoint("LEFT", self, "LEFT", pad + (i - 1) * slot, 0)
        item.button:SetWidth(slot - 16)
        local tiny = slot < 155
        item.icon:SetShown(not tiny)
        item.label:ClearAllPoints()
        if tiny then
            item.label:SetPoint("CENTER", item.button, "CENTER")
        else
            item.label:SetPoint("LEFT", item.icon, "RIGHT", 11, 0)
        end
    end
end
Window.rail:SetScript("OnSizeChanged", FitTabs)
FitTabs(Window.rail, Window.rail:GetWidth())

ns.Navigation = {
    SetPatchUnread = function(unread)
        if not patchDot then return end
        patchDot:SetShown(unread == true)
        if unread and patchDot:IsVisible() then
            if ns.Settings.Get("reduceMotion") then
                patchPulse:Stop()
                patchDot:SetAlpha(1)
            elseif not patchPulse:IsPlaying() then
                patchPulse:Play()
            end
        end
    end,
    RefreshSelection = function()
        if currentSection and currentPage then
            Select(currentSection, currentPage, true, true)
        end
    end,
    SelectKey = function(sectionKey, pageKey)
        for sectionIndex, section in ipairs(sections) do
            if section.key == sectionKey then
                for pageIndex, page in ipairs(section.pages) do
                    if page.key == pageKey then
                        Select(sectionIndex, pageIndex)
                        return true
                    end
                end
            end
        end
        return false
    end,
}

-- Every visible page registers itself, so new pages join search automatically.
for sectionIndex, section in ipairs(sections) do
    for pageIndex, page in ipairs(section.pages) do
        local si, pi = sectionIndex, pageIndex
        ns.Search.Register("page:" .. section.key .. ":" .. page.key,
            page.label, section.label,
            (page.title or "") .. " " .. (page.subtitle or ""),
            function() Select(si, pi) end)
    end
end

Select(1, 1, true)

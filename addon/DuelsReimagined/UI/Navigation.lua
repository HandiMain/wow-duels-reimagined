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

-- Only primary gameplay destinations live in the expandable upper strip.
-- Secondary utility sections remain in the narrow left rail. New gameplay
-- sections can be promoted here only when their real pages are implemented.
local primaryKeys = { hall = true }
local railButtons, primaryButtons, subButtons = {}, {}, {}
local patchDot, patchPulse
-- The page heading now belongs to Window.content, not the subcategory bar.
local sectionTitle = Style.Text(Window.nav, "HALL", 1, C.pale)
sectionTitle:Hide()

local currentSection, currentPage
local history, backButton = {}, nil
-- The last real page persists, but Back history stays session-only.
-- Scroll ownership remains with the actual Options/Community/Patch Notes page.
local workspaceReady = false
local scrollMemory = {}
local function ScrollOwner(page)
    if not page then return nil end
    if page.key == "options" or page.key == "interface" then return ns.Options end
    if page.community then return ns.Community end
    if page.patchNotes then return ns.PatchNotes end
end
local function PageId(sectionIndex, pageIndex)
    local section = sections[sectionIndex]
    local page = section and section.pages[pageIndex]
    return section, page, section and page and (section.key .. ":" .. page.key)
end
local function CapturePage()
    local section, page, id = PageId(currentSection, currentPage)
    if not id then return end
    local owner = ScrollOwner(page)
    local offset = owner and owner.GetPageScroll and owner.GetPageScroll(page.key) or 0
    if type(offset) ~= "number" or offset ~= offset then offset = 0 end
    scrollMemory[id] = offset
    if workspaceReady then
        ns.Settings.SetWorkspace(section.key, page.key, offset)
    end
end
local function RestoreScroll(sectionIndex, pageIndex)
    local _, page, id = PageId(sectionIndex, pageIndex)
    if not id then return end
    local owner = ScrollOwner(page)
    if owner and owner.SetPageScroll then
        owner.SetPageScroll(page.key, scrollMemory[id] or 0)
    end
end

-- Only the navigation owner moves this small selection indicator. The
-- existing per-button hover/selection controls and their hitboxes stay put.
local movingBar = Style.Fill(Window.nav, C.gold, "OVERLAY")
movingBar:SetSize(80, 2)
movingBar:Hide()
local movingIndex
local function PlaceBar(_, index)
    local section = sections[currentSection]
    local count = section and #section.pages or 1
    local w = math.max(80, Window.nav:GetWidth() - 12)
    local tabWidth = math.min(174, (w - (count - 1) * 8) / math.max(1, count))
    movingBar:ClearAllPoints()
    movingBar:SetPoint("BOTTOMLEFT", Window.nav, "BOTTOMLEFT",
        6 + (index - 1) * (tabWidth + 8) + 14, 0)
    movingBar:SetWidth(math.max(24, tabWidth - 28))
end
local sweep = Style.Fill(Window.nav, C.gold, "OVERLAY")
sweep:SetSize(48, 2)
sweep:Hide()
local function SweepPage()
    if ns.Settings.Get("reduceMotion") or not Window.frame:IsShown() then return end
    Motion.Stop(sweep, 0)
    sweep:Show()
    Motion.Value(sweep, 0, 1, 0.35, function(region, progress)
        region:ClearAllPoints()
        region:SetPoint("BOTTOMLEFT", Window.nav, "BOTTOMLEFT",
            6 + progress * math.max(40, Window.nav:GetWidth() - 70), 0)
        region:SetAlpha(math.sin(math.pi * progress) * 0.55)
        if progress >= 1 then region:Hide() end
    end)
end

local function FadeSelection(item, active)
    Motion.Fade(item.selected, active and (item.activeAlpha or 0.94) or 0, 0.18)
    Motion.Fade(item.hover, 0, 0.13)
end

local function Select(sectionIndex, pageIndex, noMotion, repaintOnly, isBack)
    local section = sections[sectionIndex]
    if not section or not section.pages[pageIndex] then return end
    local priorSection, priorPage = currentSection, currentPage
    local changed = priorSection ~= sectionIndex or priorPage ~= pageIndex
    if not repaintOnly and priorSection then CapturePage() end
    if changed and not repaintOnly and not isBack and priorSection then
        if #history >= 12 then table.remove(history, 1) end
        history[#history + 1] = { section = priorSection, page = priorPage }
    end
    currentSection, currentPage = sectionIndex, pageIndex
    if backButton then backButton:SetShown(#history > 0) end
    -- A theme repaint must NOT close Search, modal dialogs or reset pages.
    if not repaintOnly and ns.Header and ns.Header.CloseSearch then
        ns.Header.CloseSearch(true)
    end
    local section, page = sections[sectionIndex], sections[sectionIndex].pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))
    Window.nav:SetShown(#section.pages > 1)

    for i, item in ipairs(railButtons) do
        local on = i == sectionIndex
        if noMotion then
            item.selected:SetAlpha(on and (item.activeAlpha or 0.94) or 0)
        else
            FadeSelection(item, on)
        end
        item.bar:SetColorTexture(unpack(item.primary and C.gold or C.goldDim))
        item.bar:SetShown(on)
        item.label:SetTextColor(unpack(on and C.tabText or C.tabMuted))
        -- Keep the Hall's blue/red faction accents intact.
        if item.icon.SetVertexColor then item.icon:SetVertexColor(1, 1, 1, 1) end
        item.icon:SetAlpha(on and 1 or 0.92)
    end
    for i, group in ipairs(subButtons) do
        for j, item in ipairs(group) do
            local visible = i == sectionIndex
            item.button:SetShown(visible)
            local active = visible and j == pageIndex
            if noMotion then
                item.selected:SetAlpha(active and (item.activeAlpha or 0.94) or 0)
            else
                FadeSelection(item, active)
            end
            item.bar:SetColorTexture(unpack(C.red))
            -- The selected gold plate already includes the underline.
            item.bar:SetShown(false)
            if item.plate then item.plate:SetStyle(active and "gold" or "dark") end
            item.label:SetTextColor(unpack(active and C.tabText or C.text))
        end
    end
    -- Animate on genuine page changes only, never for theme repaints or
    -- initial loading. Switching a section snaps the bar into its new list.
    if changed or not movingIndex then
        local duration = (not noMotion and priorSection == sectionIndex)
            and 0.19 or 0
        Motion.Value(movingBar, movingIndex or pageIndex, pageIndex,
            duration, PlaceBar)
        movingIndex = pageIndex
    end
    -- Concept has one framed gold divider, not a second moving underline.
    movingBar:Hide()
    if repaintOnly then return end
    if changed and not noMotion then SweepPage() end
    if ns.Feedback then ns.Feedback.HidePreview() end
    if ns.Footer and ns.Footer.ClosePopup then ns.Footer.ClosePopup() end
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
    Window.ShowPage(page)
    RestoreScroll(sectionIndex, pageIndex)
    if workspaceReady then
        local _, _, id = PageId(sectionIndex, pageIndex)
        ns.Settings.SetWorkspace(section.key, page.key,
            id and scrollMemory[id] or 0)
    end
end

local function AddOverlay(button, primary)
    -- Selected glow and hover are OVER the extracted plate, not below it.
    -- Persistent choice uses a warm rim; pointer hover is a quicker sheen.
    local selected = Style.FeedbackOverlay(button, {
        corner=primary and 14 or 10, inset=2,
        fill=C.goldDim, edge=C.gold, shine=0.46, rim=0.86,
    })
    local hover = Style.FeedbackOverlay(button, {
        corner=primary and 14 or 10, inset=2,
        fill=C.gold, edge=C.gold, shine=0.67, rim=0.75,
    })
    return selected, hover
end

-- Keep the gameplay tab compact; primary tabs can still shrink if the
-- available width becomes constrained.
local HALL_BUTTON_WIDTH = 205
local utilityIndex, previousUtilityButton = 0, nil
for index, section in ipairs(sections) do
    local isPrimary = primaryKeys[section.key] == true
    local parent = isPrimary and Window.rail or Window.utility
    local button = CreateFrame("Button", nil, parent)

    if isPrimary then
        -- Game destinations stack vertically; later pages never displace the
        -- secondary footer links or Options subcategories.
        button:SetSize(HALL_BUTTON_WIDTH, 84)
        button:SetPoint("TOP", Window.rail, "TOP", 0, -31)
    else
        utilityIndex = utilityIndex + 1
        button:SetSize(112, 30)
        button:SetPoint("LEFT", Window.utility, "LEFT",
            (utilityIndex - 1) * 120, 0)
        previousUtilityButton = button
    end

    -- Unlike the discarded procedurally painted plaque, this image is
    -- extracted from the actual approved concept. The button frame remains
    -- responsible for mouse, selection, tooltip and navigation behavior.
    if section.key == "hall" then
        -- Exact Hall plaque is the only paint owner. Never paint a second
        -- rim, bevel, glow or live icon beneath or above its baked artwork.
        local concept = Style.ConceptImage(button, "hall", "ARTWORK", 2)
        concept:SetAllPoints(button)
        -- Visible gilded hover using the SAME approved plaque artwork:
        -- an additive highlight, not a replacement frame or new border.
        -- It is separate from the existing press/selection owner.
        local hallGlow = Style.ConceptImage(button, "hall", "OVERLAY", 6)
        hallGlow:SetAllPoints(button)
        hallGlow:SetBlendMode("ADD")
        hallGlow:SetVertexColor(1, 0.78, 0.48)
        hallGlow:SetAlpha(0)
        button.hallGlow = hallGlow
        button:HookScript("OnHide", function()
            Motion.Stop(hallGlow, 0)
        end)
    else
        -- Reusable live destinations/utility shortcuts have one plate.
        Style.Plate(button, "dark", { corner=9 })
    end
    local selected, hover = AddOverlay(button, isPrimary)
    local bar = button:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(unpack(C.gold))
    if isPrimary then
        bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 0)
        bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 0)
        bar:SetHeight(3)
        bar:SetAlpha(0)  -- gold rim already exists in the actual image
    else
        bar:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -12)
        bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 12)
        bar:SetWidth(2)
    end

    -- All navigation glyphs use the same untinted icon atlas. This removes
    -- Patch Notes' individually colored Lua strokes and preserves the four
    -- original icon meanings while theme skins remain on the buttons.
    local icon = Chrome.Icon(button, section.icon)
    icon:SetSize(isPrimary and 48 or 20, isPrimary and 48 or 20)
    local label = Style.Text(button, isPrimary and "HALL" or section.label,
        isPrimary and 23 or 12, C.tabMuted, nil,
        isPrimary and "display" or nil)
    if isPrimary then
        icon:SetPoint("TOP", button, "TOP", 0, -4)
        label:SetPoint("BOTTOM", button, "BOTTOM", 0, 6)
        label:SetJustifyH("CENTER")
        -- Static Hall lettering and swords are faithful concept pixels.
        -- Never draw an extra WoW fontstring/glyph over the extracted design.
        if section.key == "hall" then
            icon:Hide()
            label:Hide()
        end
    else
        icon:SetPoint("LEFT", button, "LEFT", 9, 0)
        Style.ConstrainButtonLabel(button, label, 35, 7, 9)
        label:SetJustifyH("LEFT")
    end

    if section.key == "patchnotes" then
        -- Preserve the unread animation, not the old mismatched bitmap.
        label:SetText("Patch Notes")
        patchDot = CreateFrame("Frame", nil, button)
        patchDot:SetSize(9, 9)
        patchDot:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -5)
        Style.Fill(patchDot, C.gold, "OVERLAY")
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
        -- Hover is visible even on the currently selected destination.
        -- Less glow on active buttons keeps the persistent selection clear.
        local active = currentSection == index
        Motion.Fade(hover, active and 0.26 or
            (isPrimary and 0.34 or 0.40), Motion.Duration("quick"))
        if button.hallGlow then
            Motion.Fade(button.hallGlow, 0.30, Motion.Duration("quick"))
        end
    end)
    button:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, Motion.Duration("gentle"))
        if button.hallGlow then
            Motion.Fade(button.hallGlow, 0, Motion.Duration("gentle"))
        end
    end)
    ns.Widgets.PressFeedback(button, hover, {
        corner=isPrimary and 13 or 9,
        hoverAlpha=0.24, clickAlpha=isPrimary and 0.39 or 0.50,
    })
    ns.Tooltips.Bind(button, { title = section.label,
        detail = "Open the " .. section.label .. " section." })

    local item = {
        button = button, primary = isPrimary,
        activeAlpha = section.key == "hall" and 0.15 or (isPrimary and 0.26 or 0.33),
        selected = selected, hover = hover, bar = bar, icon = icon, label = label,
    }
    railButtons[index] = item
    if isPrimary then primaryButtons[#primaryButtons + 1] = item end

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(174, 35)
        sub:SetPoint("LEFT", Window.nav, "LEFT", 6 + (pageIndex - 1) * 182, 0)
        -- Single extracted tab plate replaces the old stacked backdrop/rim.
        local plate = Style.Plate(sub, "dark", { corner=10 })
        local subSelected, subHover = AddOverlay(sub, false)
        local subBar = sub:CreateTexture(nil, "OVERLAY")
        subBar:SetColorTexture(unpack(C.gold))
        subBar:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 8, 0)
        subBar:SetPoint("BOTTOMRIGHT", sub, "BOTTOMRIGHT", -8, 0)
        subBar:SetHeight(2)
        local text = Style.Text(sub, page.label, 15, C.text)
        text:SetWordWrap(false)
        if page.key == "options" or page.key == "interface" then
            -- Bold gold symbols designed to read at 28px: a sparkle for
            -- Appearance and a clean window for Interface. No busy medallions.
            -- The actual button, selected and hover states remain unchanged.
            local glyph = sub:CreateTexture(nil, "OVERLAY", nil, 4)
            glyph:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelMinimalGoldTabs.tga")
            glyph:SetSize(28, 28)
            glyph:SetPoint("LEFT", sub, "LEFT", 12, 0)
            if page.key == "options" then
                glyph:SetTexCoord(0, .5, 0, 1)
            else
                glyph:SetTexCoord(.5, 1, 0, 1)
            end
            Style.ConstrainButtonLabel(sub, text, 46, 10, 10)
            text:SetJustifyH("LEFT")
        else
            Style.ConstrainButtonLabel(sub, text, 9, 9, 9)
            text:SetJustifyH("CENTER")
        end
        sub:SetScript("OnClick", function() Select(index, pageIndex) end)
        sub:SetScript("OnEnter", function()
            local chosen = currentSection == index and currentPage == pageIndex
            Motion.Fade(subHover, chosen and 0.16 or 0.42,
                Motion.Duration("quick"))
        end)
        sub:SetScript("OnLeave", function() Motion.Fade(subHover, 0, 0.20) end)
        ns.Widgets.PressFeedback(sub, subHover, {
            corner=11, hoverAlpha=0.25, clickAlpha=0.52,
        })
        ns.Tooltips.Bind(sub, {
            title = page.label,
            detail = page.subtitle or ("Open the " .. page.label .. " page.")
        })
        pages[#pages + 1] = {
            button = sub, selected = subSelected, hover = subHover,
            bar = subBar, label = text, plate = plate, activeAlpha = 0.13
        }
    end
    subButtons[index] = pages
end

-- Compact Back control belongs to the footer beside Close, not the Hall rail.
-- Navigation remains the sole owner of its state and history.
backButton = Style.Action(Window.content, "Back", "footer", {
    fill=C.nav, hover=C.selected, edge=C.goldDim,
    light=C.goldDim, dark=C.window, text=C.text,
})
backButton:SetSize(60, 24)
backButton:SetPoint("TOPRIGHT", Window.content, "TOPRIGHT", -24, -25)
backButton:SetFrameLevel(Window.content:GetFrameLevel() + 9)
ns.Tooltips.Bind(backButton, { title = "Back",
    detail = "Return to the previous page. History clears when you close Duels." })
backButton:SetScript("OnClick", function()
    local previous = table.remove(history)
    if not previous then return end
    Select(previous.section, previous.page, false, false, true)
    if ns.Feedback then ns.Feedback.Acknowledge("navigation-back-v1") end
end)
if ns.Feedback then
    ns.Feedback.NewBadge(backButton, "navigation-back-v1")
end
backButton:Hide()
Window.frame:HookScript("OnHide", function()
    if workspaceReady then CapturePage() end
    -- Back history is ephemeral presentation state, not SavedVariables.
    for i = #history, 1, -1 do history[i] = nil end
    backButton:Hide()
    Motion.Stop(movingBar)
    Motion.Stop(sweep, 0)
    sweep:Hide()
end)

-- Both geometry passes are event-driven; nothing polls an idle window.
-- Primary gameplay destinations remain independent of the footer and tabs.
local function FitTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    local buttonWidth = math.max(112, math.min(HALL_BUTTON_WIDTH, w - 28))
    for i, item in ipairs(primaryButtons) do
        item.button:ClearAllPoints()
        item.button:SetPoint("TOP", self, "TOP", 0, -31 - (i - 1) * 99)
        item.button:SetWidth(buttonWidth)
    end
end
-- The divider tracks the last gameplay button, leaving the rest of the rail
-- available to future primary destinations without a fixed overlap.
local railDivider = Chrome.Divider(Window.rail, 170, 14)
if #primaryButtons > 0 then
    railDivider:SetPoint("TOP", primaryButtons[#primaryButtons].button,
        "BOTTOM", 0, -18)
else
    railDivider:Hide()
end
Window.rail:SetScript("OnSizeChanged", FitTabs)
FitTabs(Window.rail, Window.rail:GetWidth())

local function FitSubTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    for _, group in ipairs(subButtons) do
        local count = #group
        if count > 0 then
            local tabWidth = math.max(76, math.min(174,
                (math.max(80, w) - 12 - 8 * (count - 1)) / count))
            for j, item in ipairs(group) do
                item.button:ClearAllPoints()
                item.button:SetPoint("LEFT", self, "LEFT",
                    6 + (j - 1) * (tabWidth + 8), 0)
                item.button:SetWidth(tabWidth)
            end
        end
    end
    if movingIndex then PlaceBar(nil, movingIndex) end
end
Window.nav:SetScript("OnSizeChanged", FitSubTabs)
FitSubTabs(Window.nav, Window.nav:GetWidth())

-- A subdued crossed-swords watermark lives in the *primary* rail only.
local railMark = Chrome.Icon(Window.rail, "Hall")
railMark:SetSize(145, 145)
railMark:SetPoint("BOTTOM", Window.rail, "BOTTOM", 0, 48)
railMark:SetAlpha(0.10)
railMark:EnableMouse(false)

ns.Navigation = {
    Back = function()
        if #history == 0 then return false end
        local previous = table.remove(history)
        Select(previous.section, previous.page, false, false, true)
        if ns.Feedback then ns.Feedback.Acknowledge("navigation-back-v1") end
        return true
    end,
    CanGoBack = function() return #history > 0 end,
    ResumeWorkspace = function()
        -- ADDON_LOADED has already seeded SavedVariables when the player
        -- opens Duels; don't mark a hidden Patch Notes page read on login.
        if workspaceReady then return end
        workspaceReady = true
        local sectionKey, pageKey, offset = ns.Settings.GetWorkspace()
        if sectionKey and pageKey then
            for i, section in ipairs(sections) do
                if section.key == sectionKey then
                    for j, page in ipairs(section.pages) do
                        if page.key == pageKey then
                            scrollMemory[sectionKey .. ":" .. pageKey] = offset
                            Select(i, j, true, false, true)
                            return
                        end
                    end
                end
            end
        end
        Select(currentSection or 1, currentPage or 1, true, false, true)
    end,
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

-- Like every other real action, Back participates in the ONE Search registry.
-- It is unavailable until the player actually has somewhere to return.
ns.Search.Register("navigation:back", "Back", "Navigation",
    "Return to your previous Duels page", function()
        return ns.Navigation.Back()
    end, function()
        return ns.Navigation.CanGoBack()
    end)

-- Persist the current scroll on /reload/relog even if the user didn't
-- navigate away or close the window before the interface was torn down.
local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function()
    if workspaceReady then CapturePage() end
end)

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

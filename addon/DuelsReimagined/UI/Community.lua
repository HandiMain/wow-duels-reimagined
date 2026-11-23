local _, ns = ...

-- The Duelist's Circle. One passive view over bundled GitHub-generated data:
-- zero networking, no guessed achievements, and no duplicate data owners.
local Window, Style, Chrome = ns.Window, ns.Style, ns.Chrome
local Widgets, Motion, Search = ns.Widgets, ns.Motion, ns.Search
local C = Style.color
local Community = {}
ns.Community = Community

local GITHUB = "https://github.com/HandiMain/wow-duels-reimagined/issues/new?template="
local LINKS = {
    bug = GITHUB .. "bug-report.yml",
    idea = GITHUB .. "feature-request.yml",
}

local definitions = {
    { key = "contributors", title = "CONTRIBUTORS",
      hint = "Merged GitHub pull requests.", field = "contributors",
      empty = "No contributors credited yet." },
    { key = "bug-hunters", title = "BUG HUNTERS",
      hint = "Reports that led to verified fixes.", field = "bugHunters",
      empty = "No verified reports yet." },
    { key = "community-ideas", title = "COMMUNITY IDEAS",
      hint = "Ideas that made it into the addon.", field = "ideas",
      empty = "No implemented ideas yet." },
    { key = "special-thanks", title = "SPECIAL THANKS",
      hint = "People we appreciate.", field = "specialThanks",
      empty = "No acknowledgements yet." },
}
local byKey = {}
for _, data in ipairs(definitions) do byKey[data.key] = data end

local function Entries(data)
    local source = ns.CommunityCredits or {}
    local list = source[data.field]
    if type(list) ~= "table" then return {} end
    return list
end

local function Entry(item)
    if type(item) == "string" then return item, nil end
    if type(item) ~= "table" or type(item.name) ~= "string" then return nil end
    if type(item.prs) == "number" then
        return item.name, item.prs == 1 and "1 PR" or (item.prs .. " PRs")
    elseif type(item.reports) == "number" then
        return item.name, item.reports == 1 and "1 report" or (item.reports .. " reports")
    elseif type(item.ref) == "number" then
        return item.name, "#" .. item.ref
    end
    return item.name, nil
end

local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:EnableMouse(false)
root:Hide()

-- Approved shared Community heading. The generic Window page heading is
-- deliberately hidden for custom pages, so the page owner must draw this.
local communityIcon = Chrome.Icon(root, "Community")
communityIcon:SetSize(34, 34)
communityIcon:SetPoint("TOPLEFT", root, "TOPLEFT", 23, -16)
local communityHeading = Style.Text(root, "Community", 26, C.pale, nil, "display")
communityHeading:SetPoint("TOPLEFT", root, "TOPLEFT", 64, -16)
local communityTagline = Style.Text(root, "The people shaping Duels Reimagined.", 13, C.text)
communityTagline:SetPoint("TOPLEFT", communityHeading, "BOTTOMLEFT", 0, -3)

local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 19, -139)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -22, 16)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(900, 532)
scroll:SetScrollChild(canvas)

local bar = Widgets.ScrollBar(scroll, function()
    return scroll:GetHeight(), canvas:GetHeight(), scroll:GetVerticalScroll()
end, function(position)
    scroll:SetVerticalScroll(position)
end)
local function ClampScroll()
    local maxScroll = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,
        math.min(maxScroll, scroll:GetVerticalScroll())))
    bar:Refresh()
end
scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, canvas:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0,
        math.min(maxScroll, self:GetVerticalScroll() - delta * 43)))
    bar:Refresh()
end)
scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
scroll:SetScript("OnSizeChanged", function(_, width)
    canvas:SetWidth(math.max(1, (width or 900) - 14))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    ClampScroll()
end)
scroll:HookScript("OnShow", ClampScroll)

-- Approved Duelist's Circle hero: live labels/buttons over separate faction
-- decoration. The existing Alliance/Horde imagery is retained; Blizzard's
-- PvP queue artwork supplies richer atmosphere (and is never copied into
-- addon files). Image paths are client-owned; fade art is the fallback.
local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityFactionMarks.png"
local allianceArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityAllianceLion.png"
local symbolArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityConceptSymbols.png"
local function ConceptSymbol(parent, slot, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(symbolArt)
    local x, y = slot % 4, math.floor(slot / 4)
    tex:SetTexCoord(x / 4 + 0.002, (x + 1) / 4 - 0.002,
        y / 4 + 0.002, (y + 1) / 4 - 0.002)
    tex:SetSize(size, size)
    tex:EnableMouse(false)
    return Chrome.Sharp(tex)
end

-- One subdued rim encloses the banner; the label/action hitboxes remain in
-- the same canvas above it and are never baked into a screenshot.
local hero = CreateFrame("Frame", nil, canvas)
hero:SetPoint("TOPLEFT", canvas, "TOPLEFT", 4, 0)
hero:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, 0)
hero:SetHeight(171)
Style.Skin(hero, C.window, { corner=8, edge=C.goldDim,
    smooth=true, rim=0.48 })

local function FactionMark(left)
    local background = hero:CreateTexture(nil, "BORDER", nil, 1)
    background:SetTexture("Interface\\PVPFrame\\" ..
        (left and "PvPQueueBackgroundAlliance" or "PvPQueueBackgroundHorde"))
    background:SetSize(304, 171)
    if left then
        background:SetPoint("TOPLEFT", hero, "TOPLEFT", 1, -1)
        background:SetTexCoord(0.05, 0.78, 0.02, 0.96)
    else
        background:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -1, -1)
        background:SetTexCoord(0.02, 0.80, 0.02, 0.96)
    end
    background:SetVertexColor(left and 0.65 or 0.95,
        left and 0.80 or 0.56, left and 1 or 0.55)
    background:SetAlpha(0.68)
    background:EnableMouse(false)
    Chrome.Sharp(background)
    -- Actual source faction symbols, enlarged to the hero scale. The tiny
    -- TargetingFrame PvP shields are not suitable as full-size faction marks.
    local emblem = hero:CreateTexture(nil, "ARTWORK", nil, 1)
    if left then
        emblem:SetTexture(allianceArt)
        emblem:SetTexCoord(0, 1, 0, 1)
        emblem:SetPoint("CENTER", background, "CENTER", -15, 1)
    else
        emblem:SetTexture(art)
        emblem:SetTexCoord(0.5, 1, 0, 1)
        emblem:SetPoint("CENTER", background, "CENTER", 28, 1)
    end
    emblem:SetSize(176, 176)
    emblem:SetAlpha(0.86)
    emblem:EnableMouse(false)
    Chrome.Sharp(emblem)
    return background, emblem
end
FactionMark(true)
FactionMark(false)

local title = Style.Text(hero, "THE DUELIST'S CIRCLE", 28, C.pale, nil, "display")
-- Full-width center anchor prevents clipping at the minimum window size.
title:SetPoint("TOPLEFT", hero, "TOPLEFT", 24, -14)
title:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -24, -14)
title:SetJustifyH("CENTER")
title:SetWordWrap(false)
local ornament = Chrome.Divider(hero, 340, 12)
ornament:SetPoint("TOP", title, "BOTTOM", 0, -4)
local subtitle = Style.Text(hero, "The people shaping Duels Reimagined.", 13, C.text)
subtitle:SetPoint("TOP", ornament, "BOTTOM", 0, -2)
subtitle:SetJustifyH("CENTER")
subtitle:SetWidth(460)
subtitle:SetWordWrap(false)

local function SelectableURL(kind)
    if not ns.Footer or not ns.Footer.ShowCommunityLink then return end
    local heading = kind == "bug" and "Report a Bug on GitHub" or "Suggest an Idea on GitHub"
    ns.Footer.ShowCommunityLink(heading, LINKS[kind])
end

local function Action(kind, heading, xOffset)
    local btn = Style.Action(hero, heading, "community")
    btn:SetSize(256, 41)
    btn:SetPoint("TOP", hero, "TOP", xOffset, -101)
    btn:SetScript("OnClick", function() SelectableURL(kind) end)
    local actionIcon = ConceptSymbol(btn, kind == "bug" and 8 or 9, 29)
    actionIcon:SetPoint("LEFT", btn, "LEFT", 14, 0)
    local arrow = Style.Text(btn, ">", 15, C.gold)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -15, 0)
    arrow:SetJustifyH("RIGHT")
    ns.Tooltips.Bind(btn, {
        title = heading,
        detail = (kind == "bug" and "Get a link to report a bug on GitHub."
            or "Get a link to suggest an improvement.") ..
            " Copy the URL with Ctrl+C, then open it in your browser.",
    })
    return btn
end

Action("bug", "REPORT A BUG", -139)
Action("idea", "SUGGEST AN IDEA", 139)

-- The approved Community landing page: one quiet GitHub statistics strip and
-- two readable information panels. Its five existing subcategory tabs remain
-- the ONLY destinations for detailed contributor, bug, idea and thanks lists.
-- All counters come from the same bundled generated GitHub data as those lists.
local overviewPieces = {}

local statsPanel = CreateFrame("Frame", nil, canvas)
statsPanel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -178)
statsPanel:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -178)
statsPanel:SetHeight(58)
-- The statistic strip is only 58px tall; use short native relief here,
-- not the 112px fades intended for large card backgrounds.
Style.Skin(statsPanel, C.nav, { corner=9, edge=C.goldDim,
    shine=0.09, shade=0.08, rim=0.96 })
overviewPieces[#overviewPieces + 1] = statsPanel

local statDefs = {
    { label="Contributors", field="contributors", icon=0,
      tooltip="Distinct authors of merged GitHub pull requests, excluding the project owner and bots." },
    { label="Bug Reports", field="bugReports", icon=8,
      tooltip="GitHub issues marked bug, including reports not yet verified or fixed." },
    { label="Community Ideas", field="communityIdeas", icon=9,
      tooltip="Submitted GitHub issues marked enhancement, not only ideas already implemented." },
    { label="Special Thanks", field="specialThanks", icon=3,
      tooltip="People explicitly acknowledged in the reviewed community credits file." },
}
local statCells = {}
for i, def in ipairs(statDefs) do
    local cell = CreateFrame("Frame", nil, statsPanel)
    cell:SetHeight(58)
    cell:EnableMouse(true)
    local icon = ConceptSymbol(cell, def.icon, 31)
    icon:SetPoint("LEFT", cell, "LEFT", 14, 0)
    local value = Style.Text(cell, "—", 23, C.gold, nil, "display")
    value:SetPoint("TOPLEFT", cell, "TOPLEFT", 51, -8)
    value:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -8, -8)
    local label = Style.Text(cell, def.label, 12, C.text)
    label:SetPoint("TOPLEFT", cell, "TOPLEFT", 51, -34)
    label:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -8, -34)
    label:SetWordWrap(false)
    ns.Tooltips.Bind(cell, { title=def.label,
        detail=def.tooltip .. " Counts come from the GitHub snapshot bundled with this addon build." })
    if i > 1 then
        local separator = Style.Fill(cell, C.goldDim, "ARTWORK")
        separator:ClearAllPoints()
        separator:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -12)
        separator:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 0, 12)
        separator:SetWidth(1)
        separator:SetAlpha(0.60)
    end
    statCells[i] = { frame=cell, value=value, field=def.field }
end
local function FitStats(_, width)
    width = math.max(1, width or statsPanel:GetWidth())
    local cellWidth = width / #statCells
    for i, item in ipairs(statCells) do
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", statsPanel, "TOPLEFT",
            (i - 1) * cellWidth, 0)
        item.frame:SetSize(cellWidth, 58)
    end
end
statsPanel:SetScript("OnSizeChanged", FitStats)
FitStats(statsPanel, statsPanel:GetWidth())

local function InfoPanel(left, heading, description, iconIndex)
    local panel = CreateFrame("Frame", nil, canvas)
    panel:SetHeight(224)
    if left then
        panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -247)
        panel:SetPoint("TOPRIGHT", canvas, "TOP", -9, -247)
    else
        panel:SetPoint("TOPLEFT", canvas, "TOP", 9, -247)
        panel:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -247)
    end
    -- Use the same line-free large-panel surface as the Hall, preserving
    -- one copper rim instead of stretching the small shade masks.
    Style.Skin(panel, C.nav, { corner=10, edge=C.goldDim,
        smooth=true, rim=0.98 })
    local symbol = ConceptSymbol(panel, iconIndex, 38)
    symbol:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -10)
    local headingText = Style.Text(panel, heading, 19, C.gold, nil, "display")
    headingText:SetPoint("TOPLEFT", panel, "TOPLEFT", 56, -11)
    local caption = Style.Text(panel, description, 12, C.muted)
    caption:SetPoint("TOPLEFT", panel, "TOPLEFT", 56, -36)
    caption:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    caption:SetWordWrap(false)
    local separator = Style.Fill(panel, C.goldDim, "ARTWORK")
    separator:ClearAllPoints()
    separator:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -63)
    separator:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -63)
    separator:SetHeight(1)
    separator:SetAlpha(0.45)
    overviewPieces[#overviewPieces + 1] = panel
    return panel
end

local creditsPanel = InfoPanel(true, "COMMUNITY CREDITS",
    "A guide to the community pages.", 0)
local creditDescriptions = {
    { "The Duelist's Circle", "Overview and ways to help.", 0 },
    { "Contributors", "Merged pull request authors.", 1 },
    { "Bug Hunters", "Verified bug-fix reporters.", 8 },
    { "Community Ideas", "Ideas implemented in the addon.", 9 },
    { "Special Thanks", "Community acknowledgements.", 3 },
}
for i, entry in ipairs(creditDescriptions) do
    local y = -75 - (i - 1) * 27
    local icon = ConceptSymbol(creditsPanel, entry[3], 19)
    icon:SetPoint("TOPLEFT", creditsPanel, "TOPLEFT", 15, y + 1)
    local label = Style.Text(creditsPanel, entry[1], 13, C.gold)
    label:SetPoint("TOPLEFT", creditsPanel, "TOPLEFT", 42, y)
    label:SetWidth(143)
    label:SetWordWrap(false)
    local summary = Style.Text(creditsPanel, entry[2], 12, C.text)
    summary:SetPoint("TOPLEFT", creditsPanel, "TOPLEFT", 191, y)
    summary:SetPoint("TOPRIGHT", creditsPanel, "TOPRIGHT", -12, y)
    summary:SetWordWrap(false)
end

local helpPanel = InfoPanel(false, "HOW TO HELP",
    "Simple ways to improve Duels Reimagined.", 2)
local helpRows = {
    { "Report bugs", "Help us find and fix issues." },
    { "Share ideas", "Suggest improvements." },
    { "Test builds", "Try changes and report problems." },
    { "Give feedback", "Share your experience." },
}
for i, entry in ipairs(helpRows) do
    local y = -84 - (i - 1) * 33
    -- Draw an actual Blizzard check texture instead of the unavailable
    -- unicode font glyph that rendered as a square on both WoW clients.
    local check = helpPanel:CreateTexture(nil, "ARTWORK")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(unpack(C.gold))
    check:SetSize(23, 23)
    check:SetPoint("TOPLEFT", helpPanel, "TOPLEFT", 15, y + 6)
    local label = Style.Text(helpPanel, entry[1], 13, C.gold)
    label:SetPoint("TOPLEFT", helpPanel, "TOPLEFT", 53, y)
    label:SetWidth(119)
    label:SetWordWrap(false)
    local description = Style.Text(helpPanel, entry[2], 12, C.text)
    description:SetPoint("TOPLEFT", helpPanel, "TOPLEFT", 174, y + 1)
    description:SetPoint("TOPRIGHT", helpPanel, "TOPRIGHT", -10, y + 1)
    description:SetWordWrap(false)
end

-- No Community Tools row: Patch Notes and Options are already available
-- in the permanent footer. Duplicating those buttons would add no value.
-- A generated snapshot is not a live GitHub connection. Missing stats
-- must never masquerade as zero; the automation publishes verified numbers.
local function UpdateOverview()
    local source = ns.CommunityCredits or {}
    local stats = source.stats
    for _, item in ipairs(statCells) do
        local count = type(stats) == "table" and stats[item.field] or nil
        if type(count) == "number" and count >= 0 and count == math.floor(count) then
            item.value:SetText(tostring(count))
        else
            item.value:SetText("—")
        end
    end
end

-- A single reusable detail list, rather than creating four separate panels.
local listing = CreateFrame("Frame", nil, canvas)
listing:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -175)
listing:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -175)
listing:SetHeight(245)
Style.Skin(listing, C.nav, { corner=11, edge=C.border, shine=0.25, shade=0.26 })
local listTitle = Style.Text(listing, "", 19, C.gold)
listTitle:SetPoint("TOPLEFT", listing, "TOPLEFT", 20, -15)
local listHint = Style.Text(listing, "", 13, C.muted)
listHint:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -5)
local listRule = Chrome.Divider(listing, 285, 12)
listRule:SetPoint("TOP", listing, "TOP", 0, -60)
local listEmpty = Style.Text(listing, "", 14, C.muted)
listEmpty:SetPoint("TOP", listing, "TOP", 0, -133)
listEmpty:SetJustifyH("CENTER")
local rows = {}
local function Row(i)
    if rows[i] then return rows[i] end
    local name = Style.Text(listing, "", 14, C.text)
    name:SetPoint("TOPLEFT", listing, "TOPLEFT", 25, -88 - (i - 1) * 30)
    name:SetPoint("RIGHT", listing, "RIGHT", -113, 0)
    local count = Style.Text(listing, "", 12, C.muted)
    count:SetPoint("TOPRIGHT", listing, "TOPRIGHT", -25, -88 - (i - 1) * 30)
    rows[i] = { name = name, value = count }
    return rows[i]
end
listing:Hide()

local function UpdateList(data)
    local entries = Entries(data)
    listTitle:SetText(data.title)
    listHint:SetText(data.hint)
    listEmpty:SetText(data.empty)
    listEmpty:SetShown(#entries == 0)
    for i = 1, math.max(#entries, #rows) do
        local r = Row(i)
        local name, value = Entry(entries[i])
        r.name:SetText(name or "")
        r.value:SetText(value or "")
        r.name:SetShown(name ~= nil)
        r.value:SetShown(name ~= nil and value ~= nil)
    end
    local h = math.max(245, 116 + #entries * 30)
    listing:SetHeight(h)
    canvas:SetHeight(185 + h + 20)
end

function Community.GetPageScroll(key)
    if key ~= "community" and not byKey[key] then return 0 end
    return scroll:GetVerticalScroll()
end
function Community.SetPageScroll(key, offset)
    if (key ~= "community" and not byKey[key]) or
        type(offset) ~= "number" then return end
    local limit = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(limit, offset)))
    bar:Refresh()
end

function Community.Show(key)
    local active = type(key) == "string" and
        (key == "community" or byKey[key] ~= nil)
    root:SetShown(active)
    if not active then return end
    local overview = key == "community"
    for _, item in ipairs(overviewPieces) do item:SetShown(overview) end
    listing:SetShown(not overview)
    if overview then
        UpdateOverview()
        canvas:SetHeight(485)
    else
        UpdateList(byKey[key])
    end
    scroll:SetVerticalScroll(0)
    ClampScroll()
end

-- Search actions have one owner and never claim a browser was opened.
Search.Register("community:report-bug", "Report a Bug", "Community / GitHub",
    "Open a copyable link to the GitHub bug report form", function()
        if ns.Navigation then ns.Navigation.SelectKey("community", "community") end
        SelectableURL("bug")
    end)
Search.Register("community:suggest-idea", "Suggest an Idea", "Community / GitHub",
    "Open a copyable link to suggest a Duels Reimagined improvement", function()
        if ns.Navigation then ns.Navigation.SelectKey("community", "community") end
        SelectableURL("idea")
    end)

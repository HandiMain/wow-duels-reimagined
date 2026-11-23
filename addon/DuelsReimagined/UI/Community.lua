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

-- Artwork was previously stretched across every available width. Restrict the
-- approved design to its original proportions, then reflow narrow windows.
-- Resize events own layout; no permanent OnUpdate or second resize engine.
local DESIGN_WIDTH, CARD_BREAKPOINT = 940, 930
local ReflowCommunity
local selectedKey = "community"

local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 19, -131)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -22, 16)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(900, 532)
scroll:SetScrollChild(canvas)

-- The canvas fills the scroll viewport so the child can be centered even
-- when the window grows far wider than the approved Community composition.
local stage = CreateFrame("Frame", nil, canvas)
stage:SetPoint("TOP", canvas, "TOP", 0, 0)
stage:SetSize(DESIGN_WIDTH, 460)

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
    if ReflowCommunity then ReflowCommunity() end
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    ClampScroll()
end)
scroll:HookScript("OnShow", ClampScroll)

-- Approved concept art is extracted from the supplied reference image.
-- Only static decorative content is baked; dynamic stats and clickable buttons
-- stay owned by the existing Community/UI and GitHub-credit systems.
local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityFactionMarks.png"
local allianceArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityAllianceLion.png"
local symbolArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityConceptSymbols.png"
local conceptRoot = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
local conceptHero = conceptRoot .. "CommunityConceptHero.png"
local conceptTitle = conceptRoot .. "CommunityConceptTitle.png"
local conceptButtons = conceptRoot .. "CommunityConceptButtons.png"
local conceptHeaders = conceptRoot .. "CommunityConceptHeaders.png"
local conceptIcons = conceptRoot .. "CommunityConceptIcons.png"
local function ExactSymbol(parent, slot, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(conceptIcons)
    local x = slot % 8
    local y = math.floor(slot / 8)
    tex:SetTexCoord(x / 8, (x + 1) / 8, y / 2, (y + 1) / 2)
    tex:SetSize(size, size)
    tex:EnableMouse(false)
    return Chrome.Sharp(tex)
end
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
local hero = CreateFrame("Frame", nil, stage)
-- A fixed source-ratio design plane. Narrow windows scale the entire hero
-- uniformly, including textures, lettering and true button hitboxes.
hero:SetPoint("TOP", stage, "TOP", 0, 0)
hero:SetSize(DESIGN_WIDTH - 8, 158)
Style.Skin(hero, C.window, { corner=8, edge=C.goldDim,
    smooth=true, rim=0.48 })

-- Real, user-approved hero banner pixels. The transparent center gives
-- native title/action hit targets clean ownership without image duplicates.
local exactHeroArt = hero:CreateTexture(nil, "BACKGROUND", nil, 4)
exactHeroArt:SetTexture(conceptHero)
exactHeroArt:SetAllPoints(hero)
exactHeroArt:SetTexCoord(0, 1, 0, 352 / 512)
exactHeroArt:EnableMouse(false)
Chrome.Sharp(exactHeroArt)

-- The title and ornament are static approved branding, never gameplay data.
local exactTitle = hero:CreateTexture(nil, "ARTWORK", nil, 3)
exactTitle:SetTexture(conceptTitle)
exactTitle:SetSize(418, 77)
exactTitle:SetTexCoord(0, 518 / 1024, 0, 93 / 128)
exactTitle:SetPoint("TOP", hero, "TOP", -24, -10)
exactTitle:EnableMouse(false)
Chrome.Sharp(exactTitle)

local function SelectableURL(kind)
    if not ns.Footer or not ns.Footer.ShowCommunityLink then return end
    local heading = kind == "bug" and "Report a Bug on GitHub" or "Suggest an Idea on GitHub"
    ns.Footer.ShowCommunityLink(heading, LINKS[kind])
end

local function Action(kind, heading, xOffset)
    local btn = Style.Action(hero, heading, "community-art")
    btn:SetSize(242, 42)
    btn:SetPoint("TOP", hero, "TOP", xOffset, -103)
    btn:SetScript("OnClick", function() SelectableURL(kind) end)
    -- Exact approved illustration, lettering and gold frame; the native
    -- Style.Action still owns click, hover, press, focus and tooltips.
    if btn.label then btn.label:Hide() end
    local artTex = btn:CreateTexture(nil, "ARTWORK", nil, 4)
    artTex:SetTexture(conceptButtons)
    artTex:SetAllPoints(btn)
    local x = kind == "bug" and 0 or 512
    -- The approved button frame extends beyond the previous 295x55 crop.
    -- Include the full outline/corners with a small transparent safety edge.
    artTex:SetTexCoord(x / 1024, (x + 308) / 1024, 0, 60 / 128)
    artTex:EnableMouse(false)
    Chrome.Sharp(artTex)
    ns.Tooltips.Bind(btn, {
        title=heading,
        detail=(kind == "bug" and "Get a link to report a bug on GitHub."
            or "Get a link to suggest an improvement.") ..
            " Copy the URL with Ctrl+C, then open it in your browser.",
    })
    return btn
end

-- These two native controls belong to the overview only. Detail tabs use
-- the same hero artwork but never show redundant call-to-action buttons.
local bugAction = Action("bug", "REPORT A BUG", -133)
local ideaAction = Action("idea", "SUGGEST AN IDEA", 133)

-- The approved Community landing page: one quiet GitHub statistics strip and
-- two readable information panels. Its five existing subcategory tabs remain
-- the ONLY destinations for detailed contributor, bug, idea and thanks lists.
-- All counters come from the same bundled generated GitHub data as those lists.
local overviewPieces = {}

local statsPanel = CreateFrame("Frame", nil, stage)
statsPanel:SetPoint("TOPLEFT", stage, "TOPLEFT", 12, -163)
statsPanel:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -12, -163)
statsPanel:SetHeight(58)
-- The statistic strip is only 58px tall; use short native relief here,
-- not the 112px fades intended for large card backgrounds.
Style.Skin(statsPanel, C.window, { corner=9, edge=C.goldDim,
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
local statsColumns = 4
for i, def in ipairs(statDefs) do
    local cell = CreateFrame("Frame", nil, statsPanel)
    cell:SetHeight(58)
    cell:EnableMouse(true)
    local icon = ExactSymbol(cell, i - 1, 40)
    icon:SetPoint("LEFT", cell, "LEFT", 52, 0)
    local value = Style.Text(cell, "—", 23, C.gold)
    value:SetPoint("TOPLEFT", cell, "TOPLEFT", 104, -8)
    value:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -8, -8)
    local label = Style.Text(cell, def.label, 12, C.text)
    label:SetPoint("TOPLEFT", cell, "TOPLEFT", 104, -34)
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
    local cellWidth = width / statsColumns
    for i, item in ipairs(statCells) do
        local column = (i - 1) % statsColumns
        local line = math.floor((i - 1) / statsColumns)
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", statsPanel, "TOPLEFT",
            column * cellWidth, -line * 58)
        item.frame:SetSize(cellWidth, 58)
    end
end
statsPanel:SetScript("OnSizeChanged", FitStats)
FitStats(statsPanel, statsPanel:GetWidth())

-- Both cards contain explanatory, static text, never live statistics.
-- The screenshot's exact gold lettering, icons, borders and body spacing
-- are one approved visual texture each. Live, actionable subcategories
-- continue to exist as the five native tabs and detail lists above.
local function InfoPanel(left, heading, description, iconIndex)
    local panel = CreateFrame("Frame", nil, stage)
    panel:SetHeight(203)
    if left then
        panel:SetPoint("TOPLEFT", stage, "TOPLEFT", 12, -233)
        panel:SetPoint("TOPRIGHT", stage, "TOP", 20, -233)
    else
        panel:SetPoint("TOPLEFT", stage, "TOP", 38, -233)
        panel:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -12, -233)
    end
    -- Shared background remains, but the original concept crop is the one
    -- border/text paint owner (avoid two overlapping copper rims).
    Style.Skin(panel, C.window, { corner=10, edge=C.goldDim,
        smooth=true, rim=0 })
    local artTex = panel:CreateTexture(nil, "ARTWORK", nil, 4)
    artTex:SetTexture(conceptRoot .. "CommunityConceptCards.png")
    artTex:SetAllPoints(panel)
    if left then
        artTex:SetTexCoord(0, 633 / 2048, 0, 255 / 512)
    else
        artTex:SetTexCoord(768 / 2048, 1362 / 2048, 0, 255 / 512)
    end
    artTex:EnableMouse(false)
    Chrome.Sharp(artTex)
    overviewPieces[#overviewPieces + 1] = panel
    return panel
end

local creditsPanel = InfoPanel(true, "COMMUNITY CREDITS",
    "A guide to the community pages.", 0)
local helpPanel = InfoPanel(false, "HOW TO HELP",
    "Simple ways to improve Duels Reimagined.", 2)

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
local listing = CreateFrame("Frame", nil, stage)
listing:SetPoint("TOPLEFT", stage, "TOPLEFT", 22, -175)
listing:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -22, -175)
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
end

-- At default size this resolves to the approved 940x460 composition.
-- Wider windows center it without stretching bitmap lettering or faction
-- graphics. At compact sizes the hero scales as one piece, statistic cells
-- reflow into two readable rows, and both art-backed cards stack at their
-- full readable width with natural vertical scrolling.
ReflowCommunity = function()
    local width = math.max(1, math.min(DESIGN_WIDTH, canvas:GetWidth()))
    local compact = width < CARD_BREAKPOINT
    stage:SetWidth(width)

    -- The page heading belongs to the same centered composition as the
    -- banner. Preserve its original left alignment at normal window size.
    local centerInset = math.max(0, (canvas:GetWidth() - width) / 2)
    communityIcon:ClearAllPoints()
    communityIcon:SetPoint("TOPLEFT", root, "TOPLEFT",
        23 + centerInset, -16)
    communityHeading:ClearAllPoints()
    communityHeading:SetPoint("TOPLEFT", root, "TOPLEFT",
        64 + centerInset, -16)

    local heroScale = math.min(1, width / DESIGN_WIDTH)
    hero:SetScale(heroScale)
    local heroHeight = 158 * heroScale
    local statsTop = heroHeight + 5
    local statsHeight = compact and 116 or 58
    local cardsTop = statsTop + statsHeight + 12

    statsColumns = compact and 2 or 4
    statsPanel:ClearAllPoints()
    statsPanel:SetPoint("TOPLEFT", stage, "TOPLEFT", 12, -statsTop)
    statsPanel:SetSize(math.max(1, width - 24), statsHeight)
    FitStats(statsPanel, math.max(1, width - 24))

    creditsPanel:ClearAllPoints()
    helpPanel:ClearAllPoints()
    local contentBottom
    if compact then
        -- Never compress fixed-image text into narrow half-width cards.
        local cardWidth = math.min(510, math.max(1, width - 24))
        creditsPanel:SetSize(cardWidth, 203)
        helpPanel:SetSize(cardWidth, 203)
        creditsPanel:SetPoint("TOP", stage, "TOP", 0, -cardsTop)
        helpPanel:SetPoint("TOP", stage, "TOP", 0, -(cardsTop + 213))
        contentBottom = cardsTop + 213 + 203
    else
        -- Keep the original asymmetrical (credits slightly wider) design
        -- without fighting a previous compact frame width constraint.
        creditsPanel:SetSize(width / 2 + 8, 203)
        helpPanel:SetSize(width / 2 - 50, 203)
        creditsPanel:SetPoint("TOPLEFT", stage, "TOPLEFT", 12, -cardsTop)
        helpPanel:SetPoint("TOPLEFT", stage, "TOP", 38, -cardsTop)
        contentBottom = cardsTop + 203
    end

    local listingTop = heroHeight + 17
    listing:ClearAllPoints()
    listing:SetPoint("TOPLEFT", stage, "TOPLEFT", 22, -listingTop)
    listing:SetWidth(math.max(1, width - 44))

    local height
    if selectedKey == "community" then
        height = contentBottom + 24
    else
        height = listingTop + listing:GetHeight() + 20
    end
    stage:SetHeight(height)
    canvas:SetHeight(height)
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    ClampScroll()
end
ReflowCommunity()

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
    selectedKey = key
    -- Every Community tab keeps the same decorative Alliance/Horde banner.
    -- Only the Circle overview shows its two actions, statistics and panels.
    hero:Show()
    bugAction:SetShown(overview)
    ideaAction:SetShown(overview)
    for _, item in ipairs(overviewPieces) do item:SetShown(overview) end
    listing:SetShown(not overview)
    if overview then
        UpdateOverview()
    else
        UpdateList(byKey[key])
    end
    ReflowCommunity()
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

local _, ns = ...
local Style, Chrome, Widgets = ns.Style, ns.Chrome, ns.Widgets
local Motion, Search, Settings = ns.Motion, ns.Search, ns.Settings
local C, Window = Style.color, ns.Window

-- One author-reviewed release catalogue owns the left version rail, selected
-- hero, summaries, entry cards and Search targets. Neither this UI nor the
-- demo test records invent an addon version or an actual release.
local releases = ns.PatchNotesData or {}
local byKey = {}
for index, release in ipairs(releases) do
    byKey[release.key] = { index=index, data=release }
end
local PatchNotes = {}
ns.PatchNotes = PatchNotes

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\"
local atlas = art .. "PatchNotesAtlas.tga"
local heroArtPath = art .. "PatchNotesHero.png"

local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:Hide()
local heading = Style.Text(root, "Patch Notes", 24, C.pale, nil, "display")
heading:SetPoint("TOP", root, "TOP", 0, -13)
local headingRule = Chrome.Divider(root, 300, 12)
headingRule:SetPoint("TOP", heading, "BOTTOM", 0, -3)
local subheading = Style.Text(root, "A more polished home for Duels updates.", 12, C.text)
subheading:SetPoint("TOP", headingRule, "BOTTOM", 0, -1)
subheading:SetJustifyH("CENTER")

local function TileIcon(parent, symbol, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(atlas)
    tex:SetSize(size, size)
    local coords = {
        scroll = { 0, 0.5, 0, 0.5 },
        parchment = { 0.5, 1, 0, 0.5 },
        gear = { 0, 0.5, 0.5, 1 },
        swords = { 0.5, 1, 0.5, 1 },
    }
    function tex:SetSymbol(value)
        self:SetTexCoord(unpack(coords[value] or coords.scroll))
    end
    tex:SetSymbol(symbol)
    return tex
end

-- Patch Notes pages remain registered for Search and Back, but only this
-- page draws their selection controls: a vertical,
-- independently scrollable version list that grows with the data table.
local rail = CreateFrame("Frame", nil, root)
rail:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -88)
rail:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 20, 18)
rail:SetWidth(194)
Style.Skin(rail, C.window, { corner=11, edge=C.goldDim,
    smooth=true, rim=0.96 })
local versionsTitle = Style.Text(rail, "Versions", 20, C.pale)
versionsTitle:SetPoint("TOP", rail, "TOP", 0, -8)
versionsTitle:SetJustifyH("CENTER")
-- The approved Versions heading uses two short flanking lines, NOT a
-- full-width divider below the title (which visually crossed the hero).
local function VersionFlank(side)
    local line = Style.Fill(rail, C.goldDim, "ARTWORK")
    line:ClearAllPoints()
    line:SetPoint(side == "LEFT" and "RIGHT" or "LEFT",
        versionsTitle, side, side == "LEFT" and -12 or 12, 0)
    line:SetSize(24, Style.Pixel(rail, 2))
    line:SetAlpha(0.80)
    return line
end
VersionFlank("LEFT")
VersionFlank("RIGHT")

local versionScroll = CreateFrame("ScrollFrame", nil, rail)
versionScroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 11, -51)
versionScroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, 11)
versionScroll:EnableMouseWheel(true)
local versionCanvas = CreateFrame("Frame", nil, versionScroll)
versionCanvas:SetSize(168, 100)
versionScroll:SetScrollChild(versionCanvas)
local versionBar = Widgets.ScrollBar(versionScroll, function()
    return versionScroll:GetHeight(), versionCanvas:GetHeight(),
        versionScroll:GetVerticalScroll()
end, function(offset) versionScroll:SetVerticalScroll(offset) end)
local function ClampVersions()
    local limit = math.max(0, versionCanvas:GetHeight() - versionScroll:GetHeight())
    versionScroll:SetVerticalScroll(math.max(0,
        math.min(limit, versionScroll:GetVerticalScroll())))
    versionBar:Refresh()
end
versionScroll:SetScript("OnVerticalScroll", function() versionBar:Refresh() end)
versionScroll:SetScript("OnSizeChanged", function(self)
    versionCanvas:SetWidth(math.max(1, self:GetWidth() - 12))
    ClampVersions()
end)
versionScroll:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(
        math.max(0, versionCanvas:GetHeight() - self:GetHeight()),
        self:GetVerticalScroll() - delta * 54)))
    versionBar:Refresh()
end)

local versions = {}
local railY = 2
for index, release in ipairs(releases) do
    local archived = index > 3
    if index == 4 then
        -- Small gold separator matches the artwork archive without placing
        -- another wide divider over the live release banner.
        local archiveLine = Style.Fill(versionCanvas, C.goldDim, "ARTWORK")
        archiveLine:ClearAllPoints()
        archiveLine:SetPoint("TOP", versionCanvas, "TOP", 0, -railY - 8)
        archiveLine:SetSize(132, Style.Pixel(versionCanvas, 2))
        archiveLine:SetAlpha(0.66)
        local jewel = versionCanvas:CreateTexture(nil, "OVERLAY")
        jewel:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCornerJewel.tga")
        jewel:SetSize(14, 14)
        jewel:SetPoint("CENTER", archiveLine, "CENTER", 0, 0)
        railY = railY + 36
    end
    local button = CreateFrame("Button", nil, versionCanvas)
    button:SetPoint("TOPLEFT", versionCanvas, "TOPLEFT", 2, -railY)
    button:SetPoint("TOPRIGHT", versionCanvas, "TOPRIGHT", -2, -railY)
    button:SetHeight(archived and 39 or 58)
    button:RegisterForClicks("LeftButtonUp")
    Style.Skin(button, C.nav, { corner=9, edge=C.border,
        shine=0.17, shade=0.13, rim=0.72 })
    -- Use the approved gold spear-edged selection plate, minus baked text.
    -- The native font strings remain the only version labels.
    local selected = button:CreateTexture(nil, "ARTWORK", nil, 3)
    selected:SetTexture(art .. "PatchNotesVersionSelected.png")
    selected:SetAllPoints(button)
    selected:SetTexCoord(0, 199/256, 0, 70/128)
    selected:SetAlpha(0)
    selected:EnableMouse(false)
    local hover = Style.FeedbackOverlay(button, {
        corner=9, inset=2, fill=C.gold, edge=C.goldDim,
        shine=0.32, rim=0.60,
    })
    local dot = button:CreateTexture(nil, "ARTWORK", nil, 4)
    dot:SetTexture(art .. "PatchNotesVersionRing.png")
    dot:SetSize(18, 18)
    dot:SetPoint("LEFT", button, "LEFT", 9, 0)
    dot:EnableMouse(false)
    local archiveArrow = Style.Text(button, ">", 13, C.gold)
    archiveArrow:SetPoint("LEFT", button, "LEFT", 12, 0)
    archiveArrow:SetShown(archived)
    dot:SetShown(not archived)
    local number = Style.Text(button, release.version or "?", archived and 15 or 17, C.pale)
    number:SetPoint("TOPLEFT", button, "TOPLEFT", 35, archived and -8 or -8)
    number:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -8)
    number:SetWordWrap(false)
    local description = Style.Text(button, release.navTitle or "Update", 11, C.muted)
    description:SetPoint("TOPLEFT", button, "TOPLEFT", 35, -33)
    description:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -33)
    description:SetWordWrap(false)
    description:SetShown(not archived)
    button:SetScript("OnClick", function()
        if ns.Navigation then
            ns.Navigation.SelectKey("patchnotes", release.key)
        end
    end)
    button:SetScript("OnEnter", function()
        Motion.Fade(hover, 0.22, Motion.Duration("quick"))
    end)
    button:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, Motion.Duration("gentle"))
    end)
    Widgets.PressFeedback(button, hover)
    ns.Tooltips.Bind(button, {
        title = (release.version or "Update") .. " — " .. (release.navTitle or ""),
        detail = (release.demo == false and "Release notes" or "Fictional demo patch notes") ..
            ". Select to read this version.",
    })
    versions[index] = { frame=button, selected=selected, dot=dot,
        archiveArrow=archiveArrow, archived=archived,
        version=number, description=description, offset=railY }
    railY = railY + (archived and 47 or 67)
end
versionCanvas:SetHeight(math.max(1, railY + 9))

-- Scroll only the selected version content, not the version rail. Wide windows
-- cap the main content instead of stretching the hero or type; compact ones
-- keep a readable single-column layout.
local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -19, 18)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(700, 740)
scroll:SetScrollChild(canvas)
local bar = Widgets.ScrollBar(scroll, function()
    return scroll:GetHeight(), canvas:GetHeight(), scroll:GetVerticalScroll()
end, function(offset) scroll:SetVerticalScroll(offset) end)
local function Clamp()
    local limit = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(limit,
        scroll:GetVerticalScroll())))
    bar:Refresh()
end

local banner = CreateFrame("Frame", nil, canvas)
banner:SetPoint("TOPLEFT", canvas, "TOPLEFT", 1, -2)
banner:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -8, -2)
banner:SetHeight(141)
-- Single frame owner: the nine-slice skin paints the complete copper rim.
-- The approved bitmap contains partial, baked corner strokes that do not
-- follow the resized frame. Display ONLY its interior artwork, inset from
-- the true frame so neither corners nor edges are drawn twice.
Style.Skin(banner, C.nav, { corner=11, edge=C.goldDim,
    smooth=true, rim=0.95 })
local bannerArt = banner:CreateTexture(nil, "ARTWORK", nil, 1)
bannerArt:SetTexture(heroArtPath)
bannerArt:SetPoint("TOPLEFT", banner, "TOPLEFT", 10, -10)
bannerArt:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -10, 10)
-- The source's decorative rim/corner strokes are baked at the perimeter
-- (y=37..50, y=198..212, and near x=10/1013). The inner image contains
-- just the scene: let the nine-slice frame own EVERY corner and edge.
bannerArt:SetTexCoord(28 / 1024, 996 / 1024, 51 / 256, 197 / 256)
bannerArt:EnableMouse(false)
if Chrome.Sharp then Chrome.Sharp(bannerArt) end
-- Artwork hierarchy: one clean title line and a SINGLE metadata row with
-- a gold version badge. All content stays dynamic for future releases.
local bannerTitle = Style.Text(banner, "", 24, C.pale)
bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 246, -19)
bannerTitle:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -13, -19)
bannerTitle:SetHeight(50)
bannerTitle:SetJustifyV("TOP")
bannerTitle:SetWordWrap(false)
local versionBadge = CreateFrame("Frame", nil, banner)
versionBadge:SetSize(82, 27)
versionBadge:SetPoint("TOPLEFT", banner, "TOPLEFT", 246, -79)
Style.Skin(versionBadge, C.selected, { corner=8, edge=C.goldDim,
    shine=0.25, shade=0.12, rim=0.92 })
local bannerVersion = Style.Text(versionBadge, "", 14, C.pale)
bannerVersion:SetPoint("CENTER", versionBadge, "CENTER")
bannerVersion:SetJustifyH("CENTER")
bannerVersion:SetWordWrap(false)
local bannerDate = Style.Text(banner, "", 11, C.text)
bannerDate:SetPoint("LEFT", versionBadge, "RIGHT", 12, 0)
bannerDate:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
bannerDate:SetHeight(27)
bannerDate:SetWordWrap(false)

local summaryPanel = CreateFrame("Frame", nil, canvas)
summaryPanel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -154)
summaryPanel:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -154)
summaryPanel:SetHeight(64)
Style.Skin(summaryPanel, C.nav, { corner=10, edge=C.border,
    shine=0.13, shade=0.12, rim=0.80 })
local summaryIcon = TileIcon(summaryPanel, "scroll", 42)
summaryIcon:SetPoint("LEFT", summaryPanel, "LEFT", 16, 0)
local summaryHeading = Style.Text(summaryPanel, "Version Summary", 19, C.gold)
summaryHeading:SetPoint("LEFT", summaryPanel, "LEFT", 72, 0)
local summarySeparator = Style.Fill(summaryPanel, C.goldDim, "ARTWORK")
summarySeparator:ClearAllPoints()
summarySeparator:SetPoint("TOP", summaryPanel, "TOP", -26, -8)
summarySeparator:SetPoint("BOTTOM", summaryPanel, "BOTTOM", -26, 8)
summarySeparator:SetWidth(1)
summarySeparator:SetAlpha(0.60)
local summaryDescription = Style.Text(summaryPanel, "", 12, C.text)
summaryDescription:SetPoint("LEFT", summaryPanel, "LEFT", 300, 0)
summaryDescription:SetPoint("RIGHT", summaryPanel, "RIGHT", -17, 0)
summaryDescription:SetHeight(48)
summaryDescription:SetWordWrap(true)

local changesTitle = Style.Text(canvas, "WHAT CHANGED", 13, C.gold)
changesTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 7, -232)
local changesRule = Style.Fill(canvas, C.goldDim, "ARTWORK")
changesRule:ClearAllPoints()
changesRule:SetPoint("LEFT", changesTitle, "RIGHT", 12, 0)
changesRule:SetPoint("RIGHT", canvas, "RIGHT", -13, 0)
changesRule:SetHeight(1)
changesRule:SetAlpha(0.70)

local rows = {}
local maxEntries = 0
for _, release in ipairs(releases) do
    maxEntries = math.max(maxEntries, #(release.entries or {}))
end
local function NewRow(index)
    local row = CreateFrame("Button", nil, canvas)
    row:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -258 - (index - 1) * 80)
    row:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -258 - (index - 1) * 80)
    row:SetHeight(72)
    row:RegisterForClicks("LeftButtonUp")
    Style.Skin(row, C.nav, { corner=10, edge=C.border,
        shine=0.15, shade=0.15, rim=0.76 })
    local accent = Style.Fill(row, C.red, "ARTWORK")
    accent:ClearAllPoints()
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -5)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 5)
    accent:SetWidth(4)
    local hover = Style.FeedbackOverlay(row, {
        corner=10, inset=2, fill=C.gold, edge=C.goldDim,
        shine=0.26, rim=0.55,
    })
    local tile = CreateFrame("Frame", nil, row)
    tile:SetSize(53, 53)
    tile:SetPoint("LEFT", row, "LEFT", 21, 0)
    Style.Skin(tile, C.window, { corner=9, edge=C.goldDim,
        shine=0.19, rim=0.82 })
    local icon = TileIcon(tile, "scroll", 47)
    icon:SetPoint("CENTER", tile, "CENTER")
    local category = Style.Text(row, "", 10, C.gold)
    category:SetPoint("TOPLEFT", row, "TOPLEFT", 91, -7)
    local title = Style.Text(row, "", 16, C.pale)
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 91, -23)
    title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -23)
    title:SetHeight(23)
    title:SetWordWrap(false)
    local description = Style.Text(row, "", 11, C.muted)
    description:SetPoint("TOPLEFT", row, "TOPLEFT", 91, -49)
    description:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -49)
    description:SetHeight(18)
    description:SetWordWrap(false)
    local action = Style.Text(row, "View setting  >", 11, C.gold)
    action:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    action:SetJustifyH("RIGHT")
    row:SetScript("OnClick", function(self)
        if not self.target then return end
        local item = Search.entries[self.target]
        if item then Search.Open(item) end
    end)
    row:SetScript("OnEnter", function(self)
        if self.target then Motion.Fade(hover, 0.19, 0.12) end
    end)
    row:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.17) end)
    Widgets.PressFeedback(row, hover)
    ns.Tooltips.Bind(row, function()
        return row.target and {
            title="View related setting",
            detail="Jump to this setting and briefly highlight it.",
        }
    end)
    return { frame=row, art=icon, category=category,
        title=title, description=description, action=action, hover=hover }
end
for i=1,maxEntries do rows[i] = NewRow(i) end

-- Two useful, genuinely data-driven bottom panels replace redundant links
-- and hard-coded imaginary release achievements from the artwork artwork.
local highlights = CreateFrame("Frame", nil, canvas)
Style.Skin(highlights, C.nav, { corner=10, edge=C.goldDim,
    shine=0.11, shade=0.11, rim=0.78 })
-- The artwork uses one restrained gold jewel for Highlights, not
-- another crossed-swords badge competing with the main Duel Hall identity.
local highlightsIcon = highlights:CreateTexture(nil, "ARTWORK")
highlightsIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCornerJewel.tga")
highlightsIcon:SetSize(32, 32)
highlightsIcon:SetPoint("TOPLEFT", highlights, "TOPLEFT", 11, -6)
local highlightsTitle = Style.Text(highlights, "Highlights", 18, C.pale)
highlightsTitle:SetPoint("TOPLEFT", highlights, "TOPLEFT", 44, -8)
local highlightLines = {}
for i=1,3 do
    local bullet = Style.Fill(highlights, C.gold, "ARTWORK")
    bullet:ClearAllPoints()
    bullet:SetPoint("TOPLEFT", highlights, "TOPLEFT", 53, -44 - (i-1)*19)
    bullet:SetSize(5, 5)
    local label = Style.Text(highlights, "", 11, C.text)
    label:SetPoint("TOPLEFT", highlights, "TOPLEFT", 65, -38 - (i-1)*19)
    label:SetPoint("TOPRIGHT", highlights, "TOPRIGHT", -10, -38 - (i-1)*19)
    label:SetWordWrap(false)
    highlightLines[i] = label
end
local related = CreateFrame("Frame", nil, canvas)
Style.Skin(related, C.nav, { corner=10, edge=C.goldDim,
    shine=0.11, shade=0.11, rim=0.78 })
local relatedIcon = TileIcon(related, "gear", 35)
relatedIcon:SetPoint("TOPLEFT", related, "TOPLEFT", 11, -9)
local relatedTitle = Style.Text(related, "Related Settings", 18, C.pale)
relatedTitle:SetPoint("TOPLEFT", related, "TOPLEFT", 47, -8)
local relatedHint = Style.Text(related, "", 11, C.text)
relatedHint:SetPoint("TOPLEFT", related, "TOPLEFT", 47, -37)
relatedHint:SetPoint("TOPRIGHT", related, "TOPRIGHT", -11, -37)
relatedHint:SetHeight(25)
relatedHint:SetWordWrap(true)
-- Dark gold-lined secondary action as pictured in the approved artwork.
-- Keep Style.Action as the single owner of hover, press and click behavior.
local relatedButton = Style.Action(related, "View Settings", "patchnotes", {
    fill=C.nav, edge=C.goldDim, light=C.gold, dark=C.border,
    hover=C.gold, text=C.pale,
})
relatedButton:SetSize(137, 28)
relatedButton:SetPoint("BOTTOMRIGHT", related, "BOTTOMRIGHT", -12, 9)
relatedButton:SetScript("OnClick", function()
    if PatchNotes.relatedTarget then
        local entry = Search.entries[PatchNotes.relatedTarget]
        if entry then Search.Open(entry) end
    end
end)
ns.Tooltips.Bind(relatedButton, {
    title="Related setting", detail="Open a setting mentioned in this update.",
})
local legal = Style.Text(canvas,
    "Demo content only — not an actual changelog or released addon version.",
    11, C.muted)
legal:SetJustifyH("CENTER")

local selectedIndex = 1
local activeRelease = releases[1]
local function Layout()
    local width = math.max(1, math.min(970, scroll:GetWidth() - 16))
    canvas:SetWidth(width)
    -- On minimum window width, a narrow summary places its description below
    -- the label. On larger widths, keep the exact artwork's single-row summary.
    local compact = width < 620
    -- A shorter window uses the artwork's proportions at reduced vertical
    -- density instead of hiding Highlights and Related Settings below the
    -- footer. Wider/taller windows retain their spacious presentation.
    local dense = scroll:GetHeight() < 590
    -- Derive each section from the previous block's measured bottom.
    -- Compact windows require a taller banner for a wrapped release title,
    -- and a taller summary for two lines of readable description.
    local bannerHeight = compact and 153 or (dense and 120 or 141)
    local summaryY = bannerHeight + 13
    local summaryH = compact and (dense and 81 or 84) or (dense and 54 or 64)
    local titleY = summaryY + summaryH + (dense and 11 or 14)
    local rowsY = titleY + (dense and 23 or 26)
    local rowStep = dense and 65 or 80
    local rowHeight = dense and 61 or 72
    banner:SetHeight(bannerHeight)
    summaryPanel:ClearAllPoints()
    summaryPanel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -summaryY)
    summaryPanel:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -summaryY)
    summaryPanel:SetHeight(summaryH)
    changesTitle:ClearAllPoints()
    changesTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 7, -titleY)
    -- Shorten only the decorative metadata on compact windows; the release
    -- itself and its demo status are never changed or silently hidden.
    bannerTitle:ClearAllPoints()
    bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT",
        compact and 188 or 246, compact and -14 or -19)
    bannerTitle:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -13,
        compact and -14 or -19)
    bannerTitle:SetWordWrap(compact)
    bannerTitle:SetHeight(compact and 75 or 50)
    versionBadge:ClearAllPoints()
    versionBadge:SetPoint("TOPLEFT", banner, "TOPLEFT",
        compact and 188 or 246, compact and -107 or -79)
    local date = activeRelease and activeRelease.date or "Date not set"
    local demo = not activeRelease or activeRelease.demo ~= false
    local kind = demo and "DEMO NOTES" or "RELEASE NOTES"
    bannerDate:SetText(compact and (date .. "  •  " .. kind) or
        (date .. "  •  " .. kind ..
            (demo and "  •  Fictional test update" or "")))
    if compact then
        summarySeparator:Hide()
        summaryDescription:ClearAllPoints()
        summaryDescription:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", 73, -30)
        summaryDescription:SetPoint("TOPRIGHT", summaryPanel, "TOPRIGHT", -12, -30)
        summaryDescription:SetHeight(42)
    else
        summarySeparator:Show()
        summaryDescription:ClearAllPoints()
        summaryDescription:SetPoint("LEFT", summaryPanel, "LEFT", 300, 0)
        summaryDescription:SetPoint("RIGHT", summaryPanel, "RIGHT", -17, 0)
        summaryDescription:SetHeight(48)
    end
    local count = activeRelease and #(activeRelease.entries or {}) or 0
    for i, item in ipairs(rows) do
        local frame = item.frame
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2,
            -rowsY - (i-1) * rowStep)
        frame:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9,
            -rowsY - (i-1) * rowStep)
        frame:SetHeight(rowHeight)
        item.title:ClearAllPoints()
        item.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 91,
            dense and -21 or -23)
        item.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT",
            frame.target and -117 or -12, dense and -21 or -23)
        item.title:SetHeight(dense and 20 or 23)
        item.description:ClearAllPoints()
        item.description:SetPoint("TOPLEFT", frame, "TOPLEFT", 91,
            dense and -43 or -49)
        item.description:SetPoint("TOPRIGHT", frame, "TOPRIGHT",
            frame.target and -117 or -12, dense and -43 or -49)
        item.description:SetHeight(dense and 16 or 18)
    end
    local y = rowsY + count * rowStep + (dense and 5 or 12)
    local bottomHeight = dense and 100 or 114
    highlights:ClearAllPoints()
    related:ClearAllPoints()
    if compact then
        highlights:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -y)
        highlights:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -y)
        highlights:SetHeight(bottomHeight)
        related:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -(y + bottomHeight + 10))
        related:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -(y + bottomHeight + 10))
        related:SetHeight(bottomHeight)
        y = y + 2 * bottomHeight + 20
    else
        highlights:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -y)
        highlights:SetPoint("TOPRIGHT", canvas, "TOP", -6, -y)
        related:SetPoint("TOPLEFT", canvas, "TOP", 6, -y)
        related:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -y)
        highlights:SetHeight(bottomHeight)
        related:SetHeight(bottomHeight)
        y = y + bottomHeight + 10
    end
    legal:ClearAllPoints()
    legal:SetPoint("TOP", canvas, "TOP", 0, -(y + 5))
    canvas:SetHeight(y + (dense and 27 or 40))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    Clamp()
end
scroll:SetScript("OnSizeChanged", Layout)
scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local limit = math.max(0, canvas:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0,
        math.min(limit, self:GetVerticalScroll() - delta * 48)))
    bar:Refresh()
end)
scroll:HookScript("OnShow", Layout)

-- One centered width cap for the entire version rail + notes composition.
-- Resize only on frame size changes; the global resizer remains Window-owned.
local function LayoutWorkspace()
    local total = math.max(1, root:GetWidth())
    local usable = math.min(1190, math.max(1, total - 40))
    local inset = math.max(20, (total - usable) / 2)
    rail:ClearAllPoints()
    rail:SetPoint("TOPLEFT", root, "TOPLEFT", inset, -88)
    rail:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", inset, 18)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)
    scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -inset, 18)
    Layout()
end
root:HookScript("OnSizeChanged", LayoutWorkspace)
root:HookScript("OnShow", LayoutWorkspace)

local function Populate(release, index)
    activeRelease, selectedIndex = release, index
    bannerTitle:SetText(release.title or release.version or "Patch Notes")
    bannerVersion:SetText(release.version or "")
    summaryDescription:SetText(release.overview or release.summary or "")
    subheading:SetText("A more polished home for Duels updates.")

    for i, item in ipairs(versions) do
        local current = i == index
        item.selected:SetAlpha(current and 1 or 0)
        item.dot:SetShown(not current and not item.archived)
        item.archiveArrow:SetShown(item.archived and not current)
        item.version:SetTextColor(unpack(current and C.tabText or C.pale))
    end
    for i, row in ipairs(rows) do
        local entry = release.entries and release.entries[i]
        row.frame:SetShown(entry ~= nil)
        if entry then
            row.art:SetSymbol(entry.symbol)
            row.category:SetText(entry.category or "UPDATE")
            row.title:SetText(entry.title or "")
            row.description:SetText(entry.description or "")
            local linked = entry.target and Search.entries[entry.target] ~= nil
            row.frame.target = linked and entry.target or nil
            row.frame:EnableMouse(linked == true)
            row.action:SetShown(linked == true)
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 91, -23)
            row.title:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT",
                linked and -117 or -12, -23)
            row.description:ClearAllPoints()
            row.description:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 91, -49)
            row.description:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT",
                linked and -117 or -12, -49)
            Motion.Stop(row.hover, 0)
        end
    end
    local highlightSource = release.highlights
    for i, label in ipairs(highlightLines) do
        local value = highlightSource and highlightSource[i]
        if not value and release.entries and release.entries[i] then
            value = release.entries[i].title
        end
        label:SetShown(value ~= nil)
        label:SetText(value or "")
    end
    PatchNotes.relatedTarget = nil
    for _, entry in ipairs(release.entries or {}) do
        if entry.target and Search.entries[entry.target] then
            PatchNotes.relatedTarget = entry.target
            break
        end
    end
    local hasSetting = PatchNotes.relatedTarget ~= nil
    relatedHint:SetText(hasSetting and "Configure an option mentioned in this update."
        or "No directly linked settings in this update.")
    relatedButton:SetShown(hasSetting)
    Layout()
end

function PatchNotes.RefreshReminder()
    local latest = releases[1]
    local unread = latest and Settings.Get("patchNotesReminder") and
        Settings.GetPatchNotesSeenId() ~= latest.id or false
    if ns.Navigation and ns.Navigation.SetPatchUnread then
        ns.Navigation.SetPatchUnread(unread)
    end
    if ns.AccessIcons and ns.AccessIcons.NotifyPatchNotes then
        ns.AccessIcons.NotifyPatchNotes(unread)
    end
end
function PatchNotes.GetPageScroll(pageKey)
    if not byKey[pageKey] then return 0 end
    return scroll:GetVerticalScroll()
end
function PatchNotes.SetPageScroll(pageKey, offset)
    if not byKey[pageKey] or type(offset) ~= "number" then return end
    local limit = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(limit, offset)))
    bar:Refresh()
end
function PatchNotes.Show(pageKey)
    local item = byKey[pageKey]
    root:SetShown(item ~= nil)
    if not item then return end
    Populate(item.data, item.index)
    scroll:SetVerticalScroll(0)
    -- Left-hand version list scrolls to keep the selection visible.
    local row = versions[item.index]
    if row then
        -- Use the row's actual Y: archived versions include a divider and
        -- cannot be found reliably by multiplying the normal row height.
        local top = math.max(0, row.offset - versionScroll:GetHeight() / 3)
        versionScroll:SetVerticalScroll(math.min(
            math.max(0, versionCanvas:GetHeight() - versionScroll:GetHeight()), top))
    end
    ClampVersions()
    if item.index == 1 then
        Settings.MarkPatchNotesSeen(item.data.id)
    end
    PatchNotes.RefreshReminder()
    Motion.Stop(canvas, 0.68)
    Motion.Fade(canvas, 1, Motion.Duration("gentle"))
end
root:HookScript("OnHide", function() Motion.Stop(canvas, 1) end)
PatchNotes.RefreshReminder()
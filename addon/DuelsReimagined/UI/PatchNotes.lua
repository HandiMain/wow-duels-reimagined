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

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
local atlas = art .. "PatchNotesAtlas.tga"
local heroArtPath = art .. "PatchNotesHeroApproved.png"

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

-- The original top-level horizontal tabs remain registered for Search and
-- Back, but this page owns their ONLY visible representation: a vertical,
-- independently scrollable version list that grows with the data table.
local rail = CreateFrame("Frame", nil, root)
rail:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -88)
rail:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 20, 18)
rail:SetWidth(194)
Style.Skin(rail, C.window, { corner=11, edge=C.goldDim,
    smooth=true, rim=0.96 })
local versionsTitle = Style.Text(rail, "Versions", 20, C.pale, nil, "display")
versionsTitle:SetPoint("TOP", rail, "TOP", 0, -8)
versionsTitle:SetJustifyH("CENTER")
local railDivider = Chrome.Divider(rail, 154, 12)
railDivider:SetPoint("TOP", versionsTitle, "BOTTOM", 0, -3)

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
    if index == 4 then
        local archiveLine = Chrome.Divider(versionCanvas, 132, 11)
        archiveLine:SetPoint("TOP", versionCanvas, "TOP", 0, -railY - 3)
        railY = railY + 18
        local archiveLabel = Style.Text(versionCanvas, "EARLIER UPDATES", 10, C.gold)
        archiveLabel:SetPoint("TOP", versionCanvas, "TOP", 0, -railY)
        archiveLabel:SetJustifyH("CENTER")
        railY = railY + 23
    end
    local button = CreateFrame("Button", nil, versionCanvas)
    button:SetPoint("TOPLEFT", versionCanvas, "TOPLEFT", 2, -railY)
    button:SetPoint("TOPRIGHT", versionCanvas, "TOPRIGHT", -2, -railY)
    button:SetHeight(58)
    button:RegisterForClicks("LeftButtonUp")
    Style.Skin(button, C.nav, { corner=9, edge=C.border,
        shine=0.17, shade=0.13, rim=0.72 })
    local selected = Style.Skin(button, C.selected, { corner=9,
        edge=C.gold, shine=0.54, shade=0.19, rim=0.95, alpha=0 })
    local hover = Style.FeedbackOverlay(button, {
        corner=9, inset=2, fill=C.gold, edge=C.goldDim,
        shine=0.32, rim=0.60,
    })
    local dot = CreateFrame("Frame", nil, button)
    dot:SetSize(13, 13)
    dot:SetPoint("LEFT", button, "LEFT", 11, 0)
    Style.Skin(dot, C.nav, { corner=6, edge=C.goldDim, rim=0.86 })
    local dotCenter = Style.Fill(dot, C.gold, "ARTWORK")
    dotCenter:ClearAllPoints()
    dotCenter:SetPoint("CENTER", dot, "CENTER", 0, 0)
    dotCenter:SetSize(5, 5)
    dotCenter:Hide()
    dot.inner = dotCenter
    local number = Style.Text(button, release.version or "?", 17, C.pale)
    number:SetPoint("TOPLEFT", button, "TOPLEFT", 35, -8)
    number:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -8)
    number:SetWordWrap(false)
    local description = Style.Text(button, release.navTitle or "Update", 11, C.muted)
    description:SetPoint("TOPLEFT", button, "TOPLEFT", 35, -33)
    description:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -33)
    description:SetWordWrap(false)
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
        version=number, description=description }
    railY = railY + 67
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
Style.Skin(banner, C.nav, { corner=11, edge=C.goldDim,
    smooth=true, rim=0.95 })
local bannerArt = banner:CreateTexture(nil, "ARTWORK", nil, 1)
bannerArt:SetTexture(heroArtPath)
bannerArt:SetAllPoints(banner)
bannerArt:SetTexCoord(0, 1, 37 / 256, 212 / 256)
bannerArt:EnableMouse(false)
if Chrome.Sharp then Chrome.Sharp(bannerArt) end
local bannerTitle = Style.Text(banner, "", 22, C.pale, nil, "display")
bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 202, -18)
bannerTitle:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -12, -18)
bannerTitle:SetHeight(62)
bannerTitle:SetJustifyV("TOP")
bannerTitle:SetWordWrap(true)
local bannerVersion = Style.Text(banner, "", 12, C.gold)
bannerVersion:SetPoint("TOPLEFT", banner, "TOPLEFT", 202, -94)
bannerVersion:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
bannerVersion:SetWordWrap(false)
local bannerDate = Style.Text(banner, "", 11, C.text)
bannerDate:SetPoint("TOPLEFT", banner, "TOPLEFT", 202, -116)
bannerDate:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
bannerDate:SetWordWrap(false)

local summaryPanel = CreateFrame("Frame", nil, canvas)
summaryPanel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -154)
summaryPanel:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -154)
summaryPanel:SetHeight(64)
Style.Skin(summaryPanel, C.nav, { corner=10, edge=C.border,
    shine=0.13, shade=0.12, rim=0.80 })
local summaryIcon = TileIcon(summaryPanel, "scroll", 42)
summaryIcon:SetPoint("LEFT", summaryPanel, "LEFT", 16, 0)
local summaryHeading = Style.Text(summaryPanel, "Version Summary", 19, C.gold, nil, "display")
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
-- and hard-coded imaginary release achievements from the concept artwork.
local highlights = CreateFrame("Frame", nil, canvas)
Style.Skin(highlights, C.nav, { corner=10, edge=C.goldDim,
    shine=0.11, shade=0.11, rim=0.78 })
local highlightsIcon = TileIcon(highlights, "swords", 29)
highlightsIcon:SetPoint("TOPLEFT", highlights, "TOPLEFT", 10, -7)
local highlightsTitle = Style.Text(highlights, "Highlights", 18, C.pale, nil, "display")
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
local relatedTitle = Style.Text(related, "Related Settings", 18, C.pale, nil, "display")
relatedTitle:SetPoint("TOPLEFT", related, "TOPLEFT", 47, -8)
local relatedHint = Style.Text(related, "", 11, C.text)
relatedHint:SetPoint("TOPLEFT", related, "TOPLEFT", 47, -37)
relatedHint:SetPoint("TOPRIGHT", related, "TOPRIGHT", -11, -37)
relatedHint:SetHeight(25)
relatedHint:SetWordWrap(true)
local relatedButton = Style.Action(related, "View Settings", "footer")
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
    -- the label. On larger widths, keep the exact concept's single-row summary.
    local compact = width < 620
    if compact then
        summarySeparator:Hide()
        summaryDescription:ClearAllPoints()
        summaryDescription:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", 73, -31)
        summaryDescription:SetPoint("RIGHT", summaryPanel, "RIGHT", -12, 0)
        summaryDescription:SetHeight(30)
    else
        summarySeparator:Show()
        summaryDescription:ClearAllPoints()
        summaryDescription:SetPoint("LEFT", summaryPanel, "LEFT", 300, 0)
        summaryDescription:SetPoint("RIGHT", summaryPanel, "RIGHT", -17, 0)
        summaryDescription:SetHeight(48)
    end
    local count = activeRelease and #(activeRelease.entries or {}) or 0
    local y = 258 + count * 80 + 12
    highlights:ClearAllPoints()
    related:ClearAllPoints()
    if compact then
        highlights:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -y)
        highlights:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -y)
        highlights:SetHeight(114)
        related:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -(y + 124))
        related:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -(y + 124))
        related:SetHeight(114)
        y = y + 248
    else
        highlights:SetPoint("TOPLEFT", canvas, "TOPLEFT", 2, -y)
        highlights:SetPoint("TOPRIGHT", canvas, "TOP", -6, -y)
        related:SetPoint("TOPLEFT", canvas, "TOP", 6, -y)
        related:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -9, -y)
        highlights:SetHeight(114)
        related:SetHeight(114)
        y = y + 124
    end
    legal:ClearAllPoints()
    legal:SetPoint("TOP", canvas, "TOP", 0, -(y + 5))
    canvas:SetHeight(y + 40)
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

local function Populate(release, index)
    activeRelease, selectedIndex = release, index
    bannerTitle:SetText(release.title or release.version or "Patch Notes")
    bannerVersion:SetText((release.version or "") ..
        (release.demo == false and "   •   RELEASE NOTES" or "   •   DEMO NOTES"))
    bannerDate:SetText((release.date or "Date not set") ..
        (release.demo == false and "" or "   •   Fictional test update"))
    summaryDescription:SetText(release.overview or release.summary or "")
    subheading:SetText("A more polished home for Duels updates.")

    for i, item in ipairs(versions) do
        local current = i == index
        item.selected:SetAlpha(current and 1 or 0)
        item.dot.inner:SetShown(current)
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
        local top = math.max(0, (item.index - 1) * 67 - versionScroll:GetHeight() / 3)
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
local _, ns = ...
local Style, Chrome, Widgets = ns.Style, ns.Chrome, ns.Widgets
local Motion, Search, Settings = ns.Motion, ns.Search, ns.Settings
local C, Window = Style.color, ns.Window

-- Presentation only: no version bump, no release, no gameplay claims.
-- Navigation and this page consume the same author-reviewed data table.
local releases = ns.PatchNotesData or {}
local byKey = {}
for index, release in ipairs(releases) do
    byKey[release.key] = { index = index, data = release }
end
local PatchNotes = {}
ns.PatchNotes = PatchNotes

local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\"
local atlas = art .. "PatchNotesAtlas.tga"
local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:Hide()

local heading = Style.Text(root, "Patch Notes", 23, C.pale)
heading:SetPoint("TOP", root, "TOP", 0, -17)
local titleRule = Chrome.Divider(root, 300, 12)
titleRule:SetPoint("TOP", heading, "BOTTOM", 0, -3)
local subtitle = Style.Text(root, "What's new in Duels Reimagined", 12, C.muted)
subtitle:SetPoint("TOP", titleRule, "BOTTOM", 0, -4)
local hint = Style.Text(root,
    "Select a highlighted entry to jump directly to its setting.", 11, C.muted
hint:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
hint:SetJustifyH("CENTER")

local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 22, -113)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -22, 16)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(760, 545)
scroll:SetScrollChild(canvas)
local bar = Widgets.ScrollBar(scroll, function()
    return scroll:GetHeight(), canvas:GetHeight(), scroll:GetVerticalScroll()
end, function(offset) scroll:SetVerticalScroll(offset) end)

local function Clamp()
    local limit = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,
        math.min(limit, scroll:GetVerticalScroll())))
    bar:Refresh()
end
local function Fit()
    canvas:SetWidth(math.max(1, scroll:GetWidth() - 16))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    Clamp()
end
scroll:SetScript("OnSizeChanged", Fit)
scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local limit = math.max(0, canvas:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0,
        math.min(limit, self:GetVerticalScroll() - delta * 46)))
    bar:Refresh()
end)
scroll:HookScript("OnShow", Fit)

local function TileIcon(parent, symbol, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    tex:SetTexture(atlas)
    tex:SetPoint("CENTER", parent, "CENTER")
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

-- Hero art is its own authored texture. Text is a real font string to preserve
-- scaling, font matching, search safety and accessibility.
local banner = CreateFrame("Frame", nil, canvas)
banner:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -3)
banner:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -18, -3)
banner:SetHeight(118)
Style.Skin(banner, C.nav, { corner=11, edge=C.border, shine=0.36, shade=0.28 })
local bannerAccent = Style.Fill(banner, C.red, "ARTWORK")
bannerAccent:ClearAllPoints()
bannerAccent:SetPoint("TOPLEFT", banner, "TOPLEFT", 4, -4)
bannerAccent:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 4, 4)
bannerAccent:SetWidth(4)
local bannerLine = Style.Fill(banner, C.gold, "ARTWORK")
bannerLine:ClearAllPoints()
bannerLine:SetPoint("TOPLEFT", banner, "TOPLEFT", 13, -7)
bannerLine:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -13, -7)
bannerLine:SetHeight(1)
bannerLine:SetAlpha(0.56)

local bannerTitle = Style.Text(banner, "", 22, C.pale)
bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 25, -23)
bannerTitle:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -25, -23)
bannerTitle:SetHeight(32)
bannerTitle:SetJustifyH("CENTER")
bannerTitle:SetWordWrap(true)
local bannerVersion = Style.Text(banner, "", 12, C.gold)
bannerVersion:SetPoint("TOP", bannerTitle, "BOTTOM", 0, -4)
bannerVersion:SetJustifyH("CENTER")
local bannerDate = Style.Text(banner, "", 12, C.muted)
bannerDate:SetPoint("TOP", bannerVersion, "BOTTOM", 0, -4)
bannerDate:SetJustifyH("CENTER")

local changesTitle = Style.Text(canvas, "WHAT CHANGED", 12, C.gold)
changesTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 5, -143)
local changesRule = Style.Rule(canvas, "TOPLEFT", canvas, "TOPLEFT",
    1, 1, C.goldDim)
changesRule:ClearAllPoints()
changesRule:SetPoint("LEFT", changesTitle, "RIGHT", 17, 0)
changesRule:SetPoint("RIGHT", canvas, "RIGHT", -27, 0)

local rows = {}
local maxEntries = 0
for _, release in ipairs(releases) do
    maxEntries = math.max(maxEntries, #release.entries)
end

local function NewRow(index)
    local row = CreateFrame("Button", nil, canvas)
    row:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -164 - (index - 1) * 90)
    row:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -18, -164 - (index - 1) * 90)
    row:SetHeight(82)
    Style.Skin(row, C.nav, { corner=11, edge=C.border, shine=0.26, shade=0.25 })
    local accent = Style.Fill(row, C.red, "ARTWORK")
    accent:ClearAllPoints()
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -5)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 5)
    accent:SetWidth(3)
    local hover = Style.Skin(row, C.hover, { corner=11, edge=C.goldDim,
        shine=0.21, shade=0.13, alpha=0 })

    local tile = CreateFrame("Frame", nil, row)
    tile:SetSize(52, 52)
    tile:SetPoint("LEFT", row, "LEFT", 17, 0)
    Style.Skin(tile, C.window, { corner=9, edge=C.goldDim, shine=0.24 })
    local artIcon = TileIcon(tile, "scroll", 50)
    local category = Style.Text(row, "", 10, C.gold)
    category:SetPoint("TOPLEFT", row, "TOPLEFT", 83, -9)
    local title = Style.Text(row, "", 16, C.pale)
    title:SetPoint("TOPLEFT", category, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -118, -23)
    title:SetHeight(22)
    title:SetWordWrap(false)
    local description = Style.Text(row, "", 12, C.muted)
    description:SetPoint("TOPLEFT", row, "TOPLEFT", 83, -48)
    description:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -118, 6)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    local action = Style.Text(row, "View setting  >", 12, C.gold)
    action:SetPoint("RIGHT", row, "RIGHT", -16, 0)
    action:SetJustifyH("RIGHT")

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if not self.target then return end
        local item = Search.entries[self.target]
        if item then Search.Open(item) end
    end)
    row:SetScript("OnEnter", function(self)
        if self.target then Motion.Fade(hover, 0.16, 0.12) end
    end)
    row:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.17) end)
    Widgets.PressFeedback(row, hover)
    ns.Tooltips.Bind(row, function()
        return row.target and {
            title = "View related setting",
            detail = "Jump to this option and briefly highlight it.",
        }
    end)
    return { frame = row, art = artIcon, category = category,
        title = title, description = description, action = action,
        hover = hover }
end
for i = 1, maxEntries do rows[i] = NewRow(i) end

local olderTitle = Style.Text(canvas, "OLDER UPDATES", 13, C.gold)
olderTitle:SetJustifyH("CENTER")
local olderButton = Style.Action(canvas, "View previous version")
olderButton:SetSize(210, 30)
olderButton:SetScript("OnClick", function()
    if PatchNotes.nextRelease and ns.Navigation then
        ns.Navigation.SelectKey("patchnotes", PatchNotes.nextRelease.key)
    end
end)
ns.Tooltips.Bind(olderButton, function()
    return PatchNotes.nextRelease and {
        title = "Previous version",
        detail = "Open the demo notes for " .. PatchNotes.nextRelease.version .. ".",
    }
end)
local endOfHistory = Style.Text(canvas, "END OF DEMO HISTORY", 13, C.muted)
endOfHistory:SetJustifyH("CENTER")
local legal = Style.Text(canvas,
    "Demo content only — not an actual changelog or released addon version.",
    12, C.muted)
legal:SetJustifyH("CENTER")

local function RepositionFooter(count)
    local y = 164 + count * 90 + 11
    olderTitle:ClearAllPoints()
    olderTitle:SetPoint("TOP", canvas, "TOP", 0, -y)
    olderButton:ClearAllPoints()
    olderButton:SetPoint("TOP", canvas, "TOP", 0, -(y + 28))
    endOfHistory:ClearAllPoints()
    endOfHistory:SetPoint("TOP", canvas, "TOP", 0, -(y + 35))
    legal:ClearAllPoints()
    legal:SetPoint("TOP", canvas, "TOP", 0, -(y + 71))
    canvas:SetHeight(y + 110)
    Clamp()
end

local function Populate(release, index)
    bannerTitle:SetText(release.title or release.version)
    bannerVersion:SetText((release.version or "") .. "    •    DEMO NOTES")
    bannerDate:SetText((release.date or "") .. "    •    Fictional test update")
    subtitle:SetText(release.summary or "What's new in Duels Reimagined")
    for i, row in ipairs(rows) do
        local entry = release.entries[i]
        row.frame:SetShown(entry ~= nil)
        if entry then
            row.art:SetSymbol(entry.symbol)
            row.category:SetText(entry.category or "UPDATE")
            row.title:SetText(entry.title or "")
            row.description:SetText(entry.description or "")
            -- Only real, registered destinations are actionable; empty rows
            -- cannot glow or masquerade as a link.
            local linked = entry.target and Search.entries[entry.target] ~= nil
            row.frame.target = linked and entry.target or nil
            row.frame:EnableMouse(linked == true)
            row.action:SetShown(linked == true)
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", row.category, "BOTTOMLEFT", 0, -2)
            row.title:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT",
                linked and -118 or -20, -23)
            row.description:ClearAllPoints()
            row.description:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 83, -48)
            row.description:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT",
                linked and -118 or -20, 6)
            Motion.Stop(row.hover, 0)
        end
    end
    PatchNotes.nextRelease = releases[index + 1]
    olderTitle:SetShown(PatchNotes.nextRelease ~= nil)
    olderButton:SetShown(PatchNotes.nextRelease ~= nil)
    endOfHistory:SetShown(PatchNotes.nextRelease == nil)
    RepositionFooter(#release.entries)
end

function PatchNotes.RefreshReminder()
    local latest = releases[1]
    local unread = latest and Settings.Get("patchNotesReminder") and
        Settings.GetPatchNotesSeenId() ~= latest.id or false
    if ns.Navigation and ns.Navigation.SetPatchUnread then
        ns.Navigation.SetPatchUnread(unread)
    end
end

function PatchNotes.Show(pageKey)
    local item = byKey[pageKey]
    root:SetShown(item ~= nil)
    if not item then return end
    heading:SetText("Patch Notes")
    Populate(item.data, item.index)
    scroll:SetVerticalScroll(0)
    Fit()
    -- Visiting an older version must not silently mark a newer one read.
    if item.index == 1 then
        Settings.MarkPatchNotesSeen(item.data.id)
    end
    PatchNotes.RefreshReminder()
    Motion.Stop(canvas, 0.68)
    Motion.Fade(canvas, 1, Motion.Duration("gentle"))
end

root:HookScript("OnHide", function() Motion.Stop(canvas, 1) end)
PatchNotes.RefreshReminder()

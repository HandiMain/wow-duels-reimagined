local _, ns = ...
local Window, Style = ns.Window, ns.Style
local Motion, Settings, Search = ns.Motion, ns.Settings, ns.Search
local C = Style.color
local frame, header = Window.frame, Window.header
local Header = {}
ns.Header = Header

local iconBase = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Header\\"
local manualPeek, moving, folded = false, false, false
local expandedHeight = frame:GetHeight()
local alphaWhilePeeking = 0.16

local function Tooltip(button, title, detail)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title, 1, 0.84, 0.57)
    if detail then GameTooltip:AddLine(detail, 0.82, 0.82, 0.82, true) end
    GameTooltip:Show()
end

local function HeaderButton(name, title, detail)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(24, 24)
    b:RegisterForClicks("LeftButtonUp")
    local hover = b:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints(b)
    hover:SetColorTexture(unpack(C.goldDim))
    hover:SetAlpha(0)
    local art = b:CreateTexture(nil, "ARTWORK")
    art:SetTexture(iconBase .. name .. ".png")
    art:SetSize(19, 19)
    art:SetPoint("CENTER")
    ns.Chrome.Sharp(art)
    b.art, b.hover = art, hover
    b:SetScript("OnEnter", function()
        Motion.Fade(hover, 0.24, 0.13)
        Tooltip(b, title, detail)
    end)
    b:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, 0.18)
        if GameTooltip and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
    end)
    return b
end

local function RefreshFade()
    if not frame:IsShown() then return end
    local faded = manualPeek or (moving and Settings.Get("autoPeekMoving"))
    Motion.Fade(frame, faded and alphaWhilePeeking or 1, 0.17)
end

function Header.SetManualPeek(on)
    manualPeek = on and true or false
    RefreshFade()
end

local movement = CreateFrame("Frame")
movement:SetScript("OnEvent", function(_, event)
    moving = event == "PLAYER_STARTED_MOVING"
    RefreshFade()
end)

function Header.RefreshAutoPeek()
    movement:UnregisterEvent("PLAYER_STARTED_MOVING")
    movement:UnregisterEvent("PLAYER_STOPPED_MOVING")
    if frame:IsShown() and Settings.Get("autoPeekMoving") then
        movement:RegisterEvent("PLAYER_STARTED_MOVING")
        movement:RegisterEvent("PLAYER_STOPPED_MOVING")
    else
        moving = false
    end
    RefreshFade()
end

local close = HeaderButton("Close", "Close", "Close Duels Reimagined.")
close:SetPoint("RIGHT", header, "RIGHT", -19, 0)
close:SetScript("OnClick", function() frame:Hide() end)

local foldButton = HeaderButton("FoldUp", "Fold window",
    "Collapse to the header without closing. Click again to unfold.")
local peekButton = HeaderButton("Eye", "Peek",
    "Hold to see what is behind the window.")
peekButton:SetPoint("RIGHT", foldButton, "LEFT", -3, 0)
peekButton:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then Header.SetManualPeek(true) end
end)
peekButton:SetScript("OnMouseUp", function()
    Header.SetManualPeek(false)
end)
peekButton:SetScript("OnHide", function() manualPeek = false end)

local function PaintFold()
    foldButton.art:SetTexture(iconBase .. (folded and "FoldDown" or "FoldUp") .. ".png")
end

function Header.IsFolded()
    return folded
end

function Header.Fold(value)
    local want = value and true or false
    if want == folded then return end
    if want then
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        expandedHeight = frame:GetHeight()
        folded = true
        Header.CloseSearch(true)
        Window.body:Hide()
        Window.footer:Hide()
        if Window.chromeSeams then Window.chromeSeams:Hide() end
        frame:SetHeight(header:GetHeight() + 20)
    else
        folded = false
        frame:SetHeight(expandedHeight)
        Window.body:Show()
        Window.footer:Show()
        if Window.chromeSeams then Window.chromeSeams:Show() end
    end
    PaintFold()
end

-- The standard window scale control may be used even while folded.
-- Keep its full-size target rather than losing that height on unfold.
function Header.AfterWindowResized()
    if folded then
        expandedHeight = frame:GetHeight()
        frame:SetHeight(header:GetHeight() + 20)
    end
end

foldButton:SetScript("OnClick", function() Header.Fold(not folded) end)
PaintFold()

-- Place compact header tools from the right edge inward. The search width
-- is independent of window scaling and does not overlap our unified logo.
Window.scalePercent:ClearAllPoints()
Window.scalePercent:SetPoint("RIGHT", close, "LEFT", -12, 0)
Window.scaleSlider:ClearAllPoints()
Window.scaleSlider:SetPoint("RIGHT", Window.scalePercent, "LEFT", -11, 0)
Window.scaleCaption:ClearAllPoints()
Window.scaleCaption:SetPoint("RIGHT", Window.scaleSlider, "LEFT", -9, 0)
foldButton:SetPoint("RIGHT", Window.scaleCaption, "LEFT", -12, 0)

local searchBox = CreateFrame("Frame", nil, header)
searchBox:SetSize(264, 29)
searchBox:SetPoint("RIGHT", peekButton, "LEFT", -15, 0)
Style.Fill(searchBox, C.nav)
Style.Border(searchBox, C.goldDim, 1)

local glass = searchBox:CreateTexture(nil, "ARTWORK")
glass:SetTexture(iconBase .. "Search.png")
glass:SetSize(17, 17)
glass:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
ns.Chrome.Sharp(glass)

local input = CreateFrame("EditBox", nil, searchBox)
input:SetAutoFocus(false)
input:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
input:SetTextColor(unpack(C.text))
input:SetHeight(25)
input:SetPoint("LEFT", searchBox, "LEFT", 31, 0)
input:SetPoint("RIGHT", searchBox, "RIGHT", -7, 0)
input:SetMaxLetters(80)
input:SetText("")
local hint = Style.Text(searchBox, "Search pages and settings...", 12, C.muted)
hint:SetPoint("LEFT", searchBox, "LEFT", 33, 0)
hint:EnableMouse(false)

local dropdown = CreateFrame("Frame", nil, frame)
dropdown:SetWidth(294)
dropdown:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -5)
dropdown:SetFrameLevel(frame:GetFrameLevel() + 30)
Style.Fill(dropdown, C.nav)
Style.Border(dropdown, C.goldDim, 1)
dropdown:EnableMouse(true)
dropdown:Hide()

local resultButtons, currentResults, picked = {}, {}, 1
for i = 1, 6 do
    local b = CreateFrame("Button", nil, dropdown)
    b:SetSize(278, 43)
    b:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, -8 - (i - 1) * 43)
    local hover = b:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints(b)
    hover:SetColorTexture(unpack(C.goldDim))
    hover:SetAlpha(0)
    local title = Style.Text(b, "", 13, C.text)
    title:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -5)
    local where = Style.Text(b, "", 11, C.muted)
    where:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    b:SetScript("OnEnter", function()
        picked = i
        Motion.Fade(hover, 0.30, 0.13)
    end)
    b:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.16) end)
    b:SetScript("OnClick", function()
        local match = currentResults[i]
        Header.CloseSearch(true)
        Search.Open(match)
    end)
    resultButtons[i] = { button = b, title = title, where = where, hover = hover }
end

local noMatch = Style.Text(dropdown, "No matching pages or settings", 12, C.muted)
noMatch:SetPoint("CENTER", dropdown, "CENTER")
noMatch:Hide()

local function Render(query)
    currentResults = Search.Query(query)
    picked = 1
    if query == "" or not frame:IsShown() or folded then
        dropdown:Hide()
        return
    end
    for i, row in ipairs(resultButtons) do
        local match = currentResults[i]
        row.button:SetShown(match ~= nil)
        if match then
            row.title:SetText(match.title)
            row.where:SetText(match.where)
        end
    end
    noMatch:SetShown(#currentResults == 0)
    dropdown:SetHeight(#currentResults == 0 and 44 or (16 + #currentResults * 43))
    dropdown:Show()
end

function Header.CloseSearch(clear)
    dropdown:Hide()
    input:ClearFocus()
    if clear then input:SetText("") end
end

input:SetScript("OnTextChanged", function(self)
    local query = self:GetText() or ""
    hint:SetShown(query == "")
    Render(query)
end)
input:SetScript("OnEditFocusGained", function(self)
    Render(self:GetText() or "")
end)
input:SetScript("OnEnterPressed", function()
    local match = currentResults[picked] or currentResults[1]
    Header.CloseSearch(true)
    Search.Open(match)
end)
input:SetScript("OnEscapePressed", function()
    Header.CloseSearch(true)
end)
input:SetScript("OnArrowPressed", function(_, key)
    if #currentResults == 0 then return end
    picked = math.max(1, math.min(#currentResults,
        picked + (key == "DOWN" and 1 or -1)))
    for i, row in ipairs(resultButtons) do
        Motion.Fade(row.hover, i == picked and 0.22 or 0, 0.10)
    end
end)
searchBox:EnableMouse(true)
searchBox:SetScript("OnMouseDown", function() input:SetFocus() end)

frame:HookScript("OnShow", Header.RefreshAutoPeek)
frame:HookScript("OnHide", function()
    Header.CloseSearch(true)
    manualPeek = false
    moving = false
    movement:UnregisterEvent("PLAYER_STARTED_MOVING")
    movement:UnregisterEvent("PLAYER_STOPPED_MOVING")
    Header.Fold(false)
    Motion.Stop(frame, 1)
end)

Search.Register("header:fold", "Fold window", "Header",
    "Collapse the window to its header; unfold it again", function()
        Header.Fold(not folded)
    end)
Search.Register("header:peek", "Peek behind the window", "Header",
    "Hold the eye button; automatic Peek while moving in Interface options",
    function()
        if ns.Navigation then ns.Navigation.SelectKey("options", "interface") end
    end)

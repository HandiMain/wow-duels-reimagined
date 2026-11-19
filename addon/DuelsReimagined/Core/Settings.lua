local addonName, ns = ...

-- Single owner for account-wide preferences. Read the SavedVariables global
-- on every access: WoW may replace its table after addon files have executed.
local Settings = {}
ns.Settings = Settings

Settings.MIN_SCALE = 0.65
Settings.MAX_SCALE = 1.20
Settings.SCALE_STEP = 0.05

-- Every persistent Options toggle belongs here, including future ones.
local boolDefaults = {
    matchColors = false,
    matchFont = false,
    autoPeekMoving = true,
    reduceMotion = false,
}

-- Future settings must opt in to reload tracking; none currently need it.
local reloadRequired, loadValues = {}, {}
local ReadDB

-- Ellesmere integration is an optional capability, not a fixed user default.
-- No saved override: follow availability. Explicit stored choices persist.
local function EllesmereReady()
    return ns.Theme and type(ns.Theme.IsAvailable) == "function"
        and ns.Theme.IsAvailable() or false
end

local function IsMatchPreference(key)
    return key == "matchColors" or key == "matchFont"
end

function Settings.GetDefault(key)
    if key == "menuScale" then return 1 end
    if key == "fontChoice" then return "default" end
    if key == "fontScale" then return 1 end
    if key == "fontOutline" then return "default" end
    if IsMatchPreference(key) then return EllesmereReady() end
    return boolDefaults[key]
end

function Settings.IsModified(key)
    local default = Settings.GetDefault(key)
    return default ~= nil and Settings.Get(key) ~= default
end

function Settings.Reset(key)
    if IsMatchPreference(key) then
        -- Reset means AUTO: remove the override rather than saving whatever
        -- the third-party addon happens to report in this session.
        local db = ReadDB()
        if db and db[key] ~= nil then
            db[key] = nil
            if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
        end
        return
    end
    local default = Settings.GetDefault(key)
    if default ~= nil then Settings.Set(key, default) end
end

function Settings.RegisterReloadRequired(key)
    if Settings.GetDefault(key) == nil then return end
    reloadRequired[key] = true
    loadValues[key] = Settings.Get(key)
end

function Settings.NeedsReload()
    for key in pairs(reloadRequired) do
        if Settings.Get(key) ~= loadValues[key] then return true end
    end
    return false
end

ReadDB = function()
    local db = _G.DuelsReimaginedDB
    return type(db) == "table" and db or nil
end

local function WriteDB()
    local db = ReadDB()
    if not db then
        db = {}
        _G.DuelsReimaginedDB = db
    end
    return db
end

function Settings.NormalizeScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    local step = Settings.SCALE_STEP
    return math.max(Settings.MIN_SCALE, math.min(Settings.MAX_SCALE,
        math.floor(value / step + 0.5) * step))
end

-- Separate, optional account-wide window dimensions. A missing entry
-- requests the existing screen-fitted default. Never return the database table.
local function CleanWindowSize(size)
    if type(size) ~= "table" then return nil end
    local w, h = size.width, size.height
    if type(w) ~= "number" or type(h) ~= "number" or w ~= w or h ~= h or
        w < 600 or h < 450 or w > 6000 or h > 6000 then return nil end
    return math.floor(w + 0.5), math.floor(h + 0.5)
end

function Settings.GetWindowSize()
    local db = ReadDB()
    return CleanWindowSize(db and db.windowSize)
end

function Settings.HasWindowSize()
    return Settings.GetWindowSize() ~= nil
end

function Settings.SetWindowSize(w, h)
    local db = WriteDB()
    local nw, nh = CleanWindowSize({ width = w, height = h })
    local ow, oh = CleanWindowSize(db.windowSize)
    if nw == ow and nh == oh then return end
    db.windowSize = nw and { width = nw, height = nh } or nil
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

function Settings.Get(key)
    local db = ReadDB()
    if key == "menuScale" then
        return Settings.NormalizeScale(db and db.menuScale)
    end
    if key == "fontScale" then
        local value = db and db.fontScale
        if type(value) ~= "number" or value ~= value then return 1 end
        return math.max(0.9, math.min(1.15, math.floor(value * 20 + 0.5) / 20))
    end
    if key == "fontChoice" then
        local value = db and db.fontChoice
        if type(value) ~= "string" or #value > 128 or value == "" then return "default" end
        return value
    end
    if key == "fontOutline" then
        local value = db and db.fontOutline
        if value == "none" or value == "outline" or value == "thick" then return value end
        return "default"
    end
    if boolDefaults[key] == nil then return nil end
    -- When the integration is unavailable, the EFFECTIVE setting is OFF.
    -- Preserve any saved ON override for when EllesmereUI is enabled again.
    if IsMatchPreference(key) and not EllesmereReady() then return false end
    local stored = db and db[key]
    if type(stored) == "boolean" then return stored end
    return Settings.GetDefault(key)
end

function Settings.Set(key, value)
    if key == "menuScale" then
        local nextValue = Settings.NormalizeScale(value)
        local db = WriteDB()
        if db.menuScale == nextValue then return end
        db.menuScale = nextValue
        if ns.Window and ns.Window.ApplyScale then
            ns.Window.ApplyScale(nextValue)
        end
        if ns.Window and ns.Window.RefreshScaleMarker then ns.Window.RefreshScaleMarker() end
        if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
        return
    end
    -- Typography shares this settings owner and persists immediately.
    if key == "fontChoice" or key == "fontScale" or key == "fontOutline" then
        local nextValue
        if key == "fontChoice" then
            if type(value) ~= "string" or #value > 128 or value == "" then return end
            nextValue = value
        elseif key == "fontScale" then
            if type(value) ~= "number" or value ~= value then return end
            nextValue = math.max(0.9, math.min(1.15, math.floor(value * 20 + 0.5) / 20))
        else
            if value ~= "default" and value ~= "none" and
                value ~= "outline" and value ~= "thick" then return end
            nextValue = value
        end
        local db = WriteDB()
        if Settings.Get(key) == nextValue then return end
        db[key] = nextValue
        if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
        return
    end
    if boolDefaults[key] == nil or type(value) ~= "boolean" then return end
    local db = WriteDB()
    if db[key] == value then return end
    db[key] = value
    if key == "autoPeekMoving" then
        if ns.Header and ns.Header.RefreshAutoPeek then
            ns.Header.RefreshAutoPeek()
        end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif ns.Theme then
        ns.Theme.Refresh()
    end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

-- SavedVariables are authoritative only once this addon's ADDON_LOADED fires.
-- Seed missing/invalid values then repaint UI built from earlier defaults.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    local db = WriteDB()
    for key, default in pairs(boolDefaults) do
        if IsMatchPreference(key) then
            -- Keep nil for automatic detection. Legacy true/false choices
            -- remain intact; invalid saved types become auto.
            if db[key] ~= nil and type(db[key]) ~= "boolean" then
                db[key] = nil
            end
        elseif type(db[key]) ~= "boolean" then
            db[key] = default
        end
    end
    db.menuScale = Settings.NormalizeScale(db.menuScale)
    -- Normalize through the same getters, keeping existing SavedVariables.
    db.fontChoice = Settings.Get("fontChoice")
    db.fontScale = Settings.Get("fontScale")
    db.fontOutline = Settings.Get("fontOutline")
    if not Settings.HasWindowSize() then db.windowSize = nil end
    for key in pairs(reloadRequired) do loadValues[key] = Settings.Get(key) end
    if ns.Window and ns.Window.ApplyScale then
        ns.Window.ApplyScale(db.menuScale)
    end
    if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
    if ns.Header and ns.Header.RefreshAutoPeek then
        ns.Header.RefreshAutoPeek()
    end
    if ns.Window and ns.Window.RefreshScaleMarker then ns.Window.RefreshScaleMarker() end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end)

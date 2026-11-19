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
}

local function ReadDB()
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

function Settings.Get(key)
    local db = ReadDB()
    if key == "menuScale" then
        return Settings.NormalizeScale(db and db.menuScale)
    end
    if boolDefaults[key] == nil then return nil end
    local stored = db and db[key]
    if type(stored) == "boolean" then return stored end
    return boolDefaults[key]
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
        if type(db[key]) ~= "boolean" then db[key] = default end
    end
    db.menuScale = Settings.NormalizeScale(db.menuScale)
    if ns.Window and ns.Window.ApplyScale then
        ns.Window.ApplyScale(db.menuScale)
    end
    if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
    if ns.Header and ns.Header.RefreshAutoPeek then
        ns.Header.RefreshAutoPeek()
    end
end)

local _, ns = ...

-- Single owner for account-wide UI preferences. Keep the existing names.
local Settings = {}
ns.Settings = Settings

local db = _G.DuelsReimaginedDB
if type(db) ~= "table" then
    db = {}
    _G.DuelsReimaginedDB = db
end

local boolDefaults = {
    matchColors = false,
    matchFont = false,
}

local function CleanScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    value = math.max(0.85, math.min(1.15, value))
    return math.floor(value * 20 + 0.5) / 20
end

for key, default in pairs(boolDefaults) do
    if type(db[key]) ~= "boolean" then db[key] = default end
end
db.menuScale = CleanScale(db.menuScale)

function Settings.Get(key)
    if key == "menuScale" then return db.menuScale end
    if boolDefaults[key] == nil then return nil end
    return db[key]
end

function Settings.Set(key, value)
    if key == "menuScale" then
        local nextValue = CleanScale(value)
        if db.menuScale == nextValue then return end
        db.menuScale = nextValue
        if ns.Window and ns.Window.ApplyScale then ns.Window.ApplyScale(nextValue) end
        return
    end
    if boolDefaults[key] == nil or type(value) ~= "boolean" then return end
    if db[key] == value then return end
    db[key] = value
    if ns.Theme then ns.Theme.Refresh() end
end

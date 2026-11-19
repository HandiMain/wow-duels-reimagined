local _, ns = ...

-- Account-wide appearance preferences. Other settings will use this owner later.
local Settings = {}
ns.Settings = Settings

local db = _G.DuelsReimaginedDB
if type(db) ~= "table" then
    db = {}
    _G.DuelsReimaginedDB = db
end

local defaults = {
    matchColors = false,
    matchFont = false,
}

for key, default in pairs(defaults) do
    if type(db[key]) ~= "boolean" then
        db[key] = default
    end
end

function Settings.Get(key)
    if defaults[key] == nil then return nil end
    return db[key]
end

function Settings.Set(key, value)
    if defaults[key] == nil or type(value) ~= "boolean" then return end
    if db[key] == value then return end
    db[key] = value
    if ns.Theme then ns.Theme.Refresh() end
end

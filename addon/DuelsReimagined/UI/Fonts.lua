local _, ns = ...

-- One small font-discovery adapter; not a second settings owner.
-- LibSharedMedia-3.0 was provided as a reference API and supplies registered
-- font names, not an actual font pack. It is entirely optional at runtime.
local Fonts = {}
ns.Fonts = Fonts

local builtins = {
    { key = "default", label = "Blizzard Default", path = nil },
    { key = "builtin:Arial Narrow", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "builtin:Friz Quadrata", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "builtin:Morpheus", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "builtin:Skurri", label = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

local function Library()
    if type(LibStub) ~= "function" and type(LibStub) ~= "table" then return nil end
    return LibStub("LibSharedMedia-3.0", true)
end

function Fonts.Resolve(key)
    if key == nil or key == "default" then return nil end
    for _, entry in ipairs(builtins) do
        if entry.key == key then return entry.path end
    end
    if type(key) == "string" and key:sub(1, 4) == "lsm:" then
        local lib = Library()
        if lib and type(lib.Fetch) == "function" then
            local path = lib:Fetch("font", key:sub(5), true)
            if type(path) == "string" and path ~= "" then return path end
        end
    end
    return nil
end

function Fonts.GetChoices()
    local list, seen = {}, {}
    for _, entry in ipairs(builtins) do
        list[#list + 1] = { key = entry.key, label = entry.label }
        seen[entry.key] = true
    end
    local lib = Library()
    if lib and type(lib.List) == "function" then
        local names = lib:List("font")
        if type(names) == "table" then
            for _, name in ipairs(names) do
                local key = "lsm:" .. tostring(name)
                if not seen[key] and type(lib:Fetch("font", name, true)) == "string" then
                    list[#list + 1] = { key = key, label = name }
                    seen[key] = true
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.key == "default" then return true end
        if b.key == "default" then return false end
        return a.label:lower() < b.label:lower()
    end)
    -- Keep stored third-party selections visible when their addon is absent.
    local selected = ns.Settings and ns.Settings.Get("fontChoice") or "default"
    if not seen[selected] then
        list[#list + 1] = { key = selected, label = selected:gsub("^lsm:", "") ..
            " (unavailable)" }
    end
    return list
end

function Fonts.GetLabel(key)
    for _, entry in ipairs(Fonts.GetChoices()) do
        if entry.key == key then return entry.label end
    end
    return "Blizzard Default"
end

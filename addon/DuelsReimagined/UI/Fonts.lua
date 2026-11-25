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

function Fonts.GetChoices(selected, omitDefault)
    local list, seen = {}, {}
    for _, entry in ipairs(builtins) do
        if not omitDefault or entry.key~="default" then
            list[#list + 1] = { key = entry.key, label = entry.label }
            seen[entry.key] = true
        end
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
    selected = selected or (ns.Settings and ns.Settings.Get("fontChoice")) or "default"
    if not seen[selected] then
        list[#list + 1] = { key = selected, label = selected:gsub("^lsm:", "") ..
            " (unavailable)" }
    end
    return list
end

-- A font sample is independent of Style's themed font registry. Resolve each
-- visible choice afresh, including recycled rows and missing media.
function Fonts.PaintSample(region,key,label,size,width)
    local fallback="Fonts\\FRIZQT__.TTF"
    local path=key=="default" and (STANDARD_TEXT_FONT or fallback) or Fonts.Resolve(key) or fallback
    local function Apply(face,pt)
        local ok,result=pcall(region.SetFont,region,face,pt,"")
        return ok and result and true or false
    end
    if not Apply(path,size) then
        path=fallback
        Apply(path,size)
    end
    region:SetText(label or "")
    -- Unbounded measurement avoids treating already-clipped text as fitting.
    local measure=region.GetUnboundedStringWidth or region.GetStringWidth
    if type(measure)=="function" then
        local ok,v=pcall(measure,region)
        if ok and type(issecretvalue)=="function" then
            local safe,secret=pcall(issecretvalue,v)
            if not safe or secret then ok=false end
        end
        if ok and type(v)=="number" and v>width and v<math.huge then
            Apply(path,math.max(10,math.floor(size*width/v)))
        end
    end
end

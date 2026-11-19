local _, ns = ...

-- One searchable registry for every visible page, setting and header action.
-- Owners register their actual controls; search never maintains a second
-- hardcoded feature list or pretends unfinished screens exist.
local Search = { entries = {}, order = {} }
ns.Search = Search

local function Normalize(value)
    if type(value) ~= "string" then return "" end
    return value:lower():gsub("[%p%c]", " "):gsub("%s+", " ")
        :gsub("^%s+", ""):gsub("%s+$", "")
end

function Search.Register(id, title, where, details, activate)
    if type(id) ~= "string" or type(title) ~= "string" or
        type(activate) ~= "function" then return end
    if not Search.entries[id] then Search.order[#Search.order + 1] = id end
    Search.entries[id] = {
        id = id, title = title, where = where or "",
        details = details or "", activate = activate,
        titleKey = Normalize(title),
        whereKey = Normalize(where or ""),
        keywords = Normalize((title or "") .. " " ..
            (where or "") .. " " .. (details or "")),
    }
end

function Search.Query(value)
    local term = Normalize(value)
    if term == "" then return {} end
    local matches = {}
    for _, id in ipairs(Search.order) do
        local item = Search.entries[id]
        local all = true
        for word in term:gmatch("%S+") do
            if not item.keywords:find(word, 1, true) then
                all = false
                break
            end
        end
        if all then
            local score = 10
            if item.titleKey == term then score = 100
            elseif item.titleKey:sub(1, #term) == term then score = 80
            elseif item.titleKey:find(term, 1, true) then score = 60
            elseif item.whereKey:find(term, 1, true) then score = 30 end
            matches[#matches + 1] = { item = item, score = score }
        end
    end
    table.sort(matches, function(a, b)
        if a.score == b.score then
            return a.item.title < b.item.title
        end
        return a.score > b.score
    end)
    local results = {}
    for i = 1, math.min(6, #matches) do
        results[i] = matches[i].item
    end
    return results
end

function Search.Open(item)
    if item and type(item.activate) == "function" then
        item.activate()
        return true
    end
    return false
end

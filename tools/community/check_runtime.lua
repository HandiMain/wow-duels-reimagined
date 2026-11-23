-- Runtime contract smoke checks for code shipped inside the addon.
-- Uses minimal stubs, not a fake WoW UI environment.
local function Check(value, message)
    if not value then error(message, 2) end
end

-- Client identity is independent of any UI or SavedVariables.
-- Mock the fourth value of GetBuildInfo (interface number) for each client.
local originalGetBuildInfo = _G.GetBuildInfo
local function ClientFor(interface)
    local scope = {}
    if interface == "missing" then
        _G.GetBuildInfo = nil
    else
        _G.GetBuildInfo = function()
            if interface == "error" then error("GetBuildInfo unavailable") end
            return "mock", "mock", "mock", interface
        end
    end
    local chunk = assert(loadfile("addon/DuelsReimagined/Core/Client.lua"))
    chunk("DuelsReimagined", scope)
    return scope.Client
end
local retail = ClientFor(120105)
Check(retail.Kind() == "retail" and retail.IsRetail() and not retail.IsForever()
    and retail.IsSupported(), "Retail must be recognized")
local retailText = ClientFor("120105")
Check(retailText.IsRetail(), "String-encoded Retail interface must be recognized")
local forever = ClientFor(16001)
Check(forever.Kind() == "forever" and forever.IsForever() and not forever.IsRetail()
    and forever.IsSupported(), "Forever must be recognized")
for _, iface in ipairs({ 11507, 50500, 12000, "invalid", "missing", "error" }) do
    local other = ClientFor(iface)
    Check(other.Kind() == "unsupported" and not other.IsRetail()
        and not other.IsForever() and not other.IsSupported(),
        "Unknown interface must fail closed: " .. tostring(iface))
end
_G.GetBuildInfo = originalGetBuildInfo

local ns = {}
local searchChunk = assert(loadfile("addon/DuelsReimagined/UI/Search.lua"))
searchChunk("DuelsReimagined", ns)
local Search = ns.Search
local chosen = nil
for i = 1, 9 do
    local number = i
    Search.Register("test:" .. number, "Searchable item " .. number,
        "Harness", "More test words", function() chosen = number end)
end
Search.Register("test:unavailable", "Searchable disabled action",
    "Harness", "Cannot use now", function() error("should never activate") end,
    function() return false end)
Search.Register("test:error", "Searchable broken action",
    "Harness", "Availability callback errors", function() error("should never activate") end,
    function() error("fault inside checker") end)

local matches = Search.Query("Searchable")
Check(#matches == 9, "Search must return all nine available results (no silent 6-cap)")
for _, item in ipairs(matches) do
    Check(item.title ~= "Searchable disabled action", "Unavailable action leaked")
    Check(item.title ~= "Searchable broken action", "Errored availability leaked")
end
Check(Search.Open(matches[7]) == true, "Search action should open")
Check(chosen ~= nil, "Search callback did not fire")
Check(Search.Query("no matching query")[1] == nil, "Search should return no matches")
Check(Search.Query("searchable ITEM")[1] ~= nil, "Search normalization failed")

-- Settings storage and reload-button contract.
local loader
_G.DuelsReimaginedDB = { showInCompartment = false }
_G.CreateFrame = function()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(name, callback)
        self.scripts[name] = callback
    end
    loader = frame
    return frame
end
local settingsChunk = assert(loadfile("addon/DuelsReimagined/Core/Settings.lua"))
settingsChunk("DuelsReimagined", ns)
local Settings = ns.Settings
Settings.RegisterReloadRequired("showInCompartment")
Check(type(loader.scripts.OnEvent) == "function", "ADDON_LOADED handler missing")
loader.scripts.OnEvent(loader, "ADDON_LOADED", "DuelsReimagined")
Check(Settings.Get("showInCompartment") == false, "Saved false compartment setting lost")
Check(not Settings.NeedsReload(), "Correct saved startup setting should not need reload")
Settings.Set("showInCompartment", true)
Check(Settings.NeedsReload(), "Compartment change should require reload")
Settings.Reset("showInCompartment")
Check(Settings.Get("showInCompartment") == true, "Compartment reset should restore true default")
Check(Settings.NeedsReload(), "Reset from saved false still needs reload")
Settings.Set("showInCompartment", false)
Check(not Settings.NeedsReload(), "Returning to original startup choice should clear reload")
print("Search and SavedVariables runtime contracts: PASS")

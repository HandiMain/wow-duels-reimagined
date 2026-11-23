local _, ns = ...

-- One shared client identity for the entire addon. WoW Forever uses the
-- Camelot game type and 160xx interface numbers; Retail uses 12xxxx.
-- Do not use WOW_PROJECT_ID here: Forever runs on the modern engine.
--
-- This describes which client loaded us, NOT whether an optional gameplay
-- API is available. Retail-only modules must additionally gate their
-- files in the TOC and check their actual Blizzard APIs before use.
local Client = {}
ns.Client = Client

local function Detect()
    if type(GetBuildInfo) ~= "function" then return "unsupported" end
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    if not ok then return "unsupported" end
    local number = tonumber(interface)
    if not number or number ~= number then return "unsupported" end

    if number >= 16000 and number < 20000 then return "forever" end
    if number >= 120000 and number < 200000 then return "retail" end
    return "unsupported"
end

-- Game identity cannot change during a WoW session; detect once at load.
local kind = Detect()

function Client.Kind() return kind end
function Client.IsRetail() return kind == "retail" end
function Client.IsForever() return kind == "forever" end
function Client.IsSupported() return kind ~= "unsupported" end

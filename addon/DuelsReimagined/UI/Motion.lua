local _, ns = ...

-- One shared animation driver. It runs only while at least one value changes.
local Motion = {}
ns.Motion = Motion

local driver = CreateFrame("Frame")
local active = {}

-- Reduced-motion behavior uses our existing single
-- tween owner. Never create a second animator or a permanent polling loop.
Motion.Presets = { quick = 0.12, normal = 0.17, gentle = 0.22 }
function Motion.Duration(kind)
    return Motion.Presets[kind] or Motion.Presets.normal
end
local function Reduced()
    return ns.Settings and ns.Settings.Get("reduceMotion") == true
end

local function Smooth(p)
    return p * p * (3 - 2 * p)
end

local function Tick(_, elapsed)
    for key, tween in pairs(active) do
        tween.elapsed = tween.elapsed + elapsed
        local progress = math.min(1, tween.elapsed / tween.duration)
        local value = tween.from + (tween.to - tween.from) * Smooth(progress)
        tween.apply(key, value)
        if progress >= 1 then
            active[key] = nil
        end
    end
    if not next(active) then driver:SetScript("OnUpdate", nil) end
end

-- Numeric interpolation for shared components such as sliding toggles.
-- Retargeting a value replaces its existing tween, never stacks a second one.
function Motion.Value(key, from, target, duration, apply)
    if not key or type(apply) ~= "function" then return end
    active[key] = nil
    -- Reduced motion snaps movement/slider transitions; opacity fades are
    -- still handled as brief fades in Motion.Fade.
    if Reduced() then duration = 0 end
    if not duration or duration <= 0 or math.abs(from - target) < 0.001 then
        apply(key, target)
        if not next(active) then driver:SetScript("OnUpdate", nil) end
        return
    end

    local tween = { from = from, to = target, duration = duration,
        elapsed = 0, apply = apply }
    active[key] = tween
    driver:SetScript("OnUpdate", Tick)
end

local function ApplyAlpha(region, value)
    region:SetAlpha(value)
end

function Motion.Fade(region, target, duration)
    if not region then return end
    -- Keep a tiny opacity transition for readability in reduced-motion mode.
    -- Callers retain their existing animations otherwise.
    if Reduced() then duration = 0 end
    Motion.Value(region, region:GetAlpha(), target, duration, ApplyAlpha)
end

function Motion.Stop(region, value)
    active[region] = nil
    if value ~= nil then region:SetAlpha(value) end
    if not next(active) then driver:SetScript("OnUpdate", nil) end
end

-- Read-only diagnostic probe; never expose or alter the active tween table.
function Motion.GetRuntimeState()
    local count=0
    for _ in pairs(active) do count=count+1 end
    return {active=count,driver=driver:GetScript("OnUpdate")~=nil}
end

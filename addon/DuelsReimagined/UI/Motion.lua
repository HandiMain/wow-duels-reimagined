local _, ns = ...

-- One idle-free animation driver for all Duels-owned visual feedback.
local Motion = {}
ns.Motion = Motion

local driver = CreateFrame("Frame")
local active = {}

local function Tick(_, elapsed)
    local running = false
    for region, tween in pairs(active) do
        tween.elapsed = tween.elapsed + elapsed
        local p = math.min(1, tween.elapsed / tween.duration)
        p = p * p * (3 - 2 * p)
        region:SetAlpha(tween.from + (tween.to - tween.from) * p)
        if tween.elapsed >= tween.duration then
            region:SetAlpha(tween.to)
            active[region] = nil
        else
            running = true
        end
    end
    if not running then driver:SetScript("OnUpdate", nil) end
end

function Motion.Fade(region, target, duration)
    if not region then return end
    local current = region:GetAlpha()
    if duration == nil or duration <= 0 or math.abs(current - target) < 0.001 then
        active[region] = nil
        region:SetAlpha(target)
        if not next(active) then driver:SetScript("OnUpdate", nil) end
        return
    end
    local tween = active[region]
    if not tween then
        tween = {}
        active[region] = tween
    end
    tween.from = current
    tween.to = target
    tween.elapsed = 0
    tween.duration = duration
    driver:SetScript("OnUpdate", Tick)
end

function Motion.Stop(region, value)
    active[region] = nil
    if value then region:SetAlpha(value) end
    if not next(active) then driver:SetScript("OnUpdate", nil) end
end

local addon,ns=...
-- Release sightings only. Existing Presence owns all network messages.
local U={};ns.UpdateNotices=U
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
function U.Parse(v)
    v=Plain(v)
    if type(v)~="string" or #v>16 then return nil end
    local a,b,c=v:match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    a,b,c=tonumber(a),tonumber(b),tonumber(c)
    if a>99 or b>999 or c>999 or string.format("%d.%d.%d",a,b,c)~=v then return nil end
    return {a,b,c}
end
function U.Compare(a,b)
    a,b=U.Parse(a),U.Parse(b)
    if not a or not b then return nil end
    for i=1,3 do if a[i]~=b[i] then return a[i]>b[i] and 1 or -1 end end
    return 0
end
local function Installed()
    local getter=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(getter)~="function" then return nil end
    local ok,v=pcall(getter,addon,"Version")
    if ok and U.Parse(v) then return v end
end
function U.Select(mine,roster)
    local current=U.Parse(mine)
    if not current or type(roster)~="table" or not roster.complete or roster.stale then return nil end
    local versions,seen={},{}
    for _,m in ipairs(roster.members or {}) do
        local v=Plain(m.version);local p=U.Parse(v)
        local id=Plain(m.guid)
        if m.status=="confirmed" and type(id)=="string" and id~="" and not seen[id]
            and p and U.Compare(v,mine)==1 and
            ((p[1]==current[1] and p[2]<=current[2]+1) or (p[1]==current[1]+1 and p[2]==0)) then
            seen[id]=true;versions[v]=(versions[v] or 0)+1
        end
    end
    local best
    for v,n in pairs(versions) do
        if n>=2 and (not best or U.Compare(v,best)==1) then best=v end
    end
    return best
end
local latest
function U.Observe(roster)
    local mine=Installed()
    local v=mine and U.Select(mine,roster)
    if v and (not latest or U.Compare(v,latest)==1) then latest=v end
end
function U.GetNotice()
    local mine=Installed()
    if not mine or not latest or U.Compare(latest,mine)~=1 then return nil end
    return {version=latest,mine=mine,source="peer"}
end
function U.GetStatus()
    if not Installed() then return "development build; preview only" end
    local n=U.GetNotice()
    return n and ("newer peer-reported version "..n.version) or "no newer version confirmed by peers"
end

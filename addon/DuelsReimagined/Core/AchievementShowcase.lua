local _,ns=...
-- A character's ordered cosmetic selection, not another progression store.
local Q={MAX=3};ns.AchievementShowcase=Q
function Q.Validate(ids)
    if type(ids)~="table" then return nil end
    local n,seen=0,{}
    for k,id in pairs(ids) do
        if type(k)~="number" or k<1 or k>Q.MAX or k~=math.floor(k)
            or type(id)~="string" or not ns.Achievements.GetRequirement(id) or seen[id] then return nil end
        n=n+1;seen[id]=true
        if n>Q.MAX then return nil end
    end
    local clean={}
    for i=1,n do if not ids[i] then return nil end;clean[i]=ids[i] end
    return clean
end
function Q.Same(a,b)
    if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
    for i=1,#a do if a[i]~=b[i] then return false end end
    return true
end
function Q.Model(data)
    local out={scope=data and data.scope or "LOCAL",saved={},byId={},index={},available=false,editable=false}
    if not data or data.scope~="LOCAL" then return out end
    local prefs=ns.Settings
    if prefs and prefs.GetCharacterShowcase then
        local saved,why=prefs.GetCharacterShowcase()
        if saved then out.saved=saved;out.editable=true
        else out.reason=why end
    end
    for i,id in ipairs(out.saved) do out.index[id]=i end
    out.available=not data.storageReason and not data.recordingDisabled
    if out.available then
        for _,r in ipairs(data.rows or {}) do
            if r.earned==true and not r.testOnly and not r.unavailable and not r.hidden
                and ns.Achievements.GetRequirement(r.id) then out.byId[r.id]=r end
        end
    end
    return out
end
local function RealSelection()
    if not ns.CompetitivePreview or ns.CompetitivePreview.IsActive() then return nil,"Test achievements cannot be showcased." end
    local prefs=ns.Settings
    if not prefs or not prefs.GetCharacterShowcase or not prefs.SetCharacterShowcase then return nil,"Showcase preferences unavailable." end
    return prefs.GetCharacterShowcase()
end
function Q.Toggle(id)
    if type(id)~="string" or not ns.Achievements.GetRequirement(id) then return false,"Unknown achievement." end
    local saved,why=RealSelection()
    if not saved then return false,why end
    -- Removing a previously selected ID is always safe, even while its
    -- original evidence is unavailable. New pins require a fresh live read.
    for i,v in ipairs(saved) do
        if id==v then
            table.remove(saved,i)
            return ns.Settings.SetCharacterShowcase(saved),"Showcase preferences unavailable."
        end
    end
    if #saved>=Q.MAX then return false,"Showcase full. Unpin an achievement first." end
    local ok,data=pcall(function()
        local localData=ns.CompetitivePreview.Local()
        if not localData or localData.scope~="LOCAL" then return nil end
        return ns.Achievements.Current(localData)
    end)
    if not ok or not data or data.scope~="LOCAL" or not Q.Model(data).byId[id] then
        return false,"Earn this achievement before showcasing it."
    end
    saved[#saved+1]=id
    return ns.Settings.SetCharacterShowcase(saved),"Showcase preferences unavailable."
end
function Q.SaveOrder(ids,expected)
    local nextIds=Q.Validate(ids)
    local baseline=Q.Validate(expected)
    if not nextIds or not baseline then return false,"Invalid showcase selection." end
    local current,why=RealSelection()
    if not current then return false,why end
    if not Q.Same(current,baseline) then return false,"Showcase changed. Cancel and reopen the editor." end
    local allowed={}
    for _,id in ipairs(current) do allowed[id]=true end
    -- Editing only reorders/removes the already saved pins, never awards one.
    for _,id in ipairs(nextIds) do if not allowed[id] then return false,"Pin achievements on the Achievements page." end end
    return ns.Settings.SetCharacterShowcase(nextIds),"Showcase preferences unavailable."
end

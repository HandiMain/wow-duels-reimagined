local _,ns=...
-- Titles are presentation rewards for existing achievement IDs. No unlock
-- ledger, rating calculations, new progress counters, or network messages.
local T={};ns.DuelistTitles=T
local catalog={
    {"begin","The Challenger"},{"first","The Blooded"},{"tested","Battle Forged"},
    {"rising","The Relentless"},{"seasoned","The Executioner"},{"born","Born for Battle"},
    {"thousand","The Thousand Blade"},{"double","The Rising Blade"},{"spree","The Merciless"},
    {"unstoppable","The Unbroken"},{"untouchable","The Untouchable"},{"perfection","The Invincible"},
    {"aspirant","The Aspirant"},{"contender","The Contender"},{"veteran","The Veteran"},
    {"duelist","The Duelist"},{"master","Master of Arms"},{"grandmaster","The Grandmaster"},
    {"rated","The Warlord"},{"meet","The Wanderer"},{"challenger","The Pathfinder"},
    {"fearless","The Fearless"},{"conqueror","The Conqueror"},{"giant","The Giant Slayer"},
    {"nemesis","The Nemesis"},{"revenge","The Avenger"},{"dedicated","The Dedicated"},
    {"warveteran","Veteran of War"},{"addict","The Battleborn"},{"eternal","The Eternal"},
    {"wayoflife","The Devoted"},{"legend","The Living Legend"},{"tourbegin","The Gladiator"},
    {"tourfinal","The Finalist"},{"tourwin","The Champion"},{"tourreign","The Crowned"},
    {"toursweep","The Flawless"},{"tourarena","King of the Arena"},{"tourhost","The Organizer"},
    {"tourlegend","The Immortal"},
}
local names={}
for _,v in ipairs(catalog) do
    assert(not names[v[1]] and ns.Achievements.GetRequirement(v[1]),"Invalid title reward")
    names[v[1]]=v[2]
end
function T.IsKnown(id)return names[id]~=nil end
function T.Reward(id)return names[id] end
function T.Model(achievements)
    local model={scope=achievements and achievements.scope or "LOCAL",rows={},byId={},earned=0,total=#catalog}
    local real=achievements and achievements.scope=="LOCAL" and not achievements.storageReason and not achievements.recordingDisabled
    local observed={}
    for _,r in ipairs(achievements and achievements.rows or {}) do observed[r.id]=r end
    for _,item in ipairs(catalog) do
        local id,name=item[1],item[2]
        local description,target,category,icon,rarity=ns.Achievements.GetRequirement(id)
        local r=observed[id]
        local available=real and r and not r.testOnly and not r.unavailable
        local earned=available and r.earned==true or false
        local row={id=id,name=name,description=description,target=target,category=category,icon=icon,rarity=rarity,
            progress=available and math.max(0,math.min(target,r.progress or 0)) or 0,
            earned=earned,available=not not available}
        model.rows[#model.rows+1]=row;model.byId[id]=row
        if earned then model.earned=model.earned+1 end
    end
    if model.scope=="LOCAL" and ns.Settings and ns.Settings.GetCharacterTitle then
        local id=ns.Settings.GetCharacterTitle()
        if id and model.byId[id] then
            model.saved=id
            if model.byId[id].earned then model.equipped=id end
        end
    end
    return model
end
function T.Read(data)
    local ok,result=pcall(ns.Achievements.Current,data)
    return T.Model(ok and result or nil)
end
function T.Equip(id)
    -- Only a fresh live read can authorize a write. Never accept a caller's
    -- model or fixture, even if it happens to contain the same achievement IDs.
    if not ns.CompetitivePreview or ns.CompetitivePreview.IsActive() then return false,"Titles cannot be equipped in a test." end
    if not ns.Settings or not ns.Settings.SetCharacterTitle then return false,"Title preferences unavailable." end
    if id~=nil then
        if not T.IsKnown(id) then return false,"Unknown title." end
        local ok,data=pcall(ns.CompetitivePreview.Local)
        if not ok or not data or data.scope~="LOCAL" then return false,"Title progress unavailable." end
        local model=T.Read(data)
        if not model.byId[id].earned then return false,"This title is locked." end
    end
    if not ns.Settings.SetCharacterTitle(id) then return false,"Title preferences unavailable." end
    return true
end

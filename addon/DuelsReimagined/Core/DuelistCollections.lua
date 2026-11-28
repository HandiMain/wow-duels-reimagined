local _,ns=...
-- Cosmetic rewards derive from the same achievement evaluator as titles.
-- Only selected IDs are persisted, never a second unlock ledger.
local K={};ns.DuelistCollections=K
local media="Interface\\AddOns\\DuelsReimagined\\Media\\Profile\\"
local catalog={
    {"background","bronze","Classic Bronze",nil,nil,{.065,.055,.048}},
    {"background","faction","Faction Pride",nil,nil,{.045,.07,.12}},
    {"background","blood","Blood and Steel","rising","BloodSteel.png"},
    {"background","inferno","Inferno","seasoned","Inferno.png"},
    {"background","frost","Eternal Frost","unstoppable","EternalFrost.png"},
    {"background","shadow","Shadowborn","conqueror","Shadowborn.png"},
    {"background","celestial","Celestial","born","Celestial.png"},
    {"background","glory","Eternal Glory","legend","EternalGlory.png"},
    {"border","bronze","Classic Bronze",nil,nil,{.63,.43,.23},{.29,.19,.10}},
    {"border","iron","Battle Forged","tested",nil,{.62,.65,.69},{.25,.28,.31}},
    {"border","blood","Bloodforged","spree",nil,{.88,.27,.15},{.40,.12,.08}},
    {"border","frost","Frostbound","untouchable",nil,{.37,.78,1},{.12,.31,.52}},
    {"border","champion","Golden Champion","tourwin",nil,{1,.76,.27},{.47,.31,.09}},
    {"border","grandmaster","Grandmaster's Legacy","grandmaster",nil,{.82,.48,1},{.34,.15,.55}},
}
local index={background={},border={}}
local rewards={}
for _,d in ipairs(catalog) do
    assert(not index[d[1]][d[2]])
    index[d[1]][d[2]]=d
    if d[4] then
        assert(ns.Achievements.GetRequirement(d[4]),"Unknown collection achievement")
        local v=rewards[d[4]] or {};rewards[d[4]]=v
        v[#v+1]=(d[1]=="background" and "Background: " or "Border: ")..d[3]
    end
end
function K.IsKnown(kind,id)
    return type(kind)=="string" and type(id)=="string" and index[kind] and index[kind][id]~=nil or false
end
function K.Rewards(id)
    local v=rewards[id];return v and table.concat(v,"; ") or nil
end
local function Copy(d)
    if not d then return nil end
    return {kind=d[1],id=d[2],name=d[3],achievement=d[4],texture=d[5] and media..d[5] or nil,
        color=d[6] and {unpack(d[6])},accent=d[7] and {unpack(d[7])}}
end
function K.Art(kind,id)
    return K.IsKnown(kind,id) and Copy(index[kind][id]) or nil
end
function K.Default(kind)
    if kind=="background" then
        return ns.Settings and ns.Settings.Get and ns.Settings.Get("profileFactionBackdrop")==false and "bronze" or "faction"
    end
    return "bronze"
end
function K.Model(data,titleModel)
    local scope=data and data.scope or "LOCAL"
    local model={scope=scope,rows={},byKind={background={},border={}},equipped={},saved={},counts={background={earned=0,total=0},border={earned=0,total=0}},editable=false}
    local real=scope=="LOCAL" and data and not data.storageReason and not data.recordingDisabled
    local observed={}
    if real then for _,r in ipairs(data.rows or {}) do observed[r.id]=r end end
    local prefs=ns.Settings
    if scope=="LOCAL" and prefs and prefs.GetCharacterCosmetic then
        local bg,ok=prefs.GetCharacterCosmetic("background")
        local border,ok2=prefs.GetCharacterCosmetic("border")
        model.saved.background=bg;model.saved.border=border
        model.editable=ok==true and ok2==true
    end
    for _,d in ipairs(catalog) do
        local r=Copy(d)
        local desc,target
        if d[4] then desc,target=ns.Achievements.GetRequirement(d[4]) end
        local a=observed[d[4]]
        local eligible=a and not a.testOnly and not a.unavailable and not a.hidden
        r.requirement=desc or "Available by default."
        r.target=target or 1
        r.earned=not d[4] or (eligible and a.earned==true) or false
        r.available=not d[4] or not not eligible
        r.progress=not d[4] and 1 or eligible and math.min(r.target,math.max(0,a.progress or 0)) or 0
        model.rows[#model.rows+1]=r;model.byKind[r.kind][r.id]=r
        local c=model.counts[r.kind];c.total=c.total+1;if r.earned then c.earned=c.earned+1 end
    end
    for _,kind in ipairs({"background","border"}) do
        local id=model.saved[kind]
        model.equipped[kind]=id and model.byKind[kind][id] and model.byKind[kind][id].earned and id or K.Default(kind)
    end
    model.counts.title={earned=titleModel and titleModel.earned or 0,total=titleModel and titleModel.total or 40}
    model.total=model.counts.background.total+model.counts.border.total+model.counts.title.total
    model.earned=model.counts.background.earned+model.counts.border.earned+model.counts.title.earned
    return model
end
function K.Equip(kind,id)
    if kind~="background" and kind~="border" then return false,"Unknown collection category." end
    if id~=nil and not K.IsKnown(kind,id) then return false,"Unknown collectible." end
    local source=ns.CompetitivePreview
    if not source or source.IsActive() then return false,"Collection changes are unavailable in a test." end
    local prefs=ns.Settings
    if not prefs or not prefs.SetCharacterCosmetic then return false,"Collection preferences unavailable." end
    if id~=nil and index[kind][id][4] then
        local ok,model=pcall(function()
            local d=source.Local()
            if not d or d.scope~="LOCAL" then return nil end
            return K.Model(ns.Achievements.Current(d))
        end)
        if not ok or not model or not model.byKind[kind][id].earned then return false,"Earn this collectible first." end
    end
    if not prefs.SetCharacterCosmetic(kind,id) then return false,"Collection preferences unavailable." end
    return true
end

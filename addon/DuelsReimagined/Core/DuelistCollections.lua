local _,ns=...
-- Cosmetic rewards derive from the same achievement evaluator as titles.
-- Only selected IDs are persisted, never a second unlock ledger.
local K={};ns.DuelistCollections=K
-- Client-owned Warcraft artwork: use the game files, never redistribute them.
-- The fixed specialization IDs and atlas keys match Blizzard's ClassSpecializationsFrame.
-- Legacy trees are the supported Forever talent families, not Retail-only classes.
local catalog={}
local function Background(id,name,group,achievement,art,retailOnly,foreverName)
    catalog[#catalog+1]={"background",id,name,achievement,nil,nil,nil,
        group=group,art=art,retailOnly=retailOnly,foreverName=foreverName}
end
Background("bronze","Classic Bronze","Default",nil,{color={.065,.055,.048}})
Background("faction","Faction Pride (Auto)","Faction",nil,{autoFaction=true})
Background("alliance","Alliance Pride","Faction",nil,{faction="Alliance",native={
    "Interface\\Glues\\LOADINGSCREENS\\LoadScreen_AllianceGarrison","Interface\\PVPFrame\\PvPQueueBackgroundAlliance"}})
Background("horde","Horde Pride","Faction",nil,{faction="Horde",native={
    "Interface\\Glues\\LOADINGSCREENS\\LoadingScreen_HordeGarrison","Interface\\PVPFrame\\PvPQueueBackgroundHorde"}})
local function Spec(class,key,id,spec,atlas,legacy,icon,retailOnly,foreverName)
    Background("spec-"..id,spec.." "..class,class,nil,{
        atlas="spec-thumbnail-"..key.."-"..atlas,
        native=legacy and {"Interface\\TalentFrame\\"..legacy.."-TopLeft"} or nil,
        icon="Interface\\Icons\\"..icon,
        spec=id,
    },retailOnly,foreverName)
end
Spec("Warrior","warrior",71,"Arms","arms","WarriorArms","Ability_Warrior_SavageBlow")
Spec("Warrior","warrior",72,"Fury","fury","WarriorFury","Ability_Warrior_InnerRage")
Spec("Warrior","warrior",73,"Protection","protection","WarriorProtection","Ability_Warrior_DefensiveStance")
Spec("Paladin","paladin",65,"Holy","holy","PaladinHoly","Spell_Holy_HolyBolt")
Spec("Paladin","paladin",66,"Protection","protection","PaladinProtection","Spell_Holy_DevotionAura")
Spec("Paladin","paladin",70,"Retribution","retribution","PaladinCombat","Spell_Holy_AuraOfLight")
Spec("Hunter","hunter",253,"Beast Mastery","beastmastery","HunterBeastMastery","Ability_Hunter_BeastTaming")
Spec("Hunter","hunter",254,"Marksmanship","marksmanship","HunterMarksmanship","Ability_Hunter_FocusedAim")
Spec("Hunter","hunter",255,"Survival","survival","HunterSurvival","Ability_Hunter_SwiftStrike")
Spec("Rogue","rogue",259,"Assassination","assassination","RogueAssassination","Ability_Rogue_Eviscerate")
Spec("Rogue","rogue",260,"Outlaw","outlaw","RogueCombat","Ability_BackStab",false,"Combat Rogue")
Spec("Rogue","rogue",261,"Subtlety","subtlety","RogueSubtlety","Ability_Stealth")
Spec("Priest","priest",256,"Discipline","discipline","PriestDiscipline","Spell_Holy_WordFortitude")
Spec("Priest","priest",257,"Holy","holy","PriestHoly","Spell_Holy_GuardianSpirit")
Spec("Priest","priest",258,"Shadow","shadow","PriestShadow","Spell_Shadow_ShadowWordPain")
Spec("Shaman","shaman",262,"Elemental","elemental","ShamanElementalCombat","Spell_Nature_Lightning")
Spec("Shaman","shaman",263,"Enhancement","enhancement","ShamanEnhancement","Spell_Nature_LightningShield")
Spec("Shaman","shaman",264,"Restoration","restoration","ShamanRestoration","Spell_Nature_MagicImmunity")
Spec("Mage","mage",62,"Arcane","arcane","MageArcane","Spell_Holy_MagicalSentry")
Spec("Mage","mage",63,"Fire","fire","MageFire","Spell_Fire_FireBolt02")
Spec("Mage","mage",64,"Frost","frost","MageFrost","Spell_Frost_FrostBolt02")
Spec("Warlock","warlock",265,"Affliction","affliction","WarlockCurses","Spell_Shadow_DeathCoil")
Spec("Warlock","warlock",266,"Demonology","demonology","WarlockSummoning","Spell_Shadow_Metamorphosis")
Spec("Warlock","warlock",267,"Destruction","destruction","WarlockDestruction","Spell_Shadow_RainOfFire")
Spec("Druid","druid",102,"Balance","balance","DruidBalance","Spell_Nature_StarFall")
Spec("Druid","druid",103,"Feral","feral","DruidFeralCombat","Ability_Druid_CatForm",false,"Feral Combat Druid")
Spec("Druid","druid",104,"Guardian","guardian",nil,"Ability_Racial_BearForm",true)
Spec("Druid","druid",105,"Restoration","restoration","DruidRestoration","Spell_Nature_HealingTouch")
Spec("Death Knight","deathknight",250,"Blood","blood",nil,"Spell_Deathknight_BloodPresence",true)
Spec("Death Knight","deathknight",251,"Frost","frost",nil,"Spell_Deathknight_FrostPresence",true)
Spec("Death Knight","deathknight",252,"Unholy","unholy",nil,"Spell_Deathknight_UnholyPresence",true)
Spec("Monk","monk",268,"Brewmaster","brewmaster",nil,"Spell_Monk_Brewmaster_Spec",true)
Spec("Monk","monk",270,"Mistweaver","mistweaver",nil,"Spell_Monk_Mistweaver_Spec",true)
Spec("Monk","monk",269,"Windwalker","windwalker",nil,"Spell_Monk_Windwalker_Spec",true)
Spec("Demon Hunter","demonhunter",577,"Havoc","havoc",nil,"Ability_DemonHunter_SpecDPS",true)
Spec("Demon Hunter","demonhunter",581,"Vengeance","vengeance",nil,"Ability_DemonHunter_SpecTank",true)
Spec("Demon Hunter","demonhunter",1480,"Devourer","devourer",nil,"Ability_DemonHunter_SpecDPS",true)
Spec("Evoker","evoker",1467,"Devastation","devastation",nil,"ClassIcon_Evoker",true)
Spec("Evoker","evoker",1468,"Preservation","preservation",nil,"ClassIcon_Evoker",true)
Spec("Evoker","evoker",1473,"Augmentation","augmentation",nil,"ClassIcon_Evoker",true)
local ej="Interface\\EncounterJournal\\"
local loading="Interface\\Glues\\LOADINGSCREENS\\"
local function Lore(id,name,group,achievement,scene,load,figure,icon)
    local files={}
    if scene then files[#files+1]=ej.."UI-EJ-BACKGROUND-"..scene;files[#files+1]=ej.."UI-EJ-LOREBG-"..scene end
    if load then files[#files+1]=loading..load end
    Background(id,name,group,achievement,{native=files,
        figure=figure and ej.."UI-EJ-BOSS-"..figure or nil,
        icon="Interface\\Icons\\"..icon})
end
-- The six original IDs keep their original eligibility and saved selection.
-- Changing their visuals does not re-lock a player's earned reward.
Lore("blood","Blackrock Depths","Lore","rising","BlackrockDepths","LoadScreenBlackrockDepths",nil,"INV_Sword_04")
Lore("inferno","Frozen Throne","Lore","seasoned","IcecrownCitadel","LoadScreenIcecrownCitadel","Lich King","INV_Sword_2H_Arthas_D_01")
Lore("frost","Icecrown Citadel","Lore","unstoppable","IcecrownCitadel","LoadScreenIcecrownCitadel",nil,"Spell_Frost_FrostNova")
Lore("shadow","Banshee's Fall","Lore","conqueror","HallsofReflection","LoadScreenHallsofReflection","SylvanasWindrunner","Ability_Hunter_BlackArrow")
Lore("celestial","Emerald Dream","Lore","born",nil,"LoadingScreen_EmeraldDreamway_wide",nil,"Spell_Nature_HealingTouch")
Lore("glory","Eternal Glory","Legacy","legend","TrialoftheCrusader","LoadScreenNagrandArenaBattlegrounds",nil,"INV_Crown_01")
Lore("black-temple","Black Temple","Lore","master","BlackTemple","LoadScreenBlackTemple","Illidan Stormrage","Ability_DemonHunter_GlaiveThrow")
Lore("molten-core","Molten Core","Lore","spree","MoltenCore","LoadScreenMoltenCore","Ragnaros","Spell_Fire_Fire")
Lore("naxxramas","Naxxramas","Lore","dedicated","Naxxramas","LoadScreenNaxxramas",nil,"Spell_Shadow_AnimateDead")
Lore("sunwell","Sunwell Radiance","Lore","duelist","SunwellPlateau","LOADSCREENSUNWELL",nil,"Spell_Holy_HolyBolt")
Lore("ulduar","Ulduar Forge","Lore","warveteran","Ulduar","LOADSCREENULDUARRAID",nil,"INV_Misc_Gear_01")
Lore("coliseum","Champion's Coliseum","Tournament","tourwin","TrialOfTheChampion",nil,nil,"INV_Misc_Trophy_01")
Lore("grandmaster","Grandmaster's Legacy","Competitive","grandmaster",nil,"LoadScreenTolvirArena",nil,"INV_Crown_01")
Lore("gladiator","Gladiator's Arena","Competitive","rated",nil,"LoadingScreen_NagrandArena_wide",nil,"INV_Shield_05")
Lore("nether","Twisting Nether","Lore","rankedrivals","Argus",nil,"ArgustheUnmaker","Spell_Shadow_Metamorphosis")
Lore("dalaran","Dalaran Arena","Zones","challenger",nil,"LoadScreenDalaranSewersArena",nil,"Spell_Holy_MagicalSentry")
local borders={
    {"border","bronze","Classic Bronze",nil,nil,{.63,.43,.23},{.29,.19,.10}},
    {"border","iron","Battle Forged","tested",nil,{.62,.65,.69},{.25,.28,.31}},
    {"border","blood","Bloodforged","spree",nil,{.88,.27,.15},{.40,.12,.08}},
    {"border","frost","Frostbound","untouchable",nil,{.37,.78,1},{.12,.31,.52}},
    {"border","champion","Golden Champion","tourwin",nil,{1,.76,.27},{.47,.31,.09}},
    {"border","grandmaster","Grandmaster's Legacy","grandmaster",nil,{.82,.48,1},{.34,.15,.55}},
}
for _,d in ipairs(borders) do catalog[#catalog+1]=d end
local function Client()
    return ns.Client and ns.Client.Kind and ns.Client.Kind() or "unsupported"
end
local function Supported(d,client)
    if not d then return false end
    if d.art and d.art.spec then
        return client=="retail" or (client=="forever" and not d.retailOnly)
    end
    return true
end
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
function K.IsSupported(kind,id,client)
    return K.IsKnown(kind,id) and Supported(index[kind][id],client or Client())
end
local function Copy(d,client)
    if not d then return nil end
    local r={kind=d[1],id=d[2],name=client=="forever" and d.foreverName or d[3],
        achievement=d[4],group=d.group,color=d[6] and {unpack(d[6])},accent=d[7] and {unpack(d[7])}}
    if d.art then
        for k,v in pairs(d.art) do r[k]=type(v)=="table" and {unpack(v)} or v end
        -- Classic Combat and Feral Combat use their actual legacy tree art
        -- rather than displaying Retail's pirate or separate Guardian identity.
        if client=="forever" and (r.spec==260 or r.spec==103) then r.atlas=nil end
    end
    return r
end
function K.Art(kind,id)
    local client=Client()
    return K.IsSupported(kind,id,client) and Copy(index[kind][id],client) or nil
end
function K.Groups(model)
    local available={}
    for _,r in ipairs(model and model.rows or {}) do if r.kind=="background" then available[r.group]=true end end
    local out={{key="All",label="All backgrounds"},{key="spec",label="All class / spec"}}
    for _,key in ipairs({"Default","Faction","Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid",
        "Death Knight","Monk","Demon Hunter","Evoker","Lore","Zones","Competitive","Tournament","Legacy"}) do
        if available[key] then out[#out+1]={key=key,label=key} end
    end
    return out
end
function K.InGroup(row,group)
    return group=="All" or (group=="spec" and row.spec~=nil) or row.group==group
end
function K.Default(kind)
    if kind=="background" then
        return ns.Settings and ns.Settings.Get and ns.Settings.Get("profileFactionBackdrop")==false and "bronze" or "faction"
    end
    return "bronze"
end
function K.Model(data,titleModel)
    local scope=data and data.scope or "LOCAL"
    local client=Client()
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
        if Supported(d,client) then
        local r=Copy(d,client)
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
    if id~=nil and not K.IsSupported(kind,id) then return false,"This collectible is unavailable on your client." end
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

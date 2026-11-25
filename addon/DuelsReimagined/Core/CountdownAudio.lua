local _,ns=...
-- One owner for countdown media and its single native sound handle.
-- Playback is driven by the existing countdown controller, not a timer.
local A={};ns.CountdownAudio=A
local Settings=ns.Settings
local BASE="Interface\\AddOns\\DuelsReimagined_CountdownSounds\\Sounds\\"
local TICK="Interface\\AddOns\\DuelsReimagined\\Media\\Sounds\\CountdownTick.mp3"
local DEFAULT="builtin:tick"
local groups,available={},{}
local manifest=DuelsReimaginedCountdownSoundPacks
if type(manifest)=="table" and manifest.version==1 and type(manifest.groups)=="table" then
    local count=0
    for i,g in ipairs(manifest.groups) do
        if i>24 or count>=512 then break end
        if type(g)=="table" and type(g.label)=="string" and #g.label<=64 and type(g.packs)=="table" then
            local group={label=g.label,key="group:"..i,packs={}}
            for _,p in ipairs(g.packs) do
                if count>=512 then break end
                if type(p)=="table" and type(p.key)=="string" and #p.key<=120 and
                    p.key:match("^[%w _%-]+/?[%w _%-]*$") and type(p.label)=="string" and #p.label<=80 then
                    local key="pack:"..p.key
                    if not available[key] then
                        local entry={key=key,label=p.label,displayLabel=g.label.." / "..p.label,group=group.key,
                            folder=BASE..p.key:gsub("/","\\").."\\"}
                        available[key]=entry;group.packs[#group.packs+1]=entry;count=count+1
                    end
                end
            end
            if #group.packs>0 then groups[#groups+1]=group end
        end
    end
end
function A.IsAvailable(key)
    return key==DEFAULT or available[key]~=nil
end
function A.GetChoices(selected)
    local out={{key=DEFAULT,label="Duels - Metallic Tick"}}
    for _,g in ipairs(groups) do
        out[#out+1]={key=g.key,label=g.label.." ("..#g.packs..")",heading=true}
        for _,p in ipairs(g.packs) do
            out[#out+1]={key=p.key,label=p.label,displayLabel=p.displayLabel,group=p.group}
        end
    end
    if selected and not A.IsAvailable(selected) then
        out[#out+1]={key=selected,label=selected:gsub("^pack:","").." (unavailable)"}
    end
    return out
end
-- Same optional media manifest, independent selection and a single handle.
local fightPacks,fightOrder={},{}
local FIGHT_BASE="Interface\\AddOns\\DuelsReimagined_CountdownSounds\\Fight\\"
if type(manifest)=="table" and manifest.version==1 and type(manifest.fight)=="table" then
    for i,p in ipairs(manifest.fight) do
        if i>128 then break end
        if type(p)=="table" and type(p.key)=="string" and #p.key<=80 and p.key:match("^[%w_%-]+$") and
            type(p.label)=="string" and #p.label<=80 and type(p.category)=="string" and #p.category<=64 and
            type(p.duration)=="number" and p.duration>=.05 and p.duration<=5 then
            local key="fight:"..p.key
            if not fightPacks[key] then
                local entry={key=key,label=p.label,category=p.category,duration=p.duration,path=FIGHT_BASE..p.key..".ogg"}
                fightPacks[key]=entry;fightOrder[#fightOrder+1]=entry
            end
        end
    end
end
function A.IsFightAvailable(key) return key==DEFAULT or fightPacks[key]~=nil end
function A.GetFightChoices(selected)
    local out={{key=DEFAULT,label="Duels - Metallic Tick"}}
    local cats,order={},{}
    for _,p in ipairs(fightOrder) do
        if not cats[p.category] then cats[p.category]={};order[#order+1]=p.category end
        local list=cats[p.category];list[#list+1]=p
    end
    for i,category in ipairs(order) do
        local group="fightgroup:"..i
        out[#out+1]={key=group,label=category,heading=true}
        for _,p in ipairs(cats[category]) do
            out[#out+1]={key=p.key,label=p.label,group=group,displayLabel=p.label}
        end
    end
    if selected and not A.IsFightAvailable(selected) then
        out[#out+1]={key=selected,label=(selected=="fight:mortal_kombat" and "Mortal Kombat" or selected:gsub("^fight:","")).." (pack unavailable)"}
    end
    return out
end
local handle,kind
function A.Stop(which)
    if which and which~=kind then return end
    local old=handle;handle=nil;kind=nil
    if old and type(StopSound)=="function" then pcall(StopSound,old,0) end
end
local function PlayPath(path,channel,owner)
    if type(PlaySoundFile)~="function" then return false end
    local ok,played,id=pcall(PlaySoundFile,path,channel)
    if not ok then return false end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,played)
        if not safe or secret then return false end
        safe,secret=pcall(issecretvalue,id)
        if not safe or secret then id=nil end
    end
    if played==true then
        kind=owner
        if type(id)=="number" then handle=id end
    end
    return played==true
end
function A.Play(stage)
    A.Stop()
    if stage~=1 and stage~=2 and stage~=3 then return false end
    if not Settings.Get("duelCountdownVisual") or not Settings.Get("duelCountdownSounds") then return false end
    local choice=available[Settings.Get("duelCountdownSoundPack")]
    return PlayPath(choice and choice.folder..stage..".ogg" or TICK,Settings.Get("duelCountdownAudioChannel") or "SFX","countdown")
end
function A.PlayFight()
    A.Stop()
    if not Settings.Get("duelCountdownVisual") or not Settings.Get("duelFightSounds") then return nil end
    local choice=fightPacks[Settings.Get("duelFightSoundPack")]
    if PlayPath(choice and choice.path or TICK,Settings.Get("duelFightAudioChannel") or "SFX","fight") then
        return choice and choice.duration or .5
    end
end
function A.GetDiagnosticResources()
    return {handles=handle and 1 or 0,timers=0}
end

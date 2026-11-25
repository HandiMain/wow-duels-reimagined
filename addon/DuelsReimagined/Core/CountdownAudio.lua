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
local handle
function A.Stop()
    local old=handle;handle=nil
    if old and type(StopSound)=="function" then pcall(StopSound,old,0) end
end
function A.Play(stage)
    A.Stop()
    if stage~=1 and stage~=2 and stage~=3 then return false end
    if not Settings.Get("duelCountdownVisual") or not Settings.Get("duelCountdownSounds") then return false end
    local choice=available[Settings.Get("duelCountdownSoundPack")]
    local path=choice and choice.folder..stage..".ogg" or TICK
    local channel=Settings.Get("duelCountdownAudioChannel") or "SFX"
    if type(PlaySoundFile)~="function" then return false end
    local ok,played,id=pcall(PlaySoundFile,path,channel)
    if not ok then return false end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,played)
        if not safe or secret then return false end
        safe,secret=pcall(issecretvalue,id)
        if not safe or secret then id=nil end
    end
    if played==true and type(id)=="number" then handle=id end
    return played==true
end
function A.GetDiagnosticResources()
    return {handles=handle and 1 or 0,timers=0}
end

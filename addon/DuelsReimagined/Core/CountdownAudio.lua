local _,ns=...
-- One owner for countdown media and its single native sound handle.
-- Playback is driven by the existing countdown controller, not a timer.
local A={};ns.CountdownAudio=A
local Settings=ns.Settings
local TICK="Interface\\AddOns\\DuelsReimagined\\Media\\Sounds\\CountdownTick.mp3"
local DEFAULT="builtin:tick"
local PACK_ADDON="DuelsReimagined_SoundPacks"
local LEGACY_ADDON="DuelsReimagined_CountdownSounds"
local ADDON_ROOT="Interface\\AddOns\\"
local groups,available,fightPacks,fightOrder={},{},{},{}
local resultPacks,resultOrder={victory={},defeat={}},{victory={},defeat={}}
local previous,previousGroups,previousFight,previousResults,previousAddon=false
-- Media-only addon can finish loading after this file. Rebuild only when
-- its manifest or section tables actually change, never on a frame tick.
local function RefreshCatalog()
    -- Prefer the renamed pack; retain the old folder during migration.
    local modern=type(DuelsReimaginedSoundPacks)=="table" and DuelsReimaginedSoundPacks.version==1
    local manifest=modern and DuelsReimaginedSoundPacks or DuelsReimaginedCountdownSoundPacks
    local source=modern and PACK_ADDON or LEGACY_ADDON
    local root=ADDON_ROOT..source.."\\"
    local BASE=root..(modern and "Countdown\\" or "Sounds\\")
    local FIGHT_BASE=root.."Fight\\"
    local g=type(manifest)=="table" and manifest.groups
    local f=type(manifest)=="table" and manifest.fight
    local results=type(manifest)=="table" and manifest.results
    if manifest==previous and g==previousGroups and f==previousFight and results==previousResults and source==previousAddon then return false end
    previous,previousGroups,previousFight,previousResults,previousAddon=manifest,g,f,results,source
    groups,available,fightPacks,fightOrder={},{},{},{}
    resultPacks,resultOrder={victory={},defeat={}},{victory={},defeat={}}
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
    if type(manifest)=="table" and manifest.version==1 and type(results)=="table" then
        for _,kind in ipairs({"victory","defeat"}) do
            if type(results[kind])=="table" then
                for i,p in ipairs(results[kind]) do
                    if i>128 then break end
                    if type(p)=="table" and type(p.key)=="string" and #p.key<=80 and p.key:match("^[%w_%-]+$") and
                        type(p.label)=="string" and #p.label<=80 and type(p.duration)=="number" and
                        p.duration>=.05 and p.duration<=5.3 then
                        local key=kind..":"..p.key
                        if not resultPacks[kind][key] then
                            local folder=modern and (kind=="victory" and "Victory" or "Defeat") or ("Results\\"..kind)
                            local entry={key=key,label=p.label,path=root..folder.."\\"..p.key..".ogg"}
                            resultPacks[kind][key]=entry;resultOrder[kind][#resultOrder[kind]+1]=entry
                        end
                    end
                end
            end
        end
    end
    return true
end
-- SharedMedia registers individual sound names, not three-number packs.
-- Resolve exact names from its registry without substituting a library default.
-- Do not copy third-party assets, or require a particular sound-pack addon.
local function SharedLibrary()
    if type(LibStub)~="function" and type(LibStub)~="table" then return nil end
    local ok,lib=pcall(function()return LibStub("LibSharedMedia-3.0",true)end)
    if ok and type(lib)=="table" then return lib end
end
local function SharedName(key)
    if type(key)=="string" and #key>4 and #key<=128 and key:sub(1,4)=="lsm:" and not key:find("%c") then
        return key:sub(5)
    end
end
local function SharedPath(key,lib)
    local name=SharedName(key)
    if not name then return nil end
    lib=lib or SharedLibrary()
    if not lib then return nil end
    local ok,path
    if type(lib.HashTable)=="function" then
        local registered
        ok,registered=pcall(lib.HashTable,lib,"sound")
        if ok and type(registered)=="table" then path=registered[name] end
    elseif type(lib.Fetch)=="function" then
        ok,path=pcall(lib.Fetch,lib,"sound",name,true)
    end
    if ok and type(path)=="string" and path~="" then return path end
end
local function SharedChoices()
    local lib=SharedLibrary()
    local out,seen={},{}
    if not lib or type(lib.List)~="function" then return out end
    local ok,names=pcall(lib.List,lib,"sound")
    if not ok or type(names)~="table" then return out end
    for _,name in ipairs(names) do
        if type(name)=="string" then
            local key="lsm:"..name
            if not seen[key] and SharedPath(key,lib) then
                seen[key]=true
                out[#out+1]={key=key,label=name,displayLabel=name,group="sharedmedia:sounds"}
            end
        end
    end
    table.sort(out,function(a,b)
        local x,y=a.label:lower(),b.label:lower()
        if x==y then return a.label<b.label end
        return x<y
    end)
    return out
end
local function AppendShared(out)
    local choices=SharedChoices()
    if #choices>0 then
        out[#out+1]={key="sharedmedia:sounds",label="SharedMedia ("..#choices..")",heading=true}
        for _,choice in ipairs(choices) do out[#out+1]=choice end
    end
end
function A.GetSharedSoundCount() return #SharedChoices() end
function A.IsAvailable(key)
    RefreshCatalog()
    return key==DEFAULT or available[key]~=nil or SharedPath(key)~=nil
end
function A.GetChoices(selected)
    RefreshCatalog()
    local out={{key=DEFAULT,label="Duels - Metallic Tick"}}
    for _,g in ipairs(groups) do
        out[#out+1]={key=g.key,label=g.label.." ("..#g.packs..")",heading=true}
        for _,p in ipairs(g.packs) do
            out[#out+1]={key=p.key,label=p.label,displayLabel=p.displayLabel,group=p.group}
        end
    end
    AppendShared(out)
    if selected and not A.IsAvailable(selected) then
        out[#out+1]={key=selected,label=(SharedName(selected) or selected:gsub("^pack:","")).." (unavailable)"}
    end
    return out
end
function A.IsFightAvailable(key)
    RefreshCatalog()
    return key==DEFAULT or fightPacks[key]~=nil or SharedPath(key)~=nil
end
function A.GetFightChoices(selected)
    RefreshCatalog()
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
    AppendShared(out)
    if selected and not A.IsFightAvailable(selected) then
        local name=SharedName(selected)
        out[#out+1]={key=selected,label=name and (name.." (unavailable)") or (selected=="fight:mortal_kombat" and "Mortal Kombat" or selected:gsub("^fight:","")).." (pack unavailable)"}
    end
    return out
end
function A.IsResultAvailable(kind,key)
    RefreshCatalog()
    return resultPacks[kind]~=nil and (key==DEFAULT or resultPacks[kind][key]~=nil or SharedPath(key)~=nil)
end
function A.GetResultChoices(kind,selected)
    RefreshCatalog()
    local out={{key=DEFAULT,label="Duels - Metallic Tick"}}
    local choices=resultOrder[kind] or {}
    if #choices>0 then
        local group="result:"..kind
        out[#out+1]={key=group,label=kind=="victory" and "Victory sounds" or "Defeat sounds",heading=true}
        for _,p in ipairs(choices) do out[#out+1]={key=p.key,label=p.label,group=group,displayLabel=p.label} end
    end
    AppendShared(out)
    if selected and not A.IsResultAvailable(kind,selected) then
        local name=SharedName(selected) or selected:gsub("^"..kind..":",""):gsub("^(%a+)(%d+)$","%1 %2")
        out[#out+1]={key=selected,label=name.." (unavailable)"}
    end
    return out
end
function A.GetResultSoundCounts()
    RefreshCatalog()
    return #resultOrder.victory,#resultOrder.defeat
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
    RefreshCatalog()
    local key=Settings.Get("duelCountdownSoundPack")
    local choice=available[key]
    local path=SharedPath(key) or (choice and choice.folder..stage..".ogg") or TICK
    return PlayPath(path,Settings.Get("duelCountdownAudioChannel") or "SFX","countdown")
end
function A.PlayFight()
    A.Stop()
    if not Settings.Get("duelCountdownVisual") or not Settings.Get("duelFightSounds") then return nil end
    RefreshCatalog()
    local key=Settings.Get("duelFightSoundPack")
    local choice=fightPacks[key]
    local shared=SharedPath(key)
    if PlayPath(shared or (choice and choice.path) or TICK,Settings.Get("duelFightAudioChannel") or "SFX","fight") then
        -- SharedMedia supplies no duration metadata. Keep the existing bounded
        -- stage timer and allow up to five seconds for an arbitrary clip.
        return shared and 4.95 or choice and choice.duration or .5
    end
end
function A.PlayResult(which)
    if not resultPacks[which] then return false end
    local prefix=which=="victory" and "duelVictory" or "duelDefeat"
    if Settings.Get("duelResultVisual")~=true or Settings.Get(prefix.."Sounds")~=true then return false end
    RefreshCatalog()
    local key=Settings.Get(prefix.."SoundPack")
    local choice=resultPacks[which][key]
    A.Stop()
    return PlayPath(SharedPath(key) or (choice and choice.path) or TICK,
        Settings.Get(prefix.."AudioChannel") or "SFX",which)
end
function A.GetDiagnosticResources()
    return {handles=handle and 1 or 0,timers=0}
end

-- Inspect the actual catalogue, not inferred file availability. Optional
-- media never blocks the main addon or causes an automatic enable.
function A.GetPackStatus()
    RefreshCatalog()
    local countdown=0
    for _,group in ipairs(groups) do countdown=countdown+#group.packs end
    local fight=#fightOrder
    if countdown>0 and fight>0 then return "ready",countdown,fight,previousAddon==PACK_ADDON and "Sound pack manifest detected" or "Legacy sound pack detected; replace with DuelsReimagined_SoundPacks" end
    if countdown>0 then return "older",countdown,fight,"Countdown pack detected; install the updated pack for FIGHT! sounds" end
    if fight>0 then return "partial",countdown,fight,"FIGHT! pack detected; countdown packs unavailable" end
    local api=C_AddOns
    if api and type(api.IsAddOnLoaded)=="function" then
        local ok,loaded=pcall(api.IsAddOnLoaded,PACK_ADDON)
        if ok and loaded==true then return "invalid",0,0,"Sound pack loaded but manifest missing or invalid" end
    end
    if api and type(api.GetAddOnInfo)=="function" then
        local ok,name,_,_,_,reason=pcall(api.GetAddOnInfo,PACK_ADDON)
        if ok and type(reason)=="string" and reason=="DISABLED" then
            return "disabled",0,0,"Enable Duels Reimagined - Sound Packs in AddOns"
        elseif ok and type(reason)=="string" and reason=="INTERFACE_VERSION" then
            return "not_loaded",0,0,"Sound pack interface version is outdated; check AddOns"
        elseif ok and type(name)=="string" and name==PACK_ADDON then
            return "not_loaded",0,0,"Sound pack installed but not loaded; enable it and restart WoW"
        end
    end
    return "missing",0,0,"Sound pack not detected; check AddOns and folder installation"
end
-- AddOn dependencies normally load first. On clients with a different
-- sequence, refresh the existing Options controls once the pack registers.
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(self,event,name)
    if event=="ADDON_LOADED" and name~=PACK_ADDON and name~=LEGACY_ADDON then return end
    if event=="PLAYER_LOGIN" then self:UnregisterEvent("PLAYER_LOGIN") end
    local changed=RefreshCatalog()
    if changed and ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
end)

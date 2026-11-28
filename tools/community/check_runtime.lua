-- Runtime contract smoke checks for code shipped inside the addon.
-- Uses minimal stubs, not a fake WoW UI environment.
local function Check(value, message)
    if not value then error(message, 2) end
end

-- Client identity is independent of any UI or SavedVariables.
-- Mock the fourth value of GetBuildInfo (interface number) for each client.
local originalGetBuildInfo = _G.GetBuildInfo
local function ClientFor(interface)
    local scope = {}
    if interface == "missing" then
        _G.GetBuildInfo = nil
    else
        _G.GetBuildInfo = function()
            if interface == "error" then error("GetBuildInfo unavailable") end
            return "mock", "mock", "mock", interface
        end
    end
    local chunk = assert(loadfile("addon/DuelsReimagined/Core/Client.lua"))
    chunk("DuelsReimagined", scope)
    return scope.Client
end
local retail = ClientFor(120105)
Check(retail.Kind() == "retail" and retail.IsRetail() and not retail.IsForever()
    and retail.IsSupported(), "Retail must be recognized")
local retailText = ClientFor("120105")
Check(retailText.IsRetail(), "String-encoded Retail interface must be recognized")
local forever = ClientFor(16001)
Check(forever.Kind() == "forever" and forever.IsForever() and not forever.IsRetail()
    and forever.IsSupported(), "Forever must be recognized")
for _, iface in ipairs({ 11507, 50500, 12000, "invalid", "missing", "error" }) do
    local other = ClientFor(iface)
    Check(other.Kind() == "unsupported" and not other.IsRetail()
        and not other.IsForever() and not other.IsSupported(),
        "Unknown interface must fail closed: " .. tostring(iface))
end
_G.GetBuildInfo = originalGetBuildInfo

local ns = {}
local searchChunk = assert(loadfile("addon/DuelsReimagined/UI/Search.lua"))
searchChunk("DuelsReimagined", ns)
local Search = ns.Search
local chosen = nil
for i = 1, 9 do
    local number = i
    Search.Register("test:" .. number, "Searchable item " .. number,
        "Harness", "More test words", function() chosen = number end)
end
Search.Register("test:unavailable", "Searchable disabled action",
    "Harness", "Cannot use now", function() error("should never activate") end,
    function() return false end)
Search.Register("test:error", "Searchable broken action",
    "Harness", "Availability callback errors", function() error("should never activate") end,
    function() error("fault inside checker") end)

local matches = Search.Query("Searchable")
Check(#matches == 9, "Search must return all nine available results (no silent 6-cap)")
for _, item in ipairs(matches) do
    Check(item.title ~= "Searchable disabled action", "Unavailable action leaked")
    Check(item.title ~= "Searchable broken action", "Errored availability leaked")
end
Check(Search.Open(matches[7]) == true, "Search action should open")
Check(chosen ~= nil, "Search callback did not fire")
Check(Search.Query("no matching query")[1] == nil, "Search should return no matches")
Check(Search.Query("searchable ITEM")[1] ~= nil, "Search normalization failed")

-- Settings storage and reload-button contract.
local loader
_G.DuelsReimaginedDB = { showInCompartment = false }
_G.CreateFrame = function()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(name, callback)
        self.scripts[name] = callback
    end
    loader = frame
    return frame
end
local settingsChunk = assert(loadfile("addon/DuelsReimagined/Core/Settings.lua"))
settingsChunk("DuelsReimagined", ns)
local Settings = ns.Settings
Settings.RegisterReloadRequired("showInCompartment")
Check(type(loader.scripts.OnEvent) == "function", "ADDON_LOADED handler missing")
loader.scripts.OnEvent(loader, "ADDON_LOADED", "DuelsReimagined")
Check(Settings.Get("showInCompartment") == false, "Saved false compartment setting lost")
Check(not Settings.NeedsReload(), "Correct saved startup setting should not need reload")
Settings.Set("showInCompartment", true)
Check(Settings.NeedsReload(), "Compartment change should require reload")
Settings.Reset("showInCompartment")
Check(Settings.Get("showInCompartment") == true, "Compartment reset should restore true default")
Check(Settings.NeedsReload(), "Reset from saved false still needs reload")
Settings.Set("showInCompartment", false)
Check(not Settings.NeedsReload(), "Returning to original startup choice should clear reload")
print("Search and SavedVariables runtime contracts: PASS")


-- Access appearance settings: isolate SavedVariables and verify the default
-- transition, live callback, independent modes, and reset behavior.
local originalDB = _G.DuelsReimaginedDB
local updates, modified, fullRefresh, peekRefresh = 0, 0, 0, 0
_G.DuelsReimaginedDB = {}
ns.AccessIcons = { Refresh=function() updates=updates+1 end }
ns.Options = { RefreshAccessModified=function() modified=modified+1 end,
               Refresh=function() fullRefresh=fullRefresh+1 end }
ns.Header = { RefreshAutoPeek=function() peekRefresh=peekRefresh+1 end }
Check(Settings.GetDefault("autoPeekMoving")==true and Settings.Get("autoPeekMoving")==true,
    "Auto Peek defaults on")
Check(not Settings.IsModified("autoPeekMoving"), "default ON is not modified")
Settings.Set("autoPeekMoving",false)
Check(Settings.Get("autoPeekMoving")==false and Settings.IsModified("autoPeekMoving"),
    "OFF is modified and must expose reset")
Check(peekRefresh==1,"peek reacts to change")
Settings.Reset("autoPeekMoving")
Check(Settings.Get("autoPeekMoving") and not Settings.IsModified("autoPeekMoving"),
    "reset restores ON")
Check(peekRefresh==2,"peek reacts to reset")
Check(Settings.Get("minimapSize")==36 and Settings.Get("minimapTransparency")==0,
    "minimap defaults")
local before=fullRefresh
Settings.Set("minimapSize",51)
Settings.Set("minimapTransparency",0.42)
Check(Settings.Get("minimapSize")==52 and math.abs(Settings.Get("minimapTransparency")-0.4)<0.001,
    "minimap values normalize to slider steps")
Check(Settings.Get("widgetSize")==42 and Settings.Get("widgetTransparency")==0,
    "minimap must not modify widget")
Check(updates==2 and modified==2 and fullRefresh==before,
    "live sliders refresh access icons and markers without full page refresh")
Settings.Set("widgetSize",80)
Settings.Set("widgetTransparency",0.65)
for _,mode in ipairs({"widget","both","none","minimap"}) do
    Settings.Set("iconMode",mode)
    Check(Settings.Get("minimapSize")==52 and Settings.Get("widgetSize")==80,
        "switching modes preserves independent sizes")
    Check(math.abs(Settings.Get("minimapTransparency")-0.4)<0.001 and
          math.abs(Settings.Get("widgetTransparency")-0.65)<0.001,
        "switching modes preserves independent opacity")
end
Settings.Set("minimapSize",1000)
Settings.Set("minimapTransparency",2)
Check(Settings.Get("minimapSize")==64 and Settings.Get("minimapTransparency")==0.90,
    "clamp upper minimap bounds")
Settings.Set("minimapSize",-100)
Settings.Set("minimapTransparency",-2)
Check(Settings.Get("minimapSize")==24 and Settings.Get("minimapTransparency")==0,
    "clamp lower minimap bounds")
_G.DuelsReimaginedDB.minimapSize="invalid"
_G.DuelsReimaginedDB.minimapTransparency=0/0
Check(Settings.Get("minimapSize")==36 and Settings.Get("minimapTransparency")==0,
    "invalid saved minimap settings use defaults")
Settings.Set("minimapSize",60)
Settings.Set("minimapTransparency",0.8)
Settings.Reset("minimapSize")
Settings.Reset("minimapTransparency")
Check(not Settings.IsModified("minimapSize") and not Settings.IsModified("minimapTransparency"),
    "individual minimap resets")
Check(Settings.Get("widgetSize")==80 and math.abs(Settings.Get("widgetTransparency")-0.65)<0.001,
    "minimap reset does not reset widget")
_G.DuelsReimaginedDB.autoPeekMoving=false
Check(Settings.Get("autoPeekMoving")==false and Settings.IsModified("autoPeekMoving"),
    "existing explicit OFF remains saved and resettable")
Check(Settings.Get("duelHUDAdaptive")==true and Settings.Get("duelHUDOpacity")==1,"HUD defaults")
local opacityChanges,hudChanges=0,0
ns.DuelHUD={ApplyOpacity=function() opacityChanges=opacityChanges+1 end,Refresh=function()hudChanges=hudChanges+1 end}
Settings.Set("duelHUDOpacity",.63)
Check(Settings.Get("duelHUDOpacity")==.65 and Settings.IsModified("duelHUDOpacity"),"HUD opacity step")
Settings.Set("duelHUDOpacity",-1);Check(Settings.Get("duelHUDOpacity")==.3,"HUD lower bound")
Settings.Set("duelHUDOpacity",2);Check(Settings.Get("duelHUDOpacity")==1,"HUD upper bound")
Settings.Set("duelHUDOpacity",.5);Settings.Reset("duelHUDOpacity")
Check(Settings.Get("duelHUDOpacity")==1 and not Settings.IsModified("duelHUDOpacity") and opacityChanges==5,"HUD opacity reset")
Check(math.abs(Settings.Get("widgetTransparency")-.65)<.001,"HUD opacity does not affect launcher")
Settings.Set("duelHUDAdaptive",false);Check(Settings.Get("duelHUDAdaptive")==false,"adaptive off")
Settings.Reset("duelHUDAdaptive");Check(Settings.Get("duelHUDAdaptive")==true and hudChanges==2,"adaptive reset")
_G.DuelsReimaginedDB.duelHUDOpacity="bad";Check(Settings.Get("duelHUDOpacity")==1,"invalid opacity uses default")
ns.DuelHUD=nil
Check(Settings.Get("duelCountdownStyle")=="impact" and #Settings.GetCountdownStyles()==9,"countdown style defaults")
for _,choice in ipairs(Settings.GetCountdownStyles()) do
    Settings.Set("duelCountdownStyle",choice.key)
    Check(Settings.Get("duelCountdownStyle")==choice.key,"valid countdown style persists")
end
Settings.Set("duelCountdownStyle","invalid")
Check(Settings.Get("duelCountdownStyle")=="minimal","invalid style write refused")
Settings.Reset("duelCountdownStyle")
Check(not Settings.IsModified("duelCountdownStyle") and Settings.Get("duelCountdownStyle")=="impact","style reset")
_G.DuelsReimaginedDB.duelCountdownStyle="invalid"
Check(Settings.Get("duelCountdownStyle")=="impact","invalid saved style fallback")
Check(Settings.Get("duelCountdownFont")=="builtin:Morpheus","countdown font default")
local priorInterfaceFont=Settings.Get("fontChoice")
Settings.Set("duelCountdownFont","lsm:Other font")
Check(Settings.Get("duelCountdownFont")=="lsm:Other font" and Settings.IsModified("duelCountdownFont"),"separate font choice")
Check(Settings.Get("fontChoice")==priorInterfaceFont,"interface choice unaffected")
Settings.Set("duelCountdownFont","not-a-font-key")
Check(Settings.Get("duelCountdownFont")=="lsm:Other font","invalid font choice rejected")
Settings.Reset("duelCountdownFont")
Check(Settings.Get("duelCountdownFont")=="builtin:Morpheus" and not Settings.IsModified("duelCountdownFont"),"countdown font reset")
_G.DuelsReimaginedDB.duelCountdownFont={}
Check(Settings.Get("duelCountdownFont")=="builtin:Morpheus","invalid saved font fallback")
local lx,ly,ls=Settings.GetVisualLayout("countdown")
Check(lx==.5 and ly==.5 and ls==1,"visual layout defaults")
Check(Settings.SetVisualLayout("countdown",.2,.7,1.5),"save visual layout")
lx,ly,ls=Settings.GetVisualLayout("countdown")
Check(lx==.2 and ly==.7 and ls==1.5,"independent normalized visual layout")
Check(not Settings.SetVisualLayout("unknown",.5,.5,1),"unknown visual key rejected")
Check(not Settings.SetVisualLayout("countdown",0/0,.5,1),"invalid coordinates rejected")
lx,ly,ls=Settings.ClampVisualLayout(0,1,2,1000,600,480,240)
Check(math.abs(lx-.48)<.001 and math.abs(ly-.6)<.001 and ls==2,"visual bounds at large scale")
lx,ly,ls=Settings.ClampVisualLayout(.5,.5,2,600,300,480,240)
Check(ls==1.25,"scale fits a smaller viewport")
_G.DuelsReimaginedDB.visualLayouts={countdown={x="bad",y=.5,scale=1}}
lx,ly,ls=Settings.GetVisualLayout("countdown")
Check(lx==.5 and ly==.5 and ls==1,"invalid visual layout fallback")
Check(Settings.Get("duelCountdownSounds")==true and Settings.Get("duelCountdownAudioChannel")=="SFX","countdown audio defaults")
Check(Settings.Get("duelCountdownSoundPack")=="builtin:tick","built-in cue default")
Settings.Set("duelCountdownAudioChannel","Dialog")
Check(Settings.Get("duelCountdownAudioChannel")=="Dialog","channel persisted")
Settings.Set("duelCountdownAudioChannel","invalid")
Check(Settings.Get("duelCountdownAudioChannel")=="Dialog","invalid channel rejected")
Settings.Reset("duelCountdownAudioChannel")
Check(Settings.Get("duelCountdownAudioChannel")=="SFX","channel reset")
Settings.Set("duelCountdownSounds",false)
Check(not Settings.Get("duelCountdownSounds") and Settings.Get("duelCountdownVisual"),"independent audio toggle")
Settings.Reset("duelCountdownSounds")
Check(Settings.Get("duelCountdownSounds"),"sounds default ON")
Settings.Set("duelCountdownSoundPack","pack:absent")
Check(Settings.Get("duelCountdownSoundPack")=="builtin:tick","unregistered pack rejected")
Check(Settings.Get("duelResultVisual")==true and Settings.Get("duelResultVignette")==true,"result defaults")
Settings.Set("duelResultVignette",false)
Check(not Settings.Get("duelResultVignette") and Settings.Get("duelResultVisual"),"independent vignette toggle")
Settings.Reset("duelResultVignette")
Check(Settings.Get("duelFightSounds")==true and Settings.Get("duelFightSoundPack")=="fight:mortal_kombat" and Settings.Get("duelFightAudioChannel")=="SFX","FIGHT audio defaults")
Settings.Set("duelFightAudioChannel","Master")
Check(Settings.Get("duelFightAudioChannel")=="Master" and Settings.Get("duelCountdownAudioChannel")=="SFX","independent FIGHT channel")
Settings.Set("duelFightSounds",false)
Check(not Settings.Get("duelFightSounds") and Settings.Get("duelCountdownSounds"),"independent FIGHT toggle")
Settings.Reset("duelFightSounds");Settings.Reset("duelFightAudioChannel")
Settings.Set("duelFightSoundPack","builtin:tick")
Settings.Reset("duelFightSoundPack")
Check(Settings.Get("duelFightSoundPack")=="fight:mortal_kombat","FIGHT default reset even without local pack")
local oldAudio=ns.CountdownAudio
ns.CountdownAudio={IsAvailable=function(key)return key=="lsm:Bell & Gong"end,
    IsFightAvailable=function(key)return key=="lsm:Sword - Heavy"end,Stop=function()end}
Settings.Set("duelCountdownSoundPack","lsm:Bell & Gong")
Settings.Set("duelFightSoundPack","lsm:Sword - Heavy")
Check(Settings.Get("duelCountdownSoundPack")=="lsm:Bell & Gong","SharedMedia countdown saved")
Check(Settings.Get("duelFightSoundPack")=="lsm:Sword - Heavy","SharedMedia fight saved")
ns.CountdownAudio=nil
Check(Settings.Get("duelCountdownSoundPack")=="lsm:Bell & Gong" and Settings.Get("duelFightSoundPack")=="lsm:Sword - Heavy","missing provider does not erase selection")
Settings.Set("duelCountdownSoundPack","lsm:missing")
Check(Settings.Get("duelCountdownSoundPack")=="lsm:Bell & Gong","unregistered shared sound rejected")
Settings.Reset("duelCountdownSoundPack");Settings.Reset("duelFightSoundPack")
ns.CountdownAudio=oldAudio
Check(Settings.Get("duelVictorySounds") and Settings.Get("duelDefeatSounds"),"result sounds default on")
Check(Settings.Get("duelVictorySoundPack")=="victory:victory1" and Settings.Get("duelDefeatSoundPack")=="defeat:defeat2","result sound defaults")
Settings.Set("duelVictoryAudioChannel","Music")
Check(Settings.Get("duelVictoryAudioChannel")=="Music" and Settings.Get("duelDefeatAudioChannel")=="SFX","independent result channels")
Settings.Set("duelDefeatSounds",false)
Check(Settings.Get("duelVictorySounds") and not Settings.Get("duelDefeatSounds"),"independent result sound toggles")
Settings.Reset("duelDefeatSounds");Settings.Reset("duelVictoryAudioChannel")
_G.DuelsReimaginedDB=originalDB
ns.AccessIcons, ns.Options, ns.Header = nil,nil,nil
print("Independent access settings and default-on Peek: PASS")

-- Run the isolated duel lifecycle harness after existing smoke checks.
dofile("tools/community/check_duel_detection_runtime.lua")

-- Diagnostics tests use a separate namespace and isolated SavedVariables.
dofile("tools/community/check_diagnostics_runtime.lua")

dofile("tools/community/check_opponent_discovery_runtime.lua")

dofile("tools/community/check_commands_runtime.lua")

dofile("tools/community/check_menu_buttons_runtime.lua")

dofile("tools/community/check_player_showcase_runtime.lua")

dofile("tools/community/check_duelist_titles_runtime.lua")

dofile("tools/community/check_achievement_showcase_runtime.lua")

dofile("tools/community/check_duelist_collections_runtime.lua")

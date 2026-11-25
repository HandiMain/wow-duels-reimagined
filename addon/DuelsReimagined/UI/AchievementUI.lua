local _,ns=...
local U={};ns.AchievementUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelAchievementArt.png"
local colors={{.65,.65,.65,1},{.42,.85,.28,1},{.34,.68,1,1},{.73,.38,1,1},{1,.65,.16,1}}
-- Stable artwork keys, independent of catalogue ordering or unlock logic.
local iconSlots={
    begin=0,first=1,tested=2,rising=3,seasoned=4,born=5,thousand=6,
    double=7,spree=8,unstoppable=9,untouchable=10,perfection=11,
    placement=12,aspirant=13,contender=14,veteran=15,duelist=16,master=17,grandmaster=18,rated=19,
    meet=20,challenger=21,fearless=22,conqueror=23,giant=24,
    dedicated=25,warveteran=26,addict=27,eternal=28,legend=29,
}
local HIDDEN_SLOT=35
local function Sample(t,x,y,w,h)
    t:SetTexture(ART)
    t:SetTexCoord((x+.5)/1024,(x+w-.5)/1024,(y+.5)/1024,(y+h-.5)/1024)
end
local function PaintIcon(t,slot)
    Sample(t,(slot%6)*128+1,math.floor(slot/6)*128+1,126,126)
end
function U.PaintAchievementIcon(t,id,hidden)
    PaintIcon(t,hidden and HIDDEN_SLOT or iconSlots[id] or HIDDEN_SLOT)
end
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Crop(p,layer,sub,x,y,w,h)
    local t=p:CreateTexture(nil,layer,nil,sub);ns.Chrome.Sharp(t)
    Sample(t,x,y,w,h);return t
end
function U.Plaque(p,layer,sub)return Crop(p,layer,sub,768,0,256,108) end
local function Label(p,txt,size,color,align)
    local f=S.Text(p,txt,size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(false);return f
end
local function Panel(p)
    local f=CreateFrame("Frame",nil,p);f.skin=S.Skin(f,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.12,rim=.8});return f
end
local function Icon(p)
    local t=p:CreateTexture(nil,"ARTWORK",nil,2);ns.Chrome.Sharp(t);return t
end
local function Button(p,fn)
    local b=CreateFrame("Button",nil,p);local plate=S.Plate(b,"dark",{corner=8})
    b.label=Label(b,"",14,C.pale,"CENTER");b:SetScript("OnClick",fn)
    -- Same separate chosen/hover/press layers and durations as main navigation.
    -- Motion owns reduced-motion behavior. Render never restarts an unchanged tween.
    local M=ns.Motion
    local selected=S.FeedbackOverlay(b,{corner=10,inset=2,fill=C.goldDim,edge=C.gold,shine=.46,rim=.86})
    local hover=S.FeedbackOverlay(b,{corner=10,inset=2,fill=C.gold,edge=C.gold,shine=.67,rim=.75})
    selected:SetAlpha(0);hover:SetAlpha(0)
    b.achievementSelected=selected;b.achievementHover=hover
    b:SetScript("OnEnter",function()M.Fade(hover,b.chosen and .16 or .42,M.Duration("quick"))end)
    b:SetScript("OnLeave",function()M.Fade(hover,0,M.Duration("gentle"))end)
    W.PressFeedback(b,hover,{corner=11,hoverAlpha=.25,clickAlpha=.52})
    function b.Active(on)
        if b.chosen==on then return end
        local initial=b.chosen==nil
        b.chosen=on
        if plate and plate.SetStyle then plate:SetStyle(on and "gold" or "dark") end
        if initial then M.Stop(selected,on and .13 or 0)
        else M.Fade(selected,on and .13 or 0,.18);M.Fade(hover,0,.13) end
    end
    function b.ResetMotion()
        M.Stop(hover,0);M.Stop(selected,b.chosen and .13 or 0)
        if b._duelsPressFlash then M.Stop(b._duelsPressFlash,0) end
    end
    b:HookScript("OnHide",b.ResetMotion)
    return b
end
local page=CreateFrame("Frame",nil,ns.Window.content)
page:SetPoint("TOPLEFT",ns.Window.content,"TOPLEFT",22,-17);page:SetPoint("BOTTOMRIGHT",ns.Window.content,"BOTTOMRIGHT",-22,14)
page:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Achievements",page) end
if page.SetClipsChildren then page:SetClipsChildren(true) end
local hero=Crop(page,"ARTWORK",1,778,154,112,80)
local title=Label(page,"Achievements",26,C.pale)
local subtitle=Label(page,"Prove your dueling skill and earn unique achievements.",13,C.text)
local pointsPanel=CreateFrame("Frame",nil,page)
local pointsPlaque=Crop(pointsPanel,"ARTWORK",1,0,784,384,126);pointsPlaque:SetAllPoints(pointsPanel)
local pointsTitle=Label(pointsPanel,"Achievement Points",13,C.pale,"CENTER")
local points=Label(pointsPanel,"0",29,C.pale,"CENTER")
local status=Label(page,"",11,C.muted)
local left=Panel(page);local categoryTitle=Label(left,"All Achievements",18,C.pale)
local categoryEmblem=Icon(left)
local list=CreateFrame("Frame",nil,page);if list.SetClipsChildren then list:SetClipsChildren(true) end
local empty=Label(list,"No achievements in this category",15,C.muted,"CENTER");empty:SetAllPoints(list);empty:Hide()
local tabs,filters,rows={}, {}, {}
local category="All";local offset,visible,total=0,1,0
local data,shown=false,false
local Render
local function Select(cat)
    category=cat;offset=0;Render()
end
for i,cat in ipairs(ns.Achievements.Categories) do
    local key=cat;local b=Button(page,function()Select(key)end);b.icon=Icon(b);PaintIcon(b.icon,29+i)
    b.count=Label(b,"",12,C.text,"CENTER");tabs[i]=b
end
local all={"All"};for _,cat in ipairs(ns.Achievements.Categories) do all[#all+1]=cat end
for i,cat in ipairs(all) do
    local key=cat;local b=Button(left,function()Select(key)end);b.icon=Icon(b)
    if i==1 then Sample(b.icon,778,154,112,80) else PaintIcon(b.icon,28+i) end
    filters[i]=b
end
local function Row()
    local f=Panel(list);f.icon=Icon(f)
    f.name=Label(f,"",16,C.pale);f.desc=Label(f,"",12,C.text)
    f.track=Panel(f);f.fill=f.track:CreateTexture(nil,"ARTWORK",nil,2)
    f.fill:SetColorTexture(1,.73,.25,1);f.counter=Label(f.track,"",12,C.text,"CENTER")
    f.counter:SetAllPoints(f.track)
    f.medallion=Crop(f,"ARTWORK",1,768,274,128,92)
    f.points=Label(f,"",21,C.pale,"CENTER");f.pointsLabel=Label(f,"Points",11,C.text,"CENTER")
    f.state=Label(f,"",12,C.pale,"CENTER");f.when=Label(f,"",11,C.muted,"CENTER")
    f:EnableMouseWheel(true);f:SetScript("OnMouseWheel",function(_,d)U.SetPageScroll(nil,offset-(d>0 and 1 or -1))end)
    f:Hide();return f
end
for i=1,18 do rows[i]=Row() end
local bar=W.ScrollBar(list,function()return visible,total,offset end,function(v)U.SetPageScroll(nil,v)end)
list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(_,d)U.SetPageScroll(nil,offset-(d>0 and 1 or -1))end)
local function Paint(f,r,w,h)
    local color=r.earned and C.gold or colors[r.rarity] or C.gold
    if r.unavailable or r.progress==0 then color=C.muted end
    local rim=f.skin and f.skin.groups and f.skin.groups[4]
    if rim then for _,t in ipairs(rim.regions) do t:SetVertexColor(color[1],color[2],color[3],1) end end
    local sz=h-10;Place(f.icon,f,5,5,sz,sz)
    U.PaintAchievementIcon(f.icon,r.id,r.hidden)
    local locked=r.unavailable or (not r.earned and r.progress==0)
    -- Keep authored metal and colored silhouettes readable even when locked.
    -- The existing state text and subdued rim distinguish unavailable rows.
    f.icon:SetDesaturated(false)
    f.icon:SetVertexColor(locked and .86 or 1,locked and .86 or 1,locked and .86 or 1,1)
    local x=sz+17;local stateW=w>=530 and 130 or 90
    local pX=w-stateW-81
    local textW=math.max(55,pX-x-10)
    f.name:SetText(r.title);f.name:SetTextColor(unpack(r.earned and C.pale or color))
    f.desc:SetText(r.description);f.desc:SetWordWrap(h>=82)
    Place(f.name,f,x,5,textW,22);Place(f.desc,f,x,28,textW,h>=82 and 28 or 18)
    Place(f.track,f,x,h-23,textW,16)
    local progress=r.progress/r.target
    Place(f.fill,f.track,3,3,math.max(1,(textW-6)*progress),10)
    f.fill:SetColorTexture(color[1],color[2],color[3],1);f.fill:SetShown(progress>0 and not r.unavailable)
    f.counter:SetText(r.unavailable and "Unavailable" or r.hidden and "?" or r.progress.." / "..r.target)
    -- A single sculpted open wreath; no baked-in shield, label or number.
    local medW=math.min(81,(h-6)*128/92)
    local medH=medW*92/128
    local medY=(h-medH)/2
    Place(f.medallion,f,pX+(81-medW)/2,medY,medW,medH)
    f.medallion:SetDesaturated(locked)
    f.medallion:SetVertexColor(locked and .91 or 1,locked and .91 or 1,locked and .91 or 1,1)
    Place(f.points,f,pX+12,medY+3,57,25);Place(f.pointsLabel,f,pX+12,medY+25,57,15)
    f.points:SetText(tostring(r.points));f.points:SetTextColor(unpack(locked and C.muted or C.pale))
    f.pointsLabel:SetTextColor(unpack(locked and C.muted or C.text))
    Place(f.state,f,w-stateW-4,15,stateW,22);Place(f.when,f,w-stateW-4,37,stateW,18)
    f.state:SetText(r.unavailable and "Unavailable" or r.earned and "Completed" or r.progress>0 and "In progress" or "Locked")
    f.state:SetTextColor(unpack(r.earned and C.pale or C.muted))
    local dateFn=date or (os and os.date)
    f.when:SetText(r.earned and (r.earnedAt and dateFn and dateFn("!%b %d, %Y",r.earnedAt) or "Date unavailable") or "")
end
Render=function()
    if not shown or not data or not page:IsVisible() then return end
    local w,h=page:GetWidth(),page:GetHeight()
    if w<10 or h<10 then return end
    local narrow=w<700;local heroW=narrow and 55 or 68
    Place(hero,page,0,2,heroW,heroW*80/112)
    Place(title,page,heroW+8,0,math.max(90,w*.48-heroW),34)
    Place(subtitle,page,heroW+8,32,math.max(100,w*.57-heroW),20)
    local pw=math.min(230,w*.34)
    -- Natural ribbon proportions and a safe gap to the category strip.
    local ph=pw*126/384
    Place(pointsPanel,page,w-pw-75,0,pw,ph)
    Place(pointsTitle,pointsPanel,pw*.16,ph*.295,pw*.68,ph*.23)
    Place(points,pointsPanel,pw*.30,ph*.575,pw*.40,ph*.32)
    points:SetText(tostring(data.points))
    Place(status,page,0,57,w,16)
    status:SetText(data.scope=="SIMULATED" and "SOLO TEST - SIMULATED" or data.storageReason and "Local history unavailable" or data.recordingDisabled and "Local recording disabled - achievements unavailable" or "Duel achievements - local records")
    local tw=(w-24)/5
    for i,b in ipairs(tabs) do
        local cat=ns.Achievements.Categories[i];local c=data.categories[cat]
        Place(b,page,(i-1)*(tw+6),78,tw,48);Place(b.icon,b,6,7,34,34)
        Place(b.label,b,40,2,tw-43,24);b.label:SetText(cat)
        Place(b.count,b,40,24,tw-43,20);b.count:SetText(c.earned.." / "..c.total)
        b.Active(category==cat)
    end
    local lw=math.min(200,w*.235)
    Place(left,page,0,140,lw,math.max(1,h-140))
    Place(categoryEmblem,left,9,8,29,26)
    if category=="All" then Sample(categoryEmblem,778,154,112,80)
    else for i,cat in ipairs(ns.Achievements.Categories) do if cat==category then PaintIcon(categoryEmblem,29+i);break end end end
    Place(categoryTitle,left,42,8,lw-50,31);categoryTitle:SetText(category=="All" and "Collection" or category)
    for i,b in ipairs(filters) do
        local cat=all[i];local c=cat=="All" and data or data.categories[cat]
        Place(b,left,7,45+(i-1)*33,lw-14,31);Place(b.icon,b,5,4,23,23);Place(b.label,b,29,0,lw-48,31)
        b.label:SetText((cat=="All" and "All" or cat).."   "..c.earned.." / "..c.total);b.Active(category==cat)
    end
    local listW=w-lw-10
    Place(list,page,lw+10,140,listW,math.max(1,h-140))
    local selected={}
    for _,r in ipairs(data.rows) do if category=="All" or r.category==category then selected[#selected+1]=r end end
    local rowH=math.max(70,math.min(90,math.floor((h-140)/5)-5))
    visible=math.max(1,math.min(#rows,math.floor((h-140)/(rowH+5))))
    total=#selected;offset=math.max(0,math.min(offset,math.max(0,total-visible)))
    for i,f in ipairs(rows) do
        local r=i<=visible and selected[offset+i]
        f:SetShown(not not r)
        if r then Place(f,list,0,(i-1)*(rowH+5),listW-18,rowH);Paint(f,r,listW-18,rowH) end
    end
    empty:SetShown(total==0);bar:Refresh()
end
function U.GetPageScroll()return offset end
function U.SetPageScroll(_,v)offset=math.max(0,math.floor(tonumber(v) or 0));Render()end
function U.Refresh()
    if ns.Notifications and ns.Notifications.CheckAchievements then ns.Notifications.CheckAchievements() end
    if not shown or not page:IsVisible() then data=nil;return end
    local ok,result=pcall(function()return ns.Achievements.Evaluate(ns.CompetitivePreview.Get())end)
    if ok then data=result else
        data=ns.Achievements.Evaluate({scope="LOCAL",storageReason="unavailable"})
        if ns.Diagnostics then ns.Diagnostics.Record("Achievements","Data provider unavailable") end
    end
    Render()
end
function U.Show(on)
    local wasShown=page:IsShown()
    shown=on==true;page:SetShown(shown)
    if shown and wasShown then U.Refresh() elseif not shown then data=nil end
end
page:SetScript("OnSizeChanged",Render)
page:SetScript("OnShow",function()if shown then U.Refresh()end end)
page:HookScript("OnHide",function()
    data=nil
    for _,b in ipairs(tabs) do b.ResetMotion() end
    for _,b in ipairs(filters) do b.ResetMotion() end
end)

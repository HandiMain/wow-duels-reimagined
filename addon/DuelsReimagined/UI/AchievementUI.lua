local _,ns=...
local U={};ns.AchievementUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelAchievementArt.png"
local colors={{.65,.65,.65,1},{.42,.85,.28,1},{.34,.68,1,1},{.73,.38,1,1},{1,.65,.16,1}}
local catIcons={"INV_Sword_04","Spell_Fire_Fire","INV_Shield_05","INV_Misc_GroupLooking","INV_Crown_01"}
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Crop(p,layer,sub,x,y,w,h)
    local t=p:CreateTexture(nil,layer,nil,sub);t:SetTexture(ART);ns.Chrome.Sharp(t)
    t:SetTexCoord((x+.5)/512,(x+w-.5)/512,(y+.5)/512,(y+h-.5)/512);return t
end
function U.Plaque(p,layer,sub)return Crop(p,layer,sub,0,0,256,108) end
local function Label(p,txt,size,color,align)
    local f=S.Text(p,txt,size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(false);return f
end
local function Panel(p)
    local f=CreateFrame("Frame",nil,p);f.skin=S.Skin(f,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.12,rim=.8});return f
end
local function Icon(p)
    local t=p:CreateTexture(nil,"ARTWORK",nil,2);ns.Chrome.Sharp(t);return t
end
local function Native(t,name)
    local ok=t:SetTexture("Interface\\Icons\\"..name)
    if ok==false then t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    t:SetTexCoord(.07,.93,.07,.93)
end
local function Button(p,fn)
    local b=CreateFrame("Button",nil,p);local plate=S.Plate(b,"dark",{corner=8})
    b.label=Label(b,"",14,C.pale,"CENTER");b:SetScript("OnClick",fn)
    local hover=S.FeedbackOverlay(b,{corner=8,inset=2,fill=C.gold,edge=C.gold,shine=.4,rim=.6})
    hover:SetAlpha(0)
    b:SetScript("OnEnter",function()ns.Motion.Fade(hover,.24,ns.Motion.Duration("quick"))end)
    b:SetScript("OnLeave",function()ns.Motion.Fade(hover,0,ns.Motion.Duration("gentle"))end)
    W.PressFeedback(b,hover)
    function b.Active(on) if plate and plate.SetStyle then plate:SetStyle(on and "gold" or "dark") end end
    return b
end
local page=CreateFrame("Frame",nil,ns.Window.content)
page:SetPoint("TOPLEFT",ns.Window.content,"TOPLEFT",22,-17);page:SetPoint("BOTTOMRIGHT",ns.Window.content,"BOTTOMRIGHT",-22,14)
page:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Achievements",page) end
if page.SetClipsChildren then page:SetClipsChildren(true) end
local hero=Crop(page,"ARTWORK",1,266,0,100,78)
local title=Label(page,"Achievements",26,C.pale)
local subtitle=Label(page,"Prove your dueling skill and earn unique achievements.",13,C.text)
local pointsPanel=Panel(page);local pointsTitle=Label(pointsPanel,"Achievement Points",13,C.pale,"CENTER")
local points=Label(pointsPanel,"0",29,C.pale,"CENTER")
local pointsLaurelL=Crop(pointsPanel,"ARTWORK",1,372,0,28,70)
local pointsLaurelR=Crop(pointsPanel,"ARTWORK",1,440,0,28,70)
local status=Label(page,"",11,C.muted)
local left=Panel(page);local categoryTitle=Label(left,"All Achievements",18,C.pale)
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
    local key=cat;local b=Button(page,function()Select(key)end);b.icon=Icon(b);Native(b.icon,catIcons[i])
    b.count=Label(b,"",12,C.text,"CENTER");tabs[i]=b
end
local all={"All"};for _,cat in ipairs(ns.Achievements.Categories) do all[#all+1]=cat end
for i,cat in ipairs(all) do
    local key=cat;local b=Button(left,function()Select(key)end);filters[i]=b
end
local function Row()
    local f=Panel(list);f.icon=Icon(f)
    f.iconRim=f:CreateTexture(nil,"ARTWORK",nil,1)
    f.name=Label(f,"",16,C.pale);f.desc=Label(f,"",12,C.text)
    f.track=Panel(f);f.fill=f.track:CreateTexture(nil,"ARTWORK",nil,2)
    f.fill:SetColorTexture(1,.73,.25,1);f.counter=Label(f.track,"",12,C.text,"CENTER")
    f.counter:SetAllPoints(f.track)
    f.wreathL=Crop(f,"ARTWORK",1,372,0,28,70)
    f.wreathR=Crop(f,"ARTWORK",1,440,0,28,70)
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
    f.iconRim:SetColorTexture(color[1],color[2],color[3],1)
    local sz=h-12;Place(f.iconRim,f,6,6,sz,sz);Place(f.icon,f,8,8,sz-4,sz-4)
    if r.art then f.icon:SetTexture(ART);local x=(r.art-1)*102;f.icon:SetTexCoord((x+.5)/512,(x+95.5)/512,128.5/512,223.5/512)
    else Native(f.icon,r.icon) end
    f.icon:SetDesaturated(r.unavailable or (not r.earned and r.progress==0))
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
    Place(f.wreathL,f,pX,12,18,h-24);Place(f.wreathR,f,pX+59,12,18,h-24)
    Place(f.points,f,pX+17,10,44,26);Place(f.pointsLabel,f,pX+17,36,44,16)
    f.points:SetText(tostring(r.points));f.points:SetTextColor(unpack(r.earned and C.pale or color))
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
    Place(hero,page,0,0,heroW,54)
    Place(title,page,heroW+8,0,math.max(90,w*.48-heroW),34)
    Place(subtitle,page,heroW+8,32,math.max(100,w*.57-heroW),20)
    local pw=math.min(244,w*.30)
    -- Shared Back occupies the top-right corner; preserve its hit target.
    Place(pointsPanel,page,w-pw-75,0,pw,55)
    Place(pointsLaurelL,pointsPanel,5,4,25,47);Place(pointsLaurelR,pointsPanel,pw-30,4,25,47)
    Place(pointsTitle,pointsPanel,30,2,pw-60,19);Place(points,pointsPanel,30,19,pw-60,33)
    points:SetText(tostring(data.points))
    Place(status,page,0,57,w,16)
    status:SetText(data.scope=="SIMULATED" and "SOLO TEST - SIMULATED" or data.storageReason and "Local history unavailable" or data.recordingDisabled and "Local recording disabled - achievements unavailable" or "Duel achievements - local records")
    local tw=(w-24)/5
    for i,b in ipairs(tabs) do
        local cat=ns.Achievements.Categories[i];local c=data.categories[cat]
        Place(b,page,(i-1)*(tw+6),78,tw,48);Place(b.icon,b,8,9,27,27)
        Place(b.label,b,36,2,tw-39,24);b.label:SetText(cat)
        Place(b.count,b,36,24,tw-39,20);b.count:SetText(c.earned.." / "..c.total)
        b.Active(category==cat)
    end
    local lw=math.min(200,w*.235)
    Place(left,page,0,140,lw,math.max(1,h-140))
    Place(categoryTitle,left,10,8,lw-20,31);categoryTitle:SetText(category=="All" and "Collection" or category)
    for i,b in ipairs(filters) do
        local cat=all[i];local c=cat=="All" and data or data.categories[cat]
        Place(b,left,7,45+(i-1)*33,lw-14,31);Place(b.label,b,5,0,lw-24,31)
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
page:HookScript("OnHide",function()data=nil end)

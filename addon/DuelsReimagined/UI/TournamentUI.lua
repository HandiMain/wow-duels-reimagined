local _,ns=...
-- One tournament view inside the shared window; no gameplay or network calls.
local U={};ns.TournamentUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local T=ns.TournamentState
local Population=ns.CompetitiveScope
local root=CreateFrame("Frame",nil,ns.Window.content)
root:SetAllPoints(ns.Window.content);root:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Tournaments",root) end
function U.PaintEmblem(t)
    -- Reuse an existing authored medal/emblem crop, no new asset dependency.
    t:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelAchievementArt.png")
    t:SetTexCoord(778/1024,890/1024,154/1024,234/1024)
    ns.Chrome.Sharp(t)
end
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y)
    f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,txt,size,color,align)
    local f=S.Text(p,txt,size,color)
    f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(true)
    return f
end
local function TextAt(f,p,x,y,w,h)
    Place(f,p,x,y,w,h)
end
local function Panel(p,caption)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=9,edge=C.goldDim,light=C.goldDim,dark=C.window,shade=.12,shine=.11,rim=.82})
    f.heading=Label(f,caption,18,C.pale)
    local line=S.Fill(f,C.goldDim,"BORDER")
    line:ClearAllPoints();line:SetPoint("TOPLEFT",f,"TOPLEFT",12,-38)
    line:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-38);line:SetHeight(1);line:SetAlpha(.55)
    return f
end
local function Header(f,w) TextAt(f.heading,f,12,6,w-24,28) end
local function Button(p,label,key,primary)
    local b=S.Action(p,label,"footer",{plate=primary and "hall" or "dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    b:SetScript("OnClick",function()
        if ns.Navigation then ns.Navigation.SelectKey("tournaments",key) end
    end)
    ns.Tooltips.Bind(b,{title=label,detail="Open this tournament page."})
    return b
end
local title=Label(root,"TOURNAMENTS",27,C.pale)
title:SetPoint("TOPLEFT",root,"TOPLEFT",70,-15)
local emblem=root:CreateTexture(nil,"ARTWORK");U.PaintEmblem(emblem)
emblem:SetSize(43,36);emblem:SetPoint("TOPLEFT",root,"TOPLEFT",24,-15)
local subtitle=Label(root,"Community 1v1 duel tournaments",13,C.text)
subtitle:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-4)
-- Width is assigned by the shared page layout below.
local scroll=CreateFrame("ScrollFrame",nil,root)
scroll:SetPoint("TOPLEFT",root,"TOPLEFT",24,-133)
scroll:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-28,15)
scroll:EnableMouseWheel(true)
local canvas=CreateFrame("Frame",nil,scroll);canvas:SetSize(800,500);scroll:SetScrollChild(canvas)
-- One read-only community strip for host, browsing, and future event details.
local community=Panel(canvas,"Tournament community")
community:Hide()
local labels,values={},{}
local titles={"Game client","Region","Ruleset","Faction"}
for index,caption in ipairs(titles) do
    labels[index]=Label(community,caption,11,C.muted)
    values[index]=Label(community,"Unavailable",15,C.pale)
end
local communityNote=Label(community,"Automatically detected. These settings cannot be changed.",12,C.muted)
local displayedKey
local function RefreshCommunity()
    local s=Population.GetCurrent()
    local modes={normal="PvE",pvp="PvP",rp="RP",["rp-pvp"]="RP-PvP",hardcore="Hardcore",retail="Standard"}
    values[1]:SetText(s.client=="retail" and "Retail" or s.client=="forever" and "Forever" or "Unavailable")
    values[2]:SetText(s.region=="EU" and "Europe (EU)" or s.region=="US" and "Americas (US)" or "Unavailable")
    values[3]:SetText(modes[s.ruleset] or "Unavailable")
    values[4]:SetText(s.faction or "Unavailable")
    local color=s.faction=="Alliance" and {0.40,0.67,1,1} or s.faction=="Horde" and {1,0.39,0.32,1} or C.pale
    values[4]:SetTextColor(unpack(color))
    displayedKey=Population.Key(s)
    communityNote:SetText(displayedKey and "Automatically detected. Only this community can participate." or
        "Community unavailable or unsupported. Hosting and joining are unavailable.")
    return displayedKey
end
local function LayoutCommunity(w)
    local cols=w>=600 and 4 or 2
    local rows=4/cols
    local h=80+rows*44
    Place(community,canvas,0,0,w,h);Header(community,w)
    local cell=(w-24)/cols
    for index=1,4 do
        local x=12+((index-1)%cols)*cell
        local y=43+math.floor((index-1)/cols)*44
        TextAt(labels[index],community,x,y,cell-6,16)
        TextAt(values[index],community,x,y+16,cell-6,25)
    end
    TextAt(communityNote,community,12,43+rows*44,w-24,32)
    return h+12
end
local pages={}
local function Page(key)
    local f=CreateFrame("Frame",nil,canvas);f:SetAllPoints(canvas);f:Hide();pages[key]=f;return f
end
local overview=Page("overview")
local hero=Panel(overview,"Tournament Hub")
hero.emblem=hero:CreateTexture(nil,"ARTWORK");U.PaintEmblem(hero.emblem)
hero.description=Label(hero,"Organize and compete in community 1v1 duel tournaments.",14,C.text,"CENTER")
hero.browse=Button(hero,"Browse Tournaments","browse",true)
hero.host=Button(hero,"Host Tournaments","host",false)
local open=Panel(overview,"Open Tournaments")
open.detail=Label(open,"No tournaments discovered. Discovery is not active yet.",14,C.muted,"CENTER")
open.action=Button(open,"View All","browse",false)
local champions=Panel(overview,"Recent Champions")
champions.detail=Label(champions,"No tournament champions recorded.",14,C.muted,"CENTER")
champions.action=Button(champions,"Hall of Champions","champions",false)
local browse=Page("browse")
local list=Panel(browse,"Browse Tournaments")
list.detail=Label(list,"No tournaments discovered.",17,C.muted,"CENTER")
list.note=Label(list,"Tournament discovery is not active yet.",13,C.muted,"CENTER")
local info=Panel(browse,"Tournament Details")
info.detail=Label(info,"Select a tournament to view its details and rules.",15,C.muted,"CENTER")
local host=Page("host")
local manage=Panel(host,"Tournament details")
local eventRules=Panel(host,"Format & rules")
local draftFooter=Panel(host,"Save your draft")
local defaults=T.DraftDefaults()
local form,controls,choices={}, {}, {}
local status=Label(draftFooter,"Drafts are kept until you reload or log out. Publishing is not available yet.",13,C.muted)
local refreshSchedule
local function Dirty()
    status:SetText("Unsaved changes. Drafts stay in this session only.")
    if refreshSchedule then refreshSchedule() end
end
local function Field(parent,key,caption,limit,help)
    local label=Label(parent,caption,13,C.pale)
    local box=CreateFrame("EditBox",nil,parent)
    box:SetAutoFocus(false);box:SetMultiLine(false);box:SetMaxLetters(limit)
    box:SetTextInsets(9,9,0,0)
    S.BindFont(box,13,false,C.text)
    S.Skin(box,C.body,{corner=8,edge=C.border,shine=.15,shade=.2})
    box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    box:SetScript("OnHide",function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged",function(self,userInput) if userInput then Dirty() end end)
    box:SetText(defaults[key] or "")
    controls[key]={label=label,box=box,parent=parent}
    ns.Tooltips.Bind(box,{title=caption,detail=help})
    return box
end
local function Choice(parent,key,caption,options)
    local label=Label(parent,caption,13,C.pale)
    local box,value=W.ChoiceControl(parent,226)
    local selected=defaults[key]
    local function Select(k)
        selected=k;choices[key]=k
        for _,o in ipairs(options) do if o.key==k then value:SetText(o.label);break end end
    end
    Select(selected)
    box:SetScript("OnClick",function()
        W.OpenChoices(box,options,selected,function(k) Select(k);Dirty() end)
    end)
    controls[key]={label=label,box=box,parent=parent,choice=true}
    return box
end
Field(manage,"name","Tournament name",60,"Name shown to participants. Plain text only; no links.")
Field(manage,"location","World duel location",100,"Describe the meeting place. No automatic teleport or arena.")
Field(manage,"startUTC","Start (UTC) — YYYY-MM-DD HH:MM",16,"Enter the planned start in UTC, not your local time.")
Choice(manage,"closeBefore","Registration closes",{
    {key=0,label="At start"},{key=15,label="15 min before"},{key=30,label="30 min before"},{key=60,label="60 min before"}})
local localSchedule=Label(manage,"Enter a UTC start to preview your local time.",12,C.muted)
refreshSchedule=function()
    local result=T.GetSchedulePreview(controls.startUTC.box:GetText(),choices.closeBefore)
    if result then
        localSchedule:SetText("Your local time: "..result.starts.."\nRegistration closes: "..result.closes)
    else
        localSchedule:SetText("Enter a valid UTC start for a local-time preview.")
    end
end
local format=Label(eventRules,"Single elimination · 1v1 world duels",14,C.text)
Choice(eventRules,"capacity","Maximum players",{
    {key=4,label="4 players"},{key=8,label="8 players"},{key=16,label="16 players"},{key=32,label="32 players"}})
Choice(eventRules,"bestOf","Match series",{
    {key=1,label="Best of 1"},{key=3,label="Best of 3"},{key=5,label="Best of 5"}})
Field(eventRules,"minLevel","Minimum level (optional)",3,"Leave blank for no minimum. Eligibility checks come with registration.")
Field(eventRules,"maxLevel","Maximum level (optional)",3,"Leave blank for no maximum. Eligibility checks come with registration.")
Field(eventRules,"rules","Additional rules (optional)",160,"Plain text rules for the organizer to enforce; not automatically detected.")
local ruleHint=Label(eventRules,"Level limits and additional rules will be reviewed by the organizer. No automatic enforcement yet.",12,C.muted)
local save=S.Action(draftFooter,"Save Draft","footer",{plate="hall",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
ns.Tooltips.Bind(save,{title="Save Draft",detail="Validate and keep this draft in your current session. It will not be published."})
save:SetScript("OnClick",function()
    for key,control in pairs(controls) do
        if control.choice then form[key]=choices[key]
        else form[key]=control.box:GetText();control.box:ClearFocus() end
    end
    W.CloseChoices()
    local record,why=T.SaveDraft(form,displayedKey)
    RefreshCommunity()
    status:SetText(record and "Draft saved for this session. Not published." or why)
end)
host:HookScript("OnHide",function()
    W.CloseChoices()
    for _,control in pairs(controls) do if not control.choice then control.box:ClearFocus() end end
end)
local function FieldAt(key,x,y,width)
    local v=controls[key]
    Place(v.label,v.parent,x,y,width,22)
    Place(v.box,v.parent,x,y+24,width,30)
end
local function LayoutHost(w)
    local wide=w>=700
    local a=wide and math.floor((w-12)*.49) or w
    local b=wide and w-a-12 or w
    local h1,h2=365,350
    local x2,y2=wide and a+12 or 0,wide and 0 or h1+12
    Place(manage,host,0,0,a,h1);Header(manage,a)
    FieldAt("name",12,45,a-24)
    FieldAt("location",12,105,a-24)
    FieldAt("startUTC",12,165,a-24)
    FieldAt("closeBefore",12,225,a-24)
    TextAt(localSchedule,manage,12,283,a-24,66)
    Place(eventRules,host,x2,y2,b,h2);Header(eventRules,b)
    TextAt(format,eventRules,12,43,b-24,28)
    local half=math.floor((b-34)/2)
    FieldAt("capacity",12,80,half)
    FieldAt("bestOf",22+half,80,b-half-34)
    FieldAt("minLevel",12,140,half)
    FieldAt("maxLevel",22+half,140,b-half-34)
    FieldAt("rules",12,200,b-24)
    TextAt(ruleHint,eventRules,12,264,b-24,80)
    local footerY=math.max(h1,y2+h2)+12
    Place(draftFooter,host,0,footerY,w,138);Header(draftFooter,w)
    TextAt(status,draftFooter,12,42,w-24,48)
    Place(save,draftFooter,math.max(12,w-152),96,140,30)
    return footerY+138
end
local championPage=Page("champions")
local archive=Panel(championPage,"Hall of Champions")
archive.detail=Label(archive,"No completed tournaments recorded.",15,C.muted,"CENTER")
local mine=Page("my-tournament")
local myPanel=Panel(mine,"My Tournament")
myPanel.detail=Label(myPanel,"No active tournament.",15,C.muted,"CENTER")
local brackets=Page("brackets")
local bracketPanel=Panel(brackets,"Brackets")
bracketPanel.detail=Label(bracketPanel,"No tournament bracket available.",15,C.muted,"CENTER")
local active
local function MaxScroll() return math.max(0,canvas:GetHeight()-scroll:GetHeight()) end
local function SetOffset(v)
    scroll:SetVerticalScroll(math.max(0,math.min(MaxScroll(),tonumber(v) or 0)))
end
local bar=W.ScrollBar(root,function()
    return scroll:GetHeight(),canvas:GetHeight(),scroll:GetVerticalScroll()
end,SetOffset)
bar:ClearAllPoints()
bar:SetPoint("TOPLEFT",scroll,"TOPRIGHT",4,0);bar:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",4,0)
local function Layout()
    local w=math.max(1,scroll:GetWidth()-1)
    subtitle:SetWidth(math.max(1,root:GetWidth()-170))
    local wide=w>=640
    local height
    local showCommunity=active=="host" or active=="browse" or active=="my-tournament" or active=="brackets"
    community:SetShown(showCommunity)
    local top=showCommunity and LayoutCommunity(w) or 0
    if active and pages[active] then
        local page=pages[active]
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT",canvas,"TOPLEFT",0,-top)
        page:SetPoint("BOTTOMRIGHT",canvas,"BOTTOMRIGHT",0,0)
    end
    if active=="overview" then
        local heroH=wide and 184 or 220
        Place(hero,overview,0,0,w,heroH);Header(hero,w)
        local artW=math.min(190,w*.28)
        Place(hero.emblem,hero,16,48,artW,artW*.70)
        local x=artW+26;local room=w-x-12
        TextAt(hero.description,hero,x,48,room,54)
        local bw=math.max(1,(room-10)/2)
        if wide then
            Place(hero.browse,hero,x,110,bw,35);Place(hero.host,hero,x+bw+10,110,bw,35)
        else
            Place(hero.browse,hero,x,110,room,34);Place(hero.host,hero,x,150,room,34)
        end
        Place(open,overview,0,heroH+12,w,132);Header(open,w)
        TextAt(open.detail,open,12,42,w-24,42)
        Place(open.action,open,math.max(12,w-132),88,120,28)
        Place(champions,overview,0,heroH+156,w,132);Header(champions,w)
        TextAt(champions.detail,champions,12,42,w-24,42)
        Place(champions.action,champions,math.max(12,w-172),88,160,28)
        height=heroH+288
    elseif active=="browse" then
        local h=math.max(250,scroll:GetHeight()-top)
        if wide then
            local left=math.floor((w-12)*.53)
            Place(list,browse,0,0,left,h);Header(list,left)
            Place(info,browse,left+12,0,w-left-12,h);Header(info,w-left-12)
            TextAt(list.detail,list,12,60,left-24,60)
            TextAt(list.note,list,12,122,left-24,52)
            TextAt(info.detail,info,12,60,w-left-36,90)
            height=h
        else
            Place(list,browse,0,0,w,220);Header(list,w)
            TextAt(list.detail,list,12,60,w-24,60);TextAt(list.note,list,12,122,w-24,52)
            Place(info,browse,0,232,w,190);Header(info,w)
            TextAt(info.detail,info,12,48,w-24,100)
            height=422
        end
    elseif active=="host" then
        height=LayoutHost(w)
    else
        local f=active=="champions" and archive or active=="my-tournament" and myPanel or bracketPanel
        if active and f then
            local h=math.max(200,scroll:GetHeight()-top)
            Place(f,pages[active],0,0,w,h);Header(f,w)
            TextAt(f.detail,f,20,54,w-40,100)
            height=h
        end
    end
    canvas:SetSize(w,math.max(1,(height or 1)+top))
    SetOffset(scroll:GetVerticalScroll())
    bar:Refresh()
end
function U.Show(key)
    if not key then active=nil;root:Hide();return end
    if not T.IsPageAvailable(key) then key="overview" end
    active=key
    RefreshCommunity()
    if key=="host" then refreshSchedule() end
    for k,f in pairs(pages) do f:SetShown(k==active) end
    local snapshot=T.GetSnapshot()
    local client=snapshot.client
    hero.browse:SetShown(T.IsPageAvailable("browse"))
    hero.host:SetShown(T.IsPageAvailable("host"))
    open:SetShown(T.IsPageAvailable("browse"))
    local modeNames={normal="PvE",pvp="PvP",rp="RP",["rp-pvp"]="RP-PvP",hardcore="Hardcore"}
    local label=client=="retail" and "Retail" or client=="forever" and "Forever" or "Unavailable"
    if snapshot.region then label=label.." "..snapshot.region else label=label.." (region unavailable)" end
    if client=="forever" then label=label.." / "..(modeNames[snapshot.ruleset] or "ruleset unavailable") end
    subtitle:SetText("1v1 world duels  |  "..label)
    root:Show();SetOffset(0);Layout()
end
function U.GetPageScroll() return scroll:GetVerticalScroll() end
function U.SetPageScroll(_,offset) SetOffset(offset);bar:Refresh() end
scroll:SetScript("OnMouseWheel",function(_,d)
    if active=="host" then W.CloseChoices() end
    SetOffset(scroll:GetVerticalScroll()-d*42);bar:Refresh()
end)
scroll:HookScript("OnSizeChanged",function() if active then Layout() end end)
root:HookScript("OnShow",function() if active then RefreshCommunity();Layout() end end)

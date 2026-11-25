local _,ns=...
-- One tournament view inside the shared window; no gameplay or network calls.
local U={};ns.TournamentUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local T=ns.TournamentState
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
local manage=Panel(host,"Host & Manage")
manage.detail=Label(manage,"Tournament hosting is not available yet. Tournament creation and registration will be added in a later update.",15,C.muted,"CENTER")
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
        local h=math.max(250,scroll:GetHeight())
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
    else
        local f=active=="host" and manage or active=="champions" and archive or active=="my-tournament" and myPanel or bracketPanel
        if active and f then
            local h=math.max(200,scroll:GetHeight())
            Place(f,pages[active],0,0,w,h);Header(f,w)
            TextAt(f.detail,f,20,54,w-40,100)
            height=h
        end
    end
    canvas:SetSize(w,math.max(1,height or 1))
    SetOffset(scroll:GetVerticalScroll())
    bar:Refresh()
end
function U.Show(key)
    if not key then active=nil;root:Hide();return end
    if not T.IsPageAvailable(key) then key="overview" end
    active=key
    for k,f in pairs(pages) do f:SetShown(k==active) end
    local client=T.GetSnapshot().client
    hero.browse:SetShown(T.IsPageAvailable("browse"))
    hero.host:SetShown(T.IsPageAvailable("host"))
    open:SetShown(T.IsPageAvailable("browse"))
    subtitle:SetText("Community 1v1 duel tournaments  |  "..(client=="retail" and "Retail" or client=="forever" and "Forever" or "Unavailable"))
    root:Show();SetOffset(0);Layout()
end
function U.GetPageScroll() return scroll:GetVerticalScroll() end
function U.SetPageScroll(_,offset) SetOffset(offset);bar:Refresh() end
scroll:SetScript("OnMouseWheel",function(_,d) SetOffset(scroll:GetVerticalScroll()-d*42);bar:Refresh() end)
scroll:HookScript("OnSizeChanged",function() if active then Layout() end end)
root:HookScript("OnShow",function() if active then Layout() end end)

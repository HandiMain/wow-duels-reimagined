local _,ns=...
local S,M,W,C=ns.Style,ns.Motion,ns.Widgets,ns.Style.color
local U={}
ns.CompetitiveUI=U
local ATLAS="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCompetitiveAtlas.png"
local ranks={Unranked=0,Aspirant=1,Contender=2,Veteran=3,Duelist=4,Master=5,Grandmaster=6}
local roman={"I","II","III","IV"}
local GREEN={0.49,0.92,0.30,1}
local RED={1,0.28,0.20,1}
local WHITE=C.text
local function Atlas(parent,layer,sub)
    local t=parent:CreateTexture(nil,layer or "ARTWORK",nil,sub or 1)
    t:SetTexture(ATLAS);ns.Chrome.Sharp(t);return t
end
function U.Plaque(parent,key,layer,sub)
    local t=Atlas(parent,layer,sub)
    local slot=key=="leaderboard" and 0 or key=="matchhistory" and 1 or 2
    t:SetTexCoord(slot/4,(slot+1)/4,0.5,240/256)
    return t
end
-- Only the missing bottom strip of the approved rim, never a second
-- complete border over the War Games art.
function U.LowerRim(parent)
    local t=Atlas(parent,"ARTWORK",3)
    t:SetTexCoord(.5,.75,232/256,240/256)
    t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",0,0)
    t:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,0)
    t:SetHeight(6)
    return t
end
local function Place(f,parent,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    f:SetSize(math.max(1,w),math.max(1,h))
end
local function Text(parent,size,color,align)
    local t=S.Text(parent,"",size,color or C.text)
    t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(false)
    return t
end
local function T(parent,value,size,color,align)
    local t=Text(parent,size,color,align);t:SetText(value);return t
end
local function Set(t,value,color)
    t:SetText(value==nil and "—" or tostring(value))
    if color then t:SetTextColor(unpack(color)) end
end
local function Hair(parent)
    local t=S.Fill(parent,C.border,"ARTWORK");t:SetAlpha(.72);return t
end
local function Panel(parent)
    local f=CreateFrame("Frame",nil,parent)
    S.Skin(f,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.65})
    return f
end
local function Action(parent,label,fn)
    local b=S.Action(parent,label,"footer",{fill=C.nav,hover=C.selected,edge=C.goldDim,light=C.goldDim,dark=C.window,text=C.text,tooltip=false})
    b:SetScript("OnClick",fn);return b
end
local function Rank(parent,size,division)
    local f=CreateFrame("Frame",nil,parent);f:SetSize(size,size)
    local art=Atlas(f);art:SetAllPoints(f)
    local tag=division and T(f,"",15,C.pale,"CENTER") or nil
    if tag then tag:SetPoint("BOTTOM",f,"BOTTOM",0,0);tag:SetSize(40,19) end
    function f.Paint(rank)
        local slot=ranks[rank and rank.name or "Unranked"] or 0
        art:SetTexCoord(slot/8,(slot+1)/8,0,.5)
        if tag then tag:SetText(rank and roman[rank.division] or "") end
    end
    return f
end
local function ClassIcon(parent)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetTexCoord(.07,.93,.07,.93)
    return t
end
local function FactionIcon(parent)
    local t=parent:CreateTexture(nil,"ARTWORK")
    return t
end
local function Identity(row,v,id)
    row.name:SetText(v and v.name or id or "Unknown player")
    row.realm:SetText(v and (v.realm or (v.fullName~=v.name and v.fullName or "")) or "")
    row.class:SetTexture(v and v.class and ("Interface\\Icons\\ClassIcon_"..v.class) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local faction=v and v.faction
    row.faction:SetShown(faction=="Alliance" or faction=="Horde")
    if faction=="Alliance" or faction=="Horde" then row.faction:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..faction) end
end
local function Rate(v) return v and string.format("%.1f%%",v*100) or "—" end
local function Number(v) return v and tostring(v):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") or "—" end
local function Delta(v) return v and string.format("%+d",v) or "—" end
local function Streak(n) return n and n~=0 and (math.abs(n)..(n>0 and "W" or "L")) or "—" end
local function Outcome(x)
    if x=="won" then return "Win",GREEN elseif x=="lost" then return "Loss",RED
    elseif x=="fled" then return "Fled",RED elseif x=="they_fled" then return "Opponent fled",GREEN end
    return "Unknown",C.muted
end
local function Duration(n) return n and string.format("%dm %02ds",math.floor(n/60),math.floor(n%60)) or "—" end
local function Choice(parent,values,selected,change,owner)
    local b,label=W.ChoiceControl(parent,150)
    local current=selected
    local function Paint()
        for _,v in ipairs(values) do if v.key==current then label:SetText(v.label);break end end
    end
    function b.SetChoice(key) current=key;Paint() end
    function b.SetValues(nextValues,key)
        values=nextValues;current=key
        if #values==0 then label:SetText("No active season") else Paint() end
    end
    b:SetScript("OnClick",function()
        W.OpenChoices(b,values,current,function(key)current=key;Paint();change(key)end,owner)
    end)
    Paint();return b
end
local function Search(parent,placeholder,change)
    local f=Panel(parent)
    -- Reuse the header's existing magnifier; no font glyph dependency.
    local glyph=f:CreateTexture(nil,"ARTWORK")
    glyph:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\Search.png")
    glyph:SetPoint("LEFT",f,"LEFT",8,0);glyph:SetSize(17,17)
    ns.Chrome.Sharp(glyph)
    local hint=T(f,placeholder,12,C.muted);hint:SetPoint("LEFT",f,"LEFT",29,0)
    hint:SetPoint("RIGHT",f,"RIGHT",-8,0)
    local edit=CreateFrame("EditBox",nil,f)
    edit:SetPoint("TOPLEFT",f,"TOPLEFT",26,0);edit:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-6,0)
    edit:SetAutoFocus(false);edit:SetMaxLetters(128);edit:SetTextInsets(2,2,0,0)
    edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"")
    edit:SetTextColor(unpack(C.text));S.BindFont(edit,13,nil,C.text)
    edit:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    edit:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    edit:SetScript("OnTextChanged",function(self)
        local value=self:GetText() or "";hint:SetShown(value=="");change(value)
    end)
    f:HookScript("OnHide",function()edit:ClearFocus()end)
    f.edit=edit;return f
end
local function Header(parent,title,icon)
    local f=Panel(parent)
    local label=T(f,title,17,C.pale)
    if icon then
        local image=ns.Chrome.Icon(f,icon);image:SetSize(24,24);image:SetPoint("TOPLEFT",f,"TOPLEFT",11,-7)
        label:SetPoint("TOPLEFT",f,"TOPLEFT",42,-9)
    else label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-9) end
    label:SetHeight(22);label:SetPoint("RIGHT",f,"RIGHT",-12,0)
    local line=Hair(f);line:ClearAllPoints();line:SetPoint("TOPLEFT",f,"TOPLEFT",10,-35);line:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-35);line:SetHeight(1)
    return f,label
end
local function Metric(parent,label)
    local f=CreateFrame("Frame",nil,parent)
    local a=T(f,label,12,C.muted,"CENTER");a:SetPoint("TOPLEFT",f,"TOPLEFT",1,-4);a:SetPoint("TOPRIGHT",f,"TOPRIGHT",-1,-4);a:SetHeight(20)
    local b=T(f,"—",21,C.pale,"CENTER");b:SetPoint("TOPLEFT",f,"TOPLEFT",1,-25);b:SetPoint("TOPRIGHT",f,"TOPRIGHT",-1,-25);b:SetHeight(28)
    local line=Hair(f);line:ClearAllPoints();line:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,-6);line:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,6);line:SetWidth(1)
    f.value=b;f.line=line;return f
end
local function Metrics(parent,labels)
    local list={}
    for _,label in ipairs(labels) do list[#list+1]=Metric(parent,label) end
    list[#list].line:Hide()
    return list
end
local function FitMetrics(list,parent,x,y,w,h)
    for i,f in ipairs(list) do Place(f,parent,x+(i-1)*w/#list,y,w/#list,h) end
end
local function Row(parent,kind,click)
    local f=CreateFrame("Button",nil,parent)
    local hover=S.Fill(f,C.selected,"BACKGROUND");hover:SetAlpha(0)
    local line=Hair(f);line:ClearAllPoints();line:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT");line:SetHeight(1)
    f:SetScript("OnEnter",function()M.Fade(hover,f.marked and .46 or .28,.12)end)
    f:SetScript("OnLeave",function()M.Fade(hover,f.marked and .33 or 0,.15)end)
    W.PressFeedback(f,hover,{hoverAlpha=.25,clickAlpha=.45})
    f:SetScript("OnClick",function()if f.item and click then click(f.item) end end)
    f:HookScript("OnHide",function()M.Stop(hover,0)end)
    f.class=ClassIcon(f);f.faction=FactionIcon(f)
    f.name=Text(f,14,C.text);f.realm=Text(f,10,C.muted)
    f.cols={}
    local count=kind=="board" and 5 or kind=="history" and 4 or kind=="recent" and 3 or 2
    for i=1,count do f.cols[i]=Text(f,13,C.text,"CENTER") end
    if kind=="board" then f.rank=Rank(f,30,false) end
    function f.Mark(on) f.marked=on;M.Stop(hover,on and .33 or 0) end
    return f
end
local function FitIdentity(f,x,w,h,small)
    local size=small and 24 or 28
    Place(f.class,f,x,(h-size)/2,size,size)
    local nameX=x+size+5
    if not small then
        Place(f.faction,f,nameX,(h-16)/2,16,16);nameX=nameX+19
    else f.faction:Hide() end
    Place(f.name,f,nameX,small and 0 or 1,math.max(1,w-(nameX-x)-2),small and h or h*.55)
    Place(f.realm,f,nameX,h*.54,math.max(1,w-(nameX-x)-2),h*.43)
    f.realm:SetShown(not small)
end
local boardWidths={.055,.365,.225,.12,.12,.115}
local historyWidths={.34,.18,.16,.15,.17}
local function FitColumns(labels,parent,width,height,widths)
    local x=0
    for i,label in ipairs(labels) do
        local w=width*widths[i]
        Place(label,parent,x,0,w,height);x=x+w
    end
end
local function BoardRow(f,item,w,h)
    f.item=item
    local x=0;local col={}
    for i,v in ipairs(boardWidths) do col[i]=x;x=x+v*w end
    Set(f.cols[1],item.position,item.position==1 and C.gold or item.position==2 and C.text or item.position==3 and C.goldDim or C.text)
    Place(f.cols[1],f,0,0,col[2],h)
    Identity(f,item.identity,item.id);FitIdentity(f,col[2]+4,w*boardWidths[2]-8,h,false)
    local size=math.min(30,h-3);Place(f.rank,f,col[3]+2,(h-size)/2,size,size);f.rank.Paint(item.rank)
    Place(f.cols[2],f,col[3]+size+5,0,w*boardWidths[3]-size-7,h);f.cols[2]:SetJustifyH("LEFT")
    Set(f.cols[2],item.rank and item.rank.label or "Unranked",C.pale)
    for i=3,5 do Place(f.cols[i],f,col[i+1],0,w*boardWidths[i+1],h) end
    Set(f.cols[3],Number(item.rating),C.text);Set(f.cols[4],item.wins.." / "..item.losses,C.text);Set(f.cols[5],Rate(item.winRate),GREEN)
end
local function HistoryRow(f,item,w,h)
    f.item=item;Identity(f,item.identity,item.peer);FitIdentity(f,5,w*historyWidths[1]-10,h,false)
    local x=w*historyWidths[1]
    for i=1,4 do local width=w*historyWidths[i+1];Place(f.cols[i],f,x,0,width,h);x=x+width end
    Set(f.cols[1],item.category,item.category=="Ranked" and C.text or item.category=="Disputed" and C.gold or C.muted)
    local result,color=Outcome(item.outcome);Set(f.cols[2],result,color)
    Set(f.cols[3],Duration(item.duration),C.text);Set(f.cols[4],Delta(item.delta),item.delta and (item.delta>0 and GREEN or item.delta<0 and RED or C.text) or C.muted)
end
-- One bounded pool per table; the visible rows are always inset from scrollbar.
local function List(parent,kind,rowHeight,click)
    local f=CreateFrame("Frame",nil,parent)
    if f.SetClipsChildren then f:SetClipsChildren(true) end
    local rows={};for i=1,24 do rows[i]=Row(f,kind,click);rows[i]:Hide() end
    local empty=T(f,"No matching results",15,C.muted,"CENTER");empty:SetAllPoints(f);empty:Hide()
    local offset,total,visible=0,0,1
    local fetch,paint,expanded
    local bar
    function f.SetOffset(value)
        offset=math.max(0,math.min(math.floor(value+.5),math.max(0,total-visible)))
        f.Render()
    end
    function f.Offset()return offset end
    function f.Configure(provider,painter,extra)
        fetch,paint,expanded=provider,painter,extra
    end
    function f.Render()
        if not fetch then return end
        local width=math.max(1,f:GetWidth()-18)
        visible=math.max(1,math.min(#rows,math.floor((f:GetHeight()-(expanded and expanded.Height() or 0))/rowHeight)))
        local result,n=fetch(offset,visible);total=n
        local clamped=math.min(offset,math.max(0,total-visible))
        if clamped~=offset then offset=clamped;result,n=fetch(offset,visible);total=n end
        empty:SetShown(total==0)
        if expanded then expanded.frame:Hide() end
        local y=0
        for i,row in ipairs(rows) do
            local item=result[i]
            row:SetShown(item~=nil)
            if item then
                Place(row,f,0,y,width,rowHeight);paint(row,item,width,rowHeight)
                y=y+rowHeight
                if expanded and expanded.Is(item) then
                    local height=expanded.Height();Place(expanded.frame,f,0,y,width,height)
                    expanded.Paint(item,width,height);expanded.frame:Show();y=y+height
                end
            else row.item=nil end
        end
        if bar then bar:Refresh() end
    end
    f:EnableMouseWheel(true)
    local function Wheel(_,delta)f.SetOffset(offset-(delta>0 and 3 or -3))end
    f:SetScript("OnMouseWheel",Wheel)
    for _,r in ipairs(rows) do r:EnableMouseWheel(true);r:SetScript("OnMouseWheel",Wheel) end
    bar=W.ScrollBar(f,function()return visible,total,offset end,f.SetOffset)
    return f
end
-- Fixed-size graph pool. Textures rather than per-match frames; no OnUpdate.
local function Graph(parent)
    local f=CreateFrame("Frame",nil,parent)
    local grid,labels,vertical,segments,areas,dots,ticks={}, {}, {}, {}, {}, {}, {}
    for i=1,5 do
        grid[i]=Hair(f);labels[i]=Text(f,11,C.muted,"RIGHT")
    end
    for i=1,7 do vertical[i]=Hair(f);vertical[i]:SetAlpha(.35);ticks[i]=Text(f,10,C.muted,"CENTER") end
    local footer=T(f,"",10,C.muted,"LEFT")
    local endLabel=T(f,"",10,C.muted,"RIGHT")
    local no=T(f,"No rating progression recorded",14,C.muted,"CENTER");no:SetAllPoints(f)
    for i=1,48 do
        areas[i]=S.Fill(f,C.red,"BACKGROUND");areas[i]:SetAlpha(.18)
        dots[i]=S.Fill(f,C.gold,"OVERLAY")
        local line=f:CreateTexture(nil,"ARTWORK",nil,2);line:SetColorTexture(unpack(C.gold));segments[i]=line
    end
    local function Hide()
        for i=1,48 do areas[i]:Hide();dots[i]:Hide();segments[i]:Hide() end
    end
    function f.Paint(points)
        Hide()
        local w,h=f:GetWidth(),f:GetHeight()
        local x0,y0=43,7
        local plotW,plotH=math.max(1,w-53),math.max(1,h-27)
        local low,high
        for _,p in ipairs(points) do low=math.min(low or p.rating,p.rating);high=math.max(high or p.rating,p.rating) end
        no:SetShown(not low)
        footer:SetShown(low~=nil);endLabel:SetShown(low~=nil)
        if not low then for i=1,5 do grid[i]:Hide();labels[i]:Hide() end;for i=1,7 do vertical[i]:Hide();ticks[i]:Hide() end;return end
        local step=math.max(50,math.ceil((high-low)/4/50)*50)
        low=math.max(0,math.floor(low/step)*step);high=math.max(low+step*4,math.ceil(high/step)*step)
        for i=1,5 do
            local y=y0+plotH*(i-1)/4
            Place(grid[i],f,x0,y,plotW,1);grid[i]:Show()
            Place(labels[i],f,0,y-8,36,16);Set(labels[i],Number(math.floor(high-(high-low)*(i-1)/4)));labels[i]:Show()
        end
        for i=1,7 do Place(vertical[i],f,x0+plotW*(i-1)/6,y0,1,plotH);vertical[i]:Show() end
        Place(footer,f,x0,h-17,plotW/2,15);Place(endLabel,f,x0+plotW/2,h-17,plotW/2,15)
        footer:Hide();endLabel:Hide()
        local dateFn=date or (os and os.date)
        for i=1,7 do
            local idx=math.floor(1+(i-1)*(#points-1)/6+.5)
            local value=points[idx]
            Place(ticks[i],f,x0+plotW*(i-1)/6-24,h-17,48,15)
            ticks[i]:SetText(dateFn and value.time and dateFn("!%b %d",value.time) or tostring(idx))
            ticks[i]:SetShown(i==1 or i==7 or plotW>=420 or i%2==1)
        end
        local count=math.min(48,#points);local prevX,prevY
        for i=1,count do
            local idx=count==1 and 1 or math.floor(1+(i-1)*(#points-1)/(count-1)+.5)
            local p=points[idx]
            local x=x0+(count==1 and plotW/2 or plotW*(i-1)/(count-1))
            local y=y0+plotH*(high-p.rating)/(high-low)
            Place(dots[i],f,x-2,y-2,4,4);dots[i]:Show()
            if prevX then
                local dx,dy=x-prevX,y-prevY
                local length=math.sqrt(dx*dx+dy*dy)
                local line=segments[i];Place(line,f,(prevX+x)/2-length/2,(prevY+y)/2-1,length,2)
                line:SetRotation(-math.atan2(dy,dx));line:Show()
                local top=(prevY+y)/2
                Place(areas[i],f,prevX,top,math.max(1,dx),math.max(1,y0+plotH-top));areas[i]:Show()
            end
            prevX,prevY=x,y
        end
    end
    return f
end
local preview,profileId
local pendingScroll={}
local active
local function Data() return preview end
local function Placement(d,p,season)
    if not d or not season or season<1 or season>d.current or
        (p and p.rank and not p.rank.provisional) then return nil end
    local rules=ns.SeasonRules
    local credit=math.max(0,math.min(rules.PLACEMENT_CREDIT,p and p.credit or 0))
    local rivals=math.max(0,math.min(rules.MIN_RIVALS,p and p.rivalCount or 0))
    return {credit=credit,total=rules.PLACEMENT_CREDIT,rivals=rivals,required=rules.MIN_RIVALS}
end
local function CreditText(p)
    local n=string.format("%.2f",p.credit/4):gsub("0+$",""):gsub("%.$","")
    return n.." / "..p.total/4
end
local OpenProfile
local function Go(section,key)ns.Navigation.SelectKey(section,key)end
local function Seasons()
    local current=preview and preview.current or 3
    local out={}
    for n=current,1,-1 do out[#out+1]={key=n,label="Season "..n} end
    return out
end
local function Points(id,season,filter)
    local d=Data();local out={}
    local first,last=season,season
    if filter=="All time" then first=1;last=d.current end
    for n=first,last do
        local offset=0
        while true do
            local page=d.view.Progression(id,n,offset,100)
            if not page then break end
            for _,r in ipairs(page.rows) do
                if filter~="Last 30 days" or r.time>=d.asOf-30*86400 then out[#out+1]=r end
            end
            offset=offset+#page.rows
            if #page.rows==0 or offset>=page.total then break end
        end
    end
    return out
end
local pages={}
local function Page(key,title,subtitle,previewX,owner)
    local parent=owner or ns.Window.content
    local f=CreateFrame("Frame",nil,parent)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",22,-17);f:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-22,14)
    if f.SetClipsChildren then f:SetClipsChildren(true) end
    local heading=T(f,title,26,C.pale);heading:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);heading:SetSize(360,32)
    local sub=T(f,subtitle,13,C.text);sub:SetPoint("TOPLEFT",f,"TOPLEFT",1,-33);sub:SetSize(460,20)
    local label=Panel(f);label:SetSize(173,24);label:SetPoint("TOPRIGHT",f,"TOPRIGHT",previewX or 0,-4)
    local caption=T(label,"Local data",11,C.muted,"CENTER");caption:SetAllPoints(label)
    f.dataCaption=caption
    if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Competitive / "..title,f) end
    f:Hide();if not owner then pages[key]=f end;return f
end
-- Hall: rank/season hero, activity and leaderboard previews, progression.
local hall=Page("overview","Welcome to the Hall","Your dueling journey starts here.",-71)
local hallRule=ns.Chrome.Divider(hall,300,12)
local hero=Panel(hall);local emblem=Rank(hero,120,true)
local rankText=Text(hero,24,C.pale);local ratingCaption=T(hero,"Rating",13,C.muted)
local rating=Text(hero,28,C.pale)
local placementTitle=T(hero,"Placement Matches",19,C.pale)
local placementCredit=Text(hero,12,C.pale)
local placementRivals=Text(hero,12,C.muted)
local placementBars={}
for i=1,5 do
    local bg=S.Fill(hero,C.goldDim,"ARTWORK");bg:SetAlpha(.35)
    local fill=S.Fill(hero,C.gold,"OVERLAY")
    placementBars[i]={bg=bg,fill=fill}
end
local seasonTitle=T(hero,"Season Summary",17,C.pale)
local seasonInfo=Text(hero,11,C.muted,"RIGHT")
local heroLine=Hair(hero)
local seasonMetrics=Metrics(hero,{"Wins","Losses","Win Rate","Peak Rating","Current Streak"})
local activity=Header(hall,"Recent Activity","Hall")
local activityLink=Action(activity,"View History",function()Go("matchhistory","history")end)
local leaders=Header(hall,"Leaderboard — Top Duelists")
local leadersLink=Action(leaders,"View Full",function()Go("leaderboard","standings")end)
local activityEmpty=T(activity,"No recorded duels",13,C.muted,"CENTER")
local leadersEmpty=T(leaders,"No ranked standings",13,C.muted,"CENTER")
local activityRows,leaderRows={},{}
for i=1,5 do
    activityRows[i]=Row(activity,"recent",function()Go("matchhistory","history")end)
    leaderRows[i]=Row(leaders,"mini",function(item)OpenProfile(item.id)end)
end
local graphPanel=Header(hall,"Rating Progression")
local hallGraph=Graph(graphPanel)
local hallFilter="This Season"
local graphButtons={}
for _,key in ipairs({"This Season","Last 30 days","All time"}) do
    local k=key
    graphButtons[#graphButtons+1]=Action(graphPanel,k,function()hallFilter=k;hall.Render()end)
end
local current=Panel(graphPanel)
local currentLabel=T(current,"Current Rating",12,C.muted,"CENTER")
local currentValue=Text(current,24,C.pale,"CENTER")
local currentDelta=Text(current,13,GREEN,"CENTER")
local currentHint=T(current,"vs. first shown match",10,C.muted,"CENTER")
function hall.Render()
    local d=Data();if not d then return end
    local w,h=hall:GetWidth(),hall:GetHeight()
    local heroH=math.max(110,math.min(146,h*.245))
    local bodyTop=58;local middleTop=bodyTop+heroH+11
    local graphH=math.max(145,math.min(198,h*.32))
    local middleH=math.max(85,h-middleTop-graphH-10)
    Place(hallRule,hall,0,50,w,12)
    Place(hero,hall,0,bodyTop,w,heroH)
    local left=w*.445;local icon=math.min(heroH-14,124)
    Place(emblem,hero,10,(heroH-icon)/2,icon,icon)
    local p=d.view.ProfileSummary(d.me,d.current)
    emblem.Paint(p and p.rank)
    Place(rankText,hero,icon+16,13,left-icon-24,32);Set(rankText,p and p.rank and p.rank.label or "Unranked")
    Place(ratingCaption,hero,icon+18,50,left-icon-24,20)
    Place(rating,hero,icon+16,69,left-icon-24,34);Set(rating,Number(p and p.rating))
    local placement=Placement(d,p,d.current)
    local px,pw=icon+16,math.max(1,left-icon-26)
    rankText:SetShown(not placement);ratingCaption:SetShown(not placement);rating:SetShown(not placement)
    placementTitle:SetShown(placement~=nil);placementCredit:SetShown(placement~=nil);placementRivals:SetShown(placement~=nil)
    if placement then
        Place(placementTitle,hero,px,11,pw,28)
        Place(placementCredit,hero,px,39,pw,19)
        placementCredit:SetText(CreditText(placement).." credits")
        Place(placementRivals,hero,px,78,pw,20)
        placementRivals:SetText(placement.rivals.." / "..placement.required.." unique opponents")
    end
    local cell=math.max(1,(pw-16)/5)
    for i,bar in ipairs(placementBars) do
        bar.bg:SetShown(placement~=nil)
        local fraction=placement and math.max(0,math.min(1,(placement.credit-(i-1)*4)/4)) or 0
        bar.fill:SetShown(fraction>0)
        if placement then
            Place(bar.bg,hero,px+(i-1)*(cell+4),63,cell,9)
            if fraction>0 then Place(bar.fill,hero,px+(i-1)*(cell+4),63,cell*fraction,9) end
        end
    end
    Place(heroLine,hero,left,13,1,heroH-26)
    Place(seasonTitle,hero,left+18,12,w-left-26,25)
    Place(seasonInfo,hero,left+18,36,w-left-26,17)
    if d.current>0 and d.epoch and d.asOf then
        local remain=math.max(0,d.epoch+d.current*ns.SeasonRules.DURATION-d.asOf)
        seasonInfo:SetText("Season "..d.current.."  —  "..math.floor(remain/86400).."d remaining")
    else
        seasonInfo:SetText(d.storageReason and "Local history unavailable" or "Ranked seasons not active")
    end
    FitMetrics(seasonMetrics,hero,left+8,57,w-left-16,heroH-60)
    local stats=p and p.stats or {}
    if d.scope=="LOCAL" then
        seasonTitle:SetText("Personal statistics")
        stats=d.personal
    else
        seasonTitle:SetText("Season Summary")
    end
    Set(seasonMetrics[1].value,stats.wins,GREEN);Set(seasonMetrics[2].value,stats.losses,RED)
    Set(seasonMetrics[3].value,Rate(stats.winRate),C.text);Set(seasonMetrics[4].value,Number(p and p.peakRating),C.text)
    local streak=stats.signedStreak or stats.currentStreak
    Set(seasonMetrics[5].value,Streak(streak),streak and streak<0 and RED or GREEN)
    local half=(w-12)/2
    Place(activity,hall,0,middleTop,half,middleH);Place(leaders,hall,half+12,middleTop,half,middleH)
    Place(activityLink,activity,half-104,7,93,23);Place(leadersLink,leaders,half-92,7,81,23)
    local rh=math.min(36,math.max(22,(middleH-41)/5));local count=math.max(1,math.min(5,math.floor((middleH-41)/rh)))
    local topResult=d.view.Leaderboard(d.current,0,5,"","rating")
    local top=topResult and topResult.rows or {}
    Place(activityEmpty,activity,10,38,half-20,math.max(20,middleH-45))
    Place(leadersEmpty,leaders,10,38,half-20,math.max(20,middleH-45))
    activityEmpty:SetText(d.storageReason and "Local history unavailable" or "No recorded duels")
    activityEmpty:SetShown(#d.matches==0)
    leadersEmpty:SetShown(#top==0)
    for i=1,5 do
        local row=activityRows[i];local item=d.matches[i];row:SetShown(i<=count and item~=nil)
        if item then
            row.item=item;Place(row,activity,10,38+(i-1)*rh,half-20,rh)
            Identity(row,item.identity,item.peer);FitIdentity(row,2,(half-20)*.46,rh,true)
            local result,color=Outcome(item.outcome)
            Place(row.cols[1],row,(half-20)*.47,0,(half-20)*.18,rh);Set(row.cols[1],item.category=="Ranked" and result or item.category,item.category=="Ranked" and color or C.pale)
            Place(row.cols[2],row,(half-20)*.65,0,(half-20)*.14,rh);Set(row.cols[2],Delta(item.delta),item.delta and (item.delta>=0 and GREEN or RED) or C.muted)
            Place(row.cols[3],row,(half-20)*.79,0,(half-20)*.21,rh);Set(row.cols[3],Duration(item.duration),C.muted)
        end
        local lr=leaderRows[i];local item2=top[i];lr:SetShown(i<=count and item2~=nil)
        if item2 then
            lr.item=item2;Place(lr,leaders,10,38+(i-1)*rh,half-20,rh)
            Identity(lr,item2.identity,item2.id);FitIdentity(lr,43,half-135,rh,true)
            Place(lr.cols[1],lr,1,0,39,rh);Set(lr.cols[1],item2.position,item2.position<=3 and C.gold or C.text)
            Place(lr.cols[2],lr,half-100,0,75,rh);Set(lr.cols[2],Number(item2.rating))
        end
    end
    Place(graphPanel,hall,0,h-graphH,w,graphH)
    for i,b in ipairs(graphButtons) do Place(b,graphPanel,w-3*112-8+(i-1)*112,6,106,24);b.label:SetTextColor(unpack(({"This Season","Last 30 days","All time"})[i]==hallFilter and C.gold or C.text)) end
    local side=math.min(142,w*.19)
    Place(hallGraph,graphPanel,8,43,w-side-26,graphH-48)
    Place(current,graphPanel,w-side-10,45,side,graphH-58)
    Place(currentLabel,current,2,7,side-4,19);Place(currentValue,current,2,26,side-4,31)
    Place(currentDelta,current,2,60,side-4,21);Place(currentHint,current,2,83,side-4,15)
    local points=Points(d.me,d.current,hallFilter);hallGraph.Paint(points)
    currentLabel:SetText(placement and "Provisional Rating" or "Current Rating")
    Set(currentValue,Number(p and p.rating))
    local diff=#points>0 and p and p.rating and p.rating-points[1].rating
    Set(currentDelta,Delta(diff),diff and diff<0 and RED or GREEN)
end
-- Leaderboard: native controls, bounded scroll and detail navigation.
local board=Page("standings","Leaderboard","Compete. Climb. Earn your rank.",-71)
local boardSeason,boardQuery,boardSort=3,"","rating"
local standing=Panel(board)
local standText=T(standing,"Your\nStanding",12,C.pale)
local standRank=Rank(standing,44,false)
local standName=Text(standing,17,C.pale)
local standMetrics=Metrics(standing,{"Rating","Rank"})
local boardChoice=Choice(board,Seasons(),3,function(v)boardSeason=v;board.Render(true)end)
local boardSearch=Search(board,"Search player or realm...",function(v)boardQuery=v;board.Render(true)end)
local noSeason=T(board,"No active season",12,C.muted,"CENTER")
local boardHeader=Panel(board)
local boardHeaders={}
local sorts={"rating",false,"rating","rating","wins","winRate"}
for i,name in ipairs({"#","Player","Rank","Rating","W / L","Win rate"}) do
    local idx=i
    local b=CreateFrame("Button",nil,boardHeader);local t=T(b,name,13,C.text,"CENTER");t:SetAllPoints(b)
    if sorts[i] then b:SetScript("OnClick",function()boardSort=sorts[idx];board.Render(true)end) end
    boardHeaders[i]=b
end
local boardList=List(board,"board",37,function(item)OpenProfile(item.id)end)
local pinned=Row(board,"board",function(item)OpenProfile(item.id)end)
local boardNote=T(board,"Standings reflect known ranked duels.",11,C.muted)
boardList.Configure(function(offset,limit)
    local r=Data().view.Leaderboard(boardSeason,offset,limit,boardQuery,boardSort)
    return r and r.rows or {},r and r.total or 0
end,function(row,item,w,h)BoardRow(row,item,w,h);row.Mark(item.id==Data().me)end)
function board.Render(reset)
    local d=Data();if not d then return end
    local w,h=board:GetWidth(),board:GetHeight();local strip=w*.51
    Place(standing,board,0,58,strip,63)
    Place(standText,standing,9,11,76,40);Place(standRank,standing,85,8,42,42)
    local p=d.view.ProfileSummary(d.me,boardSeason)
    standRank.Paint(p and p.rank)
    local placement=Placement(d,p,boardSeason)
    Place(standName,standing,130,11,math.max(60,strip*.63-133),40)
    Set(standName,placement and ("Placement\n"..CreditText(placement)) or (p and p.rank and p.rank.label or "Unranked"))
    FitMetrics(standMetrics,standing,strip*.64,3,strip*.36-2,57)
    Set(standMetrics[1].value,Number(p and p.rating));Set(standMetrics[2].value,p and p.position and "#"..p.position or "—")
    local choiceW=math.min(142,w*.15)
    Place(boardChoice,board,strip+16,75,choiceW,30);Place(boardSearch,board,strip+24+choiceW,75,w-strip-24-choiceW,30)
    Place(noSeason,board,strip+16,75,choiceW,30)
    boardChoice:SetShown(d.current>0);noSeason:SetShown(d.current==0)
    Place(boardHeader,board,0,134,w-18,29);FitColumns(boardHeaders,boardHeader,w-18,29,boardWidths)
    Place(boardList,board,0,165,w,math.max(1,h-225))
    if reset then boardList.SetOffset(0) else boardList.Render() end
    if p and p.position then
        local item={id=d.me,identity=p.identity,rank=p.rank,position=p.position,rating=p.rating,wins=p.stats.wins,losses=p.stats.losses,winRate=p.stats.winRate}
        Place(pinned,board,0,h-57,w-18,39);BoardRow(pinned,item,w-18,39);pinned.Mark(true);pinned:Show()
    else pinned:Hide() end
    local note=d.scope=="SIMULATED" and "Standings reflect known ranked duels."
        or "Peer-reported standings; global completeness and authenticity unverified."
    if d.scope=="LOCAL" and d.capacity then
        if d.capacity.ledger.state=="full" then note="Evidence limit reached; new competitive matches paused."
        elseif d.capacity.ledger.state=="near_capacity" then note="Competitive evidence is approaching its storage limit." end
    end
    boardNote:SetText(note)
    Place(boardNote,board,1,h-16,w-4,16)
end
-- One movable sibling window, not a route or a replacement for the main page.
-- The same profile widgets are reused for every clicked player.
local card=CreateFrame("Frame","DuelsReimaginedPlayerCard",UIParent)
card:SetSize(800,590)
card:SetPoint("CENTER",UIParent,"CENTER",70,12)
card:SetFrameStrata("FULLSCREEN_DIALOG")
card:SetToplevel(true);card:SetClampedToScreen(true);card:SetMovable(true);card:EnableMouse(true)
card:Hide()
S.Skin(card,C.window,{corner=11,edge=C.goldDim,shine=.10,shade=.10})
S.Plate(card,"shellCopper",{corner=20,layer="ARTWORK",sublevel=1})
local profile=Page("profile","Player Profile","Competitive overview and performance.",-35,card)
local drag=CreateFrame("Frame",nil,card)
drag:SetPoint("TOPLEFT",card,"TOPLEFT",12,-8);drag:SetPoint("TOPRIGHT",card,"TOPRIGHT",-46,-8);drag:SetHeight(48)
drag:SetFrameLevel(profile:GetFrameLevel()+6)
drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
drag:SetScript("OnDragStart",function() W.CloseChoices();card:StartMoving() end)
drag:SetScript("OnDragStop",function() card:StopMovingOrSizing() end)
local close=ns.Header.CreateCloseButton(card)
close:SetPoint("TOPRIGHT",card,"TOPRIGHT",-12,-12)
close:SetFrameLevel(profile:GetFrameLevel()+7)
close:SetScript("OnClick",function() card:Hide() end)
-- Blizzard closes every visible registered special frame. Temporarily replace
-- only our own main-window entry, restoring it on card close. No global hook
-- or keyboard capture; other addons' special-frame entries are untouched.
local mainSpecialIndex
local function RemoveSpecial(name)
    if type(UISpecialFrames)~="table" then return end
    for i=#UISpecialFrames,1,-1 do
        if UISpecialFrames[i]==name then table.remove(UISpecialFrames,i);return i end
    end
end
card:SetScript("OnShow",function()
    if type(UISpecialFrames)=="table" then
        mainSpecialIndex=RemoveSpecial("DuelsReimaginedWindow")
        if not mainSpecialIndex then mainSpecialIndex=false end
        table.insert(UISpecialFrames,"DuelsReimaginedPlayerCard")
    end
end)
card:SetScript("OnHide",function()
    card:StopMovingOrSizing();W.CloseChoices()
    if type(UISpecialFrames)=="table" then
        RemoveSpecial("DuelsReimaginedPlayerCard")
        if mainSpecialIndex then
            local exists=false
            for _,name in ipairs(UISpecialFrames) do if name=="DuelsReimaginedWindow" then exists=true end end
            if not exists then table.insert(UISpecialFrames,math.min(mainSpecialIndex,#UISpecialFrames+1),"DuelsReimaginedWindow") end
        end
    end
    mainSpecialIndex=nil
end)
ns.Window.frame:HookScript("OnHide",function()card:Hide()end)
function U.ClosePlayerCard()card:Hide()end
function U.IsPlayerCardOpen()return card:IsShown()end
local profileSeason=3
local profileHero=Panel(profile)
local profileEmblem=Rank(profileHero,106,true)
local profileName=Text(profileHero,25,C.pale)
local profileIdentity=Text(profileHero,14,C.text)
local profileRealm=Text(profileHero,12,C.muted)
local profileRank=Text(profileHero,22,C.pale,"CENTER")
local profileRankCaption=Text(profileHero,12,C.muted,"CENTER")
local profileStand=Metrics(profileHero,{"Standing","Rating"})
local profileChoice=Choice(profileHero,Seasons(),3,function(v)profileSeason=v;profile.Render()end,card)
local profileStats=Panel(profile)
local profileMetrics=Metrics(profileStats,{"Wins","Losses","Win Rate","Peak Rating","Current Streak","Best Streak"})
local profileGraphPanel,profileGraphTitle=Header(profile,"Rating Progression")
local profileGraph=Graph(profileGraphPanel)
local seasonsPanel=Header(profile,"Season History")
local opponentPanel=Header(profile,"Competitive Opponents","Hall")
local seasonRows,opponentRows={},{}
for i=1,3 do
    local row=CreateFrame("Button",nil,seasonsPanel)
    row.cells={}
    for j=1,5 do row.cells[j]=Text(row,12,C.text,"CENTER") end
    row.line=Hair(row);row.line:ClearAllPoints();row.line:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT");row.line:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT");row.line:SetHeight(1)
    local hover=S.Fill(row,C.selected);hover:SetAlpha(0);row.highlight=hover
    row:SetScript("OnEnter",function()M.Fade(hover,.35,.12)end);row:SetScript("OnLeave",function()M.Fade(hover,row.selected and .3 or 0,.12)end)
    W.PressFeedback(row,hover)
    row:SetScript("OnClick",function()if row.season then profileSeason=row.season;profileChoice.SetChoice(profileSeason);profile.Render()end end)
    seasonRows[i]=row
    opponentRows[i]=Row(opponentPanel,"mini",function(item)OpenProfile(item.id)end)
end
local seasonHead,oppHead={},{}
for i,x in ipairs({"Season","End Rating","Peak Rating","W / L","Win Rate"}) do seasonHead[i]=T(seasonsPanel,x,10,C.muted,"CENTER") end
for i,x in ipairs({"Opponent","W / L","Win Rate"}) do oppHead[i]=T(opponentPanel,x,10,C.muted,"CENTER") end
function profile.Render()
    local d=Data();if not d then return end
    local w,h=profile:GetWidth(),profile:GetHeight()
    local p=d.view.Profile(profileId or d.me,profileSeason)
    if not p then p={id=profileId,stats={},seasons={}} end
    local v=p.identity;local stat=p.stats
    local heroH=math.max(102,math.min(128,h*.215))
    Place(profileHero,profile,0,58,w,heroH)
    local icon=heroH-12;Place(profileEmblem,profileHero,12,6,icon,icon);profileEmblem.Paint(p.rank)
    local left=icon+25
    Place(profileName,profileHero,left,8,w*.45-left,35);Set(profileName,v and v.name or p.id or "Unknown player")
    Place(profileIdentity,profileHero,left,48,w*.45-left,20);Set(profileIdentity,v and ((v.class or "Unknown class").."  •  "..(v.faction or "Unknown faction")) or "Identity unavailable")
    Place(profileRealm,profileHero,left,71,w*.45-left,18);Set(profileRealm,v and (v.realm or v.fullName) or "—")
    local rankW=w*.22;Place(profileRank,profileHero,w*.46,39,rankW,29);Set(profileRank,p.rank and p.rank.label or "Unranked")
    local placement=Placement(d,p,profileSeason)
    if placement then Set(profileRank,"Placement "..CreditText(placement)) end
    Place(profileRankCaption,profileHero,w*.46,69,rankW,18)
    Set(profileRankCaption,placement and (placement.rivals.." / "..placement.required.." rivals") or ("Season "..profileSeason))
    FitMetrics(profileStand,profileHero,w*.69,42,w*.30,heroH-45)
    Set(profileStand[1].value,p.position and "#"..p.position or "—");Set(profileStand[2].value,Number(p.rating))
    Place(profileChoice,profileHero,w-122,7,112,28)
    local statY=58+heroH+10;Place(profileStats,profile,0,statY,w,62);FitMetrics(profileMetrics,profileStats,0,2,w,58)
    Set(profileMetrics[1].value,stat.wins or 0,GREEN);Set(profileMetrics[2].value,stat.losses or 0,RED)
    Set(profileMetrics[3].value,Rate(stat.winRate),GREEN);Set(profileMetrics[4].value,Number(p.peakRating))
    Set(profileMetrics[5].value,Streak(stat.currentStreak),stat.currentStreak and stat.currentStreak<0 and RED or GREEN);Set(profileMetrics[6].value,Streak(stat.bestStreak))
    local lowerH=math.max(122,math.min(177,h*.27));local graphY=statY+72;local graphH=math.max(100,h-graphY-lowerH-10)
    Place(profileGraphPanel,profile,0,graphY,w,graphH);profileGraphTitle:SetText("Rating Progression — Season "..profileSeason)
    Place(profileGraph,profileGraphPanel,12,41,w-24,graphH-47);profileGraph.Paint(Points(profileId or d.me,profileSeason))
    local lowerY=h-lowerH;local sw=(w-12)*.54;local ow=w-sw-12
    Place(seasonsPanel,profile,0,lowerY,sw,lowerH);Place(opponentPanel,profile,sw+12,lowerY,ow,lowerH)
    local widths={.24,.20,.20,.18,.18};local x=10
    for i,t in ipairs(seasonHead) do Place(t,seasonsPanel,x,37,(sw-20)*widths[i],17);x=x+(sw-20)*widths[i] end
    for i,t in ipairs(oppHead) do local xs={10,ow*.57,ow*.78};local ws={ow*.52,ow*.21,ow*.21};Place(t,opponentPanel,xs[i],37,ws[i],17) end
    local rh=math.max(20,math.min(32,(lowerH-58)/3))
    for i,row in ipairs(seasonRows) do
        local item=p.seasons[#p.seasons-i+1];row:SetShown(item~=nil)
        if item then
            row.season=item.season;row.selected=item.season==profileSeason
            row.highlight:SetAlpha(row.selected and .30 or 0);Place(row,seasonsPanel,10,55+(i-1)*rh,sw-20,rh)
            local values={"Season "..item.season,Number(item.rating),Number(item.peakRating),item.wins.." / "..item.losses,Rate(item.games>0 and item.wins/item.games or nil)}
            local xx=0
            for j,t in ipairs(row.cells) do local ww=(sw-20)*widths[j];Place(t,row,xx,0,ww,rh);Set(t,values[j],j==5 and GREEN or C.text);xx=xx+ww end
        end
    end
    local opponents={}
    for id,stats in pairs(stat.opponents or {}) do opponents[#opponents+1]={id=id,stats=stats} end
    table.sort(opponents,function(a,b)local x,y=a.stats.wins+a.stats.losses,b.stats.wins+b.stats.losses;if x~=y then return x>y end;return a.id<b.id end)
    for i,row in ipairs(opponentRows) do
        local item=opponents[i];row:SetShown(item~=nil)
        if item then
            row.item=item;Place(row,opponentPanel,10,55+(i-1)*rh,ow-20,rh)
            Identity(row,d.identities[item.id],item.id);FitIdentity(row,0,(ow-20)*.55,rh,true)
            Place(row.cols[1],row,(ow-20)*.55,0,(ow-20)*.23,rh);Set(row.cols[1],item.stats.wins.." / "..item.stats.losses)
            Place(row.cols[2],row,(ow-20)*.78,0,(ow-20)*.22,rh);Set(row.cols[2],Rate(item.stats.winRate),GREEN)
        end
    end
end
OpenProfile=function(id)
    if not preview or not id or preview.current==0 then return end
    if not preview.view.ProfileSummary(id,preview.current) and
        not preview.view.ProfileSummary(id,boardSeason) then return end
    W.CloseChoices()
    profileId=id
    profileSeason=active=="standings" and boardSeason or active=="overview" and preview.current or profileSeason
    profileChoice.SetChoice(profileSeason)
    -- Preserve the dragged position; only scale down on small screens.
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    card:SetScale(math.max(.4,math.min(1,(width-24)/800,(height-24)/590)))
    profile:Show()
    card:Show();card:Raise()
    profile.Render()
end
U.OpenPlayerCard=OpenProfile
profile:SetScript("OnSizeChanged",function(self)if card:IsShown() and preview then self.Render()end end)
-- Private history: display local observations, join only confirmed replay IDs.
local history=Page("history","Match History","Your dueling journey, one match at a time.",-71)
local historyQuery,historyType,historyOutcome="", "All duels","All outcomes"
local historySort,reverse="recent",false
local expandedId
local historyStats=Panel(history)
local historyIcon=ns.Chrome.Icon(historyStats,"Hall")
local historyMetrics=Metrics(historyStats,{"Total duels","Wins","Losses","Win rate"})
local historySearch=Search(history,"Search opponent or realm...",function(v)historyQuery=v;history.Render(true)end)
local function Values(list)local out={};for _,v in ipairs(list)do out[#out+1]={key=v,label=v}end;return out end
local typeChoice=Choice(history,Values({"All duels","Ranked","Unranked","Practice","Pending","Disputed","Unconfirmed"}),"All duels",function(v)historyType=v;expandedId=nil;history.Render(true)end)
local outcomeChoice=Choice(history,Values({"All outcomes","Win","Loss","Fled","Opponent fled","Unknown"}),"All outcomes",function(v)historyOutcome=v;expandedId=nil;history.Render(true)end)
local historyHeader=Panel(history)
local historyHeaders={}
local historySorts={"opponent","category","outcome","duration","delta"}
for i,name in ipairs({"Opponent","Type","Outcome","Elapsed","Rating change"}) do
    local key=historySorts[i]
    local b=CreateFrame("Button",nil,historyHeader);local t=T(b,name,13,C.pale,"CENTER");t:SetAllPoints(b)
    b:SetScript("OnClick",function()if historySort==key then reverse=not reverse else historySort=key;reverse=false end;history.Render(true)end)
    historyHeaders[i]=b
end
local historyList=List(history,"history",38,function(item)
    expandedId=expandedId==item.id and nil or item.id;history.Render()
end)
local detail=Panel(historyList)
local detailMetrics=Metrics(detail,{"Duel","Rating","Elapsed","Result"})
local filtered={}
local function Refilter()
    local query=historyQuery:lower()
    filtered={}
    for _,r in ipairs(Data().matches) do
        local v=r.identity
        local name=v and (v.name.." "..v.fullName.." "..(v.realm or "")) or r.peer or ""
        local out=Outcome(r.outcome)
        if name:lower():find(query,1,true) and (historyType=="All duels" or r.category==historyType)
            and (historyOutcome=="All outcomes" or out==historyOutcome) then filtered[#filtered+1]=r end
    end
    if historySort~="recent" then
        table.sort(filtered,function(a,b)
            local function value(r)
                if historySort=="opponent" then return r.identity and r.identity.name or r.peer or "" end
                return r[historySort] or (historySort=="delta" and 0 or "")
            end
            local x,y=value(a),value(b)
            if x==y then return a.id<b.id end
            if reverse then return x<y end
            return x>y
        end)
    end
end
historyList.Configure(function(offset,limit)
    local result={};for i=offset+1,math.min(offset+limit,#filtered) do result[#result+1]=filtered[i] end
    return result,#filtered
end,function(row,item,w,h)HistoryRow(row,item,w,h);row.Mark(item.id==expandedId)end,{
    frame=detail,Height=function()return expandedId and 59 or 0 end,
    Is=function(item)return item.id==expandedId end,
    Paint=function(item,w,h)
        FitMetrics(detailMetrics,detail,0,0,w,h)
        local result,color=Outcome(item.outcome);Set(detailMetrics[1].value,item.category.." — "..result,color)
        Set(detailMetrics[2].value,item.before and (Number(item.before).." to "..Number(item.after)) or "—",C.pale)
        Set(detailMetrics[3].value,Duration(item.duration),C.text)
        Set(detailMetrics[4].value,item.confirmed and (Data().scope=="LOCAL" and "Peer matched" or "Confirmed") or
            (Data().scope=="LOCAL" and item.category=="Unranked" and "Local only" or item.category),item.confirmed and GREEN or C.muted)
    end
})
function history.Render(reset)
    local d=Data();if not d then return end
    local w,h=history:GetWidth(),history:GetHeight()
    Place(historyStats,history,0,58,w,66);Place(historyIcon,historyStats,17,6,60,54)
    FitMetrics(historyMetrics,historyStats,95,3,w-105,60)
    Set(historyMetrics[1].value,d.personal.total);Set(historyMetrics[2].value,d.personal.wins,GREEN)
    Set(historyMetrics[3].value,d.personal.losses,RED);Set(historyMetrics[4].value,Rate(d.personal.winRate),GREEN)
    Place(historySearch,history,0,141,w*.43,32);Place(typeChoice,history,w*.45,141,w*.25,32);Place(outcomeChoice,history,w*.72,141,w*.28,32)
    Place(historyHeader,history,0,190,w-18,30);FitColumns(historyHeaders,historyHeader,w-18,30,historyWidths)
    Place(historyList,history,0,222,w,math.max(1,h-225))
    Refilter()
    if reset then historyList.SetOffset(0) else historyList.Render() end
end
local failed=T(ns.Window.content,"Competitive data is unavailable.",18,C.muted,"CENTER")
failed:SetPoint("CENTER",ns.Window.content,"CENTER");failed:SetSize(440,30);failed:Hide()
local function Caption()
    if preview.scope=="SIMULATED" then return "SOLO TEST - SIMULATED" end
    if preview.storageReason then return "Local data unavailable" end
    if preview.capacity and preview.capacity.history.state=="full" then return "Local • History full" end
    if preview.peerEvidence then return "Peer evidence • Unverified" end
    return preview.recordingDisabled and "Local • Recording disabled" or "Local observations"
end
local function EnsureData(force)
    local simulated=ns.CompetitivePreview.IsActive()
    local wanted=simulated and "SIMULATED" or "LOCAL"
    if not preview or preview.scope~=wanted or force then
        local switching=not preview or preview.scope~=wanted
        if switching and card:IsShown() then card:Hide() end
        local ok,result=pcall(simulated and ns.CompetitivePreview.Get or ns.CompetitivePreview.Local)
        if not ok or not result then
            preview=nil;card:Hide()
            ns.Diagnostics.Record("Competitive data","Data provider unavailable")
            return false
        end
        preview=result
        if switching then expandedId=nil;boardSeason=preview.current;profileSeason=preview.current end
        if boardSeason<1 or boardSeason>preview.current then boardSeason=preview.current end
        if profileSeason<1 or profileSeason>preview.current then profileSeason=preview.current end
        local values=Seasons()
        boardChoice.SetValues(values,boardSeason);profileChoice.SetValues(values,profileSeason)
    end
    return true
end
local function RenderActive(force)
    if not active then return end
    if not EnsureData(force) then
        pages[active]:Hide();failed:Show();return
    end
    local f=pages[active]
    failed:Hide()
    f.dataCaption:SetText(Caption())
    profile.dataCaption:SetText(Caption())
    if f:IsVisible() and f:GetWidth()>1 and f:GetHeight()>1 then
        f.Render()
        if pendingScroll[active] then
            local value=pendingScroll[active];pendingScroll[active]=nil
            U.SetPageScroll(active,value)
        end
    end
end
for key,f in pairs(pages) do
    f:SetScript("OnSizeChanged",function(self)if self:IsVisible() and preview then self.Render()end end)
    f:SetScript("OnShow",function()if active==key then RenderActive()end end)
    f:HookScript("OnHide",function()W.CloseChoices()end)
end
function U.Show(key)
    if active~=key then W.CloseChoices() end
    for k,f in pairs(pages) do if k~=key then f:Hide() end end
    failed:Hide();active=pages[key] and key or nil
    if active then
        local wasShown=pages[active]:IsShown()
        pages[active]:Show()
        -- OnShow owns initial paint; only refresh an already shown page.
        if wasShown and pages[active]:IsVisible() then RenderActive() end
    end
end
function U.GetPageScroll(key)
    if key=="standings" then return boardList.Offset() elseif key=="history" then return historyList.Offset() end
    return 0
end
function U.SetPageScroll(key,offset)
    if key~="standings" and key~="history" then return end
    if not preview then pendingScroll[key]=offset;return end
    if key=="standings" then boardList.SetOffset(offset) elseif key=="history" then historyList.SetOffset(offset) end
end

function U.Refresh()
    local simulated=ns.CompetitivePreview.IsActive()
    if preview and (preview.scope=="SIMULATED")~=simulated then
        if card:IsShown() then card:Hide() end
        preview=nil
    end
    if active and pages[active]:IsVisible() then RenderActive(true)
    elseif preview then
        if card:IsShown() then card:Hide() end
        preview=nil
    end
    if card:IsShown() and preview then
        if preview.view.ProfileSummary(profileId,profileSeason) then profile.Render()
        else card:Hide() end
    end
end

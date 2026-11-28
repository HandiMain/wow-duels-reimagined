local _,ns=...
local U={};ns.DuelistTitleUI=U
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Panel(p)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.65})
    return f
end
local function Text(p,t,size,color,align)
    local f=S.Text(p,t,size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(false)
    return f
end
local function Button(p,label,fn)
    local b=S.Action(p,label,"footer",{fill=C.nav,hover=C.selected,edge=C.goldDim,light=C.goldDim,dark=C.window,text=C.text,tooltip=false})
    b:SetScript("OnClick",fn);return b
end
local function Track(parent)
    local p=Panel(parent);local fill=p:CreateTexture(nil,"ARTWORK",nil,2)
    fill:SetColorTexture(.82,.59,.22,1)
    return p,fill
end
local function Progress(track,fill,w,h,progress)
    Place(fill,track,3,3,math.max(1,(w-6)*progress),h-6);fill:SetShown(progress>0)
end
function U.Create(parent,changed)
    local f=CreateFrame("Frame",nil,parent)
    local header=Panel(f);local portrait=header:CreateTexture(nil,"ARTWORK")
    local name=Text(header,"",22,C.pale)
    local equipped=Text(header,"No title equipped",16,C.gold)
    local summary=Text(header,"",14,C.text,"CENTER")
    local count=Text(header,"0 / 40",20,C.pale,"CENTER")
    local track,fill=Track(header)
    local notice=Text(f,"",12,C.muted,"CENTER")
    local filters,rows={},{}
    local model,identity,playerId,scope
    local filter,offset,visible,total="All",0,5,0
    local render
    local list=CreateFrame("Frame",nil,f)
    local function Scroll(delta)
        if type(delta)~="number" or delta==0 then return end
        offset=math.max(0,math.min(math.max(0,total-visible),offset+(delta>0 and -1 or 1)))
        render()
    end
    list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(_,d)Scroll(d)end)
    local scrollbar=W.ScrollBar(list,function()return visible,total,offset end,function(v)offset=v;render()end)
    local function Equip(id)
        local ok,why=ns.DuelistTitles.Equip(id)
        if ok then changed() else notice:SetText(why or "Title unavailable.") end
    end
    for _,key in ipairs({"All","Unlocked","Locked"}) do
        local k=key
        filters[#filters+1]={key=k,button=Button(f,k,function()filter=k;offset=0;render()end)}
    end
    local remove=Button(f,"Remove Title",function()Equip(nil)end)
    local empty=Text(list,"No titles in this filter",14,C.muted,"CENTER")
    -- Fixed reusable row pool; no frames created while scrolling.
    for i=1,7 do
        local row=Panel(list)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.name=Text(row,"",17,C.pale);row.desc=Text(row,"",12,C.text)
        row.desc:SetWordWrap(true)
        row.progress=Text(row,"",11,C.muted,"CENTER")
        row.track,row.fill=Track(row)
        row.state=Text(row,"Locked",13,C.muted,"CENTER")
        row.action=Button(row,"Equip",function()if row.item and row.item.earned then Equip(row.item.id) end end)
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",function(_,d)Scroll(d)end)
        row:Hide();rows[i]=row
    end
    function render()
        if not model or not f:IsVisible() then return end
        local w,h=f:GetWidth(),f:GetHeight()
        if w<10 or h<10 then return end
        Place(header,f,0,0,w,88)
        Place(portrait,header,12,10,68,68)
        ns.PlayerShowcase.PaintPortrait(portrait,playerId,scope,identity)
        Place(name,header,92,10,w-296,28);name:SetText(identity and (identity.name or identity.fullName) or "Your character")
        local active=model.equipped and model.byId[model.equipped]
        Place(equipped,header,92,40,w-296,25);equipped:SetText(active and active.name or "No title equipped")
        Place(summary,header,w-182,7,168,18);summary:SetText("Titles collected")
        Place(count,header,w-182,26,168,25);count:SetText(model.earned.." / "..model.total)
        Place(track,header,w-172,60,148,14);Progress(track,fill,148,14,model.earned/model.total)
        for i,item in ipairs(filters) do
            local amount=item.key=="All" and model.total or item.key=="Unlocked" and model.earned or model.total-model.earned
            item.button.label:SetText(item.key.." ("..amount..")")
            item.button:SetAlpha(item.key==filter and 1 or .72)
            Place(item.button,f,(i-1)*((w+6)/3),96,(w-12)/3,27)
        end
        local listH=math.max(1,h-173);Place(list,f,0,132,w,listH)
        local selected={}
        for _,r in ipairs(model.rows) do
            if filter=="All" or (filter=="Unlocked" and r.earned) or (filter=="Locked" and not r.earned) then selected[#selected+1]=r end
        end
        total=#selected;local rowH=54
        visible=math.max(1,math.min(#rows,math.floor(listH/(rowH+4))))
        offset=math.max(0,math.min(math.floor(offset or 0),math.max(0,total-visible)))
        local rw=w-18
        for i,row in ipairs(rows) do
            local r=i<=visible and selected[offset+i] or nil
            row.item=r;row:SetShown(r~=nil)
            if r then
                Place(row,list,0,(i-1)*(rowH+4),rw,rowH)
                Place(row.icon,row,8,7,43,43)
                if ns.AchievementUI then ns.AchievementUI.PaintAchievementIcon(row.icon,r.id,false,row)
                else row.icon:SetTexture("Interface\\Icons\\"..r.icon) end
                row.icon:SetDesaturated(not r.earned)
                row.icon:SetVertexColor(r.earned and 1 or .65,r.earned and 1 or .65,r.earned and 1 or .65,1)
                local textW=math.max(100,rw-276)
                Place(row.name,row,62,3,textW,22);row.name:SetText(r.name);row.name:SetTextColor(unpack(r.earned and C.pale or C.muted))
                Place(row.desc,row,62,24,textW,29);row.desc:SetText(r.description);row.desc:SetTextColor(unpack(r.earned and C.text or C.muted))
                local wearing=model.equipped==r.id
                local rim=row.skin and row.skin.groups and row.skin.groups[4]
                if rim then for _,texture in ipairs(rim.regions) do texture:SetVertexColor(unpack(wearing and C.gold or C.goldDim)) end end
                Place(row.progress,row,rw-205,6,102,19)
                row.progress:SetText(r.available and (r.progress.." / "..r.target) or "Unavailable")
                row.progress:SetShown(not r.earned)
                Place(row.track,row,rw-200,29,92,11);row.track:SetShown(not r.earned and r.available)
                Progress(row.track,row.fill,92,11,r.progress/r.target)
                Place(row.action,row,rw-92,14,83,28);row.action:SetShown(r.earned and not wearing)
                Place(row.state,row,rw-93,11,88,34)
                row.state:SetText(wearing and "Equipped" or "Locked")
                row.state:SetTextColor(unpack(wearing and C.gold or C.muted))
                row.state:SetShown(wearing or not r.earned)
            end
        end
        Place(empty,list,0,0,rw,listH);empty:SetShown(total==0);scrollbar:Refresh()
        Place(remove,f,0,h-34,144,28);remove:SetEnabled(model.saved~=nil and model.scope=="LOCAL")
        Place(notice,f,152,h-34,w-152,28)
    end
    function f.Paint(nextModel,id,info)
        model=nextModel;playerId=id;identity=info;scope=model.scope
        notice:SetText(scope=="SIMULATED" and "Local test - real titles remain locked" or model.saved and not model.equipped and "Selected title unavailable - unlock requirements no longer confirmed." or "Titles are earned through achievements.")
        render()
    end
    function f.Reset()filter="All";offset=0 end
    f:SetScript("OnSizeChanged",render)
    f:SetScript("OnHide",function()model=nil;identity=nil;playerId=nil end)
    f:Hide();return f
end

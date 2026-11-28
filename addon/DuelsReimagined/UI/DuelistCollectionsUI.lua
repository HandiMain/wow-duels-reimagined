local _,ns=...
local U={};ns.DuelistCollectionsUI=U
local S,C,W,K,P=ns.Style,ns.Style.color,ns.Widgets,ns.DuelistCollections,ns.PlayerShowcase
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Panel(p)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.65});return f
end
local function Text(p,t,size,color,align,wrap)
    local f=S.Text(p,t,size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(wrap==true);return f
end
local function Button(p,label,fn)
    local b=S.Action(p,label,"footer",{fill=C.nav,hover=C.selected,edge=C.goldDim,light=C.goldDim,dark=C.window,text=C.text,tooltip=false})
    b:SetScript("OnClick",fn);return b
end
function U.Create(parent,callbacks)
    local f=CreateFrame("Frame",nil,parent)
    local title=Text(f,"Duelist Collections",22,C.pale)
    local subtitle=Text(f,"Earn cosmetic rewards through dueling.",12,C.muted)
    local count=Text(f,"",15,C.gold,"RIGHT")
    local categories,filters,tiles={},{},{}
    local model,identity,playerId,scope
    local kind,filter,offset,visible,total="background","All",0,6,0
    local selected,render
    local list=CreateFrame("Frame",nil,f)
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    local details=Panel(f)
    local preview=CreateFrame("Frame",nil,details)
    local previewLabel=Text(details,"PREVIEW",12,C.gold,"CENTER")
    local name=Text(details,"",18,C.pale,"CENTER")
    local requirement=Text(details,"",12,C.text,"CENTER",true)
    local state=Text(details,"",12,C.muted,"CENTER",true)
    local notice=Text(f,"",11,C.muted,"CENTER",true)
    local empty=Text(list,"No collectibles in this filter",13,C.muted,"CENTER",true)
    local function Scroll(delta)
        if type(delta)~="number" or delta==0 then return end
        offset=math.max(0,math.min(math.max(0,total-visible),offset+(delta>0 and -2 or 2)));render()
    end
    list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(_,d)Scroll(d)end)
    local bar=W.ScrollBar(list,function()return visible,total,offset end,function(v)offset=v;render()end)
    for _,pair in ipairs({{"background","Backgrounds"},{"border","Borders"},{"title","Titles"}}) do
        local k,label=pair[1],pair[2]
        categories[#categories+1]={key=k,label=label,button=Button(f,label,function()
            if k=="title" then callbacks.titles();return end
            kind=k;filter="All";offset=0;selected=nil;render()
        end)}
    end
    for _,key in ipairs({"All","Collected","Locked"}) do
        local k=key
        filters[#filters+1]={key=k,button=Button(f,key,function()filter=k;offset=0;render()end)}
    end
    local equip=Button(details,"Equip",function()
        if not selected or not model then return end
        local r=model.byKind[kind][selected]
        if not r or not r.earned or not model.editable then return end
        local ok,why=K.Equip(kind,r.id)
        if ok then callbacks.changed() else notice:SetText(why or "Unable to equip.") end
    end)
    local remove=Button(details,"Remove",function()
        if not model or not model.editable then return end
        local ok,why=K.Equip(kind,nil)
        if ok then callbacks.changed() else notice:SetText(why or "Unable to remove.") end
    end)
    for i=1,8 do
        local tile=Button(list,"",function(self)
            if self.item then selected=self.item.id;render() end
        end)
        tile.picture=CreateFrame("Frame",nil,tile)
        tile.trim=P.CreateBorder(tile.picture)
        tile.art=tile.picture:CreateTexture(nil,"ARTWORK",nil,0)
        tile.crest=tile.picture:CreateTexture(nil,"ARTWORK",nil,1)
        tile.state=Text(tile.picture,"",10,C.pale,"RIGHT")
        tile:EnableMouseWheel(true);tile:SetScript("OnMouseWheel",function(_,d)Scroll(d)end)
        if ns.Tooltips then ns.Tooltips.Bind(tile,function()
            local r=tile.item
            if r then return {title=r.name,detail=r.requirement.."\n"..(r.earned and "Collected" or "Locked - click to preview")} end
        end) end
        tile:Hide();tiles[i]=tile
    end
    function render()
        if not model or not f:IsVisible() then return end
        local w,h=f:GetWidth(),f:GetHeight()
        if w<10 or h<10 then return end
        local left=math.floor(w*.56);local right=w-left-10
        Place(title,f,0,0,w-130,28)
        Place(subtitle,f,1,29,w-140,18)
        Place(count,f,w-145,2,145,28);count:SetText("Collected: "..model.earned.." / "..model.total)
        for i,item in ipairs(categories) do
            local q=model.counts[item.key]
            item.button.label:SetText(item.label.." "..q.earned.."/"..q.total)
            item.button:SetAlpha(item.key==kind and 1 or .78)
            Place(item.button,f,(i-1)*(w/3+1),52,w/3-4,27)
        end
        for i,item in ipairs(filters) do
            item.button:SetAlpha(item.key==filter and 1 or .72)
            Place(item.button,f,(i-1)*(left/3+1),86,left/3-4,25)
        end
        local listH=math.max(1,h-144)
        Place(list,f,0,116,left,listH)
        local filtered={}
        for _,r in ipairs(model.rows) do
            if r.kind==kind and (filter=="All" or (filter=="Collected" and r.earned) or (filter=="Locked" and not r.earned)) then filtered[#filtered+1]=r end
        end
        total=#filtered
        local tw=math.max(1,(left-24)/2)
        local th=math.max(80,math.min(108,math.floor(listH/3)-5))
        visible=math.max(2,math.min(#tiles,math.floor(listH/(th+5))*2))
        offset=math.max(0,math.min(math.floor(offset or 0),math.max(0,total-visible)))
        if not selected or not model.byKind[kind][selected] then
            selected=model.equipped[kind]
        end
        local chosen=model.byKind[kind][selected]
        if not chosen then chosen=filtered[1] end
        for i,tile in ipairs(tiles) do
            local r=i<=visible and filtered[offset+i] or nil
            tile.item=r;tile:SetShown(r~=nil)
            if r then
                local x=((i-1)%2)*(tw+6);local y=math.floor((i-1)/2)*(th+5)
                Place(tile,list,x,y,tw,th)
                Place(tile.picture,tile,4,4,tw-8,th-27)
                Place(tile.art,tile.picture,5,5,tw-18,th-37)
                local faction=identity and identity.faction
                local bg=r.kind=="background" and r or K.Art("background",model.equipped.background)
                P.PaintBackdrop(tile.art,bg,faction,tw-18,th-37)
                P.PaintBorder(tile.trim,r.kind=="border" and r or nil)
                tile.crest:Hide()
                if bg and bg.id=="faction" then
                    local aspect=P.PaintFactionCrest(tile.crest,faction)
                    local ch=math.max(1,th-40)
                    Place(tile.crest,tile.picture,(tw-8-ch*aspect)/2,4,ch*aspect,ch)
                    tile.crest:SetAlpha(.6)
                end
                tile.art:SetDesaturated(not r.earned)
                tile.art:SetAlpha(r.earned and 1 or .67)
                Place(tile.label,tile,3,th-22,tw-6,19)
                tile.label:SetText(r.name);tile.label:SetTextColor(unpack(r.earned and C.pale or C.muted))
                Place(tile.state,tile.picture,2,2,tw-15,16)
                tile.state:SetText(model.equipped[kind]==r.id and "Equipped" or r.earned and "Collected" or "Locked")
                tile.state:SetTextColor(unpack(r.earned and C.gold or C.text))
                tile:SetAlpha(chosen and chosen.id==r.id and 1 or .83)
            end
        end
        Place(empty,list,2,0,left-20,listH);empty:SetShown(total==0);bar:Refresh()
        local dh=h-86
        Place(details,f,left+10,86,right,dh)
        local previewH=math.max(1,dh-116)
        Place(previewLabel,details,8,2,right-16,17)
        Place(preview,details,8,20,right-16,previewH-16)
        local appearance={background=K.Art("background",model.equipped.background),border=K.Art("border",model.equipped.border)}
        if chosen then appearance[kind]=chosen end
        callbacks.preview(preview,playerId,scope,identity,appearance)
        Place(name,details,6,previewH+7,right-12,24);name:SetText(chosen and chosen.name or "Select a collectible")
        Place(requirement,details,6,previewH+32,right-12,36);requirement:SetText(chosen and chosen.requirement or "")
        Place(state,details,6,previewH+68,right-12,16)
        state:SetText(chosen and (model.equipped[kind]==chosen.id and "Equipped" or chosen.earned and "Collected" or chosen.available and ("Locked - "..chosen.progress.." / "..chosen.target) or "Locked - progress unavailable") or "")
        Place(equip,details,7,dh-29,(right-20)/2,24);Place(remove,details,right/2+3,dh-29,(right-20)/2,24)
        equip:SetEnabled(not not (chosen and chosen.earned and model.editable and model.equipped[kind]~=chosen.id))
        remove:SetEnabled(model.editable and model.saved[kind]~=nil)
        Place(notice,f,0,h-26,left,24)
    end
    function f.Paint(nextModel,id,info)
        model=nextModel;playerId=id;identity=info;scope=model.scope
        notice:SetText(scope=="SIMULATED" and "Preview only - test rewards do not unlock cosmetics." or not model.editable and "Collection preferences unavailable." or "Select any collectible to preview it.")
        render()
    end
    function f.Reset()model=nil;identity=nil;playerId=nil;selected=nil;kind="background";filter="All";offset=0 end
    f:SetScript("OnSizeChanged",render)
    f:SetScript("OnHide",function()model=nil;identity=nil;playerId=nil end)
    f:Hide();return f
end

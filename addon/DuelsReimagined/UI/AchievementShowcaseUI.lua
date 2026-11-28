local _,ns=...
local U={};ns.AchievementShowcaseUI=U
local S,C,Q=ns.Style,ns.Style.color,ns.AchievementShowcase
-- Reuse the shipped favorite glyph atlas on both clients. No War Games
-- module dependency, font-dependent star, or additional artwork required.
local GLYPHS="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\WarGamesPickerGlyphs.tga"
local function Place(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Text(p,t,size,color,align)
    local f=S.Text(p,t,size,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(false)
    return f
end
local function Button(p,label,fn)
    local b=S.Action(p,label,"footer",{fill=C.nav,hover=C.selected,edge=C.goldDim,light=C.goldDim,dark=C.window,text=C.text,tooltip=false})
    b:SetScript("OnClick",fn);return b
end
local function BindTip(owner)
    if ns.Tooltips then ns.Tooltips.Bind(owner,function()return owner.showcaseTip end) end
end
local function Tip(owner,value)
    if owner.showcaseTip~=value and ns.Tooltips then ns.Tooltips.Hide(owner,true) end
    owner.showcaseTip=value
end
local function Star(texture,pinned,available)
    texture:SetTexture(GLYPHS)
    texture:SetTexCoord(pinned and .25 or 0,pinned and .5 or .25,0,1)
    texture:SetDesaturated(not available)
    texture:SetAlpha(pinned and 1 or available and .85 or .45)
end
function U.CreatePin(parent,changed)
    local b=Button(parent,"",function(self)
        if not self.pinId or not self.pinAllowed then return end
        local ok,why=Q.Toggle(self.pinId)
        if ok then changed() else
            Tip(self,{title="Achievement Showcase",detail=why or "Showcase unavailable."})
            if ns.Tooltips then ns.Tooltips.Show(self,self.showcaseTip) end
        end
    end)
    local glyph=b:CreateTexture(nil,"OVERLAY")
    glyph:SetSize(22,22);glyph:SetPoint("CENTER",b,"CENTER")
    BindTip(b)
    function b.Paint(row,model)
        local pinned=model and model.index[row.id]~=nil
        local can=model and model.editable and (pinned or (model.byId[row.id]~=nil and #model.saved<Q.MAX))
        b.pinId=row.id;b.pinAllowed=not not can
        Star(glyph,pinned,not not can)
        b:SetAlpha(can and 1 or .64)
        local reason=pinned and "Remove this achievement from your showcase." or
            model and model.scope=="SIMULATED" and "Test achievements cannot be showcased." or
            not model or not model.editable and "Showcase preferences unavailable." or
            not model.byId[row.id] and "Earn this achievement before showcasing it." or
            #model.saved>=Q.MAX and "Showcase full. Unpin an achievement first." or
            "Pin this achievement to your Duelist Profile."
        Tip(b,{title=pinned and "Pinned in slot "..model.index[row.id] or "Achievement Showcase",detail=reason})
    end
    return b
end
local function AchievementTip(row)
    if not row then return end
    local rarity=({"Common","Uncommon","Rare","Epic","Legendary"})[row.rarity] or "Unknown"
    local when="Date unavailable"
    local dateFn=date or (os and os.date)
    if row.earnedAt and dateFn then when=dateFn("!%b %d, %Y",row.earnedAt) end
    local detail=row.description.."\n"..row.points.." Achievement Points\nRarity: "..rarity.."\nCompleted: "..when
    local reward=ns.DuelistTitles and ns.DuelistTitles.Reward(row.id)
    if reward then detail=detail.."\nUnlocks title: "..reward end
    return {title=row.title,detail=detail}
end
function U.Create(parent,callbacks)
    local f=CreateFrame("Frame",nil,parent)
    local slots={}
    local model,own,editing,scope,draft,baseline
    local render
    local function Reset()draft=nil;baseline=nil end
    function f.Reset()Reset();model=nil;editing=false end
    local status=Text(f,"",12,C.muted,"CENTER")
    local edit=Button(f,"Edit Showcase",function()callbacks.edit()end)
    local customize=Button(f,"Customize Profile",function()callbacks.customize()end)
    local browse=Button(f,"View Achievements",function()callbacks.browse()end)
    local clear=Button(f,"Clear All",function()draft={};render()end)
    local cancel=Button(f,"Cancel",function()Reset();callbacks.cancel()end)
    local save=Button(f,"Save Showcase",function()
        if not draft or not baseline then return end
        local ok,why=Q.SaveOrder(draft,baseline)
        if ok then Reset();callbacks.changed();callbacks.cancel()
        else status:SetText(why or "Unable to save showcase.") end
    end)
    local function Move(i,step)
        if not draft or not draft[i] or not draft[i+step] then return end
        draft[i],draft[i+step]=draft[i+step],draft[i];render()
    end
    for i=1,Q.MAX do
        local index=i
        local slot=CreateFrame("Frame",nil,f)
        S.Skin(slot,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.65})
        slot.number=Text(slot,tostring(i),11,C.pale,"CENTER")
        slot.iconHolder=CreateFrame("Frame",nil,slot);slot.iconHolder:EnableMouse(true)
        slot.icon=slot.iconHolder:CreateTexture(nil,"ARTWORK");slot.icon:SetAllPoints(slot.iconHolder)
        BindTip(slot.iconHolder)
        slot.empty=Text(slot,"Empty",12,C.muted,"CENTER")
        slot.label=Text(slot,"",11,C.text,"CENTER")
        slot.label:SetWordWrap(true)
        slot.remove=Button(slot,"X",function()
            if draft and draft[index] then table.remove(draft,index);render() end
        end)
        slot.left=Button(slot,"<",function()Move(index,-1)end)
        slot.right=Button(slot,">",function()Move(index,1)end)
        slots[i]=slot
    end
    function render()
        if not model or not f:IsVisible() then return end
        local w,h=f:GetWidth(),f:GetHeight()
        if w<10 or h<10 then return end
        local canEdit=own and scope=="LOCAL" and model.editable
        local isEditor=own and editing and scope=="LOCAL"
        local ids=isEditor and (draft or {}) or model.saved
        local available=model.available
        local count=#ids
        local text=not own and "Achievements not shared" or
            scope=="SIMULATED" and "Test achievements cannot be showcased" or
            model.reason or not available and "Achievement progress unavailable" or
            count==0 and "Pin up to 3 earned achievements" or ("Showcase: "..count.." / 3")
        if isEditor and baseline and not Q.Same(baseline,model.saved) then text="Showcase changed. Cancel and reopen." end
        status:SetText(text)
        edit:SetShown(canEdit and not editing)
        customize:SetShown(own and scope=="LOCAL" and not editing)
        browse:SetShown(own and editing)
        clear:SetShown(isEditor and canEdit);cancel:SetShown(isEditor)
        save:SetShown(isEditor and canEdit)
        if isEditor then
            local bw=math.min(156,(w-32)/4)
            Place(status,f,12,43,w-24,28)
            Place(browse,f,12,h-40,bw,28)
            Place(clear,f,20+bw,h-40,bw,28)
            Place(cancel,f,w-20-bw*2,h-40,bw,28)
            Place(save,f,w-bw-12,h-40,bw,28)
            clear:SetEnabled(count>0)
            save:SetEnabled(draft~=nil and baseline~=nil and not Q.Same(draft,baseline) and Q.Same(baseline,model.saved))
        else
            Place(edit,f,w-136,6,126,25)
            Place(customize,f,w-136,h-31,126,25)
            Place(status,f,10,37,w-148,16)
        end
        local usable=isEditor and w-24 or w-150
        local gap=isEditor and 12 or 4
        local sw=math.max(1,(usable-2*gap)/3)
        local sh=isEditor and math.min(174,math.max(90,h-124)) or math.max(1,h-54)
        for i,slot in ipairs(slots) do
            local id=ids[i];local row=id and model.byId[id]
            local present=own and (scope=="LOCAL" or scope=="SIMULATED")
            slot:SetShown(present)
            if present then
                local x=(isEditor and 12 or 8)+(i-1)*(sw+gap)
                Place(slot,f,x,isEditor and 76 or 53,sw,sh)
                local size=isEditor and math.min(76,sw-32,sh-67) or math.min(28,sh-5)
                size=math.max(16,size)
                Place(slot.number,slot,3,2,14,15)
                Place(slot.iconHolder,slot,(sw-size)/2,isEditor and 22 or 2,size,size)
                slot.iconHolder:SetShown(row~=nil)
                Tip(slot.iconHolder,AchievementTip(row))
                if row and ns.AchievementUI then ns.AchievementUI.PaintAchievementIcon(slot.icon,row.id,false,slot.iconHolder) end
                slot.empty:SetShown(not row)
                slot.empty:SetText(id and "Unavailable" or "Empty")
                Place(slot.empty,slot,15,isEditor and 35 or 2,sw-30,isEditor and 46 or 24)
                slot.label:SetShown(row~=nil)
                slot.label:SetText(row and row.title or "")
                Place(slot.label,slot,3,isEditor and size+25 or size+1,sw-6,isEditor and 29 or 17)
                slot.remove:SetShown(isEditor and canEdit and id~=nil)
                slot.left:SetShown(isEditor and canEdit and id~=nil)
                slot.right:SetShown(isEditor and canEdit and id~=nil)
                Place(slot.remove,slot,sw-25,3,22,22)
                Place(slot.left,slot,5,sh-29,30,24)
                Place(slot.right,slot,sw-35,sh-29,30,24)
                slot.left:SetEnabled(i>1);slot.right:SetEnabled(i<count)
            end
        end
        if not own then Place(status,f,12,38,w-24,math.max(18,h-45)) end
    end
    function f.Paint(nextModel,isOwn,isEditing,kind)
        if editing~=isEditing or own~=isOwn or scope~=kind then Reset() end
        model,own,editing,scope=nextModel,isOwn,isEditing,kind
        if own and editing and scope=="LOCAL" and model.editable and not draft then
            baseline=Q.Validate(model.saved);draft=Q.Validate(model.saved)
        end
        render()
    end
    f:SetScript("OnSizeChanged",render)
    f:SetScript("OnHide",function()f.Reset()end)
    f:Hide();return f
end

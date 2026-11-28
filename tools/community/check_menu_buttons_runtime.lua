-- Exercise the shipped shared menu renderer, not a second visual implementation.
local ns={}
local scale=1
ns.Settings={Get=function(key)if key=="fontScale" then return scale end end}
ns.Chrome={Sharp=function(t)return t end}
ns.Motion={Fade=function(region,value)region:SetAlpha(value)end,Duration=function()return 0 end}
ns.Widgets={PressFeedback=function(button,hover,opts)button.press=opts;button.pressHover=hover end}
local function Region()
    local r={alpha=1,points={},width=0,height=0}
    function r:SetTexture(v) self.path=v end
    function r:SetTexCoord(...) self.uv={...} end
    function r:SetVertexColor(...) self.vertex={...} end
    function r:SetBlendMode(v) self.blend=v end
    function r:SetAlpha(v) self.alpha=v end
    function r:GetAlpha()return self.alpha end
    function r:SetAllPoints(v) self.all=v end
    function r:ClearAllPoints() self.points={} end
    function r:SetPoint(...)self.points[#self.points+1]={...} end
    function r:SetSize(w,h)self.width,self.height=w,h end
    function r:SetWidth(w)self.width=w end
    function r:SetFont(path,size,flags)self.face,self.size,self.flags=path,size,flags;return true end
    function r:GetFont()return self.face,self.size,self.flags end
    function r:SetTextColor(...)self.color={...} end
    function r:SetJustifyH(v)self.justify=v end
    function r:SetJustifyV(v)self.justifyV=v end
    function r:SetText(v)self.text=v end
    function r:SetWordWrap(v)self.wrap=v end
    function r:GetUnboundedStringWidth()return #self.text*self.size*.55 end
    return r
end
local function Button(w,h)
    local b={width=w,height=h,textures={},labels={},hooks={},enabled=true}
    function b:GetWidth()return self.width end
    function b:GetHeight()return self.height end
    function b:CreateTexture(_,layer,_,level)
        local r=Region();r.layer=layer;r.level=level;self.textures[#self.textures+1]=r;return r
    end
    function b:CreateFontString()
        local r=Region();self.labels[#self.labels+1]=r;return r
    end
    function b:HookScript(event,fn)
        self.hooks[event]=self.hooks[event] or {};table.insert(self.hooks[event],fn)
    end
    function b:Fire(event)for _,fn in ipairs(self.hooks[event] or {}) do fn(self) end end
    function b:SetSize(x,y)self.width,self.height=x,y;self:Fire("OnSizeChanged")end
    function b:RegisterForClicks(v)self.clicks=v end
    function b:IsEnabled()return self.enabled end
    return b
end
assert(loadfile("addon/DuelsReimagined/UI/Style.lua"))("DuelsReimagined",ns)
local S=ns.Style
local uvSeen={}
local function CheckButton(key,title,primary,danger)
    local b=Button(primary and 166 or 112,primary and 68 or 30)
    local v=S.MenuButton(b,key,title,{primary=primary,danger=danger})
    assert(#b.labels==1 and b.label==v.label and b.icon==v.icon)
    assert(v.label.text==(primary and title:upper() or title) and not v.label.wrap)
    assert(v.icon.path:find("DRMenuEmblems.png",1,true))
    local uv=table.concat(v.icon.uv,",");assert(not uvSeen[uv],key.." duplicate emblem");uvSeen[uv]=true
    for _,r in ipairs(b.textures) do
        if r~=v.icon then assert(r.path:find("DRMenuPlates.png",1,true)) end
    end
    assert(#b.textures==(primary and 4 or 10))
    assert(v.base:GetAlpha()==1 and v.hover:GetAlpha()==0 and v.selected:GetAlpha()==0)
    v.selected:SetAlpha(.32);b:Fire("OnEnter")
    assert(v.hover:GetAlpha()==.24 and v.selected:GetAlpha()==.32)
    b:Fire("OnLeave");assert(v.hover:GetAlpha()==0 and v.selected:GetAlpha()==.32)
    b.enabled=false;b:Fire("OnEnter");assert(v.hover:GetAlpha()==0)
    local flash=b.press.flashFactory();flash:SetAlpha(.4)
    assert(flash:GetAlpha()==.4 and v.selected:GetAlpha()==.32 and v.hover:GetAlpha()==0)
    assert(b.clicks=="LeftButtonUp")
    local texCount=#b.textures
    b:SetSize(primary and 142 or 94,primary and 57 or 30)
    assert(#b.textures==texCount and #b.labels==1)
    assert(v.label:GetUnboundedStringWidth()<=v.label.width and v.label.size<=v.label.height)
    return b,v
end
local buttons={}
for _,row in ipairs({
    {"hall","Hall"},{"leaderboard","Leaderboard"},{"matchhistory","Match History"},
    {"achievements","Achievements"},{"tournaments","Tournaments"},{"wargames","War Games"},
    {"addonstatus","Addon Status"},{"community","Community"},{"patchnotes","Patch Notes"},{"options","Options"},{"close","Close"},
}) do
    local primary=#buttons<6
    local b,v=CheckButton(row[1],row[2],primary,row[1]=="close")
    buttons[#buttons+1]={b=b,v=v}
end
scale=1.5
S.ApplyTheme("Fonts\\ARIALN.TTF")
for _,entry in ipairs(buttons) do
    assert(entry.v.label.face=="Fonts\\ARIALN.TTF")
    assert(entry.v.label:GetUnboundedStringWidth()<=entry.v.label.width)
    assert(entry.v.label.size<=entry.v.label.height)
end
scale=.75
S.ApplyTheme("Fonts\\FRIZQT__.TTF")
for _,entry in ipairs(buttons) do assert(entry.v.label.face=="Fonts\\FRIZQT__.TTF")end
-- A future feature needs no new plate, just independent icon and label.
local future=Button(166,68)
local v=S.MenuButton(future,"future","Duel Arena",{primary=true,emblemTexture="Interface\\Icons\\INV_Misc_QuestionMark",emblemAspect=1})
assert(v.icon.path=="Interface\\Icons\\INV_Misc_QuestionMark")
assert(v.label.text=="DUEL ARENA" and future.textures[1].path:find("DRMenuPlates.png",1,true))
print("Shared menu button renderer: PASS (11 unique emblems, live font scaling, resize, independent states, future destination)")

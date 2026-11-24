-- Actual deterministic competitive fixtures and page controllers, mocked
-- frame APIs only. Not a WoW render, API availability or live PvP test.
local base="addon/DuelsReimagined/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol"}) do
    assert(loadfile(base.."Core/"..name..".lua"))("DuelsReimagined",ns)
end
assert(loadfile(base.."UI/CompetitivePreview.lua"))("DuelsReimagined",ns)
local cache={}
for _,client in ipairs({"forever","retail"}) do
    local d=ns.CompetitivePreview.Build(client);cache[client]=d
    assert(d.scope=="SIMULATED" and not d.rankEligible and d.current==3)
    local b=d.view.Leaderboard(3,0,100,"","rating")
    assert(b.total>5 and #b.rows==b.total)
    assert(d.view.ProfileSummary(d.me,3).rating and d.personal.total==#d.matches)
    local seen={}
    for _,m in ipairs(d.matches) do
        seen[m.category]=true
        if m.category=="Ranked" then assert(m.before and m.after and m.delta==m.after-m.before and m.confirmed) end
        if m.category=="Pending" or m.category=="Disputed" then assert(m.delta==nil) end
    end
    assert(seen.Ranked and seen.Practice and seen.Disputed and seen.Pending and seen.Unranked)
    assert(d.view.Leaderboard(3,0,100,"voidreign","rating").total==1)
end
-- Minimal frame mock: tracks scripts, visibility, sizes and text; rendering
-- is deliberately not certified here. Parent anchors get content dimensions.
local frames={}
local noop=function()end
local methods={}
function methods:SetSize(w,h)self.w=w;self.h=h end
function methods:SetWidth(w)self.w=w end
function methods:SetHeight(h)self.h=h end
function methods:GetWidth()return self.w or 0 end
function methods:GetHeight()return self.h or 0 end
function methods:SetPoint(...)self.point={...};if not self.w then self.w=960 end;if not self.h then self.h=620 end end
function methods:ClearAllPoints()self.point=nil end
function methods:SetAllPoints()end
function methods:SetScript(k,f)self.scripts[k]=f end
function methods:HookScript(k,f)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;f(...)end end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:Show()local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(t)self.text=t end
function methods:GetText()return self.text end
function methods:GetAlpha()return self.alpha or 1 end
function methods:SetAlpha(a)self.alpha=a end
function methods:GetFrameLevel()return 1 end
function methods:GetEffectiveScale()return 1 end
local function Frame(parent)
    local f=setmetatable({parent=parent,scripts={},shown=true}, {__index=function(_,k)return methods[k] or (type(k)=="string" and k:match("^[A-Z]") and noop or nil) end})
    frames[#frames+1]=f;return f
end
function methods:CreateTexture()return Frame(self)end
function methods:CreateFontString()return Frame(self)end
CreateFrame=function(_,name,parent)local f=Frame(parent);if name then _G[name]=f end;return f end
local C=setmetatable({}, {__index=function(t,k)local v={1,1,1,1};rawset(t,k,v);return v end})
ns.Style={color=C,Text=function(parent,t)local f=Frame(parent);f:SetText(t);return f end,Fill=function(parent)return Frame(parent)end,
    Skin=noop,Plate=noop,Action=function(parent,t)local f=Frame(parent);f.label=Frame(f);f.label:SetText(t);return f end,BindFont=noop}
ns.Motion={Fade=function(f,a)f:SetAlpha(a)end,Stop=function(f,a)f:SetAlpha(a or 0)end}
ns.Chrome={Sharp=noop,Icon=function(parent)return Frame(parent)end,Divider=function(parent)return Frame(parent)end}
ns.Widgets={PressFeedback=noop,ChoiceControl=function(parent)local f=Frame(parent);return f,Frame(f)end,OpenChoices=noop,
    CloseChoices=noop,ScrollBar=function(parent)local f=Frame(parent);f.Refresh=noop;return f end}
UIParent=Frame(nil);UIParent:SetSize(1440,900)
local main=Frame(UIParent)
ns.Window={frame=main,content=Frame(main)}
ns.Window.content:SetSize(960,620)
ns.Header={CreateCloseButton=function(parent)return Frame(parent)end}
UISpecialFrames={"OtherBefore","DuelsReimaginedWindow","OtherAfter"}
ns.DiagnosticAudit={RegisterUIRoot=noop}
ns.Diagnostics={Record=function(_,detail)error(detail)end}
local navigations=0
ns.Navigation={SelectKey=function()navigations=navigations+1 end}
ns.Client={Kind=function()return "retail" end}
ns.CompetitivePreview.Get=function()return cache.retail end
assert(loadfile(base.."UI/CompetitiveUI.lua"))("DuelsReimagined",ns)
local U=ns.CompetitiveUI
local count=#frames
for _,key in ipairs({"overview","standings","history","standings","overview"}) do
    U.Show(key);U.Refresh();U.SetPageScroll(key,3)
end
U.Show("standings");U.SetPageScroll("standings",3)
local before=U.GetPageScroll("standings")
local d=cache.retail
local row=d.view.Leaderboard(d.current,0,5,"","rating").rows[1]
U.OpenPlayerCard(row.id)
assert(U.IsPlayerCardOpen() and navigations==0 and U.GetPageScroll("standings")==before)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,OtherAfter,DuelsReimaginedPlayerCard")
U.OpenPlayerCard(d.me);U.Refresh()
assert(U.IsPlayerCardOpen() and navigations==0)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,OtherAfter,DuelsReimaginedPlayerCard")
U.ClosePlayerCard()
assert(not U.IsPlayerCardOpen() and U.GetPageScroll("standings")==before)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,DuelsReimaginedWindow,OtherAfter")
U.OpenPlayerCard(d.me);main:Hide()
assert(not U.IsPlayerCardOpen() and table.concat(UISpecialFrames,",")=="OtherBefore,DuelsReimaginedWindow,OtherAfter")
U.Show(nil)
assert(#frames==count,"page navigation must reuse frames")
assert(_G.DuelsReimaginedCompetitiveDB==nil and _G.DuelsReimaginedCharacterDB==nil)
print("Competitive UI simulated data and mocked page controllers: PASS")

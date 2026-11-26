local _,ns=...
-- Browse is a read-only presentation of the existing catalog. Registration,
-- discovery, bracket creation, and validation remain in their original owners.
local B={};ns.TournamentBrowse=B
local S,C,W=ns.Style,ns.Style.color,ns.Widgets
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\TournamentBrowseArt.png"
local green={.58,1,.24,1};local amber={1,.75,.20,1};local grey={.70,.68,.65,1}
local rect={logo={0,0,96,82},community={100,0,65,55},flag={170,0,36,44},location={212,34,25,29},players={244,34,29,25},swords={275,1,28,28},laurelL={312,34,28,33},laurelR={344,34,32,33},landscape={0,120,240,124},statusLight={400,60,32,32}}
for i=1,7 do rect[i]={212+(i-1)*32,0,28,28} end
-- Use the clean format swords for every small crossed-swords icon.
rect[3]=rect.swords
-- The hourglass artwork sits left and low in its original cell.
-- Recenter the square crop in the atlas gutter without stretching the art.
rect[2]={241,2,28,28}
local filters={{key="all",label="All Tournaments"},{key="open",label="Open registration"},{key="filling",label="Filling"},{key="full",label="Full"},{key="closed",label="Closed"}}
function B.Status(ad,now)
    if not ad or not ad.draft or ad.state~="open" then return "closed","Closed",false end
    local d=ad.draft
    if type(now)~="number" or type(d.registrationClosesAt)~="number" then return "unknown","Unavailable",false end
    if now>=d.registrationClosesAt then return "closed","Closed",false end
    if ad.count>=d.capacity then return "full","Full",false end
    if ad.count/d.capacity>=.85 then return "filling","Filling",true end
    return "registering","Registering",true
end
function B.Project(rows,now,filter)
    local out={}
    for index,ad in ipairs(rows or {}) do
        local key,label,joinable=B.Status(ad,now)
        if filter=="all" or not filter or filter==key or filter=="open" and joinable then
            out[#out+1]={id=ad.id,index=index,ad=ad,status=key,statusText=label,joinable=joinable}
        end
    end
    return out
end
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,size,color,align)
    local t=S.Text(p,"",size,color);t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(true);return t
end
local function Text(t,p,x,y,w,h,value,color,min)
    At(t,p,x,y,w,h);t:SetText(value or "")
    if color then t:SetTextColor(unpack(color)) end
    if min and S.ConstrainText then S.ConstrainText(t,w,h,min) end
end
local function Art(p,key,layer)
    local t=p:CreateTexture(nil,layer or "ARTWORK");t:SetTexture(ART);ns.Chrome.Sharp(t)
    local r=rect[key];t:SetTexCoord(r[1]/512,(r[1]+r[3])/512,r[2]/256,(r[2]+r[4])/256);return t
end
local function Panel(p,bright)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=10,edge=bright and C.gold or C.goldDim,light=C.goldDim,dark=C.window,shine=.22,shade=.18,rim=1})
    return f
end
local function Action(p,primary,size,reserveArrow)
    local palette={text=C.pale,edge=primary and C.gold or C.goldDim,hover=C.gold,tooltip=false,
        fontSize=size or 20,minimumFont=13,refitOnText=true,
        feedback={hoverAlpha=.55,downAlpha=.82,downHover=.88,clickAlpha=.86,corner=9}}
    palette.plate=primary and "browsePrimary" or "browseCard"
    if reserveArrow then palette.labelRight=30 end
    return S.Action(p,"","footer",palette)
end
local function Bind(b,caption,enabled,reason,fn,help)
    b.label:SetText(caption);b:SetEnabled(enabled==true);b:SetAlpha(enabled and 1 or .52)
    b:SetScript("OnClick",function()if enabled then fn() end end)
    b.browseReason=reason;b.browseHelp=help;b.browseCaption=caption
    if not b.browseTip and ns.Tooltips then
        b.browseTip=true
        ns.Tooltips.Bind(b,function(owner)
            if owner:IsEnabled() then
                if owner.browseHelp then return {title=owner.browseCaption,detail=owner.browseHelp} end
                return nil
            end
            return {title=owner.browseCaption,disabled=owner.browseReason}
        end)
    end
end
local function Row(p)
    local b=Action(p,false,18);b.label:Hide()
    local selected=S.FeedbackOverlay(b,{corner=9,inset=1,fill=C.gold,edge=C.gold,shine=.36,rim=1})
    local r={button=b,selected=selected,logo=Art(b,"logo"),title=Label(b,25,C.pale),
        people=Art(b,"players"),swords=Art(b,"swords"),count=Label(b,17,C.text),format=Label(b,17,C.text)}
    local badge=CreateFrame("Frame",nil,b)
    r.badge=badge
    -- Status is lightweight text and a tintable circular light, never a button.
    r.badgeText=Label(badge,16,C.text,"LEFT")
    r.dot=Art(badge,"statusLight","ARTWORK")
    return r
end
local function PaintRow(r,entry,w,y,selected,cb)
    local b=r.button;b:SetShown(entry~=nil)
    if not entry then return end
    local ad=entry.ad;local badgeW=128
    At(b,b:GetParent(),10,y,w-20,88)
    local bw=w-20
    r.selected:SetAlpha(selected and 1 or 0)
    At(r.logo,b,13,5,91,78)
    Text(r.title,b,116,8,bw-116-badgeW-20,36,ad.draft.name,C.pale,17)
    At(r.people,b,117,53,23,20)
    Text(r.count,b,145,46,122,31,ad.count.." / "..ad.draft.capacity.." Players",C.text,13)
    At(r.swords,b,277,53,24,20)
    Text(r.format,b,306,46,bw-306-badgeW-13,31,"Best of "..ad.draft.bestOf,C.text,13)
    At(r.badge,b,bw-badgeW-10,27,badgeW,34)
    local color=entry.status=="registering" and green or entry.status=="filling" and amber or grey
    r.dot:SetVertexColor(unpack(color));At(r.dot,r.badge,1,5,24,24)
    Text(r.badgeText,r.badge,25,0,badgeW-28,34,entry.statusText,color,12)
    b:SetScript("OnClick",function()cb(entry.id)end)
end
local function Community(parent)
    local f=Panel(parent,true)
    local d={frame=f,icon=Art(f,"community"),title=Label(f,23,C.pale),labels={},values={},rules={}}
    for i=1,4 do
        d.labels[i]=Label(f,14,C.muted);d.values[i]=Label(f,21,C.pale);d.rules[i]=S.Fill(f,C.goldDim,"BORDER")
    end
    return d
end
local function PaintCommunity(d,scope,base,wide)
    local f=d.frame;local h=wide and 66 or 120
    At(f,f:GetParent(),0,0,base,h)
    At(d.icon,f,17,7,58,50)
    Text(d.title,f,88,5,wide and 293 or base-100,53,"Tournament community",C.pale,17)
    local names={"Game client","Region","Ruleset","Faction"}
    local modes={normal="PvE",pvp="PvP",rp="RP",["rp-pvp"]="RP-PvP",hardcore="Hardcore",retail="Standard"}
    local vals={scope.client=="forever" and "Forever" or scope.client=="retail" and "Retail" or "Unavailable",
        scope.region=="EU" and "Europe (EU)" or scope.region=="US" and "Americas (US)" or "Unavailable",
        modes[scope.ruleset] or "Unavailable",scope.faction or "Unavailable"}
    local x=wide and 390 or 14;local cw=(base-x-12)/4
    for i=1,4 do
        local ox=x+(i-1)*cw;local oy=wide and 5 or 61
        At(d.rules[i],f,ox,oy+5,1,45);d.rules[i]:SetAlpha(.45)
        Text(d.labels[i],f,ox+14,oy,cw-20,23,names[i],C.muted,11)
        Text(d.values[i],f,ox+14,oy+23,cw-20,30,vals[i],i==4 and (scope.faction=="Alliance" and {.35,.70,1,1} or scope.faction=="Horde" and {1,.38,.31,1} or C.pale) or C.pale,14)
    end
    return h
end
-- Shared tournament presentation primitives. Host and Browse use the
-- same art, native action skin and compact community strip.
B.Chrome={Art=Art,Panel=Panel,Action=Action,NewCommunity=Community,PaintCommunity=PaintCommunity}
local detailNames={"Start Time:","Registration Closes:","Format:","Players:","Levels:","Rules:","Organizer:"}
local function Detail(parent)
    local f=Panel(parent,true);local d={frame=f,title=Label(f,25,C.pale,"CENTER"),la=Art(f,"laurelL"),ra=Art(f,"laurelR"),
        hero=Panel(f,true),empty=Label(f,19,C.muted,"CENTER"),rows={},join=Action(f,true,23),bracket=Action(f,false,18),note=Label(f,15,C.muted,"CENTER")}
    d.scene=Art(d.hero,"landscape","ARTWORK")
    d.logo=Art(d.hero,"logo");d.name=Label(d.hero,27,C.pale);d.pin=Art(d.hero,"location");d.location=Label(d.hero,19,C.pale)
    for i=1,7 do d.rows[i]={icon=Art(f,i),label=Label(f,18,C.pale),value=Label(f,18,C.text),line=S.Fill(f,C.goldDim,"BORDER")} end
    return d
end
local function DetailHeight(e)
    local rules=e and e.ad.draft.rules or ""
    return 502+math.max(0,math.ceil(#rules/34)-1)*22
end
local function PaintDetail(d,e,w,h,model,confirmed,cb)
    local f=d.frame
    Text(d.title,f,64,4,w-128,44,"Tournament Details",C.pale,20)
    At(d.la,f,34,9,29,31);At(d.ra,f,w-63,9,29,31)
    d.hero:SetShown(e~=nil);d.empty:SetShown(e==nil);d.join:SetShown(e~=nil);d.bracket:SetShown(e~=nil)
    d.note:SetShown(e~=nil)
    for _,r in ipairs(d.rows) do
        r.icon:SetShown(e~=nil);r.label:SetShown(e~=nil);r.value:SetShown(e~=nil);r.line:SetShown(e~=nil)
    end
    if not e then
        Text(d.empty,f,24,75,w-48,h-104,"Select a tournament to view its details and rules.");return
    end
    local ad=e.ad;local draft=ad.draft
    At(d.hero,f,12,49,w-24,110)
    local hw=w-24
    -- Only the approved Elwynn scene is present; don't represent unrelated
    -- locations with invented scenery or faction art.
    d.scene:SetShown(draft.location=="Elwynn Forest" and model.scope.faction=="Alliance")
    At(d.scene,d.hero,hw-154,4,150,102)
    At(d.logo,d.hero,16,10,100,86)
    Text(d.name,d.hero,133,12,hw-145,48,draft.name,C.pale,18)
    At(d.pin,d.hero,135,65,17,21)
    Text(d.location,d.hero,159,56,hw-172,40,draft.location,C.pale,14)
    local times=ns.TournamentState.GetSchedulePreview(draft.startUTC,draft.closeBefore)
    local vals={times and times.starts.." (local time)" or draft.startUTC.." UTC",
        times and times.closes or (draft.closeBefore==0 and "At start (UTC)" or draft.closeBefore.." minutes before start"),
        "Single elimination - Best of "..draft.bestOf,ad.count.." / "..draft.capacity,
        (draft.minLevel>0 and draft.minLevel or "Any").." - "..(draft.maxLevel>0 and draft.maxLevel or "Any"),
        draft.rules~="" and draft.rules or "None specified",ad.organizer}
    local y=166
    for i,r in ipairs(d.rows) do
        local rh=i==6 and 31+h-502 or 31
        At(r.icon,f,19,y+5,23,23)
        Text(r.label,f,51,y,w*.43-53,rh,detailNames[i],C.pale,14)
        Text(r.value,f,w*.43,y,w*.57-20,rh,tostring(vals[i] or "Unavailable"),C.text,i==6 and nil or 13)
        At(r.line,f,18,y+rh,w-36,1);r.line:SetAlpha(.34);y=y+rh
    end
    local canJoin=model.canJoin and e.joinable
    At(d.join,f,18,h-99,(w-46)*.63,57)
    At(d.bracket,f,26+(w-46)*.63,h-93,(w-46)*.37,45)
    Bind(d.join,confirmed and "Confirm Join" or "Inspect & Join",canJoin,
        not e.joinable and e.statusText or "You already have an active tournament.",function()cb("join",e)end)
    local bracketLabel=model.catalog and "Test Bracket" or model.organizer and "Organizer View" or "View Bracket"
    Bind(d.bracket,bracketLabel,model.catalog or model.organizer or model.hasBracket,
        "The bracket will be available after the tournament starts.",function()cb("bracket",e)end,
        model.catalog and "Start a simulated bracket to watch this local test tournament." or nil)
    Text(d.note,f,14,h-34,w-28,27,confirmed and "Confirm registration for this tournament." or model.feedback or "",C.muted,12)
end
function B.New(parent,action,refresh)
    local f=CreateFrame("Frame",nil,parent);f:Hide()
    local community=Community(f)
    local list=Panel(f,false)
    local listIcon=Art(list,"flag");local listTitle=Label(list,24,C.pale)
    local filter=Action(list,false,18,true)
    local filterArrow=filter:CreateTexture(nil,"ARTWORK");filterArrow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\FoldDown.png");ns.Chrome.Sharp(filterArrow)
    local rule=S.Fill(list,C.goldDim,"BORDER")
    local cards={};for i=1,4 do cards[i]=Row(list) end
    local empty=Label(list,19,C.muted,"CENTER")
    local note=Label(list,15,C.muted,"CENTER")
    local open=Action(list,false,20)
    local detail=Detail(f)
    local selected,filterKey,offset,confirmation,lastModel="","all",0,nil,nil
    local D={}
    local function Close() W.CloseChoices();confirmation=nil end
    f:HookScript("OnHide",Close)
    function D.Hide() Close();f:Hide() end
    local function RenderAgain() if refresh then refresh() end end
    local function Choose(id)
        selected=id;confirmation=nil;RenderAgain()
    end
    local function Dispatch(kind,e)
        if kind=="join" then
            local token=e.id..":"..tostring(e.ad.revision)
            if confirmation~=token then confirmation=token;RenderAgain();return end
        end
        confirmation=nil;action(kind,e)
    end
    function D.Show(model,width)
        local wide=width>=760;local base=wide and 1170 or 610;local scale=width/base
        local entries=B.Project(model.rows,model.now,filterKey)
        local e
        for i,v in ipairs(entries) do if v.id==selected then e=v;offset=math.max(0,math.min(offset,math.max(0,#entries-4)));break end end
        if not e then e=entries[1];selected=e and e.id or "";confirmation=nil;offset=0 end
        if lastModel~=model.context then confirmation=nil;lastModel=model.context end
        local confirmed=e and confirmation==e.id..":"..tostring(e.ad.revision)
        local left=wide and 592 or base;local right=wide and base-left-12 or base
        local h=DetailHeight(e);local listH=502
        local top=wide and 78 or 132
        local total=top+(wide and math.max(h,listH) or listH+12+h)
        f:SetScale(scale);At(f,parent,0,0,base,total);f:Show()
        PaintCommunity(community,model.scope or {},base,wide)
        At(list,f,0,top,left,listH);At(detail.frame,f,wide and left+12 or 0,wide and top or top+listH+12,right,h)
        At(listIcon,list,14,9,30,37);Text(listTitle,list,57,6,left-245,43,"Browse Tournaments",C.pale,18)
        At(filter,list,left-192,13,176,34);At(filterArrow,filter,151,10,15,15)
        local caption="All Tournaments"
        for _,opt in ipairs(filters) do if opt.key==filterKey then caption=opt.label end end
        Bind(filter,caption,true,nil,function()
            W.OpenChoices(filter,filters,filterKey,function(k)filterKey=k;selected="";offset=0;confirmation=nil;RenderAgain()end)
        end)
        At(rule,list,12,53,left-24,1);rule:SetAlpha(.7)
        for i,r in ipairs(cards) do PaintRow(r,entries[offset+i],left,66+(i-1)*96,entries[offset+i] and entries[offset+i].id==selected,Choose) end
        empty:SetShown(#entries==0);open:SetShown(model.canOpenTest==true)
        Text(empty,list,24,120,left-48,140,#(model.rows or {})>0 and "No tournaments match this filter." or "No tournaments discovered.")
        At(open,list,30,282,left-60,44)
        Bind(open,"Browse Test Tournaments",model.canOpenTest,nil,function()filterKey="all";selected="";action("open")end)
        Text(note,list,14,455,left-28,40,model.catalog and "Local test tournaments only. Choose a tournament to inspect or join." or model.preview and "Local rehearsal only. Nothing is published online." or "Tournament discovery is not active yet.",C.muted,12)
        PaintDetail(detail,e,right,h,model,confirmed,Dispatch)
        return total*scale
    end
    return D
end
function B.RunSelfTest()
    local function ad(id,count,state,deadline)
        return {id=id,count=count,state=state,draft={capacity=16,registrationClosesAt=deadline}}
    end
    local rows={ad("a",3,"open",100),ad("b",15,"open",100),ad("c",16,"open",100),ad("d",1,"open",10)}
    local all=B.Project(rows,20,"all");assert(#all==4 and all[1].status=="registering" and all[2].status=="filling" and all[3].status=="full" and all[4].status=="closed")
    local opened=B.Project(rows,20,"open");assert(#opened==2 and opened[2].index==2)
    local full=B.Project(rows,20,"full");assert(#full==1 and full[1].id=="c" and full[1].index==3 and not full[1].joinable)
    assert(#B.Project(rows,100,"open")==0 and #B.Project({},20,"all")==0)
    local _,_,joinable=B.Status(rows[1],nil);assert(not joinable)
    return true
end

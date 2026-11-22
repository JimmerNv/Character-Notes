local _, CN = ...
local W, L, P = CN.widgets, CN.L, CN.talents

local function className(token)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token
end

local function entryInfo(entry)
    if not entry then return '?',134400 end
    local spell = C_Spell.GetSpellInfo(entry.spell)
    local name = entry.name and entry.name ~= '' and entry.name
    local icon = entry.icon and entry.icon ~= 0 and entry.icon
    return name or (spell and spell.name) or tostring(entry.spell), icon or (spell and spell.iconID) or 134400
end

local function hint(button, text)
    button:HookScript('OnEnter',function(b)
        GameTooltip:SetOwner(b,'ANCHOR_TOP')
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    button:HookScript('OnLeave',function() GameTooltip:Hide() end)
end

local function tooltip(button)
    local f, n = CN.planner, button.node
    local entry = P.entry(n,f.build) or n.entries[1]
    local rank = f.build.ranks[n.id] or 0
    GameTooltip:SetOwner(button,'ANCHOR_RIGHT')
    -- The trait tooltip receives a rank, unlike the generic spell tooltip.
    if GameTooltip.SetTraitEntry then
        GameTooltip:SetTraitEntry(entry.id,math.max(1,rank))
    elseif GameTooltip.AppendInfo then
        GameTooltip:SetText((entryInfo(entry)))
        GameTooltip:AppendInfo('GetTraitEntry',entry.id,math.max(1,rank))
    elseif entry.spell and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(entry.spell)
    else
        GameTooltip:SetText((entryInfo(entry)))
    end
    GameTooltip:AddLine(('%d / %d'):format(rank,n.max),1,.85,.35)
    local needed = math.max(n.cost,entry.cost)
    if needed>0 then GameTooltip:AddLine(L.TREE_NEEDS:format(needed),.8,.85,.93,true) end
    for _, ids in ipairs({n.required,n.any}) do
        for _, id in ipairs(ids) do
            local parent = f.model.nodes[id]
            local name = entryInfo(P.entry(parent,f.build))
            GameTooltip:AddLine(('%s  %d/%d'):format(name,f.build.ranks[id] or 0,parent.max),.8,.85,.93,true)
        end
    end
    if #n.entries>1 then GameTooltip:AddLine(L.SWITCH_CHOICE,.65,.85,1,true) end
    GameTooltip:Show()
end

local function status(f,text)
    f.message:SetText(text or '')
end

local function accept(f,build)
    f.build = build
    f.drafts[build.class] = build
    if f.note then
        f.note:setBuild(build)
    end
    status(f)
    f:Refresh()
end

local function talentClick(button, key)
    local f, node = CN.planner,button.node
    if f.note and IsControlKeyDown and IsControlKeyDown() then
        local entry = P.entry(node,f.build) or node.entries[1]
        local link
        if entry and entry.spell then
            if C_Spell and C_Spell.GetSpellLink then link=C_Spell.GetSpellLink(entry.spell)
            elseif GetSpellLink then link=GetSpellLink(entry.spell) end
        end
        if link and not CN:IsSecret(link) and f.note.body then
            f.note.body:Insert(link)
            f.note.markDirty()
            status(f,L.TALENT_LINK_ADDED)
        else status(f,L.TALENT_LINK_UNAVAILABLE) end
        return
    end
    local candidate
    if IsShiftKeyDown() and #node.entries>1 then
        candidate = P.copy(f.build)
        local current = P.entry(node,candidate)
        for i,e in ipairs(node.entries) do
            if e==current then
                candidate.choices[node.id] = node.entries[i%#node.entries+1].id
                break
            end
        end
        if not P.valid(f.model,candidate) then candidate = nil end
    else
        candidate = P.adjust(f.model,f.build,node.id,key=='RightButton' and -1 or 1)
    end
    if candidate then accept(f,candidate); tooltip(button) else status(f,L.BLOCKED_RANK) end
end

local function talentButton(pane)
    local b = CreateFrame('Button',nil,pane)
    b:SetSize(33,33)
    W.backdrop(b)
    b.icon = b:CreateTexture(nil,'ARTWORK')
    b.icon:SetPoint('TOPLEFT',2,-2)
    b.icon:SetPoint('BOTTOMRIGHT',-2,2)
    b.icon:SetTexCoord(.07,.93,.07,.93)
    b.rank = b:CreateFontString(nil,'OVERLAY','NumberFontNormalSmall')
    b.rank:SetPoint('BOTTOMRIGHT',2,-2)
    b.rank:SetShadowOffset(1,-1)
    b:RegisterForClicks('LeftButtonUp','RightButtonUp')
    b:SetScript('OnClick',talentClick)
    b:SetScript('OnEnter',tooltip)
    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    return b
end

local function drawPane(f,pane,tree,used,spent)
    for _, b in ipairs(pane.buttons) do b:Hide() end
    for _, line in ipairs(pane.lines) do line:Hide() end
    pane.title:SetText(tree and (tree.name .. '   ' .. spent[tree.index]) or '')
    if not tree then return end
    local function center(n)
        return 25+n.col*192/(tree.cols-1), -48-n.row*213/(tree.rows-1)
    end
    local lines = 0
    for i,n in ipairs(tree.nodes) do
        local x,y = center(n)
        local b = pane.buttons[i] or talentButton(pane)
        pane.buttons[i] = b
        b.node = n
        b:ClearAllPoints()
        b:SetPoint('CENTER',pane,'TOPLEFT',x,y)
        local _,icon = entryInfo(P.entry(n,f.build))
        b.icon:SetTexture(icon)
        local rank = f.build.ranks[n.id] or 0
        local enabled = rank>0 or P.canAdd(f.model,f.build,n,used,spent)
        b.icon:SetDesaturated(not enabled)
        b.rank:SetText(rank..'/'..n.max)
        b.rank:SetTextColor(rank>0 and 1 or .85,rank>0 and .82 or .9,rank>0 and .35 or 1)
        W.backdrop(b,1,rank>0)
        b:Show()
        for _, sources in ipairs({n.required,n.any}) do
            for _, id in ipairs(sources) do
                local src = f.model.nodes[id]
                if src.tree == n.tree then
                    lines = lines+1
                    local line = pane.lines[lines] or pane:CreateLine(nil,'BORDER')
                    pane.lines[lines] = line
                    local sx,sy = center(src)
                    line:SetThickness(2)
                    line:SetColorTexture(.55,.63,.76,1)
                    line:SetStartPoint('TOPLEFT',pane,sx,sy)
                    line:SetEndPoint('TOPLEFT',pane,x,y)
                    line:Show()
                end
            end
        end
    end
end

local function templates(f)
    if not f.library then
        local lib = CN:NotePanel(f,20)
        lib:ClearAllPoints()
        lib:SetAllPoints(f)
        f.library = lib
        local heading = W.caption(lib,L.TEMPLATES,22,-20,16)
        local list = W.list(lib,22,-62,329,365)
        W.caption(lib,L.NOTE_TITLE,375,-68)
        local name = W.edit(lib,377,28)
        name:SetPoint('TOPLEFT',375,-92)
        local feedback = W.caption(lib,'',375,-144)
        feedback:SetWidth(376)
        local function bucket()
            local all = CN.db.talentTemplates
            all[f.build.class] = all[f.build.class] or {}
            return all[f.build.class]
        end
        local selected
        local function refresh()
            local rows = {}
            for title in pairs(bucket()) do rows[#rows+1] = {key=title,label=title} end
            table.sort(rows,function(a,b) return a.key:lower()<b.key:lower() end)
            list(rows,function(key)
                selected = key
                name:SetText(key)
                feedback:SetText('')
                refresh()
            end,selected)
        end
        W.action(lib,L.SAVE,180,375,-193,function()
            local title = name:GetText():match('^%s*(.-)%s*$')
            if title=='' then feedback:SetText(L.NEED_TITLE); return end
            if bucket()[title] and selected~=title then feedback:SetText(L.SELECT_TEMPLATE); return end
            if not P.valid(f.model,f.build) then feedback:SetText(L.INVALID_BUILD); return end
            bucket()[title] = P.copy(f.build)
            selected = title
            refresh()
            feedback:SetText(L.NOTE_SAVED)
        end)
        W.action(lib,L.LOAD_BUILD,180,570,-193,function()
            if not selected then feedback:SetText(L.SELECT_TEMPLATE); return end
            local saved = bucket()[selected]
            if not P.valid(f.model,saved) then feedback:SetText(L.INVALID_BUILD); return end
            lib:Hide()
            accept(f,P.copy(saved))
        end)
        W.action(lib,L.DUPLICATE,180,375,-235,function()
            if not selected then feedback:SetText(L.SELECT_TEMPLATE); return end
            local title, i = selected,2
            while bucket()[title] do title=selected..' ('..i..')'; i=i+1 end
            bucket()[title] = P.copy(bucket()[selected])
            selected = title
            name:SetText(title)
            refresh()
        end)
        W.action(lib,L.REMOVE,180,570,-235,function()
            if not selected then feedback:SetText(L.SELECT_TEMPLATE); return end
            bucket()[selected] = nil
            selected = nil
            name:SetText('')
            feedback:SetText('')
            refresh()
        end)
        W.action(lib,L.BACK,180,570,-369,function() lib:Hide() end)
        lib:SetScript('OnHide',function() name:ClearFocus() end)
        lib.open = function()
            selected = nil
            name:SetMaxLetters(100)
            name:SetText('')
            feedback:SetText('')
            heading:SetText(L.TEMPLATES .. '  ·  ' .. className(f.build.class))
            refresh()
            lib:Show()
        end
    end
    f.library.open()
end

local function makePlanner()
    local f = CreateFrame('Frame','ElvUICharNotesPlanner',UIParent)
    f:SetSize(800,520)
    f:SetPoint('TOPLEFT',CN.window,'TOPRIGHT',12,0)
    f:SetFrameStrata('DIALOG')
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',f.StartMoving)
    f:SetScript('OnDragStop',f.StopMovingOrSizing)
    W.backdrop(f)
    f:Hide()
    f.heading = W.caption(f,'',19,-14,16)
    local close = W.button(f,'X',26,26,function() f:Hide() end)
    close:SetPoint('TOPRIGHT',-13,-12)
    f.close = close
    f.budget = W.label(f,'',14)
    f.budget:SetPoint('TOPRIGHT',-53,-16)
    f.message = W.caption(f,'',19,-397)
    f.message:SetWidth(753)
    f.message:SetJustifyH('LEFT')
    f.panes, f.classButtons = {},{}
    function f:Refresh()
        local model,build = self.model,self.build
        local entry = self.note and self.note.builds[self.note.activeBuild]
        self.heading:SetText(L.TALENT_PLANNER .. '  ·  ' ..
            (entry and (entry.name .. '  ·  ') or '') .. className(build.class))
        local used,trees = 0,{}
        if model then used,trees = P.totals(model,build) end
        self.budget:SetText(model and L.POINTS_LEFT:format(model.cap-used,model.cap) or '')
        for i,pane in ipairs(self.panes) do drawPane(self,pane,model and model.trees[i],used,trees) end
        for token,b in pairs(self.classButtons) do
            W.backdrop(b,1,token==build.class)
            b.icon:SetDesaturated(token~=build.class)
        end
        if not model then status(self,L.TREE_UNAVAILABLE)
        elseif not P.valid(model,build) then status(self,L.INVALID_BUILD) end
    end
    for i,token in ipairs(P.classes) do
        local b = CreateFrame('Button',nil,f)
        b:SetSize(35,35)
        b:SetPoint('TOPLEFT',20+(i-1)*44,-43)
        W.backdrop(b)
        local icon = b:CreateTexture(nil,'ARTWORK')
        b.icon = icon
        icon:SetPoint('TOPLEFT',2,-2)
        icon:SetPoint('BOTTOMRIGHT',-2,2)
        icon:SetTexture('Interface\\Icons\\ClassIcon_'..token)
        b:SetScript('OnClick',function()
            local model = P.model(token)
            local draft = f.drafts[token] or P.blank(token)
            f.classSelected = true
            f.model,f.build = model,draft
            if f.note and model and P.valid(model,draft) then
                accept(f,draft)
            else
                status(f)
                f:Refresh()
            end
        end)
        f.classButtons[token] = b
        hint(b,className(token))
    end
    for i=1,3 do
        local pane = CreateFrame('Frame',nil,f)
        pane:SetSize(245,288)
        pane:SetPoint('TOPLEFT',19+(i-1)*257,-96)
        W.backdrop(pane)
        pane.title = W.label(pane,'',13)
        pane.title:SetPoint('TOP',0,-8)
        pane.buttons,pane.lines = {},{}
        f.panes[i] = pane
    end
    W.action(f,L.LIVE_BUILD,222,19,-443,function()
        local build = P.capture(f.model)
        if build then accept(f,build) else status(f,L.IMPORT_FAILED) end
    end)
    W.action(f,L.TEMPLATES,162,250,-443,function()
        if f.model then templates(f) else status(f,L.TREE_UNAVAILABLE) end
    end)
    W.action(f,L.RESET_BUILD,145,422,-443,function()
        if f.model then accept(f,P.blank(f.build.class)) end
    end)
    local back = W.action(f,L.BACK,197,580,-443,function() f:Hide() end)
    W.caption(f,L.TALENT_CLICKS,20,-488,11)
    W.caption(f,L.TALENT_LINK_HINT,20,-506,11)
    f.back = back
    f:SetScript('OnHide',function()
        if f.library then f.library:Hide() end
        f.note = nil
    end)
    return f
end

function CN:ShowTalentPlanner(fromNote)
    if not self.window then return end
    if not self.window:IsShown() then self:ShowWindow() end
    local note = fromNote and self.notebook and self.notebook:IsShown() and self.notebook or nil
    self.planner = self.planner or makePlanner()
    local f = self.planner
    f.note = note
    f.classSelected = false
    f.build = P.copy(note and note.build) or P.blank()
    f.drafts = {[f.build.class]=f.build}
    f.model = P.model(f.build.class)
    f.back:SetText(note and L.HIDE_PLANNER or L.BACK)
    status(f)
    f:Refresh()
    f:Show()
    f:Raise()
end

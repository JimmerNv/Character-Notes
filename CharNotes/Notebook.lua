local _, CN = ...
local W, L, P = CN.widgets, CN.L, CN.talents
CN.MAX_BUILDS_PER_NOTE = 10
local linkKinds = {item=true, spell=true, talent=true, trait=true, trade=true, enchant=true}

function CN:InsertNoteLink(text)
    local body = self.notebook and self.notebook.body
    if not body or not body:HasFocus() or self:IsSecret(text) or
            type(text) ~= 'string' or #text > 1024 then return false end
    local kind = text:match('|H([%w]+):')
    if not linkKinds[kind] or not text:find('|h',1,true) then return false end
    body:Insert(text)
    if self.notebook.markDirty then self.notebook.markDirty() end
    return true
end

function CN:PostNoteLink(link, text, button, postToChat)
    if self:IsSecret(link) or self:IsSecret(text) then return false end
    local kind = type(link) == 'string' and link:match('^([%w]+):')
    if not linkKinds[kind] or type(text) ~= 'string' or #text > 1024 then return false end
    if postToChat or (IsShiftKeyDown and IsShiftKeyDown()) then
        if not text:find('|H'..link..'|h',1,true) then return false end
        if self.notebook and self.notebook.body then self.notebook.body:ClearFocus() end
        if ChatFrameUtil and ChatFrameUtil.OpenChat then
            if ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow() and ChatFrameUtil.InsertLink then
                ChatFrameUtil.InsertLink(text)
            else ChatFrameUtil.OpenChat(text) end
        elseif ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then
            ChatEdit_InsertLink(text)
        elseif ChatFrame_OpenChat then ChatFrame_OpenChat(text)
        else return false end
    elseif SetItemRef then SetItemRef(link,text,button or 'LeftButton')
    else return false end
    return true
end

function CN:PostNoteLinkAtCursor()
    local body = self.notebook and self.notebook.body
    if not body then return false end
    local content, position = body:GetText() or '', body:GetCursorPosition()
    local search = 1
    while true do
        local first, headerEnd = content:find('|H[%w]+:[^|]-|h',search)
        if not first then break end
        local closeFirst, closeEnd = content:find('|h',headerEnd+1,true)
        if not closeFirst then break end
        if position >= first-1 and position <= closeEnd then
            local start = first
            if first > 10 and content:sub(first-10,first-1):match('^|c%x%x%x%x%x%x%x%x$') then
                start = first-10
            end
            local last = content:sub(closeEnd+1,closeEnd+2) == '|r' and closeEnd+2 or closeEnd
            local link = content:sub(first+2,headerEnd-2)
            local posted = self:PostNoteLink(link,content:sub(start,last),'LeftButton',true)
            if posted then return true end
        end
        search = closeEnd+1
    end
    self:Print(L.SELECT_LINK_TO_POST)
    return false
end

function CN:InitializeNoteLinkHook()
    if self.noteLinkHooked or not hooksecurefunc then return end
    local handler = function(text) CN:InsertNoteLink(text) end
    if ChatFrameUtil and type(ChatFrameUtil.InsertLink) == 'function' then
        hooksecurefunc(ChatFrameUtil,'InsertLink',handler)
    elseif type(ChatEdit_InsertLink) == 'function' then
        hooksecurefunc('ChatEdit_InsertLink',handler)
    else return end
    self.noteLinkHooked = true
end

function CN:NotePanel(parent, layer)
    local f = CreateFrame('Frame', nil, parent)
    f:SetPoint('TOPLEFT', parent, 'TOPLEFT', 1, -63)
    f:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', -1, 1)
    f:SetFrameLevel(parent:GetFrameLevel()+layer)
    f:EnableMouse(true)
    W.backdrop(f)
    f:Hide()
    return f
end

local function clean(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

local function sameBuild(a,b)
    if not a or not b then return a == b end
    if a.class ~= b.class then return false end
    for _, field in ipairs({'ranks','choices'}) do
        local left, right = a[field] or {}, b[field] or {}
        for key, value in pairs(left) do if right[key] ~= value then return false end end
        for key, value in pairs(right) do if left[key] ~= value then return false end end
    end
    return true
end

local function sameBuilds(a,b)
    if #a ~= #b then return false end
    for i, entry in ipairs(a) do
        if entry.name ~= b[i].name or not sameBuild(entry.build,b[i].build) then return false end
    end
    return true
end

-- Saved notes from v1.12 and earlier have one `build`. Keep reading that
-- field, but use named `builds` for all new edits and received guides.
function CN:CopyNoteBuilds(note)
    local result = {}
    if type(note) ~= 'table' then return result end
    local source = note.builds
    if type(source) ~= 'table' then
        source = note.build and {{name=L.DEFAULT_BUILD:format(1), build=note.build}} or {}
    end
    for i, entry in ipairs(source) do
        if i > self.MAX_BUILDS_PER_NOTE then return nil, L.BUILD_LIMIT:format(self.MAX_BUILDS_PER_NOTE) end
        local name = type(entry) == 'table' and type(entry.name) == 'string' and clean(entry.name) or ''
        local build = type(entry) == 'table' and entry.build
        if #name < 1 or #name > 60 or name:find('[\r\n\t]') or type(build) ~= 'table' or
                not P.spec[build.class] or type(build.ranks) ~= 'table' or
                (build.choices and type(build.choices) ~= 'table') then return nil, L.INVALID_BUILD end
        result[i] = {name=name, build=P.copy(build)}
    end
    return result
end

function CN:SaveGeneralNote(id, title, body, buildsOrBuild, activeBuild)
    title = clean(title)
    if title == '' then return nil, L.NEED_TITLE end
    local source = {builds=buildsOrBuild}
    if type(buildsOrBuild) == 'table' and buildsOrBuild.class then source = {build=buildsOrBuild} end
    local builds, err = self:CopyNoteBuilds(source)
    if not builds then return nil, err end
    local selected = #builds > 0 and math.min(math.max(tonumber(activeBuild) or 1,1),#builds) or nil
    if selected then selected = math.floor(selected) end
    local notes = self.db.generalNotes
    local old = id and notes[id]
    if not old then
        id = (self.db.nextNoteID or 0)+1
        while notes[id] do id = id+1 end
        self.db.nextNoteID = id
    end
    local now = time()
    notes[id] = {title=title, body=body or '', created=old and old.created or now,
        updated=now, builds=builds, activeBuild=selected,
        build=selected and P.copy(builds[selected].build) or nil}
    return id
end

function CN:FindGeneralNotes(search)
    local query = clean(search):lower()
    local rows = {}
    for id, note in pairs(self.db.generalNotes) do
        local matched = note.title:lower():find(query,1,true) or note.body:lower():find(query,1,true)
        if not matched then
            for _, entry in ipairs(note.builds or {}) do
                if type(entry.name) == 'string' and entry.name:lower():find(query,1,true) then
                    matched = true; break
                end
            end
        end
        if matched then
            rows[#rows+1] = {id=id, note=note}
        end
    end
    table.sort(rows,function(a,b)
        if a.note.updated == b.note.updated then return a.id > b.id end
        return a.note.updated > b.note.updated
    end)
    return rows
end

function CN:CloseNoteViews()
    if self.noteEdit then self.noteEdit:ClearFocus() end
    if self.nameEdit then self.nameEdit:ClearFocus() end
    if self.search then self.search:ClearFocus() end
    if self.notebook then self.notebook:Hide() end
    if self.planner then self.planner:Hide() end
end

local function action(parent, caption, width, x, y, fn)
    local b = W.button(parent, caption, width, 28, fn)
    b:SetPoint('TOPLEFT', x, y)
    return b
end
W.action = action

local function caption(parent, text, x, y, size)
    local line = W.label(parent,text,size or 12)
    line:SetPoint('TOPLEFT',x,y)
    return line
end
W.caption = caption

-- Scrollable lists reuse visible controls as the data changes.
function W.list(parent, x, y, width, height)
    local box = CreateFrame('Frame',nil,parent)
    box:SetSize(width,height)
    box:SetPoint('TOPLEFT',x,y)
    W.backdrop(box)
    local scroll = CreateFrame('ScrollFrame',nil,box)
    scroll:SetPoint('TOPLEFT',5,-5)
    scroll:SetPoint('BOTTOMRIGHT',-17,5)
    local child = CreateFrame('Frame',nil,scroll)
    child:SetSize(width-24,1)
    scroll:SetScrollChild(child)
    local refresh = W.scroll(box,scroll,child,32)
    local pool = {}
    local function display(rows, onSelect, selected)
        for i, item in ipairs(rows) do
            if not pool[i] then
                local b = W.button(child,'',width-24,29,function(self) onSelect(self.key) end)
                b:SetPoint('TOPLEFT',0,-(i-1)*32)
                local fs = b:GetFontString()
                fs:ClearAllPoints()
                fs:SetPoint('LEFT',8,0)
                fs:SetWidth(width-40)
                fs:SetJustifyH('LEFT')
                fs:SetWordWrap(false)
                pool[i] = b
            end
            local b = pool[i]
            b:SetText(item.label)
            b.key = item.key
            b:SetScript('OnClick',function(self) onSelect(self.key) end)
            b.cnAccent = selected == item.key
            W.backdrop(b,1,b.cnAccent)
            b:Show()
        end
        for i=#rows+1,#pool do pool[i]:Hide() end
        child:SetHeight(math.max(1,#rows*32))
        refresh()
    end
    return display,box
end

function CN:ShowNotebook()
    self:ShowWindow()
    if self.optionsPanel then self.optionsPanel:Hide() end
    if not self.notebook then
        local f = self:NotePanel(self.window,24)
        self.notebook = f
        caption(f,L.GENERAL_NOTES,19,-13,16)
        action(f,L.PLAYERS_HEADER,190,587,-8,function() self:ShowWindow() end)
        local search = W.edit(f,231,28)
        search:SetPoint('TOPLEFT',20,-69)
        caption(f,L.SEARCH_HINT,20,-48)
        local list, listBox = W.list(f,20,-107,231,330)
        local empty = caption(listBox,L.EMPTY_LIST,10,-15)
        local title = W.edit(f,508,28)
        title:SetMaxLetters(160)
        title:SetPoint('TOPLEFT',269,-69)
        caption(f,L.NOTE_TITLE,269,-48)
        caption(f,L.NOTE_HEADER,269,-112)
        local linkHint = caption(f,L.NOTE_LINK_HINT,345,-112,11)
        linkHint:SetWidth(270)
        linkHint:SetJustifyH('RIGHT')
        local box = CreateFrame('Frame',nil,f)
        box:SetPoint('TOPLEFT',269,-136)
        box:SetSize(508,256)
        W.backdrop(box)
        -- Use the client's complete scrollable editor when available. Its
        -- EditBox owns native click placement, selection, and arrow movement.
        local ok, template = pcall(CreateFrame,'ScrollFrame',nil,box,'InputScrollFrameTemplate')
        local candidate = ok and template and template.EditBox
        local valid, kind = false, nil
        if candidate and type(candidate) ~= 'function' and candidate.GetObjectType then
            valid, kind = pcall(candidate.GetObjectType,candidate)
        end
        local native = valid and kind == 'EditBox'
        if ok and template and not native then template:Hide() end
        local scroll, body, resize
        if native then
            scroll, body = template, template.EditBox
            scroll:SetPoint('TOPLEFT',6,-6)
            scroll:SetPoint('BOTTOMRIGHT',-22,6)
            if scroll.CharCount and type(scroll.CharCount) ~= 'function' then
                scroll.CharCount:Hide()
            end
            body:SetAutoFocus(false)
            body:EnableMouse(true)
            body:SetMultiLine(true)
            body:SetMaxLetters(0)
            if body.SetAltArrowKeyMode then body:SetAltArrowKeyMode(false) end
            if body.SetHistoryLines then body:SetHistoryLines(0) end
            body:SetFontObject(ChatFontNormal)
            body:SetTextColor(.94,.96,.99)
            body:SetTextInsets(4,4,6,6)
            body:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
            W.attachCaret(body,true)
            local function sizeEditor()
                local width = scroll:GetWidth()
                if width and width > 30 then body:SetWidth(width-8) end
            end
            scroll:HookScript('OnSizeChanged',sizeEditor)
            scroll:HookScript('OnShow',sizeEditor)
            sizeEditor()
            scroll:EnableMouse(true)
            scroll:HookScript('OnMouseDown',function(_,button)
                if button == 'LeftButton' then body:SetFocus() end
            end)
            if not body:GetScript('OnMouseWheel') then
                body:EnableMouseWheel(true)
                body:SetScript('OnMouseWheel',function(_,delta)
                    local wheel = scroll:GetScript('OnMouseWheel')
                    if wheel then wheel(scroll,delta) end
                end)
            end
        else
            scroll = CreateFrame('ScrollFrame',nil,box)
            scroll:SetPoint('TOPLEFT',6,-6)
            scroll:SetPoint('BOTTOMRIGHT',-18,6)
            body = W.edit(scroll,480,244,true)
            scroll:SetScrollChild(body)
            resize = W.scroll(box,scroll,body,35)
            scroll:EnableMouse(true)
            scroll:SetScript('OnMouseDown',function(_,button)
                if button == 'LeftButton' then body:SetFocus() end
            end)
            local cursorPosition
            body:HookScript('OnCursorChanged',function(_,x,y,w,h)
                if type(y) ~= 'number' or type(h) ~= 'number' then return end
                local position = body:GetCursorPosition()
                if position == cursorPosition then return end
                cursorPosition = position
                local offset = scroll:GetVerticalScroll() or 0
                local top, bottom = -y, -y + h
                if top < offset then scroll:SetVerticalScroll(math.max(0,top))
                elseif bottom > offset+scroll:GetHeight() then
                    scroll:SetVerticalScroll(bottom-scroll:GetHeight())
                end
            end)
        end
        f.nativeNoteEditor = native
        -- Hyperlinks remain editable. Posting a saved link uses the button.
        if body.SetHyperlinksEnabled then body:SetHyperlinksEnabled(false) end
        action(f,L.POST_LINK,155,620,-104,function() CN:PostNoteLinkAtCursor() end)
        local stamp = caption(f,'',269,-403,11)
        local attached = caption(f,'',269,-422,11)
        attached:SetWidth(340)
        function f:refreshBuildLabel()
            local entry = self.builds and self.builds[self.activeBuild]
            attached:SetText(entry and L.ATTACHED_BUILDS:format(#self.builds,entry.name:gsub('|','||'),
                (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.build.class] or entry.build.class))
                or L.NO_ATTACHED_BUILDS)
        end
        local function dirty()
            if f.loading then return end
            f.dirty = title:GetText() ~= f.savedTitle or body:GetText() ~= f.savedBody
                or f.activeBuild ~= f.savedActiveBuild or not sameBuilds(f.builds,f.savedBuilds)
            local note = self.db.generalNotes[f.id]
            stamp:SetText(f.dirty and L.UNSAVED or
                (note and L.NOTE_DATES:format(date('%x',note.created),date('%x %H:%M',note.updated)) or ''))
        end
        f.markDirty = dirty
        f.isDirty = function() dirty(); return f.dirty end
        function f:selectBuild(index)
            if not self.builds[index] then return false end
            if index == self.activeBuild then return true end
            if CN.planner and CN.planner.note == self then CN.planner:Hide() end
            self.activeBuild = index
            self.build = P.copy(self.builds[index].build)
            self.markDirty()
            self:refreshBuildLabel()
            return true
        end
        function f:addBuild(name, build)
            if #self.builds >= CN.MAX_BUILDS_PER_NOTE then
                return nil, L.BUILD_LIMIT:format(CN.MAX_BUILDS_PER_NOTE)
            end
            name = clean(name)
            if name == '' then
                local n = #self.builds+1
                name = L.DEFAULT_BUILD:format(n)
                local used = true
                while used do
                    used = false
                    for _, entry in ipairs(self.builds) do
                        if entry.name:lower() == name:lower() then n=n+1; name=L.DEFAULT_BUILD:format(n); used=true; break end
                    end
                end
            end
            if #name > 60 or name:find('[\r\n\t]') then return nil, L.BUILD_NAME_INVALID end
            for _, entry in ipairs(self.builds) do
                if entry.name:lower() == name:lower() then return nil, L.BUILD_NAME_DUPLICATE end
            end
            build = P.copy(build) or P.blank(self.build and self.build.class)
            self.builds[#self.builds+1] = {name=name, build=build}
            self.activeBuild = #self.builds
            self.build = P.copy(build)
            self.markDirty()
            self:refreshBuildLabel()
            return self.activeBuild
        end
        function f:setBuild(build)
            if not self.activeBuild then return self:addBuild(nil,build) end
            self.builds[self.activeBuild].build = P.copy(build)
            self.build = P.copy(build)
            self.markDirty()
            self:refreshBuildLabel()
            return self.activeBuild
        end
        function f:renameBuild(index,name)
            local entry = self.builds[index]
            name = clean(name)
            if not entry or name == '' or #name > 60 or name:find('[\r\n\t]') then
                return false, L.BUILD_NAME_INVALID
            end
            for i, other in ipairs(self.builds) do
                if i ~= index and other.name:lower() == name:lower() then return false, L.BUILD_NAME_DUPLICATE end
            end
            entry.name = name
            self.markDirty()
            self:refreshBuildLabel()
            return true
        end
        function f:removeBuild(index)
            if not self.builds[index] then return false end
            if CN.planner and CN.planner.note == self then CN.planner:Hide() end
            table.remove(self.builds,index)
            if #self.builds == 0 then self.activeBuild,self.build=nil,nil
            else
                self.activeBuild = math.min(self.activeBuild - (index < self.activeBuild and 1 or 0),#self.builds)
                self.build = P.copy(self.builds[self.activeBuild].build)
            end
            self.markDirty()
            self:refreshBuildLabel()
            return true
        end
        title:SetScript('OnTextChanged',dirty)
        body:HookScript('OnTextChanged',function()
            if not native then W.resizeEdit(body,scroll,resize,244) end
            dirty()
        end)
        local loadNote, refresh
        local confirm = CreateFrame('Frame',nil,f)
        confirm:SetAllPoints(f)
        confirm:SetFrameLevel(f:GetFrameLevel()+15)
        confirm:EnableMouse(true)
        W.backdrop(confirm)
        local message = caption(confirm,'',65,-170,15)
        action(confirm,OKAY or 'OK',140,70,-220,function()
            local fn = confirm.pending
            confirm:Hide()
            if fn then fn() end
        end)
        action(confirm,L.CANCEL,140,220,-220,function() confirm:Hide() end)
        confirm:Hide()
        local function ask(text, fn)
            title:ClearFocus()
            body:ClearFocus()
            message:SetText(text)
            confirm.pending = fn
            confirm:Show()
        end
        local function selectNote(id)
            if id and id == f.id then return end
            dirty()
            if f.dirty then ask(L.DISCARD_NOTE,function() loadNote(id) end)
            else loadNote(id) end
        end
        refresh = function()
            local rows = {}
            for _, item in ipairs(self:FindGeneralNotes(search:GetText())) do
                rows[#rows+1] = {key=item.id,label=item.note.title:gsub('|','||')}
            end
            list(rows,selectNote,f.id)
            empty:SetShown(#rows==0)
        end
        loadNote = function(id)
            if id ~= f.id and self.planner and self.planner.note == f then self.planner:Hide() end
            if id ~= f.id and self.noteBuildsWindow then self.noteBuildsWindow:Hide() end
            local note = self.db.generalNotes[id]
            f.id = id
            f.builds = self:CopyNoteBuilds(note) or {}
            f.activeBuild = note and note.activeBuild or (#f.builds > 0 and 1 or nil)
            if not f.builds[f.activeBuild] then f.activeBuild = #f.builds > 0 and 1 or nil end
            f.build = f.activeBuild and P.copy(f.builds[f.activeBuild].build) or nil
            f.loading = true
            title:SetText(note and note.title or '')
            body:SetText(note and note.body or '')
            f.savedTitle, f.savedBody = title:GetText(), body:GetText()
            f.savedBuilds = self:CopyNoteBuilds({builds=f.builds}) or {}
            f.savedActiveBuild = f.activeBuild
            body:SetCursorPosition(0)
            scroll:SetVerticalScroll(0)
            f.loading, f.dirty = false,false
            stamp:SetText(note and L.NOTE_DATES:format(date('%x',note.created),date('%x %H:%M',note.updated)) or '')
            f:refreshBuildLabel()
            refresh()
        end
        f.title, f.body, f.loadNote, f.refresh = title,body,loadNote,refresh
        search:SetScript('OnTextChanged',refresh)
        action(f,L.SHARE_GENERAL,110,335,-8,function()
            if not f.id or f.isDirty() then stamp:SetText(L.SAVE_BEFORE_SHARE); return end
            self:ShowGeneralShareDialog(f.id)
        end)
        action(f,L.GENERAL_INBOX,120,455,-8,function() self:ShowGeneralInbox() end)
        action(f,L.MANAGE_BUILDS,155,620,-409,function() self:ShowNoteBuilds() end)
        action(f,L.NEW,231,20,-449,function() selectNote(nil) end)
        action(f,L.SAVE,100,269,-449,function()
            local id, err = self:SaveGeneralNote(f.id,title:GetText(),body:GetText(),f.builds,f.activeBuild)
            if id then loadNote(id) else stamp:SetText(err) end
        end)
        action(f,L.REMOVE,100,377,-449,function()
            if f.id then ask(L.DELETE_NOTE,function()
                self.db.generalNotes[f.id] = nil
                loadNote(nil)
            end) end
        end)
        action(f,L.SHOW_PLANNER,292,485,-449,function() self:ShowTalentPlanner(true) end)
        f:SetScript('OnHide',function()
            search:ClearFocus(); title:ClearFocus(); body:ClearFocus(); confirm:Hide()
            if self.planner and self.planner.note == f then self.planner:Hide() end
            if self.noteBuildsWindow then self.noteBuildsWindow:Hide() end
        end)
        loadNote(nil)
    end
    self.notebook:Show()
    self.notebook.refresh()
    self:InitializeNoteLinkHook()
end

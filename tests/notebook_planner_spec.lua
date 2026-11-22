-- Focused mocks for the planner, note persistence, and visible edit cursor.
local function noop() end
local nativeTemplateAvailable=true
local function frame(kind, name, parent, template)
    if type(name)=='table' and parent==nil then parent=name end
    local f = {kind=kind, parent=parent, children={}, textures={}, scripts={}, shown=true, text='', focus=false}
    function f:SetScript(event, fn) self.scripts[event]=fn end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, fn)
        local old=self.scripts[event]
        self.scripts[event]=function(...) if old then old(...) end; fn(...) end
    end
    function f:CreateTexture()
        local texture=frame('Texture',self)
        self.textures[#self.textures+1]=texture
        return texture
    end
    function f:CreateFontString() return frame('FontString',self) end
    function f:CreateLine() return frame('Line',self) end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:IsShown() return self.shown end
    function f:HasFocus() return self.focus end
    function f:ClearFocus() self.focus=false end
    function f:SetFocus()
        self.focus=true
        if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
    end
    function f:Insert(value)
        local position=self:GetCursorPosition()
        self.text=self.text:sub(1,position)..value..self.text:sub(position+1)
        self:SetCursorPosition(position+#value)
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function f:SetHyperlinksEnabled(value) self.hyperlinks=value end
    function f:SetAltArrowKeyMode(value) self.altArrowMode=value end
    function f:SetHistoryLines(value) self.historyLines=value end
    function f:EnableMouse(value) self.mouseEnabled=value end
    function f:EnableMouseWheel(value) self.mouseWheelEnabled=value end
    function f:GetCursorPosition() return rawget(self,'position') or 0 end
    function f:SetCursorPosition(p)
        self.cursorSetCalls=(self.cursorSetCalls or 0)+1
        self.position=p
        if self.scripts.OnCursorChanged then self.scripts.OnCursorChanged(self,p*7,-10,1,16) end
    end
    function f:SetText(value) self.text=value end
    function f:GetText() return self.text end
    function f:SetHeight(h) self.height=h end
    function f:GetHeight() return rawget(self,'height') or 300 end
    function f:SetWidth(w) self.width=w end
    function f:GetWidth() return rawget(self,'width') or 480 end
    function f:GetFrameLevel() return 1 end
    function f:GetObjectType() return self.kind end
    function f:SetPoint(...) self.point={...} end
    function f:SetFontString(v) self.fontString=v end
    function f:GetFontString() return self.fontString end
    function f:GetVerticalScroll() return rawget(self,'verticalScroll') or 0 end
    function f:SetVerticalScroll(value) self.verticalScroll=value end
    function f:GetVerticalScrollRange()
        return math.max(0,(self.EditBox and self.EditBox:GetHeight() or 0)-self:GetHeight())
    end
    function f:SetMinMaxValues(low,high) self.min,self.max=low,high end
    function f:GetMinMaxValues() return rawget(self,'min') or 0,rawget(self,'max') or 0 end
    function f:GetValue() return rawget(self,'value') or 0 end
    function f:SetValue(value) self.value=value end
    function f:GetThumbTexture() return frame('Texture',self) end
    setmetatable(f,{__index=function(_,key)
        if type(key)=='string' and key:match('^[A-Z]') then return noop end
    end})
    if parent then parent.children[#parent.children+1]=f end
    if kind=='ScrollFrame' and template=='InputScrollFrameTemplate' and nativeTemplateAvailable then
        f.EditBox=frame('EditBox',nil,f)
        f.CharCount=frame('FontString',nil,f)
        f.EditBox:SetScript('OnTextChanged',function(self)
            self.nativeTextChanges=(self.nativeTextChanges or 0)+1
        end)
        f.EditBox:SetScript('OnCursorChanged',function(self)
            self.nativeCursorChanges=(self.nativeCursorChanges or 0)+1
        end)
        f:SetScript('OnMouseWheel',function(self,delta)
            local nextValue=self:GetVerticalScroll()-delta*35
            self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),nextValue)))
        end)
    end
    return f
end
CreateFrame=frame
UIParent=frame('Frame')
STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
ChatFontNormal={}
GetLocale=function() return 'enUS' end
GetNormalizedRealmName=function() return 'MoonGuard' end
UnitClass=function() return 'Warrior','WARRIOR' end
time=function() return 1000 end
date=function() return 'today' end
local shiftDown=false
IsShiftKeyDown=function() return shiftDown end
local controlDown=false
IsControlKeyDown=function() return controlDown end
local posted,opened
ChatFrameUtil={
    InsertLink=function() return false end,
    GetActiveWindow=function() return nil end,
    OpenChat=function(value) posted=value end,
}
SetItemRef=function(link,text) opened={link,text} end
hooksecurefunc=function(tbl,name,handler)
    local old=tbl[name]
    tbl[name]=function(...)
        local result=old(...)
        handler(...)
        return result
    end
end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=noop}
C_Spell={GetSpellInfo=function(id) return {name='Talent '..id,iconID=134400} end,
    GetSpellLink=function(id) return '|cff71d5ff|Hspell:'..id..'|h[Talent '..id..']|h|r' end}
LOCALIZED_CLASS_NAMES_MALE={WARRIOR='Warrior'}
GameTooltip=frame('Tooltip')
function GameTooltip:SetTraitEntry(_,rank) self.rank=rank end
function GameTooltip:AddLine() end
function GameTooltip:SetOwner() end

local cn={}
local function load(name)
    assert(loadfile('CharNotes/'..name..'.lua'))('ElvUI_CharNotes',cn)
end
load('Strings'); load('Core'); load('Tags'); load('TalentModel'); load('UI'); load('Notebook'); load('GeneralShare'); load('NoteBuilds'); load('Planner'); load('Sync')
ElvUICharNotesDB={}
cn.db=cn:EnsureDB()

local edit=cn.widgets.edit(frame('Frame'),480,244,true)
local caret=edit.textures[1]
assert(caret and not caret:IsShown(), 'caret starts hidden')
assert(edit.mouseEnabled==true,'clicks must reach the editable text, not only its scroll frame')
assert(edit.altArrowMode==false and edit.historyLines==0,
    'multi-line notes use plain arrow keys, without history navigation')
edit.position=15
edit.focus=true
edit.scripts.OnEditFocusGained(edit)
assert(caret:IsShown(), 'caret is visible when writing')
assert(edit.position==15 and not edit.cursorSetCalls,
    'focus does not reset the position selected by a mouse click')
edit.scripts.OnCursorChanged(edit,20,-30,1,16)
assert(caret.point and caret.point[4]==24 and caret.point[5]==-36,
    'caret tracks actual insertion position')
edit.focus=false
edit.scripts.OnEditFocusLost(edit)
assert(not caret:IsShown(), 'caret hides when leaving the edit box')

local node={id=101,tree=1,max=3,cost=0,required={},any={},col=0,row=0,
    entries={{id=111,spell=222,cost=0}}}
local model={class='WARRIOR',cap=4,nodes={[101]=node},trees={
    {index=1,name='Arms',cols=4,rows=7,nodes={node}},
    {index=2,name='Fury',cols=4,rows=7,nodes={}},
    {index=3,name='Protection',cols=4,rows=7,nodes={}},
}}
cn.talents.model=function() return model end
cn.window=frame('Frame',UIParent)
local note={shown=true,build=nil,builds={},dirty=false}
function note:IsShown() return self.shown end
function note.markDirty() note.dirty=true end
function note:setBuild(build)
    self.build=cn.talents.copy(build)
    self.builds[1]={name='Build 1',build=cn.talents.copy(build)}
    self.activeBuild=1
    self.markDirty()
    self:refreshBuildLabel()
end
function note:refreshBuildLabel()
    assert(self==note, 'build label must receive its notebook instance')
    self.labelRefreshes=(self.labelRefreshes or 0)+1
end
cn.notebook=note
function cn:ShowWindow() error('opening the planner hid the note') end
cn:ShowTalentPlanner(true)
assert(cn.planner.parent==UIParent and cn.planner.note==note and note:IsShown(),
    'note and planner must be separate visible windows')
local button=assert(cn.planner.panes[1].buttons[1])
button.scripts.OnClick(button,'LeftButton')
assert(note.dirty and note.build.ranks[101]==1 and GameTooltip.rank==1,
    'first rank attaches to note and shows first-rank text')
button.scripts.OnClick(button,'LeftButton')
assert(note.build.ranks[101]==2 and GameTooltip.rank==2,
    'second rank attaches to note and shows second-rank text')
button.scripts.OnClick(button,'RightButton')
assert(note.build.ranks[101]==1 and GameTooltip.rank==1 and note.labelRefreshes==3,
    'right-click refunds a rank and updates the linked note label')
local id=assert(cn:SaveGeneralNote(nil,'My build','Remarks',note.build))
note.build=cn.db.generalNotes[id].build
assert(cn.planner.close and cn.planner.close.text=='X','planner close button missing')
cn.planner.close.scripts.OnClick()
assert(not cn.planner:IsShown() and note:IsShown(),
    'close button must hide the planner and keep the note visible')
cn:ShowTalentPlanner(true)
assert(cn.planner.build.ranks[101]==1,'saved build reopens from note')
-- Opening a blank general note and selecting an existing one must not ask to
-- discard unchanged content; actual edits still require confirmation.
cn.notebook=nil
function cn:ShowWindow() self.window:Show() end
cn:ShowNotebook()
local notebook=cn.notebook
assert(notebook and not notebook.isDirty(),'new empty note starts clean')
assert(notebook.nativeNoteEditor and notebook.body.parent.EditBox==notebook.body,
    'general notes use the client scrollable EditBox when available')
assert(not notebook.body.scripts.OnMouseDown and not notebook.body.scripts.OnMouseUp
    and not notebook.body.scripts.OnArrowPressed,
    'selection and arrow movement remain under native EditBox control')
notebook.title.scripts.OnTextChanged(notebook.title)
assert(not notebook.isDirty(),'spurious text-change events must not mark it dirty')
local function findButton(root,key)
    if root.kind=='Button' and root.key==key then return root end
    for _,child in ipairs(root.children) do
        local result=findButton(child,key)
        if result then return result end
    end
end
local savedButton=assert(findButton(notebook,id),'saved note is listed')
savedButton.scripts.OnClick(savedButton)
assert(notebook.id==id and not notebook.isDirty(),'selecting existing note from blank opens directly')
notebook.loadNote(nil)
notebook.title:SetText('Draft')
savedButton.scripts.OnClick(savedButton)
assert(notebook.id==nil and notebook.isDirty(),'changed draft requires a discard decision')
cn:ShowGeneralShareDialog(id)
local share=cn.generalShareWindow
local function findTextButton(root,value)
    if root.kind=='Button' and root.text==value then return root end
    for _,child in ipairs(root.children) do
        local result=findTextButton(child,value)
        if result then return result end
    end
end
local shareButton=assert(findTextButton(share,cn.L.SHARE))
shareButton.scripts.OnClick()
assert(share.status.text==cn.L.SAVE_BEFORE_SHARE,'unsaved edits cannot be shared')
notebook.loadNote(id)
share.chooseChannel('GUILD')
local sent
function cn:ShareGeneralNote(noteID,channel) sent={noteID,channel}; return true,2 end
shareButton.scripts.OnClick()
assert(sent[1]==id and sent[2]=='GUILD' and share.status.text==cn.L.GENERAL_QUEUED:format(2),
    'share dialog must send selected saved note')
cn.db.generalInbox[1]={sender='Alice-MoonGuard',channel='GUILD',
    note={title='A received note',body='Full text\nwith details',build=nil}}
cn:ShowGeneralInbox()
local inbox=cn.generalInboxWindow
local proposal=assert(findButton(inbox,1))
proposal.scripts.OnClick(proposal)
assert(inbox.preview.text:find('Full text\nwith details',1,true),'inbox must preview full body')
local accept=assert(findTextButton(inbox,cn.L.ACCEPT_NOTE))
accept.scripts.OnClick()
assert(#cn.db.generalInbox==0 and cn.db.generalNotes[id].title=='My build',
    'accepting inbox note must preserve the existing saved note')
-- Legacy single builds load as the first named build. Manage several builds,
-- edit only the selected one, and persist the selection with the note.
notebook.loadNote(id)
assert(#notebook.builds==1 and notebook.builds[1].build.ranks[101]==1)
cn:ShowNoteBuilds()
local manager=cn.noteBuildsWindow
assert(manager:IsShown(),'build manager opens alongside the note')
local create=assert(findTextButton(manager,cn.L.NEW_BUILD))
create.scripts.OnClick()
assert(#notebook.builds==2 and notebook.activeBuild==2 and notebook.isDirty(),
    'adding a second build modifies the note')
local editBuild=assert(findTextButton(manager,cn.L.EDIT_BUILD))
editBuild.scripts.OnClick()
assert(cn.planner.note==notebook and cn.planner:IsShown(),
    'selected build opens in the separate planner')
local secondButton=assert(cn.planner.panes[1].buttons[1])
secondButton.scripts.OnClick(secondButton,'LeftButton')
secondButton.scripts.OnClick(secondButton,'LeftButton')
assert(notebook.builds[1].build.ranks[101]==1 and notebook.builds[2].build.ranks[101]==2,
    'planner changes affect only the selected build')
controlDown=true
secondButton.scripts.OnClick(secondButton,'LeftButton')
controlDown=false
assert(notebook.builds[2].build.ranks[101]==2 and
    notebook.body.text:find('|Hspell:222|h',1,true),
    'control-click inserts a talent link without assigning a point')
cn.planner:Hide()
cn:ShowNoteBuilds()
local function findEdit(root)
    if root.kind=='EditBox' then return root end
    for _,child in ipairs(root.children) do
        local result=findEdit(child)
        if result then return result end
    end
end
local name=assert(findEdit(manager))
name:SetText('Tank build')
assert(findTextButton(manager,cn.L.RENAME_BUILD)).scripts.OnClick()
assert(notebook.builds[2].name=='Tank build','build name changes persist in draft')
assert(findTextButton(manager,cn.L.DUPLICATE)).scripts.OnClick()
assert(#notebook.builds==3 and notebook.activeBuild==3)
local remove=assert(findTextButton(manager,cn.L.REMOVE))
remove.scripts.OnClick(); assert(#notebook.builds==3,'first remove click only asks for confirmation')
remove.scripts.OnClick(); assert(#notebook.builds==2,'second remove click removes one build')
local save=assert(findTextButton(notebook,cn.L.SAVE))
save.scripts.OnClick()
assert(#cn.db.generalNotes[id].builds==2 and cn.db.generalNotes[id].builds[2].name=='Tank build'
    and cn.db.generalNotes[id].builds[2].build.ranks[101]==2,
    'save retains multiple named builds and their separate talent allocations')
notebook.loadNote(id)
assert(#notebook.builds==2 and notebook.activeBuild==2 and not notebook.isDirty())
notebook:selectBuild(1)
assert(notebook.isDirty() and notebook.build.ranks[101]==1)
notebook.loadNote(id)
assert(notebook.activeBuild==2 and notebook.build.ranks[101]==2,
    'reloading restores the saved active build')
local itemLink='|cff0070dd|Hitem:12345|h[Blue Sword]|h|r'
notebook.body.focus=true
ChatFrameUtil.InsertLink(itemLink)
assert(notebook.body.mouseEnabled and notebook.body.hyperlinks==false
    and notebook.body.text:find(itemLink,1,true) and notebook.isDirty(),
    'a shift-clicked item link is inserted at the note cursor')
assert(notebook.body.nativeTextChanges and notebook.body.nativeTextChanges>0,
    'native text change handler remains installed when the note becomes dirty')
notebook.body.focus=false
assert(not cn:InsertNoteLink(itemLink),'unfocused notes must not capture links')
local linkStart=assert(notebook.body.text:find('|Hitem:12345',1,true))
notebook.body:SetCursorPosition(linkStart+4)
assert(notebook.body.nativeCursorChanges and notebook.body.nativeCursorChanges>0,
    'native cursor handler remains installed')
assert(findTextButton(notebook,cn.L.POST_LINK)).scripts.OnClick()
assert(posted==itemLink,'link button opens chat with the link at the caret')
notebook.body:SetCursorPosition(#notebook.body.text)
assert(not cn:PostNoteLinkAtCursor(),'button requires caret within a link')
local spellLink='|cff71d5ff|Hspell:67890|h[Spell]|h|r'
notebook.body.focus=true
ChatFrameUtil.InsertLink(spellLink)
assert(notebook.body.text:find(spellLink,1,true),'spell links are also accepted')
local scroll=notebook.body.parent
scroll.height=200
notebook.body:SetHeight(900)
assert(notebook.body.mouseWheelEnabled and notebook.body.scripts.OnMouseWheel,
    'wheel over the EditBox must reach the ScrollFrame')
scroll:SetVerticalScroll(200)
notebook.body.scripts.OnMouseWheel(notebook.body,1)
assert(scroll:GetVerticalScroll()==165,'wheel scrolls over the editable text')
notebook.body.scripts.OnCursorChanged(notebook.body,20,-400,1,16)
assert(scroll:GetVerticalScroll()==165,
    'native cursor callback does not jump after scrolling')
nativeTemplateAvailable=false
cn.notebook=nil
cn:ShowNotebook()
local fallback=cn.notebook
assert(not fallback.nativeNoteEditor and not fallback.body.scripts.OnMouseUp
    and not fallback.body.scripts.OnArrowPressed,
    'missing template uses a plain editor without synthetic cursor moves')
fallback.body.focus=false
fallback.body.parent.scripts.OnMouseDown(fallback.body.parent,'LeftButton')
assert(fallback.body:HasFocus(),'clicking empty scroll space focuses the fallback editor')
local manifest=assert(io.open('CharNotes/ElvUI_CharNotes.toc','r')):read('*a')
assert(cn.VERSION==manifest:match('## Version: ([^\r\n]+)'),
    'runtime and release version must agree')
print('notebook_planner_spec.lua: ok')

-- Mock regression checks for the isolated support copy dialog.
-- These do not verify actual clipboard support in a WoW Forever client.
local function noop() end
local frames = {}
local function frame(kind, name, parent)
    local f = {kind=kind, name=name, parent=parent, children={}, scripts={}, shown=true, text='', focus=false}
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
    end
    function f:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:SetText(value)
        self.text = value
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function f:GetText() return self.text end
    function f:SetFocus() self.focus = true end
    function f:ClearFocus() self.focus = false end
    function f:HasFocus() return self.focus end
    function f:HighlightText(first, last) self.highlight = {first,last}; self.highlightCalls = (self.highlightCalls or 0) + 1 end
    function f:CreateFontString() return frame('FontString', nil, self) end
    function f:CreateTexture() return frame('Texture', nil, self) end
    function f:SetWidth(value) self.width = value end
    function f:SetHeight(value) self.height = value end
    function f:GetWidth() return self.width or 1024 end
    function f:GetHeight() return self.height or 768 end
    function f:SetSize(width, height) self.width, self.height = width,height end
    function f:Raise() end
    setmetatable(f, {__index=function(_, key)
        if type(key)=='string' and key:match('^[A-Z]') then return noop end
    end})
    if parent then parent.children[#parent.children+1] = f end
    frames[#frames+1] = f
    return f
end
CreateFrame = frame
UIParent = frame('Frame', 'UIParent')
ChatFontNormal = {}
GetLocale = function() return 'enUS' end
local CN = {VERSION='1.13.11', db={supportId='1234-5678', diagnosticErrors={}}}
CN.IsSecret = function() return false end
CN.GetDiagnosticErrorReport = function() return nil end
CN.GetDiagnosticLog = function() return {} end
CN.FormatDiagnosticContext = function() return '' end
CN.LogEvent = function() end
assert(loadfile('CharNotes/Strings.lua'))('ElvUI_CharNotes', CN)
assert(loadfile('CharNotes/SupportUI.lua'))('ElvUI_CharNotes', CN)

local function button(label)
    for _, f in ipairs(frames) do
        if f.kind=='Button' and f.text == label then return f end
    end
    error('Missing button: '..label)
end
local function click(label)
    local b=button(label)
    assert(b.scripts.OnClick, 'No handler for '..label)
    b.scripts.OnClick(b)
end

CN:ShowSupport()
local window = assert(CN.supportWindow)
local foundTitle, panels, labels = false, 0, {}
for _, child in ipairs(window.children) do
    if child.kind == 'FontString' then
        labels[child.text] = true
        if child.text == 'CharNotes - ' .. CN.L.SUPPORT .. ' - v1.13.11' then foundTitle = true end
    end
    if child.kind == 'Texture' and child.width == 756 then panels = panels + 1 end
end
assert(foundTitle, 'support window has version without PUNK branding')
assert(panels == 3, 'all three support groups use background textures, not overlay frames')
for _, label in ipairs({CN.L.SUPPORT_TITLE, CN.L.SUPPORT_DESCRIPTION, CN.L.SUPPORT_REPORT, CN.L.SUPPORT_LINK}) do
    assert(labels[label], 'visible support field label is missing: ' .. label)
end
local function descendantsOfType(f, kind)
    local total = f.kind == kind and 1 or 0
    for _, child in ipairs(f.children) do total = total + descendantsOfType(child, kind) end
    return total
end
assert(descendantsOfType(window, 'ScrollFrame') == 2, 'only multiline fields get scrollbars')
click(CN.L.SUPPORT_SELECT_LINK)
local popup = assert(CN.supportCopyWindow)
assert(popup:IsShown(), 'copy popup is visible')
assert(popup.activeCopyEdit == popup.linkEdit, 'link uses the isolated copy field')
local link = popup.linkEdit:GetText()
assert(link:find('https://github.com/JimmerNv/Character-Notes/issues/new?',1,true), 'correct GitHub URL')
assert(link:find('support-id=1234-5678',1,true), 'support ID is in URL')
assert(popup.linkEdit:HasFocus(), 'focus is granted on opening')
assert(popup.linkEdit.highlight[2] == #link, 'complete URL selected')

-- A different UI handler steals focus or clears selection after the click.
-- Copy mode should restore focus and selection while the dialog is shown.
popup.linkEdit.focus = false
popup.linkEdit.highlight = nil
popup.copyKeeper.scripts.OnUpdate(popup.copyKeeper, 0.016)
assert(popup.linkEdit:HasFocus(), 'focus recovered after external focus loss')
assert(popup.linkEdit.highlight[2] == #link, 'selection recovered')

popup.linkEdit.scripts.OnEscapePressed(popup.linkEdit)
assert(not popup:IsShown(), 'escape closes copy dialog')
assert(not popup.copyKeeper:IsShown(), 'focus keeper stops when dialog closes')
assert(not popup.linkEdit:HasFocus(), 'copy field releases focus')

click(CN.L.SUPPORT_SELECT_REPORT)
assert(popup.activeCopyEdit==popup.reportEdit, 'report uses multiline copy field')
assert(popup.reportEdit:GetText():find('Support ID: 1234-5678', 1, true), 'report includes anonymous ID')
assert(popup.reportEdit.highlight[2]==#popup.reportEdit:GetText(), 'complete report selected')
popup:Hide()
click(CN.L.SUPPORT_SELECT_ALL)
local all = popup.reportEdit:GetText()
assert(all:find('github.com/JimmerNv/Character-Notes/issues/new',1,true))
assert(all:find('Addon: Character Notes',1,true))
assert(popup.reportEdit.highlight[2] == #all)
popup:Hide()
CN.supportWindow:Hide()
print('PASS: isolated copy dialog, persistent selection, focus recovery, Esc, report & all')

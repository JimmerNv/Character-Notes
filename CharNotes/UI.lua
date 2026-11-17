local _, CN = ...
local L = CN.L

local ORANGE = '|cffff9855'
local WHITE = 'Interface\\Buttons\\WHITE8X8'
local EDGES = {
    {'TOPLEFT', 'TOPRIGHT'}, {'BOTTOMLEFT', 'BOTTOMRIGHT'},
    {'TOPLEFT', 'BOTTOMLEFT'}, {'TOPRIGHT', 'BOTTOMRIGHT'},
}

-- Use the dark BagCleaner palette on plain frames. Textures work even when
-- SetBackdrop and ElvUI frame templates are unavailable.
local function backdrop(frame, alpha, accent, hovered)
    if not frame.cnBackground then
        local bg = frame:CreateTexture(nil, 'BACKGROUND')
        bg:SetTexture(WHITE)
        bg:SetAllPoints(frame)
        frame.cnBackground = bg
        frame.cnEdges = {}
        for i, points in ipairs(EDGES) do
            local edge = frame:CreateTexture(nil, 'BORDER')
            edge:SetTexture(WHITE)
            edge:SetPoint(points[1], frame, points[1])
            edge:SetPoint(points[2], frame, points[2])
            if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
            frame.cnEdges[i] = edge
        end
    end
    if hovered then
        frame.cnBackground:SetVertexColor(.19, .21, .26, 1)
    else
        frame.cnBackground:SetVertexColor(.065, .075, .095, alpha or 1)
    end
    for _, edge in ipairs(frame.cnEdges) do
        if hovered then edge:SetVertexColor(1, .73, .34, 1)
        elseif accent then edge:SetVertexColor(.93, .59, .25, 1)
        else edge:SetVertexColor(.25, .32, .41, 1) end
    end
end

local function label(parent, text, size, color)
    local f = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    f:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', size or 12, '')
    f:SetTextColor(color == 'muted' and .61 or .97, color == 'muted' and .65 or .82, color == 'muted' and .72 or .45)
    f:SetText(text or '')
    return f
end

local function button(parent, text, w, h, action, emphasize)
    local b = CreateFrame('Button', nil, parent)
    b:SetSize(w, h or 27)
    local fs = b:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    fs:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 12, '')
    fs:SetTextColor(1, .83, .39)
    fs:SetPoint('CENTER')
    b:SetFontString(fs)
    b:SetText(text)
    b.cnAccent = emphasize
    backdrop(b, emphasize and .96 or .88, emphasize)
    b:SetScript('OnEnter', function(self) backdrop(self, nil, nil, true) end)
    b:SetScript('OnLeave', function(self) backdrop(self, self.cnAccent and .96 or .88, self.cnAccent) end)
    if action then b:SetScript('OnClick', action) end
    return b
end

local function edit(parent, w, h, multi)
    local e = CreateFrame('EditBox', nil, parent)
    e:SetSize(w, h or 27)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetTextColor(.94, .96, .99)
    e:SetTextInsets(multi and 4 or 9, multi and 4 or 9, multi and 6 or 5, multi and 6 or 5)
    if multi then
        e:SetMultiLine(true)
        e:SetMaxLetters(0)
        e:SetJustifyH('LEFT')
        e:SetJustifyV('TOP')
        e:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    else
        backdrop(e, .82)
        e:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
        e:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    end
    return e
end

local function check(parent, onClick)
    local b = CreateFrame('CheckButton', nil, parent)
    b:SetSize(19, 19)
    backdrop(b, .93)
    local tex = b:CreateTexture(nil, 'ARTWORK')
    tex:SetTexture(WHITE)
    tex:SetVertexColor(1, .66, .26)
    tex:SetPoint('TOPLEFT', 4, -4)
    tex:SetPoint('BOTTOMRIGHT', -4, 4)
    b:SetCheckedTexture(tex)
    if onClick then b:SetScript('OnClick', onClick) end
    return b
end

local function addScrollControl(box, scroll, child, increment)
    local rail = CreateFrame('Slider', nil, box)
    rail:SetWidth(7)
    rail:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -5, -8)
    rail:SetPoint('BOTTOMRIGHT', box, 'BOTTOMRIGHT', -5, 8)
    rail:SetOrientation('VERTICAL')
    rail:SetMinMaxValues(0, 0)
    rail:SetValueStep(1)
    local track = rail:CreateTexture(nil, 'BACKGROUND')
    track:SetTexture(WHITE)
    track:SetVertexColor(.20, .23, .29, .9)
    track:SetAllPoints()
    rail:SetThumbTexture(WHITE)
    local thumb = rail:GetThumbTexture()
    if thumb then thumb:SetSize(7, 33); thumb:SetVertexColor(.65, .70, .77, 1) end
    local refreshing = false
    local function refresh()
        if refreshing then return end
        refreshing = true
        local max = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
        rail:SetMinMaxValues(0, max)
        if max < 1 then
            scroll:SetVerticalScroll(0)
            rail:Hide()
        else
            rail:Show()
            local val = math.min(math.max(0, scroll:GetVerticalScroll() or 0), max)
            scroll:SetVerticalScroll(val)
            rail:SetValue(val)
        end
        refreshing = false
    end
    rail:SetScript('OnValueChanged', function(_, value)
        if not refreshing and math.abs((scroll:GetVerticalScroll() or 0) - value) > .5 then
            scroll:SetVerticalScroll(value)
        end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(_, delta)
        local _, max = rail:GetMinMaxValues()
        local current = scroll:GetVerticalScroll() or 0
        local newValue = math.min(max or 0, math.max(0, current - delta * (increment or 35)))
        scroll:SetVerticalScroll(newValue)
        rail:SetValue(newValue)
    end)
    scroll:SetScript('OnVerticalScroll', function(_, value)
        if not refreshing and math.abs(rail:GetValue() - value) > .5 then
            rail:SetValue(value)
        end
    end)
    scroll:SetScript('OnSizeChanged', function() refresh() end)
    return refresh
end

local function resizeEditToContent(e, scroll, refresh, minimum)
    local value = e:GetText() or ''
    local calc = 0
    if e.GetStringHeight then
        local ok, v = pcall(e.GetStringHeight, e)
        if ok and type(v) == 'number' then calc = v end
    end
    -- GetStringHeight may be unavailable on some Forever forks.
    local _, newlines = value:gsub('\n', '\n')
    local approxLines = newlines + math.ceil(#value / 48)
    local height = math.max(minimum or 220, calc + 22, (approxLines + 2) * 15)
    if math.abs((e:GetHeight() or 0) - height) > 1 then e:SetHeight(height) end
    if refresh then refresh() end
end

local function separator(parent, x, y, width)
    local line = parent:CreateTexture(nil, 'ARTWORK')
    line:SetTexture(WHITE)
    line:SetVertexColor(.32, .36, .43, .75)
    line:SetSize(width, 1)
    line:SetPoint('TOPLEFT', x, y)
    return line
end

function CN:InitializeUI()
    if self.window then return end
    local w = CreateFrame('Frame', 'ElvUICharNotesWindow', UIParent)
    w:SetSize(800, 590)
    w:SetPoint('CENTER')
    w:SetFrameStrata('DIALOG')
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag('LeftButton')
    w:SetScript('OnDragStart', w.StartMoving)
    w:SetScript('OnDragStop', w.StopMovingOrSizing)
    backdrop(w)
    w:Hide()
    self.window = w

    local title = label(w, 'CharNotes  ' .. ORANGE .. '[PUNK]|r', 16)
    title:SetPoint('TOPLEFT', 20, -16)
    local subtitle = label(w, L.SUBTITLE, 11, 'muted')
    subtitle:SetPoint('TOPLEFT', 21, -40)
    local close = button(w, 'X', 26, 26, function() w:Hide() end)
    close:SetPoint('TOPRIGHT', -13, -12)
    local options = button(w, L.OPTIONS, 89, 26, function() CN:ShowOptions() end)
    options:SetPoint('RIGHT', close, 'LEFT', -9, 0)
    separator(w, 19, -62, 762)

    local listHeading = label(w, L.PLAYERS_HEADER, 12)
    listHeading:SetPoint('TOPLEFT', 21, -79)
    local listCount = label(w, '', 11, 'muted')
    listCount:SetPoint('TOPRIGHT', -522, -80)
    listCount:SetJustifyH('RIGHT')
    self.listCount = listCount
    local search = edit(w, 259, 28, false)
    search:SetPoint('TOPLEFT', 20, -103)
    self.search = search
    local hint = label(search, L.SEARCH_HINT, 11, 'muted')
    hint:SetPoint('LEFT', 10, 0)
    search:SetScript('OnTextChanged', function(e)
        hint:SetShown(e:GetText() == '')
        CN:RefreshList()
    end)
    search:SetScript('OnEditFocusGained', function() hint:Hide() end)
    search:SetScript('OnEditFocusLost', function(e) hint:SetShown(e:GetText() == '') end)
    self.searchHint = hint

    local listPane = CreateFrame('Frame', nil, w)
    listPane:SetPoint('TOPLEFT', 20, -144)
    listPane:SetSize(259, 312)
    backdrop(listPane, .57)
    self.listPane = listPane
    local listScroll = CreateFrame('ScrollFrame', nil, listPane)
    listScroll:SetPoint('TOPLEFT', 7, -7)
    listScroll:SetPoint('BOTTOMRIGHT', -18, 7)
    local listContent = CreateFrame('Frame', nil, listScroll)
    listContent:SetSize(229, 1)
    listScroll:SetScrollChild(listContent)
    self.listContent = listContent
    self.listScroll = listScroll
    self.listButtons = {}
    self.refreshListScroll = addScrollControl(listPane, listScroll, listContent, 35)
    local empty = label(listPane, L.EMPTY_LIST, 11, 'muted')
    empty:SetPoint('TOPLEFT', 14, -18)
    empty:SetWidth(213)
    self.emptyListLabel = empty

    local nameTitle = label(w, L.CHARACTER_HEADER, 12)
    nameTitle:SetPoint('TOPLEFT', 298, -79)
    local nameEdit = edit(w, 482, 28, false)
    nameEdit:SetPoint('TOPLEFT', 298, -103)
    nameEdit:SetMaxLetters(128)
    self.nameEdit = nameEdit

    local punk = check(w)
    punk:SetPoint('TOPLEFT', 299, -148)
    punk:SetChecked(true)
    self.punkCheck = punk
    local punkLabel = label(w, L.PUNK_HINT, 12)
    punkLabel:SetPoint('LEFT', punk, 'RIGHT', 9, 0)
    local targetButton = button(w, L.USE_TARGET, 112, 27, function()
        local _, name = CN:FromUnit('target')
        if name then
            CN:OpenEditor(name)
        else
            CN:Print(L.TARGET_UNREADABLE)
        end
    end)
    targetButton:SetPoint('TOPLEFT', 668, -143)

    local noteTitle = label(w, L.NOTE_HEADER, 12)
    noteTitle:SetPoint('TOPLEFT', 298, -179)
    local count = label(w, L.NOTE_SIZE:format(0), 11, 'muted')
    count:SetPoint('TOPRIGHT', -21, -180)
    self.noteCounter = count
    local noteBox = CreateFrame('Frame', nil, w)
    noteBox:SetPoint('TOPLEFT', 298, -201)
    noteBox:SetSize(482, 215)
    backdrop(noteBox, .65)
    local noteScroll = CreateFrame('ScrollFrame', nil, noteBox)
    noteScroll:SetPoint('TOPLEFT', 9, -9)
    noteScroll:SetPoint('BOTTOMRIGHT', -18, 9)
    local note = edit(noteScroll, 449, 197, true)
    noteScroll:SetScrollChild(note)
    self.noteEdit = note
    self.noteScroll = noteScroll
    self.refreshNoteScroll = addScrollControl(noteBox, noteScroll, note, 38)
    note:SetScript('OnTextChanged', function(self)
        resizeEditToContent(self, noteScroll, CN.refreshNoteScroll, 196)
        local len = #(self:GetText() or '')
        count:SetText(L.NOTE_SIZE:format(len))
        if len > 1200 then count:SetTextColor(1, .37, .38) else count:SetTextColor(.65, .69, .76) end
    end)
    note:SetScript('OnCursorChanged', function(_, x, y, width, height)
        if type(y) ~= 'number' or type(height) ~= 'number' then return end
        local offset = noteScroll:GetVerticalScroll() or 0
        local top, bottom = -y, -y + height
        local target = offset
        if top < offset then target = math.max(0, top - 7)
        elseif bottom > offset + noteScroll:GetHeight() then
            target = bottom - noteScroll:GetHeight() + 8
        end
        if math.abs(target - offset) > 1 then noteScroll:SetVerticalScroll(target) end
    end)

    local tags = button(w, L.EDIT_TAGS, 105, 31, function() CN:ShowTagManager() end)
    tags:SetPoint('TOPLEFT', 298, -429)
    local tagSummary = CreateFrame('Frame', nil, w)
    tagSummary:SetPoint('LEFT', tags, 'RIGHT', 9, 0)
    tagSummary:SetSize(368, 31)
    self.tagSummary = tagSummary
    self.tagSummaryIcons = {}
    self.editorTags = {}

    local save = button(w, L.SAVE, 107, 31, function() CN:SaveEditor() end, true)
    save:SetPoint('TOPLEFT', 298, -483)
    local del = button(w, L.REMOVE, 103, 31, function() CN:DeleteEditor() end)
    del:SetPoint('LEFT', save, 'RIGHT', 8, 0)
    local new = button(w, L.NEW, 69, 31, function() CN:OpenEditor('') end)
    new:SetPoint('LEFT', del, 'RIGHT', 8, 0)
    local share = button(w, L.SHARE_WITH_GUILD, 155, 31, function()
        CN:AskShareGuild(CN.nameEdit:GetText())
    end)
    share:SetPoint('LEFT', new, 'RIGHT', 8, 0)

    separator(w, 19, -529, 762)
    local exp = button(w, L.EXPORT, 105, 29, function() CN:ShowTransfer(false) end)
    exp:SetPoint('TOPLEFT', 20, -544)
    local imp = button(w, L.IMPORT, 105, 29, function() CN:ShowTransfer(true) end)
    imp:SetPoint('LEFT', exp, 'RIGHT', 7, 0)
    local inbox = button(w, L.GUILD_INBOX, 138, 29, function() CN:ShowGuildInbox() end)
    inbox:SetPoint('LEFT', imp, 'RIGHT', 7, 0)
    local soundText = label(w, L.ALERT_SOUND, 11)
    soundText:SetPoint('TOPLEFT', 405, -553)
    local sound = button(w, '', 157, 29, function() CN:CycleSound() end)
    sound:SetPoint('TOPLEFT', 467, -544)
    self.soundCycleButton = sound
    local test = button(w, L.TEST, 58, 29, function() CN:PlayAlertSound(true) end)
    test:SetPoint('LEFT', sound, 'RIGHT', 7, 0)
    local enabled = check(w, function(b)
        CN:SetOption('sound', not not b:GetChecked())
    end)
    enabled:SetPoint('LEFT', test, 'RIGHT', 10, 0)
    self.soundEnableCheck = enabled
    local enabledText = label(w, L.ON, 11, 'muted')
    enabledText:SetPoint('LEFT', enabled, 'RIGHT', 5, 0)
    local footer = label(w, L.FOOTER, 10, 'muted')
    footer:SetPoint('BOTTOMLEFT', 21, 5)
    self:UpdateSoundUI()
    self:RefreshList()

    local alert = CreateFrame('Frame', nil, UIParent)
    alert:SetSize(440, 108)
    alert:SetPoint('TOP', 0, -138)
    alert:SetFrameStrata('TOOLTIP')
    backdrop(alert, 1, true)
    alert:Hide()
    local warning = label(alert, L.POPUP_WARNING, 15)
    warning:SetPoint('TOP', 0, -12)
    local who = label(alert, '', 14)
    who:SetPoint('TOP', 0, -43)
    local reason = label(alert, '', 11)
    reason:SetPoint('TOP', 0, -70)
    reason:SetWidth(412)
    reason:SetJustifyH('CENTER')
    reason:SetWordWrap(true)
    local dismiss = button(alert, 'X', 23, 23, function() alert:Hide() end)
    dismiss:SetPoint('TOPRIGHT', -5, -5)
    self.alert = alert
    self.alertName = who
    self.alertReason = reason

    -- Forever announces the game menu after showing it. Close our own
    -- dialogs so a frame above the game menu cannot intercept its clicks.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback('GameMenuFrame.Shown', function()
            for _, name in ipairs({'window', 'transfer', 'guildInboxWindow', 'guildInboxDetail', 'guildShareConfirm', 'tagManager', 'alert'}) do
                local frame = CN[name]
                if frame then frame:Hide() end
            end
            CN.pendingGuildShareName = nil
        end, self)
    end
end

function CN:RefreshEditorTags()
    if not self.tagSummary then return end
    local fakeEntry = {tags = self.editorTags or {}}
    local tags = self:TagsForEntry(fakeEntry)
    for index, tag in ipairs(tags) do
        local icon = self.tagSummaryIcons[index]
        if not icon then
            icon = CreateFrame('Button', nil, self.tagSummary)
            icon:SetSize(25, 25)
            icon.texture = icon:CreateTexture(nil, 'ARTWORK')
            icon.texture:SetAllPoints()
            icon:SetScript('OnEnter', function(frame)
                if GameTooltip then
                    GameTooltip:SetOwner(frame, 'ANCHOR_TOP')
                    GameTooltip:SetText(frame.tagName or '', 1, .75, .3)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
            self.tagSummaryIcons[index] = icon
        end
        icon:ClearAllPoints()
        icon:SetPoint('LEFT', self.tagSummary, 'LEFT', (index - 1) * 29, 0)
        icon.texture:SetTexture(tag.icon)
        icon.tagName = tag.name
        icon:Show()
    end
    for index = #tags + 1, #self.tagSummaryIcons do self.tagSummaryIcons[index]:Hide() end
end

function CN:UpdateSoundUI()
    if not self.db then return end
    local sound = self:SelectedSound()
    if self.soundCycleButton then self.soundCycleButton:SetText(L[sound.titleKey] .. '  >') end
    if self.soundEnableCheck then self.soundEnableCheck:SetChecked(self.db.config.sound) end
    if self.soundChoices then
        for key, box in pairs(self.soundChoices) do box:SetChecked(key == sound.key) end
    end
end

function CN:UpdateLanguageUI()
    if self.languageDropdown then self.languageDropdown:Update() end
end

local function optionCheck(panel, text, y, onClick)
    local box = check(panel, onClick)
    box:SetPoint('TOPLEFT', 17, -y)
    local caption = label(panel, text, 12)
    caption:SetPoint('LEFT', box, 'RIGHT', 9, 0)
    return box
end

function CN:ShowOptions()
    self:ShowWindow()
    if not self.window then return end
    if not self.optionsPanel then
        local panel = CreateFrame('Frame', nil, self.window)
        panel:SetSize(362, 455)
        panel:SetPoint('TOPRIGHT', self.window, 'TOPRIGHT', -19, -66)
        panel:EnableMouse(true)
        backdrop(panel)
        panel:Hide()
        self.optionsPanel = panel
        self.window:SetScript('OnHide', function() panel:Hide() end)

        local title = label(panel, L.OPTIONS_TITLE, 15)
        title:SetPoint('TOPLEFT', 16, -13)
        local close = button(panel, 'X', 24, 24, function() panel:Hide() end)
        close:SetPoint('TOPRIGHT', -9, -9)

        local languageHeading = label(panel, L.LANGUAGE, 12)
        languageHeading:SetPoint('TOPLEFT', 16, -47)
        local dropdown = CreateFrame('DropdownButton', nil, panel, 'WowStyle2DropdownTemplate')
        dropdown:SetWidth(154)
        dropdown:SetPoint('TOPRIGHT', -20, -40)
        dropdown:SetupMenu(function(_, menu)
            local function isSelected(language)
                return CN.db.config.language == language
            end
            local function selectLanguage(language)
                CN:SetLanguage(language)
            end
            for _, language in ipairs(CN.LANGUAGE_ORDER) do
                menu:CreateRadio(L[CN.LANGUAGE_LABEL_KEYS[language]], isSelected, selectLanguage, language)
            end
            if #CN.LANGUAGE_ORDER > 7 then menu:SetScrollMode(180) end
        end)
        self.languageDropdown = dropdown
        local reloadHint = label(panel, L.LANGUAGE_RELOAD, 10, 'muted')
        reloadHint:SetPoint('TOPLEFT', 16, -73)
        separator(panel, 16, -92, 330)

        local heading = label(panel, L.SOUND_ON_JOIN, 12, 'muted')
        heading:SetPoint('TOPLEFT', 16, -131)
        local preview = button(panel, L.PREVIEW, 99, 24, function() CN:PlayAlertSound(true) end)
        preview:SetPoint('TOPRIGHT', -16, -126)
        self.soundChoices = {}
        for i, sound in ipairs(self.SOUNDS) do
            local key = sound.key
            self.soundChoices[key] = optionCheck(panel, L[sound.titleKey], 160 + (i - 1) * 24, function()
                CN:SetSoundChoice(key)
            end)
        end

        separator(panel, 16, -278, 330)
        local appearance = label(panel, L.DISPLAY_OPTIONS, 12, 'muted')
        appearance:SetPoint('TOPLEFT', 16, -290)
        self.optionChecks = {}
        local options = {
            {'sound', L.ENABLE_GROUP_SOUND, 101},
            {'popup', L.GROUP_POPUP, 314},
            {'border', L.PUNK_BORDER, 341},
            {'tooltip', L.TOOLTIP_NOTE, 368},
            {'alertAnyNote', L.ALERT_ALL_NOTES, 395},
            {'contextMenus', L.PLAYER_MENUS, 422},
        }
        for _, option in ipairs(options) do
            local key = option[1]
            self.optionChecks[key] = optionCheck(panel, option[2], option[3], function(box)
                CN:SetOption(key, not not box:GetChecked())
            end)
        end

    end
    for key, box in pairs(self.optionChecks) do box:SetChecked(self.db.config[key]) end
    self:UpdateSoundUI()
    self:UpdateLanguageUI()
    self.optionsPanel:SetFrameLevel(self.window:GetFrameLevel() + 15)
    self.optionsPanel:Show()
end

function CN:RefreshList()
    if not self.listContent or not self.db then return end
    local q = self.search and self.search:GetText() or ''
    local items = self:EntryList(q)
    local holder = self.listContent
    holder:SetHeight(math.max(1, #items * 31))
    if self.listCount then self.listCount:SetText((#items == 1 and L.ONE_ENTRY or L.MANY_ENTRIES):format(#items)) end
    if self.emptyListLabel then
        self.emptyListLabel:SetShown(#items == 0)
        self.emptyListLabel:SetText(q ~= '' and L.EMPTY_SEARCH or L.EMPTY_LIST)
    end
    for idx, entry in ipairs(items) do
        local b = self.listButtons[idx]
        if not b then
            b = CreateFrame('Button', nil, holder)
            b:SetSize(229, 29)
            local bg = b:CreateTexture(nil, 'BACKGROUND')
            bg:SetAllPoints()
            bg:SetTexture(WHITE)
            b.bg = bg
            local name = b:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
            name:SetPoint('LEFT', 9, 0)
            name:SetWidth(209)
            name:SetJustifyH('LEFT')
            b.text = name
            b:SetScript('OnEnter', function(self) self.bg:SetVertexColor(.27, .30, .39, .95) end)
            b:SetScript('OnLeave', function(self)
                if self.selected then self.bg:SetVertexColor(.25, .27, .35, .92)
                else self.bg:SetVertexColor(.15, .17, .22, .86) end
            end)
            self.listButtons[idx] = b
        end
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT', holder, 'TOPLEFT', 0, -(idx - 1) * 31)
        b.text:SetText((entry.punk and ORANGE .. '[PUNK]|r  ' or '') .. (entry.name or '?'))
        local currentKey = self.currentName and self:Normalize(self.currentName)
        local itemKey = self:Normalize(entry.name or '')
        b.selected = currentKey ~= nil and currentKey == itemKey
        if b.selected then b.bg:SetVertexColor(.25, .27, .35, .92)
        else b.bg:SetVertexColor(.15, .17, .22, .86) end
        b:SetScript('OnClick', function() CN:OpenEditor(entry.name) end)
        b:Show()
    end
    for i = #items + 1, #self.listButtons do self.listButtons[i]:Hide() end
    if self.refreshListScroll then self.refreshListScroll() end
end

function CN:ShowWindow()
    if not self.window then return end
    self.window:Show()
    self.window:Raise()
    self:RefreshList()
end

function CN:OpenEditor(name)
    self:ShowWindow()
    name = name or ''
    local entry = self:Get(name)
    self.currentName = (entry and entry.name) or name
    self.nameEdit:SetText(self.currentName)
    self.noteEdit:SetText(entry and entry.note or '')
    self.punkCheck:SetChecked(entry and entry.punk or not entry)
    self.editorTags = self:CloneTagIds(entry and entry.tags)
    self:RefreshEditorTags()
    if self.noteScroll then self.noteScroll:SetVerticalScroll(0) end
    self.nameEdit:ClearFocus()
    self.noteEdit:ClearFocus()
    self:RefreshList()
end

function CN:SaveEditor()
    local name = self.nameEdit:GetText()
    local ok, err = self:Store(name, self.noteEdit:GetText(), self.punkCheck:GetChecked(), self.editorTags)
    if not ok then self:Print(err); return end
    self.currentName = name
    self:Print(L.NOTE_SAVED)
    self:RefreshList()
end

function CN:DeleteEditor()
    local name = self.nameEdit:GetText()
    if name == '' then return end
    self:Delete(name)
    self.currentName = nil
    self.nameEdit:SetText('')
    self.noteEdit:SetText('')
    self.punkCheck:SetChecked(true)
    self.editorTags = {}
    self:RefreshEditorTags()
    self:Print(L.NOTE_REMOVED)
    self:RefreshList()
end

function CN:ShowTagManager()
    if not self.tagManager then
        local w = CreateFrame('Frame', 'ElvUICharNotesTagManager', UIParent)
        w:SetSize(760, 570)
        w:SetPoint('CENTER', 0, 20)
        w:SetFrameStrata('FULLSCREEN_DIALOG')
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', w.StartMoving)
        w:SetScript('OnDragStop', w.StopMovingOrSizing)
        backdrop(w)
        w:Hide()
        self.tagManager = w

        local title = label(w, L.TAG_MANAGER_TITLE, 16)
        title:SetPoint('TOPLEFT', 18, -16)
        local hint = label(w, L.TAG_MANAGER_HINT, 11, 'muted')
        hint:SetPoint('TOPLEFT', 19, -42)
        local close = button(w, 'X', 26, 26, function() w:Hide() end)
        close:SetPoint('TOPRIGHT', -13, -12)
        separator(w, 18, -65, 724)

        local listBox = CreateFrame('Frame', nil, w)
        listBox:SetPoint('TOPLEFT', 18, -82)
        listBox:SetSize(245, 420)
        backdrop(listBox, .57)
        local scroll = CreateFrame('ScrollFrame', nil, listBox)
        scroll:SetPoint('TOPLEFT', 6, -6)
        scroll:SetPoint('BOTTOMRIGHT', -18, 6)
        local content = CreateFrame('Frame', nil, scroll)
        content:SetSize(216, 1)
        scroll:SetScrollChild(content)
        self.tagListContent = content
        self.tagListRows = {}
        self.refreshTagListScroll = addScrollControl(listBox, scroll, content, 34)
        local empty = label(listBox, L.TAG_NO_TAGS, 11, 'muted')
        empty:SetPoint('TOPLEFT', 13, -16)
        self.tagListEmpty = empty

        local nameLabel = label(w, L.TAG_NAME, 12)
        nameLabel:SetPoint('TOPLEFT', 286, -84)
        local nameEdit = edit(w, 300, 28, false)
        nameEdit:SetPoint('TOPLEFT', 286, -104)
        nameEdit:SetMaxLetters(40)
        self.tagNameEdit = nameEdit
        local newTag = button(w, L.TAG_NEW, 125, 28, function() CN:SelectTag(nil) end)
        newTag:SetPoint('TOPRIGHT', -18, -104)

        local iconLabel = label(w, L.TAG_ICON, 12)
        iconLabel:SetPoint('TOPLEFT', 286, -146)
        local iconSearch = edit(w, 265, 25, false)
        iconSearch:SetPoint('TOPRIGHT', -18, -138)
        local iconSearchHint = label(iconSearch, L.TAG_ICON_SEARCH, 10, 'muted')
        iconSearchHint:SetPoint('LEFT', 8, 0)
        iconSearch:SetScript('OnTextChanged', function(field)
            iconSearchHint:SetShown(field:GetText() == '')
            CN.tagIconPage = 1
            CN:RefreshTagIconSelection()
        end)
        iconSearch:SetScript('OnEditFocusGained', function() iconSearchHint:Hide() end)
        iconSearch:SetScript('OnEditFocusLost', function(field)
            iconSearchHint:SetShown(field:GetText() == '')
        end)
        self.tagIconSearch = iconSearch
        self.tagIconButtons = {}
        self.tagIconPage = 1
        for index = 1, 40 do
            local icon = CreateFrame('Button', nil, w)
            icon:SetSize(38, 38)
            local column = (index - 1) % 10
            local row = math.floor((index - 1) / 10)
            icon:SetPoint('TOPLEFT', 286 + column * 44, -168 - row * 44)
            icon.texture = icon:CreateTexture(nil, 'ARTWORK')
            icon.texture:SetPoint('TOPLEFT', 3, -3)
            icon.texture:SetPoint('BOTTOMRIGHT', -3, 3)
            icon:SetScript('OnClick', function(frame)
                if not frame.iconPath then return end
                CN.tagSelectedIcon = frame.iconPath
                CN:RefreshTagIconSelection()
            end)
            icon:SetScript('OnEnter', function(frame)
                backdrop(frame, nil, nil, true)
                if GameTooltip then
                    GameTooltip:SetOwner(frame, 'ANCHOR_TOP')
                    GameTooltip:SetText(frame.iconName, 1, .75, .3)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript('OnLeave', function(frame)
                backdrop(frame, .88, frame.iconPath == CN.tagSelectedIcon)
                if GameTooltip then GameTooltip:Hide() end
            end)
            self.tagIconButtons[index] = icon
        end

        local previous = button(w, '<', 36, 24, function()
            CN.tagIconPage = math.max(1, (CN.tagIconPage or 1) - 1)
            CN:RefreshTagIconSelection()
        end)
        previous:SetPoint('TOPLEFT', 286, -347)
        local page = label(w, '', 10, 'muted')
        page:SetPoint('LEFT', previous, 'RIGHT', 10, 0)
        page:SetWidth(120)
        page:SetJustifyH('CENTER')
        self.tagIconPageLabel = page
        local nextPage = button(w, '>', 36, 24, function()
            CN.tagIconPage = math.min(CN.tagIconPageCount or 1, (CN.tagIconPage or 1) + 1)
            CN:RefreshTagIconSelection()
        end)
        nextPage:SetPoint('LEFT', page, 'RIGHT', 10, 0)

        local tooltipCheck = check(w)
        tooltipCheck:SetPoint('TOPLEFT', 286, -384)
        self.tagTooltipCheck = tooltipCheck
        local tooltipText = label(w, L.TAG_TOOLTIP, 11)
        tooltipText:SetPoint('LEFT', tooltipCheck, 'RIGHT', 7, 0)
        local framesCheck = check(w)
        framesCheck:SetPoint('TOPLEFT', 286, -413)
        self.tagFramesCheck = framesCheck
        local framesText = label(w, L.TAG_FRAMES, 11)
        framesText:SetPoint('LEFT', framesCheck, 'RIGHT', 7, 0)

        local pointLabel = label(w, L.TAG_POSITION, 11)
        pointLabel:SetPoint('TOPLEFT', 286, -449)
        local point = CreateFrame('DropdownButton', nil, w, 'WowStyle2DropdownTemplate')
        point:SetWidth(190)
        point:SetPoint('TOPLEFT', 402, -440)
        point:SetupMenu(function(_, menu)
            for _, value in ipairs(CN.TAG_FRAME_POINTS) do
                menu:CreateRadio(L[CN.TAG_FRAME_POINT_KEYS[value]],
                    function(candidate) return CN.tagFramePoint == candidate end,
                    function(candidate) CN.tagFramePoint = candidate end, value)
            end
        end)
        self.tagPointDropdown = point

        local save = button(w, L.TAG_SAVE, 130, 30, function() CN:SaveTagEditor() end, true)
        save:SetPoint('BOTTOMLEFT', 286, 20)
        local delete = button(w, L.TAG_DELETE, 165, 30, function() CN:DeleteTagEditor() end)
        delete:SetPoint('LEFT', save, 'RIGHT', 8, 0)
        self.tagDeleteButton = delete
        local done = button(w, L.TAG_DONE, 105, 30, function()
            CN:RefreshEditorTags()
            w:Hide()
        end)
        done:SetPoint('BOTTOMRIGHT', -18, 20)
    end
    if self.tagSelectedId and self.db.tags[self.tagSelectedId] then self:SelectTag(self.tagSelectedId)
    else self:SelectTag(nil) end
    self.tagManager:Show()
    self.tagManager:Raise()
end

function CN:RefreshTagIconSelection()
    local query = self.tagIconSearch and self.tagIconSearch:GetText() or ''
    local catalog = self:FilterBlizzardIcons(query)
    local pageSize = 40
    self.tagIconPageCount = math.max(1, math.ceil(#catalog / pageSize))
    self.tagIconPage = math.min(self.tagIconPageCount, math.max(1, self.tagIconPage or 1))
    local first = (self.tagIconPage - 1) * pageSize
    for index, icon in ipairs(self.tagIconButtons or {}) do
        local item = catalog[first + index]
        if item then
            icon.iconPath, icon.iconName = item, self:GetBlizzardIconName(item)
            icon.texture:SetTexture(item)
            backdrop(icon, .88, item == self.tagSelectedIcon)
            icon:Show()
        else
            icon.iconPath, icon.iconName = nil, nil
            icon:Hide()
        end
    end
    if self.tagIconPageLabel then
        self.tagIconPageLabel:SetText(('%d / %d'):format(self.tagIconPage, self.tagIconPageCount))
    end
end

function CN:SelectTag(id)
    local tag = id and self.db.tags[id]
    self.tagSelectedId = tag and id or nil
    self.pendingTagDeleteId = nil
    if self.tagDeleteButton then self.tagDeleteButton:SetText(L.TAG_DELETE) end
    self.tagNameEdit:SetText(tag and tag.name or '')
    self.tagSelectedIcon = tag and tag.icon or self.BLIZZARD_ICONS[1][1]
    if self.tagIconSearch then self.tagIconSearch:SetText('') end
    local catalog = self:GetBlizzardIconCatalog()
    for index, item in ipairs(catalog) do
        if item == self.tagSelectedIcon then self.tagIconPage = math.ceil(index / 40); break end
    end
    self.tagTooltipCheck:SetChecked(not tag or tag.showTooltip)
    self.tagFramesCheck:SetChecked(tag and tag.showFrames or false)
    self.tagFramePoint = tag and tag.framePoint or 'TOPRIGHT'
    if self.tagPointDropdown then self.tagPointDropdown:Update() end
    self:RefreshTagIconSelection()
    self:RefreshTagManager(self.tagSelectedId, true)
end

local function tagAssigned(tags, id)
    for _, value in ipairs(tags or {}) do if value == id then return true end end
    return false
end

function CN:ToggleEditorTag(id, enabled)
    local nextTags = {}
    for _, value in ipairs(self.editorTags or {}) do if value ~= id then nextTags[#nextTags + 1] = value end end
    if enabled then
        if #nextTags >= self.MAX_TAGS_PER_ENTRY then
            self:Print(L.TAG_LIMIT:format(self.MAX_TAGS_PER_ENTRY))
            return false
        end
        nextTags[#nextTags + 1] = id
    end
    table.sort(nextTags)
    self.editorTags = nextTags
    -- Existing notes persist tag assignments immediately. This avoids a
    -- surprising second save step after closing the tag manager, while new
    -- notes still keep the selection pending until their first normal save.
    if self.currentName and self:Get(self.currentName) then
        self:SetEntryTags(self.currentName, nextTags)
    end
    self:RefreshEditorTags()
    return true
end

function CN:RefreshTagManager(selectedId, keepEditor)
    if not self.tagListContent then return end
    local tags = self:TagDefinitions()
    self.tagListContent:SetHeight(math.max(1, #tags * 34))
    self.tagListEmpty:SetShown(#tags == 0)
    for index, tag in ipairs(tags) do
        local row = self.tagListRows[index]
        if not row then
            row = CreateFrame('Button', nil, self.tagListContent)
            row:SetSize(216, 32)
            row.check = check(row)
            row.check:SetPoint('LEFT', 5, 0)
            row.icon = row:CreateTexture(nil, 'ARTWORK')
            row.icon:SetSize(24, 24)
            row.icon:SetPoint('LEFT', 30, 0)
            row.text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
            row.text:SetPoint('LEFT', 61, 0)
            row.text:SetWidth(148)
            row.text:SetJustifyH('LEFT')
            row:SetScript('OnEnter', function(frame) backdrop(frame, nil, nil, true) end)
            row:SetScript('OnLeave', function(frame) backdrop(frame, .75, frame.tagId == CN.tagSelectedId) end)
            self.tagListRows[index] = row
        end
        local id = tag.id
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 0, -(index - 1) * 34)
        row.tagId = id
        row.icon:SetTexture(tag.icon)
        row.text:SetText(tag.name)
        row.check:SetChecked(tagAssigned(self.editorTags, id))
        row.check:SetScript('OnClick', function(box)
            if not CN:ToggleEditorTag(id, not not box:GetChecked()) then box:SetChecked(false) end
        end)
        row:SetScript('OnClick', function() CN:SelectTag(id) end)
        backdrop(row, .75, id == selectedId)
        row:Show()
    end
    for index = #tags + 1, #self.tagListRows do self.tagListRows[index]:Hide() end
    if self.refreshTagListScroll then self.refreshTagListScroll() end
    if selectedId and not keepEditor and self.db.tags[selectedId] then self:SelectTag(selectedId) end
end

function CN:SaveTagEditor()
    local id, err
    if self.tagSelectedId then
        local ok
        ok, err = self:UpdateTag(self.tagSelectedId, self.tagNameEdit:GetText(), self.tagSelectedIcon,
            self.tagTooltipCheck:GetChecked(), self.tagFramesCheck:GetChecked(), self.tagFramePoint)
        if ok then id = self.tagSelectedId end
    else
        id, err = self:CreateTag(self.tagNameEdit:GetText(), self.tagSelectedIcon,
            self.tagTooltipCheck:GetChecked(), self.tagFramesCheck:GetChecked(), self.tagFramePoint)
        if id then self:ToggleEditorTag(id, true) end
    end
    if not id then self:Print(err); return end
    self:SelectTag(id)
    self:RefreshHighlights()
end

function CN:DeleteTagEditor()
    local id = self.tagSelectedId
    if not id then self:Print(L.TAG_SELECT_FIRST); return end
    if self.pendingTagDeleteId ~= id then
        self.pendingTagDeleteId = id
        self.tagDeleteButton:SetText(L.TAG_DELETE_CONFIRM)
        return
    end
    self:ToggleEditorTag(id, false)
    self:DeleteTag(id)
    self:SelectTag(nil)
    self:RefreshTagManager(nil, true)
    self:RefreshHighlights()
end

function CN:ShowAlert(name, note)
    if not self.alert then return end
    self.alertName:SetText(name)
    self.alertReason:SetText(note and note:sub(1, 185) or '')
    self.alert:Show()
    self.alertTick = (self.alertTick or 0) + 1
    local id = self.alertTick
    if C_Timer and C_Timer.After then
        C_Timer.After(12, function() if id == CN.alertTick then CN.alert:Hide() end end)
    end
end

function CN:ShowTransfer(importMode)
    if not self.transfer then
        local f = CreateFrame('Frame', 'ElvUICharNotesTransfer', UIParent)
        f:SetSize(700, 420)
        f:SetPoint('CENTER', 0, 30)
        f:SetFrameStrata('FULLSCREEN_DIALOG')
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag('LeftButton')
        f:SetScript('OnDragStart', f.StartMoving)
        f:SetScript('OnDragStop', f.StopMovingOrSizing)
        backdrop(f)
        f:Hide()
        local title = label(f, L.TRANSFER_TITLE, 16)
        title:SetPoint('TOPLEFT', 18, -15)
        local instr = label(f, '', 11)
        instr:SetPoint('TOPLEFT', 18, -47)
        instr:SetWidth(650)
        instr:SetJustifyH('LEFT')
        self.transferInstr = instr
        local box = CreateFrame('Frame', nil, f)
        box:SetPoint('TOPLEFT', 17, -80)
        box:SetSize(655, 276)
        backdrop(box)
        local sc = CreateFrame('ScrollFrame', nil, box)
        sc:SetPoint('TOPLEFT', 8, -8)
        sc:SetPoint('BOTTOMRIGHT', -28, 8)
        local e = edit(sc, 608, 252, true)
        sc:SetScrollChild(e)
        local refreshTransfer = addScrollControl(box, sc, e, 40)
        e:SetScript('OnTextChanged', function(self)
            resizeEditToContent(self, sc, refreshTransfer, 252)
        end)
        self.transferEdit = e
        local run = button(f, L.RUN_IMPORT, 150, 27, function()
            local imported, err = CN:ImportData(CN.transferEdit:GetText())
            CN:Print(imported and L.IMPORT_DONE:format(imported) or err)
        end)
        run:SetPoint('BOTTOMLEFT', 18, 15)
        self.transferRun = run
        local close = button(f, L.CLOSE, 120, 27, function() f:Hide() end)
        close:SetPoint('BOTTOMRIGHT', -19, 15)
        self.transfer = f
    end
    self.transferRun:SetShown(importMode)
    self.transferInstr:SetText(importMode and L.IMPORT_INSTRUCTIONS or L.EXPORT_INSTRUCTIONS)
    self.transferEdit:SetText(importMode and '' or self:ExportData())
    self.transfer:Show()
    self.transferEdit:SetFocus()
    if not importMode then self.transferEdit:HighlightText() end
end

function CN:ShowGuildInbox()
    if not self.guildInboxWindow then
        local w = CreateFrame('Frame', 'ElvUICharNotesInbox', UIParent)
        w:SetSize(680, 460)
        w:SetPoint('CENTER', 0, 30)
        w:SetFrameStrata('FULLSCREEN_DIALOG')
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', w.StartMoving)
        w:SetScript('OnDragStop', w.StopMovingOrSizing)
        backdrop(w)
        w:Hide()
        local title = label(w, L.GUILD_INBOX_TITLE, 16)
        title:SetPoint('TOPLEFT', 16, -17)
        local hint = label(w, L.GUILD_INBOX_HINT, 11)
        hint:SetPoint('TOPLEFT', 16, -48)
        local close = button(w, L.CLOSE, 95, 25, function() w:Hide() end)
        close:SetPoint('BOTTOMRIGHT', -15, 12)
        local pane = CreateFrame('Frame', nil, w)
        pane:SetPoint('TOPLEFT', 16, -78)
        pane:SetSize(646, 320)
        backdrop(pane, .4)
        local scroll = CreateFrame('ScrollFrame', nil, pane)
        scroll:SetPoint('TOPLEFT', 4, -4)
        scroll:SetPoint('BOTTOMRIGHT', -28, 4)
        local content = CreateFrame('Frame', nil, scroll)
        content:SetSize(600, 1)
        scroll:SetScrollChild(content)
        self.refreshInboxScroll = addScrollControl(pane, scroll, content, 77)
        self.guildInboxContent = content
        self.guildInboxItems = {}
        self.guildInboxWindow = w
    end
    self:RefreshInbox()
    self.guildInboxWindow:Show()
    self.guildInboxWindow:Raise()
end

function CN:RefreshInbox()
    if not self.guildInboxContent or not self.db then return end
    local entries = self.db.inbox
    local holder = self.guildInboxContent
    holder:SetHeight(math.max(1, #entries * 76))
    for i, entry in ipairs(entries) do
        local row = self.guildInboxItems[i]
        if not row then
            row = CreateFrame('Frame', nil, holder)
            row:SetSize(592, 74)
            local bg = row:CreateTexture(nil, 'BACKGROUND')
            bg:SetAllPoints()
            bg:SetTexture(WHITE)
            bg:SetVertexColor(.14, .16, .21, .8)
            row.head = label(row, '', 12)
            row.head:SetPoint('TOPLEFT', 8, -6)
            row.note = label(row, '', 11)
            row.note:SetPoint('TOPLEFT', 8, -29)
            row.note:SetWidth(415)
            row.note:SetHeight(41)
            row.note:SetJustifyH('LEFT')
            row.note:SetJustifyV('TOP')
            row.note:SetWordWrap(true)
            row.accept = button(row, L.VIEW, 102, 24)
            row.accept:SetPoint('TOPRIGHT', -5, -7)
            row.reject = button(row, L.REJECT, 102, 24)
            row.reject:SetPoint('TOPRIGHT', -5, -36)
            self.guildInboxItems[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 0, -(i - 1) * 76)
        row.head:SetText(L.INBOX_ENTRY:format(entry.entry.punk and ORANGE .. '[PUNK]|r' or L.NOTE_TAG, entry.entry.name, entry.sender))
        row.note:SetText((entry.entry.note ~= '' and entry.entry.note or L.NO_NOTE_TEXT):sub(1, 300):gsub('|', '||'))
        row.accept:SetScript('OnClick', function() CN:ShowGuildInboxDetail(i) end)
        row.reject:SetScript('OnClick', function() CN:RejectInbox(i) end)
        row:Show()
    end
    for i = #entries + 1, #self.guildInboxItems do self.guildInboxItems[i]:Hide() end
    if self.refreshInboxScroll then self.refreshInboxScroll() end
end


function CN:ShowGuildInboxDetail(index)
    local item = self.db and self.db.inbox[index]
    if not item then return end
    if not self.guildInboxDetail then
        local w = CreateFrame('Frame', 'ElvUICharNotesInboxDetail', UIParent)
        w:SetSize(670, 415)
        w:SetPoint('CENTER', 0, 45)
        w:SetFrameStrata('TOOLTIP')
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', w.StartMoving)
        w:SetScript('OnDragStop', w.StopMovingOrSizing)
        backdrop(w)
        w:Hide()
        local title = label(w, '', 15)
        title:SetPoint('TOPLEFT', 18, -15)
        title:SetWidth(610)
        title:SetJustifyH('LEFT')
        local detailBox = CreateFrame('Frame', nil, w)
        detailBox:SetPoint('TOPLEFT', 18, -52)
        detailBox:SetSize(634, 298)
        backdrop(detailBox, .57)
        local scroll = CreateFrame('ScrollFrame', nil, detailBox)
        scroll:SetPoint('TOPLEFT', 8, -8)
        scroll:SetPoint('BOTTOMRIGHT', -18, 8)
        local note = edit(scroll, 602, 280, true)
        scroll:SetScrollChild(note)
        local refresh = addScrollControl(detailBox, scroll, note, 40)
        note:SetScript('OnEditFocusGained', function(self) self:ClearFocus() end)
        self.guildInboxDetailTitle = title
        self.guildInboxDetailText = note
        self.guildInboxDetailScroll = scroll
        self.refreshGuildInboxDetailScroll = refresh
        self.guildInboxDetail = w
        local accept = button(w, L.ACCEPT_NOTE, 180, 28, function()
            local n = CN.guildInboxDetailIndex
            if CN.db.inbox[n] then CN:AcceptInbox(n) end
            w:Hide()
        end)
        accept:SetPoint('BOTTOMLEFT', 18, 16)
        local reject = button(w, L.REJECT, 110, 28, function()
            local n = CN.guildInboxDetailIndex
            if CN.db.inbox[n] then CN:RejectInbox(n) end
            w:Hide()
        end)
        reject:SetPoint('LEFT', accept, 'RIGHT', 8, 0)
        local close = button(w, L.CLOSE, 110, 28, function() w:Hide() end)
        close:SetPoint('BOTTOMRIGHT', -20, 16)
    end
    self.guildInboxDetailIndex = index
    self.guildInboxDetailTitle:SetText(L.GUILD_DETAIL_TITLE:format(item.entry.name, item.sender))
    self.guildInboxDetailText:SetText(item.entry.note or '')
    resizeEditToContent(self.guildInboxDetailText, self.guildInboxDetailScroll,
        self.refreshGuildInboxDetailScroll, 280)
    self.guildInboxDetailScroll:SetVerticalScroll(0)
    self.guildInboxDetailText:SetCursorPosition(0)
    self.guildInboxDetail:Show()
    self.guildInboxDetail:Raise()
end

-- Created only when the user explicitly shares a guild note.  A standalone
-- confirmation avoids tainting Blizzard's shared StaticPopupDialogs table.
function CN:ShowGuildSharePrompt(playerName)
    if not self.guildShareConfirm then
        local w = CreateFrame('Frame', nil, UIParent)
        w:SetSize(460, 150)
        w:SetPoint('CENTER')
        w:SetFrameStrata('DIALOG')
        w:EnableMouse(true)
        backdrop(w)
        local title = label(w, ORANGE .. L.GUILD_SHARE_TITLE .. '|r', 14)
        title:SetPoint('TOPLEFT', 18, -16)
        local info = label(w, '', 12, 'muted')
        info:SetPoint('TOPLEFT', 18, -49)
        info:SetWidth(422)
        info:SetJustifyH('LEFT')
        self.guildShareConfirmText = info
        local yes = button(w, L.SHARE, 135, 29, function()
            local name = CN.pendingGuildShareName
            CN.pendingGuildShareName = nil
            w:Hide()
            if name then CN:ShareGuild(name) end
        end, true)
        yes:SetPoint('BOTTOMRIGHT', -126, 15)
        local no = button(w, L.CANCEL, 110, 29, function()
            CN.pendingGuildShareName = nil
            w:Hide()
        end)
        no:SetPoint('LEFT', yes, 'RIGHT', 8, 0)
        w:Hide()
        self.guildShareConfirm = w
    end
    self.pendingGuildShareName = playerName
    self.guildShareConfirmText:SetText(L.GUILD_SHARE_CONFIRM:format(tostring(playerName)))
    self.guildShareConfirm:Show()
    self.guildShareConfirm:Raise()
end

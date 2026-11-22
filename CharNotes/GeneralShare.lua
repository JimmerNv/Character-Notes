local _, CN = ...
local W, L = CN.widgets, CN.L

local function window(name, width, height)
    local f = CreateFrame('Frame', name, UIParent)
    f:SetSize(width, height)
    f:SetPoint('CENTER')
    f:SetFrameStrata('FULLSCREEN_DIALOG')
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart', f.StartMoving)
    f:SetScript('OnDragStop', f.StopMovingOrSizing)
    W.backdrop(f)
    W.action(f, 'X', 28, width-43, -12, function() f:Hide() end)
    f:Hide()
    return f
end

function CN:ShowGeneralShareDialog(id)
    if not self.db or not self.db.generalNotes[id] then return end
    if not self.generalShareWindow then
        local f = window('ElvUICharNotesGeneralShare', 580, 340)
        self.generalShareWindow = f
        W.caption(f, L.GENERAL_SHARE_TITLE, 20, -19, 16)
        W.caption(f, L.GENERAL_CHANNEL, 20, -75)
        local channels = {'PARTY', 'RAID', 'GUILD', 'WHISPER'}
        local buttons = {}
        local function choose(channel)
            f.channel = channel
            for key, button in pairs(buttons) do
                button.cnAccent = key == channel
                W.backdrop(button, 1, button.cnAccent)
            end
            f.recipient:SetShown(channel == 'WHISPER')
            f.targetButton:SetShown(channel == 'WHISPER')
            f.recipientHint:SetShown(channel == 'WHISPER')
        end
        for i, channel in ipairs(channels) do
            local button = W.action(f, L['GENERAL_'..channel], 126, 20+(i-1)*135, -100,
                function() choose(channel) end)
            buttons[channel] = button
        end
        f.recipientHint = W.caption(f, L.GENERAL_RECIPIENT, 20, -155)
        f.recipient = W.edit(f, 298, 28)
        f.recipient:SetMaxLetters(128)
        f.recipient:SetPoint('TOPLEFT', 20, -177)
        f.targetButton = W.action(f, L.USE_TARGET, 155, 329, -177, function()
            local _, name = CN:FromUnit('target')
            if name then f.recipient:SetText(name)
            else f.status:SetText(L.TARGET_UNREADABLE) end
        end)
        f.status = W.caption(f, '', 20, -218, 12)
        f.status:SetWidth(530)
        f.status:SetJustifyH('LEFT')
        W.action(f, L.SHARE, 160, 20, -260, function()
            local note = CN.db.generalNotes[f.noteID]
            if not note or (CN.notebook and CN.notebook.isDirty()) then
                f.status:SetText(L.SAVE_BEFORE_SHARE)
                return
            end
            local ok, result = CN:ShareGeneralNote(f.noteID, f.channel, f.recipient:GetText())
            f.status:SetText(ok and L.GENERAL_QUEUED:format(result) or result)
        end)
        W.action(f, L.CLOSE, 160, 190, -260, function() f:Hide() end)
        f.chooseChannel = choose
    end
    local f = self.generalShareWindow
    f.noteID = id
    f.recipient:SetText('')
    f.status:SetText(L.GENERAL_SHARE_HINT:format(self.db.generalNotes[id].title))
    f.chooseChannel('WHISPER')
    f:Show()
    f:Raise()
end

function CN:ShowGeneralInbox()
    if not self.generalInboxWindow then
        local f = window('ElvUICharNotesGeneralInbox', 780, 495)
        self.generalInboxWindow = f
        W.caption(f, L.GENERAL_INBOX_TITLE, 20, -18, 16)
        W.caption(f, L.GENERAL_INBOX_HINT, 20, -46, 11)
        local list = W.list(f, 20, -84, 230, 350)
        local box = CreateFrame('Frame', nil, f)
        box:SetPoint('TOPLEFT', 265, -84)
        box:SetSize(494, 350)
        W.backdrop(box)
        local scroll = CreateFrame('ScrollFrame', nil, box)
        scroll:SetPoint('TOPLEFT', 7, -7)
        scroll:SetPoint('BOTTOMRIGHT', -18, 7)
        local preview = W.edit(scroll, 466, 333, true)
        scroll:SetScrollChild(preview)
        local resize = W.scroll(box, scroll, preview, 38)
        preview:HookScript('OnEditFocusGained', function(self) self:ClearFocus() end)
        f.preview, f.previewScroll, f.resizePreview = preview, scroll, resize
        local selected
        local function refresh()
            local rows = {}
            for i, item in ipairs(CN.db.generalInbox) do
                rows[#rows+1] = {key=i, label=L.GENERAL_INBOX_ITEM:format(item.note.title:gsub('|','||'), item.sender)}
            end
            if not CN.db.generalInbox[selected] then selected = nil end
            list(rows, function(index)
                selected = index
                refresh()
            end, selected)
            local item = CN.db.generalInbox[selected]
            if item then
                local builds = CN:CopyNoteBuilds(item.note) or {}
                local names = {}
                for _, entry in ipairs(builds) do
                    local class=entry.build.class
                    names[#names+1]=entry.name..' ('..(LOCALIZED_CLASS_NAMES_MALE and
                        LOCALIZED_CLASS_NAMES_MALE[class] or class)..')'
                end
                local summary = #names > 0 and (L.TALENT_PLANNER..': '..table.concat(names,', ')) or ''
                preview:SetText(L.GENERAL_PREVIEW:format(item.note.title, item.sender,
                    L['GENERAL_'..item.channel] or item.channel, summary, item.note.body))
            else preview:SetText(L.GENERAL_SELECT_NOTE) end
            preview:SetCursorPosition(0)
            scroll:SetVerticalScroll(0)
            W.resizeEdit(preview, scroll, resize, 333)
        end
        f.refreshInbox = refresh
        W.action(f, L.ACCEPT_NOTE, 145, 20, -448, function()
            if selected then CN:AcceptGeneralInbox(selected); selected = nil; refresh() end
        end)
        W.action(f, L.REJECT, 120, 175, -448, function()
            if selected then CN:RejectGeneralInbox(selected); selected = nil; refresh() end
        end)
        W.action(f, L.CLOSE, 120, 640, -448, function() f:Hide() end)
    end
    self:RefreshGeneralInbox()
    self.generalInboxWindow:Show()
    self.generalInboxWindow:Raise()
end

function CN:RefreshGeneralInbox()
    if self.generalInboxWindow and self.generalInboxWindow.refreshInbox then
        self.generalInboxWindow.refreshInbox()
    end
end

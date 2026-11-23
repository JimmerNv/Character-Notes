local _, CN = ...
local L = CN.L

-- Central repository setting. The game never makes an HTTP/API request.
CN.SUPPORT_REPOSITORY = 'https://github.com/JimmerNv/Character-Notes'
local templates = {bug='bug_report.yml', feature='feature_request.yml', feedback='feedback.yml'}
local fields = {bug='summary', feature='feature', feedback='topic'}
local prefixes = {bug='[Bug] ', feature='[Feature] ', feedback='[Feedback] '}
local function encode(s)
    return (tostring(s or ''):gsub('\n', '\r\n'):gsub('([^%w%-_%.~])', function(c)
        return string.format('%%%02X', string.byte(c))
    end))
end
local function text(frame, label, x, y)
    local f = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    f:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, y)
    f:SetText(label)
    return f
end
local function action(frame, title, x, y, width, handler)
    local b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    b:SetSize(width, 25)
    b:SetPoint('TOPLEFT', x, y)
    b:SetText(title)
    b:SetScript('OnClick', function()
        if CN.LogEvent then CN:LogEvent('UI_BUTTON_CLICKED', 'support-button') end
        handler()
    end)
    return b
end
-- Section backgrounds are textures on the support window itself, not child
-- frames. A child frame renders above its parent's font strings even when its
-- texture is BACKGROUND: that hid every field label in v1.13.10.
-- Keeping backgrounds on the same frame guarantees OVERLAY labels stay visible.
local function section(parent, top, height, purpose)
    local bg = parent:CreateTexture(nil, 'BACKGROUND')
    bg:SetPoint('TOPLEFT', parent, 'TOPLEFT', 12, top)
    bg:SetSize(756, height)
    bg:SetTexture('Interface\\Buttons\\WHITE8X8')
    if purpose == 'report' then
        bg:SetVertexColor(.09, .115, .16, 1)
    elseif purpose == 'link' then
        bg:SetVertexColor(.075, .12, .15, 1)
    else
        bg:SetVertexColor(.105, .12, .15, 1)
    end
    local marker = parent:CreateTexture(nil, 'BORDER')
    marker:SetTexture('Interface\\Buttons\\WHITE8X8')
    marker:SetPoint('TOPLEFT', parent, 'TOPLEFT', 12, top)
    marker:SetSize(3, height)
    if purpose == 'report' then
        marker:SetVertexColor(.48, .64, .83, 1)
    elseif purpose == 'link' then
        marker:SetVertexColor(.4, .7, .7, 1)
    else
        marker:SetVertexColor(.95, .65, .28, 1)
    end
end

local function input(parent, width, height, multiline, readonly, purpose)
    local outer = CreateFrame('Frame', nil, parent)
    outer:SetSize(width, height)
    local bg = outer:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    bg:SetTexture('Interface\\Buttons\\WHITE8X8')
    bg:SetVertexColor(.035, .045, .065, 1)
    -- Thin borders keep dark editable fields visibly separate from previews.
    local sides = {
        {'TOPLEFT', 'TOPRIGHT'}, {'BOTTOMLEFT', 'BOTTOMRIGHT'},
        {'TOPLEFT', 'BOTTOMLEFT'}, {'TOPRIGHT', 'BOTTOMRIGHT'},
    }
    for index, points in ipairs(sides) do
        local edge = outer:CreateTexture(nil, 'BORDER')
        edge:SetTexture('Interface\\Buttons\\WHITE8X8')
        edge:SetPoint(points[1], outer, points[1])
        edge:SetPoint(points[2], outer, points[2])
        if index <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        if purpose == 'report' then
            edge:SetVertexColor(.38, .52, .68, 1)
        elseif purpose == 'link' or readonly then
            edge:SetVertexColor(.35, .6, .63, 1)
        else
            edge:SetVertexColor(.43, .48, .58, 1)
        end
    end

    local scroll
    local edit
    if multiline then
        -- A real scroll frame is necessary for longer descriptions and logs.
        scroll = CreateFrame('ScrollFrame', nil, outer, 'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT', 6, -5)
        scroll:SetPoint('BOTTOMRIGHT', -25, 5)
        edit = CreateFrame('EditBox', nil, scroll)
        edit:SetWidth(width - 37)
        edit:SetHeight(math.max(height - 10, 30))
    else
        -- Single-line title and URL fields must not have scroll arrows.
        edit = CreateFrame('EditBox', nil, outer)
        edit:SetPoint('TOPLEFT', outer, 'TOPLEFT', 7, -4)
        edit:SetPoint('BOTTOMRIGHT', outer, 'BOTTOMRIGHT', -7, 4)
    end
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextColor(1, 1, 1)
    edit:SetMultiLine(multiline)
    -- WoW EditBoxes may otherwise truncate long prefilled GitHub URLs.
    edit:SetMaxLetters(0)
    edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    if not multiline then edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end) end
    if readonly then edit:SetScript('OnTextChanged', function(self, userInput)
        if userInput and self._fixed then self:SetText(self._fixed) end
    end) end
    if multiline then
        edit:SetScript('OnCursorChanged', function()
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end)
        scroll:SetScrollChild(edit)
        edit:HookScript('OnTextChanged', function(self)
            -- Grow the scroll child for long stacktraces / diagnostic reports.
            local value = self:GetText() or ''
            local lines = 0
            for segment in (value .. '\n'):gmatch('(.-)\n') do
                lines = lines + math.max(1, math.ceil(#segment / math.max(25, math.floor((width - 42) / 7))))
            end
            self:SetHeight(math.max(height - 10, (lines + 1) * 16))
        end)
    end
    return outer, edit
end
-- Use an isolated copy dialog instead of selecting text inside the support
-- window. The original edit box can lose focus when other UI handlers run.
-- Keep the copy edit box focused and selected until the dialog is closed.
function CN:ShowSupportCopy(value, caption, isReport)
    if not self.supportCopyWindow then
        local popup = CreateFrame('Frame', 'ElvUICharNotesSupportCopy', UIParent)
        popup:SetPoint('CENTER')
        popup:SetFrameStrata('FULLSCREEN_DIALOG')
        popup:SetFrameLevel(500)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetMovable(true)
        popup:RegisterForDrag('LeftButton')
        popup:SetScript('OnDragStart', popup.StartMoving)
        popup:SetScript('OnDragStop', popup.StopMovingOrSizing)
        popup:Hide()
        self.supportCopyWindow = popup

        local bg = popup:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture('Interface\\Buttons\\WHITE8X8')
        bg:SetVertexColor(.055, .07, .09, .99)
        local heading = text(popup, '', 18, -16)
        local linkField, linkEdit = input(popup, 700, 34, false, true)
        linkField:SetPoint('TOPLEFT', 18, -58)
        local reportField, reportEdit = input(popup, 700, 216, true, true)
        reportField:SetPoint('TOPLEFT', 18, -58)
        local instructions = popup:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        instructions:SetPoint('BOTTOMLEFT', popup, 'BOTTOMLEFT', 18, 50)
        instructions:SetText(L.SUPPORT_COPY_HINT)
        local closeX = CreateFrame('Button', nil, popup, 'UIPanelCloseButton')
        closeX:SetPoint('TOPRIGHT', popup, 'TOPRIGHT', -4, -4)
        closeX:SetScript('OnClick', function() popup:Hide() end)
        local close = CreateFrame('Button', nil, popup, 'UIPanelButtonTemplate')
        close:SetSize(130, 25)
        close:SetPoint('BOTTOMRIGHT', popup, 'BOTTOMRIGHT', -18, 14)
        close:SetText(L.SUPPORT_CLOSE)
        close:SetScript('OnClick', function() popup:Hide() end)

        -- WoW Forever sometimes clears EditBox selection after a mouse click.
        -- Unlike a one-frame HighlightText, this maintains the selection
        -- throughout copy mode. The loop stops completely when the copy
        -- dialog closes. No OS clipboard/API access or keyboard interception.
        local keeper = CreateFrame('Frame', nil, popup)
        keeper:Hide()
        keeper:SetScript('OnUpdate', function(self)
            local target = popup.activeCopyEdit
            if not target or not popup:IsShown() then self:Hide(); return end
            if not target:HasFocus() then target:SetFocus() end
            target:HighlightText(0, #(target:GetText() or ''))
        end)
        popup.copyKeeper = keeper
        popup.linkField, popup.linkEdit = linkField, linkEdit
        popup.reportField, popup.reportEdit = reportField, reportEdit
        popup.heading = heading
        local function escape(self) popup:Hide() end
        linkEdit:SetScript('OnEscapePressed', escape)
        reportEdit:SetScript('OnEscapePressed', escape)
        popup:SetScript('OnHide', function()
            keeper:Hide()
            local target = popup.activeCopyEdit
            popup.activeCopyEdit = nil
            if target then target:ClearFocus() end
        end)
    end
    local popup = self.supportCopyWindow
    local target
    if isReport then
        popup:SetSize(736, 362)
        popup.linkField:Hide()
        popup.reportField:Show()
        target = popup.reportEdit
    else
        popup:SetSize(736, 180)
        popup.reportField:Hide()
        popup.linkField:Show()
        target = popup.linkEdit
    end
    popup.heading:SetText(caption or L.SUPPORT_COPY_HINT)
    -- Store a private snapshot; do not modify the editable support report.
    target._fixed = tostring(value or '')
    target:SetText(target._fixed)
    popup.activeCopyEdit = target
    popup:Show()
    popup:Raise()
    target:SetFocus()
    target:HighlightText(0, #(target:GetText() or ''))
    popup.copyKeeper:Show()
end
local function timestamp(t)
    if type(date) == 'function' then return date('%Y-%m-%d %H:%M:%S', t) end
    return tostring(t or '')
end
function CN:GetSupportLink(kind, title, description)
    kind = templates[kind] and kind or 'bug'
    local url = self.SUPPORT_REPOSITORY .. '/issues/new?template=' .. templates[kind]
    local prefix = prefixes[kind]
    local shortTitle = (title or ''):sub(1, 120)
    if shortTitle ~= '' then
        url = url .. '&title=' .. encode(prefix .. shortTitle) .. '&' .. fields[kind] .. '=' .. encode(shortTitle)
    end
    local sid = self.db and self.db.supportId or ''
    if sid ~= '' then url = url .. '&support-id=' .. encode(sid) end
    -- GitHub's Issue Forms accept query parameters matching field IDs. For
    -- long text / logs prefer the separately selectable report, not a huge URL.
    local target = kind == 'bug' and 'reproduction' or (kind == 'feature' and 'motivation' or 'feedback')
    if description and #description > 0 and #description <= 600 then
        local withDescription = url .. '&' .. target .. '=' .. encode(description)
        if #withDescription < 1600 then url = withDescription end
    end
    return url
end
function CN:BuildSupportReport(kind, title, description, errorIndex)
    local parts = {
        'Title: ' .. tostring(title or ''),
        'Description: ' .. tostring(description or ''),
        '',
        'Addon: Character Notes',
        'Addon version: ' .. tostring(self.VERSION or ''),
        'Support ID: ' .. tostring(self.db and self.db.supportId or ''),
    }
    if type(GetBuildInfo) == 'function' then
        local ok, version, build = pcall(GetBuildInfo)
        if ok and not self:IsSecret(version) and not self:IsSecret(build) then
            parts[#parts+1] = 'WoW version/build: ' .. tostring(version) .. ' / ' .. tostring(build)
        end
    end
    if type(GetLocale) == 'function' then
        local ok, locale = pcall(GetLocale)
        if ok and not self:IsSecret(locale) then parts[#parts+1] = 'Locale: ' .. tostring(locale) end
    end
    if type(UnitClass) == 'function' then
        local ok, _, token = pcall(UnitClass, 'player')
        if ok and not self:IsSecret(token) and type(token) == 'string' then parts[#parts+1] = 'Class: ' .. token end
    end
    if kind == 'bug' then
        local technical = self:GetDiagnosticErrorReport(errorIndex)
        parts[#parts+1] = ''
        parts[#parts+1] = 'Technical log:'
        if technical then
            parts[#parts+1] = technical
        else
            parts[#parts+1] = 'No captured addon error. Recent diagnostic events:'
            local now = type(time) == 'function' and time() or 0
            local rows = {}
            for _, row in ipairs(self:GetDiagnosticLog()) do
                if type(row.at) == 'number' and row.at >= now - 300 then rows[#rows+1] = row end
            end
            parts[#parts+1] = self:FormatDiagnosticContext(rows)
        end
    end
    return table.concat(parts, '\n')
end
function CN:ShowSupport()
    if not self.supportWindow then
        local w = CreateFrame('Frame', 'ElvUICharNotesSupport', UIParent)
        w:SetSize(780, 690)
        w:SetPoint('CENTER')
        -- The main window also uses DIALOG; ensure Support is always above it.
        w:SetFrameStrata('FULLSCREEN_DIALOG')
        w:SetFrameLevel(200)
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', w.StartMoving)
        w:SetScript('OnDragStop', w.StopMovingOrSizing)
        w:SetClampedToScreen(true)
        local bg = w:CreateTexture(nil, 'BACKGROUND')
        bg:SetTexture('Interface\\Buttons\\WHITE8X8')
        bg:SetAllPoints()
        bg:SetVertexColor(.04, .05, .07, 1)
        w:Hide()
        self.supportWindow = w
        -- Distinct panels for user input, editable report preview, and URL.
        section(w, -80, 175, 'entry')
        section(w, -285, 249, 'report')
        section(w, -539, 75, 'link')
        text(w, 'CharNotes - ' .. L.SUPPORT .. ' - v' .. tostring(CN.VERSION or ''), 17, -13)
        -- Standard close control in the title bar, additionally to the bottom button.
        local closeX = CreateFrame('Button', nil, w, 'UIPanelCloseButton')
        closeX:SetPoint('TOPRIGHT', w, 'TOPRIGHT', -4, -3)
        closeX:SetScript('OnClick', function()
            if CN.LogEvent then CN:LogEvent('UI_BUTTON_CLICKED', 'support-close-x') end
            w:Hide()
        end)
        local kind, errorIndex = 'bug', 1
        local titleBox, titleEdit = input(w, 745, 28, false, false, 'entry')
        titleBox:SetPoint('TOPLEFT', 17, -107)
        text(w, L.SUPPORT_TITLE, 22, -88)
        local descriptionBox, descriptionEdit = input(w, 745, 82, true, false, 'entry')
        descriptionBox:SetPoint('TOPLEFT', 17, -166)
        text(w, L.SUPPORT_DESCRIPTION, 22, -147)
        local reportBox, reportEdit = input(w, 745, 210, true, false, 'report')
        reportBox:SetPoint('TOPLEFT', 17, -317)
        text(w, L.SUPPORT_REPORT, 22, -294)
        local linkBox, linkEdit = input(w, 745, 28, false, true, 'link')
        linkBox:SetPoint('TOPLEFT', 17, -566)
        -- Clicking the link opens a focused, isolated copy field as well.
        linkEdit:SetScript('OnMouseUp', function(self, button)
            if button == 'LeftButton' then
                CN:ShowSupportCopy(self:GetText(), L.SUPPORT_SELECT_LINK, false)
            end
        end)
        text(w, L.SUPPORT_LINK, 22, -545)
        local status = text(w, '', 22, -263)
        status:SetWidth(440)
        status:SetJustifyH('LEFT')
        local hint = text(w, L.SUPPORT_HINT, 17, -603)
        hint:SetWidth(745)
        hint:SetJustifyH('LEFT')
        local function redraw()
            local errors = CN.db and CN.db.diagnosticErrors or {}
            if #errors == 0 then errorIndex = 1 end
            if errorIndex > #errors then errorIndex = #errors end
            if errorIndex < 1 then errorIndex = 1 end
            local e = errors[errorIndex]
            if e then
                status:SetText(L.SUPPORT_LAST_ERROR .. ' ' .. errorIndex .. '/' .. #errors .. ' - ' .. timestamp(e.lastAt) .. ' (x' .. tostring(e.count) .. ')')
            else status:SetText(L.SUPPORT_NO_ERRORS) end
            reportEdit:SetText(CN:BuildSupportReport(kind, titleEdit:GetText(), descriptionEdit:GetText(), errorIndex))
            local link = CN:GetSupportLink(kind, titleEdit:GetText(), descriptionEdit:GetText())
            linkEdit._fixed = link
            linkEdit:SetText(link)
            -- Show the beginning of the repository URL rather than its tail.
            if linkEdit.SetCursorPosition then linkEdit:SetCursorPosition(0) end
        end
        local function change(newKind)
            kind = newKind
            redraw()
        end
        action(w, L.SUPPORT_BUG, 17, -43, 190, function() change('bug') end)
        action(w, L.SUPPORT_FEATURE, 215, -43, 190, function() change('feature') end)
        action(w, L.SUPPORT_FEEDBACK, 413, -43, 190, function() change('feedback') end)
        action(w, L.SUPPORT_PREVIOUS, 488, -254, 90, function() errorIndex = errorIndex - 1; redraw() end)
        action(w, L.SUPPORT_NEXT, 585, -254, 82, function() errorIndex = errorIndex + 1; redraw() end)
        local confirm = false
        action(w, L.SUPPORT_CLEAR_SHORT or L.SUPPORT_CLEAR, 674, -254, 89, function()
            if not confirm then confirm = true; status:SetText(L.SUPPORT_CLEAR_CONFIRM); return end
            confirm = false
            CN:ClearDiagnosticLog()
            errorIndex = 1
            redraw()
        end)
        titleEdit:HookScript('OnTextChanged', redraw)
        descriptionEdit:HookScript('OnTextChanged', redraw)
        action(w, L.SUPPORT_SELECT_LINK, 17, -638, 140, function()
            CN:ShowSupportCopy(linkEdit:GetText(), L.SUPPORT_SELECT_LINK, false)
        end)
        action(w, L.SUPPORT_SELECT_REPORT, 163, -638, 150, function()
            CN:ShowSupportCopy(reportEdit:GetText(), L.SUPPORT_SELECT_REPORT, true)
        end)
        action(w, L.SUPPORT_SELECT_ALL, 319, -638, 134, function()
            local all = linkEdit:GetText() .. '\n\n' .. CN:BuildSupportReport(kind, titleEdit:GetText(), descriptionEdit:GetText(), errorIndex)
            CN:ShowSupportCopy(all, L.SUPPORT_SELECT_ALL, true)
        end)
        action(w, L.SUPPORT_CLOSE, 619, -638, 144, function() w:Hide() end)
        w:SetScript('OnHide', function()
            if CN.supportCopyWindow then CN.supportCopyWindow:Hide() end
        end)
        w:SetScript('OnShow', function(self)
            self:SetScale(math.min(1, (UIParent:GetWidth() - 20) / 800, (UIParent:GetHeight() - 20) / 710))
            redraw()
        end)
        redraw()
    end
    self.supportWindow:Show()
    self.supportWindow:Raise()
end

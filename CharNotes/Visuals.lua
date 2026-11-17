local _, CN = ...
local L = CN.L

local frameBorders = setmetatable({}, {__mode = 'k'})
local frameTagIcons = setmetatable({}, {__mode = 'k'})
local frameTagParents = setmetatable({}, {__mode = 'k'})
local tooltipKeys = setmetatable({}, {__mode = 'k'})

local function canUseFrame(frame)
    if CN:IsSecret(frame) then return false end
    local kind = type(frame)
    return (kind == 'table' or kind == 'userdata') and (not frame.IsForbidden or not frame:IsForbidden())
end

local function isUnitToken(unit)
    return not CN:IsSecret(unit) and type(unit) == 'string' and unit ~= ''
end

local function frameUnit(frame)
    local unit = frame.unit
    if isUnitToken(unit) then return unit end
    unit = frame.unitID
    if isUnitToken(unit) then return unit end
    unit = frame.__unit
    if isUnitToken(unit) then return unit end
    if frame.GetAttribute then
        local ok, attribute = pcall(frame.GetAttribute, frame, 'unit')
        if ok and isUnitToken(attribute) then return attribute end
    end
end

local function elvUIUnitFrames()
    local E = CN:GetElvUI()
    if E and type(E.GetModule) == 'function' then
        local ok, module = pcall(E.GetModule, E, 'UnitFrames', true)
        if ok and type(module) == 'table' then return module end
    end
end

local function makeBorder(parent)
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not parent.CreateTexture then return nil end
    local t = {}
    local function line(point1, point2, x1, y1, x2, y2)
        local tex = parent:CreateTexture(nil, 'OVERLAY', nil, 7)
        tex:SetTexture('Interface\\Buttons\\WHITE8X8')
        tex:SetVertexColor(1, .596, .333, 1)
        tex:SetPoint(point1, parent, point1, x1, y1)
        tex:SetPoint(point2, parent, point2, x2, y2)
        return tex
    end
    t[1] = line('TOPLEFT', 'TOPRIGHT', 0, 0, 0, 0)
    t[1]:SetHeight(3)
    t[2] = line('BOTTOMLEFT', 'BOTTOMRIGHT', 0, 0, 0, 0)
    t[2]:SetHeight(3)
    t[3] = line('TOPLEFT', 'BOTTOMLEFT', 0, 0, 0, 0)
    t[3]:SetWidth(3)
    t[4] = line('TOPRIGHT', 'BOTTOMRIGHT', 0, 0, 0, 0)
    t[4]:SetWidth(3)
    frameBorders[parent] = t
    return t
end

local function portraitForFrame(frame)
    local portrait = frame.Portrait or frame.portrait or frame.PortraitTexture
    if portrait then return portrait end
    if frame.GetName then
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == 'string' then return _G[name .. 'Portrait'] end
    end
end

local function tagIconParent(frame)
    -- ElvUI renders its health/power elements above textures created directly
    -- on the unit frame. Its RaisedElementParent is the intended overlay layer.
    local raised = frame.RaisedElementParent
    if canUseFrame(raised) and raised.CreateTexture then return raised end

    -- Blizzard's modern unit frames also contain several child-frame layers.
    -- An anonymous high-level child keeps our textures above that artwork and
    -- follows the unit frame without changing its secure attributes.
    local overlay = frameTagParents[frame]
    if overlay then return overlay end
    if type(CreateFrame) ~= 'function' then return frame end
    overlay = CreateFrame('Frame', nil, frame)
    overlay:SetAllPoints(frame)
    overlay:EnableMouse(false)
    if frame.GetFrameLevel and overlay.SetFrameLevel then
        local ok, level = pcall(frame.GetFrameLevel, frame)
        if ok and not CN:IsSecret(level) and type(level) == 'number' then
            overlay:SetFrameLevel(level + 100)
        end
    end
    frameTagParents[frame] = overlay
    return overlay
end

local function refreshTagIcons(frame, entry, enabled)
    local tags = enabled and CN:TagsForEntry(entry, 'frames') or {}
    local icons = frameTagIcons[frame]
    local locked = InCombatLockdown and InCombatLockdown()
    if #tags > 0 and not icons then
        if locked then return end
        local parent = tagIconParent(frame)
        if not parent.CreateTexture then return end
        icons = {}
        icons.parent = parent
        frameTagIcons[frame] = icons
    end
    if not icons then return end
    local pointOffsets = {}
    for index, tag in ipairs(tags) do
        local icon = icons[index]
        if not icon then
            if locked then break end
            icon = icons.parent:CreateTexture(nil, 'OVERLAY', nil, 7)
            icons[index] = icon
        end
        local point = tag.framePoint or 'TOPRIGHT'
        local size = CN:ValidTagFrameSize(tag.frameSize)
        local offset = pointOffsets[point] or 0
        pointOffsets[point] = offset + size + 1
        local anchor = frame
        if not locked then
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            if point == 'PORTRAIT' then
                anchor = portraitForFrame(frame) or frame
                icon:SetPoint('CENTER', anchor, 'CENTER', offset, 0)
            elseif point == 'TOPLEFT' then
                icon:SetPoint('TOPLEFT', anchor, 'TOPLEFT', offset, 0)
            elseif point == 'BOTTOMLEFT' then
                icon:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', offset, 0)
            elseif point == 'BOTTOMRIGHT' then
                icon:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', -offset, 0)
            else
                icon:SetPoint('TOPRIGHT', anchor, 'TOPRIGHT', -offset, 0)
            end
        end
        icon:SetTexture(tag.icon)
        icon:Show()
    end
    for index = #tags + 1, #icons do icons[index]:Hide() end
end

local chatTagEvents = {
    'CHAT_MSG_SAY', 'CHAT_MSG_YELL', 'CHAT_MSG_GUILD', 'CHAT_MSG_OFFICER',
    'CHAT_MSG_PARTY', 'CHAT_MSG_PARTY_LEADER', 'CHAT_MSG_RAID', 'CHAT_MSG_RAID_LEADER',
    'CHAT_MSG_RAID_WARNING', 'CHAT_MSG_INSTANCE_CHAT', 'CHAT_MSG_INSTANCE_CHAT_LEADER',
    'CHAT_MSG_WHISPER', 'CHAT_MSG_WHISPER_INFORM', 'CHAT_MSG_CHANNEL',
    'CHAT_MSG_EMOTE', 'CHAT_MSG_TEXT_EMOTE',
}

local function chatTagFilter(_, _, message, author, ...)
    if not CN.db or CN:IsSecret(message) or CN:IsSecret(author) or
            type(message) ~= 'string' or type(author) ~= 'string' then return false end
    local key = CN:Normalize(author)
    local entry = key and CN.db.entries[key]
    if not entry or entry.deleted then return false end
    local tags = CN:TagsForEntry(entry, 'chat')
    if #tags == 0 then return false end
    local icons = {}
    for _, tag in ipairs(tags) do
        icons[#icons + 1] = '|T' .. tostring(tag.icon) .. ':16:16|t'
    end
    return false, table.concat(icons, ' ') .. ' ' .. message, author, ...
end

function CN:InitializeChatTags()
    if self.chatTagFilter or type(ChatFrame_AddMessageEventFilter) ~= 'function' then return end
    self.chatTagFilter = chatTagFilter
    for _, event in ipairs(chatTagEvents) do
        pcall(ChatFrame_AddMessageEventFilter, event, chatTagFilter)
    end
end

local function refreshUnitFrame(frame, unit, showTags)
    if not canUseFrame(frame) then return end
    local visible = frame.IsVisible or frame.IsShown
    if not visible then return end
    local ok, shown = pcall(visible, frame)
    if not ok or CN:IsSecret(shown) or not shown then return end
    local resolvedUnit = unit or frameUnit(frame)
    local key = CN:FromUnit(resolvedUnit)
    local entry = key and CN.db.entries[key]
    local shouldShow = CN.db.config.border and entry and not entry.deleted and entry.punk or false
    local overlay = frameBorders[frame]
    if shouldShow and not overlay then overlay = makeBorder(frame) end
    if overlay then
        for _, tex in ipairs(overlay) do tex:SetShown(shouldShow) end
    end
    refreshTagIcons(frame, entry, showTags ~= false and entry and not entry.deleted)
end

function CN:IsPunkUnit(unit)
    if not self.db or not self.db.config.border then return false end
    local key = self:FromUnit(unit)
    local e = key and self.db.entries[key]
    return e and not e.deleted and e.punk or false
end

local function refreshCompactGroup(group)
    if not canUseFrame(group) or type(group.memberUnitFrames) ~= 'table' then return end
    for _, frame in ipairs(group.memberUnitFrames) do refreshUnitFrame(frame) end
end

local function refreshBlizzardFrames()
    refreshUnitFrame(_G.PlayerFrame, 'player')
    refreshUnitFrame(_G.TargetFrame, 'target')
    refreshUnitFrame(_G.FocusFrame, 'focus')
    refreshUnitFrame(_G.TargetFrameToT, 'targettarget')
    local party = _G.PartyFrame
    if canUseFrame(party) then
        for i = 1, 4 do
            refreshUnitFrame(party['MemberFrame' .. i], 'party' .. i)
        end
    end
    refreshCompactGroup(_G.CompactPartyFrame)
    local raid = _G.CompactRaidFrameContainer
    if canUseFrame(raid) and raid.GetChildren then
        for _, frame in ipairs({raid:GetChildren()}) do
            refreshUnitFrame(frame) -- Flat raid layout.
            refreshCompactGroup(frame) -- Grouped raid layout.
        end
    end
end

function CN:RefreshHighlights()
    if not self.db then return end
    refreshBlizzardFrames()
    local UF = elvUIUnitFrames()
    if UF and type(UF.units) == 'table' then
        -- ElvUI stores these frames by their literal unit token. Preserve that
        -- token because current oUF frames expose it primarily as __unit and it
        -- may otherwise be unavailable on protected frames.
        for unit, frame in pairs(UF.units) do
            refreshUnitFrame(frame, isUnitToken(unit) and unit or nil)
        end
    end
    -- Keep explicit fallbacks for ElvUI versions which do not publish units or
    -- populate the table after Character Notes has initialized.
    refreshUnitFrame((UF and UF.player) or _G.ElvUF_Player, 'player')
    refreshUnitFrame(_G.ElvUF_Target, 'target')
    refreshUnitFrame(_G.ElvUF_Focus, 'focus')
    refreshUnitFrame(_G.ElvUF_TargetTarget, 'targettarget')
    refreshUnitFrame(_G.ElvUF_MouseOver, 'mouseover')
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if canUseFrame(plate) then
                local unit = plate.namePlateUnitToken
                if not isUnitToken(unit) then
                    local frame = plate.UnitFrame
                    unit = canUseFrame(frame) and frameUnit(frame) or nil
                end
                refreshUnitFrame(plate, unit, false)
            end
        end
    end
end

-- WoW Forever/12.x: GameTooltip:GetUnit() can return a secret unit token.
-- ElvUI's group-frame OnEnter is a more reliable entry point: the frame's
-- fixed partyN/raidN slot is known to us without inspecting protected values.
-- The *identity* of that unit still has to be accessible; we never bypass
-- a secret UnitName/UnitFullName result.
local groupFrameUnits = setmetatable({}, {__mode = 'k'})

local function groupUnitFromFrame(frame)
    for _ = 1, 7 do
        if not canUseFrame(frame) then return nil end
        local mapped = groupFrameUnits[frame]
        if mapped then return mapped end
        local unit = frameUnit(frame)
        if unit and (unit:match('^party%d+$') or unit:match('^raid%d+$')) then return unit end
        if frame.GetName then
            local ok, name = pcall(frame.GetName, frame)
            if ok and not CN:IsSecret(name) and type(name) == 'string' then
                local index = name:match('^ElvUF_Party(%d+)$')
                if index and tonumber(index) <= 4 then return 'party' .. index end
                index = name:match('^ElvUF_Raid(%d+)$')
                if index and tonumber(index) <= 40 then return 'raid' .. index end
            end
        end
        if not frame.GetParent then return nil end
        local ok, parent = pcall(frame.GetParent, frame)
        if not ok then return nil end
        frame = parent
    end
end

-- Fallback only to *readable* text which is already displayed in a unit
-- tooltip. Do not extract/compare restricted tooltip strings or GUIDs.
local function displayedNameKey(tip)
    if not tip.GetName then return nil end
    local ok, tipName = pcall(tip.GetName, tip)
    if not ok or CN:IsSecret(tipName) or type(tipName) ~= 'string' then return nil end
    local line = _G[tipName .. 'TextLeft1']
    if not line or not line.GetText then return nil end
    local readOK, displayName = pcall(line.GetText, line)
    if not readOK or CN:IsSecret(displayName) or type(displayName) ~= 'string' then return nil end
    -- Strip display-only coloring; reject titles or decorated strings instead
    -- of assuming they belong to a named player.
    displayName = displayName:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    displayName = displayName:match('^%s*(.-)%s*$')
    if not displayName or displayName == '' or displayName:find('[\r\n\t|]') then return nil end
    local key = CN:Normalize(displayName)
    return key
end

local function isUnitTooltip(tip)
    if tip.IsTooltipType and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        local ok, result = pcall(tip.IsTooltipType, tip, Enum.TooltipDataType.Unit)
        if ok and not CN:IsSecret(result) then return result and true or false end
    end
    return true -- Older supported clients do not have IsTooltipType.
end

function CN:TooltipUnit(tip, knownGroupUnit)
    if not self.db or not self.db.config.tooltip or not canUseFrame(tip) or not tip.AddLine then return end
    if not isUnitTooltip(tip) then return end

    local key
    -- The explicit, *literal* party/raid unit from our frame hook takes
    -- precedence over GetUnit() (which may be a secret).
    if knownGroupUnit and not self:IsSecret(knownGroupUnit) then
        key = self:FromUnit(knownGroupUnit)
    end
    if not key and tip.GetUnit then
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if ok and not self:IsSecret(unit) then key = self:FromUnit(unit) end
    end
    if not key and tip.GetOwner then
        local ok, owner = pcall(tip.GetOwner, tip)
        if ok then
            local groupUnit = groupUnitFromFrame(owner)
            if groupUnit then key = self:FromUnit(groupUnit) end
        end
    end
    if not key then key = displayedNameKey(tip) end
    local e = key and self.db.entries[key]
    if not e or e.deleted then return end
    if tooltipKeys[tip] == key then return end
    tooltipKeys[tip] = key
    local ignored = self:IsPlayerIgnored(e.name)
    tip:AddLine('|cffff9855CharNotes' .. (e.punk and '  [PUNK]' or '') .. '|r' ..
        (ignored and '  |cff7fb4ff' .. L.IGNORE_MARKER .. '|r' or ''))
    local tooltipTags = self:TagsForEntry(e, 'tooltip')
    if #tooltipTags > 0 then
        local parts = {}
        for _, tag in ipairs(tooltipTags) do
            parts[#parts + 1] = '|T' .. tag.icon .. ':16:16|t |cffffc56b' .. tag.name .. '|r'
        end
        tip:AddLine(table.concat(parts, '   '), 1, 1, 1, true)
    end
    if e.note and e.note ~= '' then
        tip:AddLine('|cffffffff' .. e.note:sub(1, 420):gsub('|', '||') .. '|r', 1, 1, 1, true)
    end
    tip:Show()
end

function CN:HookGroupFrameTooltips()
    if not self:GetElvUI() then return end
    local UF = elvUIUnitFrames()
    local added = 0
    local function hook(unit, globalName)
        local frame = (UF and UF[unit]) or _G[globalName]
        if not canUseFrame(frame) or groupFrameUnits[frame] or not frame.HookScript then return end
        local ok = pcall(frame.HookScript, frame, 'OnEnter', function()
            -- ElvUI normally sets the unit tooltip in its original OnEnter.
            local tip = _G.GameTooltip
            if not canUseFrame(tip) or not tip.IsShown then return end
            local visible, shown = pcall(tip.IsShown, tip)
            if visible and not CN:IsSecret(shown) and shown then CN:TooltipUnit(tip, unit) end
        end)
        if ok then groupFrameUnits[frame] = unit; added = added + 1 end
    end
    for i = 1, 4 do hook('party' .. i, 'ElvUF_Party' .. i) end
    for i = 1, 40 do hook('raid' .. i, 'ElvUF_Raid' .. i) end
    self.groupTooltipHookCount = (self.groupTooltipHookCount or 0) + added
end

function CN:InitializeVisuals()
    self:InitializeChatTags()
    local t = GameTooltip
    if t then
        local function clearTooltipKey(tip) tooltipKeys[tip] = nil end
        t:HookScript('OnHide', clearTooltipKey)
        pcall(t.HookScript, t, 'OnTooltipCleared', clearTooltipKey)
        if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip) CN:TooltipUnit(tip) end)
        else
            t:HookScript('OnTooltipSetUnit', function(tip) CN:TooltipUnit(tip) end)
        end
    end
    self:HookGroupFrameTooltips()
    local ev = CreateFrame('Frame')
    for _, event in ipairs({'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'UPDATE_MOUSEOVER_UNIT',
        'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'UNIT_NAME_UPDATE', 'PLAYER_REGEN_ENABLED'}) do
        ev:RegisterEvent(event)
    end
    ev:SetScript('OnEvent', function()
        CN:HookGroupFrameTooltips()
        CN:RefreshHighlights()
    end)
    ev.elapsed = 0
    ev.hookElapsed = 0
    ev:SetScript('OnUpdate', function(self, dt)
        self.hookElapsed = self.hookElapsed + dt
        if self.hookElapsed >= 3 then
            self.hookElapsed = 0
            CN:HookGroupFrameTooltips()
        end
        self.elapsed = self.elapsed + dt
        if self.elapsed >= .9 then
            self.elapsed = 0
            CN:RefreshHighlights()
        end
    end)
    self.visualEvents = ev
    self:RefreshHighlights()
end

local ADDON, CN = ...
local L = CN.L
_G.ElvUI_CharNotes = CN
CN.ADDON = ADDON
CN.VERSION = '1.13.4'
CN.COLOR = '|cffff9855'
CN.RESET = '|r'
CN.db = nil
CN.seen = {}
CN.initialized = false

local function trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function CN:Print(s)
    local msg = self.COLOR .. '[CharNotes]|r ' .. tostring(s)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(msg) else print(msg) end
end

function CN:LocalRealm()
    local s = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ''
    return tostring(s):gsub('%s+', '')
end

function CN:Normalize(name)
    if type(name) ~= 'string' then return nil end
    name = trim(name):gsub('^%[', ''):gsub('%]$', '')
    if name == '' or #name > 128 or name:find('[\r\n\t|]') then return nil end
    local char, realm = name:match('^([^%-]+)%-(.+)$')
    if not char then char, realm = name, self:LocalRealm() end
    if not char or char == '' then return nil end
    realm = (realm or ''):gsub('%s+', '')
    local label = char .. (realm ~= '' and '-' .. realm or '')
    return label:lower(), label
end

-- WoW Forever can return restricted/secret unit tokens and names. Addon
-- code must NOT inspect those values; skip the affected unit instead.
-- issecretvalue / canaccessvalue are the official visibility checks.
function CN:IsSecret(value)
    if type(issecretvalue) == 'function' then return issecretvalue(value) end
    if type(canaccessvalue) == 'function' then return not canaccessvalue(value) end
    -- Older client builds don't support secret values; pcall fallbacks below
    -- still prevent an unexpected API error from propagating into WoW.
    return false
end

local function readUnit(self, unit)
    -- Keep secret values out of UnitExists and out of string comparisons.
    if self:IsSecret(unit) then return nil end
    if type(unit) ~= 'string' or unit == '' then return nil end
    if not UnitExists or not UnitIsPlayer then return nil end

    local exists = UnitExists(unit)
    if self:IsSecret(exists) or not exists then return nil end
    local player = UnitIsPlayer(unit)
    if self:IsSecret(player) or not player then return nil end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
        if self:IsSecret(name) or self:IsSecret(realm) then return nil end
    end
    if not name or name == '' then
        if not UnitName then return nil end
        name, realm = UnitName(unit)
        if self:IsSecret(name) or self:IsSecret(realm) then return nil end
    end
    if type(name) ~= 'string' or name == '' then return nil end
    if realm and type(realm) == 'string' and realm ~= '' then
        return self:Normalize(name .. '-' .. realm)
    end
    return self:Normalize(name)
end

function CN:FromUnit(unit)
    -- Defensive fallback for client variants returning a rejected secret
    -- argument before we can inspect it. Never attempt to reveal the secret.
    -- pcall is only for containment, not for bypassing Blizzard restrictions.
    local ok, key, label = pcall(readUnit, self, unit)
    if ok then return key, label end
    return nil
end

function CN:EnsureDB()
    if type(ElvUICharNotesDB) ~= 'table' then ElvUICharNotesDB = {} end
    local d = ElvUICharNotesDB
    self.db = d
    if type(d.generalNotes) ~= 'table' then d.generalNotes = {} end
    if type(d.talentTemplates) ~= 'table' then d.talentTemplates = {} end
    if type(d.entries) ~= 'table' then d.entries = {} end
    if type(d.tags) ~= 'table' then d.tags = {} end
    if type(d.ignored) ~= 'table' then d.ignored = {} end
    if type(d.trusted) ~= 'table' then d.trusted = {} end
    if type(d.inbox) ~= 'table' then d.inbox = {} end
    if type(d.generalInbox) ~= 'table' then d.generalInbox = {} end
    if type(d.config) ~= 'table' then d.config = {} end
    local c = d.config
    if not self.LANGUAGE_LABEL_KEYS[c.language] then c.language = 'client' end
    if type(c.sound) ~= 'boolean' then c.sound = true end
    if type(c.soundChoice) ~= 'string' then c.soundChoice = 'RAID_WARNING' end
    if type(c.popup) ~= 'boolean' then c.popup = true end
    if type(c.border) ~= 'boolean' then c.border = true end
    if type(c.tooltip) ~= 'boolean' then c.tooltip = true end
    if type(c.alertAnyNote) ~= 'boolean' then c.alertAnyNote = false end
    -- Earlier versions could not distinguish their default of false from an
    -- explicit opt-out. Enable the new menu once and retain later choices.
    if c.menuDefaultEnabled130 ~= true or type(c.contextMenus) ~= 'boolean' then
        c.contextMenus = true
        c.menuDefaultEnabled130 = true
    end
    if type(d.node) ~= 'string' or d.node == '' then
        d.node = tostring(time()) .. '-' .. tostring(math.random(10000, 99999))
    end
    self:SanitizeTagDefinitions()
    -- Migrate an unfinished pre-release that used the accidental "pink" name.
    for _, e in pairs(d.entries) do
        if type(e) == 'table' then
            if e.punk == nil then e.punk = (e.pink == true) end
            e.pink = nil
            e.tags = self:NormalizeTagIds(e.tags)
        end
    end
    d.schema = 4
    return d
end

function CN:Get(name)
    local key = self:Normalize(name)
    if not key or not self.db then return nil end
    local e = self.db.entries[key]
    return type(e) == 'table' and not e.deleted and e or nil
end

function CN:Store(name, note, punk, tags)
    local key, label = self:Normalize(name)
    if not key then return false, L.INVALID_CHARACTER end
    if type(note) ~= 'string' then note = '' end
    note = trim(note)
    if #note > 1200 then return false, L.NOTE_TOO_LONG end
    local old = self.db.entries[key]
    if tags == nil and old then tags = old.tags end
    self.db.entries[key] = {
        name = label, note = note, punk = not not punk,
        tags = self:NormalizeTagIds(tags),
        updated = math.max(time(), (old and tonumber(old.updated) or 0) + 1),
        writer = self.db.node, deleted = false,
    }
    self:Changed(key)
    return true
end

function CN:Delete(name)
    local key, label = self:Normalize(name)
    if not key then return false end
    local old = self.db.entries[key]
    self.db.entries[key] = {
        name = label, note = '', punk = false, deleted = true,
        updated = math.max(time(), (old and tonumber(old.updated) or 0) + 1),
        writer = self.db.node,
    }
    self:Changed(key)
    return true
end

function CN:TogglePunk(name)
    local old = self:Get(name)
    local newValue = not (old and old.punk)
    local ok, err = self:Store(name, old and old.note or '', newValue, old and old.tags)
    if ok then self:Print((newValue and L.PUNK_MARKED or L.PUNK_UNMARKED):format(old and old.name or name)) end
    return ok, err
end

local function ignoreCount()
    local api = C_FriendList and C_FriendList.GetNumIgnores
    if type(api) == 'function' then
        local ok, count = pcall(api)
        if ok and type(count) == 'number' then return count end
    end
    if type(GetNumIgnores) == 'function' then
        local ok, count = pcall(GetNumIgnores)
        if ok and type(count) == 'number' then return count end
    end
end

local function ignoreNameAt(index)
    local api = C_FriendList and C_FriendList.GetIgnoreName
    if type(api) == 'function' then
        local ok, name = pcall(api, index)
        if ok and type(name) == 'string' then return name end
    end
    api = C_FriendList and C_FriendList.GetIgnoreInfo
    if type(api) == 'function' then
        local ok, info = pcall(api, index)
        if ok then
            if type(info) == 'string' then return info end
            if type(info) == 'table' then return info.name or info.fullName or info.accountName end
        end
    end
    if type(GetIgnoreName) == 'function' then
        local ok, name = pcall(GetIgnoreName, index)
        if ok and type(name) == 'string' then return name end
    end
end

function CN:FindIgnoredName(name)
    local key = self:Normalize(name)
    if not key then return nil end
    local count = ignoreCount()
    if count ~= nil then
        for index = 1, count do
            local ignoredName = ignoreNameAt(index)
            local ignoredKey = ignoredName and self:Normalize(ignoredName)
            if ignoredKey == key then
                self.db.ignored[key] = ignoredName
                return ignoredName
            end
        end
        self.db.ignored[key] = nil
        return nil
    end
    return self.db and self.db.ignored[key] or nil
end

function CN:IsPlayerIgnored(name)
    return self:FindIgnoredName(name) ~= nil
end

function CN:RefreshIgnoreCache()
    if not self.db then return end
    local count = ignoreCount()
    if count == nil then return end
    local nextIgnored = {}
    for index = 1, count do
        local name = ignoreNameAt(index)
        if name then
            local key, label = self:Normalize(name)
            if key then nextIgnored[key] = label end
        end
    end
    self.db.ignored = nextIgnored
end

function CN:UpdateIgnoreUI()
    if not self.ignoreCheck or not self.nameEdit then return end
    local name = self.nameEdit:GetText()
    self.ignoreCheck:SetChecked(name ~= '' and self:IsPlayerIgnored(name) or false)
end

local function changeIgnore(name, ignored)
    local api
    if ignored then
        api = C_FriendList and C_FriendList.AddIgnore or _G.AddIgnore
    else
        api = C_FriendList and C_FriendList.DelIgnore or _G.DelIgnore
    end
    if type(api) ~= 'function' then return false end
    local ok, result = pcall(api, name)
    return ok and result ~= false
end

function CN:SetPlayerIgnored(name, ignored, silent)
    local key, label = self:Normalize(name)
    if not key then return false, L.INVALID_CHARACTER end
    ignored = not not ignored
    local listedName = self:FindIgnoredName(label)
    if ignored == (listedName ~= nil) then return true, false end
    if not changeIgnore(listedName or label, ignored) then
        if not silent then self:Print(L.IGNORE_UNAVAILABLE) end
        return false, L.IGNORE_UNAVAILABLE
    end
    if ignored then self.db.ignored[key] = label else self.db.ignored[key] = nil end
    if not silent then
        self:Print((ignored and L.IGNORE_ADDED or L.IGNORE_REMOVED):format(label))
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(.4, function()
            CN:RefreshIgnoreCache()
            CN:UpdateIgnoreUI()
            if CN.RefreshList then CN:RefreshList() end
        end)
    end
    return true, true
end

function CN:ToggleIgnore(name)
    local ignored = not self:IsPlayerIgnored(name)
    local ok, err = self:SetPlayerIgnored(name, ignored)
    if ok and ignored and not self:Get(name) then self:Store(name, '', false, {}) end
    return ok, err
end

function CN:Changed(key)
    if self.RefreshList then self:RefreshList() end
    if self.RefreshHighlights then self:RefreshHighlights() end
    -- Do not force re-alert the whole group after each data edit/sync.
    if self.CheckGroup then self:CheckGroup(false) end
end

function CN:EntryList(query)
    local items = {}
    query = (query or ''):lower()
    for key, e in pairs(self.db.entries) do
        local tagMatch = false
        if query ~= '' and type(e) == 'table' then
            for _, tag in ipairs(self:TagsForEntry(e)) do
                if tag.name:lower():find(query, 1, true) then tagMatch = true; break end
            end
        end
        if type(e) == 'table' and not e.deleted and
            (query == '' or key:find(query, 1, true) or (e.note or ''):lower():find(query, 1, true) or tagMatch) then
            items[#items + 1] = e
        end
    end
    table.sort(items, function(a, b)
        if a.punk ~= b.punk then return a.punk end
        return (a.name or ''):lower() < (b.name or ''):lower()
    end)
    return items
end

CN.SOUNDS = {
    {key = 'RAID_WARNING', titleKey = 'SOUND_RAID_WARNING'},
    {key = 'ALARM_CLOCK_WARNING_1', titleKey = 'SOUND_ALARM_CLOCK'},
    {key = 'READY_CHECK', titleKey = 'SOUND_READY_CHECK'},
    {key = 'TELL_MESSAGE', titleKey = 'SOUND_MESSAGE'},
    {key = 'LEVEL_UP', titleKey = 'SOUND_LEVEL_UP', fallbackKey = 'UI_GARRISON_COMMAND_TABLE_FOLLOWER_LEVEL_UP'},
}

function CN:SelectedSound()
    for index, sound in ipairs(self.SOUNDS) do
        if sound.key == self.db.config.soundChoice then return sound, index end
    end
    return self.SOUNDS[1], 1
end

function CN:SetSoundChoice(key)
    self.db.config.soundChoice = key
    self:UpdateSoundUI()
    self:PlayAlertSound(true)
end

function CN:CycleSound()
    local _, index = self:SelectedSound()
    self:SetSoundChoice(self.SOUNDS[(index % #self.SOUNDS) + 1].key)
end

function CN:PlayAlertSound(test)
    if not test and not self.db.config.sound then return end
    local sound = self:SelectedSound()
    local id
    if SOUNDKIT then
        id = SOUNDKIT[sound.key] or (sound.fallbackKey and SOUNDKIT[sound.fallbackKey]) or SOUNDKIT.RAID_WARNING
    end
    if test and not id then self:Print(L.NO_SOUND_KIT) end
    if id and PlaySound then pcall(PlaySound, id, 'Master') end
end

function CN:SetLanguage(language)
    if not self.LANGUAGE_LABEL_KEYS[language] then
        self:Print(L.LANGUAGE_USAGE)
        return false
    end
    self.db.config.language = language
    if self.UpdateLanguageUI then self:UpdateLanguageUI() end
    if self:ResolveLocale(language) ~= self.locale then
        local reload = (C_UI and C_UI.Reload) or ReloadUI
        if type(reload) == 'function' then
            local ok, result = pcall(reload)
            if ok and result ~= false then return true end
        end
        self:Print(L.LANGUAGE_RELOAD_MANUAL)
    end
    return true
end

function CN:SetOption(key, enabled)
    self.db.config[key] = enabled
    if key == 'sound' then
        self:UpdateSoundUI()
    elseif key == 'border' then
        self:RefreshHighlights()
    elseif key == 'contextMenus' then
        local registered = self:RegisterMenus()
        if enabled then
            self:Print(registered and L.MENUS_ENABLED or self.menuState)
        else
            self:Print(L.MENUS_DISABLED)
        end
    end
    local check = self.optionChecks and self.optionChecks[key]
    if check then check:SetChecked(enabled) end
end

function CN:Alert(name, note)
    if self.db.config.popup and self.ShowAlert then self:ShowAlert(name, note) end
    local reason = note ~= '' and L.GROUP_REASON:format(note:sub(1, 180):gsub('|', '||')) or L.MARKED_PLAYER
    self:Print(L.GROUP_WARNING:format(name, reason))
    self:PlayAlertSound(false)
end

function CN:CheckGroup()
    if not self.db then return end
    local now, units = {}, {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do units[#units + 1] = 'raid' .. i end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or
            (GetNumPartyMembers and GetNumPartyMembers()) or 0
        for i = 1, n do units[#units + 1] = 'party' .. i end
    end
    for _, unit in ipairs(units) do
        local key, full = self:FromUnit(unit)
        if key then
            -- UnitIsUnit may also produce secrets/restricted-call errors.
            local ok, isSelf = pcall(function()
                if not UnitIsUnit then return false end
                local value = UnitIsUnit(unit, 'player')
                if self:IsSecret(value) then return nil end
                return value and true or false
            end)
            -- If identity access is restricted, skip this player entirely.
            if ok and isSelf == false then
                now[key] = true
                local e = self.db.entries[key]
                if e and not e.deleted and (e.punk or self.db.config.alertAnyNote) and not self.seen[key] then
                    self:Alert(e.name or full, e.note or '')
                end
            end
        end
    end
    self.seen = now
end

local function isReadableName(self, value)
    return not self:IsSecret(value) and type(value) == 'string' and value ~= ''
end

local function resolveContextSafe(self, data, owner)
    if self:IsSecret(data) then return nil end
    if type(data) == 'table' then
        local _, label = self:FromUnit(data.unit)
        if label then return label end

        -- Blizzard separates Name-Realm into name and surname on UnitPopup.
        local name = data.name
        if not isReadableName(self, name) then name = data.playerName end
        if isReadableName(self, name) then
            if not name:find('-', 1, true) then
                local realm = data.surname
                if self:IsSecret(realm) then return nil end
                if not isReadableName(self, realm) then realm = data.realm end
                if self:IsSecret(realm) then return nil end
                if isReadableName(self, realm) then name = name .. '-' .. realm end
            end
            local _, normalized = self:Normalize(name)
            if normalized then return normalized end
        end

        -- A menu's explicit unit outranks the owner's unit or the current target.
        if self:IsSecret(data.unit) or data.unit ~= nil then return nil end
    end
    if not self:IsSecret(owner) and owner then
        local unit = owner.unit
        if self:IsSecret(unit) then return nil end
        if unit == nil and owner.GetAttribute then
            unit = owner:GetAttribute('unit')
        end
        local _, label = self:FromUnit(unit)
        return label
    end
end

function CN:ResolveContext(data, owner)
    local ok, label = pcall(resolveContextSafe, self, data, owner)
    if ok then return label end
    return nil
end

function CN:Help()
    for _, key in ipairs({
        'HELP_HEADER', 'HELP_MAIN', 'HELP_NOTE', 'HELP_OPTIONS', 'LANGUAGE_USAGE',
        'HELP_TRANSFER', 'HELP_SYNC', 'HELP_GUILD', 'HELP_MISC',
    }) do
        self:Print(L[key])
    end
    self:Print('/cn notes — ' .. L.GENERAL_NOTES .. '   /cn talents — ' .. L.TALENT_PLANNER)
end

function CN:Slash(text)
    text = trim(text or '')
    if text == '' then self:ShowWindow(); return end
    local cmd, rest = text:match('^(%S+)%s*(.-)$')
    cmd = cmd:lower()
    if cmd == 'help' then self:Help()
    elseif cmd == 'notes' then self:ShowNotebook()
    elseif cmd == 'talents' then self:ShowTalentPlanner()
    elseif cmd == 'status' or cmd == 'diag' then self:Status()
    elseif cmd == 'options' then self:ShowOptions()
    elseif cmd == 'tags' then self:ShowWindow(); self:ShowTagManager()
    elseif cmd == 'language' or cmd == 'lang' then self:SetLanguage(rest:lower())
    elseif cmd == 'add' or cmd == 'edit' then
        if rest ~= '' then self:OpenEditor(rest) else self:Print(L.ENTER_CHARACTER) end
    elseif cmd == 'mark' or cmd == 'punk' then
        if rest ~= '' then self:TogglePunk(rest) else self:Print(L.USAGE_PUNK) end
    elseif cmd == 'ignore' then
        if rest ~= '' then self:ToggleIgnore(rest) else self:Print(L.USAGE_IGNORE) end
    elseif cmd == 'note' then
        local who, note = rest:match('^(%S+)%s*|%s*(.*)$')
        if who then
            local e = self:Get(who)
            local ok, err = self:Store(who, note, e and e.punk or false)
            self:Print(ok and L.NOTE_SAVED or err)
        else self:Print(L.USAGE_NOTE) end
    elseif cmd == 'menus' then
        if rest == 'on' or rest == 'off' then
            self:SetOption('contextMenus', rest == 'on')
        else
            self:Print(L.MENUS_STATE:format(self.db.config.contextMenus and L.ON or L.OFF))
        end
    elseif cmd == 'sound' then
        if rest == 'next' then self:CycleSound()
        elseif rest == 'test' then self:PlayAlertSound(true)
        elseif rest == 'on' or rest == 'off' then
            self:SetOption('sound', rest == 'on')
            self:Print(rest == 'on' and L.SOUND_ENABLED or L.SOUND_DISABLED)
        else
            local sound = self:SelectedSound()
            self:Print(L.SOUND_STATE:format(L[sound.titleKey]))
        end
    elseif cmd == 'target' then
        local _, name = self:FromUnit('target')
        if name then self:OpenEditor(name) else self:Print(L.NO_PLAYER_TARGET) end
    elseif cmd == 'export' then self:ShowTransfer(false)
    elseif cmd == 'import' then self:ShowTransfer(true)
    elseif cmd == 'trust' then self:Trust(rest, true)
    elseif cmd == 'untrust' then self:Trust(rest, false)
    elseif cmd == 'peers' then self:ListTrusted()
    elseif cmd == 'sync' then self:StartSync(rest)
    elseif cmd == 'guild' then self:AskShareGuild(rest)
    elseif cmd == 'inbox' then self:ShowGuildInbox()
    elseif cmd == 'accept' then self:AcceptInbox(tonumber(rest))
    elseif cmd == 'reject' then self:RejectInbox(tonumber(rest))
    else self:Help() end
end

-- Forever has the modern WoW event system. PARTY_MEMBERS_CHANGED was removed
-- and can raise an invalid-event error before our OnEvent handler is attached.
CN.events = CreateFrame('Frame')
CN.events:RegisterEvent('ADDON_LOADED')
CN.events:RegisterEvent('PLAYER_LOGIN')
CN.events:RegisterEvent('PLAYER_ENTERING_WORLD')
CN.events:RegisterEvent('GROUP_ROSTER_UPDATE')
pcall(CN.events.RegisterEvent, CN.events, 'IGNORELIST_UPDATE')

CN.startup = CN.startup or {}
local function startPart(id, fn)
    if CN.startup[id] == true then return end
    local ok, err = pcall(fn)
    CN.startup[id] = ok and true or tostring(err)
    if not ok then CN:Print(L.STARTUP_ERROR:format(L['COMPONENT_' .. id], tostring(err))) end
end

function CN:Status()
    local E = self:GetElvUI()
    local menu = _G.Menu and type(_G.Menu.ModifyMenu) == 'function'
    self:Print(L.STATUS_VERSION:format(self.VERSION, E and 'ElvUI' or L.MODE_STANDALONE))
    if E then
        self:Print(L.STATUS_ELVUI:format(self.elvuiPluginState or L.STATUS_NOT_INITIALIZED))
    end
    self:Print(L.STATUS_SECRET_API:format(type(issecretvalue) == 'function' and L.YES or L.NO,
        type(canaccessvalue) == 'function' and L.YES or L.NO))
    self:Print(L.STATUS_MENU_API:format(menu and L.YES or L.NO, self.db and self.db.config.contextMenus and L.ON or L.OFF,
        self.menuHookCount or 0, self.menuState or L.STATUS_NOT_INITIALIZED, self.groupTooltipHookCount or 0))
    if self.notebook then
        self:Print(L.STATUS_COMPONENT:format(L.GENERAL_NOTES,
            self.notebook.nativeNoteEditor and 'InputScrollFrameTemplate' or 'ScrollFrame'))
    end
    for _, id in ipairs({'UI', 'Menus', 'Visuals', 'Sync', 'ElvUI'}) do
        local state = self.startup and self.startup[id]
        if state ~= true and (id ~= 'ElvUI' or E) then
            self:Print(L.STATUS_COMPONENT:format(L['COMPONENT_' .. id], tostring(state or L.STATUS_NOT_INITIALIZED)))
        end
    end
end

local function loadSettings()
    if CN.db then return end
    CN.db = CN:EnsureDB()
    CN:LoadLocale(CN.db.config.language)
end

function CN:FinishInitialize()
    loadSettings()
    if self.initialized then return end
    self.initialized = true
    -- Problems in one integration must not block slash commands or other modules.
    startPart('UI', function() self:InitializeUI() end)
    startPart('Menus', function() self:RegisterMenus() end)
    startPart('Visuals', function() self:InitializeVisuals() end)
    startPart('Sync', function() self:InitializeSync() end)
    if self:GetElvUI() then
        startPart('ElvUI', function() self:InitializeElvUI() end)
    end
    self:Print(L.STARTED:format(self.VERSION))
    self:CheckGroup()
end

CN.events:SetScript('OnEvent', function(_, event, addon)
    if event == 'ADDON_LOADED' then
        if addon == ADDON then
            loadSettings()
        elseif CN.initialized then
            if addon == 'Blizzard_Menu' or addon == 'Blizzard_UnitPopup' or addon == 'Blizzard_UnitPopupShared' then
                CN:RegisterMenus()
            elseif addon == 'ElvUI' then
                startPart('ElvUI', function() CN:InitializeElvUI() end)
            elseif addon == 'ElvUI_Options' then
                CN:TryRegisterElvUIOptions()
            end
        end
        if CN.db and (addon == ADDON or addon == 'Titan') and type(_G.TitanPanelButton_OnLoad) == 'function' then
            startPart('Titan', function() CN:InitializeTitan() end)
        end
    elseif event == 'PLAYER_LOGIN' then
        CN:FinishInitialize()
    elseif CN.initialized and event == 'IGNORELIST_UPDATE' then
        CN:RefreshIgnoreCache()
        CN:UpdateIgnoreUI()
        if CN.RefreshList then CN:RefreshList() end
    elseif CN.initialized and (event == 'PLAYER_ENTERING_WORLD' or event == 'GROUP_ROSTER_UPDATE') then
        CN:CheckGroup()
        if CN.RefreshHighlights then CN:RefreshHighlights() end
    end
end)

SLASH_ELVUICHARNOTES1 = '/cn'
SLASH_ELVUICHARNOTES2 = '/charnotes'
SlashCmdList.ELVUICHARNOTES = function(msg) CN:Slash(msg) end

local _, CN = ...

-- Diagnostic records are metadata only. Never accept note titles, note bodies,
-- player names, chat messages or arbitrary UI labels as event details.
local MAX_EVENTS, MAX_ERRORS = 3000, 20
local DAY, WINDOW = 86400, 300
local allowed = {
    NOTE_SAVED=true, NOTE_DELETED=true, PUNK_TOGGLED=true,
    TAGS_ASSIGNED=true, TAG_CREATED=true, TAG_UPDATED=true, TAG_DELETED=true,
    POINT_ADDED=true, POINT_REMOVED=true, CHOICE_CHANGED=true,
    TALENT_ACTION_BLOCKED=true, TALENTS_RESET=true, CLASS_SELECTED=true,
    UI_BUTTON_CLICKED=true, ADDON_INITIALIZED=true,
}

local function now()
    if type(time) == 'function' then
        local ok, value = pcall(time)
        if ok and type(value) == 'number' then return math.floor(value) end
    end
    return 0
end

local function uuid()
    -- Pseudorandom support ID, not a security credential. Not based on
    -- character/account names, notes, BattleTag or any other identifier.
    local result = {}
    for i=1,16 do result[i] = math.random(0,255) end
    result[7] = (result[7] % 16) + 64 -- RFC 4122 v4
    result[9] = (result[9] % 64) + 128
    local hex = {}
    for i=1,16 do hex[i] = string.format('%02x', result[i]) end
    return table.concat(hex, '', 1, 4) .. '-' .. table.concat(hex, '', 5, 6) .. '-' ..
        table.concat(hex, '', 7, 8) .. '-' .. table.concat(hex, '', 9, 10) .. '-' ..
        table.concat(hex, '', 11, 16)
end

local function prune(log, cutoff, limit)
    if type(log) ~= 'table' then return {} end
    local kept = {}
    for _, row in ipairs(log) do
        if type(row) == 'table' and type(row.at) == 'number' and row.at >= cutoff and
            row.at <= now() + 60 and type(row.event) == 'string' then
            kept[#kept + 1] = row
        end
    end
    while #kept > limit do table.remove(kept, 1) end
    return kept
end

function CN:InitializeSupportLog()
    local d = self.db
    if not d then return end
    if type(d.supportId) ~= 'string' or not d.supportId:match('^[a-f0-9]+%-[a-f0-9]+%-[a-f0-9]+%-[a-f0-9]+%-[a-f0-9]+$') or #d.supportId ~= 36 then
        d.supportId = uuid()
    end
    d.diagnosticLog = prune(d.diagnosticLog, now() - DAY, MAX_EVENTS)
    if type(d.diagnosticErrors) ~= 'table' then d.diagnosticErrors = {} end
    while #d.diagnosticErrors > MAX_ERRORS do table.remove(d.diagnosticErrors, 1) end
end

function CN:LogEvent(event, details)
    if not self.db or not allowed[event] then return end
    if type(details) ~= 'string' or #details > 120 or details:find('[\r\n|]') then details = '' end
    -- Only generated, safe fields are passed by internal call sites.
    local log = self.db.diagnosticLog
    if type(log) ~= 'table' then return end
    log[#log + 1] = {at=now(), event=event, detail=details}
    if #log > MAX_EVENTS or (#log > 1 and log[1].at < now() - DAY) then
        self.db.diagnosticLog = prune(log, now() - DAY, MAX_EVENTS)
    end
end

function CN:GetDiagnosticLog()
    if not self.db then return {} end
    self.db.diagnosticLog = prune(self.db.diagnosticLog, now() - DAY, MAX_EVENTS)
    return self.db.diagnosticLog
end

function CN:ClearDiagnosticLog()
    if not self.db then return end
    self.db.diagnosticLog = {}
    self.db.diagnosticErrors = {}
end

local function recent(self, stamp)
    local rows = {}
    for _, row in ipairs(self:GetDiagnosticLog()) do
        if row.at >= stamp - WINDOW and row.at <= stamp then
            rows[#rows + 1] = {at=row.at, event=row.event, detail=row.detail}
        end
    end
    return rows
end

function CN:RecordDiagnosticError(source, message)
    if not self.db or type(source) ~= 'string' or type(message) ~= 'string' then return end
    local stamp = now()
    -- No locals or user content are introspected. Error text may nonetheless
    -- contain sensitive data supplied by other code: review before publishing.
    local normalized = message:sub(1, 2000)
    local signature = source .. ':' .. normalized:sub(1, 300)
    local errors = self.db.diagnosticErrors
    if type(errors) ~= 'table' then errors = {}; self.db.diagnosticErrors = errors end
    for _, row in ipairs(errors) do
        if row.signature == signature then
            row.lastAt = stamp
            row.count = (tonumber(row.count) or 1) + 1
            row.context = recent(self, stamp)
            return
        end
    end
    errors[#errors + 1] = {
        at=stamp, lastAt=stamp, count=1, source=source, signature=signature,
        message=normalized, context=recent(self, stamp),
        supportId=self.db.supportId,
    }
    while #errors > MAX_ERRORS do table.remove(errors, 1) end
end

function CN:InstallErrorCapture()
    if self._diagnosticHandler or type(geterrorhandler) ~= 'function' or type(seterrorhandler) ~= 'function' then return end
    local previous = geterrorhandler()
    if type(previous) ~= 'function' then return end
    local function handler(message)
        -- Keep other addons' errors out of our SavedVariables.
        if type(message) == 'string' and (message:find('CharNotes/', 1, true) or
                message:find('ElvUI_CharNotes', 1, true)) then
            pcall(CN.RecordDiagnosticError, CN, 'LUA_ERROR', message)
        end
        return previous(message)
    end
    local ok = pcall(seterrorhandler, handler)
    if ok then self._diagnosticHandler = handler end
end

function CN:FormatDiagnosticContext(rows)
    local formatted = {}
    for _, row in ipairs(rows or {}) do
        if type(row) == 'table' then
            local when = type(date) == 'function' and date('%Y-%m-%d %H:%M:%S', row.at) or tostring(row.at)
            formatted[#formatted + 1] = when .. ' | ' .. tostring(row.event) .. ' | ' .. tostring(row.detail or '')
        end
    end
    return table.concat(formatted, '\n')
end

-- Prepares a support-ready technical section; no notes, chats or talent builds.
-- It is NOT sent automatically. Review error text before publication.
function CN:GetDiagnosticErrorReport(index)
    local errorRow = self.db and self.db.diagnosticErrors and self.db.diagnosticErrors[index]
    if type(errorRow) ~= 'table' then return nil end
    local lines = {
        'Addon: Character Notes',
        'Addon version: ' .. tostring(self.VERSION),
        'Support ID: ' .. tostring(self.db.supportId or ''),
        'First occurrence: ' .. tostring(errorRow.at),
        'Last occurrence: ' .. tostring(errorRow.lastAt),
        'Occurrences: ' .. tostring(errorRow.count),
        'Source: ' .. tostring(errorRow.source),
        'Error/stack: ' .. tostring(errorRow.message),
        'Events from five minutes before the latest occurrence:',
        self:FormatDiagnosticContext(errorRow.context),
    }
    if type(GetBuildInfo) == 'function' then
        local ok, version, build = pcall(GetBuildInfo)
        if ok and not self:IsSecret(version) and not self:IsSecret(build) then
            lines[#lines + 1] = 'WoW version/build: ' .. tostring(version) .. ' / ' .. tostring(build)
        end
    end
    if type(GetLocale) == 'function' then
        local ok, locale = pcall(GetLocale)
        if ok and not self:IsSecret(locale) then lines[#lines + 1] = 'Locale: ' .. tostring(locale) end
    end
    return table.concat(lines, '\n')
end

local _, CN = ...
local L = CN.L
local PREFIX = 'CNForever2'
local CHUNK = 175
local MAX_PARTS = 180
local MAX_EXPORT_LINE = 32000

local function hex(s)
    return (s:gsub('.', function(c) return string.format('%02X', string.byte(c)) end))
end

local function unhex(s)
    if type(s) ~= 'string' or #s % 2 ~= 0 or not s:match('^[%x]*$') then return nil end
    return (s:gsub('..', function(c) return string.char(tonumber(c, 16)) end))
end

-- General notes use length-prefixed fields so tabs, newlines and talent data
-- survive addon messages without evaluating data received from other players.
local function field(value)
    value = value or ''
    return tostring(#value) .. ':' .. value
end

local function mapText(values, maxValue)
    local keys, result = {}, {}
    for id, value in pairs(values or {}) do
        if type(id) ~= 'number' or id < 1 or id > 2147483647 or id % 1 ~= 0 or
                type(value) ~= 'number' or value < 1 or value > maxValue or value % 1 ~= 0 then return nil end
        keys[#keys+1] = id
        if #keys > 240 then return nil end
    end
    table.sort(keys)
    for _, id in ipairs(keys) do result[#result+1] = id .. ':' .. values[id] end
    return table.concat(result, ',')
end

local function encodeGeneral(note)
    if type(note) ~= 'table' or type(note.title) ~= 'string' or #note.title < 1 or
            #note.title > 160 or note.title:find('[\r\n]') or type(note.body) ~= 'string' or
            #note.body > 6000 then return nil end
    local build = note.build
    if build and (type(build) ~= 'table' or not CN.talents.spec[build.class] or
            type(build.ranks) ~= 'table' or (build.choices and type(build.choices) ~= 'table')) then return nil end
    local ranks = mapText(build and build.ranks, 100)
    local choices = mapText(build and build.choices, 2147483647)
    if not ranks or not choices then return nil end
    local raw = field(note.title)..field(note.body)..field(build and build.class or '')..
        field(ranks)..field(choices)
    local payload = hex(raw)
    if #payload > CHUNK * MAX_PARTS then return nil end
    return payload
end

local function encodeGeneralMany(note)
    if type(note) ~= 'table' or type(note.title) ~= 'string' or #note.title < 1 or
            #note.title > 160 or note.title:find('[\r\n]') or type(note.body) ~= 'string' or
            #note.body > 6000 then return nil end
    local builds = CN:CopyNoteBuilds(note)
    if not builds then return nil end
    local selected = #builds > 0 and (note.activeBuild or 1) or 0
    if type(selected) ~= 'number' or selected % 1 ~= 0 or selected < 0 or selected > #builds then return nil end
    local fields = {field(note.title),field(note.body),field(tostring(#builds)),field(tostring(selected))}
    for _, entry in ipairs(builds) do
        local ranks = mapText(entry.build.ranks,100)
        local choices = mapText(entry.build.choices,2147483647)
        if not ranks or not choices then return nil end
        fields[#fields+1] = field(entry.name)..field(entry.build.class)..field(ranks)..field(choices)
    end
    local payload = hex(table.concat(fields))
    return #payload <= CHUNK * MAX_PARTS and payload or nil
end

local function decodeGeneralMany(payload)
    local raw = unhex(payload)
    if not raw or #raw > CHUNK * MAX_PARTS / 2 then return nil end
    local pos = 1
    local function read()
        local first, last, digits = raw:find('(%d+):',pos)
        if first ~= pos or not digits or #digits > 5 then return nil end
        local length = tonumber(digits)
        if length > 7000 or last + length > #raw then return nil end
        local value = raw:sub(last+1,last+length)
        pos = last+length+1
        return value
    end
    local function readMap(value,maxValue)
        local result,parts = {},{}
        if value == '' then return result end
        for pair in value:gmatch('[^,]+') do
            local id,number = pair:match('^(%d+):(%d+)$')
            id,number=tonumber(id),tonumber(number)
            if not id or not number or id < 1 or id > 2147483647 or id % 1 ~= 0 or
                    number < 1 or number > maxValue or number % 1 ~= 0 or result[id] then return nil end
            result[id]=number
            parts[#parts+1]=pair
            if #parts > 240 then return nil end
        end
        return table.concat(parts,',') == value and result or nil
    end
    local title,body,countText,selectedText=read(),read(),read(),read()
    if not title or #title < 1 or #title > 160 or title:match('^%s*$') or title:find('[\r\n]') or
            not body or #body > 6000 or not countText or not countText:match('^%d+$') or
            not selectedText or not selectedText:match('^%d+$') then return nil end
    local count,selected=tonumber(countText),tonumber(selectedText)
    if not count or count > CN.MAX_BUILDS_PER_NOTE or not selected or
            selected ~= (count == 0 and 0 or math.floor(selected)) or
            (count > 0 and (selected < 1 or selected > count)) then return nil end
    local builds={}
    for i=1,count do
        local name,class,rankText,choiceText=read(),read(),read(),read()
        if not name or #name < 1 or #name > 60 or name:match('^%s*$') or name:find('[\r\n\t]') or
                not class or not CN.talents.spec[class] or not rankText or not choiceText then return nil end
        local ranks,choices=readMap(rankText,100),readMap(choiceText,2147483647)
        if not ranks or not choices then return nil end
        builds[i]={name=name,build={class=class,ranks=ranks,choices=choices}}
    end
    if pos ~= #raw+1 then return nil end
    return {title=title,body=body,builds=builds,activeBuild=count > 0 and selected or nil}
end

local function decodeGeneral(payload)
    local raw = unhex(payload)
    if not raw or #raw > CHUNK * MAX_PARTS / 2 then return nil end
    local pos = 1
    local function read()
        local first, last, digits = raw:find('(%d+):', pos)
        if first ~= pos or not digits or #digits > 5 then return nil end
        local length = tonumber(digits)
        if length > 7000 or last + length > #raw then return nil end
        local value = raw:sub(last+1, last+length)
        pos = last+length+1
        return value
    end
    local title, body, class, rankText, choiceText = read(), read(), read(), read(), read()
    if not title or #title < 1 or #title > 160 or title:match('^%s*$') or title:find('[\r\n]') or
            not body or #body > 6000 or not class or not rankText or not choiceText or
            pos ~= #raw + 1 then return nil end
    local function readMap(value, maxValue)
        local result, parts = {}, {}
        if value == '' then return result end
        for pair in value:gmatch('[^,]+') do
            local id, number = pair:match('^(%d+):(%d+)$')
            id, number = tonumber(id), tonumber(number)
            if not id or not number or id < 1 or id > 2147483647 or id % 1 ~= 0 or
                    number < 1 or number > maxValue or number % 1 ~= 0 or result[id] then return nil end
            result[id] = number
            parts[#parts+1] = pair
            if #parts > 240 then return nil end
        end
        if table.concat(parts, ',') ~= value then return nil end
        return result
    end
    local ranks, choices = readMap(rankText, 100), readMap(choiceText, 2147483647)
    if not ranks or not choices then return nil end
    if class == '' and rankText == '' and choiceText == '' then
        return {title = title, body = body}
    end
    if not CN.talents.spec[class] then return nil end
    return {title = title, body = body, build = {class = class, ranks = ranks, choices = choices}}
end

local function encodeTags(entry)
    local records = {}
    for _, id in ipairs(entry.tags or {}) do
        local tag = CN.db.tags[id]
        if tag then
            records[#records + 1] = table.concat({id, hex(tag.name), hex(tostring(tag.icon)),
                tag.showTooltip ~= false and '1' or '0', tag.showChat ~= false and '1' or '0',
                tag.showFrames and '1' or '0', tag.framePoint or 'TOPRIGHT',
                tostring(CN:ValidTagFrameSize(tag.frameSize)), tostring(tag.updated or 0), hex(tag.writer or '')}, ',')
        end
    end
    return 'T4:' .. table.concat(records, ';')
end

local function encode(entry, includeTags)
    return hex(table.concat({
        tostring(entry.name or ''), tostring(entry.updated or 0), tostring(entry.writer or ''),
        entry.punk and '1' or '0', entry.deleted and '1' or '0',
        -- Guild shares intentionally omit tags; keep their empty T3 payload so
        -- older CharNotes clients can still review the shared note text.
        includeTags == false and 'T3:' or encodeTags(entry), tostring(entry.note or ''),
    }, '\t'))
end

local function decodeTags(payload)
    if type(payload) ~= 'string' or (payload:sub(1, 3) ~= 'T3:' and payload:sub(1, 3) ~= 'T4:') then return nil end
    local version = payload:sub(1, 2)
    local ids, definitions, seen = {}, {}, {}
    local body = payload:sub(4)
    if body == '' then return ids, definitions end
    for record in body:gmatch('[^;]+') do
        local id, nameHex, iconHex, tooltip, chat, frames, point, frameSize, stamp, writerHex
        if version == 'T4' then
            id, nameHex, iconHex, tooltip, chat, frames, point, frameSize, stamp, writerHex =
                record:match('^([%w_.%-]+),([0-9A-F]*),([0-9A-F]*),([01]),([01]),([01]),([A-Z]+),(%d+),(%d+),([0-9A-F]*)$')
        else
            id, nameHex, iconHex, tooltip, frames, point, stamp, writerHex =
                record:match('^([%w_.%-]+),([0-9A-F]*),([0-9A-F]*),([01]),([01]),([A-Z]+),(%d+),([0-9A-F]*)$')
            chat, frameSize = '1', '18'
        end
        local name, iconText, writer = unhex(nameHex), unhex(iconHex), unhex(writerHex)
        local icon = iconText and iconText:match('^%d+$') and tonumber(iconText) or iconText
        local updated = tonumber(stamp)
        frameSize = tonumber(frameSize)
        if not id or #id > 80 or not name or #name > 40 or name == '' or name:find('[\r\n\t|]') or
                not icon or not CN:IsBlizzardTagIcon(icon) or not writer or #writer > 80 or
                not updated or updated < 0 or updated > time() + 31536000 or
                not frameSize or frameSize < 10 or frameSize > 40 or frameSize ~= math.floor(frameSize) or
                not CN.TAG_FRAME_POINT_KEYS[point] or seen[id] then return nil end
        seen[id] = true
        ids[#ids + 1] = id
        definitions[#definitions + 1] = {id = id, name = name, icon = icon,
            showTooltip = tooltip == '1', showChat = chat == '1', showFrames = frames == '1',
            framePoint = point, frameSize = frameSize, updated = updated, writer = writer}
        if #ids > CN.MAX_TAGS_PER_ENTRY then return nil end
    end
    return ids, definitions
end

local function decode(data)
    local raw = unhex(data)
    if not raw then return nil end
    local name, stamp, writer, punk, deleted, tagPayload, note =
        raw:match('^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(T[34]:[^\t]*)\t(.*)$')
    local tagIds, tagDefinitions
    if tagPayload then
        tagIds, tagDefinitions = decodeTags(tagPayload)
    end
    if not tagIds then
        name, stamp, writer, punk, deleted, note =
            raw:match('^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$')
    end
    if not name then return nil end
    local num = tonumber(stamp)
    if not num or num < 0 or num > time() + 31536000 or num ~= math.floor(num) then return nil end
    if #writer > 80 or writer == '' or writer:find('[\r\n\t|]') then return nil end
    if punk ~= '0' and punk ~= '1' then return nil end
    if deleted ~= '0' and deleted ~= '1' then return nil end
    if #note > 1200 then return nil end
    local key, normalized = CN:Normalize(name)
    if not key then return nil end
    return key, {name = normalized, updated = num, writer = writer, punk = punk == '1',
        deleted = deleted == '1', note = note, tags = tagIds}, tagDefinitions
end

function CN:MergeEntry(key, record, tagDefinitions)
    if type(record) ~= 'table' or not key then return false end
    local old = self.db.entries[key]
    local replace = not old or record.updated > (tonumber(old.updated) or 0) or
        (record.updated == (tonumber(old.updated) or 0) and record.writer > (old.writer or ''))
    if replace then
        if record.tags == nil then record.tags = old and self:CloneTagIds(old.tags) or {}
        else
            self:ImportTagDefinitions(tagDefinitions)
            record.tags = self:NormalizeTagIds(record.tags)
        end
        self.db.entries[key] = record
        self:Changed(key)
        return true
    end
    return false
end

function CN:ExportData()
    local lines = {'CN4'}
    local keys = {}
    for key, e in pairs(self.db.entries) do
        if type(e) == 'table' then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do lines[#lines + 1] = encode(self.db.entries[key]) end
    return table.concat(lines, '\n')
end

function CN:ImportData(data)
    if type(data) ~= 'string' or #data > 8000000 then return nil, L.INVALID_EXPORT end
    data = data:gsub('\r\n', '\n')
    if data:sub(1, 4) ~= 'CN2\n' and data ~= 'CN2' and data:sub(1, 4) ~= 'CN3\n' and data ~= 'CN3' and
            data:sub(1, 4) ~= 'CN4\n' and data ~= 'CN4' then
        return nil, L.INVALID_EXPORT_FORMAT
    end
    local imported, checked = 0, 0
    for line in (data .. '\n'):gmatch('(.-)\n') do
        if line ~= '' and line ~= 'CN2' and line ~= 'CN3' and line ~= 'CN4' then
            checked = checked + 1
            if checked > 8000 or #line > MAX_EXPORT_LINE then return nil, L.IMPORT_LIMIT end
            local key, record, tagDefinitions = decode(line)
            if not key then return nil, L.IMPORT_INVALID_RECORD:format(checked) end
            if self:MergeEntry(key, record, tagDefinitions) then imported = imported + 1 end
        end
    end
    return imported
end

function CN:Trust(name, yes)
    local key, label = self:Normalize(name)
    if not key then self:Print(L.ENTER_CHARACTER); return end
    if yes then self.db.trusted[key] = label else self.db.trusted[key] = nil end
    self:Print((yes and L.SYNC_TRUSTED or L.SYNC_UNTRUSTED):format(label))
end

function CN:ListTrusted()
    local names = {}
    for _, label in pairs(self.db.trusted) do names[#names + 1] = label end
    table.sort(names)
    self:Print(#names > 0 and table.concat(names, ', ') or L.SYNC_NO_PARTNERS)
end

local function dispatch(message, channel, target)
    if C_ChatInfo then
        local send = C_ChatInfo.SendAddonMessageLogged or C_ChatInfo.SendAddonMessage
        if send then return send(PREFIX, message, channel, target) end
    end
    if SendAddonMessage then return SendAddonMessage(PREFIX, message, channel, target) end
    return false
end

function CN:QueueRecord(e, kind, target)
    -- Guild sharing intentionally sends no local tag definitions or assignments.
    -- Trusted sync and explicit export/import retain the complete account data.
    local payload = encode(e, kind ~= 'G')
    local count = math.ceil(#payload / CHUNK)
    if count > MAX_PARTS then return false, L.SYNC_PROTOCOL_LIMIT end
    self.pendingOut = self.pendingOut or {}
    if #self.pendingOut + count > 3000 then return false, L.SYNC_QUEUE_FULL end
    local packetId = tostring(math.random(100000, 999999))
    for i = 1, count do
        local part = payload:sub((i - 1) * CHUNK + 1, i * CHUNK)
        local msg = string.format('%s|%s|%d|%d|%s', kind, packetId, i, count, part)
        self.pendingOut[#self.pendingOut + 1] = {msg = msg, channel = kind == 'G' and 'GUILD' or 'WHISPER', target = target}
    end
    return true, count
end

function CN:ShareGeneralNote(id, channel, target)
    local note = self.db.generalNotes[id]
    if not note then return false, L.GENERAL_NO_SAVED_NOTE end
    if channel == 'GUILD' then
        if not IsInGuild or not IsInGuild() then return false, L.GUILD_NOT_MEMBER end
    elseif channel == 'RAID' then
        if not IsInRaid or not IsInRaid() then return false, L.GENERAL_NOT_IN_RAID end
    elseif channel == 'PARTY' then
        if not IsInGroup or not IsInGroup() or (IsInRaid and IsInRaid()) then
            return false, L.GENERAL_NOT_IN_PARTY
        end
    elseif channel == 'WHISPER' then
        local key, label = self:Normalize(target)
        if not key then return false, L.ENTER_CHARACTER end
        target = label
    else return false, L.GENERAL_INVALID_CHANNEL end
    local builds = self:CopyNoteBuilds(note)
    if not builds then return false, L.INVALID_BUILD end
    -- Keep the original one-build wire format for peers running v1.12.
    local legacy = #builds == 0 or (#builds == 1 and builds[1].name == L.DEFAULT_BUILD:format(1))
    local kind = legacy and 'N' or 'M'
    local payload = legacy and encodeGeneral({title=note.title,body=note.body,
        build=builds[1] and builds[1].build}) or encodeGeneralMany(note)
    if not payload then return false, L.SYNC_PROTOCOL_LIMIT end
    local count = math.ceil(#payload / CHUNK)
    self.pendingOut = self.pendingOut or {}
    if #self.pendingOut + count > 3000 then return false, L.SYNC_QUEUE_FULL end
    local packetId = tostring(math.random(100000,999999))
    for i=1,count do
        self.pendingOut[#self.pendingOut+1] = {
            msg = string.format('%s|%s|%d|%d|%s', kind, packetId, i, count,
                payload:sub((i-1)*CHUNK+1,i*CHUNK)), channel = channel, target = target,
        }
    end
    return true, count
end

function CN:TickOutgoing(elapsed)
    if not self.pendingOut or #self.pendingOut == 0 then return end
    self.sendingElapsed = (self.sendingElapsed or 0) + elapsed
    if self.sendingElapsed < 1.3 then return end
    self.sendingElapsed = 0
    local item = self.pendingOut[1]
    -- pcall makes API changes survivable; throttle codes are retried.
    local ok, result = pcall(dispatch, item.msg, item.channel, item.target)
    if ok and (result == 0 or result == true or result == nil or
        (Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.Success)) then
        table.remove(self.pendingOut, 1)
    elseif not ok or result == 3 or
        (Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.AddonMessageThrottle) then
        -- Retain and retry at the next tick, even for transient C_ChatInfo errors.
    else
        table.remove(self.pendingOut, 1)
        if not self.outgoingErrorPrinted then
            self:Print(L.SYNC_SEND_ERROR:format(tostring(result)))
            self.outgoingErrorPrinted = true
        end
    end
    if #self.pendingOut == 0 then
        self.outgoingErrorPrinted = nil
        self:Print(L.SYNC_SENT)
    end
end

function CN:StartSync(name)
    local key, label = self:Normalize(name)
    if not key or not self.db.trusted[key] then
        self:Print(L.SYNC_TRUST_FIRST)
        return
    end
    local num, chunks = 0, 0
    for _, e in pairs(self.db.entries) do
        if type(e) == 'table' then
            local ok, count = self:QueueRecord(e, 'S', label)
            if not ok then self:Print(count); break end
            num = num + 1
            chunks = chunks + count
        end
    end
    self:Print(L.SYNC_QUEUED:format(label, num, chunks))
end

function CN:AskShareGuild(name)
    local e = self:Get(name)
    if not e then self:Print(L.GUILD_NO_SAVED_NOTE); return end
    if not IsInGuild or not IsInGuild() then self:Print(L.GUILD_NOT_MEMBER); return end
    -- Use our own confirmation frame. Writing StaticPopupDialogs during
    -- PLAYER_LOGIN may taint Blizzard's game-menu logout callbacks.
    if self.ShowGuildSharePrompt then
        self:ShowGuildSharePrompt(e.name)
    else
        self:Print(L.GUILD_CONFIRM_UNAVAILABLE)
    end
end

function CN:ShareGuild(name)
    local e = self:Get(name)
    if not e then self:Print(L.GUILD_NOTE_NOT_FOUND); return end
    if not IsInGuild or not IsInGuild() then self:Print(L.GUILD_NOT_MEMBER); return end
    local ok, count = self:QueueRecord(e, 'G')
    if ok then self:Print(L.GUILD_SHARED:format(e.name, count))
    else self:Print(count) end
end

function CN:ReceivePacket(message, channel, sender)
    if type(message) ~= 'string' or type(sender) ~= 'string' or #message > 255 then return end
    local kind, id, part, count, data = message:match('^([GSNM])|(%d+)|(%d+)|(%d+)|([0-9A-F]+)$')
    if not kind then return end
    local key, senderLabel = self:Normalize(sender)
    if not key then return end
    local myKey = self:FromUnit('player')
    if key == myKey then return end
    if kind == 'N' or kind == 'M' then
        if channel ~= 'WHISPER' and channel ~= 'PARTY' and channel ~= 'RAID' and channel ~= 'GUILD' then return end
        if channel == 'GUILD' and (not IsInGuild or not IsInGuild()) then return end
        if channel == 'PARTY' and (not IsInGroup or not IsInGroup()) then return end
        if channel == 'RAID' and (not IsInRaid or not IsInRaid()) then return end
    elseif kind == 'S' then
        if channel ~= 'WHISPER' or not self.db.trusted[key] then return end
    else
        if channel ~= 'GUILD' or not IsInGuild or not IsInGuild() then return end
    end
    part, count = tonumber(part), tonumber(count)
    if not part or not count or count < 1 or count > MAX_PARTS or part > count or part < 1 or #id > 10 then return end
    self.receiving = self.receiving or {}
    local identifier = kind .. ':' .. channel .. ':' .. key .. ':' .. id
    local cur = self.receiving[identifier]
    if not cur or cur.count ~= count or cur.expires < time() then
        -- Prevent unbounded memory growth if peers stop mid-transfer.
        local size = 0
        for k, r in pairs(self.receiving) do
            if r.expires < time() then self.receiving[k] = nil else size = size + 1 end
        end
        if size > 80 then return end
        cur = {count = count, parts = {}, received = 0, expires = time() + 180,
            sender = senderLabel, kind = kind}
        self.receiving[identifier] = cur
    end
    if not cur.parts[part] then
        cur.parts[part] = data
        cur.received = cur.received + 1
        cur.expires = time() + 180
    end
    if cur.received < cur.count then return end
    self.receiving[identifier] = nil
    local full = table.concat(cur.parts)
    if #full > MAX_EXPORT_LINE then return end
    if kind == 'N' or kind == 'M' then
        local note = kind == 'N' and decodeGeneral(full) or decodeGeneralMany(full)
        if not note then return end
        self.receivedGeneralThrottle = self.receivedGeneralThrottle or {}
        local limit = self.receivedGeneralThrottle[key] or {time = time(), count = 0}
        if time() - limit.time > 60 then limit.time, limit.count = time(), 0 end
        limit.count = limit.count + 1
        self.receivedGeneralThrottle[key] = limit
        if limit.count > 10 then return end
        local inbox = self.db.generalInbox
        if #inbox >= 50 then table.remove(inbox,1) end
        inbox[#inbox+1] = {sender = senderLabel, channel = channel, note = note, received = time()}
        self:Print(L.GENERAL_RECEIVED:format(senderLabel, note.title:gsub('|', '||')))
        if self.RefreshGeneralInbox then self:RefreshGeneralInbox() end
        return
    end
    local entryKey, entry, tagDefinitions = decode(full)
    if not entryKey then return end
    if kind == 'S' then
        if self:MergeEntry(entryKey, entry, tagDefinitions) then self:Print(L.SYNC_UPDATED:format(entry.name)) end
    else
        if entry.deleted then return end -- No tombstones via guild shares.
        entry.tags = entry.tags or {}
        self.receivedGuildThrottle = self.receivedGuildThrottle or {}
        local limit = self.receivedGuildThrottle[key] or {time = time(), count = 0}
        if time() - limit.time > 60 then limit.time, limit.count = time(), 0 end
        limit.count = limit.count + 1
        self.receivedGuildThrottle[key] = limit
        if limit.count > 10 then return end
        local inbox = self.db.inbox
        -- Replace newer proposals from the same author for the same subject.
        for i = #inbox, 1, -1 do
            if inbox[i].sender == senderLabel and inbox[i].key == entryKey then table.remove(inbox, i) end
        end
        if #inbox >= 50 then table.remove(inbox, 1) end
        inbox[#inbox + 1] = {sender = senderLabel, key = entryKey, entry = entry,
            tagDefinitions = tagDefinitions, received = time()}
        self:Print(L.GUILD_RECEIVED:format(senderLabel, entry.name))
        if self.RefreshInbox then self:RefreshInbox() end
    end
end

function CN:AcceptGeneralInbox(index)
    local inbox = self.db.generalInbox
    local item = inbox[index]
    if not item then return false end
    local id, err = self:SaveGeneralNote(nil, item.note.title, item.note.body,
        item.note.builds or item.note.build,item.note.activeBuild)
    if not id then self:Print(err); return false end
    table.remove(inbox,index)
    self:Print(L.GENERAL_ACCEPTED:format(item.note.title))
    if self.notebook and self.notebook.refresh then self.notebook.refresh() end
    if self.RefreshGeneralInbox then self:RefreshGeneralInbox() end
    return true
end

function CN:RejectGeneralInbox(index)
    if not self.db.generalInbox[index] then return false end
    table.remove(self.db.generalInbox,index)
    if self.RefreshGeneralInbox then self:RefreshGeneralInbox() end
    return true
end

function CN:AcceptInbox(index)
    if not index or index < 1 or index > #self.db.inbox then
        self:Print(L.GUILD_INDEX_HELP); return
    end
    local item = table.remove(self.db.inbox, index)
    -- Manual acceptance should apply the explicitly approved copy even if another
    -- local record has a higher timestamp. The edit is local and becomes a new revision.
    local old = self.db.entries[item.key]
    local e = item.entry
    self:ImportTagDefinitions(item.tagDefinitions)
    e.tags = self:NormalizeTagIds(e.tags)
    e.updated = math.max(time(), (old and tonumber(old.updated) or 0) + 1)
    e.writer = self.db.node
    self.db.entries[item.key] = e
    self:Changed(item.key)
    self:Print(L.GUILD_ACCEPTED:format(e.name))
    if self.RefreshInbox then self:RefreshInbox() end
end

function CN:RejectInbox(index)
    if not index or index < 1 or index > #self.db.inbox then
        self:Print(L.GUILD_INDEX_INVALID); return
    end
    table.remove(self.db.inbox, index)
    self:Print(L.GUILD_REJECTED)
    if self.RefreshInbox then self:RefreshInbox() end
end

function CN:InitializeSync()
    -- Do not touch Blizzard's StaticPopupDialogs table at login.
    local ok = false
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        ok = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then ok = RegisterAddonMessagePrefix(PREFIX) end
    if ok == false then self:Print(L.SYNC_UNAVAILABLE) end
    local f = CreateFrame('Frame')
    f:RegisterEvent('CHAT_MSG_ADDON')
    f:SetScript('OnEvent', function(_, _, prefix, msg, channel, sender)
        if prefix == PREFIX then CN:ReceivePacket(msg, channel, sender) end
    end)
    f:SetScript('OnUpdate', function(_, dt) CN:TickOutgoing(dt) end)
    self.syncEvents = f
end

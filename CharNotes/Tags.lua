local _, CN = ...
local L = CN.L

CN.MAX_TAGS_PER_ENTRY = 12
CN.TAG_FRAME_POINTS = {'TOPLEFT', 'TOPRIGHT', 'BOTTOMLEFT', 'BOTTOMRIGHT', 'PORTRAIT'}
CN.TAG_FRAME_SIZES = {12, 14, 16, 18, 20, 24, 28, 32, 36, 40}
CN.TAG_FRAME_POINT_KEYS = {
    TOPLEFT = 'TAG_POSITION_TOPLEFT', TOPRIGHT = 'TAG_POSITION_TOPRIGHT',
    BOTTOMLEFT = 'TAG_POSITION_BOTTOMLEFT', BOTTOMRIGHT = 'TAG_POSITION_BOTTOMRIGHT',
    PORTRAIT = 'TAG_POSITION_PORTRAIT',
}

-- Curated Blizzard-owned fallback textures. The client macro icon APIs extend
-- this catalog when available, without depending on ElvUI or external media.
CN.BLIZZARD_ICONS = {
    {'Interface\\Icons\\INV_Misc_Note_01', 'Note'},
    {'Interface\\Icons\\INV_Misc_QuestionMark', 'Question'},
    {'Interface\\Icons\\INV_Misc_Book_09', 'Book'},
    {'Interface\\Icons\\INV_Letter_15', 'Letter'},
    {'Interface\\Icons\\Ability_DualWield', 'Crossed weapons'},
    {'Interface\\Icons\\Ability_Warrior_BattleShout', 'Battle shout'},
    {'Interface\\Icons\\Ability_Rogue_FeignDeath', 'Skull'},
    {'Interface\\Icons\\Ability_Spy', 'Eye'},
    {'Interface\\Icons\\Ability_Hunter_MarkedForDeath', 'Marked target'},
    {'Interface\\Icons\\Ability_Hunter_SniperShot', 'Target'},
    {'Interface\\Icons\\Spell_Shadow_DeathCoil', 'Shadow skull'},
    {'Interface\\Icons\\Spell_Shadow_ShadowWordPain', 'Shadow face'},
    {'Interface\\Icons\\Spell_Shadow_Possession', 'Possession'},
    {'Interface\\Icons\\Spell_Shadow_Charm', 'Charm'},
    {'Interface\\Icons\\Spell_Holy_PrayerOfHealing', 'Prayer'},
    {'Interface\\Icons\\Spell_Holy_GreaterHeal', 'Healing'},
    {'Interface\\Icons\\Spell_Holy_SealOfProtection', 'Protection'},
    {'Interface\\Icons\\Spell_Holy_BlessingOfStrength', 'Blessing'},
    {'Interface\\Icons\\Spell_Nature_Lightning', 'Lightning'},
    {'Interface\\Icons\\Spell_Nature_StoneClawTotem', 'Shield'},
    {'Interface\\Icons\\Spell_Nature_RavenForm', 'Raven'},
    {'Interface\\Icons\\Spell_Fire_Fire', 'Fire'},
    {'Interface\\Icons\\Spell_Fire_FlameBolt', 'Flame'},
    {'Interface\\Icons\\Spell_Frost_FrostBolt02', 'Frost'},
    {'Interface\\Icons\\Spell_Frost_IceStorm', 'Ice storm'},
    {'Interface\\Icons\\INV_Misc_Coin_01', 'Coin'},
    {'Interface\\Icons\\INV_Misc_Gem_Pearl_04', 'Pearl'},
    {'Interface\\Icons\\INV_Misc_Key_03', 'Key'},
    {'Interface\\Icons\\INV_Misc_Map_01', 'Map'},
    {'Interface\\Icons\\INV_Misc_GroupLooking', 'Group'},
    {'Interface\\Icons\\INV_Misc_Head_Dragon_01', 'Dragon'},
    {'Interface\\Icons\\INV_BannerPVP_01', 'Alliance banner'},
    {'Interface\\Icons\\INV_BannerPVP_02', 'Horde banner'},
    {'Interface\\Icons\\Achievement_General', 'Achievement'},
    {'Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend', 'Friend'},
    {'Interface\\Icons\\Achievement_PVP_A_01', 'Alliance PvP'},
    {'Interface\\Icons\\Achievement_PVP_H_01', 'Horde PvP'},
    {'Interface\\Icons\\Trade_Engineering', 'Engineering'},
    {'Interface\\Icons\\Trade_Alchemy', 'Alchemy'},
    {'Interface\\Icons\\Trade_BlackSmithing', 'Blacksmithing'},
}

local iconSet = {}
for _, item in ipairs(CN.BLIZZARD_ICONS) do iconSet[item[1]] = true end
local iconCatalog
local iconLabels = {}

local function addCatalogIcon(result, seen, icon, label)
    if (type(icon) == 'number' and icon > 0 or type(icon) == 'string' and icon ~= '') and not seen[icon] then
        seen[icon] = true
        result[#result + 1] = icon
        iconLabels[icon] = label or tostring(icon)
        iconSet[icon] = true
    end
end


function CN:GetBlizzardIconName(icon)
    self:GetBlizzardIconCatalog()
    return iconLabels[icon] or tostring(icon)
end

function CN:GetBlizzardIconCatalog()
    if iconCatalog then return iconCatalog end
    local result, seen = {}, {}
    for _, item in ipairs(self.BLIZZARD_ICONS) do addCatalogIcon(result, seen, item[1], item[2]) end
    local function collect(api)
        if type(api) ~= 'function' then return end
        local values = {}
        local ok, returned = pcall(api, values)
        if not ok then return end
        if type(returned) == 'table' then values = returned end
        for _, icon in ipairs(values) do addCatalogIcon(result, seen, icon) end
    end
    collect(GetMacroIcons)
    collect(GetMacroItemIcons)
    iconCatalog = result
    return result
end

function CN:FilterBlizzardIcons(query)
    local catalog = self:GetBlizzardIconCatalog()
    query = type(query) == 'string' and query:lower():gsub('^%s+', ''):gsub('%s+$', '') or ''
    if query == '' then return catalog end
    local result = {}
    for _, icon in ipairs(catalog) do
        local identifier = tostring(icon):lower()
        local label = self:GetBlizzardIconName(icon):lower()
        if identifier:find(query, 1, true) or label:find(query, 1, true) then
            result[#result + 1] = icon
        end
    end
    return result
end

local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or #name > 40 or name:find('[\r\n\t|]') then return nil end
    return name
end

local function validPoint(point)
    return CN.TAG_FRAME_POINT_KEYS[point] and point or 'TOPRIGHT'
end

local function validFrameSize(size)
    size = tonumber(size)
    if not size then return 18 end
    size = math.floor(size + .5)
    if size < 10 then return 10 end
    if size > 40 then return 40 end
    return size
end

function CN:ValidTagFrameSize(size)
    return validFrameSize(size)
end

function CN:IsBlizzardTagIcon(icon)
    self:GetBlizzardIconCatalog()
    return (type(icon) == 'string' or type(icon) == 'number') and iconSet[icon] == true
end

function CN:NormalizeTagIds(tags)
    local result, seen = {}, {}
    if type(tags) ~= 'table' then return result end
    for key, value in pairs(tags) do
        local id = type(key) == 'number' and value or (value and key or nil)
        if type(id) == 'string' and self.db and self.db.tags[id] and not seen[id] then
            seen[id] = true
            result[#result + 1] = id
            if #result >= self.MAX_TAGS_PER_ENTRY then break end
        end
    end
    table.sort(result)
    return result
end

function CN:CloneTagIds(tags)
    local result = {}
    for _, id in ipairs(tags or {}) do result[#result + 1] = id end
    return result
end

function CN:SetEntryTags(name, tags)
    local key = self:Normalize(name)
    local entry = key and self.db and self.db.entries[key]
    if type(entry) ~= 'table' or entry.deleted then return false end

    local normalized = self:NormalizeTagIds(tags)
    local unchanged = #normalized == #(entry.tags or {})
    if unchanged then
        for index, id in ipairs(normalized) do
            if entry.tags[index] ~= id then unchanged = false; break end
        end
    end
    if unchanged then return true end

    entry.tags = normalized
    if self.LogEvent then self:LogEvent('TAGS_ASSIGNED', 'count=' .. tostring(#normalized)) end
    entry.updated = math.max(time(), (tonumber(entry.updated) or 0) + 1)
    entry.writer = self.db.node
    self:Changed(key)
    return true
end

function CN:SanitizeTagDefinitions()
    local tags = self.db and self.db.tags
    if type(tags) ~= 'table' then return end
    for id, tag in pairs(tags) do
        if type(id) ~= 'string' or #id > 80 or not id:match('^[%w_.%-]+$') or type(tag) ~= 'table' then
            tags[id] = nil
        else
            tag.name = cleanName(tag.name)
            if not tag.name then tags[id] = nil
            else
                tag.id = id
                if not self:IsBlizzardTagIcon(tag.icon) then tag.icon = self.BLIZZARD_ICONS[1][1] end
                tag.showTooltip = tag.showTooltip ~= false
                tag.showChat = tag.showChat ~= false
                tag.showFrames = tag.showFrames == true
                tag.framePoint = validPoint(tag.framePoint)
                tag.frameSize = validFrameSize(tag.frameSize)
                tag.updated = tonumber(tag.updated) or 0
                tag.writer = type(tag.writer) == 'string' and tag.writer or self.db.node
            end
        end
    end
end

function CN:TagsForEntry(entry, target)
    local result = {}
    if type(entry) ~= 'table' then return result end
    for _, id in ipairs(entry.tags or {}) do
        local tag = self.db and self.db.tags[id]
        if tag and (target == nil or (target == 'tooltip' and tag.showTooltip) or
                (target == 'chat' and tag.showChat) or (target == 'frames' and tag.showFrames)) then
            result[#result + 1] = tag
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

function CN:TagDefinitions()
    local result = {}
    for _, tag in pairs(self.db.tags) do result[#result + 1] = tag end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

local function duplicateName(self, name, exceptId)
    for id, tag in pairs(self.db.tags) do
        if id ~= exceptId and tag.name:lower() == name:lower() then return true end
    end
    return false
end

local function touchEntries(self, id, remove)
    local changed = false
    for key, entry in pairs(self.db.entries) do
        if type(entry) == 'table' and not entry.deleted then
            local found, nextTags = false, {}
            for _, tagId in ipairs(entry.tags or {}) do
                if tagId == id then found = true elseif not remove then nextTags[#nextTags + 1] = tagId end
            end
            if found then
                if remove then entry.tags = nextTags end
                entry.updated = math.max(time(), (tonumber(entry.updated) or 0) + 1)
                entry.writer = self.db.node
                changed = key
            end
        end
    end
    if changed then self:Changed(changed) end
end

function CN:CreateTag(name, icon, showTooltip, showChat, showFrames, framePoint, frameSize)
    name = cleanName(name)
    if not name then return nil, L.TAG_NAME_INVALID end
    if duplicateName(self, name) then return nil, L.TAG_NAME_DUPLICATE end
    if not self:IsBlizzardTagIcon(icon) then icon = self.BLIZZARD_ICONS[1][1] end
    local id
    repeat
        self.db.tagSequence = (tonumber(self.db.tagSequence) or 0) + 1
        id = self.db.node .. '-' .. tostring(self.db.tagSequence)
    until not self.db.tags[id]
    self.db.tags[id] = {id = id, name = name, icon = icon, showTooltip = showTooltip ~= false,
        showChat = showChat ~= false, showFrames = showFrames == true, framePoint = validPoint(framePoint),
        frameSize = validFrameSize(frameSize), updated = time(), writer = self.db.node}
    if self.LogEvent then self:LogEvent('TAG_CREATED', 'definition') end
    return id
end

function CN:UpdateTag(id, name, icon, showTooltip, showChat, showFrames, framePoint, frameSize)
    local tag = self.db.tags[id]
    name = cleanName(name)
    if not tag then return false, L.TAG_NOT_FOUND end
    if not name then return false, L.TAG_NAME_INVALID end
    if duplicateName(self, name, id) then return false, L.TAG_NAME_DUPLICATE end
    if not self:IsBlizzardTagIcon(icon) then return false, L.TAG_ICON_INVALID end
    tag.name, tag.icon = name, icon
    tag.showTooltip, tag.showChat, tag.showFrames = showTooltip ~= false, showChat ~= false, showFrames == true
    tag.framePoint = validPoint(framePoint)
    tag.frameSize = validFrameSize(frameSize)
    tag.updated, tag.writer = math.max(time(), (tag.updated or 0) + 1), self.db.node
    if self.LogEvent then self:LogEvent('TAG_UPDATED', 'definition') end
    touchEntries(self, id, false)
    if self.RefreshTagManager then self:RefreshTagManager(id) end
    return true
end

function CN:DeleteTag(id)
    if not self.db.tags[id] then return false end
    self.db.tags[id] = nil
    if self.LogEvent then self:LogEvent('TAG_DELETED', 'definition') end
    touchEntries(self, id, true)
    return true
end

function CN:ImportTagDefinitions(definitions)
    for _, incoming in ipairs(definitions or {}) do
        if type(incoming) == 'table' and type(incoming.id) == 'string' and incoming.id:match('^[%w_.%-]+$') and
                #incoming.id <= 80 and cleanName(incoming.name) and self:IsBlizzardTagIcon(incoming.icon) then
            local old = self.db.tags[incoming.id]
            local replace = not old or (tonumber(incoming.updated) or 0) > (tonumber(old.updated) or 0) or
                (incoming.updated == old.updated and (incoming.writer or '') > (old.writer or ''))
            if replace then
                self.db.tags[incoming.id] = {id = incoming.id, name = cleanName(incoming.name), icon = incoming.icon,
                    showTooltip = incoming.showTooltip ~= false, showChat = incoming.showChat ~= false,
                    showFrames = incoming.showFrames == true, framePoint = validPoint(incoming.framePoint),
                    frameSize = validFrameSize(incoming.frameSize), updated = tonumber(incoming.updated) or 0,
                    writer = type(incoming.writer) == 'string' and incoming.writer or ''}
            end
        end
    end
end

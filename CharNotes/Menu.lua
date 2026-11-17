local _, CN = ...
local L = CN.L

-- UnitPopup tags used by Blizzard and supported ElvUI unit frames.
local playerMenus = {
    'SELF', 'PLAYER', 'ENEMY_PLAYER', 'PARTY', 'RAID_PLAYER', 'RAID', 'TARGET', 'FOCUS',
    'FRIEND', 'FRIEND_OFFLINE', 'GUILD', 'GUILD_OFFLINE', 'CHAT_ROSTER',
    'COMMUNITIES_WOW_MEMBER', 'COMMUNITIES_GUILD_MEMBER',
}
local registrations = {}
local decorated = setmetatable({}, {__mode = 'k'})

local function enabled()
    return CN.db and CN.db.config.contextMenus
end

local function runAction(action, name)
    if not enabled() then return end
    if name then
        action(CN, name)
    else
        CN:Print(L.MENU_IDENTITY_UNAVAILABLE)
    end
end

local function addEntries(root, name)
    if not enabled() or not root or type(root.CreateButton) ~= 'function' or decorated[root] then return end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(CN.COLOR .. L.ADD_NOTE .. CN.RESET, function() runAction(CN.OpenEditor, name) end)
    root:CreateButton(CN.COLOR .. L.TOGGLE_PUNK .. CN.RESET, function() runAction(CN.TogglePunk, name) end)
    root:CreateButton(CN.COLOR .. (CN:IsPlayerIgnored(name) and L.REMOVE_IGNORE or L.ADD_IGNORE) .. CN.RESET,
        function() runAction(CN.ToggleIgnore, name) end)
    decorated[root] = true
end

local function buildPlayerMenu(owner, root, data)
    if not enabled() then return end
    -- Keep the identity from this menu even if the target changes before clicking.
    addEntries(root, CN:ResolveContext(data, owner))
end

local function buildUnitMenu(_, root, data)
    if not enabled() or CN:IsSecret(data) or type(data) ~= 'table' then return end
    -- Generic target and focus menus also open for NPCs.
    local _, name = CN:FromUnit(data.unit)
    if name then addEntries(root, name) end
end

function CN:RegisterMenus()
    if not enabled() then
        for tag, handle in pairs(registrations) do
            if type(handle) == 'table' and type(handle.Unregister) == 'function' then
                if pcall(handle.Unregister, handle) then registrations[tag] = nil end
            end
        end
        self.menuHookCount = 0
        self.menuState = L.OFF
        return false
    end

    local menu = _G.Menu
    if not menu or type(menu.ModifyMenu) ~= 'function' then
        self.menuHookCount = 0
        self.menuState = L.MENUS_WAITING
        return false
    end

    local count, lastError = 0
    for _, which in ipairs(playerMenus) do
        local tag = 'MENU_UNIT_' .. which
        if not registrations[tag] then
            local builder = (which == 'TARGET' or which == 'FOCUS') and buildUnitMenu or buildPlayerMenu
            local ok, result = pcall(menu.ModifyMenu, tag, builder)
            if ok then
                registrations[tag] = result or true
            else
                lastError = result
            end
        end
        if registrations[tag] then count = count + 1 end
    end
    self.menuHookCount = count
    self.menuState = lastError and L.MENUS_ERROR:format(tostring(lastError)) or L.MENUS_REGISTERED
    return count > 0
end

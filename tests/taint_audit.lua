-- Static taint regression checks for Character Notes Alerts.
-- These checks inspect source text; they do not replace live WoW Forever tests.

local sourceFiles = {
    'CharNotes/Strings.lua',
    'CharNotes/Core.lua',
    'CharNotes/Tags.lua',
    'CharNotes/UI.lua',
    'CharNotes/Menu.lua',
    'CharNotes/Visuals.lua',
    'CharNotes/Sync.lua',
    'CharNotes/ElvUI.lua',
    'CharNotes/Titan.lua',
}

local function read(path)
    local handle, err = io.open(path, 'rb')
    assert(handle, path .. ': ' .. tostring(err))
    local contents = handle:read('*a')
    handle:close()
    return contents
end

local sources = {}
local combined = {}
for _, path in ipairs(sourceFiles) do
    sources[path] = read(path)
    combined[#combined + 1] = sources[path]
end
combined = table.concat(combined, '\n')

local function assertNotFound(pattern, description)
    assert(not combined:find(pattern), description)
end

-- Shared Blizzard registries and protected entry points must not be assigned.
assertNotFound('StaticPopupDialogs%s*[%[%.][^\n]-=', 'mutates Blizzard StaticPopupDialogs')
assertNotFound('_G%.StaticPopupDialogs%s*=', 'replaces Blizzard StaticPopupDialogs')
assertNotFound('StaticPopupDialogs%s*=', 'replaces Blizzard StaticPopupDialogs')

local protectedFunctions = {
    'CloseAllWindows', 'CloseSpecialWindows', 'ShowUIPanel', 'HideUIPanel',
    'ToggleGameMenu', 'UseContainerItem', 'SplitContainerItem',
    'PickupContainerItem', 'BuyGuildBankTab',
}
for _, name in ipairs(protectedFunctions) do
    assertNotFound('function%s+' .. name .. '%s*%(', 'replaces protected function ' .. name)
    assertNotFound(name .. '%s*=%s*function', 'assigns protected function ' .. name)
    assertNotFound('_G%.' .. name .. '%s*=', 'assigns protected global ' .. name)
end

local protectedCalls = {
    'UseContainerItem', 'SplitContainerItem', 'PickupContainerItem', 'BuyGuildBankTab',
}
for _, name in ipairs(protectedCalls) do
    assertNotFound('[^%w_]' .. name .. '%s*%(', 'calls unrelated protected action ' .. name)
end

assertNotFound('SecureActionButtonTemplate', 'creates secure action buttons')
assertNotFound('GameMenuFrame%s*:%s*SetScript', 'overwrites the game menu handler')
assertNotFound('GameMenuButtonLogout%s*:%s*SetScript', 'overwrites the logout handler')
assertNotFound('GameMenuButtonQuit%s*:%s*SetScript', 'overwrites the quit handler')

local ui = sources['CharNotes/UI.lua']
local sync = sources['CharNotes/Sync.lua']
local menu = sources['CharNotes/Menu.lua']
local visuals = sources['CharNotes/Visuals.lua']

assert(ui:find("CreateFrame%('Frame', nil, UIParent%)"), 'addon-owned confirmation frame missing')
assert(ui:find('pendingGuildShareName%s*=%s*nil'), 'confirmation state is not cleared')
assert(ui:find("EventRegistry:RegisterCallback%('GameMenuFrame%.Shown'"),
    'addon dialogs are not closed when the game menu opens')
assert(sync:find('self:ShowGuildSharePrompt%(e%.name%)'), 'guild sharing does not request confirmation')

local askStart = assert(sync:find('function CN:AskShareGuild'))
local askEnd = assert(sync:find('\nend', askStart))
local askBody = sync:sub(askStart, askEnd)
assert(not askBody:find('self:ShareGuild%s*%('), 'guild share bypasses confirmation')

assert(menu:find('menu%.ModifyMenu'), 'context menus do not use the additive menu API')
assert(not menu:find('UIDropDownMenu'), 'legacy shared dropdown tables are modified')
assert(visuals:find('InCombatLockdown%s+and%s+InCombatLockdown%(%)'),
    'protected unit-frame decoration lacks a combat guard')
assert(visuals:find('overlay:EnableMouse%(false%)'), 'unit-frame overlay can capture clicks')
assert(visuals:find('frame%.HookScript'), 'unit-frame tooltip integration is not a post-hook')
assert(not visuals:find('frame:SetScript'), 'unit-frame handler is overwritten')

print('taint_audit.lua: ok')

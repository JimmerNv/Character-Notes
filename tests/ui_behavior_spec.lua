-- Mock behavior tests for Character Notes Alerts.
-- This is not an in-game WoW Forever integration test.

local function noop() end

local function region()
    return setmetatable({text = ''}, {
        __index = function(_, key)
            if key == 'GetText' then return function(self) return self.text end end
            if key == 'SetText' then return function(self, value) self.text = value end end
            return noop
        end,
    })
end

local function frame(kind, name, parent)
    local value = {
        kind = kind,
        name = name,
        parent = parent,
        children = {},
        scripts = {},
        shown = true,
        text = '',
    }
    function value:RegisterEvent() end
    function value:SetScript(event, callback) self.scripts[event] = callback end
    function value:HookScript(event, callback) self.scripts[event] = callback end
    function value:CreateTexture() return region() end
    function value:CreateFontString() return region() end
    function value:SetFontString(fontString) self.fontString = fontString end
    function value:SetText(text) self.text = text end
    function value:GetText() return self.text end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:IsShown() return self.shown end
    function value:Raise() end
    function value:SetSize() end
    function value:SetPoint() end
    function value:SetFrameStrata() end
    function value:EnableMouse() end
    function value:RegisterForDrag() end
    if parent and parent.children then parent.children[#parent.children + 1] = value end
    return value
end

CreateFrame = frame
UIParent = frame('Frame', 'UIParent')
SlashCmdList = {}
GetLocale = function() return 'enUS' end
GetNormalizedRealmName = function() return 'Moon Guard' end
time = function() return 1000 end
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
STANDARD_TEXT_FONT = 'Fonts\\FRIZQT__.TTF'
ChatFontNormal = {}
IsInGuild = function() return true end
UnitExists = function() return true end
UnitIsPlayer = function() return true end
UnitFullName = function() return 'Alice', 'Moon Guard' end
UnitName = UnitFullName
issecretvalue = function() return false end
C_FriendList = {}

local timers = {}
C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
}

local cn = {}
assert(loadfile('CharNotes/Strings.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Core.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Tags.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Sync.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/UI.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Menu.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Visuals.lua'))('CharNotes', cn)
cn.GetElvUI = function() return nil end

local preserved = {
    name = 'Existing-MoonGuard', note = 'Keep me', punk = false,
    tags = {}, updated = 10, writer = 'old-node', deleted = false,
}
ElvUICharNotesDB = {entries = {['existing-moonguard'] = preserved}, config = {}}
cn.db = cn:EnsureDB()
assert(cn.db.entries['existing-moonguard'] == preserved, 'saved note was replaced during migration')

assert(cn:Store('Alice', 'Reliable tank', false, {}))
assert(cn:Get('Alice').note == 'Reliable tank')
assert(cn:Store('Alice', 'Updated note', true, {}))
assert(cn:Get('Alice').note == 'Updated note' and cn:Get('Alice').punk == true)
assert(cn:Delete('Alice'))
assert(cn:Get('Alice') == nil)
assert(cn:Store('Alice', 'Reliable tank', false, {}))

-- The standalone confirmation must not share on cancellation.
local shares = {}
cn.ShareGuild = function(self, name)
    assert(self.pendingGuildShareName == nil, 'confirmation state was not cleared before sharing')
    shares[#shares + 1] = name
end
cn:ShowGuildSharePrompt('Alice-MoonGuard')
local prompt = assert(cn.guildShareConfirm)
local shareButton, cancelButton
for _, child in ipairs(prompt.children) do
    if child.text == cn.L.SHARE then shareButton = child end
    if child.text == cn.L.CANCEL then cancelButton = child end
end
assert(shareButton and cancelButton, 'confirmation buttons missing')
cancelButton.scripts.OnClick()
assert(#shares == 0, 'cancel executed the confirmed action')
assert(cn.pendingGuildShareName == nil, 'cancel left pending confirmation state')

cn:ShowGuildSharePrompt('Alice-MoonGuard')
shareButton.scripts.OnClick()
assert(#shares == 1 and shares[1] == 'Alice-MoonGuard', 'accept did not execute once')
assert(cn.pendingGuildShareName == nil, 'accept left pending confirmation state')

-- AskShareGuild must open the prompt instead of sending directly.
local prompted
cn.ShowGuildSharePrompt = function(_, name) prompted = name end
cn.ShareGuild = function() error('AskShareGuild bypassed confirmation') end
cn:AskShareGuild('Alice')
assert(prompted == 'Alice-MoonGuard')

-- Alert windows open and close through the addon-owned frame.
cn.alert = frame('Frame')
cn.alertName = region()
cn.alertReason = region()
cn:ShowAlert('Alice-MoonGuard', 'Reliable tank')
assert(cn.alert.shown and cn.alertName.text == 'Alice-MoonGuard')
assert(#timers > 0)
timers[#timers]()
assert(not cn.alert.shown, 'alert timer did not close the warning')

-- Sound configuration remains functional.
local played
SOUNDKIT = {RAID_WARNING = 42}
PlaySound = function(id, channel) played = {id, channel} end
cn.db.config.sound = true
cn.db.config.soundChoice = 'RAID_WARNING'
cn:PlayAlertSound(true)
assert(played and played[1] == 42 and played[2] == 'Master')

-- Context menu registration is additive and callbacks still work.
local builders = {}
Menu = {
    ModifyMenu = function(tag, builder)
        builders[tag] = builder
        return {Unregister = function() builders[tag] = nil end}
    end,
}
cn.db.config.contextMenus = true
assert(cn:RegisterMenus())
local root = {buttons = {}}
function root:CreateDivider() self.divider = true end
function root:CreateButton(text, callback)
    self.buttons[#self.buttons + 1] = {text = text, callback = callback}
end
local opened
cn.OpenEditor = function(_, name) opened = name end
assert(builders.MENU_UNIT_TARGET)
builders.MENU_UNIT_TARGET(nil, root, {unit = 'target'})
assert(root.divider and #root.buttons == 3)
root.buttons[1].callback()
assert(opened == 'Alice-MoonGuard')

-- Tooltip notes and tags remain additive.
local tooltip = {lines = {}, shown = false}
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() self.shown = true end
cn.db.config.tooltip = true
cn:TooltipUnit(tooltip, 'target')
assert(tooltip.shown and #tooltip.lines >= 2)
assert(tooltip.lines[1]:find('CharNotes', 1, true))
assert(tooltip.lines[#tooltip.lines]:find('Reliable tank', 1, true))

print('ui_behavior_spec.lua: ok')

local eventFilters = {}
local ignored = {}

local function frame()
  return {
    RegisterEvent = function() end,
    SetScript = function() end,
  }
end

CreateFrame = frame
SlashCmdList = {}
GetLocale = function() return 'enUS' end
GetNormalizedRealmName = function() return 'Moon Guard' end
time = function() return 1000 end
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
ChatFrame_AddMessageEventFilter = function(event, filter) eventFilters[event] = filter end
C_Timer = {After = function(_, callback) callback() end}
C_FriendList = {
  GetNumIgnores = function() return #ignored end,
  GetIgnoreName = function(index) return ignored[index] end,
  AddIgnore = function(name) ignored[#ignored + 1] = name end,
  DelIgnore = function(name)
    for index = #ignored, 1, -1 do
      if ignored[index] == name then table.remove(ignored, index) end
    end
  end,
}

local cn = {}
assert(loadfile('CharNotes/Strings.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Core.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Tags.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Sync.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/ElvUI.lua'))('CharNotes', cn)
assert(loadfile('CharNotes/Visuals.lua'))('CharNotes', cn)

ElvUICharNotesDB = {
  entries = {},
  tags = {
    legacy = {id = 'legacy', name = 'Legacy', icon = 'Interface\\Icons\\INV_Misc_Note_01'},
  },
  config = {},
}
cn.db = cn:EnsureDB()
assert(cn.db.tags.legacy.showChat == true)
assert(cn.db.tags.legacy.frameSize == 18)

local tagId = assert(cn:CreateTag('Friendly', 'Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend',
  true, true, true, 'TOPRIGHT', 24))
assert(cn:Store('Alice', 'Reliable player', false, {tagId}))
local entry = assert(cn:Get('Alice'))
assert(#cn:TagsForEntry(entry, 'chat') == 1)
assert(cn:TagsForEntry(entry, 'frames')[1].frameSize == 24)

cn:InitializeChatTags()
local filter = assert(eventFilters.CHAT_MSG_GUILD)
local blocked, message, author = filter(nil, 'CHAT_MSG_GUILD', 'Hello!', 'Alice-Moon Guard')
assert(blocked == false)
assert(author == 'Alice-Moon Guard')
assert(message:find('|T', 1, true) and message:find('Hello!', 1, true))

local exported = cn:ExportData()
assert(exported:sub(1, 3) == 'CN4')
cn.db.entries, cn.db.tags = {}, {}
assert(cn:ImportData(exported) == 1)
entry = assert(cn:Get('Alice'))
local importedTag = assert(cn:TagsForEntry(entry, 'chat')[1])
assert(importedTag.showChat == true and importedTag.frameSize == 24)

assert(cn:SetPlayerIgnored('Alice', true))
assert(cn:IsPlayerIgnored('Alice'))
assert(cn:SetPlayerIgnored('Alice', false))
assert(not cn:IsPlayerIgnored('Alice'))

print('feature_check.lua: ok')

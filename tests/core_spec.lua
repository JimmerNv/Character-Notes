-- Lightweight Lua 5.1 mock tests. They do not exercise the WoW Forever client.
local function frame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

CreateFrame = frame
SlashCmdList = {}
GetLocale = function() return "enUS" end
GetNormalizedRealmName = function() return "Moon Guard" end
time = function() return 100 end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GetMacroIcons = function(icons) icons[#icons + 1] = 134400 end

local cn = {}
assert(loadfile("CharNotes/Strings.lua"))("ElvUI_CharNotes", cn)
assert(loadfile("CharNotes/Core.lua"))("ElvUI_CharNotes", cn)
assert(loadfile("CharNotes/Tags.lua"))("ElvUI_CharNotes", cn)

local key, label = cn:Normalize("Alice-Moon Guard")
assert(key == "alice-moonguard")
assert(label == "Alice-MoonGuard")
assert(cn:Normalize("Bad|Name") == nil)

ElvUICharNotesDB = { entries = { old = { pink = true } }, config = {} }
cn.db = cn:EnsureDB()
assert(cn.db.entries.old.punk == true and cn.db.entries.old.pink == nil)
assert(cn.db.config.contextMenus == true)
assert(cn.db.schema == 3)
assert(cn:FilterBlizzardIcons("134400")[1] == 134400)
assert(cn:FilterBlizzardIcons("dualwield")[1] == "Interface\\Icons\\Ability_DualWield")

local tagId = assert(cn:CreateTag("Bad Guy", "Interface\\Icons\\Ability_DualWield", true, true, "PORTRAIT"))
assert(cn:Store("Alice", "A note", true, {tagId}))
local entry = cn:Get("alice-moonguard")
assert(entry and entry.note == "A note" and entry.punk == true)
assert(#entry.tags == 1 and entry.tags[1] == tagId)
assert(cn:TagsForEntry(entry, "tooltip")[1].name == "Bad Guy")
assert(cn:EntryList("bad guy")[1] == entry)
assert(cn:UpdateTag(tagId, "Enemy", "Interface\\Icons\\Ability_Rogue_FeignDeath", true, false, "TOPRIGHT"))
assert(cn:TagsForEntry(entry)[1].name == "Enemy")
assert(cn:Delete("Alice"))
assert(cn:Get("Alice") == nil)

print("core_spec.lua: ok")

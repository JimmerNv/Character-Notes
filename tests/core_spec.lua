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

local cn = {}
assert(loadfile("CharNotes/Strings.lua"))("ElvUI_CharNotes", cn)
assert(loadfile("CharNotes/Core.lua"))("ElvUI_CharNotes", cn)

local key, label = cn:Normalize("Alice-Moon Guard")
assert(key == "alice-moonguard")
assert(label == "Alice-MoonGuard")
assert(cn:Normalize("Bad|Name") == nil)

ElvUICharNotesDB = { entries = { old = { pink = true } }, config = {} }
cn.db = cn:EnsureDB()
assert(cn.db.entries.old.punk == true and cn.db.entries.old.pink == nil)
assert(cn.db.config.contextMenus == true)

assert(cn:Store("Alice", "A note", true))
local entry = cn:Get("alice-moonguard")
assert(entry and entry.note == "A note" and entry.punk == true)
assert(cn:Delete("Alice"))
assert(cn:Get("Alice") == nil)

print("core_spec.lua: ok")

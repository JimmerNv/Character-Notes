-- CN3 import/export tests with WoW APIs mocked. No live client behavior is tested.
local function frame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

CreateFrame = frame
SlashCmdList = {}
GetLocale = function() return "enUS" end
GetNormalizedRealmName = function() return "MoonGuard" end
time = function() return 500 end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local function loadAddon()
    local cn = {}
    assert(loadfile("CharNotes/Strings.lua"))("ElvUI_CharNotes", cn)
    assert(loadfile("CharNotes/Core.lua"))("ElvUI_CharNotes", cn)
    assert(loadfile("CharNotes/Tags.lua"))("ElvUI_CharNotes", cn)
    assert(loadfile("CharNotes/Sync.lua"))("ElvUI_CharNotes", cn)
    cn.db = cn:EnsureDB()
    return cn
end

ElvUICharNotesDB = {}
local source = loadAddon()
local tagId = assert(source:CreateTag("Good Guy", "Interface\\Icons\\Spell_Holy_GreaterHeal", true, true, "TOPLEFT"))
assert(source:Store("Alice", "Helpful player", false, {tagId}))
local exported = source:ExportData()
assert(exported:sub(1, 4) == "CN3\n")

ElvUICharNotesDB = {}
local target = loadAddon()
assert(target:ImportData(exported) == 1)
local imported = assert(target:Get("Alice"))
assert(imported.note == "Helpful player" and #imported.tags == 1)
local importedTag = assert(target.db.tags[imported.tags[1]])
assert(importedTag.name == "Good Guy")
assert(importedTag.icon == "Interface\\Icons\\Spell_Holy_GreaterHeal")
assert(importedTag.showFrames == true and importedTag.framePoint == "TOPLEFT")

-- Guild sharing must not copy local tag definitions or assignments.
source.pendingOut = {}
assert(source:QueueRecord(source:Get("Alice"), "G"))
local guildPayload = {}
for _, packet in ipairs(source.pendingOut) do
    local part = packet.msg:match("^[GS]|%d+|%d+|%d+|([0-9A-F]+)$")
    guildPayload[#guildPayload + 1] = part
end
local guildExport = "CN3\n" .. table.concat(guildPayload)
ElvUICharNotesDB = {}
local guildTarget = loadAddon()
assert(guildTarget:ImportData(guildExport) == 1)
local guildEntry = assert(guildTarget:Get("Alice"))
assert(#guildEntry.tags == 0 and next(guildTarget.db.tags) == nil)

-- Legacy CN2 data remains accepted and must not discard local tags when newer.
local legacy = "CN2\n" .. (function()
    local raw = table.concat({"Alice-MoonGuard", "502", "legacy", "0", "0", "Legacy text"}, "\t")
    return (raw:gsub(".", function(c) return string.format("%02X", string.byte(c)) end))
end)()
assert(target:ImportData(legacy) == 1)
assert(target:Get("Alice").tags[1] == imported.tags[1])

print("sync_spec.lua: ok")

-- Lua 5.1 mock for diagnostics: no WoW UI is required.
local current = 100000
function time() return current end
function GetLocale() return 'enUS' end
function GetNormalizedRealmName() return 'TestRealm' end
function GetMacroIcons() end
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
local cn = {}
assert(loadfile('CharNotes/Strings.lua'))('ElvUI_CharNotes', cn)
assert(loadfile('CharNotes/Core.lua'))('ElvUI_CharNotes', cn)
assert(loadfile('CharNotes/SupportLog.lua'))('ElvUI_CharNotes', cn)
assert(loadfile('CharNotes/Tags.lua'))('ElvUI_CharNotes', cn)
ElvUICharNotesDB = {entries={}, tags={}, config={}, generalNotes={}}
cn:EnsureDB()
local id = cn.db.supportId
assert(id:match('^[a-f0-9]+%-[a-f0-9]+%-4[a-f0-9]+%-[89ab][a-f0-9]+%-[a-f0-9]+$'))
cn:LogEvent('NOTE_SAVED','general; created')
cn:LogEvent('TAG_CREATED','definition')
cn:LogEvent('POINT_ADDED','class=DRUID; node=123; rank=0->1')
-- The diagnostics API must not inspect source note data.
cn.db.generalNotes[1]={title='PRIVATE_TITLE',body='PRIVATE_BODY'}
current = current + 301
cn:LogEvent('TAG_DELETED','definition')
cn:RecordDiagnosticError('LUA_ERROR','CharNotes/Core.lua:100: failure')
assert(#cn.db.diagnosticErrors == 1)
assert(#cn.db.diagnosticErrors[1].context == 1)
assert(cn.db.diagnosticErrors[1].context[1].event == 'TAG_DELETED')
cn:RecordDiagnosticError('LUA_ERROR','CharNotes/Core.lua:100: failure')
assert(cn.db.diagnosticErrors[1].count == 2)
assert(cn:GetDiagnosticErrorReport(1):find(id,1,true))
assert(not cn:GetDiagnosticErrorReport(1):find('PRIVATE_TITLE',1,true))
assert(not cn:GetDiagnosticErrorReport(1):find('PRIVATE_BODY',1,true))
cn:EnsureDB()
assert(cn.db.supportId == id)
current = current + 86401
assert(#cn:GetDiagnosticLog() == 0)
cn:ClearDiagnosticLog()
assert(#cn.db.diagnosticErrors == 0)
print('support_log_spec.lua: ok')

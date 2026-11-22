-- Check every runtime file listed by the manifest, including locale modules.
local count = 0
for line in io.lines('CharNotes/ElvUI_CharNotes.toc') do
  local file = line:match('^%s*(.-)%s*$'):gsub('\\', '/')
  if file:match('%.lua$') then
    local chunk, err = loadfile('CharNotes/' .. file)
    assert(chunk, file .. ': ' .. tostring(err))
    count = count + 1
  end
end
assert(count > 0, 'No Lua files found in the addon manifest')
print('syntax_check.lua: ok (' .. count .. ' runtime files)')

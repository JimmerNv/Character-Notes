local files = {
  'CharNotes/Strings.lua', 'CharNotes/Core.lua', 'CharNotes/Tags.lua',
  'CharNotes/UI.lua', 'CharNotes/Menu.lua', 'CharNotes/Visuals.lua',
  'CharNotes/Sync.lua', 'CharNotes/ElvUI.lua', 'CharNotes/Titan.lua',
}

for _, file in ipairs(files) do
  local chunk, err = loadfile(file)
  assert(chunk, file .. ': ' .. tostring(err))
end

print('syntax_check.lua: ok')

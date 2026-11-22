-- General note transfer, explicit acceptance, and transport guards.
CreateFrame = function() return {RegisterEvent=function() end, SetScript=function() end} end
SlashCmdList = {}
GetLocale = function() return 'enUS' end
GetNormalizedRealmName = function() return 'MoonGuard' end
time = function() return 1000 end
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
IsInGuild = function() return true end
IsInGroup = function() return true end
IsInRaid = function() return false end

local function newClient()
    local cn = {widgets={}}
    for _, name in ipairs({'Strings','Core','Tags','TalentModel','Notebook','Sync'}) do
        assert(loadfile('CharNotes/'..name..'.lua'))('ElvUI_CharNotes',cn)
    end
    ElvUICharNotesDB = {}
    cn.db = cn:EnsureDB()
    return cn
end

local source, target = newClient(), newClient()
local id = assert(source:SaveGeneralNote(nil,'Build for raid',
    'A|B\nLine 2\t'..string.rep('z',370),
    {class='WARRIOR',ranks={[101]=3,[102]=2},choices={[102]=777}}))
local function deliver(channel, recipient)
    source.pendingOut = {}
    local ok, count = source:ShareGeneralNote(id,channel,recipient)
    assert(ok and count > 1 and #source.pendingOut == count)
    assert(source.pendingOut[1].msg:sub(1,2)=='N|','default single build retains legacy wire format')
    for _, packet in ipairs(source.pendingOut) do
        assert(packet.channel == channel)
        assert(packet.target == (channel=='WHISPER' and 'Bob-MoonGuard' or nil))
        target:ReceivePacket(packet.msg,channel,'Alice-MoonGuard')
    end
    local item = assert(target.db.generalInbox[#target.db.generalInbox])
    assert(item.channel==channel and item.sender=='Alice-MoonGuard')
    assert(item.note.title=='Build for raid' and item.note.body==source.db.generalNotes[id].body)
    assert(item.note.build.class=='WARRIOR' and item.note.build.ranks[101]==3
        and item.note.build.choices[102]==777)
end

deliver('PARTY')
assert(next(target.db.generalNotes)==nil,'receiving must not import automatically')
assert(target:RejectGeneralInbox(1) and #target.db.generalInbox==0)
IsInRaid=function() return true end
deliver('RAID')
assert(not source:ShareGeneralNote(id,'PARTY'),'raid must use raid channel')
assert(target:AcceptGeneralInbox(1))
assert(#target.db.generalInbox==0 and target.db.generalNotes[1].build.ranks[102]==2)
deliver('GUILD')
deliver('WHISPER','Bob-MoonGuard')
assert(#target.db.generalInbox==2)
assert(target:AcceptGeneralInbox(1) and target:AcceptGeneralInbox(1))
assert(#target.db.generalInbox==0 and target.db.generalNotes[1].title=='Build for raid'
    and target.db.generalNotes[2].title=='Build for raid'
    and target.db.generalNotes[3].title=='Build for raid',
    'accepting creates new notes without overwriting existing ones')
assert(#target.db.generalNotes[3].builds==1 and target.db.generalNotes[3].builds[1].build.ranks[101]==3,
    'one-build messages migrate into the named build list')
local embeddedLink='|cff0070dd|Hitem:12345|h[Guide item]|h|r'
local guideID=assert(source:SaveGeneralNote(nil,'Three roles','Guide\nfor all builds\n'..embeddedLink,{
    {name='Damage',build={class='WARRIOR',ranks={[101]=3},choices={}}},
    {name='Tank',build={class='WARRIOR',ranks={[102]=2},choices={[102]=777}}},
    {name='PvP',build={class='WARRIOR',ranks={[103]=1},choices={}}},
},3))
source.pendingOut={}
local queued,parts=source:ShareGeneralNote(guideID,'WHISPER','Bob-MoonGuard')
assert(queued and parts>1 and source.pendingOut[1].msg:sub(1,2)=='M|',
    'multiple named builds require the new wire format')
for i=#source.pendingOut,1,-1 do
    target:ReceivePacket(source.pendingOut[i].msg,'WHISPER','Alice-MoonGuard')
end
local proposal=assert(target.db.generalInbox[1])
assert(#proposal.note.builds==3 and proposal.note.builds[1].name=='Damage'
    and proposal.note.builds[2].name=='Tank' and proposal.note.builds[3].name=='PvP'
    and proposal.note.activeBuild==3 and proposal.note.body:find(embeddedLink,1,true),
    'all builds and their names survive out-of-order packets')
assert(target:AcceptGeneralInbox(1))
local saved=assert(target.db.generalNotes[4])
assert(saved.title=='Three roles' and saved.activeBuild==3 and
    saved.builds[1].build.ranks[101]==3 and saved.builds[2].build.ranks[102]==2 and
    saved.builds[2].build.choices[102]==777 and saved.builds[3].build.ranks[103]==1,
    'accepting a guide saves every build and keeps older notes untouched')
local ten={}
for n=1,10 do ten[n]={name='Phase '..n,build={class='WARRIOR',ranks={[100+n]=n},choices={}}} end
local tenID=assert(source:SaveGeneralNote(nil,'Ten stages','A complete guide',ten,10))
source.pendingOut={}
assert(source:ShareGeneralNote(tenID,'GUILD'))
for _,packet in ipairs(source.pendingOut) do target:ReceivePacket(packet.msg,'GUILD','Alice-MoonGuard') end
assert(target.db.generalInbox[1].note.builds[10].name=='Phase 10')
assert(target:AcceptGeneralInbox(1))
assert(#target.db.generalNotes[5].builds==10 and target.db.generalNotes[5].activeBuild==10)
ten[11]={name='Extra',build={class='WARRIOR',ranks={},choices={}}}
assert(not source:SaveGeneralNote(nil,'Too many','',ten), 'eleven builds must be rejected')
assert(not source:ShareGeneralNote(id,'WHISPER',''))
assert(not source:ShareGeneralNote(id,'INVALID'))
target:ReceivePacket('N|123456|1|1|4142','WHISPER','Alice-MoonGuard')
target:ReceivePacket('M|123456|1|1|4142','WHISPER','Alice-MoonGuard')
assert(#target.db.generalInbox==0,'malformed payload must be discarded')
source.db.generalNotes[id].body=string.rep('x',7000)
assert(not source:ShareGeneralNote(id,'GUILD'),'oversized note must be rejected')
print('general_share_spec.lua: ok')

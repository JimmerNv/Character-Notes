local _, CN = ...
local W, L, P = CN.widgets, CN.L, CN.talents

function CN:ShowNoteBuilds()
    local note = self.notebook
    if not note or not note:IsShown() then return end
    if not self.noteBuildsWindow then
        local f = CreateFrame('Frame','ElvUICharNotesBuilds',UIParent)
        f:SetSize(680,470)
        f:SetPoint('CENTER')
        f:SetFrameStrata('FULLSCREEN_DIALOG')
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag('LeftButton')
        f:SetScript('OnDragStart',f.StartMoving)
        f:SetScript('OnDragStop',f.StopMovingOrSizing)
        W.backdrop(f)
        self.noteBuildsWindow = f
        W.action(f,'X',28,636,-12,function() f:Hide() end)
        W.caption(f,L.MANAGE_BUILDS,20,-18,16)
        W.caption(f,L.BUILD_MANAGER_HINT,20,-48,11)
        local list = W.list(f,20,-87,245,320)
        W.caption(f,L.BUILD_NAME,290,-89)
        local name = W.edit(f,352,28)
        name:SetMaxLetters(60)
        name:SetPoint('TOPLEFT',290,-112)
        local status = W.caption(f,'',290,-300,12)
        status:SetWidth(350)
        status:SetJustifyH('LEFT')
        local pendingRemoval
        local function current() return CN.notebook end
        local function refresh()
            local n = current()
            local rows = {}
            for i, entry in ipairs(n.builds) do
                local class = entry.build.class
                local label = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
                rows[#rows+1] = {key=i,label=(entry.name..'  ·  '..label):gsub('|','||')}
            end
            list(rows,function(index)
                pendingRemoval = nil
                n:selectBuild(index)
                name:SetText(n.builds[index].name)
                status:SetText('')
                refresh()
            end,n.activeBuild)
            if n.activeBuild and not n.builds[n.activeBuild] then n.activeBuild=nil end
        end
        f.refresh = refresh
        f.open = function()
            pendingRemoval = nil
            local n=current()
            name:SetText(n.builds[n.activeBuild] and n.builds[n.activeBuild].name or '')
            status:SetText('')
            refresh()
            f:Show()
            f:Raise()
        end
        W.action(f,L.RENAME_BUILD,170,290,-159,function()
            local n=current()
            local ok, err=n:renameBuild(n.activeBuild,name:GetText())
            status:SetText(ok and L.BUILD_RENAMED or err)
            pendingRemoval=nil
            refresh()
        end)
        W.action(f,L.NEW_BUILD,170,472,-159,function()
            local n=current()
            local currentName=n.builds[n.activeBuild] and n.builds[n.activeBuild].name
            local newName=name:GetText()
            if newName==currentName then newName=nil end
            local index, err=n:addBuild(newName,P.blank(n.build and n.build.class))
            if not index then status:SetText(err); return end
            pendingRemoval=nil
            name:SetText(n.builds[index].name)
            status:SetText(L.BUILD_ADDED)
            refresh()
        end)
        W.action(f,L.EDIT_BUILD,352,290,-202,function()
            local n=current()
            if not n.activeBuild then status:SetText(L.SELECT_BUILD); return end
            f:Hide()
            CN:ShowTalentPlanner(true)
        end)
        W.action(f,L.DUPLICATE,170,290,-245,function()
            local n=current()
            local original=n.builds[n.activeBuild]
            if not original then status:SetText(L.SELECT_BUILD); return end
            local i,newName=2
            repeat
                local suffix=' ('..i..')'
                newName=original.name:sub(1,60-#suffix)..suffix
                i=i+1
                local duplicate=false
                for _, entry in ipairs(n.builds) do
                    if entry.name:lower()==newName:lower() then duplicate=true; break end
                end
                if not duplicate then break end
            until i>100
            local index,err=n:addBuild(newName,original.build)
            if not index then status:SetText(err); return end
            pendingRemoval=nil
            name:SetText(n.builds[index].name)
            status:SetText(L.BUILD_ADDED)
            refresh()
        end)
        W.action(f,L.REMOVE,170,472,-245,function()
            local n=current()
            if not n.activeBuild then status:SetText(L.SELECT_BUILD); return end
            if pendingRemoval~=n.activeBuild then
                pendingRemoval=n.activeBuild
                status:SetText(L.REMOVE_BUILD_CONFIRM)
                return
            end
            n:removeBuild(n.activeBuild)
            pendingRemoval=nil
            name:SetText(n.builds[n.activeBuild] and n.builds[n.activeBuild].name or '')
            status:SetText(L.BUILD_REMOVED)
            refresh()
        end)
        W.action(f,L.CLOSE,170,472,-420,function() f:Hide() end)
        f:SetScript('OnHide',function() name:ClearFocus() end)
        f:Hide()
    end
    self.noteBuildsWindow.open()
end

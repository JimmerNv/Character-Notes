local ADDON, CN = ...
local L = CN.L

-- ElvUI 16.01 registers third-party plugins with LibElvUIPlugin-1.0,
-- not via E:RegisterPlugin (which is not part of the public plugin API).
function CN:GetElvUI()
    local elvUI = _G.ElvUI
    if type(elvUI) ~= 'table' then return nil end
    if type(elvUI[1]) == 'table' then return elvUI[1] end
    if type(elvUI.GetModule) == 'function' then return elvUI end
end

local function getPluginLibrary(E)
    local EP = E and E.Libs and E.Libs.EP
    if EP and type(EP.RegisterPlugin) == 'function' then return EP end
    if _G.LibStub then
        local ok, lib = pcall(_G.LibStub, 'LibElvUIPlugin-1.0', true)
        if ok and lib and type(lib.RegisterPlugin) == 'function' then return lib end
    end
end

local function optionsTable()
    return {
        type = 'group', name = 'CharNotes (PUNK)', order = 900,
        args = {
            overview = { type = 'description', order = 1,
                name = L.ELVUI_OVERVIEW },
            open = { type = 'execute', name = L.OPEN_NOTES, order = 2,
                func = function() CN:ShowWindow() end },
            sound = { type = 'toggle', name = L.ENABLE_GROUP_SOUND, order = 3,
                get = function() return CN.db.config.sound end,
                set = function(_, value) CN:SetOption('sound', value) end },
            soundChoice = { type = 'select', name = L.SOUND_ON_JOIN, order = 4,
                values = (function()
                    local result = {}
                    for _, item in ipairs(CN.SOUNDS) do result[item.key] = item.title end
                    return result
                end)(),
                get = function() return CN:SelectedSound().key end,
                set = function(_, value) CN:SetSoundChoice(value) end },
            test = { type = 'execute', name = L.PREVIEW, order = 5,
                func = function() CN:PlayAlertSound(true) end },
            popup = { type = 'toggle', name = L.GROUP_POPUP, order = 6,
                get = function() return CN.db.config.popup end,
                set = function(_, value) CN:SetOption('popup', value) end },
            border = { type = 'toggle', name = L.PUNK_BORDER, order = 7,
                get = function() return CN.db.config.border end,
                set = function(_, value) CN:SetOption('border', value) end },
            tooltip = { type = 'toggle', name = L.TOOLTIP_NOTE, order = 8,
                get = function() return CN.db.config.tooltip end,
                set = function(_, value) CN:SetOption('tooltip', value) end },
            contextMenus = { type = 'toggle', name = L.PLAYER_MENUS, order = 8.5,
                desc = L.PLAYER_MENUS_DESC,
                get = function() return CN.db.config.contextMenus end,
                set = function(_, value) CN:SetOption('contextMenus', value) end },
            any = { type = 'toggle', name = L.ALERT_ALL_NOTES, order = 9,
                get = function() return CN.db.config.alertAnyNote end,
                set = function(_, value) CN:SetOption('alertAnyNote', value) end },
            status = { type = 'execute', name = L.ELVUI_STATUS_BUTTON, order = 10,
                func = function() CN:Status() end },
        },
    }
end

function CN:TryRegisterElvUIOptions()
    local E = self:GetElvUI()
    if not E then return false end
    if not E.Options or type(E.Options.args) ~= 'table' then
        self.elvuiPluginState = L.ELVUI_WAITING
        return false
    end
    -- Called by the official library when ElvUI_Options becomes available.
    if E.Options.args.cnPunk then return true end
    E.Options.args.cnPunk = optionsTable()
    self.elvuiPluginState = L.ELVUI_READY
    if E.Libs and E.Libs.ACR and type(E.Libs.ACR.NotifyChange) == 'function' then
        pcall(E.Libs.ACR.NotifyChange, E.Libs.ACR, 'ElvUI')
    elseif _G.LibStub then
        local ok, ACR = pcall(_G.LibStub, 'AceConfigRegistry-3.0', true)
        if ok and ACR and ACR.NotifyChange then pcall(ACR.NotifyChange, ACR, 'ElvUI') end
    end
    return true
end

function CN:InitializeElvUI()
    if self.elvuiHooked then return end
    local E = self:GetElvUI()
    if not E then return end
    local EP = getPluginLibrary(E)
    if EP then
        -- EP:RegisterPlugin calls its callback immediately when options are already
        -- loaded, and otherwise delays it until ElvUI_Options is initialized.
        local ok, err = pcall(EP.RegisterPlugin, EP, ADDON, function()
            CN:TryRegisterElvUIOptions()
        end)
        if ok then
            self.elvuiHooked = true
            self.elvuiPluginState = L.ELVUI_REGISTERED
            if E.Options and E.Options.args and E.Options.args.cnPunk then
                self.elvuiPluginState = L.ELVUI_READY
            end
            return
        end
        self:Print(L.ELVUI_REGISTER_ERROR:format(tostring(err)))
    end
    -- Rare compatible forks that do not expose the library still get an
    -- options entry once ElvUI_Options is loaded. Retry on ADDON_LOADED.
    self.elvuiPluginState = L.ELVUI_FALLBACK
    self:TryRegisterElvUIOptions()
end

local _, CN = ...
local L = CN.L
local ID = 'CharacterNotesAlerts'

function TitanPanelCharacterNotesAlerts_GetButtonText()
    return L.TITAN_LABEL
end

function TitanPanelCharacterNotesAlerts_GetTooltipText()
    return L.TITAN_OPEN_NOTES
end

function CN:InitializeTitan()
    -- The template queues the button for registration during its OnLoad script.
    local button = CreateFrame('Button', 'TitanPanel' .. ID .. 'Button', UIParent, 'TitanPanelComboTemplate')
    button.registry = {
        id = ID,
        category = 'Information',
        version = self.VERSION,
        menuText = L.TITAN_TITLE,
        buttonTextFunction = 'TitanPanelCharacterNotesAlerts_GetButtonText',
        tooltipTitle = L.TITAN_TITLE,
        tooltipTextFunction = 'TitanPanelCharacterNotesAlerts_GetTooltipText',
        icon = 'Interface\\Icons\\INV_Misc_Note_01',
        iconWidth = 16,
        controlVariables = { ShowIcon = true },
        savedVariables = { ShowIcon = 1 },
    }
    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    button:HookScript('OnClick', function(_, mouseButton)
        if mouseButton == 'LeftButton' then CN:ShowWindow() end
    end)
end

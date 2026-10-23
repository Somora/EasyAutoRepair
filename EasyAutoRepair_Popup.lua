local addon = EasyAutoRepair

local StaticPopup_Show = StaticPopup_Show
local StaticPopup_Visible = StaticPopup_Visible
local StaticPopupDialogs = StaticPopupDialogs

function addon:ShowProviderPopup(providers)
    -- Do not replace the definition or selection data of an open dialog.
    if StaticPopup_Visible(self.POPUP_NAME) then
        return
    end

    local popupData = {
        providers = providers,
        signature = self:BuildProviderSignature(providers),
    }
    local selectionHandled = false

    local function SelectProvider(index)
        if not selectionHandled and popupData.providers[index] then
            selectionHandled = true
            addon:SetProvider(popupData.providers[index])
        end
    end

    local labels = {}
    for index, provider in ipairs(providers) do
        labels[index] = self:GetProviderLabel(provider)
    end

    StaticPopupDialogs[self.POPUP_NAME] = {
        text = "Choose which addon should handle your repairs.",
        button1 = labels[1],
        button2 = labels[2],
        button3 = labels[3],
        OnAccept = function()
            SelectProvider(1)
        end,
        OnCancel = function(_, _, reason)
            if reason == "clicked" then
                SelectProvider(2)
            end
        end,
        OnHide = function()
            if not selectionHandled then
                selectionHandled = true
                EasyAutoRepairDB.providerPromptSignature = popupData.signature
                EasyAutoRepairDB.providerPromptSignatures[popupData.signature] = true
                addon:Print("Provider selection skipped. Use /ear provider easyautorepair, /ear provider elvui, or /ear provider zygor anytime.")
            end
        end,
        OnAlt = function()
            SelectProvider(3)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        -- Escape also uses the "clicked" reason on Retail. Only button 2
        -- should select provider 2; OnHide handles dismissal separately.
        noCancelOnEscape = true,
        preferredIndex = 3,
        hasEditBox = false,
    }

    if StaticPopup_Show(self.POPUP_NAME, nil, nil, popupData) then
        self.promptedSessionSignature = popupData.signature
    end
end

function addon:MaybePromptForProviderSelection(trigger)
    local providers = self:GetAvailableProviders()
    if #providers <= 1 then
        return
    end

    local signature = self:BuildProviderSignature(providers)
    local drifted = self:IsProviderConfigurationOutOfSync()

    if drifted then
        if trigger == "login" and EasyAutoRepairDB.providerPromptSignature ~= "" then
            return
        end

        EasyAutoRepairDB.providerPromptSignature = ""
        EasyAutoRepairDB.providerPromptSignatures[signature] = nil

        if self.promptedSessionSignature == signature then
            return
        end

        self:Print("A repair provider setting changed outside EasyAutoRepair. Please confirm your preferred provider again.")
        self:ShowProviderPopup(providers)
        return
    end

    if EasyAutoRepairDB.providerPromptSignatures[signature] then
        return
    end

    self:ShowProviderPopup(providers)
end

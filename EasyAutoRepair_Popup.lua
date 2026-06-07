local addon = EasyAutoRepair

local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs

local pendingPopupData

function addon:ShowProviderPopup(providers)
    pendingPopupData = {
        providers = providers,
        signature = self:BuildProviderSignature(providers),
    }

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
            addon:SetProvider(pendingPopupData.providers[1])
            pendingPopupData = nil
        end,
        OnCancel = function(_, reason)
            if reason == "clicked" and pendingPopupData and pendingPopupData.providers[2] then
                addon:SetProvider(pendingPopupData.providers[2])
                pendingPopupData = nil
                return
            end

            if pendingPopupData then
                EasyAutoRepairDB.providerPromptSignature = pendingPopupData.signature
                EasyAutoRepairDB.providerPromptSignatures[pendingPopupData.signature] = true
            end
            pendingPopupData = nil
            addon:Print("Provider selection skipped. Use /ear provider easyautorepair, /ear provider elvui, or /ear provider zygor anytime.")
        end,
        OnAlt = function()
            if pendingPopupData and pendingPopupData.providers[3] then
                addon:SetProvider(pendingPopupData.providers[3])
            end
            pendingPopupData = nil
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        hasEditBox = false,
    }

    StaticPopup_Show(self.POPUP_NAME)
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

        self.promptedSessionSignature = signature
        self:Print("A repair provider setting changed outside EasyAutoRepair. Please confirm your preferred provider again.")
        self:ShowProviderPopup(providers)
        return
    end

    if EasyAutoRepairDB.providerPromptSignatures[signature] then
        return
    end

    self.promptedSessionSignature = signature
    self:ShowProviderPopup(providers)
end

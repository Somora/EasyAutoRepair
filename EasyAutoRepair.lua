local ADDON_NAME = ...

EasyAutoRepair = EasyAutoRepair or {}

EasyAutoRepair.ADDON_NAME = ADDON_NAME
EasyAutoRepair.PREFIX = "|cff33ff99EasyAutoRepair|r: "
EasyAutoRepair.PROVIDER_EAR = "easyautorepair"
EasyAutoRepair.PROVIDER_ELVUI = "elvui"
EasyAutoRepair.PROVIDER_ZYGOR = "zygor"
EasyAutoRepair.ELVUI_ADDON_NAME = "ElvUI"
EasyAutoRepair.POPUP_NAME = "EASYAUTOREPAIR_PROVIDER_SELECT"
EasyAutoRepair.defaults = {
    enabled = true,
    provider = "easyautorepair",
    elvUIDetected = false,
    zygorDetected = false,
    providerPromptSignature = "",
    zygorAutoRepairMode = nil,
}

local frame = CreateFrame("Frame")
EasyAutoRepair.promptedSessionSignature = nil

function EasyAutoRepair:Print(message)
    print(self.PREFIX .. message)
end

function EasyAutoRepair:GetStatusText(enabled)
    return enabled and "enabled" or "disabled"
end

function EasyAutoRepair:InitializeDatabase()
    EasyAutoRepairDB = EasyAutoRepairDB or {}

    for key, value in pairs(self.defaults) do
        if EasyAutoRepairDB[key] == nil then
            EasyAutoRepairDB[key] = value
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == EasyAutoRepair.ADDON_NAME then
            EasyAutoRepair:InitializeDatabase()
        elseif arg1 == EasyAutoRepair.ELVUI_ADDON_NAME and EasyAutoRepairDB then
            EasyAutoRepair:SyncProviderState(false)
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        EasyAutoRepair:SyncProviderState(false)
        EasyAutoRepair:Print("Loaded. Use /ear status or /ear provider easyautorepair|elvui|zygor.")
        if EasyAutoRepair:IsElvUIAvailable() then
            EasyAutoRepair:Print("ElvUI detected. Preferred repair provider: " .. EasyAutoRepair:GetProviderLabel(EasyAutoRepairDB.provider) .. ".")
        end
        if EasyAutoRepair:IsZygorAvailable() then
            EasyAutoRepair:Print("Zygor detected. Preferred repair provider: " .. EasyAutoRepair:GetProviderLabel(EasyAutoRepairDB.provider) .. ".")
        end
        EasyAutoRepair:MaybePromptForProviderSelection("login")
        return
    end

    if event == "MERCHANT_SHOW" then
        EasyAutoRepair:MaybePromptForProviderSelection("merchant")
        EasyAutoRepair:HandleMerchantShow()
    end
end)

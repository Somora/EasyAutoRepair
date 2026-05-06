local addon = EasyAutoRepair

local strlower = strlower
local strmatch = strmatch
local strtrim = strtrim

function addon:PrintStatus()
    local status = self:GetStatusText(EasyAutoRepairDB.enabled)
    local provider = self:GetProviderLabel(EasyAutoRepairDB.provider)
    local elvUIStatus = EasyAutoRepairDB.elvUIDetected and "detected" or "not detected"
    local zygorStatus = EasyAutoRepairDB.zygorDetected and "detected" or "not detected"

    self:Print("Auto repair is " .. status .. ". Provider: " .. provider .. ". ElvUI: " .. elvUIStatus .. ". Zygor: " .. zygorStatus .. ".")
end

SLASH_EASYAUTOREPAIR1 = "/ear"
SlashCmdList.EASYAUTOREPAIR = function(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "on" then
        EasyAutoRepairDB.enabled = true
        addon:SyncProviderState(false)
        addon:Print("Auto repair is now enabled.")
        return
    end

    if msg == "off" then
        EasyAutoRepairDB.enabled = false
        addon:SyncProviderState(false)
        addon:Print("Auto repair is now disabled.")
        return
    end

    if msg == "status" then
        addon:MaybePromptForProviderSelection()
        addon:PrintStatus()
        return
    end

    if msg == "" or msg == "toggle" then
        EasyAutoRepairDB.enabled = not EasyAutoRepairDB.enabled
        addon:SyncProviderState(false)
        addon:Print("Auto repair is now " .. addon:GetStatusText(EasyAutoRepairDB.enabled) .. ".")
        return
    end

    local provider = strmatch(msg, "^provider%s+(%S+)$")
    if provider == addon.PROVIDER_EAR or provider == "ear" then
        addon:SetProvider(addon.PROVIDER_EAR)
        return
    end

    if provider == addon.PROVIDER_ELVUI then
        addon:SetProvider(addon.PROVIDER_ELVUI)
        return
    end

    if provider == addon.PROVIDER_ZYGOR then
        addon:SetProvider(addon.PROVIDER_ZYGOR)
        return
    end

    addon:Print("Usage: /ear, /ear on, /ear off, /ear toggle, /ear status, /ear provider easyautorepair, /ear provider elvui, or /ear provider zygor.")
end

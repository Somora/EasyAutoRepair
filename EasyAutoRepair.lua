-- SavedVariables setup (in .toc)
EasyAutoRepairDB = EasyAutoRepairDB or {}
if EasyAutoRepairDB.enabled == nil then
    EasyAutoRepairDB.enabled = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("EasyAutoRepair loaded. Use /ear to enable or disable auto repair.")
        return
    end

    if event == "MERCHANT_SHOW" then
        if not EasyAutoRepairDB.enabled then return end
        if not CanMerchantRepair() then return end

        local repairAllCost, canRepair = GetRepairAllCost()

        if repairAllCost > 0 and canRepair then
            if IsInGuild() and CanGuildBankRepair() then
                RepairAllItems(true)
                if GetRepairAllCost() == 0 then
                    print("EasyAutoRepair: Repaired using guild funds.")
                    return
                end
            end
            RepairAllItems(false)
            print("EasyAutoRepair: Repaired for " .. GetCoinTextureString(repairAllCost) .. ".")
        else
            print("EasyAutoRepair: No repairs needed.")
        end
    end
end)

-- Slash command
SLASH_EASYAUTOREPAIR1 = "/ear"
SlashCmdList["EASYAUTOREPAIR"] = function(msg)
    EasyAutoRepairDB.enabled = not EasyAutoRepairDB.enabled
    local status = EasyAutoRepairDB.enabled and "enabled" or "disabled"
    print("EasyAutoRepair: Auto repair is now " .. status .. ".")
end
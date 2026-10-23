local addon = EasyAutoRepair

local GetMoney = GetMoney
local GetRepairAllCost = GetRepairAllCost
local GetCoinTextureString = GetCoinTextureString
local CanMerchantRepair = CanMerchantRepair
local CanGuildBankRepair = CanGuildBankRepair
local IsInGuild = IsInGuild
local RepairAllItems = RepairAllItems
local issecretvalue = issecretvalue

local repairFrame = CreateFrame("Frame")
local pendingRepair
local merchantRepairStarted = false
local RESULT_TIMEOUT = 5
local CHECK_INTERVAL = 0.1

local function IsReadableNumber(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "number" and value >= 0
end

function addon:CancelPendingRepair()
    pendingRepair = nil
    repairFrame:UnregisterAllEvents()
    repairFrame:SetScript("OnUpdate", nil)
end

function addon:HandleMerchantClosed()
    self:CancelPendingRepair()
    merchantRepairStarted = false
end

local function BeginRepair(useGuild, cost)
    -- Install the observer before the request; an event may arrive immediately.
    pendingRepair = { useGuild = useGuild, cost = cost, elapsed = 0, checkElapsed = 0 }
    repairFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    repairFrame:RegisterEvent("UI_ERROR_MESSAGE")
    repairFrame:SetScript("OnUpdate", function(_, elapsed)
        addon:UpdatePendingRepair(elapsed)
    end)
    RepairAllItems(useGuild)
end

function addon:TryRepairWithPlayerMoney(cost)
    if pendingRepair or not IsReadableNumber(cost) or cost <= 0 then
        return
    end

    local money = GetMoney()
    if not IsReadableNumber(money) then
        return
    end
    if money < cost then
        self:Print("Not enough money to repair.")
        return
    end

    BeginRepair(false, cost)
end

function addon:UpdatePendingRepair(elapsed)
    local attempt = pendingRepair
    if not attempt then
        return
    end
    if not EasyAutoRepairDB.enabled or EasyAutoRepairDB.provider ~= self.PROVIDER_EAR or not CanMerchantRepair() then
        self:CancelPendingRepair()
        return
    end

    attempt.elapsed = attempt.elapsed + elapsed
    attempt.checkElapsed = attempt.checkElapsed + elapsed
    if attempt.checkElapsed < CHECK_INTERVAL then
        return
    end
    attempt.checkElapsed = 0

    -- An unchanged quote, money event, or elapsed time is not a guild failure.
    -- Only a durability update with a lower quote confirms a repair result.
    if attempt.durabilityUpdated or attempt.guildRejected then
        local remainingCost = GetRepairAllCost()
        if IsReadableNumber(remainingCost) then
            if attempt.durabilityUpdated and remainingCost < attempt.cost then
                local repairedCost = attempt.cost - remainingCost
                self:CancelPendingRepair()
                if attempt.useGuild then
                    if remainingCost == 0 then
                        self:Print("Repaired with guild funds.")
                    else
                        self:Print("Guild covered " .. GetCoinTextureString(repairedCost) .. ".")
                        self:TryRepairWithPlayerMoney(remainingCost)
                    end
                elseif remainingCost == 0 then
                    self:Print("Repaired with personal funds for " .. GetCoinTextureString(repairedCost) .. ".")
                else
                    self:Print("Personal funds covered " .. GetCoinTextureString(repairedCost) .. "; some repairs remain.")
                end
                return
            elseif attempt.guildRejected then
                -- A known refusal ends the guild request. Re-read the quote
                -- before making the single permitted personal-funds attempt.
                self:CancelPendingRepair()
                self:TryRepairWithPlayerMoney(remainingCost)
                return
            end
        end
    end

    if attempt.elapsed >= RESULT_TIMEOUT then
        self:CancelPendingRepair()
        self:Print("Repair result was not confirmed. Please check your gear.")
    end
end

repairFrame:SetScript("OnEvent", function(_, event, errorType)
    local attempt = pendingRepair
    if not attempt then
        return
    end
    if event == "UPDATE_INVENTORY_DURABILITY" then
        attempt.durabilityUpdated = true
    elseif event == "UI_ERROR_MESSAGE" then
        if issecretvalue and issecretvalue(errorType) then
            return
        end
        local guildShortage = LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY
        local personalShortage = LE_GAME_ERR_NOT_ENOUGH_MONEY
        if attempt.useGuild and ((guildShortage and errorType == guildShortage) or (personalShortage and errorType == personalShortage)) then
            attempt.guildRejected = true
        elseif not attempt.useGuild and personalShortage and errorType == personalShortage then
            addon:CancelPendingRepair()
            addon:Print("Not enough money to repair.")
        end
    end
end)

function addon:HandleMerchantShow()
    if merchantRepairStarted or pendingRepair or not EasyAutoRepairDB.enabled
        or EasyAutoRepairDB.provider ~= self.PROVIDER_EAR or not CanMerchantRepair() then
        return
    end

    local totalCost, canRepair = GetRepairAllCost()
    if (issecretvalue and issecretvalue(canRepair)) or not IsReadableNumber(totalCost) then
        return
    end
    if not canRepair or totalCost <= 0 then
        return
    end

    merchantRepairStarted = true
    if type(CanGuildBankRepair) == "function" and IsInGuild() and CanGuildBankRepair() then
        BeginRepair(true, totalCost)
    else
        self:TryRepairWithPlayerMoney(totalCost)
    end
end

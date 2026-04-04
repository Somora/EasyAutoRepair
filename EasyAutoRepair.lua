local ADDON_NAME = ...
local PREFIX = "|cff33ff99EasyAutoRepair|r: "

local defaults = {
    enabled = true,
}

local CreateFrame = CreateFrame
local GetRepairAllCost = GetRepairAllCost
local CanMerchantRepair = CanMerchantRepair
local IsInGuild = IsInGuild
local CanGuildBankRepair = CanGuildBankRepair
local RepairAllItems = RepairAllItems
local GetCoinTextureString = GetCoinTextureString
local GetMoney = GetMoney
local print = print
local strlower = strlower
local strtrim = strtrim

local frame = CreateFrame("Frame")

local function Print(message)
    print(PREFIX .. message)
end

local function GetStatusText(enabled)
    return enabled and "enabled" or "disabled"
end

local function InitializeDatabase()
    EasyAutoRepairDB = EasyAutoRepairDB or {}

    for key, value in pairs(defaults) do
        if EasyAutoRepairDB[key] == nil then
            EasyAutoRepairDB[key] = value
        end
    end
end

local function TryRepairWithPlayerMoney(cost)
    if GetMoney() < cost then
        Print("Not enough money to repair.")
        return
    end

    RepairAllItems(false)
    Print("Repaired with personal funds for " .. GetCoinTextureString(cost) .. ".")
end

local function HandleMerchantShow()
    if not EasyAutoRepairDB.enabled or not CanMerchantRepair() then
        return
    end

    local totalCost, canRepair = GetRepairAllCost()
    if not canRepair or totalCost <= 0 then
        return
    end

    if IsInGuild() and CanGuildBankRepair() then
        RepairAllItems(true)

        local remainingCost = GetRepairAllCost()
        if remainingCost == 0 then
            Print("Repaired with guild funds.")
            return
        end

        if remainingCost < totalCost then
            local guildPaid = totalCost - remainingCost
            Print("Guild covered " .. GetCoinTextureString(guildPaid) .. ".")
            TryRepairWithPlayerMoney(remainingCost)
            return
        end
    end

    TryRepairWithPlayerMoney(totalCost)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitializeDatabase()
            frame:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        Print("Loaded. Use /ear to toggle, or /ear status for the current setting.")
        return
    end

    if event == "MERCHANT_SHOW" then
        HandleMerchantShow()
    end
end)

SLASH_EASYAUTOREPAIR1 = "/ear"
SlashCmdList.EASYAUTOREPAIR = function(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "on" then
        EasyAutoRepairDB.enabled = true
    elseif msg == "off" then
        EasyAutoRepairDB.enabled = false
    elseif msg == "status" then
        Print("Auto repair is " .. GetStatusText(EasyAutoRepairDB.enabled) .. ".")
        return
    elseif msg == "" or msg == "toggle" then
        EasyAutoRepairDB.enabled = not EasyAutoRepairDB.enabled
    else
        Print("Usage: /ear, /ear on, /ear off, /ear toggle, or /ear status.")
        return
    end

    Print("Auto repair is now " .. GetStatusText(EasyAutoRepairDB.enabled) .. ".")
end

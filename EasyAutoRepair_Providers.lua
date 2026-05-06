local addon = EasyAutoRepair

local C_AddOns = C_AddOns
local GetMoney = GetMoney
local GetRepairAllCost = GetRepairAllCost
local GetCoinTextureString = GetCoinTextureString
local IsAddOnLoaded = IsAddOnLoaded
local CanMerchantRepair = CanMerchantRepair
local CanGuildBankRepair = CanGuildBankRepair
local IsInGuild = IsInGuild
local RepairAllItems = RepairAllItems

function addon:GetProviderLabel(provider)
    if provider == self.PROVIDER_ELVUI then
        return "ElvUI"
    end

    if provider == self.PROVIDER_ZYGOR then
        return "Zygor"
    end

    return "EasyAutoRepair"
end

function addon:IsElvUIAvailable()
    if type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" then
        return true
    end

    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded(self.ELVUI_ADDON_NAME) then
        return true
    end

    if IsAddOnLoaded and IsAddOnLoaded(self.ELVUI_ADDON_NAME) then
        return true
    end

    return false
end

function addon:IsZygorAvailable()
    return (_G.ZGV or _G.ZygorGuidesViewer) and true or false
end

function addon:GetAvailableProviders()
    local providers = { self.PROVIDER_EAR }

    if self:IsElvUIAvailable() then
        providers[#providers + 1] = self.PROVIDER_ELVUI
    end

    if self:IsZygorAvailable() then
        providers[#providers + 1] = self.PROVIDER_ZYGOR
    end

    return providers
end

function addon:BuildProviderSignature(providers)
    return table.concat(providers, "|")
end

function addon:GetElvUIEngine()
    local elvUI = _G.ElvUI
    if type(elvUI) ~= "table" then
        return nil
    end

    local engine = elvUI[1]
    if type(engine) ~= "table" then
        return nil
    end

    if type(engine.db) ~= "table" or type(engine.db.general) ~= "table" then
        return nil
    end

    return engine
end

function addon:GetZygorEngine()
    local engine = _G.ZGV or _G.ZygorGuidesViewer
    if type(engine) ~= "table" then
        return nil
    end

    if type(engine.db) ~= "table" or type(engine.db.profile) ~= "table" then
        return nil
    end

    return engine
end

function addon:GetElvUIAutoRepairMode()
    local engine = self:GetElvUIEngine()
    if not engine then
        return nil
    end

    return engine.db.general.autoRepair
end

function addon:GetZygorAutoRepairMode()
    local engine = self:GetZygorEngine()
    if not engine then
        return nil
    end

    return engine.db.profile.autorepair
end

function addon:SetElvUIAutoRepair(enabled)
    local engine = self:GetElvUIEngine()
    if not engine then
        return false
    end

    engine.db.general.autoRepair = enabled and "GUILD" or "NONE"

    if type(engine.SaveSettings) == "function" then
        pcall(engine.SaveSettings, engine)
    end

    return true
end

function addon:SetZygorAutoRepair(enabled)
    local engine = self:GetZygorEngine()
    if not engine then
        return false
    end

    local currentMode = engine.db.profile.autorepair

    if enabled then
        if type(currentMode) == "number" and currentMode > 1 then
            EasyAutoRepairDB.zygorAutoRepairMode = currentMode
            return true
        end

        if type(EasyAutoRepairDB.zygorAutoRepairMode) == "number" and EasyAutoRepairDB.zygorAutoRepairMode > 1 then
            engine.db.profile.autorepair = EasyAutoRepairDB.zygorAutoRepairMode
        else
            engine.db.profile.autorepair = engine.IsClassic and 2 or 3
        end
    else
        if type(currentMode) == "number" and currentMode > 1 then
            EasyAutoRepairDB.zygorAutoRepairMode = currentMode
        end

        engine.db.profile.autorepair = 1
    end

    return true
end

function addon:SyncProviderState(notify)
    local elvUIAvailable = self:IsElvUIAvailable() and true or false
    local zygorAvailable = self:IsZygorAvailable() and true or false
    local provider = EasyAutoRepairDB.provider
    local enabled = EasyAutoRepairDB.enabled

    EasyAutoRepairDB.elvUIDetected = elvUIAvailable
    EasyAutoRepairDB.zygorDetected = zygorAvailable

    if not enabled then
        if elvUIAvailable then
            self:SetElvUIAutoRepair(false)
        end
        if zygorAvailable then
            self:SetZygorAutoRepair(false)
        end

        if notify then
            self:Print("Auto repair is disabled.")
        end
        return
    end

    if provider == self.PROVIDER_ELVUI then
        if zygorAvailable then
            self:SetZygorAutoRepair(false)
        end

        if elvUIAvailable then
            self:SetElvUIAutoRepair(true)
            if notify then
                self:Print("Repair provider set to ElvUI.")
            end
        elseif notify then
            self:Print("ElvUI repair was selected, but ElvUI is not loaded.")
        end
        return
    end

    if provider == self.PROVIDER_ZYGOR then
        if elvUIAvailable then
            self:SetElvUIAutoRepair(false)
        end
        if zygorAvailable then
            self:SetZygorAutoRepair(true)
        end

        if notify then
            if zygorAvailable then
                self:Print("Repair provider set to Zygor.")
            else
                self:Print("Zygor repair was selected, but Zygor is not loaded.")
            end
        end
        return
    end

    if elvUIAvailable then
        self:SetElvUIAutoRepair(false)
    end
    if zygorAvailable then
        self:SetZygorAutoRepair(false)
    end

    if notify then
        self:Print("Repair provider set to EasyAutoRepair.")
    end
end

function addon:TryRepairWithPlayerMoney(cost)
    if GetMoney() < cost then
        self:Print("Not enough money to repair.")
        return
    end

    RepairAllItems(false)
    self:Print("Repaired with personal funds for " .. GetCoinTextureString(cost) .. ".")
end

function addon:HandleMerchantShow()
    if not EasyAutoRepairDB.enabled or EasyAutoRepairDB.provider ~= self.PROVIDER_EAR or not CanMerchantRepair() then
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
            self:Print("Repaired with guild funds.")
            return
        end

        if remainingCost < totalCost then
            local guildPaid = totalCost - remainingCost
            self:Print("Guild covered " .. GetCoinTextureString(guildPaid) .. ".")
            self:TryRepairWithPlayerMoney(remainingCost)
            return
        end
    end

    self:TryRepairWithPlayerMoney(totalCost)
end

function addon:SetProvider(provider)
    EasyAutoRepairDB.provider = provider
    EasyAutoRepairDB.providerPromptSignature = self:BuildProviderSignature(self:GetAvailableProviders())
    self.promptedSessionSignature = EasyAutoRepairDB.providerPromptSignature
    self:SyncProviderState(true)

    if provider == self.PROVIDER_ELVUI then
        self:Print("EasyAutoRepair repairs will stay inactive while ElvUI handles repairs.")
        return
    end

    if provider == self.PROVIDER_ZYGOR then
        self:Print("EasyAutoRepair repairs will stay inactive while Zygor handles repairs.")
        return
    end

    self:Print("ElvUI and Zygor auto repair have been disabled when available.")
end

function addon:IsProviderConfigurationOutOfSync()
    if not EasyAutoRepairDB or not EasyAutoRepairDB.enabled then
        return false
    end

    local provider = EasyAutoRepairDB.provider
    local elvMode = self:GetElvUIAutoRepairMode()
    local zygorMode = self:GetZygorAutoRepairMode()

    if provider == self.PROVIDER_EAR then
        if elvMode and elvMode ~= "NONE" then
            return true
        end

        if type(zygorMode) == "number" and zygorMode > 1 then
            return true
        end

        return false
    end

    if provider == self.PROVIDER_ELVUI then
        if elvMode and elvMode == "NONE" then
            return true
        end

        if type(zygorMode) == "number" and zygorMode > 1 then
            return true
        end

        return false
    end

    if provider == self.PROVIDER_ZYGOR then
        if elvMode and elvMode ~= "NONE" then
            return true
        end

        if zygorMode == 1 then
            return true
        end
    end

    return false
end

"""Lua 5.1 regression checks. Requires Python and `pip install lupa`.

Run from the repository root: python -m unittest discover -s tests -v
These mocks cannot reproduce WoW's secure execution or secret values.
"""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = r'''
messages, repairCalls, frames = {}, {}, {}
money, repairCost, merchantCanRepair = 1000, 100, true
guild, guildAllowed, guildPays = false, false, 0
popupAvailable, popupShows = true, 0
delayedRepairs = false
LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY, LE_GAME_ERR_NOT_ENOUGH_MONEY = 100, 101
StaticPopupDialogs, SlashCmdList = {}, {}
strlower, strmatch = string.lower, string.match
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
print = function(s) table.insert(messages, s) end
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(name, script) self[name] = script end
    table.insert(frames, frame)
    return frame
end
function Emit(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.OnEvent then frame.OnEvent(frame, event, ...) end
    end
end
function Advance(elapsed)
    for _, frame in ipairs(frames) do
        if frame.OnUpdate then frame.OnUpdate(frame, elapsed) end
    end
end
C_AddOns = { IsAddOnLoaded = function() return false end }
GetMoney = function() return money end
GetCoinTextureString = function(cost) return tostring(cost) end
CanMerchantRepair = function() return merchantCanRepair end
GetRepairAllCost = function() return repairCost, repairCost > 0 end
IsInGuild = function() return guild end
CanGuildBankRepair = function() return guildAllowed end
RepairAllItems = function(useGuild)
    table.insert(repairCalls, useGuild)
    if delayedRepairs then return end
    if useGuild then
        repairCost = math.max(0, repairCost - guildPays)
    else
        money, repairCost = money - repairCost, 0
    end
    Emit("UPDATE_INVENTORY_DURABILITY")
end
StaticPopup_Visible = function() return popup end
StaticPopup_Show = function(which, _, _, data)
    popupShows = popupShows + 1
    if not popupAvailable then
        StaticPopupDialogs[which].OnCancel(nil, data)
        return nil
    end
    popup = { which = which, data = data }
    return popup
end
function HidePopup()
    local old = popup
    popup = nil
    StaticPopupDialogs[old.which].OnHide(old, old.data)
end
function ClickPopup(index)
    local definition = StaticPopupDialogs[popup.which]
    if index == 1 then definition.OnAccept(popup, popup.data)
    elseif index == 2 then definition.OnCancel(popup, popup.data, "clicked")
    else definition.OnAlt(popup, popup.data, "clicked") end
    HidePopup()
end
function EscapePopup()
    local definition = StaticPopupDialogs[popup.which]
    if not definition.noCancelOnEscape then
        definition.OnCancel(popup, popup.data, "clicked")
    end
    HidePopup()
end
'''


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(FIXTURE)
        for name in (
            "EasyAutoRepair.lua", "EasyAutoRepair_Providers.lua",
            "EasyAutoRepair_Repair.lua", "EasyAutoRepair_Popup.lua", "EasyAutoRepair_Commands.lua",
        ):
            self.lua.execute(ROOT.joinpath(name).read_text(encoding="utf-8-sig"), "EasyAutoRepair")
        self.lua.execute('frames[1].OnEvent(nil, "ADDON_LOADED", "EasyAutoRepair")')

    def check(self, code):
        self.lua.execute(code)

    def test_all_provider_buttons(self):
        for index, provider in enumerate(("easyautorepair", "elvui", "zygor"), 1):
            with self.subTest(provider=provider):
                self.check(f'''
                    EasyAutoRepair:ShowProviderPopup({{"easyautorepair", "elvui", "zygor"}})
                    ClickPopup({index})
                    assert(EasyAutoRepairDB.provider == "{provider}")
                ''')

    def test_escape_preserves_provider_and_remembers_skip(self):
        self.check('''
            EasyAutoRepair:ShowProviderPopup({"easyautorepair", "elvui"})
            EscapePopup()
            assert(EasyAutoRepairDB.provider == "easyautorepair")
            assert(EasyAutoRepairDB.providerPromptSignatures["easyautorepair|elvui"])
        ''')

    def test_reentrant_show_preserves_original_provider_list(self):
        self.check('''
            EasyAutoRepair:ShowProviderPopup({"easyautorepair", "elvui"})
            EasyAutoRepair:ShowProviderPopup({"easyautorepair", "zygor"})
            assert(popupShows == 1)
            ClickPopup(2)
            assert(EasyAutoRepairDB.provider == "elvui")
        ''')

    def test_full_popup_slots_do_not_acknowledge_prompt(self):
        self.check('''
            popupAvailable = false
            EasyAutoRepair:ShowProviderPopup({"easyautorepair", "elvui"})
            assert(EasyAutoRepair.promptedSessionSignature == nil)
            assert(not EasyAutoRepairDB.providerPromptSignatures["easyautorepair|elvui"])
            assert(#messages == 0)
        ''')

    def test_failed_drift_prompt_can_retry(self):
        self.check('''
            ElvUI = {{ db = { general = { autoRepair = "GUILD" } } }}
            popupAvailable = false
            EasyAutoRepair:MaybePromptForProviderSelection("merchant")
            popupAvailable = true
            EasyAutoRepair:MaybePromptForProviderSelection("merchant")
            assert(popupShows == 2 and popup)
            ClickPopup(2)
            assert(EasyAutoRepairDB.provider == "elvui")
        ''')

    def test_dismissed_prompt_does_not_repeat(self):
        self.check('''
            ElvUI = {{ db = { general = { autoRepair = "NONE" } } }}
            EasyAutoRepair:MaybePromptForProviderSelection("status")
            EscapePopup()
            EasyAutoRepair:MaybePromptForProviderSelection("status")
            assert(popupShows == 1)
        ''')

    def test_personal_repair(self):
        self.check('''
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1 and repairCalls[1] == false)
            assert(money == 900 and repairCost == 0)
            assert(#messages == 0)
            Advance(0.1)
            assert(messages[1]:find("Repaired with personal funds for 100", 1, true))
        ''')

    def test_insufficient_personal_funds(self):
        self.check('''
            money = 10
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 0)
            assert(messages[1]:find("Not enough money", 1, true))
        ''')

    def test_guild_repair_synchronous_success(self):
        self.check('''
            guild, guildAllowed, guildPays = true, true, 100
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1 and repairCalls[1] == true)
            assert(money == 1000 and repairCost == 0)
            assert(#messages == 0)
            Advance(0.1)
            assert(messages[1]:find("Repaired with guild funds", 1, true))
        ''')

    def test_partial_guild_repair_synchronous_fallback(self):
        self.check('''
            guild, guildAllowed, guildPays = true, true, 40
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1)
            Advance(0.1)
            assert(#repairCalls == 2 and repairCalls[1] and not repairCalls[2])
            assert(money == 940 and repairCost == 0)
            Advance(0.1)
            assert(#messages == 2)
        ''')

    def test_missing_optional_guild_api(self):
        self.lua = LuaRuntime()
        self.lua.execute(FIXTURE + '\nCanGuildBankRepair = nil; guild = true')
        for name in ("EasyAutoRepair.lua", "EasyAutoRepair_Providers.lua", "EasyAutoRepair_Repair.lua"):
            self.lua.execute(ROOT.joinpath(name).read_text(), "EasyAutoRepair")
        self.check('''
            EasyAutoRepair:InitializeDatabase()
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1 and not repairCalls[1])
        ''')

    def test_no_repair_when_disabled_or_other_provider_or_wrong_vendor(self):
        self.check('''
            EasyAutoRepairDB.enabled = false
            EasyAutoRepair:HandleMerchantShow()
            EasyAutoRepairDB.enabled = true
            EasyAutoRepairDB.provider = "elvui"
            EasyAutoRepair:HandleMerchantShow()
            EasyAutoRepairDB.provider = "easyautorepair"
            merchantCanRepair = false
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 0)
        ''')

    def test_elvui_profile_update_does_not_call_unrelated_save_hook(self):
        self.check('''
            ElvUI = {{ db = { general = {} }, SaveSettings = function() error("unexpected save hook") end }}
            assert(EasyAutoRepair:SetElvUIAutoRepair(true))
            assert(ElvUI[1].db.general.autoRepair == "GUILD")
            EasyAutoRepair:SetElvUIAutoRepair(false)
            assert(ElvUI[1].db.general.autoRepair == "NONE")
        ''')

    def test_zygor_mode_preserved(self):
        self.check('''
            ZGV = { db = { profile = { autorepair = 4 } } }
            EasyAutoRepair:SetZygorAutoRepair(false)
            assert(ZGV.db.profile.autorepair == 1)
            EasyAutoRepair:SetZygorAutoRepair(true)
            assert(ZGV.db.profile.autorepair == 4)
        ''')

    def test_slash_commands(self):
        self.check('''
            SlashCmdList.EASYAUTOREPAIR(" OFF ")
            assert(not EasyAutoRepairDB.enabled)
            SlashCmdList.EASYAUTOREPAIR("on")
            assert(EasyAutoRepairDB.enabled)
            SlashCmdList.EASYAUTOREPAIR("provider elvui")
            assert(EasyAutoRepairDB.provider == "elvui")
            SlashCmdList.EASYAUTOREPAIR("provider ear")
            assert(EasyAutoRepairDB.provider == "easyautorepair")
        ''')

    def test_delayed_guild_result_must_not_start_personal_repair(self):
        self.check('''
            guild, guildAllowed = true, true
            delayedRepairs = true
        ''')
        self.check('''
            EasyAutoRepair:HandleMerchantShow()
            Advance(1)
            assert(#repairCalls == 1)
            assert(#messages == 0)
        ''')

    def test_refused_personal_repair_must_not_report_success(self):
        self.check('delayedRepairs = true')
        self.check('''
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_NOT_ENOUGH_MONEY)
            Advance(1)
            assert(not messages[1] or not messages[1]:find("Repaired with personal funds", 1, true))
            assert(messages[1]:find("Not enough money", 1, true))
            assert(frames[2].OnUpdate == nil)
        ''')

    def test_delayed_guild_success_never_spends_personal_money(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Advance(2)
            assert(#repairCalls == 1 and #messages == 0)
            repairCost = 0
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(#repairCalls == 1 and money == 1000)
            assert(messages[1]:find("Repaired with guild funds", 1, true))
            assert(frames[2].OnUpdate == nil and next(frames[2].events) == nil)
        ''')

    def test_guild_refusal_falls_back_once_at_current_quote(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            repairCost = 80
            Advance(0.1)
            assert(#repairCalls == 2 and not repairCalls[2] and #messages == 0)
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            Advance(0.1)
            assert(#repairCalls == 2)
            repairCost = 0
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(messages[1]:find("Repaired with personal funds for 80", 1, true))
        ''')

    def test_guild_refusal_without_personal_funds(self):
        self.check('''
            guild, guildAllowed, delayedRepairs, money = true, true, true, 0
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            Advance(0.1)
            assert(#repairCalls == 1)
            assert(messages[1]:find("Not enough money", 1, true))
        ''')

    def test_durability_event_before_quote_refresh(self):
        self.check('''
            delayedRepairs = true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(#messages == 0)
            repairCost = 0
            Advance(0.1)
            assert(messages[1]:find("Repaired with personal funds", 1, true))
        ''')

    def test_unrelated_durability_and_errors_do_not_trigger_fallback(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UPDATE_INVENTORY_DURABILITY")
            Emit("UI_ERROR_MESSAGE", 999)
            Advance(1)
            assert(#repairCalls == 1 and #messages == 0)
        ''')

    def test_quote_change_without_durability_event_is_not_success(self):
        self.check('''
            delayedRepairs = true
            EasyAutoRepair:HandleMerchantShow()
            repairCost = 0
            Advance(1)
            assert(#messages == 0)
        ''')

    def test_timeout_does_not_guess_guild_failure(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Advance(5.1)
            assert(#repairCalls == 1)
            assert(messages[1]:find("not confirmed", 1, true))
            assert(frames[2].OnUpdate == nil and next(frames[2].events) == nil)
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1)
            repairCost = 0
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(1)
            assert(#messages == 1)
        ''')

    def test_merchant_close_cancels_followup_and_allows_next_visit(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            Emit("MERCHANT_CLOSED")
            Advance(10)
            assert(#repairCalls == 1 and #messages == 0)
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 2 and repairCalls[2])
        ''')

    def test_duplicate_merchant_event_does_not_repeat_repair(self):
        self.check('''
            EasyAutoRepair:HandleMerchantShow()
            EasyAutoRepair:HandleMerchantShow()
            Advance(0.1)
            EasyAutoRepair:HandleMerchantShow()
            assert(#repairCalls == 1 and #messages == 1)
        ''')

    def test_disable_cancels_pending_fallback(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            SlashCmdList.EASYAUTOREPAIR("off")
            Advance(10)
            assert(#repairCalls == 1 and frames[2].OnUpdate == nil)
        ''')

    def test_provider_change_cancels_pending_fallback(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            Emit("UI_ERROR_MESSAGE", LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY)
            SlashCmdList.EASYAUTOREPAIR("provider elvui")
            Advance(10)
            assert(#repairCalls == 1 and frames[2].OnUpdate == nil)
        ''')

    def test_world_exit_cancels_pending_work(self):
        self.check('''
            delayedRepairs = true
            EasyAutoRepair:HandleMerchantShow()
            Emit("PLAYER_LEAVING_WORLD")
            repairCost = 0
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(10)
            assert(#messages == 0 and frames[2].OnUpdate == nil)
        ''')

    def test_delayed_partial_guild_then_delayed_personal_confirmation(self):
        self.check('''
            guild, guildAllowed, delayedRepairs = true, true, true
            EasyAutoRepair:HandleMerchantShow()
            repairCost = 60
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(#repairCalls == 2 and not repairCalls[2])
            assert(#messages == 1 and messages[1]:find("Guild covered 40", 1, true))
            Advance(1)
            assert(#messages == 1)
            repairCost = 0
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(messages[2]:find("Repaired with personal funds for 60", 1, true))
        ''')

    def test_partial_personal_result_does_not_claim_full_repair(self):
        self.check('''
            delayedRepairs = true
            EasyAutoRepair:HandleMerchantShow()
            repairCost = 50
            Emit("UPDATE_INVENTORY_DURABILITY")
            Advance(0.1)
            assert(messages[1]:find("some repairs remain", 1, true))
            assert(#repairCalls == 1 and frames[2].OnUpdate == nil)
        ''')

    def test_secret_cost_capability_guard_skips_request(self):
        # A capability stub checks the guard, not WoW's actual secret semantics.
        self.check('''
            secret = {}
            issecretvalue = function(value) return value == secret end
            GetRepairAllCost = function() return secret, true end
        ''')
        self.lua.execute(ROOT.joinpath("EasyAutoRepair_Repair.lua").read_text())
        self.check('EasyAutoRepair:HandleMerchantShow(); assert(#repairCalls == 0)')

    def test_secret_money_capability_guard_skips_request(self):
        self.check('''
            secret = {}
            issecretvalue = function(value) return value == secret end
            GetMoney = function() return secret end
        ''')
        self.lua.execute(ROOT.joinpath("EasyAutoRepair_Repair.lua").read_text())
        self.check('EasyAutoRepair:HandleMerchantShow(); assert(#repairCalls == 0)')


if __name__ == "__main__":
    unittest.main()

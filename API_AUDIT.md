# Retail 12.1.5 API and taint audit

Reviewed on 2026-10-23 against EasyAutoRepair 1.13, updated for the 1.14 fixes,
and the public UI source
mirror's `live` branch. This is a source review and mocked Lua 5.1 execution,
not an in-client certification. The linked branches can change.

## API inventory

| Area | Calls or data | Result |
| --- | --- | --- |
| Bootstrap | `CreateFrame`, `RegisterEvent`, `SetScript`, `ADDON_LOADED`, `PLAYER_LOGIN`, `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `PLAYER_LEAVING_WORLD` | No migration identified for the events and plain addon frames used here. |
| Addon detection | `C_AddOns.IsAddOnLoaded`, legacy `IsAddOnLoaded` fallback | Modern namespace already preferred; configuration access is guarded by engine/database table checks. The modern API can report loaded-or-loading in its first return, so detection alone is not proof a provider is initialized. |
| Repairs | `CanMerchantRepair`, `GetRepairAllCost`, `RepairAllItems`, `GetMoney`, `GetCoinTextureString`, `UPDATE_INVENTORY_DURABILITY`, `UI_ERROR_MESSAGE` | No namespace migration identified. The new repair module observes outcomes instead of assuming immediate success. |
| Guild funds | `IsInGuild`, optional `CanGuildBankRepair` | Existing capability guard handles clients without guild repair support. |
| Popup | `StaticPopupDialogs`, `StaticPopup_Show`, `StaticPopup_Visible` | Fixed the callback signature and popup lifecycle issues below. `OnAlt` remains supported by the legacy callback path; this addon does not enable `selectCallbackByIndex`. |
| Commands | `SlashCmdList`, `SLASH_EASYAUTOREPAIR1`, `strtrim`, `strlower`, `strmatch` | No migration identified for the calls used here. Input comes from slash commands, not combat APIs. |
| ElvUI | `engine.db.general.autoRepair` | Current ElvUI repair code reads this setting directly and expects `NONE`, `GUILD`, or `PLAYER`. Removed an unnecessary optional `SaveSettings` hook call. This is a third-party profile integration, not a Blizzard API guarantee. |
| Zygor | `engine.db.profile.autorepair`, `engine.IsClassic` | Preserves existing modes. No current licensed Zygor source/client was available to verify this private integration; mock coverage cannot certify current Zygor compatibility. |

## Fixed locally

- The second provider button read the wrong callback argument. Blizzard calls
  `OnCancel(dialog, data, reason)`; the addon treated `data` as the reason.
- Escape can also pass the reason `clicked`. Added `noCancelOnEscape`, with
  dismissal handled by `OnHide`, so Escape never selects provider 2.
- Repeated requests no longer replace an open popup's definition/provider data.
  Each shown popup has its own selection state.
- A failed popup display (for example, all dialog slots occupied) no longer
  acknowledges the choice or consumes the session's drift prompt. It can retry.
- Provider synchronization no longer invokes an optional, unrelated ElvUI
  save hook. Writing the specific profile field is sufficient for the current
  repair module. This reduces unnecessary third-party calls; it is not proof
  that the removed call caused taint.
- Repair results are now observed asynchronously; see below.

## Secret values and taint

The addon does not query unit health, auras, combat logs, spell cooldowns, or
other combat-data sources commonly subject to secret-value restrictions.
Provider comparisons use addon configuration, and popup labels are addon-owned
strings. No direct secret-value consumer was identified in the current code.
This does not prove all merchant data is readable under every client condition.
The repair module guards numeric money/cost inputs and the initial repair flag
with the optional `issecretvalue` capability before comparing them; it skips
unreadable inputs rather than trying to unwrap them.

The addon creates a plain event frame and its own popup definition. It does not
replace Blizzard functions, hook protected actions, modify secure frame
attributes, or manipulate action buttons. The popup uses Blizzard's supported
addon dialog path, which itself contains taint isolation logic. Sharing that
path or another addon's profile does not establish that an entire session is
taint-free. `pcall` would not make protected operations secure or remove taint;
no such workaround is used.

No blanket combat guard or speculative `C_MerchantFrame` replacements were added:
the reviewed code gives no evidence those changes are required for these calls.

## Repair result fixes in 1.14

The two issues identified in 1.13 are fixed in `EasyAutoRepair_Repair.lua`:

1. **Guild fallback waits for evidence.** A durability update plus a lower repair
   quote confirms progress. A partial guild result permits one personal-funds
   request for the remaining quote. A known guild money refusal also permits
   fallback, using a fresh quote and checking personal funds. An unchanged quote,
   unrelated error, or elapsed time alone never authorizes personal fallback.
2. **Success requires confirmation.** The addon reports success only after a
   durability event and an observed quote reduction. A refused request therefore
   cannot produce the old immediate success message. Printed amounts describe
   the confirmed reduction in repair cost, not a separately measured wallet debit.

The observer is installed before requesting a repair. It checks results at most
every 0.1 seconds, handles durability events arriving before quote refresh, and
stops after five seconds without confirmation. Each vendor visit permits one
initial request and at most one guild-to-personal fallback. A timeout reports an
unconfirmed outcome and does not trigger fallback or automatic retries.

Merchant close, world exit, disabling the addon, or changing the provider cancels
pending observation and follow-up actions. Already sent server requests cannot
be canceled. Closing and reopening the merchant starts a new visit. Success,
refusal, timeout, and cancellation remove the temporary event registrations and
the `OnUpdate` observer.

WoW provides no repair request identifier in the events used here. Attribution
assumes that the player does not manually repair or change equipment while the
addon is awaiting a result. Unsupported guild refusal codes are handled
conservatively by waiting for confirmation or timeout, rather than guessing a
failure. Real client event timing and taint behavior still require in-game QA.

## Validation

Run with Python and `lupa` installed:

```text
python -m unittest discover -s tests -v
```

Result: 33 tests passed, including the two previously expected failures. Tests
execute the actual addon modules in Lua 5.1 with mocked WoW APIs.
They cover all three popup buttons, Escape, duplicate prompts, full popup slots,
retry after failure, personal/guild repairs with synchronous results, missing
guild APIs, disabled/delegated repairs, slash commands, and provider settings.
They do not emulate WoW's secure execution engine or genuine secret values.

In Retail 12.1.5, enable `/console scriptErrors 1` and `/console taintLog 1`,
then `/reload`. Test each popup choice and Escape, vendor interactions, personal
and guild repairs (including insufficient funds and refusals), and provider changes through
ElvUI/Zygor. Include combat entry/exit and opening a vendor while in combat where
possible. Check Lua errors, blocked-action messages, actual money/durability
changes, and `Logs/taint.log`. Repeat with only EasyAutoRepair enabled and then
with the providers, so errors can be attributed. Turn logging off afterward with
`/console taintLog 0`. Record the exact client build from `GetBuildInfo()`.

## Sources

- [Blizzard StaticPopup source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua): callback argument order, legacy `OnAlt`, `noCancelOnEscape`, no-slot cancellation, `OnHide`, and taint isolation.
- [Blizzard merchant UI source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua): merchant and repair globals still used by the UI.
- [Blizzard addon API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua): modern addon detection and loading events.
- [ElvUI repair implementation](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Modules/Misc/Misc.lua): profile modes, delayed repair reporting, and error-based fallback.

# EasyAutoRepair Changelog
All notable changes to this project will be documented in this file.

## Version 1.10 (2026-06-17):
- Updated the Retail TOC interface version for WoW build `120007`.
- Synchronized Retail, Mists, TBC, and Vanilla addon versions to `1.10`.

## Version 1.09 (2026-06-07):
- Remember multiple approved provider signatures so characters with different addon combinations do not keep re-triggering the provider popup.
- Improved cross-character behavior when Zygor is enabled on some characters but not others.

## Version 1.08 (2026-06-06):
- Reduced repeated login prompts by limiting drift-based provider re-prompts to active usage moments like vendors and `/ear status`.
- Polished the provider popup behavior after real-world testing with ElvUI and Zygor.
- Remembered multiple accepted provider setups so characters with different enabled addons do not keep re-triggering the popup.

## Version 1.07 (2026-05-06):
- Reworked TOC packaging to match the EasyDelete layout with Retail, Mists, TBC, and Vanilla variants.
- Added a repair provider preference so players can choose between EasyAutoRepair, ElvUI, and Zygor.
- Automatically disables ElvUI auto repair when EasyAutoRepair is preferred.
- Keeps EasyAutoRepair repair handling inactive when ElvUI is preferred.
- Added new slash commands for provider selection and improved status output.
- Added Zygor as an additional repair provider option.
- Added direct Zygor auto-repair synchronization using Zygor's own `autorepair` profile setting.
- Zygor is now fully enabled when selected as provider and disabled automatically when another provider is preferred.
- ElvUI and Zygor auto-repair are both disabled automatically when EasyAutoRepair is the preferred provider.
- Added a login/reload provider selection popup when multiple repair providers are detected.
- The popup remembers your choice for the current detected provider setup.
- Manual `/ear provider ...` selection now also suppresses repeat prompts for the same setup.
- Improved ElvUI detection to handle load-order and API differences more reliably.
- Fixed ElvUI provider syncing so EasyAutoRepair now correctly disables ElvUI auto repair by setting its expected string mode values.
- Zygor provider switching now preserves the player's existing Zygor auto-repair mode and restores it when Zygor is re-enabled.
- Split the addon into smaller internal modules for bootstrap, providers, popup handling, and slash commands.
- Added provider drift detection so the popup returns when ElvUI or Zygor settings are changed outside EasyAutoRepair.

## Version 1.06 (2026-04-22):
- Updated Retail TOC interface version for WoW build `120005`.
- Synchronized Retail, Classic, and MoP addon versions to `1.06`.

## Version 1.05 (2026-04-04):
- Improved addon initialization by loading saved settings through `ADDON_LOADED`.
- Refined auto-repair flow to better handle guild-funded and personal-funded repairs.
- Reduced unnecessary chat output and made repair/status messages more consistent.
- Expanded `/ear` commands with `on`, `off`, `toggle`, and `status` options while keeping `/ear` as a toggle.
- Synchronized Retail, Classic, and MoP TOC versions to `1.05`.

## Version 1.04 (2026-02-22):
- Updated addon for Midnight build version 120001.

## Version 1.03 (2025-12-04):
- Updated addon for The War Within build version 110207. (The Warning)

## Version 1.02 (2025-09-23):
- Changed TOC version for incompatibility with client -> 110205 to 110200
- Changed TOC to 3 files - Retail, MoP and Classic
- Localized global functions.
- Combined conditions for MERCHANT_SHOW.
- Minor message consistency.

## Version 1.01 (2025-08-29):
- Updated addon for The War Within build version 110205. (Ghosts of K'aresh)

## Version 1.00 (2025-07-23):
- Initial release of EasyAutoRepair.
- Automatically repairs your gear when visiting a vendor.
- Uses guild funds first if available, then personal gold.
- Slash command `/ear` to enable/disable.








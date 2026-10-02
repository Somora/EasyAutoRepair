# EasyAutoRepair

**EasyAutoRepair** is a lightweight World of Warcraft addon that automatically repairs your equipment when visiting a vendor. It uses guild funds first when available, falls back to your own money when needed, and remembers your preference between sessions.

Current release: `1.12`

---

## 🔧 Features

- ✅ Automatically repairs gear when opening a merchant window
- 🏦 Uses guild bank funds first (if allowed)
- 💰 Falls back to personal funds if guild funds do not fully cover repairs
- 💬 Clear status and repair messages in chat
- 🔁 Toggle or control the addon via `/ear` slash commands
- ⚖️ Choose whether EasyAutoRepair, ElvUI, or Zygor should handle repairs
- 🪟 Shows a provider selection popup when multiple repair addons are detected
- 💾 Remembers your setting across sessions
- 📦 Versioned for Retail, Forever, Mists, TBC, and Vanilla clients

---

## 💬 Slash Commands

| Command | Description |
|---------|-------------|
| `/ear` | Toggle automatic repairs on or off |
| `/ear on` | Enable automatic repairs |
| `/ear off` | Disable automatic repairs |
| `/ear toggle` | Toggle automatic repairs on or off |
| `/ear status` | Show whether auto repair is enabled |
| `/ear provider easyautorepair` | Let EasyAutoRepair handle repairs and disable ElvUI auto repair when available |
| `/ear provider elvui` | Let ElvUI handle repairs and keep EasyAutoRepair repair logic inactive |
| `/ear provider zygor` | Let Zygor handle repairs, enable Zygor auto repair, and keep EasyAutoRepair repair logic inactive |

---

## 📦 Installation

1. Download and unzip the addon.
2. Copy the `EasyAutoRepair` folder into:  
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart the game or type `/reload`.
4. Enable the addon in the character select AddOns menu.

### WoW: Forever

The Forever client uses `EasyAutoRepair_Camelot.toc` with interface `16001`
(client version `1.60.1`). All Lua modules and saved settings use the same layout
as the other supported clients. Guild funds are used only when the client offers
guild bank repairs; otherwise the addon uses personal funds.

For the Forever beta, copy the `EasyAutoRepair` folder into
`World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the client.
For other installations, use the `Interface/AddOns/` directory inside the
Forever client folder. Keep the addon folder named `EasyAutoRepair`.

The compatibility changes have not yet been tested in the Forever client.
To verify them, enable Lua errors with `/console scriptErrors 1`, check
`/ear status`, and visit a repair vendor with damaged gear. Check personal
repairs, insufficient funds, guild repairs when available, and the provider
popup with compatible ElvUI/Zygor versions. Use `/reload` and log out/in to
verify that your settings persist. Beta interface versions may change; check
the installed version with `/dump select(4, GetBuildInfo())`.

---

## 🧑‍💻 Contributing

Pull requests and suggestions are welcome! Open an issue or PR to contribute.

---

## 📄 License

This addon is released under the GPL-3.0 License.

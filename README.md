# EasyAutoRepair

**EasyAutoRepair** is a lightweight World of Warcraft addon that automatically repairs your equipment when visiting a vendor. It uses guild funds first when available, falls back to your own money when needed, and remembers your preference between sessions.

Current release: `1.07`

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
- 📦 Versioned for Retail, Mists, TBC, and Vanilla clients

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

---

## 🧑‍💻 Contributing

Pull requests and suggestions are welcome! Open an issue or PR to contribute.

---

## 📄 License

This addon is released under the GPL-3.0 License.

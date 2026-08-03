<div align="center">

# 🚀 Windows 11 & WSL Environment Setup 🚀

Automated, high-performance environment setup scripts and configuration dotfiles for Windows 11 and WSL.

</div>

---

## ⚡ Quick Start

### 1️⃣ Pre-Setup (Timezone, Hostname & Rotation)
```powershell
iwr -useb raw.githubusercontent.com/aaxyat/WindowsSetup/main/presetup.ps1 | iex
```

### 2️⃣ System & Profile Setup
```powershell
iwr -useb l.ayushb.com/setup | iex
```

### 3️⃣ Package & Apps Installation
```powershell
pwsh -File ./install-apps.ps1
```

### 4️⃣ Microsoft 365 / Office Setup & Activation
```powershell
pwsh -File ./office.ps1
```

---

## 📜 Scripts Overview

| Script | Purpose & Features |
| :--- | :--- |
| **`presetup.ps1`** | Sets timezone (Nepal Standard Time UTC+5:45), hardware-based hostname assignment (`Turing` for HP Envy x360, `Titan` for Gigabyte A520M), and display auto-rotation settings for laptops. |
| **`script.ps1`** | Main bootstrap script. Installs Chocolatey & PowerShell 7, auto-relaunches in `pwsh`, configures Windows Terminal, Starship prompt, system PATHs, and Astral `uv`. |
| **`install-apps.ps1`** | Package manager script installing WinGet & Chocolatey packages including Atuin, LocalSend, PowerToys, Steam, VS Code, and development tools. |
| **`office.ps1`** | Standalone installer for Microsoft 365. Downloads Click-To-Run (C2R) from Microsoft CDN with file integrity checking, fallback to WinGet, and automatic MAS Ohook activation. |
| **`wsl-setup.sh`** | WSL (Ubuntu) environment setup with Fish shell, Fisher, NVM, Pyenv, Poetry, Astral `uv`, `fastfetch`, and Git credential manager integration. |

---

## ⚡ PowerShell Profile & Features

The repository includes an ultra-fast, optimized PowerShell profile ([`Microsoft.PowerShell_profile.ps1`](file:///c:/Users/aaxyat/Documents/Github/WindowsSetup/ConfigFiles/Microsoft.PowerShell_profile.ps1)):

- **~60 ms Startup Speed**: Uses lazy initialization to defer heavy prompt themes and prediction engines until first prompt render.
- **Atuin Shell History Sync**: Integrated with Atuin (`Atuinsh.Atuin`) using a compact 10-line inline search UI.
- **`activate` Function**: Single-command Windows HWID & Office Ohook activation with inline `gsudo` / `sudo` elevation:
  ```powershell
  activate
  ```
- **Helper Shortcuts (`s`)**: Type `s` to view all custom aliases (`acm`, `lazyg`, `cinst`, `doh`, `merge-mp4`, `atuin`, `activate`).

---

## 🔄 Atuin History Import

To import your previous PowerShell command history into Atuin's encrypted SQLite database:

```powershell
atuin import auto
```

---

## 📂 Configuration Files (`ConfigFiles/`)

- `Microsoft.PowerShell_profile.ps1`: Optimized PowerShell 7 profile.
- `settings.json`: Windows Terminal custom color themes & settings.
- `shortcuts.exe` / `shortcuts.ahk`: AutoHotkey hotkey shortcuts utility.
- `starship.toml`: Custom Starship cross-shell prompt configuration.

---

## 🤝 Contributing & License

Contributions and pull requests are welcome! Licensed under the [MIT License](LICENSE).

<div align="center">

### Built with ❤️ by [aaxyat](https://github.com/aaxyat)

</div>

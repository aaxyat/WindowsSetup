<div align="center">

# 🚀 Windows 11 & WSL Environment Setup 🚀

Automated, high-performance environment setup scripts and configuration dotfiles for Windows 11 and WSL.

</div>

---

## ⚡ Quick Start

### 1️⃣ Pre-Setup (Timezone, Hostname & Rotation)
```powershell
irm https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/presetup.ps1 | iex
```

### 2️⃣ System & Profile Setup
```powershell
irm https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/script.ps1 | iex
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
| **`script.ps1`** | Main bootstrap script. Installs Chocolatey & PowerShell 7, auto-relaunches in `pwsh`, enables Windows Long Paths (`LongPathsEnabled = 1`), Developer Mode, global Git settings (`autocrlf`, `autoSetupRemote`, `histogram`), Starship prompt, system PATHs, and Astral `uv`. |
| **`install-apps.ps1`** | Package manager installer with interactive UI card, progress bar, **fast pre-install self-check (~0.3s)**, **persistent JSON state tracking** across crashes/reboots, **interactive `'n'` key package skip**, and 5-minute timeout protection. Installs WinGet & Chocolatey tools including Atuin, Flow Launcher, LocalSend, PowerToys, Steam, VS Code, etc. |
| **`office.ps1`** | Standalone installer for Microsoft 365. Downloads Click-To-Run (C2R) from Microsoft CDN with file integrity checking, inline `gsudo` elevation, fallback to WinGet, and automatic MAS Ohook activation. |
| **`wsl-setup.sh`** | WSL (Ubuntu) environment setup with Fish shell, Fisher, NVM, Pyenv, Poetry, Astral `uv`, `fastfetch`, and Git credential manager integration. |

---

## ⚡ PowerShell Profile & Features

The repository includes an ultra-fast, optimized PowerShell profile ([`Microsoft.PowerShell_profile.ps1`](file:///c:/Users/aaxyat/Documents/Github/WindowsSetup/ConfigFiles/Microsoft.PowerShell_profile.ps1)):

- **~60 ms Startup Speed**: Uses lazy initialization to defer heavy prompt themes and prediction engines until first prompt render.
- **Atuin E2EE Shell History Sync**: Integrated with Atuin (`Atuinsh.Atuin`) using a compact inline search UI.
- **`activate` Function**: One-command Windows HWID & Office Ohook activation with inline `gsudo` / `sudo` elevation:
  ```powershell
  activate
  ```
- **`sysinfo` Command**: Displays CPU model, RAM usage, Drive C:\ space, and Uptime in a colorized dashboard.
- **`flushdns` Command**: One-command DNS resolver cache flush.
- **Quick Directory Shortcuts**: `g` (`~/Documents/Github`), `p` (`~/Documents/Projects`), `x` (`C:\xampp\htdocs`).
- **Helper Shortcuts (`s`)**: Type `s` to view all custom aliases.

---

## 🔄 Atuin History Restore

To restore your synced command history on a new Windows installation:

```powershell
atuin login -u aaxyat
# (Paste 24-word encryption key when prompted)
atuin sync
```

---

## 📂 Configuration Files (`ConfigFiles/`)

- `Microsoft.PowerShell_profile.ps1`: Optimized PowerShell 7 profile.
- `settings.json`: Windows Terminal configuration with **Direct3D 11 GPU Acceleration**, compact tabs, and Dracula theme.
- `shortcuts.exe` / `shortcuts.ahk`: AutoHotkey hotkey shortcuts (`Ctrl+Alt+T` Terminal, `Ctrl+Alt+B` Bitwarden).
- `starship.toml`: Custom Starship prompt configuration optimized with sub-1000ms timeouts.

---

## 🤝 Contributing & License

Contributions and pull requests are welcome! Licensed under the [MIT License](LICENSE).

<div align="center">

### Built with ❤️ by [aaxyat](https://github.com/aaxyat)

</div>

<div align="center">

# 🚀 Windows 11 and WSL Setup Script 🚀

This repository contains scripts and configuration files for setting up Windows 11 and WSL environments.

</div>

---

# Windows Setup

## 📡 Fetching and Executing the Setup Script 📡

To fetch and execute the setup script in PowerShell, open PowerShell and run the following command:

```powershell
iwr -useb l.ayushb.com/setup | iex
```

This command uses `iwr` (an alias for `Invoke-WebRequest`) to fetch the script from the provided URL and pipes it to `iex` (an alias for `Invoke-Expression`) to execute the fetched script.

# WSL Setup

This repository includes a script to set up Windows Subsystem for Linux (WSL) with common developer tools and configurations.

## What the WSL Setup Script Installs

- apt-fast for accelerated package installation
- Essential build tools and utilities
- Fish shell with Oh My Fish and bira theme
- Fisher plugin manager for Fish
- Fastfetch (with neofetch alias) for system information
- Git with personalized configuration
- Python development tools:
  - Pyenv for Python version management
  - Poetry for Python package management
  - uv for faster Python package installation
- Node.js development tools:
  - NVM (Node Version Manager with Fish support)
  - pnpm for efficient Node package management
- Convenient directory structure:
  - ~/Github for GitHub repositories
  - ~/Projects for development projects

## How to Use the WSL Script

To run the script directly via curl, use:

```bash
curl -fsSL https://l.ayushb.com/wsl | bash
```

### Manual Installation

If you prefer to review the script before running it:

1. Download the script:
   ```bash
   curl -O https://l.ayushb.com/wsl
   ```

2. Make it executable:
   ```bash
   chmod +x wsl-setup.sh
   ```

3. Run it:
   ```bash
   ./wsl-setup.sh
   ```

### Post-Installation

After running the script:
1. Restart your WSL terminal to apply all changes
2. The script will have set Fish as your default shell
3. Use the aliases `g` to quickly navigate to ~/Github and `p` to navigate to ~/Projects
4. Run `fastfetch` or `neofetch` to see your system information
5. Use pyenv to install Python versions: `pyenv install 3.10.0`
6. Use Poetry for Python project management: `poetry new my-project`
7. Use pnpm for Node.js package management: `pnpm install <package>`
8. Use uv for faster Python package installation: `uv pip install <package>`

## 📂 Configuration Files 📂

The `ConfigFiles` directory contains various configuration files that are used by the setup script:

- `Microsoft.PowerShell_profile.ps1`: This is the PowerShell profile file.
- `settings.json`: This file contains settings for windows terminal.
- `shortcuts.ahk` and `shortcuts.exe`: These files are used for setting up keyboard shortcuts.
- `sshd_config`: This is the configuration file for SSH daemon.
- `starship.toml`: This is the configuration file for Starship, a customizable prompt for any shell.

# 🎯 Development 🎯

## 🛠️ Requirements 🛠️

- VirtualBox (Optional)
- Windows 11 ISO (Optional)

To get a local copy up and running, follow these simple steps:

1. Clone the repository to your local machine:

   ```sh
   git clone https://github.com/aaxyat/WindowsSetup.git
   ```

2. Navigate to the cloned repository:

   ```sh
   cd WindowsSetup
   ```

## 🧪 Testing the Setup Script 🧪

Run your setup script and test the environment as needed.

## 🤝 Contributing 🤝

Contributions, issues, and feature requests are welcome! Please read `CONTRIBUTING.md` for details on our code of conduct, and the process for submitting pull requests to us.

## 📝 License 📝

This project is licensed under the terms of the MIT license. See the `LICENSE` file for details.

<div align="center">

### Built with ❤️ by [aaxyat](https://github.com/aaxyat)

</div>

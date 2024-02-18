<div align="center">

# 🚀 Windows 11 Setup Script Testing Environment 🚀

This repository contains scripts and configuration files for setting up a Windows 11 environment.

</div>

---

## 📡 Fetching and Executing the Setup Script 📡

To fetch and execute the setup script in PowerShell, open PowerShell and run the following command:

```powershell
iwr -useb l.ayushb.com/setup | iex
```

This command uses `iwr` (an alias for `Invoke-WebRequest`) to fetch the script from the provided URL and pipes it to `iex` (an alias for `Invoke-Expression`) to execute the fetched script.

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
   git clone https://github.com/aaxyat/WinndowsSetup.git
   ```

2. Navigate to the cloned repository:

   ```sh
   cd WinndowsSetup
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

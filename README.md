# 🛠️ Windows 11 Setup Script Testing Environment 🛠️

This repository contains scripts for setting up a Windows 11 environment.

## 🚀 Fetching and Executing the Setup Script 🚀

To fetch and execute the setup script in PowerShell, open PowerShell and run the following command:

```powershell
iwr -useb l.ayushb.com/setup | iex
```

This command uses `iwr` (an alias for `Invoke-WebRequest`) to fetch the script from the provided URL and pipes it to `iex` (an alias for `Invoke-Expression`) to execute the fetched script.

## 💻 Development 💻

### Requirements

- [VirtualBox](https://www.virtualbox.org/) (Optional)
- [Windows 11 ISO](https://www.microsoft.com/software-download/windows11) (Optional)

### Testing the Setup Script

1. Run your setup script.
2. Test the environment as needed.

## 📈 Stats 📈

- Scripts written: 1
- Lines of code: 100 (approximate)
- Coffee cups consumed: ☕☕☕

## 🤝 Contribution 🤝

Contributions are always welcome! Please read the [contribution guidelines](CONTRIBUTING.md) first.

## 📜 License 📜

This project is licensed under the terms of the MIT license.

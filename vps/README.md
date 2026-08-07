# VPS & WSL Environment Setup Automation

Automated shell scripts for initializing and managing Oracle Cloud VPS instances and local Windows Subsystem for Linux (WSL) environments.

## 🚀 Quick Start Guide

### 1. Ubuntu WSL Environment Setup (Local Windows PC)
To configure your local Ubuntu WSL environment in a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/vps/wslsetup.sh | sudo bash
# Run automated self-test suite:
bash wslsetup.sh --test
```

---

### 2. Ubuntu WSL PHP Dev Environment Setup (XAMPP-like)
To install Apache2 + PHP + MariaDB + phpMyAdmin with `/home/aaxyat/projects/php` DocumentRoot, `newsite` CLI manager, and wildcard `*.local` Virtual Hosts:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/vps/wsldev.sh | sudo bash
# OR run locally inside WSL:
bash wsldev.sh
```

---

### 3. VPS Full Initial Setup (Oracle Cloud / Debian)
Once your VPS reboots, SSH in as `root` and run `setup.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/vps/setup.sh | sudo bash
# OR run locally:
bash setup.sh
```

---

### 4. Reset / Re-install VPS OS
To reset your Oracle VPS back to a clean Debian 13 OS using `debi.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/vps/reset.sh | sudo bash
# OR run locally:
bash reset.sh
```

---

## 🌐 Virtual Host Management with `newsite` CLI

The `wsldev.sh` engine installs the **`newsite`** CLI manager into `/usr/local/bin/newsite`:

```bash
# 1. Create a new site (Creates ~/projects/php/mims, /etc/apache2/sites-available/mims.conf, enables site & updates Windows hosts file)
newsite mims

# 2. Create a new site with a custom domain (e.g. ~/projects/php/mims points to http://ims.local):
newsite mims ims

# 3. List all configured Virtual Host sites:
newsite --list

# 4. Delete a Virtual Host site (Disables site, removes Apache config & cleans Windows hosts file):
newsite --delete mims
```

---

## 💻 Windows PowerShell Domain Mapper (`wslmap`)

Shortcut function included in your PowerShell profile (`Microsoft.PowerShell_profile.ps1`):

- **`wslmap`** (or **`mapwsl`**): Grants modify permissions on `C:\Windows\System32\drivers\etc\hosts` (using `gsudo` / UAC elevation).
- Usage in PowerShell:
  ```powershell
  wslmap
  ```

---

## 🛠️ What `wsldev.sh` Configures (XAMPP-like PHP Stack)

1. **Workspace DocumentRoot (`/home/aaxyat/projects/php`)**:
   - Equivalent of XAMPP `htdocs`. Owned by `aaxyat:www-data` (`775` mode).
   - Serves `http://localhost/projectname` ➔ `/home/aaxyat/projects/php/projectname`.
   - Generates a modern dark-mode PHP project dashboard (`index.php`).

2. **Apache2 & Full PHP Suite**:
   - Apache2 with `mod_rewrite`, `mod_vhost_alias`, `mod_headers`, `mod_env`.
   - PHP extensions: `cli`, `mysql`, `curl`, `gd`, `mbstring`, `xml`, `zip`, `intl`, `bcmath`, `soap`, `sqlite3`.

3. **MariaDB/MySQL Database Server**:
   - MySQL service enabled via `systemd`.
   - Pre-configured root and developer account `aaxyat` with full privileges (Password: `root`).

4. **phpMyAdmin Integration**:
   - Web interface pre-configured at `http://localhost/phpmyadmin`.

5. **`newsite` CLI Tool & Wildcard Virtual Hosts (`*.local`)**:
   - CLI tool for site creation/deletion, and automatic wildcard mapping for any subfolder in `/home/aaxyat/projects/php/<folder>` ➔ `http://<folder>.local`.

---

## 🛠️ What `wslsetup.sh` Configures (Optimized for WSL)

1. **User & Sudo Verification**:
   - Detects active WSL user (`aaxyat`). Enables `pwfeedback` (asterisks `*` when typing sudo passwords).
2. **Package & System Acceleration**:
   - Sets timezone to `Asia/Kathmandu`.
   - **Nala ➔ apt-fast ➔ apt-get** package manager priority chain.
   - Installs `nala`, `apt-fast`, `git`, `python3`, `curl`, `wget`.
3. **Developer Tools & Version Managers**:
   - **NVM** (Node Version Manager) & **Astral `uv`** (Fast Python package manager).
4. **Docker Desktop Windows Integration**:
   - Configures socket group permissions (`root:docker`, `660` mode) and adds user to `docker` group.
5. **Developer Environment & Shell Customization**:
   - Default shell: **Fish** + **Oh-My-Fish** (`bira` theme + `z` plugin automated).
   - **Tmux**: Auto-attaches to persistent session `main`.
   - Developer CLI suite: `nala`, `btop`, `micro`, `lsd`, `fastfetch`.
   - Fish Aliases (`explorer`, `clip`, `code`, `ls=lsd`, `neofetch=fastfetch`, `ports`, `update`, `dps`, `cls`).

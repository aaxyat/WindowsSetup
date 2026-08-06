# VPS & WSL Environment Setup Automation

Automated shell scripts for initializing and managing Oracle Cloud VPS instances and local Windows Subsystem for Linux (WSL) environments.

## 🚀 Quick Start Guide

### 1. Ubuntu WSL One-Command Setup (Local Windows PC)
To configure your local Ubuntu WSL environment in a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/wslsetup.sh | sudo bash
# OR run locally inside WSL:
bash wslsetup.sh
```

---

### 2. VPS Full Initial Setup (Oracle Cloud / Debian)
Once your VPS reboots, SSH in as `root` and run `setup.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/setup.sh | sudo bash
# OR run locally:
bash setup.sh
```

---

### 3. Reset / Re-install VPS OS
To reset your Oracle VPS back to a clean Debian 13 OS using `debi.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/reset.sh | sudo bash
# OR run locally:
bash reset.sh
```

---

## 🛠️ What `wslsetup.sh` Configures (Optimized for WSL)

1. **User & Sudo Verification**:
   - Detects active WSL user (`aaxyat`).
   - Enables `pwfeedback` (asterisks `*` when typing sudo passwords).

2. **Package & System Acceleration**:
   - Sets timezone to `Asia/Kathmandu`.
   - **Nala ➔ apt-fast ➔ apt-get** package manager priority chain.
   - Installs `nala`, `apt-fast`, `git`, `python3`, `curl`, `wget`.

3. **Docker Engine & Portainer CE**:
   - Installs official Docker Engine + Docker Compose.
   - WSL service compatibility (works seamlessly with systemd or SysV init).
   - Deploys Portainer CE container (`http://localhost:9000`).

4. **Developer Environment & Shell Customization**:
   - Default shell: **Fish** + **Oh-My-Fish** (`bira` theme + `z` plugin).
   - **Tmux**: Auto-attaches to persistent session `main`.
   - Developer CLI suite: `nala`, `btop`, `micro`, `lsd`, `fastfetch`.
   - Fish Aliases (`ls=lsd`, `neofetch=fastfetch`, `ports`, `update`, `dps`, `cls`).

5. **Nala-Style Bounded UI**:
   - Live command output streaming inside fixed 5-line scrolling ASCII border boxes.

---

## 🖥️ What `setup.sh` Configures (Oracle VPS Production)

1. **User Management**:
   - Creates user `aaxyat` with sudo privileges and password prompt.
2. **Swap & Memory Tuning**:
   - 8GB Swap file allocation + swappiness tuning (`vm.swappiness=10`).
3. **SSH Hardening & UFW Firewall**:
   - Key-only SSH auth (`PermitRootLogin no`, `PasswordAuthentication no`).
   - Opens ports `22`, `80`, `443`, `9000`.
4. **Dynamic OCI Keep-Alive Daemon (`sys-healthd`)**:
   - Dynamic load balancer maintaining ~21% CPU/RAM to prevent Oracle reclaim.
5. **Docker, Portainer & Shell Customizations**:
   - Fish + OMF `bira` + `z` + `tmux` + Portainer CE.

---

## 🔒 Post-Setup Access

Log in as `aaxyat` via SSH:
```bash
ssh aaxyat@<YOUR_VPS_IP>
```
Access Portainer dashboard:
```text
# VPS:
http://<YOUR_VPS_IP>:9000

# WSL:
http://localhost:9000
```

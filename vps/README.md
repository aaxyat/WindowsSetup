# Oracle VPS Setup & Reset Automation

Automated shell scripts for initializing and managing an Oracle Cloud VPS running Debian.

## 🚀 Quick Start Guide

### 1. Reset / Re-install VPS OS
To reset your VPS back to a clean Debian 12 OS using `debi.sh`:

```bash
curl -sL https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/reset.sh | bash
# OR run locally:
bash reset.sh
```

---

### 2. Full VPS Initial Setup
Once your VPS reboots after reset, SSH in as `root` and run `setup.sh`:

```bash
curl -sL https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/setup.sh | bash
# OR run locally:
bash setup.sh
```

---

## 🛠️ What `setup.sh` Configures Automatically

1. **User Management**:
   - Creates user `aaxyat` with sudo privileges.
   - Interactively prompts to set user password.
   - Enables `pwfeedback` (asterisks `*` when typing sudo passwords).

2. **Package & System Acceleration**:
   - Sets timezone to `Asia/Kathmandu`.
   - Installs `apt-fast` for multi-threaded parallel package downloads.
   - Enables `unattended-upgrades` for automated security patches.

3. **Swap & Kernel Tuning**:
   - Allocates 8GB persistent Swap file in `/etc/fstab`.
   - Tunes kernel swappiness (`vm.swappiness=10`, `vm.vfs_cache_pressure=50`).

4. **SSH Security & Lockout Prevention**:
   - Installs user SSH public key into `/home/aaxyat/.ssh/authorized_keys`.
   - Enforces strict OpenSSH permissions (`750` home, `700` `.ssh`, `600` `authorized_keys`).
   - Disables root SSH login (`PermitRootLogin no`) and password authentication (`PasswordAuthentication no`).
   - Verifies key validity before completing script execution.

5. **UFW Firewall**:
   - Sets default deny incoming / allow outgoing policies.
   - Opens ports: `22` (SSH), `80` (HTTP), `443` (HTTPS), `9000` (Portainer).

6. **Docker & Portainer CE**:
   - Installs official Docker Engine + Docker Compose.
   - Adds `aaxyat` to `docker` group.
   - Deploys Portainer CE container (`http://<vps-ip>:9000`).
   - Schedules root weekly maintenance cron (`/etc/cron.weekly/docker-prune`).

7. **Dynamic OCI Keep-Alive Daemon (`sys-healthd`)**:
   - Python 3 supervisor service that dynamically calculates system CPU & RAM load.
   - Only tops up load to ~21% with organic fluctuation if real applications are idle.
   - Automatically drops to 0% overhead when your Docker apps or web servers are active.

8. **Developer Productivity & Shell Customization**:
   - Default shell: **Fish** + **Oh-My-Fish** (`bira` theme + `z` plugin).
   - **Tmux**: Auto-attaches to persistent session `main` upon SSH login.
   - Installed CLI tools: `nala`, `btop`, `micro`, `lsd`, `fastfetch`.
   - Fish Aliases:
     - `ls` → `lsd`
     - `neofetch` → `fastfetch`
     - `ports` → `sudo ss -tulpn`
     - `update` → `sudo apt update && sudo apt upgrade -y`
     - `dps` → `docker ps formatted table`
     - `cls` → `clear`

---

## 🔒 Post-Setup Access

Log in as `aaxyat` via SSH:
```bash
ssh aaxyat@<YOUR_VPS_IP>
```
Access Portainer dashboard:
```text
http://<YOUR_VPS_IP>:9000
```

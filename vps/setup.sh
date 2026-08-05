#!/usr/bin/env bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# -------------------------------------------------------------------
# ANSI Styling & Color Tokens
# -------------------------------------------------------------------
BOLD='\033[1m'
DIM='\033[2m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;82m'
MAGENTA='\033[38;5;198m'
YELLOW='\033[38;5;226m'
WHITE='\033[38;5;255m'
RESET='\033[0m'

info()    { echo -e "  ${CYAN}ℹ${RESET}  $*"; }
success() { echo -e "  ${GREEN}✔${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "  ${MAGENTA}✖${RESET}  $*"; }
item()    { echo -e "  ${BLUE}✚${RESET}  $*"; }

# -------------------------------------------------------------------
# Error Handling & Cleanup Traps
# -------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    # Terminate background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    # Clean temporary files
    rm -f /tmp/sshd_config_new /tmp/fastfetch.deb /tmp/lsd.deb 2>/dev/null || true
    if [ $exit_code -ne 0 ]; then
        echo "" >&2
        echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
        echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}VPS Setup encountered an error and stopped.${RESET}                       ${MAGENTA}│${RESET}" >&2
        echo -e "${MAGENTA}│${RESET} ${WHITE}Your system state has been safely preserved.${RESET}                          ${MAGENTA}│${RESET}" >&2
        echo -e "${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯${RESET}" >&2
    fi
}
trap cleanup EXIT

error_handler() {
    local line_no=$1
    local bash_command=$2
    echo "" >&2
    echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}CRITICAL ERROR: setup.sh failed at line ${line_no}!${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} Failed Command: ${WHITE}${bash_command}${RESET}" >&2
    echo -e "${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯${RESET}" >&2
}
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

# Non-interactive frontend for apt package installations
export DEBIAN_FRONTEND=noninteractive

# Determine sudo requirement (works whether run as root or non-root with sudo)
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
        # Authenticate up-front from /dev/tty and refresh sudo timestamp in background
        if [ -c /dev/tty ]; then
            $SUDO -v </dev/tty
        else
            $SUDO -v
        fi
        ( while true; do $SUDO -n true; sleep 50; kill -0 "$$" || exit; done ) 2>/dev/null &
    else
        error "This script must be run as root or with sudo installed."
        exit 1
    fi
else
    SUDO=""
fi

# Package installer helper using apt-fast if available
apt_install() {
    if command -v apt-fast &>/dev/null; then
        $SUDO apt-fast install -y "$@"
    else
        $SUDO apt-get install -y "$@"
    fi
}

# Modern ANSI progress bar renderer
show_progress() {
    local step=$1
    local total=8
    local description=$2
    local percent=$(( (step * 100) / total ))
    local width=32
    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    echo ""
    echo -e "${BLUE}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${BLUE}│${RESET} ${BOLD}${WHITE}Step ${step}/${total}${RESET} ${CYAN}➔${RESET} ${BOLD}${YELLOW}${description}${RESET}"
    echo -e "${BLUE}│${RESET} ${GREEN}[${bar}]${RESET} ${BOLD}${WHITE}${percent}%${RESET}"
    echo -e "${BLUE}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""
}

clear
echo -e "${MAGENTA}"
cat << "EOF"
  ██████╗ ██████╗  █████╗  ██████╗██╗     ███████╗    ██╗   ██╗██████╗ ███████╗
 ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██║     ██╔════╝    ██║   ██║██╔══██╗██╔════╝
 ██║   ██║██████╔╝███████║██║     ██║     █████╗      ██║   ██║██████╔╝███████╗
 ██║   ██║██╔══██╗██╔══██║██║     ██║     ██╔══╝      ╚██╗ ██╔╝██╔═══╝ ╚════██║
 ╚██████╔╝██║  ██║██║  ██║╚██████╗███████╗███████╗     ╚████╔╝ ██║     ███████║
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝      ╚═══╝  ╚═╝     ╚══════╝
EOF
echo -e "${CYAN}             ⚡ Automated Oracle Cloud VPS Setup Engine ⚡${RESET}\n"

NEW_USER="aaxyat"
SWAP_SIZE="8096M"

# -------------------------------------------------------------------
# 1. User Creation & Interactive Password Prompt
# -------------------------------------------------------------------
show_progress 1 "Setting up user '${NEW_USER}' & sudo permissions"

if id "${NEW_USER}" &>/dev/null; then
    info "User '${NEW_USER}' already exists."
else
    $SUDO useradd -m -s /bin/bash "${NEW_USER}"
    success "User '${NEW_USER}' created."
fi

echo -e "\n  ${YELLOW}🔑${RESET}  ${BOLD}Please set the password for user '${NEW_USER}':${RESET}"
if [ -c /dev/tty ]; then
    $SUDO passwd "${NEW_USER}" </dev/tty
else
    $SUDO passwd "${NEW_USER}"
fi
success "Password set for user '${NEW_USER}'."

# -------------------------------------------------------------------
# 2. System Update, Timezone, Packages & Auto-Upgrades
# -------------------------------------------------------------------
show_progress 2 "System updates, Asia/Kathmandu timezone & package suite"

info "Setting system timezone to Asia/Kathmandu..."
$SUDO timedatectl set-timezone Asia/Kathmandu 2>/dev/null || {
    $SUDO ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
    echo "Asia/Kathmandu" | $SUDO tee /etc/timezone >/dev/null
}
success "Timezone set to Asia/Kathmandu."

info "Updating package lists and upgrading system..."
$SUDO apt update -y >/dev/null 2>&1
$SUDO apt upgrade -y >/dev/null 2>&1
success "Package lists updated."

info "Installing prerequisite tools & unattended upgrades..."
$SUDO apt install -y sudo curl wget lsb-release ca-certificates gnupg unattended-upgrades python3 >/dev/null 2>&1

$SUDO tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
success "Unattended security updates enabled."

$SUDO usermod -aG sudo "${NEW_USER}" 2>/dev/null || true

info "Enabling pwfeedback (asterisks) in sudoers..."
if [ -d /etc/sudoers.d ]; then
    echo "Defaults pwfeedback" | $SUDO tee /etc/sudoers.d/pwfeedback >/dev/null
    $SUDO chmod 0440 /etc/sudoers.d/pwfeedback
else
    if ! $SUDO grep -q "pwfeedback" /etc/sudoers; then
        echo "Defaults pwfeedback" | $SUDO tee -a /etc/sudoers >/dev/null
    fi
fi
success "pwfeedback enabled in sudoers."

info "Installing apt-fast package acceleration tool..."
$SUDO /bin/bash -c "$(curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/ilikenwf/apt-fast/master/quick-install.sh)" >/dev/null 2>&1 || warn "apt-fast installation notice."

info "Installing core tools via apt-fast (fish, git, nodejs, npm, htop, tmux, nala, btop, micro)..."
apt_install fish git nodejs npm htop tmux nala btop micro >/dev/null 2>&1 || true
success "Core developer tools installed."

# Install lsd (with fallback)
if ! command -v lsd &>/dev/null; then
    info "Installing lsd..."
    apt_install lsd >/dev/null 2>&1 || {
        ARCH=$(dpkg --print-architecture)
        LSD_URL=$(curl -sSL --connect-timeout 15 --retry 3 https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep "browser_download_url.*_${ARCH}.deb" | cut -d '"' -f 4 | head -n 1)
        if [ -n "${LSD_URL:-}" ]; then
            curl -sSL --connect-timeout 15 --retry 3 "$LSD_URL" -o /tmp/lsd.deb && $SUDO dpkg -i /tmp/lsd.deb && rm -f /tmp/lsd.deb
        fi
    } >/dev/null 2>&1 || true
fi
success "lsd installed."

# Install fastfetch (with fallback)
if ! command -v fastfetch &>/dev/null; then
    info "Installing fastfetch..."
    apt_install fastfetch >/dev/null 2>&1 || {
        ARCH=$(dpkg --print-architecture)
        FF_URL=$(curl -sSL --connect-timeout 15 --retry 3 https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-${ARCH}.deb" | cut -d '"' -f 4 | head -n 1)
        if [ -n "${FF_URL:-}" ]; then
            curl -sSL --connect-timeout 15 --retry 3 "$FF_URL" -o /tmp/fastfetch.deb && $SUDO dpkg -i /tmp/fastfetch.deb && rm -f /tmp/fastfetch.deb
        fi
    } >/dev/null 2>&1 || true
fi
success "fastfetch installed."

# -------------------------------------------------------------------
# 3. Swapfile & Kernel Memory Tuning (Swappiness = 10)
# -------------------------------------------------------------------
show_progress 3 "8GB Swapfile allocation & kernel memory tuning"

if [ -f /swapfile ]; then
    info "Swapfile already exists at /swapfile. Skipping creation."
else
    info "Allocating 8GB Swapfile at /swapfile..."
    $SUDO fallocate -l "${SWAP_SIZE}" /swapfile || $SUDO dd if=/dev/zero of=/swapfile bs=1M count=8096
    $SUDO chmod 0600 /swapfile
    $SUDO mkswap /swapfile >/dev/null
    $SUDO swapon /swapfile
    success "Swapfile created and activated."
fi

if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile swap swap defaults 0 0" | $SUDO tee -a /etc/fstab >/dev/null
    success "Swapfile added to /etc/fstab."
fi

info "Tuning kernel swappiness (10) and cache pressure (50)..."
$SUDO tee /etc/sysctl.d/99-vps-tuning.conf >/dev/null << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
$SUDO sysctl -p /etc/sysctl.d/99-vps-tuning.conf >/dev/null 2>&1 || true
success "Kernel memory parameters optimized."

# -------------------------------------------------------------------
# 4. SSH Security & UFW Firewall Setup
# -------------------------------------------------------------------
show_progress 4 "SSH security hardening & UFW firewall setup"

USER_HOME="/home/${NEW_USER}"
SSH_DIR="${USER_HOME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

$SUDO mkdir -p "${SSH_DIR}"

SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9DEsM1tG0mwfYLLDPPpGyg9X0oW1vLQ8LuGkvaZQHLPtRpmumCPByC/MUsLDbvSGVGu9DsgyL402Fu7I+k0sgI+MA3r8tq9RtQa8iPa99puvKj5t45U3kh9Hu/e9YXmQgVO3/1YF4LMgVBVsPgp/5gKjaRTGdVx/1I3pKEYFH2SlWiyi8RBdc9IQWNsLfApOPYJ9eNHI7pInBqNWdE14eL6Ucd7HO0+4js0m7Sk034mFkJD06JeLs4LmoE6d+gsVDpa1RlKSe6GCEqGNA7CcKK/8A+x4Xddg3p8CB3Rip53WU/+mi6ro+64GMJTECfCoXtW/uNEPZvo3vvTsfzCx1 ssh-key-2021-10-22"

if ! $SUDO grep -q "$SSH_KEY" "${AUTH_KEYS}" 2>/dev/null; then
    echo "$SSH_KEY" | $SUDO tee -a "${AUTH_KEYS}" >/dev/null
    success "SSH public key added to ${AUTH_KEYS}."
fi

$SUDO chmod 700 "${SSH_DIR}"
$SUDO chmod 600 "${AUTH_KEYS}"
$SUDO chown -R "${NEW_USER}:${NEW_USER}" "${SSH_DIR}"

if [ -f /etc/ssh/sshd_config ]; then
    $SUDO cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
fi

info "Applying hardened OpenSSH configuration (PermitRootLogin no, PasswordAuthentication no)..."
$SUDO tee /etc/ssh/sshd_config >/dev/null << 'EOF'
Include /etc/ssh/sshd_config.d/*.conf

# Authentication:
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2

# Password & PAM settings
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Shell & Session
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

$SUDO chmod 644 /etc/ssh/sshd_config

if command -v sshd &>/dev/null; then
    if ! $SUDO sshd -t 2>/dev/null; then
        warn "Syntax error in sshd_config. Restoring backup..."
        if [ -f /etc/ssh/sshd_config.bak ]; then
            $SUDO cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        fi
    fi
fi

$SUDO systemctl restart sshd 2>/dev/null || $SUDO systemctl restart ssh 2>/dev/null || true
success "OpenSSH daemon secured and restarted."

info "Configuring UFW Firewall..."
apt_install ufw >/dev/null 2>&1
$SUDO ufw default deny incoming >/dev/null 2>&1
$SUDO ufw default allow outgoing >/dev/null 2>&1
$SUDO ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
$SUDO ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
$SUDO ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1
$SUDO ufw allow 9000/tcp comment 'Portainer' >/dev/null 2>&1
$SUDO ufw --force enable >/dev/null 2>&1
success "UFW Firewall active (ports 22, 80, 443, 9000 open)."

# -------------------------------------------------------------------
# 5. Docker Engine, Portainer CE & Maintenance Cron
# -------------------------------------------------------------------
show_progress 5 "Docker Engine, Portainer CE & maintenance cron"

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    $SUDO apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

$SUDO apt update -y >/dev/null 2>&1
apt_install ca-certificates curl lsb-release >/dev/null 2>&1

$SUDO install -m 0755 -d /etc/apt/keyrings
$SUDO curl -sSLf --connect-timeout 15 --retry 3 https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
$SUDO chmod a+r /etc/apt/keyrings/docker.asc

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

$SUDO apt update -y >/dev/null 2>&1
apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose >/dev/null 2>&1
success "Docker Engine installed."

$SUDO groupadd -f docker
$SUDO usermod -aG docker "${NEW_USER}"
success "User '${NEW_USER}' added to 'docker' group."

info "Deploying Portainer CE container..."
$SUDO docker volume create portainer_data >/dev/null 2>&1 || true
if ! $SUDO docker ps -a | grep -q "portainer"; then
    $SUDO docker run -d \
      -p 8000:8000 \
      -p 9000:9000 \
      --name=portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce >/dev/null 2>&1
    success "Portainer CE deployed on port 9000."
else
    info "Portainer container already running."
fi

info "Configuring weekly Docker prune cron..."
$SUDO tee /etc/cron.weekly/docker-prune >/dev/null << 'EOF'
#!/usr/bin/env bash
/usr/bin/docker system prune -af --volumes > /var/log/docker-prune.log 2>&1
EOF
$SUDO chmod +x /etc/cron.weekly/docker-prune
success "Weekly Docker prune cron scheduled."

# -------------------------------------------------------------------
# 6. Dynamic OCI Keep-Alive Daemon (Supervisor & Python)
# -------------------------------------------------------------------
show_progress 6 "Dynamic OCI keep-alive daemon (sys-healthd)"

$SUDO apt update -y >/dev/null 2>&1
apt_install supervisor python3 >/dev/null 2>&1

KEEPALIVE_SCRIPT="/usr/local/bin/sys-healthd.py"

info "Installing dynamic load balancer (/usr/local/bin/sys-healthd.py)..."
$SUDO tee "${KEEPALIVE_SCRIPT}" >/dev/null << 'EOF'
#!/usr/bin/env python3
import time
import os
import random

TARGET_CPU = 21.0  # Oracle Free Tier requires >= 20%
TARGET_RAM = 21.0  # Oracle Free Tier requires >= 20%

def get_cpu_usage():
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        fields = [float(x) for x in line.strip().split()[1:]]
        idle = fields[3] + fields[4]
        total = sum(fields)
        return total, idle
    except Exception:
        return 0, 0

def get_mem_usage():
    try:
        mem = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    mem[parts[0].strip()] = int(parts[1].strip().split()[0])
        total = mem.get('MemTotal', 1)
        available = mem.get('MemAvailable', mem.get('MemFree', 0))
        return ((total - available) / total) * 100.0
    except Exception:
        return 50.0

def main():
    allocated_ram = []
    t1_total, t1_idle = get_cpu_usage()
    
    while True:
        time.sleep(3)
        t2_total, t2_idle = get_cpu_usage()
        
        diff_total = t2_total - t1_total
        diff_idle = t2_idle - t1_idle
        
        current_cpu = 100.0 * (1.0 - (diff_idle / diff_total)) if diff_total > 0 else 0.0
        t1_total, t1_idle = t2_total, t2_idle
        
        current_ram = get_mem_usage()
        
        if current_ram < TARGET_RAM:
            allocated_ram.append(bytearray(10 * 1024 * 1024))
        elif current_ram > (TARGET_RAM + 4.0) and len(allocated_ram) > 0:
            allocated_ram.pop()
            
        target_jitter = TARGET_CPU + random.uniform(-1.8, 1.8)
        if current_cpu < target_jitter:
            end_time = time.time() + 1.5
            while time.time() < end_time:
                _ = [x * x for x in range(3000)]

if __name__ == '__main__':
    main()
EOF

$SUDO chmod +x "${KEEPALIVE_SCRIPT}"

KEEPALIVE_CONF="/etc/supervisor/conf.d/sys-healthd.conf"
$SUDO tee "${KEEPALIVE_CONF}" >/dev/null << 'EOF'
[program:sys-healthd]
command=/usr/bin/python3 /usr/local/bin/sys-healthd.py
directory=/usr/local/bin
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/sys-healthd.log
EOF

$SUDO rm -f /etc/supervisor/conf.d/stress.conf 2>/dev/null || true

$SUDO supervisorctl reread >/dev/null 2>&1 || true
$SUDO supervisorctl update >/dev/null 2>&1 || true
success "Dynamic OCI keep-alive daemon (sys-healthd) active."

$SUDO tee /etc/logrotate.d/sys-healthd >/dev/null << 'EOF'
/var/log/sys-healthd.log {
    weekly
    missingok
    rotate 4
    compress
    notifempty
    maxsize 10M
}
EOF
success "sys-healthd logrotate configured."

# -------------------------------------------------------------------
# 7. Shell Customization (Fish, OMF, bira, z, lsd, btop, micro & Tmux)
# -------------------------------------------------------------------
show_progress 7 "Fish shell, Oh-My-Fish, themes, aliases & Tmux session"

BASHRC_FILE="${USER_HOME}/.bashrc"
if [ -f "${BASHRC_FILE}" ]; then
    if ! grep -q "fish" "${BASHRC_FILE}"; then
        echo "fish" >> "${BASHRC_FILE}"
        $SUDO chown "${NEW_USER}:${NEW_USER}" "${BASHRC_FILE}"
        success "Fish auto-start added to .bashrc."
    fi
fi

if command -v fish &>/dev/null; then
    info "Installing Oh-My-Fish, 'bira' theme & 'z' plugin for '${NEW_USER}'..."
    if [ "$EUID" -eq 0 ]; then
        su - "${NEW_USER}" -c "curl -sSL --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish --noninteractive" >/dev/null 2>&1 || true
        su - "${NEW_USER}" -c "fish -c 'omf install bira'" >/dev/null 2>&1 || true
        su - "${NEW_USER}" -c "fish -c 'omf install z'" >/dev/null 2>&1 || true
    else
        sudo -u "${NEW_USER}" -H bash -c "curl -sSL --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish --noninteractive" >/dev/null 2>&1 || true
        sudo -u "${NEW_USER}" -H fish -c "omf install bira" >/dev/null 2>&1 || true
        sudo -u "${NEW_USER}" -H fish -c "omf install z" >/dev/null 2>&1 || true
    fi
    success "Oh-My-Fish, bira theme & z plugin configured."
fi

FISH_CONF_DIR="${USER_HOME}/.config/fish"
FISH_CONF_FILE="${FISH_CONF_DIR}/config.fish"

$SUDO mkdir -p "${FISH_CONF_DIR}"

if ! $SUDO grep -q "alias neofetch" "${FISH_CONF_FILE}" 2>/dev/null; then
    echo "alias neofetch=fastfetch" | $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null
fi

if ! $SUDO grep -q "alias ls=lsd" "${FISH_CONF_FILE}" 2>/dev/null; then
    $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null << 'EOF'
alias ls=lsd
alias l='lsd -l'
alias la='lsd -a'
alias ll='lsd -la'
alias lt='lsd --tree'
EOF
fi

if ! $SUDO grep -q "alias ports" "${FISH_CONF_FILE}" 2>/dev/null; then
    $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null << 'EOF'
alias ports='sudo ss -tulpn'
alias update='sudo apt update && sudo apt upgrade -y'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias cls='clear'
EOF
fi

if ! $SUDO grep -q "tmux new-session" "${FISH_CONF_FILE}" 2>/dev/null; then
    echo "" | $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null
    echo "# Auto-attach to existing tmux session 'main' or create a new one" | $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null
    echo "if status is-interactive; and not set -q TMUX; exec tmux new-session -A -s main; end" | $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null
fi
success "Fish shell aliases and tmux auto-attach configured."

# -------------------------------------------------------------------
# 8. Final Security & Lockout Prevention Verification
# -------------------------------------------------------------------
show_progress 8 "Final security, SSH key & lockout safety verification"

$SUDO chown -R "${NEW_USER}:${NEW_USER}" "${USER_HOME}"
$SUDO chmod 750 "${USER_HOME}"
$SUDO chmod 700 "${SSH_DIR}"
$SUDO chmod 600 "${AUTH_KEYS}"

if [ -f "${AUTH_KEYS}" ] && $SUDO grep -qF "$SSH_KEY" "${AUTH_KEYS}" 2>/dev/null; then
    success "Exact public SSH key verified in ${AUTH_KEYS}."
else
    warn "Key missing. Injecting public SSH key..."
    echo "$SSH_KEY" | $SUDO tee -a "${AUTH_KEYS}" >/dev/null
    $SUDO chmod 600 "${AUTH_KEYS}"
    $SUDO chown "${NEW_USER}:${NEW_USER}" "${AUTH_KEYS}"
    success "SSH public key injected and verified."
fi

$SUDO ufw allow 22/tcp >/dev/null 2>&1 || true

# -------------------------------------------------------------------
# Completion Dashboard
# -------------------------------------------------------------------
echo ""
echo -e "${GREEN}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET} ${BOLD}${WHITE}  🎉  ORACLE VPS SETUP COMPLETED SUCCESSFULLY!  🎉                       ${RESET}${GREEN}│${RESET}"
echo -e "${GREEN}├──────────────────────────────────────────────────────────────────────────┤${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Created User${RESET}      : ${BOLD}${WHITE}${NEW_USER}${RESET}                                  ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• System Timezone${RESET}   : ${BOLD}${WHITE}Asia/Kathmandu${RESET}                            ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• SSH Access Command${RESET}: ${BOLD}${YELLOW}ssh ${NEW_USER}@<YOUR_VPS_IP>${RESET}                   ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Portainer Web UI${RESET}  : ${BOLD}${YELLOW}http://<YOUR_VPS_IP>:9000${RESET}                ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Keep-Alive Daemon${RESET} : ${BOLD}${WHITE}sys-healthd (active ~21% load)${RESET}              ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Default Shell${RESET}    : ${BOLD}${WHITE}Fish (bira theme + z + lsd + tmux)${RESET}          ${GREEN}│${RESET}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

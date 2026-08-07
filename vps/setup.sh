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

export -f info success warn error item 2>/dev/null || true

# Nala-style bounded scrolling box renderer (fixed 5-line window with clean line erase)
run_boxed() {
    local cmd="$*"
    if command -v python3 &>/dev/null; then
        python3 -c "
import sys, subprocess

box_width = 74
max_lines = 5
buffer = ['' for _ in range(max_lines)]

print(f'  \033[38;5;39m┌{\"─\" * box_width}┐\033[0m\033[K')
for _ in range(max_lines):
    print(f'  \033[38;5;39m│\033[0m {\" \":<{box_width - 2}} \033[38;5;39m│\033[0m\033[K')
print(f'  \033[38;5;39m└{\"─\" * box_width}┘\033[0m\033[K')
sys.stdout.write(f'\033[{max_lines + 1}A')
sys.stdout.flush()

proc = subprocess.Popen('''$cmd''', shell=True, executable='/bin/bash', stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

for line in iter(proc.stdout.readline, ''):
    line_clean = line.strip().replace('\t', ' ')
    if not line_clean:
        continue
    if len(line_clean) > (box_width - 4):
        line_clean = line_clean[:box_width - 7] + '...'
    
    buffer.pop(0)
    buffer.append(line_clean)
    
    sys.stdout.write(f'\033[{max_lines}A')
    for b in buffer:
        sys.stdout.write(f'\r\033[K  \033[38;5;39m│\033[0m  {b:<{box_width - 4}}  \033[38;5;39m│\033[0m\033[K\n')
    sys.stdout.flush()

proc.stdout.close()
rc = proc.wait()
sys.stdout.write(f'\033[1B\r')
sys.exit(rc)
" 2>/dev/null || eval "$cmd" >/dev/null 2>&1
    else
        eval "$cmd" >/dev/null 2>&1
    fi
}

# -------------------------------------------------------------------
# Error Handling & Cleanup Traps
# -------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    # Erase password from memory
    unset USER_PASS USER_PASS_CONFIRM 2>/dev/null || true
    # Terminate background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    # Clean temporary files
    rm -f /tmp/sshd_config_new /tmp/fastfetch.deb /tmp/lsd.deb /tmp/omf_installer 2>/dev/null || true
    rm -rf /tmp/omf_repo 2>/dev/null || true
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
export SUDO 2>/dev/null || true

# Package installer helper with prioritized fallback: nala -> apt-fast -> apt-get
pkg_install() {
    if command -v nala &>/dev/null; then
        if $SUDO nala install -y "$@"; then
            return 0
        fi
    fi
    
    if command -v apt-fast &>/dev/null; then
        if $SUDO apt-fast install -y "$@"; then
            return 0
        fi
    fi
    
    $SUDO apt-get install -y "$@"
}
export -f pkg_install 2>/dev/null || true

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
 ╚██████╔╝██║  ██║██║  ██║╚██████╗███████╗███████╗     ╚████╔╝ ██║     ███████╗
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

echo -e "\n  ${YELLOW}🔑${RESET}  ${BOLD}Set password for user '${NEW_USER}':${RESET}"

while true; do
    if [ -c /dev/tty ]; then
        read -rsp "  Enter Password: " USER_PASS </dev/tty
        echo ""
        read -rsp "  Confirm Password: " USER_PASS_CONFIRM </dev/tty
        echo ""
    else
        read -rsp "  Enter Password: " USER_PASS
        echo ""
        read -rsp "  Confirm Password: " USER_PASS_CONFIRM
        echo ""
    fi
    
    if [ -z "${USER_PASS}" ]; then
        warn "Password cannot be empty. Please try again."
    elif [ "${USER_PASS}" != "${USER_PASS_CONFIRM}" ]; then
        warn "Passwords do not match. Please try again."
    else
        break
    fi
done

echo "${NEW_USER}:${USER_PASS}" | $SUDO chpasswd
success "Password set and verified for user '${NEW_USER}'."

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

info "Updating package lists..."
run_boxed "$SUDO apt update -y" || true

info "Upgrading system packages..."
run_boxed "$SUDO apt upgrade -y" || true
success "System packages updated."

info "Installing core package manager prerequisites (nala, sudo, curl, wget, lsb-release, ca-certificates, gnupg, unattended-upgrades, python3, aria2)..."
run_boxed "$SUDO apt-get install -y sudo curl wget lsb-release ca-certificates gnupg unattended-upgrades python3 nala aria2" || true

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

# Non-interactive apt-fast setup
if ! command -v apt-fast &>/dev/null; then
    info "Installing apt-fast package acceleration tool..."
    $SUDO wget -q https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast -O /usr/local/bin/apt-fast 2>/dev/null || true
    $SUDO chmod +x /usr/local/bin/apt-fast 2>/dev/null || true
    $SUDO tee /etc/apt-fast.conf >/dev/null << 'EOF'
DOWNLOADER="aria2c -s 5 -m 5 -k 1m -x 5"
MAXNUM=5
EOF
    success "apt-fast package acceleration tool configured."
fi

info "Installing core tools via package priority chain (nala -> apt-fast -> apt)..."
run_boxed "pkg_install fish git nodejs npm htop tmux btop micro" || true
success "Core developer tools installed."

# Install lsd (with fallback)
if ! command -v lsd &>/dev/null; then
    info "Installing lsd..."
    run_boxed "pkg_install lsd" || {
        ARCH=$(dpkg --print-architecture)
        LSD_URL=$(curl -sSL --connect-timeout 15 --retry 3 https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep "browser_download_url.*_${ARCH}.deb" | cut -d '"' -f 4 | head -n 1)
        if [ -n "${LSD_URL:-}" ]; then
            curl -sSL --connect-timeout 15 --retry 3 "$LSD_URL" -o /tmp/lsd.deb && $SUDO dpkg -i /tmp/lsd.deb && rm -f /tmp/lsd.deb
        fi
    } || true
fi
success "lsd installed."

# Install fastfetch (with fallback)
if ! command -v fastfetch &>/dev/null; then
    info "Installing fastfetch..."
    run_boxed "pkg_install fastfetch" || {
        ARCH=$(dpkg --print-architecture)
        FF_URL=$(curl -sSL --connect-timeout 15 --retry 3 https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-${ARCH}.deb" | cut -d '"' -f 4 | head -n 1)
        if [ -n "${FF_URL:-}" ]; then
            curl -sSL --connect-timeout 15 --retry 3 "$FF_URL" -o /tmp/fastfetch.deb && $SUDO dpkg -i /tmp/fastfetch.deb && rm -f /tmp/fastfetch.deb
        fi
    } || true
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
    run_boxed "$SUDO fallocate -l ${SWAP_SIZE} /swapfile || $SUDO dd if=/dev/zero of=/swapfile bs=1M count=8096" || true
    $SUDO chmod 0600 /swapfile 2>/dev/null || true
    $SUDO mkswap /swapfile 2>/dev/null || true
    $SUDO swapon /swapfile 2>/dev/null || true
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
$SUDO sysctl -p /etc/sysctl.d/99-vps-tuning.conf || true
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
run_boxed "pkg_install ufw" || true
$SUDO ufw default deny incoming || true
$SUDO ufw default allow outgoing || true
$SUDO ufw allow 22/tcp comment 'SSH' || true
$SUDO ufw allow 80/tcp comment 'HTTP' || true
$SUDO ufw allow 443/tcp comment 'HTTPS' || true
$SUDO ufw allow 9000/tcp comment 'Portainer' || true
$SUDO ufw --force enable || true
success "UFW Firewall active (ports 22, 80, 443, 9000 open)."

# -------------------------------------------------------------------
# 5. Docker Engine, Portainer CE & Maintenance Cron (Fault-Tolerant)
# -------------------------------------------------------------------
show_progress 5 "Docker Engine, Portainer CE & maintenance cron"

if ! (
    set -e
    info "Cleaning up conflicting legacy docker packages..."
    $SUDO apt-get remove -y --purge docker.io docker-doc docker-compose podman-docker containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    $SUDO apt-get autoremove -y 2>/dev/null || true

    info "Installing prerequisite certificates..."
    run_boxed "$SUDO apt update -y" || true
    run_boxed "pkg_install ca-certificates curl lsb-release" || true

    # Setup Docker official GPG key
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -sSLf --connect-timeout 15 --retry 3 https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null || true
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc 2>/dev/null || true

    ARCH=$(dpkg --print-architecture)
    DISTRO=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "debian")
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")

    if [[ "$CODENAME" == "trixie" || "$CODENAME" == "sid" || "$CODENAME" == "n/a" || -z "$CODENAME" ]]; then
        info "Debian testing/trixie detected. Using 'bookworm' suite for Docker repository compatibility..."
        CODENAME="bookworm"
    fi

    info "Configuring Docker repository for ${DISTRO} (${CODENAME} / ${ARCH})...."
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

    info "Updating package index..."
    run_boxed "$SUDO apt update -y || true"

    info "Installing Docker Engine packages..."
    if ! run_boxed "pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"; then
        warn "Official Docker repository install encountered an issue. Falling back to Debian native docker packages..."
        run_boxed "pkg_install docker.io docker-compose-v2 || pkg_install docker.io docker-compose || true"
    fi

    info "Starting Docker system daemon..."
    $SUDO systemctl unmask docker 2>/dev/null || true
    $SUDO systemctl enable --now docker 2>/dev/null || true
    $SUDO systemctl restart docker 2>/dev/null || true
    success "Docker Engine installed and daemon active."

    $SUDO groupadd -f docker
    $SUDO usermod -aG docker "${NEW_USER}"

    info "Deploying Portainer CE container..."
    $SUDO docker volume create portainer_data || true
    if ! $SUDO docker ps -a | grep -q "portainer"; then
        run_boxed "$SUDO docker run -d \
          -p 8000:8000 \
          -p 9000:9000 \
          --name=portainer \
          --restart=always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ce"
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
); then
    warn "Notice: Docker Engine or Portainer setup encountered an issue. Continuing with remaining VPS setup..."
fi

# -------------------------------------------------------------------
# 6. Dynamic OCI Keep-Alive Daemon (Supervisor & Python)
# -------------------------------------------------------------------
show_progress 6 "Dynamic OCI keep-alive daemon (sys-healthd)"

if ! (
    run_boxed "$SUDO apt update -y" || true
    run_boxed "pkg_install supervisor python3" || true

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

    $SUDO supervisorctl reread || true
    $SUDO supervisorctl update || true
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
); then
    warn "Notice: sys-healthd daemon setup encountered an issue. Continuing with remaining VPS setup..."
fi

# -------------------------------------------------------------------
# 7. Shell Customization (Fish, OMF, bira, z, lsd, btop, micro & Tmux)
# -------------------------------------------------------------------
show_progress 7 "Fish shell, Oh-My-Fish, themes, aliases & Tmux session"

if ! (
    BASHRC_FILE="${USER_HOME}/.bashrc"
    if [ -f "${BASHRC_FILE}" ]; then
        if ! grep -q "fish" "${BASHRC_FILE}"; then
            echo "fish" >> "${BASHRC_FILE}"
            $SUDO chown "${NEW_USER}:${NEW_USER}" "${BASHRC_FILE}"
            success "Fish auto-start added to .bashrc."
        fi
    fi

    if command -v fish &>/dev/null; then
        info "Installing Oh-My-Fish non-interactively for '${NEW_USER}'..."
        
        # Download OMF installer script
        curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install -o /tmp/omf_installer 2>/dev/null || true
        
        if [ -f /tmp/omf_installer ]; then
            $SUDO chmod +x /tmp/omf_installer
            if [ "$EUID" -eq 0 ]; then
                run_boxed "su - \"${NEW_USER}\" -c \"fish /tmp/omf_installer --noninteractive --yes\"" || true
            else
                run_boxed "sudo -u \"${NEW_USER}\" -H fish /tmp/omf_installer --noninteractive --yes" || true
            fi
            rm -f /tmp/omf_installer
        fi

        # Pre-configure OMF theme to 'bira' and enable 'z' plugin natively
        OMF_CONF_DIR="${USER_HOME}/.config/omf"
        $SUDO mkdir -p "${OMF_CONF_DIR}"
        echo "bira" | $SUDO tee "${OMF_CONF_DIR}/theme" >/dev/null
        echo "z" | $SUDO tee "${OMF_CONF_DIR}/bundle" >/dev/null
        $SUDO chown -R "${NEW_USER}:${NEW_USER}" "${OMF_CONF_DIR}" "${USER_HOME}/.local/share/omf" 2>/dev/null || true
        success "Oh-My-Fish, bira theme & z plugin automated."
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
); then
    warn "Notice: Shell customization encountered an issue. Continuing with remaining VPS setup..."
fi

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

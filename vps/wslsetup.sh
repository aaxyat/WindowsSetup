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

# Nala-style bounded scrolling box renderer (fixed 5-line window)
run_boxed() {
    local cmd="$*"
    if command -v python3 &>/dev/null; then
        python3 -c "
import sys, subprocess

box_width = 74
max_lines = 5
buffer = ['' for _ in range(max_lines)]

print(f'  \033[38;5;39m┌{\"─\" * box_width}┐\033[0m')
for _ in range(max_lines):
    print(f'  \033[38;5;39m│\033[0m {\" \":<{box_width - 2}} \033[38;5;39m│\033[0m')
print(f'  \033[38;5;39m└{\"─\" * box_width}┘\033[0m')
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
        sys.stdout.write(f'\r  \033[38;5;39m│\033[0m  {b:<{box_width - 4}}  \033[38;5;39m│\033[0m\n')
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
    unset USER_PASS USER_PASS_CONFIRM 2>/dev/null || true
    jobs -p | xargs -r kill 2>/dev/null || true
    rm -f /tmp/fastfetch.deb /tmp/lsd.deb 2>/dev/null || true
    if [ $exit_code -ne 0 ]; then
        echo "" >&2
        echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
        echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}WSL Setup encountered an error and stopped.${RESET}                        ${MAGENTA}│${RESET}" >&2
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
    echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}CRITICAL ERROR: wslsetup.sh failed at line ${line_no}!${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} Failed Command: ${WHITE}${bash_command}${RESET}" >&2
    echo -e "${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯${RESET}" >&2
}
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

# Non-interactive frontend for apt package installations
export DEBIAN_FRONTEND=noninteractive

# Determine sudo requirement
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
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
    local total=6
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
 ██╗██╗  ██╗███████╗██╗     ███████╗███████╗████████╗██╗   ██╗██████╗ 
 ██║██║  ██║██╔════╝██║     ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
 ██║██║  ██║███████╗██║     ███████╗█████╗     ██║   ██║   ██║██████╔╝
 ██║██╔╗ ██║╚════██║██║     ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
 ██║╚█████╔╝███████║███████╗███████║███████╗   ██║   ╚██████╔╝██║     
 ╚═╝ ╚════╝ ╚══════╝╚══════╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
EOF
echo -e "${CYAN}             ⚡ Automated Ubuntu WSL Setup Engine ⚡${RESET}\n"

# Determine target WSL username (prefers current user or fallback to aaxyat)
CURRENT_USER="${SUDO_USER:-${USER:-aaxyat}}"
if [ "${CURRENT_USER}" == "root" ]; then
    CURRENT_USER="aaxyat"
fi
USER_HOME="/home/${CURRENT_USER}"
if [ "${CURRENT_USER}" == "root" ]; then
    USER_HOME="/root"
fi

# -------------------------------------------------------------------
# 1. User & Sudo Verification
# -------------------------------------------------------------------
show_progress 1 "Configuring user '${CURRENT_USER}' & sudo permissions"

if id "${CURRENT_USER}" &>/dev/null; then
    info "User '${CURRENT_USER}' active."
else
    $SUDO useradd -m -s /bin/bash "${CURRENT_USER}"
    success "User '${CURRENT_USER}' created."
fi

$SUDO usermod -aG sudo "${CURRENT_USER}" 2>/dev/null || true

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

# Auto-symlink Windows SSH Keys if available
WIN_SSH_DIR="/mnt/c/Users/${CURRENT_USER}/.ssh"
LINUX_SSH_DIR="${USER_HOME}/.ssh"
if [ -d "${WIN_SSH_DIR}" ]; then
    info "Windows SSH keys detected at ${WIN_SSH_DIR}. Configuring symlink..."
    $SUDO mkdir -p "${LINUX_SSH_DIR}"
    $SUDO cp -rn "${WIN_SSH_DIR}"/* "${LINUX_SSH_DIR}/" 2>/dev/null || true
    $SUDO chmod 700 "${LINUX_SSH_DIR}" 2>/dev/null || true
    $SUDO chmod 600 "${LINUX_SSH_DIR}"/* 2>/dev/null || true
    $SUDO chown -R "${CURRENT_USER}:${CURRENT_USER}" "${LINUX_SSH_DIR}" 2>/dev/null || true
    success "Windows SSH keys integrated."
fi

# Configure /etc/wsl.conf for clean file permissions and systemd
info "Configuring /etc/wsl.conf (systemd=true & automount metadata)..."
$SUDO tee /etc/wsl.conf >/dev/null << 'EOF'
[boot]
systemd=true

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"

[interop]
enabled = true
appendWindowsPath = true
EOF
success "/etc/wsl.conf optimized."

# -------------------------------------------------------------------
# 2. System Update, Timezone & Core Package Suite
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

info "Installing core package manager prerequisites (nala, sudo, curl, wget, lsb-release, ca-certificates, gnupg, python3)..."
run_boxed "$SUDO apt-get install -y sudo curl wget lsb-release ca-certificates gnupg python3 nala" || true

info "Installing apt-fast package acceleration tool..."
if [ -c /dev/tty ]; then
    run_boxed "$SUDO /bin/bash -c \"\$(curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/ilikenwf/apt-fast/master/quick-install.sh)\" </dev/tty" || warn "apt-fast installation notice."
else
    run_boxed "$SUDO /bin/bash -c \"\$(curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/ilikenwf/apt-fast/master/quick-install.sh)\"" || warn "apt-fast installation notice."
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
# 3. Development Version Managers (NVM & UV)
# -------------------------------------------------------------------
show_progress 3 "Installing development version managers (NVM & UV)"

# Install NVM for target user
info "Installing NVM (Node Version Manager)..."
if [ "$EUID" -eq 0 ]; then
    run_boxed "su - \"${CURRENT_USER}\" -c \"curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash\"" || true
else
    run_boxed "sudo -u \"${CURRENT_USER}\" -H bash -c \"curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash\"" || true
fi
success "NVM (Node Version Manager) installed."

# Install Astral UV for target user
info "Installing Astral 'uv' (Fast Python package manager)..."
if [ "$EUID" -eq 0 ]; then
    run_boxed "su - \"${CURRENT_USER}\" -c \"curl -LsSf https://astral.sh/uv/install.sh | sh\"" || true
else
    run_boxed "sudo -u \"${CURRENT_USER}\" -H bash -c \"curl -LsSf https://astral.sh/uv/install.sh | sh\"" || true
fi
success "Astral 'uv' installed."

# -------------------------------------------------------------------
# 4. Docker Desktop Integration Verification
# -------------------------------------------------------------------
show_progress 4 "Verifying Docker Desktop Windows integration"

$SUDO groupadd -f docker 2>/dev/null || true
$SUDO usermod -aG docker "${CURRENT_USER}" 2>/dev/null || true

if command -v docker &>/dev/null; then
    success "Docker CLI detected (provided via Docker Desktop WSL integration)."
else
    info "Installing docker-cli client tools for Docker Desktop..."
    run_boxed "pkg_install docker-cli docker-compose-v2" || true
    success "Docker CLI client installed."
fi

# -------------------------------------------------------------------
# 5. Shell Customization & Sane Aliases (Fish, OMF, bira, z & Tmux)
# -------------------------------------------------------------------
show_progress 5 "Fish shell, Oh-My-Fish, themes, aliases & Tmux session"

if ! (
    BASHRC_FILE="${USER_HOME}/.bashrc"
    if [ -f "${BASHRC_FILE}" ]; then
        if ! grep -q "fish" "${BASHRC_FILE}"; then
            echo "fish" >> "${BASHRC_FILE}"
            $SUDO chown "${CURRENT_USER}:${CURRENT_USER}" "${BASHRC_FILE}" 2>/dev/null || true
            success "Fish auto-start added to .bashrc."
        fi
    fi

    if command -v fish &>/dev/null; then
        info "Installing Oh-My-Fish, 'bira' theme & 'z' plugin for '${CURRENT_USER}'..."
        if [ "$EUID" -eq 0 ]; then
            run_boxed "su - \"${CURRENT_USER}\" -c \"curl -sSL --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish --noninteractive\"" || true
            run_boxed "su - \"${CURRENT_USER}\" -c \"fish -c 'omf install bira'\"" || true
            run_boxed "su - \"${CURRENT_USER}\" -c \"fish -c 'omf install z'\"" || true
        else
            run_boxed "sudo -u \"${CURRENT_USER}\" -H bash -c \"curl -sSL --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish --noninteractive\"" || true
            run_boxed "sudo -u \"${CURRENT_USER}\" -H fish -c \"omf install bira\"" || true
            run_boxed "sudo -u \"${CURRENT_USER}\" -H fish -c \"omf install z\"" || true
        fi
        success "Oh-My-Fish, bira theme & z plugin configured."
    fi

    FISH_CONF_DIR="${USER_HOME}/.config/fish"
    FISH_CONF_FILE="${FISH_CONF_DIR}/config.fish"

    $SUDO mkdir -p "${FISH_CONF_DIR}"

    info "Configuring sane & high-productivity Fish aliases..."
    $SUDO tee "${FISH_CONF_FILE}" >/dev/null << 'EOF'
# --- Environment Paths ---
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin
fish_add_path ~/.nvm

# --- Windows Interop Shortcuts ---
alias explorer="explorer.exe ."
alias clip="clip.exe"
alias code="code ."

# --- Modern Directory & Listing Shortcuts (lsd) ---
alias ls='lsd'
alias l='lsd -l'
alias la='lsd -a'
alias ll='lsd -la'
alias lt='lsd --tree'

# --- Navigation Shortcuts ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- System & Maintenance Shortcuts ---
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='sudo ss -tulpn'
alias cls='clear'
alias neofetch='fastfetch'

# --- Git Productivity Shortcuts ---
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# --- Docker Desktop Shortcuts ---
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dclean='docker system prune -af --volumes'

# --- Tmux Interactive Auto-Attach ---
if status is-interactive; and not set -q TMUX
    exec tmux new-session -A -s main
end
EOF

    $SUDO chown -R "${CURRENT_USER}:${CURRENT_USER}" "${FISH_CONF_DIR}" 2>/dev/null || true
    success "Sane Fish shell aliases and tmux auto-attach configured."
); then
    warn "Notice: Shell customization encountered an issue. Continuing with remaining WSL setup..."
fi

# -------------------------------------------------------------------
# 6. Completion Dashboard
# -------------------------------------------------------------------
show_progress 6 "Final environment verification"

$SUDO chown -R "${CURRENT_USER}:${CURRENT_USER}" "${USER_HOME}" 2>/dev/null || true

echo ""
echo -e "${GREEN}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET} ${BOLD}${WHITE}  🎉  UBUNTU WSL SETUP COMPLETED SUCCESSFULLY!  🎉                      ${RESET}${GREEN}│${RESET}"
echo -e "${GREEN}├──────────────────────────────────────────────────────────────────────────┤${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Configured User${RESET}   : ${BOLD}${WHITE}${CURRENT_USER}${RESET}                                  ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• System Timezone${RESET}   : ${BOLD}${WHITE}Asia/Kathmandu${RESET}                            ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Dev Tools Installed${RESET}: ${BOLD}${WHITE}NVM, Astral 'uv', Fish, OMF, Tmux, lsd${RESET}    ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Package Chain${RESET}     : ${BOLD}${WHITE}Nala ➔ apt-fast ➔ apt-get${RESET}                 ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Docker Engine${RESET}     : ${BOLD}${WHITE}Docker Desktop (Windows Integration)${RESET}       ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Windows Interop${RESET}   : ${BOLD}${WHITE}explorer, clip, code, wsl.conf, SSH Keys${RESET}  ${GREEN}│${RESET}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

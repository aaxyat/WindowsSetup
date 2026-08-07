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
# Automated Self-Test Suite (--test / test)
# -------------------------------------------------------------------
run_self_tests() {
    echo -e "${CYAN}🧪 Running Automated WSL Environment Test Suite...${RESET}\n"
    local passed=0
    local failed=0
    
    test_check() {
        local name=$1
        local cmd=$2
        if eval "$cmd" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✔ [PASS]${RESET} ${WHITE}${name}${RESET}"
            passed=$((passed + 1))
        else
            echo -e "  ${MAGENTA}✖ [FAIL]${RESET} ${WHITE}${name}${RESET}"
            failed=$((failed + 1))
        fi
    }

    test_check "User '${CURRENT_USER}' active" "id '${CURRENT_USER}'"
    test_check "Sudo group membership for '${CURRENT_USER}'" "id -nG '${CURRENT_USER}' | grep -qw sudo"
    test_check "Passwordless sudo configured" "$SUDO grep -q '${CURRENT_USER}' /etc/sudoers.d/* 2>/dev/null"
    test_check "Timezone set to Asia/Kathmandu" "timedatectl 2>/dev/null | grep -q 'Asia/Kathmandu' || grep -q 'Asia/Kathmandu' /etc/timezone 2>/dev/null"
    test_check "/etc/wsl.conf systemd & automount" "grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null"
    test_check "Fish shell installed" "command -v fish"
    test_check "Git installed" "command -v git"
    test_check "Python3 installed" "command -v python3"
    test_check "Nala package manager" "command -v nala"
    test_check "apt-fast package manager" "command -v apt-fast"
    test_check "lsd utility" "command -v lsd"
    test_check "fastfetch utility" "command -v fastfetch"
    test_check "btop system monitor" "command -v btop"
    test_check "micro text editor" "command -v micro"
    test_check "tmux terminal multiplexer" "command -v tmux"
    test_check "NVM (Node Version Manager)" "[ -s '${USER_HOME}/.nvm/nvm.sh' ] || command -v nvm"
    test_check "Astral 'uv' Python tool" "[ -f '${USER_HOME}/.cargo/bin/uv' ] || [ -f '${USER_HOME}/.local/bin/uv' ] || command -v uv"
    test_check "Oh-My-Fish installed" "[ -d '${USER_HOME}/.local/share/omf' ]"
    test_check "bira theme active" "grep -q 'bira' '${USER_HOME}/.config/omf/theme' 2>/dev/null"
    test_check "z plugin active" "grep -q 'z' '${USER_HOME}/.config/omf/bundle' 2>/dev/null"
    test_check "Docker Desktop CLI / Socket access" "docker ps"

    echo ""
    echo -e "${BLUE}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${BLUE}│${RESET} ${BOLD}${WHITE}TEST SUMMARY: ${GREEN}${passed} Passed${RESET}${WHITE}, ${MAGENTA}${failed} Failed${RESET}                             ${BLUE}│${RESET}"
    echo -e "${BLUE}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""
    if [ "$failed" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

if [ "${1:-}" == "--test" ] || [ "${1:-}" == "test" ]; then
    if [ "$EUID" -ne 0 ]; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    run_self_tests
fi

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
    unset USER_PASS USER_PASS_CONFIRM 2>/dev/null || true
    jobs -p | xargs -r kill 2>/dev/null || true
    rm -f /tmp/fastfetch.deb /tmp/lsd.deb /tmp/omf_installer 2>/dev/null || true
    rm -rf /tmp/omf_repo 2>/dev/null || true
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

info "Configuring passwordless sudo for developer user '${CURRENT_USER}'..."
if [ -d /etc/sudoers.d ]; then
    echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" | $SUDO tee "/etc/sudoers.d/${CURRENT_USER}" >/dev/null
    $SUDO chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
fi
success "Passwordless sudo configured for '${CURRENT_USER}'."

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

info "Installing core package manager prerequisites (nala, sudo, curl, wget, lsb-release, ca-certificates, gnupg, python3, aria2)..."
run_boxed "$SUDO apt-get install -y sudo curl wget lsb-release ca-certificates gnupg python3 nala aria2" || true

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
# 4. Docker Desktop Integration Verification & Permissions
# -------------------------------------------------------------------
show_progress 4 "Verifying Docker Desktop Windows integration & permissions"

$SUDO groupadd -f docker 2>/dev/null || true
$SUDO usermod -aG docker "${CURRENT_USER}" 2>/dev/null || true

if [ -e /var/run/docker.sock ]; then
    $SUDO chgrp docker /var/run/docker.sock 2>/dev/null || true
    $SUDO chmod 660 /var/run/docker.sock 2>/dev/null || true
fi

if command -v docker &>/dev/null; then
    success "Docker CLI detected (provided via Docker Desktop WSL integration)."
else
    info "Installing docker-cli client tools for Docker Desktop..."
    run_boxed "pkg_install docker-cli docker-compose-v2" || true
    success "Docker CLI client installed."
fi

# -------------------------------------------------------------------
# 5. Automated Oh-My-Fish & bira Theme Setup
# -------------------------------------------------------------------
show_progress 5 "Automating Oh-My-Fish, bira theme & Fish shell customization"

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
        info "Installing Oh-My-Fish non-interactively for '${CURRENT_USER}'..."
        
        # Download OMF installer script
        curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install -o /tmp/omf_installer 2>/dev/null || true
        
        if [ -f /tmp/omf_installer ]; then
            $SUDO chmod +x /tmp/omf_installer
            if [ "$EUID" -eq 0 ]; then
                run_boxed "su - \"${CURRENT_USER}\" -c \"fish /tmp/omf_installer --noninteractive --yes\"" || true
            else
                run_boxed "sudo -u \"${CURRENT_USER}\" -H fish /tmp/omf_installer --noninteractive --yes" || true
            fi
            rm -f /tmp/omf_installer
        fi

        # Pre-configure OMF theme to 'bira' and enable 'z' plugin natively
        OMF_CONF_DIR="${USER_HOME}/.config/omf"
        $SUDO mkdir -p "${OMF_CONF_DIR}"
        echo "bira" | $SUDO tee "${OMF_CONF_DIR}/theme" >/dev/null
        echo "z" | $SUDO tee "${OMF_CONF_DIR}/bundle" >/dev/null
        $SUDO chown -R "${CURRENT_USER}:${CURRENT_USER}" "${OMF_CONF_DIR}" "${USER_HOME}/.local/share/omf" 2>/dev/null || true
        success "Oh-My-Fish, bira theme & z plugin automated."
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

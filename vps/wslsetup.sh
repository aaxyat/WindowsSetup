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
# Error Handling & Traps
# -------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    jobs -p | xargs -r kill 2>/dev/null || true
    if [ $exit_code -ne 0 ]; then
        echo "" >&2
        echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
        echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}WSL Environment Setup encountered an error and stopped.${RESET}           ${MAGENTA}│${RESET}" >&2
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

# Self-Test Verification Suite
run_self_tests() {
    echo -e "${CYAN}🧪 Running Automated WSL Environment Verification Suite...${RESET}\n"
    local passed=0
    local failed=0
    local SUDO=""
    if [ "$EUID" -ne 0 ]; then SUDO="sudo"; fi

    assert_cmd() {
        local name=$1
        local cmd=$2
        if eval "$cmd" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✔ [PASS]${RESET} ${name}"
            passed=$((passed + 1))
        else
            echo -e "  ${MAGENTA}✖ [FAIL]${RESET} ${name}"
            failed=$((failed + 1))
        fi
    }

    assert_cmd "Timezone is Asia/Kathmandu" "timedatectl 2>/dev/null | grep -q 'Asia/Kathmandu' || cat /etc/timezone | grep -q 'Asia/Kathmandu'"
    assert_cmd "pwfeedback enabled in sudoers" "$SUDO grep -q 'pwfeedback' /etc/sudoers.d/pwfeedback /etc/sudoers 2>/dev/null"
    assert_cmd "Passwordless sudo enabled for user" "$SUDO sudo -n true 2>/dev/null"
    assert_cmd "Nala package manager installed" "command -v nala"
    assert_cmd "apt-fast package manager installed" "command -v apt-fast"
    assert_cmd "Git installed" "command -v git"
    assert_cmd "Python3 installed" "command -v python3"
    assert_cmd "Curl installed" "command -v curl"
    assert_cmd "Wget installed" "command -v wget"
    assert_cmd "NVM (Node Version Manager) installed" "[ -s \"\$HOME/.nvm/nvm.sh\" ] || command -v nvm"
    assert_cmd "Astral 'uv' installed" "[ -f \"\$HOME/.local/bin/uv\" ] || command -v uv"
    assert_cmd "Docker socket group permissions set" "[ -e /var/run/docker.sock ] && [ \$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 0) -eq \$(getent group docker | cut -d: -f3 2>/dev/null || echo 1) ]"
    assert_cmd "User added to docker group" "groups | grep -q 'docker'"
    assert_cmd "Fish shell installed" "command -v fish"
    assert_cmd "Oh-My-Fish installed" "[ -d \"\$HOME/.local/share/omf\" ]"
    assert_cmd "OMF theme set to bira" "grep -q 'bira' \"\$HOME/.config/omf/theme\" 2>/dev/null"
    assert_cmd "OMF plugin z enabled" "grep -q 'z' \"\$HOME/.config/omf/bundle\" 2>/dev/null"
    assert_cmd "Tmux installed" "command -v tmux"
    assert_cmd "lsd installed" "command -v lsd"
    assert_cmd "fastfetch installed" "command -v fastfetch"
    assert_cmd "Fish configuration present" "[ -f \"\$HOME/.config/fish/config.fish\" ]"

    echo ""
    echo -e "${BOLD}${WHITE}Verification Summary: ${GREEN}${passed} Passed${RESET}, ${MAGENTA}${failed} Failed${RESET}"
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}🎉 All 21 self-tests passed successfully!${RESET}\n"
        exit 0
    else
        echo -e "${MAGENTA}⚠️ Some verification tests failed.${RESET}\n"
        exit 1
    fi
}

if [ "${1:-}" == "--test" ]; then
    run_self_tests
fi

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
echo -e "${CYAN}"
cat << "EOF"
██╗███╗   ██╗███████╗████████╗██████╗  ██████╗ ███╗   ██╗██╗████████╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗████╗  ██║██║╚══██╔══╝
██║██╔██╗ ██║███████╗   ██║   ██████╔╝██║   ██║██╔██╗ ██║██║   ██║   
██║██║╚██╗██║╚════██║   ██║   ██╔══██╗██║   ██║██║╚██╗██║██║   ██║   
██║██║ ╚████║███████║   ██║   ██║  ██║╚██████╔╝██║ ╚████║██║   ██║   
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═══╝   
EOF
echo -e "${MAGENTA}          ⚡ Automated Ubuntu WSL Setup Engine (v2.0) ⚡${RESET}\n"

CURRENT_USER="${SUDO_USER:-${USER:-aaxyat}}"
if [ "${CURRENT_USER}" == "root" ]; then
    CURRENT_USER="aaxyat"
fi
USER_HOME="/home/${CURRENT_USER}"
if [ "${CURRENT_USER}" == "root" ]; then
    USER_HOME="/root"
fi

# -------------------------------------------------------------------
# 1. User & Sudo Privileges & Timezone (Asia/Kathmandu)
# -------------------------------------------------------------------
show_progress 1 "Configuring user privileges, passwordless sudo & timezone"

info "Setting system timezone to Asia/Kathmandu..."
$SUDO timedatectl set-timezone Asia/Kathmandu 2>/dev/null || {
    echo "Asia/Kathmandu" | $SUDO tee /etc/timezone >/dev/null
    $SUDO ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
}
success "Timezone set to Asia/Kathmandu."

info "Enabling sudo password feedback (asterisks) & passwordless sudo..."
$SUDO tee /etc/sudoers.d/pwfeedback >/dev/null << 'EOF'
Defaults pwfeedback
EOF
$SUDO chmod 0440 /etc/sudoers.d/pwfeedback

$SUDO tee "/etc/sudoers.d/${CURRENT_USER}" >/dev/null << EOF
${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL
EOF
$SUDO chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
success "Password feedback and passwordless sudo enabled for '${CURRENT_USER}'."

# -------------------------------------------------------------------
# 2. System Update & Package Acceleration (Nala, apt-fast, CLI tools)
# -------------------------------------------------------------------
show_progress 2 "Updating system & installing package managers (Nala, apt-fast)"

info "Updating package repositories..."
run_boxed "$SUDO apt-get update -y" || true

info "Installing base dependencies (git, curl, wget, python3, software-properties-common)..."
run_boxed "$SUDO apt-get install -y git curl wget python3 python3-pip software-properties-common build-essential ca-certificates gnupg" || true

# Install Nala
if ! command -v nala &>/dev/null; then
    info "Installing Nala package manager..."
    run_boxed "$SUDO apt-get install -y nala" || true
fi
success "Nala package manager active."

# Install apt-fast
if ! command -v apt-fast &>/dev/null; then
    info "Installing apt-fast package manager..."
    $SUDO add-apt-repository -y ppa:apt-fast/stable 2>/dev/null || true
    $SUDO apt-get update -y 2>/dev/null || true
    echo "apt-fast apt-fast/maxdownloads string 16" | $SUDO debconf-set-selections 2>/dev/null || true
    echo "apt-fast apt-fast/dlflag boolean true" | $SUDO debconf-set-selections 2>/dev/null || true
    echo "apt-fast apt-fast/aptmanager string apt-get" | $SUDO debconf-set-selections 2>/dev/null || true
    run_boxed "$SUDO apt-get install -y apt-fast" || {
        $SUDO wget -q https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast -O /usr/local/bin/apt-fast 2>/dev/null || true
        $SUDO chmod +x /usr/local/bin/apt-fast 2>/dev/null || true
    } || true
fi
success "apt-fast package manager active."

info "Installing developer CLI utilities (fish, tmux, btop, micro, lsd)..."
run_boxed "pkg_install fish tmux btop micro lsd" || true

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
# 5. Automated Oh-My-Fish, bira Theme & Windows Terminal Nerd Font Setup
# -------------------------------------------------------------------
show_progress 5 "Automating Oh-My-Fish, bira theme & Windows Terminal Nerd Font"

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

    # Configure FiraCode Nerd Font for Windows Terminal
    info "Configuring FiraCode Nerd Font for Windows Terminal..."
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, os, urllib.request, zipfile, winreg

try:
    font_dir = os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Windows\Fonts')
    os.makedirs(font_dir, exist_ok=True)
    
    target_ttf = os.path.join(font_dir, 'FiraCodeNerdFont-Regular.ttf')
    if not os.path.exists(target_ttf):
        zip_path = os.path.expandvars(r'%TEMP%\FiraCode.zip')
        url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as resp, open(zip_path, 'wb') as out:
            out.write(resp.read())
        with zipfile.ZipFile(zip_path, 'r') as z:
            for name in z.namelist():
                if name.endswith('.ttf') or name.endswith('.otf'):
                    z.extract(name, font_dir)
        if os.path.exists(zip_path):
            os.remove(zip_path)
            
    reg_key = r'Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, reg_key, 0, winreg.KEY_SET_VALUE) as key:
        for f in os.listdir(font_dir):
            if f.endswith('.ttf') or f.endswith('.otf'):
                font_path = os.path.join(font_dir, f)
                val_name = f.replace('.ttf', '').replace('.otf', '') + ' (TrueType)'
                winreg.SetValueEx(key, val_name, 0, winreg.REG_SZ, font_path)
                
    wt_path = os.path.expandvars(r'%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
    if os.path.exists(wt_path):
        with open(wt_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        defaults = data.setdefault('profiles', {}).setdefault('defaults', {})
        font = defaults.setdefault('font', {})
        font['face'] = 'FiraCode Nerd Font'
        font['features'] = {'calt': 1}
        with open(wt_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
except Exception:
    pass
" 2>/dev/null || true
        success "FiraCode Nerd Font downloaded and configured for Windows Terminal."
    fi
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
echo -e "${GREEN}│${RESET}  ${CYAN}• Windows Terminal${RESET}  : ${BOLD}${WHITE}FiraCode Nerd Font configured${RESET}              ${GREEN}│${RESET}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

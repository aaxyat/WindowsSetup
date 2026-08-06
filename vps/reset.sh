#!/usr/bin/env bash

# Exit immediately if any command fails or variable is unset
set -euo pipefail

# ANSI Styling Tokens
BOLD='\033[1m'
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

# Error handling & Memory cleanup trap
cleanup() {
    unset ROOT_PASS ROOT_PASS_CONFIRM 2>/dev/null || true
}
trap cleanup EXIT

error_handler() {
    local line_no=$1
    local bash_command=$2
    echo "" >&2
    echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}CRITICAL ERROR: reset.sh failed at line ${line_no}!${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} Failed Command: ${WHITE}${bash_command}${RESET}" >&2
    echo -e "${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯${RESET}" >&2
    exit 1
}
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

# Determine sudo requirement
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        error "This script must be run as root or with sudo installed."
        exit 1
    fi
else
    SUDO=""
fi

clear
echo -e "${MAGENTA}"
cat << "EOF"
  ██████╗ ███████╗███████╗███████╗████████╗    ██╗   ██╗██████╗ ███████╗
  ██╔══██╗██╔════╝██╔════╝██╔════╝╚══██╔══╝    ██║   ██║██╔══██╗██╔════╝
  ██████╔╝█████╗  ███████╗█████╗     ██║       ██║   ██║██████╔╝███████╗
  ██╔══██╗██╔══╝  ╚════██║██╔══╝     ██║       ╚██╗ ██╔╝██╔═══╝ ╚════██║
  ██║  ██║███████╗███████║███████╗   ██║        ╚████╔╝ ██║     ███████╗
  ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝         ╚═══╝  ╚═╝     ╚══════╝
EOF
echo -e "${CYAN}             ⚠️  Oracle Cloud VPS OS Re-installation ⚠️${RESET}\n"

echo -e "${YELLOW}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${YELLOW}│${RESET} ${BOLD}${WHITE}WARNING: This script will execute debi.sh to re-install Debian 13.${RESET}  ${YELLOW}│${RESET}"
echo -e "${YELLOW}│${RESET} ${BOLD}${MAGENTA}ALL DATA AND CUSTOM CONFIGURATIONS ON THIS VPS WILL BE ERASED!${RESET}      ${YELLOW}│${RESET}"
echo -e "${YELLOW}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# 1. Prompt for root password with double confirmation
echo -e "  ${YELLOW}🔑${RESET}  ${BOLD}Set ROOT password for the new Debian installation:${RESET}"

while true; do
    if [ -c /dev/tty ]; then
        read -rsp "  Enter Root Password: " ROOT_PASS </dev/tty
        echo ""
        read -rsp "  Confirm Root Password: " ROOT_PASS_CONFIRM </dev/tty
        echo ""
    else
        read -rsp "  Enter Root Password: " ROOT_PASS
        echo ""
        read -rsp "  Confirm Root Password: " ROOT_PASS_CONFIRM
        echo ""
    fi
    
    if [ -z "${ROOT_PASS}" ]; then
        warn "Password cannot be empty. Please try again."
    elif [ "${ROOT_PASS}" != "${ROOT_PASS_CONFIRM}" ]; then
        warn "Passwords do not match. Please try again."
    else
        break
    fi
done

# 2. Display the root password clearly for verification before confirmation
echo ""
echo -e "${GREEN}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET} ${BOLD}${WHITE}  IMPORTANT: ROOT PASSWORD VERIFICATION                                  ${RESET}${GREEN}│${RESET}"
echo -e "${GREEN}├──────────────────────────────────────────────────────────────────────────┤${RESET}"
echo -e "${GREEN}│${RESET}  ${YELLOW}➔ ROOT PASSWORD:${RESET} ${BOLD}${CYAN}${ROOT_PASS}${RESET}"
echo -e "${GREEN}│${RESET}                                                                          ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${WHITE}Please write down or copy this password to access root after reboot.${RESET}    ${GREEN}│${RESET}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# 3. Final confirmation prompt unless passed -y or --yes flag
AUTO_CONFIRM=false
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    AUTO_CONFIRM=true
fi

if [[ "$AUTO_CONFIRM" == false ]]; then
    echo -ne "  ${YELLOW}❓${RESET}  ${BOLD}Are you sure you want to proceed with full OS reset? (y/N): ${RESET}"
    if [ -c /dev/tty ]; then
        read -r confirm </dev/tty
    else
        read -r confirm
    fi
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo ""
        info "Reset cancelled. No changes were made."
        exit 0
    fi
fi

echo ""
info "Updating package index..."
$SUDO apt update -y >/dev/null 2>&1
success "Package index updated."

info "Installing curl prerequisite..."
$SUDO apt install -y curl >/dev/null 2>&1
success "Curl installed."

info "Downloading debi.sh installer..."
rm -f debi.sh
curl -sSLf --connect-timeout 15 --retry 3 https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh -o debi.sh

if [ ! -s debi.sh ]; then
    error "Failed to download debi.sh or file is empty!"
    exit 1
fi
chmod a+rx debi.sh
success "debi.sh downloaded and verified."

info "Executing debi.sh (Debian re-installation engine)..."
echo -e "${CYAN}--------------------------------------------------------------------------------${RESET}"
if [ -c /dev/tty ]; then
    $SUDO ./debi.sh --version 13 --cdn --bbr --ethx --user root --password "${ROOT_PASS}" --timezone Asia/Kathmandu </dev/tty
else
    $SUDO ./debi.sh --version 13 --cdn --bbr --ethx --user root --password "${ROOT_PASS}" --timezone Asia/Kathmandu
fi
echo -e "${CYAN}--------------------------------------------------------------------------------${RESET}"

echo ""
success "Re-installation triggered successfully!"
info "Rebooting VPS now..."
$SUDO shutdown -r now

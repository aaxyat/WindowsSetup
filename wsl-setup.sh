#!/bin/bash

# WSL Setup Script
# This script sets up WSL with common developer tools and configurations

set -e

echo "===================================================="
echo "             WSL Setup Script                       "
echo "                V 1.2.0                             "
echo "===================================================="

# Update packages
echo "Updating packages..."
sudo apt update

# Install nala for faster apt package installation
echo "Installing nala for faster apt package installation..."
curl https://gitlab.com/volian/volian-archive/-/raw/main/install-nala.sh | bash

# Upgrade packages using nala
echo "Upgrading packages using nala..."
sudo nala upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo nala install -y \
build-essential \
curl \
git \
wget \
unzip \
zip \
htop \
fish \
libssl-dev \
zlib1g-dev \
libbz2-dev \
libreadline-dev \
libsqlite3-dev \
llvm \
libncursesw5-dev \
xz-utils \
tk-dev \
libxml2-dev \
libxmlsec1-dev \
libffi-dev \
liblzma-dev \
micro

# Create common directories
echo "Creating common directories..."
mkdir -p ~/Github ~/Projects

# Install and setup Fish shell
echo "Setting up Fish shell..."
sudo nala install -y fish

# Create Fish configuration directory if it doesn't exist
mkdir -p ~/.config/fish/

# Install Fisher (plugin manager for Fish)
echo "Installing Fisher plugin manager..."
cat > /tmp/install_fisher.fish << 'EOF'
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher install jorgebucaran/fisher
EOF
fish /tmp/install_fisher.fish
rm -f /tmp/install_fisher.fish

#  Setup nvm
echo "Setting up nvm..."
cat > /tmp/setup_nvm.fish << 'EOF'
fisher install jorgebucaran/nvm.fish
nvm install lts
nvm use lts
EOF
fish /tmp/setup_nvm.fish
rm -f /tmp/setup_nvm.fish

# Install pyenv for Python version management
echo "Installing pyenv..."
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

# Install Poetry for Python package management
echo "Installing Poetry..."
curl -sSL https://install.python-poetry.org | python3 -

# Install uv for faster Python package installation
echo "Installing uv..."
curl -sSL https://astral.sh/uv/install.sh | bash

# Configure git
echo "Configuring git global settings..."
read -p "Enter your Git username: " git_username
read -p "Enter your Git email: " git_email

git config --global user.name "$git_username"
git config --global user.email "$git_email"
git config --global init.defaultBranch main
git config --global core.editor "micro"
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# Create final Fish configuration
echo "Setting up final Fish configuration..."
cat > ~/.config/fish/config.fish << 'EOL'
# Fish configuration

# Set aliases
alias ll 'ls -la'
alias update 'sudo nala update && sudo nala upgrade -y'
alias neofetch 'fastfetch'
alias g 'cd ~/Github'
alias p 'cd ~/Projects'

# Add local bin to path
if test -d "$HOME/.local/bin"
    set -gx PATH $HOME/.local/bin $PATH
end

# Poetry setup
if test -d "$HOME/.poetry/bin"
    set -gx PATH $HOME/.poetry/bin $PATH
end

# uv setup
if test -d "$HOME/.cargo/bin"
    set -gx PATH $HOME/.cargo/bin $PATH
end

# Pyenv setup
set -x PYENV_ROOT $HOME/.pyenv
set -x PATH $PYENV_ROOT/bin $PATH
if command -v pyenv 1>/dev/null 2>&1
    status is-login; and pyenv init --path | source
    pyenv init - | source
end

# NVM setup
set -gx NVM_DIR "$HOME/.nvm"
# nvm.fish plugin handles the rest

# pnpm setup
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end

EOL

# Configure ~/.bashrc to auto-launch Fish only in interactive sessions
echo "Configuring bashrc to auto-launch Fish..."
cat >> ~/.bashrc << 'EOL'
# Launch Fish automatically in interactive Bash sessions
if [[ $- == *i* ]] && [ -z "$BASH_EXECUTION_STRING" ]; then
    exec fish
fi
EOL

# Clean up temporary files
rm -f /tmp/install_fisher.fish /tmp/setup_nvm.fish

echo "===================================================="
echo "            WSL Setup Script Completed              "
echo "===================================================="
echo "Please restart your WSL terminal to apply all changes."
echo "Fish shell will launch automatically in interactive sessions."
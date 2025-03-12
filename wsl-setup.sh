#!/bin/bash

# WSL Setup Script
# This script sets up WSL with common developer tools and configurations

set -e

echo "===================================================="
echo "             WSL Setup Script Started               "
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

# # Install fastfetch (a faster alternative to neofetch)
# echo "Installing fastfetch..."
# sudo apt-fast install -y cmake
# git clone https://github.com/LinusDierheimer/fastfetch.git /tmp/fastfetch
# cd /tmp/fastfetch
# mkdir -p build
# cd build
# cmake ..
# cmake --build . --target fastfetch --target flashfetch
# sudo cmake --install .
# cd ~

# Install and setup Fish shell
echo "Setting up Fish shell..."
sudo apt-fast install -y fish

# Create Fish configuration directory if it doesn't exist
mkdir -p ~/.config/fish/

# Create initial Fish configuration
echo "Setting up initial Fish configuration..."
cat > ~/.config/fish/config.fish << 'EOL'
# Basic Fish configuration
# This will be replaced with a more complete version later

# Add local bin to path
if test -d "$HOME/.local/bin"
    set -gx PATH $HOME/.local/bin $PATH
end
EOL

# Install Fisher (plugin manager for Fish)
echo "Installing Fisher plugin manager..."
fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"

# Install nvm (Node Version Manager)
echo "Installing nvm..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    
    # Source nvm immediately
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Setup nvm.fish plugin for Fish
    fish -c "fisher install jorgebucaran/nvm.fish"
    
    # Install latest LTS version of node
    nvm install --lts
    
    # Install pnpm
    echo "Installing pnpm..."
    npm install -g pnpm
fi

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
git config --global core.editor "nano"
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# Create final Fish configuration
echo "Setting up final Fish configuration..."
cat > ~/.config/fish/config.fish << 'EOL'
# Fish configuration

# Set aliases
alias ll 'ls -la'
alias update 'sudo apt-fast update && sudo apt-fast upgrade -y'
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

# Set Fish as the default shell
echo "Setting Fish as default shell by editing /etc/passwd..."
sudo sed -i "s|$USER:.*|$USER:/bin/bash:/usr/bin/fish|" /etc/passwd

echo "===================================================="
echo "            WSL Setup Script Completed              "
echo "===================================================="
echo "Please restart your WSL terminal to apply all changes."
echo "Your default shell has been set to Fish with the bira theme."
echo "Run 'fastfetch' or 'neofetch' to see your system information."
echo "Use 'g' to cd into ~/Github and 'p' to cd into ~/Projects"
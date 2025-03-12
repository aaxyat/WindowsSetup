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

# Install and setup Fish shell
echo "Setting up Fish shell..."
sudo nala install -y fish

# Create Fish configuration directory if it doesn't exist
mkdir -p ~/.config/fish/

# Create initial Fish configuration
echo "Setting up initial Fish configuration..."
cat > ~/.config/fish/config.fish << 'EOL'
# Basic Fish configuration

# Add local bin to path
if test -d "$HOME/.local/bin"
    set -gx PATH $HOME/.local/bin $PATH
end
EOL

# Install Fisher (plugin manager for Fish)
echo "Installing Fisher plugin manager..."
fish -c 'curl -sL https://git.io/fisher | source; and fisher install jorgebucaran/fisher'


# Configure ~/.bashrc to auto-launch Fish only in interactive sessions
echo "Configuring bashrc to auto-launch Fish..."
cat >> ~/.bashrc << 'EOL'
# Launch Fish automatically in interactive Bash sessions
if [[ $- == *i* ]] && [ -z "$BASH_EXECUTION_STRING" ]; then
    exec fish
fi
EOL

echo "===================================================="
echo "            WSL Setup Script Completed              "
echo "===================================================="
echo "Please restart your WSL terminal to apply all changes."
echo "Fish shell will launch automatically in interactive sessions."

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
        echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}WSL PHP Dev Setup encountered an error and stopped.${RESET}                 ${MAGENTA}│${RESET}" >&2
        echo -e "${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯${RESET}" >&2
    fi
}
trap cleanup EXIT

error_handler() {
    local line_no=$1
    local bash_command=$2
    echo "" >&2
    echo -e "${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮${RESET}" >&2
    echo -e "${MAGENTA}│${RESET} ${BOLD}${MAGENTA}CRITICAL ERROR: wsldev.sh failed at line ${line_no}!${RESET}" >&2
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
 ██╗  ██╗ █████╗ ███╗   ███╗██████╗ ██████╗ 
 ██║  ██║██╔══██╗████╗ ████║██╔══██╗██╔══██╗
 ███████║███████║██╔████╔██║██████╔╝██████╔╝
 ██╔══██║██╔══██║██║╚██╔╝██║██╔═══╝ ██╔═══╝ 
 ██║  ██║██║  ██║██║ ╚═╝ ██║██║     ██║     
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚═╝     
EOF
echo -e "${CYAN}        ⚡ Automated WSL PHP Development Environment (XAMPP-like) ⚡${RESET}\n"

CURRENT_USER="${SUDO_USER:-${USER:-aaxyat}}"
if [ "${CURRENT_USER}" == "root" ]; then
    CURRENT_USER="aaxyat"
fi
USER_HOME="/home/${CURRENT_USER}"
if [ "${CURRENT_USER}" == "root" ]; then
    USER_HOME="/root"
fi

PROJECTS_DIR="${USER_HOME}/projects/php"

# -------------------------------------------------------------------
# 1. Workspace Directory & Permissions (/home/aaxyat/projects/php)
# -------------------------------------------------------------------
show_progress 1 "Configuring PHP project workspace at '${PROJECTS_DIR}'"

info "Creating project root directory structure..."
$SUDO mkdir -p "${PROJECTS_DIR}"
$SUDO mkdir -p "${PROJECTS_DIR}/mims"
$SUDO mkdir -p "${PROJECTS_DIR}/erp"
$SUDO mkdir -p "${PROJECTS_DIR}/college"

# Set ownership to current user and www-data group with 775 permissions
$SUDO usermod -aG www-data "${CURRENT_USER}" 2>/dev/null || true
$SUDO chown -R "${CURRENT_USER}:www-data" "${USER_HOME}/projects"
$SUDO chmod -R 775 "${USER_HOME}/projects"

# Generate a sleek dark-mode index.php in project root if missing
INDEX_FILE="${PROJECTS_DIR}/index.php"
if [ ! -f "${INDEX_FILE}" ]; then
    info "Generating developer dashboard (index.php)..."
    $SUDO tee "${INDEX_FILE}" >/dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WSL PHP Development Server</title>
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --accent: #38bdf8;
            --text: #f8fafc;
            --text-dim: #94a3b8;
            --border: #334155;
            --success: #4ade80;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 40px 20px;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 900px;
            width: 100%;
        }
        header {
            margin-bottom: 30px;
            border-bottom: 1px solid var(--border);
            padding-bottom: 20px;
        }
        h1 { margin: 0 0 10px 0; color: var(--accent); font-size: 2rem; }
        p { margin: 0; color: var(--text-dim); }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 20px;
            transition: transform 0.2s, border-color 0.2s;
            text-decoration: none;
            color: var(--text);
        }
        .card:hover {
            transform: translateY(-3px);
            border-color: var(--accent);
        }
        .card h3 { margin: 0 0 8px 0; font-size: 1.2rem; color: var(--accent); }
        .card span { font-size: 0.85rem; color: var(--text-dim); }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 6px;
            background: rgba(56, 189, 248, 0.1);
            color: var(--accent);
            font-size: 0.8rem;
            margin-top: 10px;
        }
        .tools {
            display: flex;
            gap: 15px;
            margin-top: 30px;
        }
        .tool-btn {
            background: var(--card-bg);
            border: 1px solid var(--border);
            color: var(--accent);
            padding: 10px 18px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: bold;
            font-size: 0.9rem;
        }
        .tool-btn:hover { background: var(--border); }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>⚡ WSL PHP Dev Workspace</h1>
            <p>Serving from <code>/home/aaxyat/projects/php</code> | PHP <?php echo phpversion(); ?></p>
        </header>

        <h2>📂 Active Projects</h2>
        <div class="grid">
            <?php
            $dir = __DIR__;
            $items = scandir($dir);
            $count = 0;
            foreach ($items as $item) {
                if ($item[0] === '.' || !is_dir($dir . '/' . $item)) continue;
                $count++;
                echo '<a href="/' . htmlspecialchars($item) . '" class="card">';
                echo '<h3>' . htmlspecialchars($item) . '</h3>';
                echo '<span>http://localhost/' . htmlspecialchars($item) . '</span><br>';
                echo '<span class="badge">http://' . htmlspecialchars($item) . '.local</span>';
                echo '</a>';
            }
            if ($count === 0) {
                echo '<p>No project subfolders found yet in ' . htmlspecialchars($dir) . '</p>';
            }
            ?>
        </div>

        <h2>🛠️ Quick Dev Tools</h2>
        <div class="tools">
            <a href="/phpmyadmin" target="_blank" class="tool-btn">🗄️ phpMyAdmin</a>
            <a href="?phpinfo=1" class="tool-btn">ℹ️ PHP Info</a>
        </div>
        <?php
        if (isset($_GET['phpinfo'])) {
            echo '<hr style="margin-top:30px; border-color:var(--border);">';
            phpinfo();
        }
        ?>
    </div>
</body>
</html>
EOF
    $SUDO chown "${CURRENT_USER}:www-data" "${INDEX_FILE}"
    $SUDO chmod 664 "${INDEX_FILE}"
fi

# Add sample index pages to demo projects
for proj in mims erp college; do
    PROJ_INDEX="${PROJECTS_DIR}/${proj}/index.php"
    if [ ! -f "${PROJ_INDEX}" ]; then
        $SUDO tee "${PROJ_INDEX}" >/dev/null << EOF
<?php
echo "<h1>Welcome to " . ucfirst('${proj}') . " Application</h1>";
echo "<p>Running on Apache + PHP " . phpversion() . " in WSL!</p>";
echo "<p>Virtual Host URL: <code>http://${proj}.local</code></p>";
EOF
        $SUDO chown "${CURRENT_USER}:www-data" "${PROJ_INDEX}"
        $SUDO chmod 664 "${PROJ_INDEX}"
    fi
done

success "PHP project workspace initialized at ${PROJECTS_DIR}."

# -------------------------------------------------------------------
# 2. Apache2 & PHP Suite Installation
# -------------------------------------------------------------------
show_progress 2 "Installing Apache2 & full PHP extension suite"

info "Updating package repositories..."
run_boxed "$SUDO apt update -y" || true

info "Installing Apache2 web server and PHP modules..."
run_boxed "pkg_install apache2 libapache2-mod-php php php-cli php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl php-bcmath php-soap php-sqlite3" || true

success "Apache2 & PHP installed."

# -------------------------------------------------------------------
# 3. MariaDB/MySQL Server & Database Setup
# -------------------------------------------------------------------
show_progress 3 "Installing & configuring MariaDB/MySQL database server"

info "Installing MariaDB database server..."
run_boxed "pkg_install mariadb-server mariadb-client" || true

info "Starting MariaDB service..."
$SUDO systemctl unmask mariadb 2>/dev/null || $SUDO systemctl unmask mysql 2>/dev/null || true
$SUDO systemctl enable --now mariadb 2>/dev/null || $SUDO systemctl enable --now mysql 2>/dev/null || true

info "Configuring MySQL root & developer user '${CURRENT_USER}'..."
$SUDO mysql -u root << EOF || true
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('root');
CREATE USER IF NOT EXISTS '${CURRENT_USER}'@'localhost' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO '${CURRENT_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

success "MariaDB database server active (User: ${CURRENT_USER} / root, Pass: root)."

# -------------------------------------------------------------------
# 4. phpMyAdmin Non-Interactive Installation & Apache Alias
# -------------------------------------------------------------------
show_progress 4 "Installing & configuring phpMyAdmin"

# Preseed debconf for silent phpMyAdmin setup
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | $SUDO debconf-set-selections 2>/dev/null || true
echo "phpmyadmin phpmyadmin/app-password-confirm password root" | $SUDO debconf-set-selections 2>/dev/null || true
echo "phpmyadmin phpmyadmin/mysql/admin-pass password root" | $SUDO debconf-set-selections 2>/dev/null || true
echo "phpmyadmin phpmyadmin/mysql/app-pass password root" | $SUDO debconf-set-selections 2>/dev/null || true
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | $SUDO debconf-set-selections 2>/dev/null || true

info "Installing phpMyAdmin..."
run_boxed "pkg_install phpmyadmin" || true

# Ensure phpMyAdmin apache config is included
if [ -f /etc/phpmyadmin/apache.conf ]; then
    if [ ! -f /etc/apache2/conf-available/phpmyadmin.conf ]; then
        $SUDO ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
    fi
    $SUDO a2enconf phpmyadmin 2>/dev/null || true
fi

success "phpmyadmin configured at http://localhost/phpmyadmin"

# -------------------------------------------------------------------
# 5. Apache DocumentRoot & Automatic Virtual Hosts (.local)
# -------------------------------------------------------------------
show_progress 5 "Configuring Apache DocumentRoot & Automatic Virtual Hosts"

info "Enabling Apache modules (rewrite, vhost_alias, headers, env)..."
$SUDO a2enmod rewrite vhost_alias headers env 2>/dev/null || true

# Configure Default Apache Site (http://localhost/ -> /home/aaxyat/projects/php)
info "Configuring default Apache VirtualHost for '/home/aaxyat/projects/php'..."
$SUDO tee /etc/apache2/sites-available/000-default.conf >/dev/null << EOF
<VirtualHost *:80>
    ServerName localhost
    ServerAdmin webmaster@localhost
    DocumentRoot ${PROJECTS_DIR}

    <Directory ${PROJECTS_DIR}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Configure Wildcard Fallback VirtualHosts (*.local -> /home/aaxyat/projects/php/*)
info "Configuring Wildcard Fallback Virtual Host (*.local)..."
$SUDO tee /etc/apache2/sites-available/zz-dynamic-vhosts.conf >/dev/null << EOF
# Automatic Wildcard Fallback Virtual Hosts: http://<folder>.local -> ${PROJECTS_DIR}/<folder>
<VirtualHost *:80>
    ServerAlias *.local
    VirtualDocumentRoot ${PROJECTS_DIR}/%1

    <Directory ${PROJECTS_DIR}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

$SUDO a2ensite 000-default.conf 2>/dev/null || true
$SUDO a2ensite zz-dynamic-vhosts.conf 2>/dev/null || true

info "Restarting Apache2 web server..."
$SUDO systemctl restart apache2 2>/dev/null || $SUDO service apache2 restart 2>/dev/null || true
success "Apache2 web server configured and active."

# -------------------------------------------------------------------
# 6. Installing 'newsite' CLI Manager into /usr/local/bin/newsite
# -------------------------------------------------------------------
show_progress 6 "Installing 'newsite' CLI tool into /usr/local/bin/newsite"

NEWSITE_SRC="$(dirname "$0")/newsite"
if [ -f "$NEWSITE_SRC" ]; then
    $SUDO cp "$NEWSITE_SRC" /usr/local/bin/newsite
    $SUDO chmod +x /usr/local/bin/newsite
    success "'newsite' CLI manager installed."
else
    # Fetch from repository if running via curl pipe
    $SUDO curl -sSLf https://raw.githubusercontent.com/aaxyat/WindowsSetup/master/vps/newsite -o /usr/local/bin/newsite 2>/dev/null || true
    $SUDO chmod +x /usr/local/bin/newsite 2>/dev/null || true
    success "'newsite' CLI manager fetched and installed."
fi

# Add dev control aliases to Fish shell config
FISH_CONF_FILE="${USER_HOME}/.config/fish/config.fish"
if [ -f "${FISH_CONF_FILE}" ]; then
    if ! $SUDO grep -q "alias devstart" "${FISH_CONF_FILE}" 2>/dev/null; then
        $SUDO tee -a "${FISH_CONF_FILE}" >/dev/null << 'EOF'

# --- PHP Dev Server Control Aliases ---
alias devstart='sudo systemctl start apache2 mariadb'
alias devstop='sudo systemctl stop apache2 mariadb'
alias devrestart='sudo systemctl restart apache2 mariadb'
alias devstatus='sudo systemctl status apache2 mariadb'
EOF
    fi
fi

# -------------------------------------------------------------------
# Completion Dashboard & Instructions
# -------------------------------------------------------------------
echo ""
echo -e "${GREEN}╭──────────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GREEN}│${RESET} ${BOLD}${WHITE}  🎉  WSL PHP DEV ENVIRONMENT & 'newsite' CLI READY!  🎉               ${RESET}${GREEN}│${RESET}"
echo -e "${GREEN}├──────────────────────────────────────────────────────────────────────────┤${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• DocumentRoot${RESET}     : ${BOLD}${WHITE}${PROJECTS_DIR}${RESET}                      ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• Web Dashboard${RESET}    : ${BOLD}${YELLOW}http://localhost${RESET}                           ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• phpMyAdmin${RESET}       : ${BOLD}${YELLOW}http://localhost/phpmyadmin${RESET}                ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• MySQL User/Pass${RESET}  : ${BOLD}${WHITE}${CURRENT_USER} / root${RESET}                            ${GREEN}│${RESET}"
echo -e "${GREEN}│${RESET}  ${CYAN}• CLI Command${RESET}      : ${BOLD}${CYAN}newsite <folder> [domain]${RESET}                   ${GREEN}│${RESET}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as administrator." -ForegroundColor Red
    pause
    exit
}

# Beautiful UI Functions
function Show-Banner {
    Clear-Host
    $banner = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🚀 WINDOWS SYSTEM SETUP INSTALLER 🚀                     ║
║                                                                              ║
║                      Automated Package Installation                          ║
║                           & System Configuration                             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host ""
}

function Show-Section {
    param([string]$Title, [string]$Icon = "🔧")
    Write-Host ""
    Write-Host "┌─" -NoNewline -ForegroundColor DarkGray
    Write-Host "─" * ($Title.Length + 4) -NoNewline -ForegroundColor DarkGray
    Write-Host "─┐" -ForegroundColor DarkGray
    Write-Host "│  $Icon $Title  │" -ForegroundColor Yellow
    Write-Host "└─" -NoNewline -ForegroundColor DarkGray
    Write-Host "─" * ($Title.Length + 4) -NoNewline -ForegroundColor DarkGray
    Write-Host "─┘" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Status {
    param(
        [string]$Message,
        [string]$Status = "Info",
        [switch]$NoNewline
    )
    
    $icons = @{
        "Success" = "✅"
        "Error"   = "❌"
        "Warning" = "⚠️"
        "Info"    = "ℹ️"
        "Progress" = "⏳"
        "Done"    = "✨"
    }
    
    $colors = @{
        "Success" = "Green"
        "Error"   = "Red"
        "Warning" = "Yellow"
        "Info"    = "Cyan"
        "Progress" = "Magenta"
        "Done"    = "Green"
    }
    
    $icon = $icons[$Status]
    $color = $colors[$Status]
    
    if ($NoNewline) {
        Write-Host "$icon $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

function Show-InstallationProgress {
    param (
        [int]$Current,
        [int]$Total,
        [string]$PackageName,
        [string]$Type,
        [string]$Status = "Installing"
    )
    
    $percentComplete = [math]::Round(($Current / $Total) * 100)
    $progressBar = Create-ProgressBar -Percent $percentComplete -Width 50
    
    Write-Host ""
    Write-Host "  📦 Package: " -NoNewline -ForegroundColor Cyan
    Write-Host $PackageName -ForegroundColor White
    Write-Host "  📊 Progress: " -NoNewline -ForegroundColor Cyan
    Write-Host "($Current/$Total) " -NoNewline -ForegroundColor Yellow
    Write-Host "$percentComplete%" -ForegroundColor Green
    Write-Host "  $progressBar" -ForegroundColor Blue
    Write-Host ""
    
    Write-Progress -Activity "Installing $Type" -Status "$Status $PackageName" -PercentComplete $percentComplete
}

function Create-ProgressBar {
    param(
        [int]$Percent,
        [int]$Width = 50
    )
    
    $filled = [math]::Floor($Width * $Percent / 100)
    $empty = $Width - $filled
    
    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $Percent%"
}

function Show-Summary {
    param(
        [int]$Successful,
        [int]$Failed,
        [int]$Total
    )
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           INSTALLATION SUMMARY        ║" -ForegroundColor Cyan
    Write-Host "╠═══════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  Total Packages: " -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-19}" -f $Total) -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "║  Successful: " -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-23}" -f $Successful) -NoNewline -ForegroundColor Green
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "║  Failed: " -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-27}" -f $Failed) -NoNewline -ForegroundColor Red
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Initialize
Show-Banner

# Define the log file path
Show-Section "System Initialization" "🔧"
$logDir = "$HOME\Documents\logs"
$logFile = "$logDir\apps-setup.log"

# Create the logs directory if it doesn't exist
if (!(Test-Path -Path $logDir)) {
    Show-Status "Creating logs directory..." "Progress"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Show-Status "Logs directory created successfully" "Success"
} else {
    Show-Status "Logs directory already exists" "Info"
}

# Start the transcript
Start-Transcript -Path $logFile -Append
Show-Status "Logging started: $logFile" "Success"

# Set the global execution policy to unrestricted
Show-Status "Setting execution policy..." "Progress"
Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force
Show-Status "Execution policy set to Unrestricted" "Success"

# Check if Chocolatey is installed
Show-Section "Package Manager Setup" "📦"
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Show-Status "Installing Chocolatey..." "Progress"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Show-Status "Chocolatey installed successfully" "Success"
} else {
    Show-Status "Chocolatey is already installed" "Info"
}

# Set WinGet downloader to WinINET
Show-Section "WinGet Configuration" "⚙️"
Show-Status "Configuring WinGet downloader..." "Progress"
try {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
    $settingsDir = Split-Path -Parent $settingsPath
    
    # Create settings directory if it doesn't exist
    if (!(Test-Path -Path $settingsDir)) {
        New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
    }
    
    # Initialize settings object
    $settings = $null

    # Check if settings file exists
    if (Test-Path -Path $settingsPath) {
        $fileContent = Get-Content -Path $settingsPath -Raw -ErrorAction SilentlyContinue
        
        # Check if file content is not null or empty
        if (![string]::IsNullOrWhiteSpace($fileContent)) {
            try {
                $settings = $fileContent | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Show-Status "Settings file contains invalid JSON, creating new one" "Warning"
                $settings = $null
            }
        } else {
            Show-Status "Settings file is empty, creating new one" "Warning"
        }
    }

    # Create a new settings object if it's null
    if ($null -eq $settings) {
        $settings = [PSCustomObject]@{
            network = [PSCustomObject]@{
                downloader = "wininet"
            }
        }
    } else {
        # Ensure network property exists
        if (-not $settings.PSObject.Properties.Match("network")) {
            $settings | Add-Member -NotePropertyName "network" -NotePropertyValue ([PSCustomObject]@{downloader = "wininet"})
        }
        # Ensure downloader property exists inside network
        if (-not $settings.network.PSObject.Properties.Match("downloader")) {
            $settings.network | Add-Member -NotePropertyName "downloader" -NotePropertyValue "wininet"
        } else {
            # Update existing downloader property
            $settings.network.downloader = "wininet"
        }
    }

    # Save settings with proper JSON formatting
    $settings | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $settingsPath -Encoding UTF8
    Show-Status "WinGet downloader configured successfully" "Success"
} catch {
    Show-Status "Failed to configure WinGet downloader: $_" "Error"
}

# Check if PowerShell 7 is installed using winget
Show-Section "PowerShell 7 Setup" "💻"
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Show-Status "Installing PowerShell 7..." "Progress"
    winget install --accept-source-agreements --accept-package-agreements -e --id Microsoft.PowerShell 
    Show-Status "PowerShell 7 installed successfully" "Success"
} else {
    Show-Status "PowerShell 7 is already installed" "Info"
}

# Check if the shell used to execute the script is not PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Show-Status "PowerShell 7 is required to continue" "Error"
    pause
    exit
}

# Setup Brave Registry Keys
Show-Section "Browser Configuration" "🌐"
Show-Status "Configuring Brave Browser settings..." "Progress"
$bravePath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"

# Ensure the registry path exists
if (-not (Test-Path $bravePath)) {
    New-Item -Path $bravePath -Force | Out-Null
}

# Apply Brave Browser settings
$braveSettings = @{
    "BraveRewardsDisabled" = 1
    "BraveWalletDisabled" = 1
    "BraveVPNDisabled" = 1
    "BraveAIChatEnabled" = 0
    "PasswordManagerEnabled" = 0
    "HttpsUpgradesEnabled" = 0
    "BraveAdsEnabled" = 0
    "BuiltInDnsClientEnabled" = 1
}

foreach ($setting in $braveSettings.GetEnumerator()) {
    Set-ItemProperty -Path $bravePath -Name $setting.Key -Value $setting.Value -Type DWord
}
Show-Status "Brave Browser configured successfully" "Success"

# Copy AHK Script and execute it 
Show-Section "Utility Setup" "🔧"
Show-Status "Setting up shortcuts utility..." "Progress"
try {
    Invoke-WebRequest -Uri "https://github.com/aaxyat/WindowsSetup/raw/main/ConfigFiles/shortcuts.exe" -OutFile "$env:TEMP\shortcut.exe"
    
    $shellStartup = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $shellStartup "shortcut.exe"
    Copy-Item -Path "$env:TEMP\shortcut.exe" -Destination $shortcutPath -Force
    
    Start-Process -FilePath $shortcutPath -NoNewWindow
    Show-Status "Shortcuts utility configured successfully" "Success"
} catch {
    Show-Status "Failed to setup shortcuts utility: $_" "Error"
}

# Create directories
Show-Section "Directory Setup" "📁"
$directories = @{
    "Github" = Join-Path $HOME\Documents "Github"
    "Projects" = Join-Path $HOME\Documents "Projects"
}

foreach ($dir in $directories.GetEnumerator()) {
    if (!(Test-Path -Path $dir.Value)) {
        Show-Status "Creating $($dir.Key) directory..." "Progress"
        New-Item -ItemType Directory -Force -Path $dir.Value | Out-Null
        Show-Status "$($dir.Key) directory created" "Success"
    } else {
        Show-Status "$($dir.Key) directory already exists" "Info"
    }
}

# Enhanced Package Installation Function
function Install-Packages {
    param (
        [string[]]$PackageIds,
        [string]$Type,
        [string]$Manager = "winget"
    )
    
    Show-Section "$Type Installation" "📦"
    
    $activePackages = ($PackageIds | Where-Object { $_ -notmatch '^\s*#' })
    $total = $activePackages.Count
    $current = 0
    $successful = 0
    $failed = 0
    
    Show-Status "Starting installation of $total packages..." "Info"
    
    foreach ($package in $PackageIds) {
        if ($package -match '^\s*#') {
            continue
        }
        
        $current++
        Show-InstallationProgress -Current $current -Total $total -PackageName $package -Type $Type
        
        try {
            if ($Manager -eq "winget") {
                $result = winget install --accept-package-agreements --id $package 2>&1
            } elseif ($Manager -eq "choco") {
                $result = choco install -y $package 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Show-Status "✅ $package installed successfully" "Success"
                $successful++
            } else {
                Show-Status "❌ Failed to install $package" "Error"
                $failed++
            }
        } catch {
            Show-Status "❌ Error installing $package`: $_" "Error"
            $failed++
        }
    }
    
    Write-Progress -Activity "Installing $Type" -Completed
    Show-Summary -Successful $successful -Failed $failed -Total $total
}

# Package Lists
$chocoPackages = @("python", "autohotkey", "gsudo", "adb", "firacode", "curl")

$wingetPackages = @(
    'WireGuard.WireGuard',
    'Brave.Brave',
    'Bitwarden.Bitwarden',
    'Bitwarden.CLI',
    'WinDirStat.WinDirStat',
    'amir1376.ABDownloadManager',
    'qBittorrent.qBittorrent',
    'Git.Git',
    'yt-dlp.yt-dlp',
    '7zip.7zip',
    'Starship.Starship',
    'VideoLAN.VLC',
    'Rclone.Rclone',
    'WinFsp.WinFsp',
    'NSSM.NSSM',
    'Stremio.Stremio',
    'junegunn.fzf',
    'ajeetdsouza.zoxide',
    'Notepad++.Notepad++',
    'calibre.calibre',
    'RevoUninstaller.RevoUninstaller',
    'Amazon.SendToKindle',
    'StartIsBack.StartAllBack',
    'AppWork.JDownloader',
    'CodecGuide.K-LiteCodecPack.Full',
    'JetBrains.Toolbox',
    'pCloudAG.pCloudDrive',
    'Mozilla.Firefox',
    'GitHub.GitHubDesktop',
    'tailscale.tailscale',
    'TechNobo.TcNoAccountSwitcher',
    'Valve.Steam',
    'Microsoft.PowerToys',
    'voidtools.Everything',
    'lin-ycv.EverythingPowerToys',
    'RadolynLabs.AyuGramDesktop',
    'Microsoft.VisualStudioCode',
    'IPVanish.IPVanish',
    'Ferdium.Ferdium',
    'SublimeHQ.SublimeText.4',
    'Jellyfin.JellyfinMediaPlayer',
    'IanWalton.JellyfinMPVShim',
    'Termius.Termius',
    'XMBCFoundation.Kodi',
    'mpv.net',
    'Rakuten.Viber',
    "AdGuard.AdGuard",
    "Hugo.Hugo.Extended",
    "Genymobile.scrcpy",
    "Microsoft.Sysinternals.ProcessMonitor",
    "EpicGames.EpicGamesLauncher",
    "MarkText.MarkText"
)

$storePackages = @(
    '9P92N00QV14J', # HP Command Center
    '9P1FBSLRNM43', # BatteryTracker
    '9NKSQGP7F2NH', # Whatsapp
    '9n0dx20hk701' # Windows Terminal
)

# Execute installations
Install-Packages -PackageIds $chocoPackages -Type "Chocolatey Applications" -Manager "choco"
Install-Packages -PackageIds $wingetPackages -Type "Regular Applications"
Install-Packages -PackageIds $storePackages -Type "Microsoft Store Applications"

# Final completion message
Show-Section "Installation Complete" "🎉"
Show-Status "All installations have been completed!" "Done"
Show-Status "Check the log file for detailed information: $logFile" "Info"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║                    🎉 SETUP COMPLETED SUCCESSFULLY! 🎉                       ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║                     Thank you for using this installer!                     ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Stop the transcript
Stop-Transcript
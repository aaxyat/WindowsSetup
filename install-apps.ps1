# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as administrator."
    pause
    exit
 }
 
 # Define the log file path
 $logDir = "$HOME\Documents\logs"
 $logFile = "$logDir\apps-setup.log"
 
 
 # Create the logs directory if it doesn't exist
 if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir
 }
 
 # Start the transcript
 Start-Transcript -Path $logFile -Append
 
 
 # Set the global execution policy to unrestricted
 Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force
 
 # Check if Chocolatey is installed
 if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Host "Chocolatey is installed."
 }
 else {
    Write-Host "Chocolatey is already installed."
 }

# Set WinGet downloader to WinINET
Write-Host "Setting WinGet downloader to WinINET..."
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
                Write-Host "Settings file contains invalid JSON. Creating a new settings object." -ForegroundColor Yellow
                $settings = $null
            }
        } else {
            Write-Host "Settings file is empty. Creating a new settings object." -ForegroundColor Yellow
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
    Write-Host "WinGet downloader set to WinINET successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to set WinGet downloader: $_" -ForegroundColor Red
}

 
 # Check if PowerShell 7 is installed using winget
 if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    # Install PowerShell 7 using winget
    Write-Host "PowerShell 7 is not installed. Installing PowerShell 7..."
    winget install  --accept-source-agreements --accept-package-agreements -e --id Microsoft.PowerShell 
    Write-Host "PowerShell 7 is installed."
 }
 else {
    Write-Host "PowerShell 7 is already installed."
 }
 
 # Check if the shell used to execute the script is not PowerShell 7
 if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "You need to use PowerShell 7 to execute this script."
    pause
    exit
 }

# Install the required packages using Chocolatey
$chocoPackages = @("python", "autohotkey", "gsudo", "qbittorrent", "yt-dlp", "k-litecodecpackfull", "revo-uninstaller", "adb", "firacode", "curl", "stremio")

function Show-InstallationProgress {
    param (
        [int]$Current,
        [int]$Total,
        [string]$PackageName,
        [string]$Type
    )
    
    $percentComplete = [math]::Round(($Current / $Total) * 100)
    Write-Host "[$Type] Installing ($Current/$Total): $PackageName" -ForegroundColor Cyan
    Write-Progress -Activity "Installing $Type" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
}

function Install-Packages {
    param (
        [string[]]$PackageIds,
        [string]$Type,
        [string]$Manager = "winget"
    )
    
    Write-Host "`nStarting $Type installation..." -ForegroundColor Blue
    
    $activePackages = ($PackageIds | Where-Object { $_ -notmatch '^\s*#' })
    $total = $activePackages.Count
    $current = 0
    
    foreach ($package in $PackageIds) {
        if ($package -match '^\s*#') {
            continue
        }
        
        $current++
        Show-InstallationProgress -Current $current -Total $total -PackageName $package -Type $Type
        
        if ($Manager -eq "winget") {
            winget install --accept-package-agreements --id $package
        } elseif ($Manager -eq "choco") {
            choco install -y $package
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully installed $package" -ForegroundColor Green
        } else {
            Write-Host "Failed to install $package" -ForegroundColor Red
        }
    }
    
    Write-Host "`n$Type installation completed.`n" -ForegroundColor Blue
    Write-Progress -Activity "Installing $Type" -Completed
}

# Main installation process
Clear-Host
Write-Host "Starting package installation process..." -ForegroundColor Blue

# Install Chocolatey packages
Install-Packages -PackageIds $chocoPackages -Type "Chocolatey Applications" -Manager "choco"

# Regular winget packages
$wingetPackages = @(
    'WinDirStat.WinDirStat',
    'amir1376.ABDownloadManager',
    'Git.Git',
    'Starship.Starship',
    'VideoLAN.VLC',
    'Brave.Brave',
    'Rclone.Rclone',
    'WinFsp.WinFsp',
    'M2Team.NanaZip',
    'NSSM.NSSM',
    'junegunn.fzf',
    'ajeetdsouza.zoxide',
    'Notepad++.Notepad++',
    'calibre.calibre',
    'Amazon.SendToKindle',
    # 'Giorgiotani.Peazip',
    # 'Tonec.InternetDownloadManager',
    'StartIsBack.StartAllBack',
    'AppWork.JDownloader',
    # 'HeroicGamesLauncher.HeroicGamesLauncher',
    'Bitwarden.Bitwarden',
    'Bitwarden.CLI',
    'JetBrains.Toolbox',
    'pCloudAG.pCloudDrive',
    'WireGuard.WireGuard',
    'Mozilla.Firefox',
    'GitHub.GitHubDesktop',
    'tailscale.tailscale',
    # 'Axosoft.GitKraken',
    'TechNobo.TcNoAccountSwitcher',
    # 'hluk.CopyQ',
    'Valve.Steam',
    'Microsoft.PowerToys',
    'voidtools.Everything',
    'lin-ycv.EverythingPowerToys',
    'RadolynLabs.AyuGramDesktop',
    'Microsoft.VisualStudioCode',
    'IPVanish.IPVanish',
    # 'SoftDeluxe.FreeDownloadManager',
    # 'spacedrive.Spacedrive',
    'wez.wezterm',
    'Ferdium.Ferdium',
    'SublimeHQ.SublimeText.4',
    'Jellyfin.JellyfinMediaPlayer',
    'IanWalton.JellyfinMPVShim',
    'futo-org.Grayjay.Desktop',
    'Termius.Termius',
    'XMBCFoundation.Kodi',
    'mpv.net',
    'Rakuten.Viber'

)

# Windows Store packages
$storePackages = @(
    '9P92N00QV14J', # HP Command Center
    '9P1FBSLRNM43', # BatteryTracker
    # '9PCKT2B7DZMW', # Battery Percentage icon
    # '9NM8N7DQ3Z5F', # WinDynamicDesktop
   '9NKSQGP7F2NH', # Whatsapp
    # '9NK1GDVPX09V', #Termius
    # '9N97ZCKPD60Q', # Unigram
    # '9ncrcvjc50wl', # WinnowMail
    '9n0dx20hk701' # Windows Terminal
    # '9PMHZVM588P4'  # Bluemail
)

# Install regular packages
Install-Packages -PackageIds $wingetPackages -Type "Regular Applications"

# Install Store packages
Install-Packages -PackageIds $storePackages -Type "Microsoft Store Applications"

Write-Host "All installations completed." -ForegroundColor Green




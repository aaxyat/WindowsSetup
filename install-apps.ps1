# ASCII-Only Windows Setup Script
# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as administrator." -ForegroundColor Red
    pause
    exit
}

# ASCII Icons
function Get-Icon {
    param([string]$Name)
    
    $asciiIcons = @{
        "rocket" = "[*]"
        "wrench" = "[+]"
        "package" = "[P]"
        "gear" = "[C]"
        "computer" = "[PC]"
        "globe" = "[W]"
        "folder" = "[D]"
        "success" = "[OK]"
        "error" = "[X]"
        "warning" = "[!]"
        "info" = "[i]"
        "progress" = "[~]"
        "done" = "[*]"
        "installing" = "[>]"
        "separator" = "="
        "party" = "[!]"
        "utility" = "[U]"
        "complete" = "[DONE]"
    }
    return $asciiIcons[$Name]
}

function Show-Banner {
    Clear-Host
    $rocket = Get-Icon "rocket"
    
    $banner = @"
================================================================================
                                                                              
                    $rocket WINDOWS SYSTEM SETUP INSTALLER $rocket                     
                                                                              
                      Automated Package Installation                          
                           & System Configuration                             
                                                                              
================================================================================
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host ""
}

function Show-Section {
    param([string]$Title, [string]$IconName = "wrench")
    
    $icon = Get-Icon $IconName
    $separator = Get-Icon "separator"
    
    Write-Host ""
    Write-Host "$separator" -NoNewline -ForegroundColor DarkGray
    Write-Host "$separator" * ($Title.Length + 6) -ForegroundColor DarkGray
    Write-Host "  $icon $Title" -ForegroundColor Yellow
    Write-Host "$separator" -NoNewline -ForegroundColor DarkGray
    Write-Host "$separator" * ($Title.Length + 6) -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Status {
    param(
        [string]$Message,
        [string]$Status = "Info",
        [switch]$NoNewline
    )
    
    $icon = Get-Icon $Status.ToLower()
    
    $colors = @{
        "Success" = "Green"
        "Error"   = "Red"
        "Warning" = "Yellow"
        "Info"    = "Cyan"
        "Progress" = "Magenta"
        "Done"    = "Green"
    }
    
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
    Write-Host "  [P] Package: " -NoNewline -ForegroundColor Cyan
    Write-Host $PackageName -ForegroundColor White
    Write-Host "  [%] Progress: " -NoNewline -ForegroundColor Cyan
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
    
    $bar = "#" * $filled + "-" * $empty
    return "[$bar] $Percent%"
}

function Show-Summary {
    param(
        [int]$Successful,
        [int]$Failed,
        [int]$Total
    )
    
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "           INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  Total Packages: $Total" -ForegroundColor White
    Write-Host "  Successful: $Successful" -ForegroundColor Green
    Write-Host "  Failed: $Failed" -ForegroundColor Red
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
}

# Initialize
Show-Banner

# Define the log file path
Show-Section "System Initialization" "wrench"
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
Show-Section "Package Manager Setup" "package"
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Show-Status "Installing Chocolatey..." "Progress"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Show-Status "Chocolatey installed successfully" "Success"
} else {
    Show-Status "Chocolatey is already installed" "Info"
}

# Set WinGet downloader to WinINET
Show-Section "WinGet Configuration" "gear"
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
Show-Section "PowerShell 7 Setup" "computer"
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
Show-Section "Browser Configuration" "globe"
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

# Setup Chrome Registry Keys for MV2 Support
Show-Status "Configuring Chrome Browser settings..." "Progress"
$chromePath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

# Ensure the registry path exists
if (-not (Test-Path $chromePath)) {
    New-Item -Path $chromePath -Force | Out-Null
}

# Apply Chrome Browser settings for MV2 support
$chromeSettings = @{
    "ExtensionManifestV2Availability" = 2  # 2 = Enable for all extensions
}

foreach ($setting in $chromeSettings.GetEnumerator()) {
    Set-ItemProperty -Path $chromePath -Name $setting.Key -Value $setting.Value -Type DWord
}
Show-Status "Chrome Browser configured successfully" "Success"

# Copy AHK Script and execute it 
Show-Section "Utility Setup" "utility"
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
Show-Section "Directory Setup" "folder"
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

# Enhanced Package Installation Function with Clean Output
function Install-Packages {
    param (
        [string[]]$PackageIds,
        [string]$Type,
        [string]$Manager = "winget"
    )
    
    Show-Section "$Type Installation" "package"
    
    $activePackages = ($PackageIds | Where-Object { $_ -notmatch '^\s*#' })
    $total = $activePackages.Count
    $current = 0
    $successful = 0
    $failed = 0
    $completedPackages = @()
    
    Show-Status "Starting installation of $total packages..." "Info"
    Write-Host ""
    
    foreach ($package in $PackageIds) {
        if ($package -match '^\s*#') {
            continue
        }
        
        $current++
        
        # Clear console but keep the header and completed packages
        Clear-Host
        Show-Banner
        Show-Section "$Type Installation" "package"
        
        # Show completed packages
        if ($completedPackages.Count -gt 0) {
            foreach ($completed in $completedPackages) {
                Write-Host $completed
            }
            Write-Host ""
        }
        
        # Show current installation
        $installingIcon = Get-Icon "installing"
        Write-Host "$installingIcon Installing Package $current/$total`: " -NoNewline -ForegroundColor Cyan
        Write-Host $package -ForegroundColor White
        
        Write-Host ("=" * 80) -ForegroundColor DarkGray
        Write-Host ""
        
        try {
            if ($Manager -eq "winget") {
                # Direct execution to show real-time output
                & winget install --accept-package-agreements --id $package
                $exitCode = $LASTEXITCODE
            } elseif ($Manager -eq "choco") {
                # Direct execution to show real-time output
                & choco install -y $package
                $exitCode = $LASTEXITCODE
            }
            
            $successIcon = Get-Icon "success"
            $errorIcon = Get-Icon "error"
            
            if ($exitCode -eq 0) {
                $completedPackages += "$successIcon Package $current/$total`: $package installed successfully"
                $successful++
            } else {
                $completedPackages += "$errorIcon Package $current/$total`: $package failed (Exit Code: $exitCode)"
                $failed++
            }
        } catch {
            $errorIcon = Get-Icon "error"
            $completedPackages += "$errorIcon Package $current/$total`: $package error - $_"
            $failed++
        }
    }
    
    # Final display with all results
    Clear-Host
    Show-Banner
    Show-Section "$Type Installation Complete" "done"
    
    foreach ($completed in $completedPackages) {
        Write-Host $completed
    }
    
    Write-Host ""
    Show-Summary -Successful $successful -Failed $failed -Total $total
}

# Package Lists
$chocoPackages = @("python", "autohotkey", "gsudo", "adb", "firacode", "curl", "qbittorrent")

$wingetPackages = @(
    'Google.Chrome',
    'WireGuard.WireGuard',
    'Tonec.InternetDownloadManager',
    'Bitwarden.Bitwarden',
    'Bitwarden.CLI',
    'WinDirStat.WinDirStat',
    # 'amir1376.ABDownloadManager',
    'Git.Git',
    'yt-dlp.yt-dlp',
    '7zip.7zip',
    'Starship.Starship',
    'VideoLAN.VLC',
    'Daum.PotPlayer',
    'Rclone.Rclone',
    'WinFsp.WinFsp',
    'NSSM.NSSM',
    'Stremio.Stremio',
    'junegunn.fzf',
    'ajeetdsouza.zoxide',
    'Notepad++.Notepad++',
    'calibre.calibre',
    'RevoUninstaller.RevoUninstaller',
    'StartIsBack.StartAllBack',
    'AppWork.JDownloader',
    'CodecGuide.K-LiteCodecPack.Full',
    'JetBrains.Toolbox',
    'pCloudAG.pCloudDrive',
    'Mozilla.Firefox',
    'GitHub.GitHubDesktop',
    'tailscale.tailscale',
    'Valve.Steam',
    'Microsoft.PowerToys',
    'voidtools.Everything',
    'lin-ycv.EverythingPowerToys',
    'RadolynLabs.AyuGramDesktop',
    'Microsoft.VisualStudioCode',
    'IPVanish.IPVanish',
    # 'Ferdium.Ferdium',
    'SublimeHQ.SublimeText.4',
    'Jellyfin.JellyfinMediaPlayer',
    'IanWalton.JellyfinMPVShim',
    'Termius.Termius',
    'mpv.net',
    'Rakuten.Viber',
    "AdGuard.AdGuard",
    "Hugo.Hugo.Extended",
    "Genymobile.scrcpy",
    "Microsoft.Sysinternals.ProcessMonitor",
    "EpicGames.EpicGamesLauncher",
    "MarkText.MarkText",
    "Amazon.Corretto.24.JDK",
    # "BrechtSanders.WinLibs.POSIX.UCRT"
)

# Base store packages for all systems
$storePackages = @(
    '9NKSQGP7F2NH', # Whatsapp
    '9n0dx20hk701' # Windows Terminal
)

# Check if this is an HP system and add HP-specific packages
Show-Status "Detecting system manufacturer..." "Progress"
try {
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    Show-Status "System manufacturer: $manufacturer" "Info"
    
    if ($manufacturer -like "*HP*" -or $manufacturer -like "*Hewlett*") {
        Show-Status "HP system detected - adding HP-specific applications" "Success"
        $storePackages += '9P92N00QV14J' # HP Command Center
        $storePackages += '9P1FBSLRNM43' # BatteryTracker
        Show-Status "Added: HP Command Center and BatteryTracker" "Info"
    } else {
        Show-Status "Non-HP system detected - skipping HP-specific applications" "Info"
    }
} catch {
    Show-Status "Could not detect manufacturer - skipping HP-specific applications: $_" "Warning"
}

# Execute installations
Install-Packages -PackageIds $chocoPackages -Type "Chocolatey Applications" -Manager "choco"
Install-Packages -PackageIds $wingetPackages -Type "Regular Applications"
Install-Packages -PackageIds $storePackages -Type "Microsoft Store Applications"

# Final completion message
Show-Section "Installation Complete" "complete"
Show-Status "All installations have been completed!" "Done"
Show-Status "Check the log file for detailed information: $logFile" "Info"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "                                                                              " -ForegroundColor Green
Write-Host "                    [!] SETUP COMPLETED SUCCESSFULLY! [!]                    " -ForegroundColor Green
Write-Host "                                                                              " -ForegroundColor Green
Write-Host "                     Thank you for using this installer!                     " -ForegroundColor Green
Write-Host "                                                                              " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

# Stop the transcript
Stop-Transcript
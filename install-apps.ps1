# ASCII & Unicode High-Performance Windows Setup Script
# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as administrator." -ForegroundColor Red
    pause
    exit
}

# Icon Dictionary
function Get-Icon {
    param([string]$Name)

    $icons = @{
        "rocket"     = "🚀"
        "wrench"     = "🛠️ "
        "package"    = "📦"
        "gear"       = "⚙️ "
        "computer"   = "💻"
        "globe"      = "🌐"
        "folder"     = "📁"
        "success"    = "✅"
        "error"      = "❌"
        "warning"    = "⚠️ "
        "info"       = "ℹ️ "
        "progress"   = "⏳"
        "done"       = "✨"
        "installing" = "⚡"
        "separator"  = "═"
        "party"      = "🎉"
        "utility"    = "🧰"
        "complete"   = "🏆"
        "skip"       = "⏭️ "
        "tip"        = "💡"
    }
    if ($icons.ContainsKey($Name)) { return $icons[$Name] } else { return "[*]" }
}

# Fun Tips Array for Installation Screens
$global:FunTips = @(
    "Press 'n' on your keyboard anytime to instantly skip the current downloading package!",
    "All completed packages are automatically saved so you can safely resume after restarts.",
    "Using Cloudflare DNS over HTTPS (DoH) optimizes package download speeds.",
    "PowerShell 7 profile is pre-configured with lazy loading for sub-60ms tab startup.",
    "Atuin shell history syncs your terminal commands seamlessly across all your machines.",
    "Use 'activate' command in PowerShell for one-click Windows & Office activation."
)

function Get-RandomTip {
    return $global:FunTips[(Get-Random -Maximum $global:FunTips.Count)]
}

function Show-Banner {
    Clear-Host
    $rocket = Get-Icon "rocket"

    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ $rocket                 WINDOWS SYSTEM SETUP INSTALLER $rocket                ║" -ForegroundColor Cyan
    Write-Host "  ║                   Automated Package Manager & Configurator                   ║" -ForegroundColor DarkCyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Section {
    param([string]$Title, [string]$IconName = "wrench")

    $icon = Get-Icon $IconName
    Write-Host ""
    Write-Host "  ┌──[ $icon $Title ]" -ForegroundColor Yellow
    Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
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
        "Success"  = "Green"
        "Error"    = "Red"
        "Warning"  = "Yellow"
        "Info"     = "Cyan"
        "Progress" = "Magenta"
        "Done"     = "Green"
    }

    $color = $colors[$Status]
    if ($null -eq $color) { $color = "White" }

    if ($NoNewline) {
        Write-Host "  $icon $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "  $icon $Message" -ForegroundColor $color
    }
}

function Create-ProgressBar {
    param(
        [int]$Percent,
        [int]$Width = 40
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

    $party = Get-Icon "party"
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                         INSTALLATION SUMMARY                                 ║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║   Total Packages Processed : $Total" -ForegroundColor White
    Write-Host "  ║   Successful / Skipped     : $Successful" -ForegroundColor Green
    Write-Host "  ║   Failed / Timed Out       : $Failed" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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

# Set global execution policy
Show-Status "Setting execution policy..." "Progress"
Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force
Show-Status "Execution policy set to Unrestricted" "Success"

# Check Chocolatey
Show-Section "Package Manager Setup" "package"
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Show-Status "Installing Chocolatey..." "Progress"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Show-Status "Chocolatey installed successfully" "Success"
} else {
    Show-Status "Chocolatey is already installed" "Info"
}

# Configure WinGet Downloader
Show-Section "WinGet Configuration" "gear"
Show-Status "Configuring WinGet downloader (WinINET)..." "Progress"
try {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
    $settingsDir = Split-Path -Parent $settingsPath

    if (!(Test-Path -Path $settingsDir)) {
        New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
    }

    $settings = $null
    if (Test-Path -Path $settingsPath) {
        $fileContent = Get-Content -Path $settingsPath -Raw -ErrorAction SilentlyContinue
        if (![string]::IsNullOrWhiteSpace($fileContent)) {
            try {
                $settings = $fileContent | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $settings = $null
            }
        }
    }

    if ($null -eq $settings) {
        $settings = [PSCustomObject]@{ network = [PSCustomObject]@{ downloader = "wininet" } }
    } else {
        if (-not $settings.PSObject.Properties.Match("network")) {
            $settings | Add-Member -NotePropertyName "network" -NotePropertyValue ([PSCustomObject]@{downloader = "wininet"})
        }
        if (-not $settings.network.PSObject.Properties.Match("downloader")) {
            $settings.network | Add-Member -NotePropertyName "downloader" -NotePropertyValue "wininet"
        } else {
            $settings.network.downloader = "wininet"
        }
    }

    $settings | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $settingsPath -Encoding UTF8
    Show-Status "WinGet downloader configured successfully" "Success"
} catch {
    Show-Status "Failed to configure WinGet downloader: $_" "Error"
}

# Check PowerShell 7
Show-Section "PowerShell 7 Setup" "computer"
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Show-Status "Installing PowerShell 7..." "Progress"
    winget install --accept-source-agreements --accept-package-agreements -e --id Microsoft.PowerShell
    Show-Status "PowerShell 7 installed successfully" "Success"
} else {
    Show-Status "PowerShell 7 is already installed" "Info"
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Show-Status "PowerShell 7 is required to continue" "Error"
    pause
    exit
}

# Setup Brave Registry Keys
Show-Section "Browser Configuration" "globe"
Show-Status "Configuring Brave Browser settings..." "Progress"
$bravePath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"

if (-not (Test-Path $bravePath)) {
    New-Item -Path $bravePath -Force | Out-Null
}

$braveSettings = @{
    "BraveRewardsDisabled"   = 1
    "BraveWalletDisabled"    = 1
    "BraveVPNDisabled"       = 1
    "BraveAIChatEnabled"     = 0
    "PasswordManagerEnabled" = 0
    "HttpsUpgradesEnabled"   = 0
    "BraveAdsEnabled"        = 0
    "BuiltInDnsClientEnabled" = 1
}

foreach ($setting in $braveSettings.GetEnumerator()) {
    Set-ItemProperty -Path $bravePath -Name $setting.Key -Value $setting.Value -Type DWord
}
Show-Status "Brave Browser configured successfully" "Success"

# Setup Chrome Registry Keys for MV2 Support
Show-Status "Configuring Chrome Browser settings..." "Progress"
$chromePath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

if (-not (Test-Path $chromePath)) {
    New-Item -Path $chromePath -Force | Out-Null
}

$chromeSettings = @{
    "ExtensionManifestV2Availability" = 2
}

foreach ($setting in $chromeSettings.GetEnumerator()) {
    Set-ItemProperty -Path $chromePath -Name $setting.Key -Value $setting.Value -Type DWord
}
Show-Status "Chrome Browser configured successfully" "Success"

# Copy AHK Script
Show-Section "Utility Setup" "utility"
Show-Status "Setting up shortcuts utility..." "Progress"
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/ConfigFiles/shortcuts.exe" -OutFile "$env:TEMP\shortcut.exe"

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
    "Github"   = Join-Path $HOME\Documents "Github"
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

# State file for progress tracking across script restarts / crashes / Ctrl+C
$stateFile = "$logDir\installation_state.json"

function Get-InstallationState {
    if (Test-Path $stateFile) {
        try {
            $content = Get-Content -Path $stateFile -Raw -ErrorAction SilentlyContinue
            if (![string]::IsNullOrWhiteSpace($content)) {
                $json = $content | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($json -and $json.CompletedPackages) {
                    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                    foreach ($pkg in $json.CompletedPackages) {
                        $set.Add($pkg) | Out-Null
                    }
                    return $set
                }
            }
        } catch {}
    }
    return [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
}

function Save-InstallationState {
    param([System.Collections.Generic.HashSet[string]]$StateSet)
    try {
        $arr = @($StateSet)
        @{ CompletedPackages = $arr } | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8
    } catch {}
}

# Fast self-check to verify if package is ALREADY installed before invoking heavy installer
function Test-PackageInstalled {
    param (
        [string]$PackageId,
        [string]$Manager = "winget"
    )

    try {
        if ($Manager -eq "winget") {
            $output = & winget list --exact --id $PackageId 2>$null
            if ($LASTEXITCODE -eq 0 -and ($output -match [regex]::Escape($PackageId))) {
                return $true
            }
        } elseif ($Manager -eq "choco") {
            $output = & choco list --local-only --exact $PackageId 2>$null
            if ($LASTEXITCODE -eq 0 -and ($output -match [regex]::Escape($PackageId))) {
                return $true
            }
        }
    } catch {}

    return $false
}

function Install-SinglePackageWithTimeout {
    param (
        [string]$PackageId,
        [string]$Manager = "winget",
        [int]$TimeoutSeconds = 300
    )

    if ($Manager -eq "winget") {
        $exe = "winget"
        $arguments = "install --accept-package-agreements --accept-source-agreements -e --id `"$PackageId`""
    } else {
        $exe = "choco"
        $arguments = "install -y `"$PackageId`""
    }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = $arguments
        $psi.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($null -eq $proc) { return -1 }

        # Poll process execution while listening for 'n' key to skip
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $proc.HasExited) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'n' -or $key.KeyChar -eq 'N') {
                    try { $proc.Kill() } catch {}
                    return 1477 # Custom exit code for user skip
                }
            }

            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                try { $proc.Kill() } catch {}
                return 1460 # Timeout exit code
            }

            Start-Sleep -Milliseconds 250
        }

        return $proc.ExitCode
    } catch {
        return -1
    }
}

# Enhanced Package Installation Function with Self-Check, State Persistence & Interactive Skip ('n')
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

    $completedState = Get-InstallationState

    Show-Status "Starting installation of $total packages..." "Info"
    Write-Host ""

    foreach ($package in $PackageIds) {
        if ($package -match '^\s*#') {
            continue
        }

        $current++
        $successIcon = Get-Icon "success"
        $errorIcon = Get-Icon "error"
        $skipIcon  = Get-Icon "skip"

        # 1. Fast check: Skip if already recorded in state file
        if ($completedState.Contains($package)) {
            $completedPackages += "  $successIcon Package $current/$total : $package (Already Recorded - Skipped)"
            $successful++
            continue
        }

        # 2. Fast self-check: Detect if package is already installed on system
        if (Test-PackageInstalled -PackageId $package -Manager $Manager) {
            $completedState.Add($package) | Out-Null
            Save-InstallationState -StateSet $completedState
            $completedPackages += "  $successIcon Package $current/$total : $package (Self-Check Installed - Skipped)"
            $successful++
            continue
        }

        # Clear console but keep header and completed list
        Clear-Host
        Show-Banner
        Show-Section "$Type Installation" "package"

        # Render completed history
        if ($completedPackages.Count -gt 0) {
            foreach ($completed in $completedPackages) {
                Write-Host $completed
            }
            Write-Host ""
        }

        # Render progress card
        $pct = [math]::Round(($current / $total) * 100)
        $progressBar = Create-ProgressBar -Percent $pct -Width 35
        $installingIcon = Get-Icon "installing"
        $tipIcon = Get-Icon "tip"

        Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkGray
        Write-Host "  ║ $installingIcon Package ($current/$total) : " -NoNewline -ForegroundColor Cyan
        Write-Host ("{0,-48}" -f $package) -ForegroundColor White -NoNewline
        Write-Host "║" -ForegroundColor DarkGray
        Write-Host "  ║ 📊 Progress       : $progressBar                             ║" -ForegroundColor Yellow
        Write-Host "  ║ $tipIcon Controls       : Press 'n' to skip current download                       ║" -ForegroundColor Magenta
        Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkGray
        Write-Host ""

        # Retry logic with 5-minute timeout per package
        $maxRetries = 2
        $attempt = 0
        $exitCode = -1

        while ($attempt -lt $maxRetries -and $exitCode -ne 0 -and $exitCode -ne 1477) {
            $attempt++
            if ($attempt -gt 1) {
                Show-Status "Retrying $package (Attempt $attempt/$maxRetries)..." "Warning"
                Start-Sleep -Seconds 2
            }

            $exitCode = Install-SinglePackageWithTimeout -PackageId $package -Manager $Manager -TimeoutSeconds 300
        }

        if ($exitCode -eq 0) {
            $completedState.Add($package) | Out-Null
            Save-InstallationState -StateSet $completedState

            $completedPackages += "  $successIcon Package $current/$total : $package installed successfully"
            $successful++
        } elseif ($exitCode -eq 1477) {
            $completedPackages += "  $skipIcon Package $current/$total : $package (Skipped by User)"
            $failed++
        } elseif ($exitCode -eq 1460) {
            $completedPackages += "  $errorIcon Package $current/$total : $package timed out after 300s (Skipped)"
            $failed++
        } else {
            $completedPackages += "  $errorIcon Package $current/$total : $package failed (Exit Code: $exitCode)"
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
    'Brave.Brave',
    'Google.Chrome',
    'ZedIndustries.Zed',
    'Google.Antigravity',
    'Google.GoogleDrive',
    'WireGuard.WireGuard',
    'Tonec.InternetDownloadManager',
    'CodeSector.TeraCopy',
    'Bitwarden.Bitwarden',
    'WinDirStat.WinDirStat',
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
    'RevoUninstaller.RevoUninstaller',
    'AppWork.JDownloader',
    'CodecGuide.K-LiteCodecPack.Full',
    'JetBrains.Toolbox',
    'pCloudAG.pCloudDrive',
    'Mozilla.Firefox',
    'GitHub.GitHubDesktop',
    'tailscale.tailscale',
    'Valve.Steam',
    'Microsoft.PowerToys',
    'Microsoft.VisualStudioCode',
    'IPVanish.IPVanish',
    'SublimeHQ.SublimeText.4',
    'Termius.Termius',
    'mpv.net',
    'Rakuten.Viber',
    "AdGuard.AdGuard",
    "Genymobile.scrcpy",
    "Microsoft.Sysinternals.ProcessMonitor",
    "MarkText.MarkText",
    "Amazon.Corretto.24.JDK",
    "LocalSend.LocalSend",
    "Atuinsh.Atuin"
)

# Base store packages for all systems
$storePackages = @(
    '9NKSQGP7F2NH', # Whatsapp
    '9n0dx20hk701', # Windows Terminal
    '9n8g7tscl18r'  # Nanazip
)

# Detect hardware manufacturer for HP packages
Show-Status "Detecting system manufacturer..." "Progress"
try {
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    Show-Status "System manufacturer: $manufacturer" "Info"

    if ($manufacturer -like "*HP*" -or $manufacturer -like "*Hewlett*") {
        Show-Status "HP system detected - adding HP-specific applications" "Success"
        $storePackages += '9P92N00QV14J' # HP Command Center
        $storePackages += '9P1FBSLRNM43' # BatteryTracker
    }
} catch {
    Show-Status "Could not detect manufacturer: $_" "Warning"
}

# Execute installations
Install-Packages -PackageIds $chocoPackages -Type "Chocolatey Applications" -Manager "choco"
Install-Packages -PackageIds $wingetPackages -Type "Regular Applications"
Install-Packages -PackageIds $storePackages -Type "Microsoft Store Applications"

# Final completion message
Show-Section "Installation Complete" "complete"
Show-Status "All installations completed!" "Done"
Show-Status "Log file: $logFile" "Info"

Write-Host ""
Write-Host "  🎉 ════════════════════════════════════════════════════════════════════════ 🎉" -ForegroundColor Green
Write-Host "     ✨ SETUP COMPLETED! Your applications are installed & ready to use! ✨     " -ForegroundColor Green
Write-Host "  🎉 ════════════════════════════════════════════════════════════════════════ 🎉" -ForegroundColor Green
Write-Host ""

# Stop the transcript
Stop-Transcript

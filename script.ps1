# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
   Write-Host "You need to run this script as administrator." -ForegroundColor Red
   pause
   exit
}

# Force TLS 1.2 protocol for web downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define the log file path
$logDir = "$HOME\Documents\logs"
$logFile = "$logDir\setup.log"

# Create the logs directory if it doesn't exist
if (!(Test-Path -Path $logDir)) {
   New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

# Start the transcript
Start-Transcript -Path $logFile -Append

# Set the global execution policy to unrestricted
Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
   Write-Host "Chocolatey is not installed. Installing Chocolatey..." -ForegroundColor Yellow
   Set-ExecutionPolicy Bypass -Scope Process -Force
   Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   Write-Host "Chocolatey installed successfully." -ForegroundColor Green
} else {
   Write-Host "Chocolatey is already installed." -ForegroundColor Green
}

# Check if PowerShell 7 is installed using winget
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
   Write-Host "PowerShell 7 is not installed. Installing PowerShell 7..." -ForegroundColor Yellow
   winget install --accept-source-agreements --accept-package-agreements -e --id Microsoft.PowerShell 
   Write-Host "PowerShell 7 installed successfully." -ForegroundColor Green
} else {
   Write-Host "PowerShell 7 is already installed." -ForegroundColor Green
}

# Auto-relaunch script in PowerShell 7 if currently running in Windows PowerShell (< 7)
if ($PSVersionTable.PSVersion.Major -lt 7) {
   if (Get-Command pwsh -ErrorAction SilentlyContinue) {
       Write-Host "Relaunching setup script in PowerShell 7..." -ForegroundColor Yellow
       Stop-Transcript
       pwsh -File "$PSCommandPath"
       exit
   } else {
       Write-Host "You need to use PowerShell 7 to execute this script." -ForegroundColor Red
       pause
       exit
   }
}

# Install PowerShellGet and PSReadLine
Write-Host "Installing PowerShellGet and PSReadLine..." -ForegroundColor Yellow
Install-Module -Name PowerShellGet -Force -AllowClobber -Scope AllUsers -Confirm:$false -ErrorAction SilentlyContinue
Install-Module -Name PSReadLine -Force -AllowClobber -Scope AllUsers -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "PowerShellGet and PSReadLine are installed." -ForegroundColor Green

# UAC Configuration
$confirmation = Read-Host "Do you want to change the UAC settings? (Yes/No) [Yes]"

if ($confirmation -eq "" -or $confirmation -match '^(y|yes)$') {
    # Set UAC Consent Prompt Behavior for Admins
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 1
    Write-Host "UAC Prompt Changed" -ForegroundColor Green
} else {
    Write-Host "No changes were made to UAC settings." -ForegroundColor Yellow
}

# Install the profile into PowerShell 7 profile directory
$profileDir = Split-Path -Parent $PROFILE
if (!(Test-Path -Path $profileDir)) {
   New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/ConfigFiles/Microsoft.PowerShell_profile.ps1" -OutFile $PROFILE
Write-Host "PowerShell 7 profile installed." -ForegroundColor Green

# Download the Windows Terminal settings file safely
$wtLocalState = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (!(Test-Path -Path $wtLocalState)) {
   New-Item -ItemType Directory -Force -Path $wtLocalState | Out-Null
}
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/ConfigFiles/settings.json" -OutFile "$wtLocalState\settings.json"
Write-Host "Windows Terminal settings file downloaded and installed." -ForegroundColor Green

# Download the starship.toml file and install it
$starshipUrl = "https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/ConfigFiles/starship.toml"
$destDir = "$HOME\.config"
$destFile = "$destDir\starship.toml"

# Create the directory if it doesn't exist
if (!(Test-Path -Path $destDir)) {
   New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

# Download starship config
Invoke-WebRequest -Uri $starshipUrl -OutFile $destFile
Write-Host "Starship configuration installed." -ForegroundColor Green

# Set the default explorer open folder to "This PC"
$explorerKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $explorerKeyPath -Name "LaunchTo" -Value 1

# Disable "Hide extensions for known file types"
$hideExtensionsKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $hideExtensionsKeyPath -Name "HideFileExt" -Value 0


# Add Sublime Text to PATH if it exists
$sublimeTextPath = "C:\Program Files\Sublime Text"
if (Test-Path -Path $sublimeTextPath) {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if (-not ($currentPath -split ";" -contains $sublimeTextPath)) {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$sublimeTextPath", "Machine")
        Write-Host "Added Sublime Text to system PATH." -ForegroundColor Green
    } else {
        Write-Host "Sublime Text is already in system PATH." -ForegroundColor Green
    }
} else {
    Write-Host "Sublime Text installation not found at $sublimeTextPath. Skipping PATH update." -ForegroundColor Yellow
}

# Install Astral UV
Write-Host "Installing UV package manager..." -ForegroundColor Yellow
Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
Write-Host "UV installation completed." -ForegroundColor Green

# Stop the transcript at the end of the script
Stop-Transcript

# Check if the script is running as administrator and elevate inline via gsudo if available
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "💡 Administrator privileges required for Office setup. Elevating..." -ForegroundColor Yellow
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $scriptPath = $MyInvocation.MyCommand.Path

    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        & gsudo $shell -File "$scriptPath"
        exit $LASTEXITCODE
    } elseif (Get-Command sudo -ErrorAction SilentlyContinue) {
        & sudo $shell -File "$scriptPath"
        exit $LASTEXITCODE
    } else {
        Start-Process $shell -Verb RunAs -ArgumentList "-File `"$scriptPath`""
        exit
    }
}

# Force TLS 1.2 protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "     MICROSOFT 365 / OFFICE INSTALLER (C2R)      " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Helper function to verify if Office binary is present
function Test-OfficeInstalled {
    $wordx64 = "${env:ProgramFiles}\Microsoft Office\root\Office16\WINWORD.EXE"
    $wordx86 = "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE"
    return (Test-Path -Path $wordx64) -or (Test-Path -Path $wordx86)
}

# Check if Word/Office is already installed
if (Test-OfficeInstalled) {
    Write-Host "Microsoft Office / 365 is already installed on this system." -ForegroundColor Green
    exit 0
}

Write-Host "Starting Microsoft 365 (C2R) installation..." -ForegroundColor Yellow

$installed = $false
$installerPath = Join-Path $env:TEMP "OfficeSetup.exe"

# Primary Method: Official Microsoft Click-To-Run (C2R) Direct Installer
try {
    # 1. Clean up any existing corrupted/partial download in TEMP
    if (Test-Path $installerPath) {
        Write-Host "Cleaning up previous temporary installer file..." -ForegroundColor DarkGray
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Downloading latest Microsoft 365 Click-To-Run installer from Microsoft CDN..." -ForegroundColor Yellow
    $officeUrl = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA"

    # Download with basic parsing
    Invoke-WebRequest -Uri $officeUrl -OutFile $installerPath -UseBasicParsing

    # 2. Verify Download Integrity (File exists & size > 1 MB)
    if (!(Test-Path $installerPath)) {
        throw "Download failed - installer file not found after download."
    }
    
    $fileSize = (Get-Item $installerPath).Length
    if ($fileSize -lt 1MB) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        throw "Corrupted download detected (File size: $([math]::Round($fileSize / 1KB, 1)) KB is less than expected 1 MB)."
    }

    Write-Host "Download verified successfully ($([math]::Round($fileSize / 1MB, 2)) MB). Running Microsoft 365 C2R setup..." -ForegroundColor Green
    
    # 3. Execute setup and monitor process
    $process = Start-Process -FilePath $installerPath -Wait -PassThru
    
    # Clean up installer executable after execution
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    # Handle process exit codes (0 = Success, 3010 / 1641 = Success, Reboot Required)
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or $process.ExitCode -eq 1641) {
        # 4. Post-installation Verification (Ensure binaries actually exist)
        if (Test-OfficeInstalled) {
            Write-Host "Microsoft 365 / Office installed and verified successfully via C2R!" -ForegroundColor Green
            $installed = $true
        } else {
            Write-Host "Partial installation detected: Setup reported success but Office binaries are missing." -ForegroundColor Yellow
        }
    } else {
        Write-Host "C2R setup failed or was cancelled by user (Exit code: $($process.ExitCode))." -ForegroundColor Yellow
    }
} catch {
    # Ensure temporary corrupted installer file is deleted on exception
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    Write-Host "C2R download/execution failed ($($_.Exception.Message)). Attempting WinGet fallback..." -ForegroundColor Yellow
}

# Secondary Fallback: Install via WinGet
if (-not $installed -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    try {
        Write-Host "`nAttempting WinGet installation (Microsoft.Office)..." -ForegroundColor Yellow
        winget install --accept-source-agreements --accept-package-agreements -e --id Microsoft.Office
        
        if ($LASTEXITCODE -eq 0 -and (Test-OfficeInstalled)) {
            Write-Host "Microsoft 365 / Office installed and verified successfully via WinGet!" -ForegroundColor Green
            $installed = $true
        } else {
            Write-Host "WinGet installation finished with code $LASTEXITCODE." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WinGet fallback encountered an error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Final Result Summary & Activation
if ($installed) {
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "  OFFICE SETUP COMPLETED & VERIFIED SUCCESSFULLY " -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green

    # Run MAS Ohook activation
    Write-Host "`nRunning Microsoft Office activation (MAS Ohook)..." -ForegroundColor Yellow
    try {
        & ([ScriptBlock]::Create((curl.exe -s --doh-url https://1.1.1.1/dns-query https://get.activated.win | Out-String))) /Ohook
        Write-Host "Activation command executed." -ForegroundColor Green
    } catch {
        Write-Host "Activation encountered an error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "  OFFICE SETUP UNABLE TO COMPLETE AUTOMATICALLY   " -ForegroundColor Red
    Write-Host "  Please run setup manually from office.com       " -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    exit 1
}

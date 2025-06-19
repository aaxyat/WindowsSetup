# Automatic Hostname Setup Script
# Sets hostname based on computer model

Write-Host "Checking computer model to set appropriate hostname..." -ForegroundColor Yellow

# Get computer information
$computerInfo = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
$manufacturer = $computerInfo.Manufacturer
$model = $computerInfo.Model

Write-Host "Detected Manufacturer: $manufacturer" -ForegroundColor Cyan
Write-Host "Detected Model: $model" -ForegroundColor Cyan

# Determine hostname based on model
$newHostname = $null

if ($model -eq "HP ENVY x360 Convertible 15-eu1xxx") {
    $newHostname = "Turing"
    Write-Host "HP ENVY x360 detected - Setting hostname to 'Turing'" -ForegroundColor Green
}
elseif ($manufacturer -eq "Gigabyte Technology Co., Ltd." -and $model -eq "A520M AORUS ELITE") {
    $newHostname = "Titan"
    Write-Host "Gigabyte A520M AORUS ELITE detected - Setting hostname to 'Titan'" -ForegroundColor Green
}
else {
    Write-Host "Unknown computer model detected:" -ForegroundColor Red
    Write-Host "Manufacturer: $manufacturer" -ForegroundColor Red
    Write-Host "Model: $model" -ForegroundColor Red
    Write-Host "No automatic hostname configuration available for this model." -ForegroundColor Red
    exit 1
}

# Get current hostname
$currentHostname = $env:COMPUTERNAME
Write-Host "Current hostname: $currentHostname" -ForegroundColor Cyan

# Check if hostname change is needed
if ($currentHostname -eq $newHostname) {
    Write-Host "Hostname is already set to '$newHostname'. No change needed." -ForegroundColor Green
    exit 0
}

# Confirm hostname change
Write-Host "About to change hostname from '$currentHostname' to '$newHostname'" -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (Y/N)"

if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
    try {
        # Change hostname
        Write-Host "Changing hostname to '$newHostname'..." -ForegroundColor Yellow
        Rename-Computer -NewName $newHostname -Force
        
        Write-Host "Hostname successfully changed to '$newHostname'!" -ForegroundColor Green
        Write-Host "A restart is required to complete the hostname change." -ForegroundColor Yellow
        
        # Ask if user wants to restart now
        $restartConfirmation = Read-Host "Do you want to restart now? (Y/N)"
        if ($restartConfirmation -eq 'Y' -or $restartConfirmation -eq 'y') {
            Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
        else {
            Write-Host "Please restart your computer manually to complete the hostname change." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error changing hostname: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Make sure you're running this script as Administrator." -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "Hostname change cancelled." -ForegroundColor Yellow
    exit 0
}

# Configure rotation settings only for laptop (HP ENVY x360)
if ($model -eq "HP ENVY x360 Convertible 15-eu1xxx") {
    Write-Host "`nConfiguring display rotation settings for laptop..." -ForegroundColor Yellow

    try {
        # Disable rotation lock
        Write-Host "Disabling rotation lock..." -ForegroundColor Cyan
        
        # Registry path for rotation settings
        $rotationRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AutoRotation"
        
        # Create the registry key if it doesn't exist
        if (!(Test-Path $rotationRegistryPath)) {
            New-Item -Path $rotationRegistryPath -Force | Out-Null
            Write-Host "Created AutoRotation registry key" -ForegroundColor Green
        }
        
        # Enable auto-rotation (disable rotation lock)
        # 0 = Rotation lock disabled (auto-rotation enabled)
        # 1 = Rotation lock enabled (auto-rotation disabled)
        Set-ItemProperty -Path $rotationRegistryPath -Name "Enable" -Value 0 -Type DWord
        Write-Host "Rotation lock disabled - auto-rotation enabled" -ForegroundColor Green
        
        # Set default orientation to landscape
        Write-Host "Setting default orientation to landscape..." -ForegroundColor Cyan
        
        # Registry path for display orientation
        $orientationRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell"
        
        # Create the registry key if it doesn't exist
        if (!(Test-Path $orientationRegistryPath)) {
            New-Item -Path $orientationRegistryPath -Force | Out-Null
            Write-Host "Created ImmersiveShell registry key" -ForegroundColor Green
        }
        
        # Set tablet mode orientation preference to landscape
        # 0 = Landscape, 1 = Portrait
        Set-ItemProperty -Path $orientationRegistryPath -Name "TabletMode" -Value 0 -Type DWord
        Write-Host "Default orientation set to landscape" -ForegroundColor Green
        
        # Additional setting for rotation preference
        $rotationPrefPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell\EdgeUI"
        if (!(Test-Path $rotationPrefPath)) {
            New-Item -Path $rotationPrefPath -Force | Out-Null
        }
        Set-ItemProperty -Path $rotationPrefPath -Name "DisableTLCorner" -Value 1 -Type DWord
        
        Write-Host "Display rotation settings configured successfully for laptop!" -ForegroundColor Green
        Write-Host "Changes will take effect after restart or sign out/sign in." -ForegroundColor Yellow
        
    } catch {
        Write-Host "Error configuring display rotation settings: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Some settings may require administrator privileges." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nSkipping rotation settings - not applicable for desktop PC" -ForegroundColor Cyan
}

# Pause to allow user to review output
Write-Host "`nScript execution completed!" -ForegroundColor Green
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

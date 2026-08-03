# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as administrator." -ForegroundColor Red
    pause
    exit
}

# Set the timezone to UTC+ 5:45 (Nepal Standard Time)
$currentTimeZone = tzutil /g
if ($currentTimeZone -ne "Nepal Standard Time") {
    $timeZoneConfirmation = Read-Host "Current timezone is '$currentTimeZone'. Do you want to set it to Nepal Standard Time (UTC+5:45)? (Y/N)"
    if ($timeZoneConfirmation -eq 'Y' -or $timeZoneConfirmation -eq 'y') {
        try {
            Write-Host "Setting timezone to 'Nepal Standard Time' (UTC+5:45)..." -ForegroundColor Yellow
            tzutil /s "Nepal Standard Time"
            Write-Host "Timezone successfully set to 'Nepal Standard Time' (UTC+5:45)." -ForegroundColor Green
        } catch {
            Write-Host "Error setting timezone: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Timezone change canceled. The current timezone remains as '$currentTimeZone'." -ForegroundColor Yellow
    }
} else {
    Write-Host "Timezone is already set to 'Nepal Standard Time' (UTC+5:45). No changes needed." -ForegroundColor Green
}

# Automatic Hostname Setup Script
Write-Host "`nChecking computer model to set appropriate hostname..." -ForegroundColor Yellow

# Get computer information
$computerInfo = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
$manufacturer = $computerInfo.Manufacturer
$model = $computerInfo.Model

Write-Host "Detected Manufacturer: $manufacturer" -ForegroundColor Cyan
Write-Host "Detected Model: $model" -ForegroundColor Cyan

# Determine hostname based on model using wildcard matching
$newHostname = $null

if ($model -like "*HP ENVY x360*" -or $model -like "*15-eu*") {
    $newHostname = "Turing"
    Write-Host "HP ENVY x360 detected - Target hostname: 'Turing'" -ForegroundColor Green
}
elseif ($manufacturer -like "*Gigabyte*" -or $model -like "*A520M*" -or $model -like "*AORUS ELITE*") {
    $newHostname = "Titan"
    Write-Host "Gigabyte A520M AORUS ELITE detected - Target hostname: 'Titan'" -ForegroundColor Green
}
else {
    Write-Host "Unknown computer model detected:" -ForegroundColor Red
    Write-Host "Manufacturer: $manufacturer" -ForegroundColor Red
    Write-Host "Model: $model" -ForegroundColor Red
    Write-Host "Skipping automatic hostname configuration for this model." -ForegroundColor Yellow
}

# Process hostname change if a matching model was identified
if ($newHostname) {
    $currentHostname = $env:COMPUTERNAME
    Write-Host "Current hostname: $currentHostname" -ForegroundColor Cyan

    if ($currentHostname -eq $newHostname) {
        Write-Host "Hostname is already set to '$newHostname'. No change needed." -ForegroundColor Green
    } else {
        Write-Host "About to change hostname from '$currentHostname' to '$newHostname'" -ForegroundColor Yellow
        $confirmation = Read-Host "Do you want to proceed? (Y/N)"

        if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
            try {
                Write-Host "Changing hostname to '$newHostname'..." -ForegroundColor Yellow
                Rename-Computer -NewName $newHostname -Force
                
                Write-Host "Hostname successfully changed to '$newHostname'!" -ForegroundColor Green
                Write-Host "A restart is required to complete the hostname change." -ForegroundColor Yellow
                
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
            }
        }
        else {
            Write-Host "Hostname change cancelled." -ForegroundColor Yellow
        }
    }
}

# Configure rotation settings only for laptop (HP ENVY x360)
if ($model -like "*HP ENVY x360*" -or $model -like "*15-eu*") {
    Write-Host "`nConfiguring display rotation settings for laptop..." -ForegroundColor Yellow

    try {
        Write-Host "Enabling auto-rotation..." -ForegroundColor Cyan
        
        # Registry path for rotation settings
        $rotationRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AutoRotation"
        
        if (!(Test-Path $rotationRegistryPath)) {
            New-Item -Path $rotationRegistryPath -Force | Out-Null
            Write-Host "Created AutoRotation registry key" -ForegroundColor Green
        }
        
        # Enable auto-rotation (1 = Enable auto-rotation)
        Set-ItemProperty -Path $rotationRegistryPath -Name "Enable" -Value 1 -Type DWord
        Write-Host "Auto-rotation enabled successfully" -ForegroundColor Green
        
        # Set default orientation to landscape
        Write-Host "Setting default orientation to landscape..." -ForegroundColor Cyan
        
        $orientationRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell"
        
        if (!(Test-Path $orientationRegistryPath)) {
            New-Item -Path $orientationRegistryPath -Force | Out-Null
            Write-Host "Created ImmersiveShell registry key" -ForegroundColor Green
        }
        
        Set-ItemProperty -Path $orientationRegistryPath -Name "TabletMode" -Value 0 -Type DWord
        Write-Host "Default orientation set to landscape" -ForegroundColor Green
        
        $rotationPrefPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell\EdgeUI"
        if (!(Test-Path $rotationPrefPath)) {
            New-Item -Path $rotationPrefPath -Force | Out-Null
        }
        Set-ItemProperty -Path $rotationPrefPath -Name "DisableTLCorner" -Value 1 -Type DWord
        
        Write-Host "Display rotation settings configured successfully for laptop!" -ForegroundColor Green
        Write-Host "Changes will take effect after restart or sign out/sign in." -ForegroundColor Yellow
        
    } catch {
        Write-Host "Error configuring display rotation settings: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nSkipping rotation settings - not applicable for desktop PC" -ForegroundColor Cyan
}

# Pause to allow user to review output
Write-Host "`nScript execution completed!" -ForegroundColor Green
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Check if the script is running under administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If not running as admin, re-run the script with elevated privileges
if (-not $isAdmin) {
   $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
   Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
   Exit
}



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

# Wait till the user presses any button
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


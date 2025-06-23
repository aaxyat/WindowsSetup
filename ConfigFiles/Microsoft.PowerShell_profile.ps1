Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySavePath "P:\ps-history\ConsoleHost_history.txt"

Invoke-Expression (&starship init powershell)

function acm {
        param(
                [Parameter(ValueFromRemainingArguments = $true)]
                [String[]] $message
        )
        git add .
        git commit -a -m "$message"
        git push
}

#choco install Script
Function cinst {
        sudo choco install $args
}

# If so and the current host is a command line, then change to red color 
# as warning to user that they are operating in an elevated context
# Useful shortcuts for traversing directories
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# Compute file hashes - useful for checking successful downloads 
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }

# Quick shortcut to start notepad
function n { notepad $args }

# Drive shortcuts
function HKLM: { Set-Location HKLM: }
function HKCU: { Set-Location HKCU: }
function Env: { Set-Location Env: }

# Creates drive shortcut for Work Folders, if current user account is using it
if (Test-Path "$env:USERPROFILE\Work Folders") {
        New-PSDrive -Name Work -PSProvider FileSystem -Root "$env:USERPROFILE\Work Folders" -Description "Work Folders"
        function Work: { Set-Location Work: }
}


# Does the the rough equivalent of dir /s /b. For example, dirs *.png is dir /s /b *.png
function dirs {
        if ($args.Count -gt 0) {
                Get-ChildItem -Recurse -Include "$args" | Foreach-Object FullName
        }
        else {
                Get-ChildItem -Recurse | Foreach-Object FullName
        }
}

# Function to create requirements.txt from a poetry requirements
function Export-PoetryRequirements {
        [CmdletBinding()]
        param()
    
        # Export requirements and clean up the output
        poetry export --without-hashes | 
            ForEach-Object { 
                # Split on semicolon and take the first part (package and version)
                ($_ -split ';')[0].Trim() 
            } | 
            Set-Content -Path requirements.txt
    
        Write-Host "Created requirements.txt with clean package versions"
    }
    
# Set an alias for convenience
Set-Alias requirements Export-PoetryRequirements

# Simple function to start a new elevated process. If arguments are supplied then 
# a single command is started with admin rights; if not then a new admin instance
# of PowerShell is started.
function admin {
        if ($args.Count -gt 0) {   
                $argList = "& '" + $args + "'"
                Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $argList
        }
        else {
                Start-Process "$psHome\powershell.exe" -Verb runAs
        }
}

# Make it easy to edit this profile once it's installed
function Edit-Profile {
        if ($host.Name -match "ise") {
                $psISE.CurrentPowerShellTab.Files.Add($profile.CurrentUserAllHosts)
        }
        else {
                notepad $profile.CurrentUserAllHosts
        }
}

#
# Aliases
#    
function ll { Get-ChildItem -Path $pwd -File }
function g { Set-Location $HOME\Documents\Github }
function p { Set-Location $HOME\Documents\Projects }
function gcom {
        git add .
        git commit -m "$args"
}

# Function to losslessly merge multiple mp4 files into a single file using ffmpeg
function Merge-MP4 {
        [CmdletBinding()]
        param(
            [string]$OutputFile = "merged_output.mp4"
        )
    
        # 1. Get and validate MP4 files
        try {
            $files = Get-ChildItem -Path $PWD -Filter "*.mp4" -ErrorAction Stop | 
                     Sort-Object Name
            if (-not $files) {
                Write-Error "No MP4 files found in current directory"
                return
            }
        }
        catch {
            Write-Error "File discovery failed: $_"
            return
        }
    
        # 2. Create temporary file list
        $fileListPath = Join-Path $PWD "filelist.txt"
        try {
            $files | ForEach-Object { "file '$($_.Name)'" } | 
            Set-Content -Path $fileListPath -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to create file list: $_"
            return
        }
    
        # 3. Initialize progress tracking
        $activity = "🎬 Merging $($files.Count) MP4 Files"
        $progressParams = @{
            Activity = $activity
            Status   = "Starting FFmpeg processing..."
            PercentComplete = 0
        }
        Write-Progress @progressParams
    
        # 4. Execute FFmpeg with error handling
        $ffmpegOutput = & ffmpeg -f concat -safe 0 -i $fileListPath -c copy $OutputFile 2>&1
        $ffmpegExitCode = $LASTEXITCODE
    
        # 5. Process output and handle errors
        $ffmpegOutput | ForEach-Object {
            Write-Host $_  # Forward FFmpeg output to console
            if ($_ -match 'time=(\S+)') {
                Write-Progress -Activity $activity -Status "Processing: $($matches[1])" -PercentComplete -1
            }
        }
    
        # 6. Validate results and cleanup
        Remove-Item $fileListPath -ErrorAction SilentlyContinue
        
        if ($ffmpegExitCode -eq 0) {
            if (Test-Path $OutputFile) {
                Write-Host "✅ Successfully merged $($files.Count) files into '$OutputFile'" -ForegroundColor Green
                return $true
            }
            else {
                Write-Error "FFmpeg succeeded but output file missing"
                return $false
            }
        }
        else {
            Write-Error "FFmpeg failed with exit code $ffmpegExitCode (Error details above)"
            return $false
        }
    }
    
function lazyg {
        git add .
        git commit -m "$args"
        git push
}
function npp {
        Start-Process notepad++.exe $args
}

function Get-PubIP4 {

        if (!(Get-Command curl -ErrorAction SilentlyContinue)) {
                Write-Error "curl is not installed. Please install curl using 'winget install curl'"
                return
        }
        curl -4 https://ipconfig.io/ip
}

function Get-PubIP6 {
        if (!(Get-Command curl -ErrorAction SilentlyContinue)) {
                Write-Error "curl is not installed. Please install curl using 'winget install curl'"
                return
        }
        curl -6 https://ipconfig.io/ip
}



function uptime {
        Get-WmiObject win32_operatingsystem | Select-Object csname, @{LABEL = 'LastBootUpTime';
                EXPRESSION                                           = { $_.ConverttoDateTime($_.lastbootuptime) }
        }
}
function reload-profile {
    @(
        $Profile.AllUsersAllHosts,
        $Profile.AllUsersCurrentHost,
        $Profile.CurrentUserAllHosts,
        $Profile.CurrentUserCurrentHost
    ) | Where-Object { Test-Path $_ } | ForEach-Object {
        . $_
    }
    Write-Host "Profile reloaded successfully!" -ForegroundColor Green
}

function find-file($name) {
        Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
                $place_path = $_.directory
                Write-Output "${place_path}\${_}"
        }
}
function unzip ($file) {
        Write-Output("Extracting", $file, "to", $pwd)
        $fullFile = Get-ChildItem -Path $pwd -Filter .\cove.zip | ForEach-Object { $_.FullName }
        Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function grep($regex, $dir) {
        if ( $dir ) {
                Get-ChildItem $dir | select-string $regex
                return
        }
        $input | select-string $regex
}

# Function to open Kali WSL
function kali {
        wsl -d kali-linux
}
    
    # Function to open Ubuntu WSL
function ubuntu {
        wsl -d Ubuntu
}
    

function mas {
        Invoke-RestMethod https://get.activated.win | Invoke-Expression

}
function ctt {
        Invoke-WebRequest -useb https://christitus.com/win | Invoke-Expression
}
function betterbrave {
        Invoke-WebRequest -useb https://raw.githubusercontent.com/aaxyat/BetterBrave/refs/heads/main/BetterBrave.ps1 | Invoke-Expression
}

function touch($file) {
        "" | Out-File $file -Encoding ASCII
}
function df {
        get-volume
}
function sed($file, $find, $replace) {
        (Get-Content $file).replace("$find", $replace) | Set-Content $file
}
function which($name) {
        Get-Command $name | Select-Object -ExpandProperty Definition
}
function export($name, $value) {
        set-item -force -path "env:$name" -value $value;
}
function pkill($name) {
        Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}
function pgrep($name) {
        Get-Process $name
}
# Function to quickly install a winget package

function install {
    param(
        [Parameter(Position = 0)]
        [String] $package
    )

    winget install -e $package
}

function Set-DoH {
    [CmdletBinding()]
    param()
    
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-Host "Error: This command requires administrator privileges." -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        return
    }

    # Define Cloudflare DoH server addresses
    $DoHServerAddresses = @(
        "https://dns.cloudflare.com/dns-query",
        "https://dns.cloudflare.com/dns-query"
    )

    # Define Cloudflare IPv4 addresses (as fallback)
    $IPv4Addresses = @(
        "1.1.1.1",
        "1.0.0.1"
    )

    # Define Cloudflare IPv6 addresses (as fallback)
    $IPv6Addresses = @(
        "2606:4700:4700::1111",
        "2606:4700:4700::1001"
    )

    try {
        $activeInterfaces = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        
        foreach ($interface in $activeInterfaces) {
            Write-Host "`nConfiguring interface: $($interface.Name)" -ForegroundColor Cyan
            
            # Get current IP configuration without trying to enable/disable
            $ipConfig = Get-NetIPInterface -InterfaceIndex $interface.ifIndex
            
            # Set DNS over HTTPS
            try {
                Set-DnsClientDohServerAddress -InterfaceIndex $interface.ifIndex -ServerAddress $DoHServerAddresses
                Write-Host "Successfully configured DoH servers" -ForegroundColor Green
            } catch {
                Write-Host "Warning: Could not set DoH servers. Falling back to traditional DNS." -ForegroundColor Yellow
                
                # Set IPv4 and IPv6 DNS servers
                Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses $IPv4Addresses
                Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses $IPv6Addresses
            }
            
            # Verify configuration
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $interface.ifIndex
            
            Write-Host "`nCurrent DNS Configuration for $($interface.Name):"
            Write-Host "IPv4 DNS Servers:" -ForegroundColor Yellow
            $dnsServers | Where-Object {$_.AddressFamily -eq 2} | Select-Object -ExpandProperty ServerAddresses
            
            Write-Host "IPv6 DNS Servers:" -ForegroundColor Yellow
            $dnsServers | Where-Object {$_.AddressFamily -eq 23} | Select-Object -ExpandProperty ServerAddresses
            
            if (Get-Command "Get-DnsClientDohServerAddress" -ErrorAction SilentlyContinue) {
                Write-Host "DoH Servers:" -ForegroundColor Yellow
                Get-DnsClientDohServerAddress -InterfaceIndex $interface.ifIndex | Select-Object -ExpandProperty ServerAddress
            }
        }
        
        # Flush DNS cache
        Write-Host "`nFlushing DNS cache..." -ForegroundColor Cyan
        ipconfig /flushdns
        
        Write-Host "`nConfiguration complete!" -ForegroundColor Green
    } catch {
        Write-Host "`nError during configuration: $_" -ForegroundColor Red
    }
}

# Add an alias for easier use
Set-Alias -Name doh -Value Set-DoH

function update-profile {
    $url = "https://raw.githubusercontent.com/aaxyat/WindowsSetup/main/ConfigFiles/Microsoft.PowerShell_profile.ps1"
    $backupPath = "$($PROFILE).backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    try {
        # Create backup of current profile
        if (Test-Path $PROFILE) {
            Write-Host "📦 Creating backup of current profile..." -ForegroundColor Yellow
            Copy-Item -Path $PROFILE -Destination $backupPath -ErrorAction Stop
            Write-Host "✅ Backup created at: $backupPath" -ForegroundColor Green
        }

        # Download new profile
        Write-Host "⬇️ Downloading new profile from GitHub..." -ForegroundColor Yellow
        $newProfile = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop

        # Save new profile
        if ($newProfile.StatusCode -eq 200) {
            $newProfile.Content | Out-File -FilePath $PROFILE -Force -Encoding UTF8
            Write-Host "✅ Profile updated successfully!" -ForegroundColor Green
            Write-Host "🔄 Reloading profile..." -ForegroundColor Yellow
            . $PROFILE
            Write-Host "✨ Profile reloaded! You're all set!" -ForegroundColor Green
        } else {
            throw "Failed to download profile: HTTP Status $($newProfile.StatusCode)"
        }
    }
    catch {
        Write-Host "❌ Error updating profile: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $backupPath) {
            Write-Host "🔄 Restoring backup..." -ForegroundColor Yellow
            Copy-Item -Path $backupPath -Destination $PROFILE -Force
            Write-Host "✅ Backup restored successfully!" -ForegroundColor Green
        }
        return
    }
}
# Alias 
Set-Alias -Name pubip4 -Value Get-PubIP4
Set-Alias -Name pubip6 -Value Get-PubIP6
Set-Alias -Name sudo -Value gsudo
 

# Helper Function

function s {
    param(
        [Parameter(Position = 0)]
        [String] $command
    )

    $shortcuts = @{
        'acm'           = @{desc = 'Git add all changes, commit with message and push to remote in one command'; usage = 'acm "commit message"'; color = 'DarkYellow'}
        'cinst'         = @{desc = 'Install packages using Chocolatey package manager with admin privileges'; usage = 'cinst package-name'; color = 'Blue'}
        'cd...'         = @{desc = 'Navigate up two directory levels from current location'; usage = 'cd...'; color = 'Green'}
        'cd....'        = @{desc = 'Navigate up three directory levels from current location'; usage = 'cd....'; color = 'Green'}
        'md5'           = @{desc = 'Calculate MD5 hash of specified file for verification'; usage = 'md5 filename'; color = 'Magenta'}
        'sha1'          = @{desc = 'Calculate SHA1 hash of specified file for verification'; usage = 'sha1 filename'; color = 'Magenta'}
        'sha256'        = @{desc = 'Calculate SHA256 hash of specified file for verification'; usage = 'sha256 filename'; color = 'Magenta'}
        'n'             = @{desc = 'Quickly open specified file in Windows Notepad'; usage = 'n filename'; color = 'Blue'}
        'dirs'          = @{desc = 'Recursively list all files and directories with optional pattern matching'; usage = 'dirs [pattern]'; color = 'Yellow'}
        'admin'         = @{desc = 'Launch new PowerShell session or specific command with admin privileges'; usage = 'admin [command]'; color = 'Red'}
        'Edit-Profile'  = @{desc = 'Open PowerShell profile in default editor for customization'; usage = 'Edit-Profile'; color = 'Cyan'}
        'll'            = @{desc = 'List all files in current directory with detailed information'; usage = 'll'; color = 'Green'}
        'g'             = @{desc = 'Quick navigation to Github projects directory'; usage = 'g'; color = 'DarkYellow'}
        'p'             = @{desc = 'Quick navigation to Projects directory'; usage = 'p'; color = 'DarkYellow'}
        'gcom'          = @{desc = 'Stage all changes and create a git commit with specified message'; usage = 'gcom "message"'; color = 'DarkYellow'}
        'lazyg'         = @{desc = 'Stage, commit all changes and push to remote git repository'; usage = 'lazyg "message"'; color = 'DarkYellow'}
        'npp'           = @{desc = 'Open specified file in Notepad++ text editor'; usage = 'npp filename'; color = 'Blue'}
        'Get-PubIP4'    = @{desc = 'Display current public IPv4 address of the system'; usage = 'Get-PubIP'; color = 'Cyan'}
        'pubip4'        = @{desc = 'Display current public IPv4 address of the system'; usage = 'pubip'; color = 'magenta'}
        'Get-PubIP6'    = @{desc = 'Display current public IPv6 address of the system'; usage = 'Get-PubIP6'; color = 'Cyan'}
        'pubip6'        = @{desc = 'Display current public IPv6 address of the system'; usage = 'pubip6'; color = 'magenta'}
        'uptime'        = @{desc = 'Show system uptime since last boot with timestamp'; usage = 'uptime'; color = 'Cyan'}
        'reload-profile'= @{desc = 'Reload PowerShell profile to apply recent changes'; usage = 'reload-profile'; color = 'Cyan'}
        'find-file'     = @{desc = 'Recursively search for files matching specified pattern'; usage = 'find-file name'; color = 'Yellow'}
        'unzip'         = @{desc = 'Extract contents of specified zip file to current directory'; usage = 'unzip file.zip'; color = 'Blue'}
        'grep'          = @{desc = 'Search for pattern in files or pipeline input with optional directory'; usage = 'grep pattern [dir]'; color = 'Yellow'}
        'mas'           = @{desc = 'Run Microsoft Activation Scripts for Windows/Office activation'; usage = 'mas'; color = 'Red'}
        'ctt'           = @{desc = 'Execute Chris Titus Tech Windows optimization utilities'; usage = 'ctt'; color = 'Magenta'}
        'touch'         = @{desc = 'Create new empty file or update timestamp of existing file'; usage = 'touch file'; color = 'Blue'}
        'df'            = @{desc = 'Display information about system disk volumes and space'; usage = 'df'; color = 'Green'}
        'sed'           = @{desc = 'Find and replace text in specified file with pattern matching'; usage = 'sed file find replace'; color = 'Yellow'}
        'which'         = @{desc = 'Show full path of specified command or executable'; usage = 'which cmd'; color = 'Cyan'}
        'export'        = @{desc = 'Set or modify system environment variable with specified value'; usage = 'export name value'; color = 'Magenta'}
        'pkill'         = @{desc = 'Terminate all processes matching specified name pattern'; usage = 'pkill name'; color = 'Red'}
        'pgrep'         = @{desc = 'Find and list all processes matching specified name pattern'; usage = 'pgrep name'; color = 'Yellow'}
        'vim'           = @{desc = 'Open specified file in Neovim text editor (alias for nvim)'; usage = 'vim file'; color = 'Blue'}
        'install'       = @{desc = 'Install specified package using Windows Package Manager (winget)'; usage = 'install package'; color = 'Green'}
        'update-profile'= @{desc = 'Update PowerShell profile from GitHub repository'; usage = 'update-profile'; color = 'Cyan'}
        'requirements'  = @{desc = 'Export clean package versions from Poetry requirements file'; usage = 'requirements'; color = 'Magenta'}
        'betterbrave'   = @{desc = 'Run BetterBrave script for Brave Browser setup and optimization'; usage = 'betterbrave'; color = 'Red'}
        'Set-DoH'       = @{desc = 'Configure Cloudflare DNS over HTTPS with IPv4 and IPv6 support (requires admin)'; usage = 'Set-DoH'; color = 'Cyan'}
        'doh'           = @{desc = 'Configure Cloudflare DNS over HTTPS with IPv4 and IPv6 support (requires admin)'; usage = 'doh'; color = 'Cyan'}
        'kali'          = @{desc = 'Open Kali Linux WSL instance'; usage = 'kali'; color = 'Cyan'}
        'ubuntu'        = @{desc = 'Open Ubuntu WSL instance'; usage = 'ubuntu'; color = 'Cyan'}
        'merge-mp4'     = @{desc = 'Merge multiple MP4 files into a single file using ffmpeg'; usage = 'merge-mp4'; color = 'Green'}
    }

    if ($command) {
        if ($shortcuts.ContainsKey($command)) {
            $shortcut = $shortcuts[$command]
            Write-Host "`n🔍 " -NoNewline
            Write-Host $command -ForegroundColor Cyan -NoNewline
            Write-Host " → " -ForegroundColor DarkGray -NoNewline
            Write-Host $shortcut.desc -ForegroundColor $shortcut.color
            Write-Host "📎 Usage: " -NoNewline
            Write-Host $shortcut.usage -ForegroundColor Yellow
            Write-Host ""
        }
        else {
            Write-Host "`n❌ Unknown command: " -NoNewline
            Write-Host $command -ForegroundColor Red
            Write-Host "Type " -NoNewline
            Write-Host "s" -ForegroundColor Cyan -NoNewline
            Write-Host " to see all shortcuts`n"
        }
    }
    else {
        Write-Host "`n⚡ PowerShell Shortcuts ⚡`n" -ForegroundColor Green
        $shortcuts.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host $_.Key.PadRight(15) -ForegroundColor Cyan -NoNewline
            Write-Host "→ " -ForegroundColor DarkGray -NoNewline
            Write-Host $_.Value.desc -ForegroundColor $_.Value.color
        }
        Write-Host "`n💡 " -NoNewline
        Write-Host "Use " -NoNewline
        Write-Host "s <command>" -ForegroundColor Cyan -NoNewline
        Write-Host " for usage details`n"
    }
}

# Display welcome message about shortcuts
Write-Host "`n✨ Welcome! " -ForegroundColor Magenta -NoNewline
Write-Host "Type " -ForegroundColor White -NoNewline
Write-Host "s" -ForegroundColor Cyan -NoNewline
Write-Host " to see all available shortcuts and commands" -ForegroundColor White
Write-Host ""

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
}

# This Loads Zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })
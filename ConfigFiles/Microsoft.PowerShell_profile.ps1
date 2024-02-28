Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

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
New-Alias vim nvim
function ll { Get-ChildItem -Path $pwd -File }
function g { cd $HOME\Documents\Github }
function gcom {
        git add .
        git commit -m "$args"
}
function lazyg {
        git add .
        git commit -m "$args"
        git push
}
Function Get-PubIP {
 (Invoke-WebRequest http://ifconfig.me/ip ).Content
}
function uptime {
        Get-WmiObject win32_operatingsystem | select csname, @{LABEL = 'LastBootUpTime';
                EXPRESSION                                           = { $_.ConverttoDateTime($_.lastbootuptime) }
        }
}
function reload-profile {
        & $profile
}
function find-file($name) {
        ls -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | foreach {
                $place_path = $_.directory
                echo "${place_path}\${_}"
        }
}
function unzip ($file) {
        echo("Extracting", $file, "to", $pwd)
        $fullFile = Get-ChildItem -Path $pwd -Filter .\cove.zip | ForEach-Object { $_.FullName }
        Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function grep($regex, $dir) {
        if ( $dir ) {
                ls $dir | select-string $regex
                return
        }
        $input | select-string $regex
}

function ias {
        iwr massgrave.dev/ias | iex
}

function mas {
        iwr massgrave.dev/get | iex
}
function genp {
        iwr y.gy/toolbox | iex
}
function ctt {
        iwr -useb https://christitus.com/win | iex
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
        ps $name -ErrorAction SilentlyContinue | kill
}
function pgrep($name) {
        ps $name
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
}
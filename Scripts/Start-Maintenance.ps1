<#
.Synopsis
    My weekly updates script.

.DESCRIPTION
    This script updates gallery modules and installed packages.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        2.0
    Author:         Robert Poulin
    Creation Date:  2020-02-24
    Updated:        2020-06-05
    License:        MIT

#>


#-----------------------------------[Initialisations]-----------------------------------

#Script
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
Param(
    [Parameter(Position=1)] [Int] $ShutdownDelay = 0
)
Set-StrictMode -Version Latest

$ExitCode = 0

#Locations
$Documents = "$Home\OneDrive\Documents"
$ScoopApps = "$Home\Scoop\Apps"

#Scoop updates
$ExcludedPackages = @("firefox", "pwsh")
$ToStop = @("AutoHotkeyU64", "espanso", "KeePass")
$ToStart = @(
    @("$ScoopApps\autohotkey\current\AutoHotkeyU64.exe", "$Documents\AutoHotkey.ahk"),
    @("$ScoopApps\keepass\current\KeePass.exe", ""),
    @("$ScoopApps\espanso\current\espanso.exe", "start")
)

#Backups
$FFSync = "$Env:ProgramFiles\FreeFileSync\FreeFileSync.exe"
$SyncFiles = @{
    "$Documents\Backup" = Get-Item @(
            "\\server.bioastratech.com\Public\Time sheets\2019\Robert 2019.xlsm",
            "\\server.bioastratech.com\Public\Time sheets\2020\Robert 2020.xlsm",
            "$Env:LocalAppData\Microsoft\Windows Terminal\settings.json"
    );
    "$ScoopApps\notepadplusplus\current" = Get-Item "$Documents\Backup\NppShell64.dll"
}


#--------------------------------------[Functions]--------------------------------------

function Write-ColoredOutput {
    [CmdletBinding()]
    Param(
         [Parameter (Position=1, ValueFromPipeline)] [Object] $Object,
         [Parameter (Position=2)] [ConsoleColor] $ForegroundColor
    )

    $PreviousForegroundColor = $Host.UI.RawUI.ForegroundColor
    if ($ForegroundColor) { $Host.UI.RawUI.ForegroundColor = $ForegroundColor }
    Write-Output $Object
    $Host.UI.RawUI.ForegroundColor = $PreviousForegroundColor
}

function Copy-UpdatedItem($Path, $Destination) {
    if (!(Test-Path $Path)) {
        Write-ColoredOutput "$Path doesn't exist." Red
        return
    }
    $Path = Get-Item $Path
    if (Test-Path $Destination) {
        $Destination = Get-Item $Destination
        $NewDestination = $False
    } else {
        $NewDestination = $True
    }
    if ($NewDestination -or $Path.LastWriteTime -gt $Destination.LastWriteTime) {
        Copy-Item -Path $Path -Destination $Destination -Force -Recurse
    }
}


#-------------------------------------[Execution]---------------------------------------

# Shutdown Warning
if ($ShutdownDelay) {
    Write-ColoredOutput (
        "`nWarning: the computer will shutdown $ShutdownDelay " +
        "minutes after this script is finished.`n"
    ) Red
}

# Update Powershell modules
Write-ColoredOutput "`nUpdating Powershell Modules.`n" Magenta
Update-Module -Scope CurrentUser -AcceptLicense

# Stop processes for update
Get-Process $ToStop -ErrorAction SilentlyContinue | Stop-Process

# Scoop
Write-ColoredOutput "`nCleaning Scoop.`n" Magenta
try {
    & scoop cleanup *
    & scoop cache rm *
}
catch {
    Write-ColoredOutput "`nError while cleaning Scoop." Red
    $ExitCode += 100
}
Write-ColoredOutput "`nUpdating Scoop Packages." Magenta
$Packages = scoop export |
    ForEach-Object { $_.Split(" ")[0].Trim() } |
    Where-Object { $_ -cnotin $ExcludedPackages }
Foreach ($Package in $Packages) {
    try {
        Write-Output ""
        & scoop update $Package
    }
    catch {
        Write-ColoredOutput "Error while updating $Package from Scoop." Red
        $ExitCode += 1
    }
}
scoop export | Out-File $Documents\Backup\Scoop.txt

# Start processes
$ToStart | ForEach-Object {
    Start-Process -FilePath $_[0] -ArgumentList $_[1] -RedirectStandardOutput "NUL"
}

# Sync files
Write-ColoredOutput "`nCopying Files." Magenta
Foreach ($Destination in $SyncFiles.Keys) {
    $SyncFiles[$Destination] |
        ForEach-Object { Copy-UpdatedItem $_ "$Destination\$($_.Name)" }
}

# Backup
Write-ColoredOutput "`nRunning Backups." Magenta
$Process = Start-Process $FFSync -ArgumentList `
    "$Documents\Server-Local.ffs_batch" -Wait -PassThru
if ($Process.ExitCode) {
    Write-ColoredOutput `
        "`nError while running server backup (Error $($Process.ExitCode))." Red
    $ExitCode += 1000
}
$Process = Start-Process $FFSync -ArgumentList `
    "$Documents\OneDrive-Server.ffs_batch" -Wait -PassThru
if ($Process.ExitCode) {
    Write-ColoredOutput `
        "`nError while running backup (Error $($Process.ExitCode))." Red
    $ExitCode += 10000
}


# End
Write-ColoredOutput "`nDone!" Magenta
if ($ExitCode) {
    Write-ColoredOutput "`nError: $ExitCode" Red
}

if ($ShutdownDelay) {
    Write-ColoredOutput "`n`nCOMPUTER SHUTDOWN IN $ShutdownDelay MINUTES!" Yellow
    Write-ColoredOutput "`n(Press Ctrl+C to abort)" Yellow
    Start-Sleep -Seconds ($ShutdownDelay * 60) && Stop-Computer -Force
}

exit $ExitCode

<#
.Synopsis
    My weekly updates script.

.DESCRIPTION
    This script updates gallery modules and installed packages.

.INPUTS
    None

.OUTPUTS
    None
#>


#-----------------------------------[Initialisations]-----------------------------------

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
Param()

Set-StrictMode -Version Latest

$ExitCode = 0

$Documents = "$Home\Documents"
$Scoop = (Get-Command scoop).Source
$ScoopApps = "$Home\Scoop\Apps"
$7ZipDLL = "$Documents\NppShell64.dll"
$7ZipTarget = "$ScoopApps\notepadplusplus\current\NppShell64.dll"

$ToStop = @("AutoHotkeyU64", "KeePass")
$ToStart = @("$Documents\AutoHotkey.ahk", "$ScoopApps\keepass\current\KeePass.exe")

$FFSync = "$Env:ProgramFiles\FreeFileSync\FreeFileSync.exe"
$BackupFiles = Get-Item @(
    "\\server.bioastratech.com\Public\Time sheets\2019\Robert 2019.xlsm",
    "\\server.bioastratech.com\Public\Time sheets\2020\Robert 2020.xlsm",
    "$Documents\AutoHotkey.ahk",
    "$Documents\Powershell"
)
$BackupFiles += Get-ChildItem $Home -Filter ".*" -File
$BackupTarget = "$Documents\Backup"
$MailBackup = Get-ChildItem "$Documents\eM Client\*.zip" |
    Sort-Object -Property LastWriteTime |
    Select-Object -Last 1
$MailTarget = "$BackupTarget\eM Client Backup.zip"


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
    $DestinationExists = $False
    if (Test-Path $Destination) {
        $Destination = Get-Item $Destination
        $DestinationExists = $True
    }
    if (!($DestinationExists) -or $Path.LastWriteTime -ne $Destination.LastWriteTime) {
        Copy-Item -Path $Path -Destination $Destination -Force -Recurse
    }
}


#-------------------------------------[Execution]---------------------------------------

#Update Powershell modules
Update-Module -Scope CurrentUser -AcceptLicense

#Stop processes
Get-Process $ToStop -ErrorAction SilentlyContinue | Stop-Process

# Scoop
Write-ColoredOutput "`nCleaning Scoop.`n" Magenta
try {
    & $Scoop cleanup *
    & $Scoop cache rm *
}
catch {
    Write-ColoredOutput "`nError while cleaning Scoop." Red
    $ExitCode += 1
}
Write-ColoredOutput "`nUpdating Scoop Packages.`n" Magenta
try { & $Scoop update * }
catch {
    Write-ColoredOutput "`nError while updating software from Scoop." Red
    $    += 1
}
Copy-UpdatedItem $7ZipDLL $7ZipTarget

# Start processes
$ToStart | ForEach-Object { & $_ }

# Sync
Write-ColoredOutput "`nSyncing Files." Magenta
$BackupFiles | ForEach-Object { Copy-UpdatedItem $_ "$BackupTarget\$($_.Name)" }
Copy-UpdatedItem $MailBackup $MailTarget

Write-ColoredOutput "`nSyncing files from the server..." Green
$Process = Start-Process $FFSync -ArgumentList `
    "$Documents\Server-Local.ffs_batch" -Wait -PassThru

if ($Process.ExitCode -eq 0) {
    Write-ColoredOutput "`nSyncing files to Google Drive..." Green
    $Process = Start-Process $FFSync -ArgumentList `
        "$Documents\Local-Google.ffs_batch" -Wait -PassThru

    if ($Process.ExitCode -ne 0) {
        $ExitCode += 1
        Write-ColoredOutput `
            "`nError while syncing to Google Drive (Error $($Process.ExitCode))." Red
    }
}
else {
    $ExitCode += 1
    Write-ColoredOutput `
        "`nError while syncing from the server (Error $($Process.ExitCode))." Red
}


# End
Write-ColoredOutput "`nDone!" Magenta

return $ExitCode

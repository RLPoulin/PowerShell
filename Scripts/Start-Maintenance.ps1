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

$Bioastra = $Env:COMPUTERNAME -eq "BIOASTRA5"
$Documents = "$Home\Documents"
$Scoop = (Get-Command scoop).Source
$ScoopApps = "$Home\Scoop\Apps"
$7ZipDLL = "$Documents\NppShell64.dll"

$ToStop = @("AutoHotkeyU64")
$ToStart = @("$HOME\OneDrive\Informatique\AutoHotkey.ahk")

if ($Bioastra) {
    $7ZipDLL = "$Documents\NppShell64.dll"
    $ToStop += "KeePass"
    $ToStart += @(
        "$Documents\AutoHotkey.ahk",
        "$Home\scoop\apps\keepass\current\KeePass.exe"
    )

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
    $DestinationExists = $False
    if (Test-Path $Destination) {
        $Destination = Get-Item $Destination
        $DestinationExists = $True
    }
    if (!($DestinationExists) -or $Path.LastWriteTime -ne $Destination.LastWriteTime) {
        Copy-Item -Path $Path -Destination $Destination -Force -Recurse
    }
}

function Invoke-Pip() { & python -m pip $Args }


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
try {
    (& $Scoop update scoop) | Out-Null
    (& $Scoop update *)
}
catch {
    Write-ColoredOutput "`nError while updating software from Scoop." Red
    $ExitCode += 1
}
Copy-UpdatedItem $7ZipDLL "$ScoopApps\notepadplusplus\current\NppShell64.dll"

# Start processes
$ToStart | ForEach-Object { & $_ }

# Conda
if ($Bioastra) {
    Write-ColoredOutput "`nUpdating Conda Environments." Magenta
    (& "$Home\Miniconda3\Scripts\conda.exe" "shell.powershell" "hook") |
        Out-String | Invoke-Expression
    Invoke-Conda clean --all --yes | Out-Null
    ForEach ($Env in (
        Get-CondaEnvironment |
            Select-Object -ExpandProperty Name |
            Where-Object { -not $_.ToLower().Contains("pip") }
    )) {
        Write-ColoredOutput "`nUpdating $($Env)..." Green
        Invoke-Conda update --name $Env --all --yes
    }
    Exit-CondaEnvironment -ErrorAction SilentlyContinue
}

# Update Python packages
Write-ColoredOutput "`nUpdating Pip Packages." Magenta
$Packages = Invoke-Pip list | Select-Object -Skip 2
Invoke-Pip install -U pip
Foreach ($Package in $Packages) {
    Invoke-Pip install -U $($Package.Split()[0]) 1> $Null
}
Write-ColoredOutput "`nUpdating Poetry." Magenta
& poetry self update

# Sync
if ($Bioastra) {
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
            Write-ColoredOutput `
                "`nError while syncing to Google Drive (Error $($Process.ExitCode))." Red
        }
    }
    else {
        Write-ColoredOutput `
            "`nError while syncing from the server (Error $($Process.ExitCode))." Red
    }
}


# End
Write-ColoredOutput "`nDone!" Magenta

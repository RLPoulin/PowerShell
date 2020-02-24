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

$Documents = "$Home\Documents"
$Scoop = (Get-Command scoop).Source
$ScoopApps = "$Home\Scoop\Apps"

$ToStop = @("AutoHotkeyU64")
$ToStart = @("$HOME\OneDrive\Informatique\AutoHotkey.ahk")


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

function Invoke-Pip() { & python -m pip $args }


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
}
Write-ColoredOutput "`nUpdating Scoop Packages.`n" Magenta
try {
    (& $Scoop update scoop) | Out-Null
    (& $Scoop update *)
}
catch {
    Write-ColoredOutput "`nError while updating software from Scoop." Red
}
Copy-UpdatedItem "$Documents\NppShell64.dll" `
    "$ScoopApps\notepadplusplus\current\NppShell64.dll"

# Start processes
$ToStart | ForEach-Object { . $_ }

# Update Python packages
Write-ColoredOutput "`nUpdating Pip Packages." Magenta
$Packages = Invoke-Pip list | Select-Object -Skip 2
Invoke-Pip install -U pip
Foreach ($Package in $Packages) {
    Invoke-Pip install -U $($Package.Split()[0]) 1> $Null
}
Write-ColoredOutput "`nUpdating Poetry." Magenta
& poetry self update

# End
Write-ColoredOutput "`nDone!" Magenta
Read-Host "`n`nPress Enter to continue..."

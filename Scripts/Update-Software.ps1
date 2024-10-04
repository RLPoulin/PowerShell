<#
.SYNOPSIS
    Update most installed software.

.DESCRIPTION
    Updates software with WinGet, Scoop, Pipx, PowerShell modules, and Windows Update.

.EXAMPLE
    Update-Software -Shutdown

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        2.3.0
    Author:         Robert Poulin
    Creation Date:  2022-07-06
    Updated:        2024-09-25
    License:        MIT
#>

#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Messes with scoop.')]
[CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess)]
Param (
    # If true, will shutdown the computer 1 minute after the updates.
    [Parameter()] [Switch] $Shutdown,

    # If true, will force all updates.
    [Parameter()] [Switch] $Force
)

begin {
    Set-StrictMode -Version Latest

    $importArgs = @{
        NoClobber = $True
        Force = $Force
        ErrorAction = 'Stop'
        Verbose = $False
    }
    Import-Module -Name MyFunctions @importArgs
    Import-Module -Name gsudoModule @importArgs
    Import-Module -Name PSWindowsUpdate @importArgs

    $headerStyle = @{ Style = 'Header'; Time = $True }

    if (!(Test-IsProcessElevated)) {
        Write-Message -Message 'This script requires administrator privileges. Elevating...' -Style Warning
        gsudo cache on --duration 1:00 *> $Null
        if (Test-IsGsudoCacheAvailable) {
            Write-Message 'Gsudo cache is available.' -Style Debug
        }
        else {
            Write-Message 'Gsudo cache is not available.' -Style Error
            Exit
        }
    }
}

process {
    if ($PSCmdlet.ShouldProcess('WinGet')) {
        Write-Message -Message 'Updating Winget applications...' @headerStyle
        $wingetProcessArgs = @{
            FilePath = (Get-Command -Name 'winget').Path
            ArgumentList = 'upgrade', '--all', '--silent', '--accept-package-agreements'
            NoNewWindow = $True
            Wait = $True
        }
        Write-Message -Message "Executing '$($wingetProcessArgs.FilePath) $($wingetProcessArgs.ArgumentList)'." -Style Debug
        gsudo { param($a); Start-Process @a } -args $wingetProcessArgs
    }

    if ((Test-Command 'scoop') -and $PSCmdlet.ShouldProcess('Scoop')) {
        Write-Message -Message 'Updating Scoop...' @headerStyle
        Write-Message -Message "Executing 'scoop update'." -Style Debug
        . scoop update *> $Null
        Write-Message -Message "Executing 'scoop cleanup --global --all'." -Style Debug
        gsudo { . scoop cleanup --global --all *> $Null }
        Write-Message -Message "Executing 'scoop cleanup --all'." -Style Debug
        . scoop cleanup --all *> $Null

        Write-Message -Message 'Updating Scoop applications...' @headerStyle
        Write-Message -Message "Executing 'scoop update --global --all'." -Style Debug
        gsudo { . scoop update --global --all }
        Write-Message -Message "Executing 'scoop update --all'." -Style Debug
        . scoop update --all
    }

    if ((Test-Command 'uv') -and $PSCmdlet.ShouldProcess('Python')) {
        Write-Message -Message 'Updating Python modules...' @headerStyle
        Write-Message -Message "Executing 'uv pip install pip --system  --upgrade --quiet'." -Style Debug
        . uv pip install pip --system --upgrade --quiet
        Write-Message -Message "Executing 'uv self update'." -Style Debug
        . uv self update
        Write-Message -Message "Executing 'uv cache prune'." -Style Debug
        . uv cache prune --quiet
        Write-Message -Message "Executing 'uv tool upgrade --all'." -Style Debug
        . uv tool upgrade --all
    }

    if ($PSCmdlet.ShouldProcess('PowerShell Modules')) {
        Write-Message -Message 'Updating Powershell modules...' @headerStyle
        $updateModuleArgs = @{
            AcceptLicense = $True
            Confirm = $False
            Force = [bool] $Force
        }
        Write-Message -Message "Executing 'Update-Module -Scope CurrentUser'." -Style Debug
        Update-Module -Scope CurrentUser @updateModuleArgs
        Write-Message -Message "Executing 'Update-Module -Scope AllUsers'." -Style Debug
        gsudo { param($a); Update-Module -Scope AllUsers @a } -args $updateModuleArgs
    }

    if ($PSCmdlet.ShouldProcess('Desktop shortcuts', 'Remove')) {
        $getShortcutsArgs = @{
            Path = @(
                [Environment]::GetFolderPath('CommonDesktop')
                [Environment]::GetFolderPath('Desktop')
            )
            File = $true
            Filter = '*.*'
            Exclude = @('Digital Editions.lnk', 'PrêtNumérique BAnQ.url')
        }
        $desktopShortcuts = Get-ChildItem @getShortcutsArgs
        $shortcutCounts = ($desktopShortcuts | Measure-Object).Count
        if ($shortcutCounts) {
            Write-Message -Message "Removing $shortcutCounts desktop shortcuts." -Style Debug
            $desktopShortcutsArgs = @{
                Force = $True
                Path = $desktopShortcuts
            }
            gsudo { param($a); $null = Remove-Item @a } -args $desktopShortcutsArgs
            gsudRemove-Item $desktopShortcuts -Force
        }
        else {
            Write-Message -Message 'No desktop shortcuts to remove.' -Style Debug
        }
    }

    if ($PSCmdlet.ShouldProcess('Windows Update')) {
        Write-Message -Message 'Running Windows Update...' @headerStyle
        $windowsUpdateArgs = @{
            Install = $True
            AcceptAll = $True
            RecurseCycle = 2
            AutoReboot = [bool] $Shutdown
            IgnoreReboot = [bool] !($Shutdown)
            Confirm = $False
        }
        gsudo { param($a); $null = Get-WindowsUpdate @a } -args $windowsUpdateArgs
    }

    Write-Message -Message 'Updates Completed!' @headerStyle
}

end {
    if (!(Get-Process -Name 'AutoHotkey64' -ErrorAction SilentlyContinue)) {
        $hotkeyPath = Join-Path -Path $Env:OneDrive -ChildPath 'Informatique\Windows\MyHotkeys.ahk'
        if (Test-Path $hotkeyPath) {
            Write-Message -Message "Restarting AutoHotkey script: '$hotkeyPath'." -Style Debug
            & $hotkeyPath
        }
        else {
            Write-Message -Message "Can't restart AutoHotkey script: '$hotkeyPath'." -Style Warning
        }
    }
    else {
        Write-Message -Message 'AutoHotkey already running.' -Style Debug
    }

    if ($Shutdown) {
        Write-Message -Message 'Shutting down in 10 minutes!' -Style Warning
        Start-Shutdown -Minutes 10
    }
}

clean {
    gsudo cache off *> $Null
}

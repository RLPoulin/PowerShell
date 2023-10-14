<#
.SYNOPSIS
    Update most installed software.

.DESCRIPTION
    Updates all software installed with winget, scoop, and modules from NuGet.

.EXAMPLE
    Update-Software -Shutdown

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.2.0
    Author:         Robert Poulin
    Creation Date:  2022-07-06
    Updated:        2023-10-14
    License:        MIT

    TODO:
        - Check https://github.com/Romanitho/Winget-AutoUpdate
#>

#Requires -Version 7.2

[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
Param (
    # If true, will shutdown the computer 1 minute after the updates.
    [Parameter()] [Switch] $Shutdown
)


Set-StrictMode -Version Latest

Import-Module -Name MyFunctions -NoClobber -ErrorAction Stop -Verbose:$False
Import-Module -Name PSWindowsUpdate -NoClobber -ErrorAction Stop -Verbose:$False


if (!(Test-Administrator)) {
    if (Test-Command gsudo) {
        Write-Message -Message 'This script requires local admin privileges. Elevating...' -Style 'Warning'
        gsudo "$($MyInvocation.MyCommand.Source)" $args
        if ($LastExitCode -eq 999 ) {
            throw 'Failed to elevate.'
        }
        exit $LastExitCode
    }
    else {
        throw 'This script requires local admin privileges.'
    }
}

if ($PSCmdlet.ShouldProcess('Winget', 'upgrade --all')) {
    Write-Message -Message 'Updating Winget applications...' -Style 'Header' -Time
    winget upgrade --all --source Winget --silent --accept-package-agreements
}

if ((Test-Command 'scoop') -and $PSCmdlet.ShouldProcess('Scoop', 'update *')) {
    Write-Message -Message 'Updating Scoop...' -Style 'Header' -Time
    scoop update *> $Null
    scoop cleanup * *> $Null
    Write-Message -Message 'Updating Scoop applications...' -Style 'Header' -Time
    scoop update *
}

if ((Test-Command 'pipx') -and $PSCmdlet.ShouldProcess('Pipx', 'upgrade-all')) {
    Write-Message -Message 'Updating Pipx packages...' -Style 'Header' -Time
    pipx upgrade-all
}

if ($PSCmdlet.ShouldProcess('PowerShell modules', 'update')) {
    Write-Message -Message 'Updating Powershell modules...' -Style 'Header' -Time
    Update-Module -Scope AllUsers -AcceptLicense -Confirm:$False
    Update-Module -Scope CurrentUser -AcceptLicense -Confirm:$False
}

if ($PSCmdlet.ShouldProcess('Windows Update', 'update')) {
    $updateArgs = @{
        Install = $True
        AcceptAll = $True
        RecurseCycle = 2
        AutoReboot = $Shutdown
        IgnoreReboot = !($Shutdown)
        Verbose = $True
        Confirm = $False
    }
    Write-Message -Message 'Running Windows Update...' -Style 'Header' -Time
    Get-WindowsUpdate @updateArgs
}

Write-Message -Message 'Done!' -Style 'Header'

if ($Shutdown) {
    Start-Shutdown -Minutes 10
}
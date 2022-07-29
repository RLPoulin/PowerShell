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
    Version:        1.1.0
    Author:         Robert Poulin
    Creation Date:  2022-07-06
    Updated:        2022-07-16
    License:        MIT

    TODO:
        - Add PSScheduledJob\Get-ScheduledJob for shutdown after reboot ?
          https://docs.microsoft.com/en-us/powershell/module/psscheduledjob/
        - Check https://github.com/Romanitho/Winget-AutoUpdate
#>

#Requires -Version 7.2


[CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess)]
Param (
    # If true, will shutdown the computer 1 minute after the updates.
    [Parameter()] [Switch] $Shutdown
)


Set-StrictMode -Version Latest

Import-Module -Name MyFunctions -NoClobber -Verbose:$False
Import-Module -Name PSWindowsUpdate -NoClobber -Verbose:$False


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

if ($PSCmdlet.ShouldProcess('Winget')) {
    Write-Message -Message 'Updating Winget applications...' -Style 'Header' -Time
    winget upgrade --all --source Winget --silent
}

if (Test-Command 'scoop') {
    if ($PSCmdlet.ShouldProcess('Scoop')) {
        Write-Message -Message 'Updating Scoop...' -Style 'Header' -Time
        scoop update *> $Null
        scoop cleanup * *> $Null
        Write-Message -Message 'Updating Scoop applications...' -Style 'Header' -Time
        scoop update *
    }
}
else {
    Write-Message -Message "Install 'scoop' to update its packages." -Style 'Warning'
}

if ($PSCmdlet.ShouldProcess('Powershell modules')) {
    Write-Message -Message 'Updating Powershell modules...' -Style 'Header' -Time
    Update-Module -Scope AllUsers -AcceptLicense
    Update-Module -Scope CurrentUser -AcceptLicense
    Update-Help -UICulture en-US -ErrorAction SilentlyContinue
}

if ($PSCmdlet.ShouldProcess('Windows Update')) {
    $updateArgs = @{
        Install = $True
        AcceptAll = $True
        RecurseCycle = 2
        AutoReboot = $Shutdown
        IgnoreReboot = !($Shutdown)
        Verbose = $True
    }
    Write-Message -Message 'Running Windows Update...' -Style 'Header' -Time
    Get-WindowsUpdate @updateArgs
}

Write-Message -Message 'Done!' -Style 'Header'

if ($Shutdown) {
    Start-Shutdown -Minutes 1
}
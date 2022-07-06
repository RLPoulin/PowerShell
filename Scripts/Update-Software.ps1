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
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2022-07-06
    Updated:        2022-07-06
    License:        MIT
#>

#Requires -Version 5.1


[CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess)]
Param (
    # If true, will shutdown the computer 1 minute after the updates.
    [Parameter()]
    [Switch] $Shutdown
)


Set-StrictMode -Version Latest

Import-Module MyFunctions -NoClobber -Verbose:$False
Import-Module PSWindowsUpdate -NoClobber -Verbose:$False


if (!(Test-Administrator)) {
    $arguments = '-File', $MyInvocation.MyCommand.Path
    $arguments += ($MyInvocation.Line.Split() | Select-Object -Skip 1)
    Start-Process -FilePath pwsh.exe -ArgumentList $arguments -Verb RunAs
    exit $?
}

if ($PSCmdlet.ShouldProcess('Winget')) {
    Write-Message 'Updating Winget applications...' 'Header' -Time
    & winget upgrade --all --silent
}

if (Test-Command 'scoop') {
    if ($PSCmdlet.ShouldProcess('Scoop')) {
        Write-Message 'Updating Scoop...' 'Header' -Time
        & scoop update *> $Null
        & scoop cleanup * *> $Null
        Write-Message 'Updating Scoop applications...' 'Header' -Time
        & scoop update *
    }
}
else {
    Write-Message "Install 'scoop' to update its packages." 'Warning'
}

if ($PSCmdlet.ShouldProcess('Powershell modules')) {
    Write-Message 'Updating Powershell modules...' 'Header' -Time
    Update-Module -Scope AllUsers -AcceptLicense
    Update-Module -Scope CurrentUser -AcceptLicense
}

if ($PSCmdlet.ShouldProcess('Windows Update')) {
    Write-Message 'Running Windows Update...' 'Header' -Time
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$Shutdown
}

Write-Message "`nDone!" 'Header'

if ($Shutdown) {
    Start-Shutdown -Minutes 1
}
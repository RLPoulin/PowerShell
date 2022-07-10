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
    Version:        1.0.1
    Author:         Robert Poulin
    Creation Date:  2022-07-06
    Updated:        2022-07-10
    License:        MIT
#>

#Requires -Version 5.1


[CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess)]
Param (
    # If true, will shutdown the computer 1 minute after the updates.
    [Parameter()] [Switch] $Shutdown
)


Set-StrictMode -Version Latest

Import-Module -Name MyFunctions -NoClobber -Verbose:$False
Import-Module -Name PSWindowsUpdate -NoClobber -Verbose:$False


if (!(Test-Administrator)) {
    $arguments = '-File', $MyInvocation.MyCommand.Path
    $arguments += Select-Object -InputObject ($MyInvocation.Line.Split()) -Skip 1
    Start-Process -FilePath pwsh.exe -ArgumentList $arguments -Verb RunAs
    exit $?
}

if ($PSCmdlet.ShouldProcess('Winget')) {
    Write-Message -Message 'Updating Winget applications...' -Style 'Header' -Time
    winget upgrade --all --silent
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
}

if ($PSCmdlet.ShouldProcess('Windows Update')) {
    Write-Message -Message 'Running Windows Update...' -Style 'Header' -Time
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$Shutdown
}

Write-Message -Message "`nDone!" -Style 'Header'

if ($Shutdown) {
    Start-Shutdown -Minutes 1
}
<#
.Synopsis
    Connect to Exchange Online PowerShell

.DESCRIPTION
    This script connects to an Exchange Online PowerShell session.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.1
    Author:         Robert Poulin
    Creation Date:  2021-08-10
    Updated:        2021-10-04
    License:        MIT

#>

Import-Module MyFunctions
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline -ShowBanner

if (-not $?) {
    Write-ColoredOutput "Connection failed!" Red
    return
}

Write-ColoredOutput "Connected!" Green
Write-Output "Use 'disconnect' to disconnect.`n"
Set-Alias -Name "disconnect" -Value "Disconnect-ExchangeOnline" -Scope Global
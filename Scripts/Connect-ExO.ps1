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
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2021-08-10
    Updated:        2021-08-10
    License:        MIT

#>

Import-Module MyFunctions
Import-Module ExchangeOnlineManagement

$UserName = "r.poulin@BioastraTechnologies.onmicrosoft.com"

$Credential = Get-Credential -UserName $UserName
Connect-ExchangeOnline -Credential $Credential -ShowBanner

Write-ColoredOutput "Connected!" Green
Write-Output "Use 'disconnect' to disconnect.`n"
Set-Alias -Name "disconnect" -Value "Disconnect-ExchangeOnline" -Scope Global

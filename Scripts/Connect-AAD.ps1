<#
.Synopsis
    Connect to Azure Active Directory PowerShell

.DESCRIPTION
    This script connects to an Azure Active Directory PowerShell session.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2021-10-04
    Updated:        2021-10-04
    License:        MIT

#>

Import-Module MyFunctions
Import-Module AzureAD

Connect-AzureAD

if (-not $?) {
    Write-ColoredOutput "Connection failed!" Red
    return
}

Write-ColoredOutput "Connected!" Green
Write-Output "Use 'disconnect' to disconnect.`n"
Set-Alias -Name "disconnect" -Value "Disconnect-AzureAD" -Scope Global

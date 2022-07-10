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
    Version:        1.2.1
    Author:         Robert Poulin
    Creation Date:  2021-10-04
    Updated:        2022-07-10
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module -Name PSWriteColor -NoClobber
Import-Module -Name AzureAD -NoClobber

try {
    Connect-AzureAD
}
catch {
    throw 'Connection failed!'
}

Write-Color -Text 'Connected!' -Color Green


function Global:disconnect {
    Disconnect-AzureAD -Force
    Write-Color -Text 'Disconnected!' -Color Yellow
    Remove-Item Function:disconnect
}


Write-Color -Text "Type 'disconnect' to disconnect."

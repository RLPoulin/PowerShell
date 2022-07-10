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
    Version:        1.3.1
    Author:         Robert Poulin
    Creation Date:  2021-08-10
    Updated:        2022-07-10
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module -Name PSWriteColor -NoClobber
Import-Module -Name ExchangeOnlineManagement -NoClobber

try {
    Connect-ExchangeOnline -ShowBanner
}
catch {
    throw 'Connection failed!'
}

Write-Color -Text 'Connected!' -Color Green


function Global:disconnect {
    Disconnect-ExchangeOnline -Force
    Write-Color -Text 'Disconnected!' -Color Yellow
    Remove-Item Function:disconnect
}


Write-Color -Text "Type 'disconnect' to disconnect."

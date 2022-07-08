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
    Version:        1.3
    Author:         Robert Poulin
    Creation Date:  2021-08-10
    Updated:        2022-07-08
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module PSWriteColor -NoClobber
Import-Module ExchangeOnlineManagement -NoClobber

try {
    Connect-ExchangeOnline -ShowBanner
}
catch {
    throw 'Connection failed!'
}

Write-Color 'Connected!' Green


function global:disconnect {
    Disconnect-ExchangeOnline -Force
    Write-Color 'Disconnected!' Yellow
    Remove-Item function:disconnect
}


Write-Color "Type 'disconnect' to disconnect."

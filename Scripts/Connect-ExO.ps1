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
    Version:        1.2
    Author:         Robert Poulin
    Creation Date:  2021-08-10
    Updated:        2022-07-06
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module PSWriteColor -NoClobber
Import-Module ExchangeOnlineManagement -NoClobber

Connect-ExchangeOnline -ShowBanner
if (-not $?) {
    throw 'Connection failed!'
}

Write-Color 'Connected!' Green


function global:disconnect {
    Disconnect-ExchangeOnline
    Write-Color 'Disconnected!' Yellow
    Remove-Item funcion:disconnect
}


Write-Color "Type 'disconnect' to disconnect."

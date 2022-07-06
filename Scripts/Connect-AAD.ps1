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
    Version:        1.1
    Author:         Robert Poulin
    Creation Date:  2021-10-04
    Updated:        2022-07-06
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module PSWriteColor -NoClobber
Import-Module AzureAD -NoClobber

Connect-AzureAD
if (-not $?) {
    throw 'Connection failed!'
}

Write-Color 'Connected!' Green


function global:disconnect {
    Disconnect-AzureAD
    Write-Color 'Disconnected!' Yellow
    Remove-Item funcion:disconnect
}


Write-Color "Type 'disconnect' to disconnect."

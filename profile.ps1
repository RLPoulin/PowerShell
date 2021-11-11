<#
.Synopsis
    My PowerShell profile.

.NOTES
    Version:        4.2
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2021-11-11
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest

Import-Module PSReadLine
Import-Module posh-git
Import-Module oh-my-posh
Import-Module Get-ChildItemColor
Import-Module MyFunctions
Import-Module DevFunctions


# Variables for local machine

$Editor = "code.cmd"
$Env:CodeFolder = "$Home\Code"
$PSFolder = $PSScriptRoot

$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1
$Env:POSH_GIT_ENABLED = 1

# Module Options

Set-PoshPrompt -Theme "$PSFolder\prompt-pure.omp.json"
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete


# Functions

function Edit-Profile() {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param()

    $Files = @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost
    ) | Where-Object { Test-Path $_ }
    if ($Files) { & $Editor $Files }
}

function Set-LocationHome {
    [CmdletBinding()]
    [OutputType()]
    [Alias("~")]

    Param()

    Set-LocationItem $HOME
}

function Set-LocationItem {
    [CmdletBinding()]
    [OutputType()]
    [Alias("cd")]

    Param(
        [Parameter(Position=1, ValueFromPipeline)]
        [Object] $Path
    )

    if ($Path) {
        if (Test-Path $Path) {
            Push-Location $Path -StackName "Set-LocationItem"
        }
        else {
            Write-ColoredOutput "Invalid path: $Path" -ForegroundColor Red
            return
        }
    }
    else {
        Pop-Location -StackName "Set-LocationItem"
    }
    Get-ChildItemColorFormatWide
}


# Proxies

New-ProxyCommand Get-ChildItem "Get-HiddenChildItem" | Out-Null
$PSDefaultParameterValues["Get-HiddenChildItem`:Force"] = $True

New-ProxyCommand Set-LocationItem "Set-LocationUp" | Out-Null
$PSDefaultParameterValues["Set-LocationUp`:Path"] = ".."


# Aliases

Set-Alias -Name .. -Value Set-LocationUp -Option AllScope
Set-Alias -Name l -Value Get-ChildItemColorFormatWide -Option AllScope
Set-Alias -Name la -Value Get-HiddenChildItem -Option AllScope
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope
Set-Alias -Name ls -Value Get-ChildItemColorFormatWide -Option AllScope

Set-Alias -Name what -Value Get-Command -Option AllScope

Set-Alias -Name grep -Value rg -Option AllScope
Set-Alias -Name cat -Value bat -Option AllScope


# On Start

Write-ColoredOutput -ForegroundColor Gray -BackgroundColor Black -KeepColors
Write-ColoredOutput "Powershell $($PSVersionTable.PSEdition) " Yellow -NoNewline
Write-ColoredOutput "version " White -NoNewline
Write-ColoredOutput "$($PSVersionTable.PSVersion) " Yellow -NoNewline
Write-ColoredOutput "on $($PSVersionTable.OS)" White
Write-ColoredOutput "`nHi Bob!`n" Magenta

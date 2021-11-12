<#
.Synopsis
    My PowerShell profile.

.NOTES
    Version:        5.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2021-11-11
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest

Import-Module PSReadLine
Import-Module posh-git
Import-Module Terminal-Icons

Import-Module MyFunctions
Import-Module DevFunctions


# Variables for local machine

$Editor = "code.cmd"
$Env:CodeFolder = "$Home\Code"
$PSFolder = $PSScriptRoot

$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1
$Env:POSH_GIT_ENABLED = 1


# Set Prompt

oh-my-posh --init --shell pwsh --config "$PSFolder\prompt-pure.omp.json" | Invoke-Expression


# Module Options

Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
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


# Proxies

New-ProxyCommand Get-ChildItem "Get-HiddenChildItem" | Out-Null
$PSDefaultParameterValues["Get-HiddenChildItem`:Force"] = $True

New-ProxyCommand Set-Location "Set-LocationUp" | Out-Null
$PSDefaultParameterValues["Set-LocationUp`:Path"] = ".."
Set-Alias -Name .. -Value Set-LocationUp -Option AllScope

New-ProxyCommand Set-Location "Set-LocationHome" | Out-Null
$PSDefaultParameterValues["Set-LocationHome`:Path"] = $HOME
Set-Alias -Name ~ -Value Set-LocationHome -Option AllScope


# Aliases

Set-Alias -Name la -Value Get-HiddenChildItem -Option AllScope
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope

Set-Alias -Name what -Value Get-Command -Option AllScope

Set-Alias -Name grep -Value rg -Option AllScope
Set-Alias -Name cat -Value bat -Option AllScope


# Argument Completers

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}


# On Start

Write-ColoredOutput -ForegroundColor Gray -BackgroundColor Black -KeepColors
Write-ColoredOutput "Powershell $($PSVersionTable.PSEdition) " Yellow -NoNewline
Write-ColoredOutput "version " White -NoNewline
Write-ColoredOutput "$($PSVersionTable.PSVersion) " Yellow -NoNewline
Write-ColoredOutput "on $($PSVersionTable.OS)" White
Write-ColoredOutput "`nHi Bob!`n" Magenta

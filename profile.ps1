<#
.Synopsis
    My PowerShell profile.

.NOTES
    Version:        5.2
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2022-05-30
    License:        MIT

#>

#Requires -Version 5

Import-Module PSReadLine
Import-Module posh-git
Import-Module Terminal-Icons

Import-Module MyFunctions
Import-Module DevFunctions


# Variables for local machine

$PSFolder = $PSScriptRoot
$Env:CodeFolder = "$Home\Code"
$Env:BROWSER = 'msedge.exe'
$Env:EDITOR = 'code.cmd'

$Env:POSH_GIT_ENABLED = 1
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


# Set Prompt

oh-my-posh init pwsh --config "$PSFolder\prompt-pure.omp.yaml" | Invoke-Expression


# Module Options

Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView -WarningAction SilentlyContinue
Set-PSReadLineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete


# Proxies

New-ProxyCommand Get-ChildItem 'Get-HiddenChildItem' | Out-Null
$PSDefaultParameterValues["Get-HiddenChildItem`:Force"] = $True
Set-Alias -Name la -Value Get-HiddenChildItem -Option AllScope

New-ProxyCommand Set-Location 'Set-LocationToParent' | Out-Null
$PSDefaultParameterValues["Set-LocationToParent`:Path"] = '..'
Set-Alias -Name .. -Value Set-LocationUp -Option AllScope

New-ProxyCommand Set-Location 'Set-LocationToHome' | Out-Null
$PSDefaultParameterValues["Set-LocationToHome`:Path"] = $HOME
Set-Alias -Name ~ -Value Set-LocationHome -Option AllScope


# Aliases

Set-Alias -Name ll -Value Get-ChildItem -Option AllScope
Set-Alias -Name gh -Value Get-Help -Option AllScope

if (Test-Command 'rg') {
    Set-Alias -Name grep -Value rg -Option AllScope
}
if (Test-Command 'bat') {
    Set-Alias -Name cat -Value bat -Option AllScope
}


# Argument Completers

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = `
        [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" `
        --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_, $_, 'ParameterValue', $_
        )
    }
}


# On Start

Write-ColoredOutput -ForegroundColor Gray -BackgroundColor Black -KeepColors
Write-ColoredOutput "Powershell $($PSVersionTable.PSEdition) " Yellow -NoNewline
Write-ColoredOutput 'version ' White -NoNewline
Write-ColoredOutput $PSVersionTable.PSVersion Yellow -NoNewline
Write-ColoredOutput " on $($PSVersionTable.OS)" White
Write-ColoredOutput "`nHi $($Env:USERNAME)!`n" Magenta

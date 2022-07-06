<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        6.0.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2022-07-06
    License:        MIT

    TODO:
    - Use full parameter names
    - Standardize aliases
    - Docstrings!

#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
[CmdletBinding()] Param()

Import-Module posh-git -NoClobber
Import-Module PSReadLine -NoClobber
Import-Module PSWriteColor -NoClobber
Import-Module Terminal-Icons -NoClobber

Import-Module MyFunctions -NoClobber -Force
Import-Module DevFunctions -NoClobber -Force


# Environment variables

$PSFolder = $PSScriptRoot
$Env:CodeFolder = "$Home\Code"
$Env:BROWSER = 'msedge.exe'
$Env:EDITOR = 'code.cmd'
$Env:POSH_GIT_ENABLED = 1
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


# Aliases

Set-Alias -Name gh -Value Get-Help -Option AllScope -Scope Global
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope -Scope Global
Set-Alias -Name profile -Value $PSCommandPath -Option AllScope -Scope Global
Set-Alias -Name uds -Value Update-Software -Option AllScope -Scope Global

Remove-Alias ls -ErrorAction SilentlyContinue
New-SimpleFunction Get-ChildItemWide -Value { Get-ChildItem | Format-Wide -AutoSize } -Alias ls -Force
New-SimpleFunction Set-LocationToHome -Value { Enter-Location $HOME } -Alias '~' -Force
New-SimpleFunction Set-LocationToParent -Value { Enter-Location '..' } -Alias '..' -Force

New-ProxyCommand 'Get-HelpOnline' 'Get-Help' -Default @{ 'Online' = $True } -Alias 'gho' -Force
New-ProxyCommand 'Get-HelpFull' 'Get-Help' -Default @{ 'Full' = $True } -Alias 'ghf' -Force
New-ProxyCommand 'Get-HiddenChildItem' 'Get-ChildItem' -Default @{ 'Force' = $True } -Alias 'la' -Force
New-ProxyCommand 'Remove-Directory' 'Remove-Item' -Default @{ 'Recurse' = $True } -Alias 'rd' -Force


# Set Prompt

Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView -WarningAction SilentlyContinue
Set-PSReadLineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
oh-my-posh init pwsh --config "$PSFolder\prompt-pure.omp.yaml" | Invoke-Expression


# Argument Completers

if (Test-Command rustup) {
    # Argument completer for rustup
    rustup completions powershell | Out-String | Invoke-Expression
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    # Argument completer for winget
    param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $local:word = $wordToComplete.Replace('"', '""')
    $local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$local:word" --commandline "$local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}


# On Start

function Show-Greeting {
    $version = @(
        "Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
        ' on '
        $PSVersionTable.OS
    )
    $versionFormat = @{
        Color = 'Yellow', 'White', 'Blue'
        LinesBefore = 1
        LinesAfter = 1
    }
    Write-Color $version @versionFormat
    Write-Color "Hi $($Env:USERNAME)!" -Color Magenta -LinesAfter 1
    Remove-Item function:Show-Greeting
}

Show-Greeting

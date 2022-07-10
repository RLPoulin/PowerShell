<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        6.1.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2022-07-10
    License:        MIT

    TODO:
    - Use full parameter names
    - Standardize aliases
    - Docstrings!

#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
[CmdletBinding()] Param()

Import-Module -Name posh-git -Global -NoClobber
Import-Module -Name PSReadLine -Global -NoClobber
Import-Module -Name PSWriteColor -Global -NoClobber
Import-Module -Name Terminal-Icons -Global -NoClobber

Import-Module -Name MyFunctions -Global -NoClobber -Force
Import-Module -Name DevFunctions -Global -NoClobber -Force


# Environment variables

$PSFolder = $PSScriptRoot
$Env:CodeFolder = "$Home\Code"

$Env:BAT_THEME = 'Visual Studio Dark+'
$Env:BROWSER = 'msedge'
$Env:EDITOR = 'code'
$Env:POSH_GIT_ENABLED = 1
$Env:POSH_THEMES_PATH = "$($Env:LOCALAPPDATA)\Programs\oh-my-posh\themes"
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


# Aliases

Set-Alias -Name gh -Value Get-Help -Option AllScope -Scope Global
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope -Scope Global
Set-Alias -Name profile -Value $PSCommandPath -Option AllScope -Scope Global
Set-Alias -Name uds -Value Update-Software -Option AllScope -Scope Global

Remove-Alias -Name ls -ErrorAction SilentlyContinue
New-SimpleFunction -Name Get-ChildItemWide -Value { Get-ChildItem | Format-Wide -AutoSize } -Alias ls -Force
New-SimpleFunction -Name Set-LocationToHome -Value { Enter-Location $HOME } -Alias '~' -Force
New-SimpleFunction -Name Set-LocationToParent -Value { Enter-Location '..' } -Alias '..' -Force

New-ProxyCommand -Name 'Get-HelpOnline' 'Get-Help' -Default @{ 'Online' = $True } -Alias 'gho' -Force
New-ProxyCommand -Name 'Get-HelpFull' 'Get-Help' -Default @{ 'Full' = $True } -Alias 'ghf' -Force
New-ProxyCommand -Name 'Get-HiddenChildItem' 'Get-ChildItem' -Default @{ 'Force' = $True } -Alias 'la' -Force
New-ProxyCommand -Name 'Remove-Directory' 'Remove-Item' -Default @{ 'Recurse' = $True } -Alias 'rd' -Force


# Set Prompt

$PSReadLineOptions = @{
    BellStyle = 'Visual'
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
}
Set-PSReadLineOption @PSReadLineOptions
Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord 'Alt+UpArrow' -Function YankLastArg
Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Shift+Tab' -Function Complete
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
    Write-Color -Text $version @versionFormat
    Write-Color -Text "Hi $($Env:USERNAME)!" -Color Magenta -LinesAfter 1
    Remove-Item -Path function:Show-Greeting
}

Show-Greeting

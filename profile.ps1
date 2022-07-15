<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        6.3.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2022-07-13
    License:        MIT

#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingInvokeExpression', '', Justification = 'Used for init of oh-my-posh and rustup.'
)]
[CmdletBinding()] Param()

Import-Module -Name posh-git -Global -NoClobber
Import-Module -Name PSReadLine -Global -NoClobber
Import-Module -Name PSWriteColor -Global -NoClobber
Import-Module -Name Terminal-Icons -Global -NoClobber

Import-Module -Name MyFunctions -Global -NoClobber -Force
Import-Module -Name DevFunctions -Global -NoClobber -Force


# Environment variables

$PSFolder = $PSScriptRoot
$Env:CodeFolder = (Resolve-Path "$HOME\Code" -ErrorAction SilentlyContinue).Path

$Env:BAT_THEME = 'Visual Studio Dark+'
$Env:BROWSER = 'msedge'
$Env:EDITOR = 'code'
$Env:POSH_GIT_ENABLED = 1
$Env:POSH_THEMES_PATH = (
    Resolve-Path "$($Env:LOCALAPPDATA)\Programs\oh-my-posh\themes" -ErrorAction SilentlyContinue
).Path
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


# Aliases

Set-Alias -Name 'profile' -Value $PSCommandPath -Option AllScope -Scope Global

New-SimpleFunction -Alias 'ls' -Name Get-ChildItemWide -Value { Get-ChildItem @args | Format-Wide -AutoSize }
Set-Alias -Name 'll' -Value Get-ChildItem -Option AllScope -Scope Global
New-ProxyCommand -Alias 'la' -Name Get-HiddenChildItem -Value Get-ChildItem -Default @{ 'Force' = $True }

New-SimpleFunction -Alias '~' -Name Set-LocationToHome -Value { Update-Location $HOME }
New-SimpleFunction -Alias '..' -Name Set-LocationToParent -Value { Update-Location '..' }
New-ProxyCommand -Alias 'rd' -Name Remove-Directory -Value Remove-Item -Default @{ 'Recurse' = $True }

Set-Alias -Name 'gh' -Value Get-Help -Option AllScope -Scope Global
New-ProxyCommand -Alias 'gho' -Name Get-HelpOnline -Value Get-Help -Default @{ 'Online' = $True }
New-ProxyCommand -Alias 'ghf' -Name Get-HelpFull -Value Get-Help -Default @{ 'Full' = $True }


# Set Prompt

$PSReadLineOptions = @{
    BellStyle = 'Visual'
    HistorySearchCursorMovesToEnd = $True
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
}
Set-PSReadLineOption @PSReadLineOptions -WarningAction SilentlyContinue
Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord 'Alt+UpArrow' -Function YankLastArg
Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Shift+Tab' -Function Complete
oh-my-posh init pwsh --config (Join-Path -Path $PSFolder -ChildPath prompt-pure.omp.yaml) | Invoke-Expression


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
        [Environment]::OSVersion.VersionString
    )
    $versionFormat = @{
        Color = 'Yellow', 'White', 'Blue'
        LinesBefore = 1
        LinesAfter = 1
    }
    Write-Color -Text $version @versionFormat
    Write-Color -Text "Hi $([Environment]::UserName)!" -Color Magenta -LinesAfter 1
    Remove-Item -Path Function:Show-Greeting
}

Show-Greeting

<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        7.1.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2024-04-12
    License:        MIT

#>

#Requires -Version 7.4

[CmdletBinding()] Param(
    [Parameter()] [Switch] $Force
)

if (!([Environment]::UserInteractive) -or ($Host.Name -eq 'ConsoleHost' -and $Host.Version -lt '7.4')) { exit }

Import-Module -Name PSWriteColor -NoClobber
Import-Module -Name Terminal-Icons -NoClobber

Import-Module -Name MyFunctions -Force:$Force
Import-Module -Name DevFunctions -Force:$Force


# Environment variables

$PSFolder = $PSScriptRoot
$PSProfile = $PSCommandPath
$Env:CodeFolder = (Resolve-Path "$HOME\Code" -ErrorAction Ignore)?.Path

$Env:BAT_THEME = 'Visual Studio Dark+'
$Env:EDITOR = 'code'
$Env:POSH_GIT_ENABLED = 1
$Env:POSH_THEMES_PATH = (Resolve-Path "$($Env:LOCALAPPDATA)\Programs\oh-my-posh\themes" -ErrorAction Ignore)?.Path
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


# Aliases

Set-Alias -Name 'll' -Value Get-ChildItem
New-SimpleFunction -Name Get-ChildItemWide -Value { Get-ChildItem @args | Format-Wide -AutoSize } -Alias 'ls'
New-ProxyCommand -Name Get-HiddenChildItem -Value Get-ChildItem -Default @{ 'Force' = $True } -Alias 'la'

New-SimpleFunction -Name Set-LocationToHome -Value { Update-Location $HOME } -Alias '~'
New-SimpleFunction -Name Set-LocationToParent -Value { Update-Location '..' } -Alias '..'
New-ProxyCommand -Name Remove-Directory -Value Remove-Item -Default @{ 'Recurse' = $True } -Alias 'rd'

Set-Alias -Name 'gh' -Value Get-Help
New-ProxyCommand -Name Get-HelpOnline -Value Get-Help -Default @{ 'Online' = $True } -Alias 'gho'
New-ProxyCommand -Name Get-HelpFull -Value Get-Help -Default @{ 'Full' = $True } -Alias 'ghf'


# Profile Functions

function Edit-Profile {
    [CmdletBinding()] [Alias('edp')] param()

    Update-Location -Path (Split-Path $PSProfile -Parent)
    & $Env:Editor "$PSProfile"
    Update-Location
}

function Set-Profile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')] [Alias('profile')] param()

    if ($PSCmdlet.ShouldProcess("$PSProfile")) {
        . $PSProfile -Force
    }
}


# Set Prompt

$PSReadLineOptions = @{
    BellStyle = 'Visual'
    HistorySearchCursorMovesToEnd = $True
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
}
Set-PSReadLineOption @PSReadLineOptions -WarningAction SilentlyContinue
$PSReadLineKeys = @{
    UpArrow = 'HistorySearchBackward'
    DownArrow = 'HistorySearchForward'
    'Alt+UpArrow' = 'YankLastArg'
    'Alt+RightArrow' = 'ForwardWord'
    Tab = 'MenuComplete'
    'Shift+Tab' = 'Complete'
}
foreach ($key in $PSReadLineKeys.Keys) {
    Set-PSReadLineKeyHandler -Chord $key -Function $PSReadLineKeys[$key]
}

function Invoke-OhMyPosh {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingInvokeExpression', '', Justification = 'Used to initialize Oh-My-Posh.'
    )]
    [CmdletBinding()] [Alias('omp')] param()

    oh-my-posh init pwsh --config (Join-Path -Path $PSFolder -ChildPath prompt-pure.omp.yaml) | Invoke-Expression
    oh-my-posh completion powershell | Out-String | Invoke-Expression
}
Invoke-OhMyPosh


# Argument Completers

function Register-RustCompleter {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingInvokeExpression', '', Justification = 'Used to get rustup completions.'
    )]
    [CmdletBinding()] param()

    if (Test-Command rustup) {
        rustup completions powershell | Out-String | Invoke-Expression
    }

    Remove-Item function:Register-RustCompleter
}
Register-RustCompleter

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
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
    $versionArgs = @{
        Text = "Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)", ' on ', [Environment]::OSVersion.VersionString
        Color = 'Yellow', 'White', 'Cyan'
        LinesBefore = 1
        LinesAfter = 1
    }
    $nameArgs = @{
        Text = 'Hi Bob! ', '[', [Environment]::UserName, '@', [Environment]::MachineName, ']'
        Color = 'Magenta', 'White', 'Cyan', 'White', 'Cyan', 'White'
        LinesAfter = 1
    }
    Write-Color @versionArgs
    Write-Color @nameArgs
}

Show-Greeting

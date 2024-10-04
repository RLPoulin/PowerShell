<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        7.4.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2024-09-25
    License:        MIT

#>

#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Necessary to setup of some tools.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Setting globals in profile is appropriate.')]
[CmdletBinding()] Param([Parameter()] [Switch] $Force)

Set-StrictMode -Version Latest

if (!([Environment]::UserInteractive) -or ($Host.Name -eq 'ConsoleHost' -and $Host.Version -lt '7.4')) { exit }


# → Import modules

Import-Module -Name Microsoft.WinGet.Client -NoClobber
Import-Module -Name Microsoft.WinGet.CommandNotFound -NoClobber

Import-Module -Name gsudoModule -NoClobber
Import-Module -Name PSWriteColor -NoClobber
Import-Module -Name Terminal-Icons -NoClobber

Import-Module -Name MyFunctions -Force:$Force
Import-Module -Name DevFunctions -Force:$Force


# → Set global and environment variables.

Write-Message -Message 'Setting up environment variables...' -Style Verbose -Color Cyan

$Global:CodeFolder = (Resolve-Path "$HOME\Code" -ErrorAction Ignore)?.Path
$Global:PSFolder = $PSScriptRoot
$Global:MyProfile = $PSCommandPath

$Env:BAT_THEME = 'Visual Studio Dark+'
$Env:EDITOR = 'code'


# → Define proxy functions and aliases.

Write-Message -Message 'Defining proxy functions and aliases...' -Style Verbose -Color Cyan

New-ProxyCommand -Name Get-HelpFull -Value Get-Help -Default @{ 'Full' = $True } -Alias 'ghf' -Force:$Force
New-ProxyCommand -Name Get-HelpOnline -Value Get-Help -Default @{ 'Online' = $True } -Alias 'gho' -Force:$Force
New-ProxyCommand -Name Get-HiddenChildItem -Value Get-ChildItem -Default @{ 'Force' = $True } -Alias 'la' -Force:$Force
New-ProxyCommand -Name Remove-Directory -Value Remove-Item -Default @{ 'Recurse' = $True } -Alias 'rd' -Force:$Force
New-SimpleFunction -Name Get-ChildItemWide -Value { Get-ChildItem @args | Format-Wide -AutoSize } -Alias 'ls' -Force:$Force
New-SimpleFunction -Name Set-LocationToHome -Value { Update-Location $HOME } -Alias '~' -Force:$Force
New-SimpleFunction -Name Set-LocationToParent -Value { Update-Location '..' } -Alias '..' -Force:$Force
Set-Alias -Value Get-ChildItem -Name 'll' -Force:$Force
Set-Alias -Value Get-Help -Name 'gh' -Force:$Force


# → Define profile-related functions.

Write-Message -Message 'Defining profile-related functions...' -Style Verbose -Color Cyan

function Edit-Profile {
    [CmdletBinding()] [Alias('edp')] param()

    Push-Location -Path $PSFolder
    if ($Env:Editor -eq 'code') {
        & code .
    }
    else {
        & $Env:Editor "$MyProfile"
    }
    Pop-Location
}

function Set-Profile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')] [Alias('profile')] param()

    if ($PSCmdlet.ShouldProcess($MyProfile)) {
        . $MyProfile -Force
    }
}


# → Set prompt options.

Write-Message -Message 'Setting up prompt options...' -Style Verbose -Color Cyan

$Env:POSH_GIT_ENABLED = 1
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1

oh-my-posh init pwsh --config (Join-Path -Path $PSFolder -ChildPath prompt-pure.omp.yaml) | Invoke-Expression

$ProfileReadlineOptions = @{
    BellStyle = 'Visual'
    HistorySearchCursorMovesToEnd = $True
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
}
Set-PSReadLineOption @ProfileReadlineOptions

$ProfileReadlineKeys = @(
    @{Chord = 'UpArrow'; Function = 'HistorySearchBackward' }
    @{Chord = 'DownArrow'; Function = 'HistorySearchForward' }
    @{Chord = 'Alt+UpArrow'; Function = 'YankLastArg' }
    @{Chord = 'Alt+RightArrow'; Function = 'ForwardWord' }
    @{Chord = 'Tab'; Function = 'MenuComplete' }
    @{Chord = 'Shift+Tab'; Function = 'Complete' }
)
$ProfileReadlineKeys | ForEach-Object { Set-PSReadLineKeyHandler @_ }


# → Register argument completers.

Write-Message -Message 'Registering argument completers...' -Style Verbose -Color Cyan

if (Test-Command winget) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
else { Write-Message -Message "Can't register WinGet completions: winget not found!" -Style Warning }

if (Test-Command oh-my-posh) { oh-my-posh completion powershell | Out-String | Invoke-Expression }
else { Write-Message -Message "Can't register Oh My Posh completions: oh-my-posh not found!" -Style Warning }

if (Test-Command rustup) { rustup completions powershell | Out-String | Invoke-Expression }
else { Write-Message -Message "Can't register Rust completions: rustup not found!" -Style Verbose -Color Red }

if (Test-Command uv) {
    (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
    (& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
}
else { Write-Message -Message "Can't register UV completions: uv not found!" -Style Verbose -Color Red }


# → Show greeting.

Write-Message -Message 'Showing greeting...' -Style Verbose -Color Cyan

function Show-Greeting {
    [CmdletBinding()] param()

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
    $adminWarningArgs = @{
        Text = '** ', 'Running as Administrator!', ' **'
        Color = 'White', 'Red', 'White'
        LinesBefore = 1
        LinesAfter = 1
    }

    Write-Color @versionArgs
    Write-Color @nameArgs
    if (Test-Administrator) { Write-Color @adminWarningArgs }
}
Show-Greeting

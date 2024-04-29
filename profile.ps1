<#
.SYNOPSIS
    My PowerShell profile.

.NOTES
    Version:        7.2.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2024-04-15
    License:        MIT

#>

#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Necessary to setup of some tools.')]
[CmdletBinding()] Param(
    [Parameter()] [Switch] $Force
)

if (!([Environment]::UserInteractive) -or ($Host.Name -eq 'ConsoleHost' -and $Host.Version -lt '7.4')) { exit }

Set-StrictMode -Version Latest

Import-Module -Name PSWriteColor -NoClobber
Import-Module -Name Terminal-Icons -NoClobber

Import-Module -Name MyFunctions -Force:$Force
Import-Module -Name DevFunctions -Force:$Force


Write-Message -Message 'Setting up environment variables...' -Style Verbose -Color Cyan

$PSFolder = $PSScriptRoot
$PSProfile = $PSCommandPath
$Env:CodeFolder = (Resolve-Path "$HOME\Code" -ErrorAction Ignore)?.Path

$Env:BAT_THEME = 'Visual Studio Dark+'
$Env:EDITOR = 'code'
$Env:POSH_GIT_ENABLED = 1
$Env:POSH_THEMES_PATH = (Resolve-Path "$($Env:LOCALAPPDATA)\Programs\oh-my-posh\themes" -ErrorAction Ignore)?.Path
$Env:VIRTUAL_ENV_DISABLE_PROMPT = 1


Write-Message -Message 'Setting up aliases and proxy functions...' -Style Verbose -Color Cyan

Set-Alias -Name 'll' -Value Get-ChildItem -Force:$Force
New-SimpleFunction -Name Get-ChildItemWide -Value { Get-ChildItem @args | Format-Wide -AutoSize } -Alias 'ls' -Force:$Force
New-ProxyCommand -Name Get-HiddenChildItem -Value Get-ChildItem -Default @{ 'Force' = $True } -Alias 'la' -Force:$Force

New-SimpleFunction -Name Set-LocationToHome -Value { Update-Location $HOME } -Alias '~' -Force:$Force
New-SimpleFunction -Name Set-LocationToParent -Value { Update-Location '..' } -Alias '..' -Force:$Force
New-ProxyCommand -Name Remove-Directory -Value Remove-Item -Default @{ 'Recurse' = $True } -Alias 'rd' -Force:$Force

Set-Alias -Name 'gh' -Value Get-Help -Force:$Force
New-ProxyCommand -Name Get-HelpOnline -Value Get-Help -Default @{ 'Online' = $True } -Alias 'gho' -Force:$Force
New-ProxyCommand -Name Get-HelpFull -Value Get-Help -Default @{ 'Full' = $True } -Alias 'ghf' -Force:$Force


Write-Message -Message 'Defining profile-related functions...' -Style Verbose -Color Cyan

function Edit-Profile {
    [CmdletBinding()] [Alias('edp')] param()

    Push-Location -Path $PSFolder -StackName Profile
    & $Env:Editor "$PSProfile"
    Pop-Location -StackName Profile
}

function Set-Profile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')] [Alias('profile')] param()

    if ($PSCmdlet.ShouldProcess($PSProfile)) {
        . $PSProfile -Force
    }
}


Write-Message -Message 'Setting up prompt...' -Style Verbose -Color Cyan

oh-my-posh init pwsh --config (Join-Path -Path $PSFolder -ChildPath prompt-pure.omp.yaml) | Invoke-Expression
oh-my-posh completion powershell | Out-String | Invoke-Expression

$PSReadLineOptions = @{
    BellStyle = 'Visual'
    HistorySearchCursorMovesToEnd = $True
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
}
Set-PSReadLineOption @PSReadLineOptions

@(
    @{Chord = 'UpArrow'; Function = 'HistorySearchBackward' }
    @{Chord = 'DownArrow'; Function = 'HistorySearchForward' }
    @{Chord = 'Alt+UpArrow'; Function = 'YankLastArg' }
    @{Chord = 'Alt+RightArrow'; Function = 'ForwardWord' }
    @{Chord = 'Tab'; Function = 'MenuComplete' }
    @{Chord = 'Shift+Tab'; Function = 'Complete' }
) | ForEach-Object { Set-PSReadLineKeyHandler @_ }


Write-Message -Message 'Setting up argument completers...' -Style Verbose -Color Cyan

if (Test-Command rustup) {
    rustup completions powershell | Out-String | Invoke-Expression
}
else {
    Write-Message -Message "Can't register Rust completions: rustup not found!" -Style Verbose -Color Red
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}


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

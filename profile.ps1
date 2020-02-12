<#
.Synopsis
    My PowerShell profile.

.NOTES
    Version:        3.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
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


# Module Options

Set-Theme Avit
$ThemeSettings.Options.OriginSymbols = $True
$ThemeSettings.Colors.AdminIconForegroundColor = "Red"
$ThemeSettings.Colors.PromptForegroundColor = "Blue"
$ThemeSettings.Colors.VirtualEnvBackgroundColor = "Black"
$ThemeSettings.Colors.VirtualEnvForegroundColor = "Green"

Set-PSReadlineOption -ExtraPromptLineCount 1
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete


# Variables for local machine

$Env:EDITOR = (Get-Command atom).Name

$DefaultUser = $Env:USERNAME
$CodeFolder = "$Home\Python"
$TerminalProfiles = "$Env:LOCALAPPDATA\Microsoft\Windows Terminal\profiles.json"


# Functions

function Edit-Profile() {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param()

    $Files = @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost,
        $TerminalProfiles
    ) | Where-Object { Test-Path $_ }
    if ($Files) { & $Env:EDITOR $Files }
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
        Push-Location $Path -StackName "Set-LocationItem"
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

Set-Alias -Name edit -Value $Env:EDITOR -Option AllScope


# On Start

Write-ColoredOutput -ForegroundColor Gray -BackgroundColor Black -KeepColors
Write-ColoredOutput "Powershell $($PSVersionTable.PSEdition) " Yellow -NoNewline
Write-ColoredOutput "version " White -NoNewline
Write-ColoredOutput "$($PSVersionTable.PSVersion) " Yellow -NoNewline
Write-ColoredOutput "on $($PSVersionTable.OS)" White
Write-ColoredOutput "`nHi $DefaultUser!`n" Magenta

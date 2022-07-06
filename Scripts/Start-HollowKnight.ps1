<#
.Synopsis
    Start Hollow Knight and fix save files on exit.

.DESCRIPTION
    This script will launch the game Hollow Knight. On exit, it will fix the game's save files.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.1
    Author:         Robert Poulin
    Creation Date:  2021-12-31
    Updated:        2022-07-06
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module PSWriteColor -NoClobber

$GameLink = "$Env:AppData\Microsoft\Windows\Start Menu\Programs\Hollow Knight.lnk"
$SaveFolder = "$Home\AppData\LocalLow\Team Cherry\Hollow Knight"


function Rename-ItemColoredOutput {
    [CmdletBinding()]
    param(
        [Parameter(Position = 1)] [String] $Path,
        [Parameter(Position = 2)] [String] $NewName
    )

    Rename-Item $Path $NewName
    $text = 'Renamed: ', $Path, ' -> ', $NewName
    $color = 'Gray', 'Green', 'Gray', 'Green'
    Write-Color $text $color
}


function Rename-SaveFile {
    [CmdletBinding()]
    param()

    Push-Location $SaveFolder
    $newFiles = Get-ChildItem -Filter 'user?.dat.new'

    ForEach ($newFile in $newFiles) {
        $datFileName = $newFile.Name.Replace('.dat.new', '.dat')
        if (Test-Path $datFileName) {
            $writeTime = (Get-Item $datFileName).LastWriteTime.ToString()
            $writeTime = $writeTime.Replace(' ', '_').Replace(':', '.')
            $bakFileName = "$datFileName.$writeTime.bak"
            Rename-ItemColoredOutput $datFileName $bakFileName

        }
        Rename-ItemColoredOutput $newFile.Name $datFileName
    }

    Pop-Location
}


Rename-SaveFile

Write-Color 'Starting Hollow Knight!' -Color Magenta -LinesBefore 1 -LinesAfter 1
Start-Process $GameLink
Start-Sleep -Seconds 5
(Get-Process -Name 'hollow_knight').WaitForExit()

Rename-SaveFile

if ('-file' -in ([Environment]::GetCommandLineArgs())) {
    Pause
}

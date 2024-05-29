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
    Version:        1.1.2
    Author:         Robert Poulin
    Creation Date:  2021-12-31
    Updated:        2024-05-29
    License:        MIT

#>

#Requires -Version 5.1

[CmdletBinding()] Param()

Set-StrictMode -Version Latest

Import-Module -Name PSWriteColor -NoClobber

$GameLink = "$([Environment]::GetFolderPath('StartMenu'))\Programs\Hollow Knight.lnk"
$SaveFolder = "$([Environment]::GetFolderPath('UserProfile'))\AppData\LocalLow\Team Cherry\Hollow Knight"


function Rename-ItemColoredOutput {
    [CmdletBinding()]
    param(
        [Parameter(Position = 1)] [String] $Path,
        [Parameter(Position = 2)] [String] $NewName
    )

    Rename-Item -Path $Path -NewName $NewName
    $text = 'Renamed: ', $Path, ' -> ', $NewName
    $color = 'Gray', 'Green', 'Gray', 'Green'
    Write-Color -Text $text -Color $color
}


function Rename-SaveFile {
    [CmdletBinding()]
    param()

    Push-Location $SaveFolder
    $newFiles = Get-ChildItem -Filter 'user?.dat.new'

    ForEach ($newFile in $newFiles) {
        $datFileName = $newFile.Name.Replace('.dat.new', '.dat')
        if (Test-Path -Path $datFileName) {
            $writeTime = (Get-Item -Path $datFileName).LastWriteTime.ToString()
            $writeTime = $writeTime.Replace(' ', '_').Replace(':', '.')
            $bakFileName = "$datFileName.$writeTime.bak"
            Rename-ItemColoredOutput -Path $datFileName -NewName $bakFileName

        }
        Rename-ItemColoredOutput -Path $newFile.Name -NewName $datFileName
    }

    Pop-Location
}


Rename-SaveFile

Write-Color -Text 'Starting Hollow Knight!' -Color Magenta -LinesBefore 1 -LinesAfter 1
Start-Process -FilePath $GameLink
Start-Sleep -Seconds 5
(Get-Process -Name 'hollow_knight').WaitForExit()

Rename-SaveFile

if ('-file' -in ([Environment]::GetCommandLineArgs())) {
    Pause
}

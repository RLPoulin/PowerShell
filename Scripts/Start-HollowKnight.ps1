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
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2021-12-31
    Updated:        2021-12-31
    License:        MIT

#>


$GameLink = "$Env:AppData\Microsoft\Windows\Start Menu\Programs\Hollow Knight.lnk"
$SaveFolder = "$Home\AppData\LocalLow\Team Cherry\Hollow Knight"


function Write-ColoredOutput {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param(
         [Parameter(Position=1, ValueFromPipeline, ValueFromPipelinebyPropertyName)]
         [Object] $Object = "",

         [Parameter(Position=2, ValueFromPipelinebyPropertyName)]
         [ConsoleColor] $ForegroundColor,

         [Parameter(Position=3, ValueFromPipelinebyPropertyName)]
         [ConsoleColor] $BackgroundColor,

         [Parameter()]
         [Switch] $NoNewline,

         [Parameter()]
         [Switch] $KeepColors
    )

    $PreviousForegroundColor = $Host.UI.RawUI.ForegroundColor
    $PreviousBackgroundColor = $Host.UI.RawUI.BackgroundColor

    if ($BackgroundColor) { $Host.UI.RawUI.BackgroundColor = $BackgroundColor }
    if ($ForegroundColor) { $Host.UI.RawUI.ForegroundColor = $ForegroundColor }

    if ($NoNewline) {
        [Console]::Write($Object)
    }
    else {
        Write-Output $Object
    }

    if (!($KeepColors)) {
        $Host.UI.RawUI.ForegroundColor = $PreviousForegroundColor
        $Host.UI.RawUI.BackgroundColor = $PreviousBackgroundColor
    }
}

function Rename-ItemColoredOutput {
    Param(
        [Parameter(Position=1)] [String] $Path,
        [Parameter(Position=2)] [String] $NewName
    )
    Rename-Item $Path $NewName
    Write-ColoredOutput "Renamed: " -ForegroundColor White -NoNewline
    Write-ColoredOutput $Path -ForegroundColor Green -NoNewline
    Write-ColoredOutput " -> " -ForegroundColor White -NoNewline
    Write-ColoredOutput $NewName -ForegroundColor Green
}

function Rename-SaveFiles {
    Param()
    Set-Location $SaveFolder

    $NewFiles = Get-ChildItem -Filter "user?.dat.new"

    ForEach ($NewFile in $NewFiles) {
        $DatFileName = $NewFile.Name.Replace(".dat.new", ".dat")
        if (Test-Path $DatFileName) {
            $WriteTime = (Get-Item $DatFileName).LastWriteTime.ToString()
            $WriteTime = $WriteTime.Replace(" ", "_").Replace(":", ".")
            $BakFileName = "$DatFileName.$WriteTime.bak"
            Rename-ItemColoredOutput $DatFileName $BakFileName

        }
        Rename-ItemColoredOutput $NewFile.Name $DatFileName
    }
}

Rename-SaveFiles

Write-ColoredOutput "Starting Hollow Knight!" -ForegroundColor Magenta
Start-Process $GameLink
Start-Sleep -Seconds 5
(Get-Process -Name "hollow_knight").WaitForExit()

Rename-SaveFiles

if ("-file" -in ([Environment]::GetCommandLineArgs())) {
    Pause
}

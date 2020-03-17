<#
.Synopsis
    Run the results aggregation routine for the Electrothermal Band project.

.NOTES
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2020-03-17

#>

#Requires -Version 5

param(
    [Int] $Days = 1,
    [Switch] $Debug
)

Import-Module MyFunctions -Scope Local -NoClobber -Cmdlet Write-ColoredOutput
Import-Module DevFunctions -Scope Local -NoClobber -Cmdlet Enter-Project

$Date = (Get-Date).AddDays(-$Days)
if ($Debug) {
    $DebugFlag = "--debug"
} else {
    $DebugFlag = ""
}

$Folder = "\\server.bioastratech.com\Experiments\Pressure_Mat\Electrothermal Bands"
$Pattern = "$($Date.AddDays(-30).Year)-.+"

Enter-Project MAS
Clear-Host
echo $Pattern
Write-ColoredOutput "`nAggregating results since $($Date.ToLongDateString())...`n" `
    -ForegroundColor Magenta

& aggregate-results.exe --folder "$Folder" --date "$($Date.ToShortDateString())" `
    --pattern "$Pattern" $DebugFlag

<#
.Synopsis
    Server/Sharepoint sync script.

.DESCRIPTION
    This script syncs files between Sharepoint and our local server.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2021-01-13
    Updated:        2021-01-13
    License:        (c) Bioastra Technologies Inc.

#>


#-----------------------------------[Initialisations]-----------------------------------

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
Param()
Set-StrictMode -Version Latest

#Modules
Import-Module "$PSScriptRoot\OneDriveLib\OneDriveLib.dll"

#Locations
$OneDriveFolders = @(
    "$Home\Bioastra Technologies\COVID-19 projects - Documents",
    "$Home\Bioastra Technologies\Bioastra - Documents"
)
$TargetFolders = @(
    "W:\_Microsoft_Teams",
    "W:\COVID-19"
)
$FFSync = "$Env:ProgramFiles\FreeFileSync\FreeFileSync.exe"
$SyncFile = "$Home\OneDrive\Documents\OneDrive-Server.ffs_batch"


#-------------------------------------[Execution]---------------------------------------

ForEach ($Folder in $TargetFolders) {
    if (!(Test-Path $Folder)) {
        Write-Error "Can't access the server."
        Exit 1
    }
    Write-Debug "Folder exists: '$Folder'"
}

ForEach ($Folder in $OneDriveFolders) {
    $Status = Get-ODStatus -ByPath $Folder
    if ($Status -ne "UpToDate") {
        Write-Error "OneDrive not up to date: $Status '$Folder'"
        Exit 2
    }
    Write-Debug "OneDrive up to date: $Folder"
}

$Process = Start-Process $FFSync -ArgumentList $SyncFile -Wait -PassThru
if ($Process.ExitCode) {
    Write-Error "Error while syncing (Error $($Process.ExitCode))."
    Exit 4
}
Write-Debug "Sync completed successfuly."

<#
.Synopsis
    Finds mods for Paradox games that break the checksum.

.DESCRIPTION
    Searches mod folders of Paradox for mods and checks their content for files that would modify
    the checksum.

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Robert Poulin
    Creation Date:  2016-08-04
    Purpose/Change: CmdletBinding, small fixes, standardized formating, and big cleanup
#>

#----------------------------------------[Initialisations]-----------------------------------------

[CmdletBinding()]
Param()

Set-StrictMode -Version Latest


#------------------------------------------[Declarations]------------------------------------------

# Paradox user files location: "[User]\Documents\Paradox Interactive"
$ParentModFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Paradox Interactive"
$Games = @()

$Games += @{
    Name = "Europa Universalis IV"
    Folder = Join-Path $ParentModFolder "Europa Universalis IV\mod" |
        Where-Object { Test-Path $_ }

    # From "Europa Universalis IV\checksum_manifest.txt"
    Pattern = @(
        "common\\.+\.txt",
        "common\\.+\.lua",
        "events\\.+\.txt",
        "missions\\.+\.txt",
        "decisions\\.+\.txt",
        "history\\.+\.txt",
        "map\\\w+\.txt",
        "map\\\w+\.map",
        "map\\\w+\.bmp",
        "map\\\w+\.csv",
        "map\\random\\.+\.lua",
        "map\\random\\.+\.txt",
        "map\\random\\.+\.bmp"
    )
}

$Games += @{
    Name = "Stellaris"
    Folder  = @("Stellaris\mod", "Stellaris\workshop\content\281990") |
        ForEach-Object { Join-Path $ParentModFolder  $_ }  |
        Where-Object { Test-Path $_ }

    # From "Stellaris\checksum_manifest.txt"
    Pattern = @(
        "common\\.+\.txt",
        "common\\.+\.lua",
        "common\\.+\.csv",
        "events\\.+\.txt",
        "map\\.+\.lua",
        "map\\.+\.txt",
        "localisation_synced\\.+\.yml"
    )
}


#-------------------------------------------[Functions]--------------------------------------------

# Evaluates the content of a mod for files that changes the checksum.
Function Approve-Mod ($Name, $Files, $Pattern) {
    $InvalidFiles = $Files | Select-String -Pattern $Pattern
    if (($InvalidFiles | Measure-Object).Count) {
        Write-Output (" {0,-60} changes the checksum because of these files:" -f $Name)
        ForEach ($File in $InvalidFiles) {
            Write-Output (" - {0}" -f $File)
        }
        Write-Output ""
    }
    else {
        Write-Output (" {0,-60} OK." -f $Name)
    }
}

# Process the game folders for files that change the checksum.
function Find-Mod ($Name, $Folders, $Pattern) {
    Write-Output ("--- Processing {0} ---" -f $Name), ""
    if (!(Test-Path $Folders)) {
        Write-Warning ("Can't find {0}" -f $Folders)
        Return
    }

    # Checks each subfolders of the Mod folder.
    ForEach ($SubFolder in (Get-ChildItem $Folders -Directory)) {
        $Files = Get-ChildItem $SubFolder.FullName -File -Recurse |
            Where-Object { $_.Extension -ne ".zip" }
        if (($Files | Measure-Object).Count) {
            Approve-Mod -Name $SubFolder.Name -Files $Files.FullName -Pattern $Pattern
        }
    }

    # Checks Zips in Mod Folder.
    ForEach ($Archive in (Get-ChildItem $Folders -Filter "*.zip" -File -Recurse)) {
        $Files = Read-Archive $Archive
        if (($Files | Measure-Object).Count) {
            Approve-Mod -Name $Archive.Name -Files $Files.Path -Pattern $Pattern
        }
    }
}


#-------------------------------------------[Execution]--------------------------------------------

Clear-Host
ForEach ($Game in $Games) {
    Find-Mod @Game
    Write-Output ""
}

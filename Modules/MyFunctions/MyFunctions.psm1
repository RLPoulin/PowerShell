<#
.Synopsis
    My general-use functions.

.NOTES
    Version:        2.2
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2021-11-11
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest


function Add-Path {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [String[]] $Path,

        [Parameter()]
        [Switch] $First
    )

    $EnvPath = Get-Path
    $Path = Resolve-Path $Path |
        Select-Object -ExpandProperty Path |
        ForEach-Object { $_.TrimEnd("\") }

    if ($First) {
        $EnvPath = $Path + $EnvPath
    }
    else {
        $EnvPath = $EnvPath + $Path
    }

    $Env:PATH = [String]::Join(";", $EnvPath) + ";"
}


function Copy-File {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateScript({Test-Path -Path $_})]
        [String] $Source,

        [Parameter(Position=2, Mandatory)]
        [String] $Target
    )

    $SourceFile = [io.file]::OpenRead($Source)
    $TargetFile = [io.file]::OpenWrite($Target)
    Write-Progress -Activity "Copying file" -status "$Source -> $Target" `
        -PercentComplete 0

    try {
        [Byte[]] $Buffer = New-Object Byte[] 4096
        [Long] $Total = [Long] $Count = 0
        do {
            $Count = $SourceFile.Read($Buffer, 0, $Buffer.Length)
            $TargetFile.Write($Buffer, 0, $Count)
            $Total += $Count
            if ($Total % 1mb -eq 0) {
                Write-Progress -Activity "Copying file" -status "$Source -> $Target" `
                   -PercentComplete ([Int]($Total/$SourceFile.Length * 100))
            }
        } while ($Count -gt 0)
    }
    finally {
        $SourceFile.Dispose()
        $TargetFile.Dispose()
        Write-Progress -Activity "Copying file" -Status "Ready" -Completed
    }
}


function Get-Path {
    [CmdletBinding()]
    [OutputType([String[]])]
    [Alias()]

    Param()

    [String[]] ($Env:PATH).Split(";") | Where-Object { $_.Length -gt 1 }
}


function New-Directory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="Low")]
    [OutputType()]
    [Alias("md")]

    Param (
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { !(Test-Path -Path $_) } )]
        [Object] $Path
    )

    $Directory = New-Item -Path $Path -ItemType Directory
    Set-Location $Directory
}


function New-Link {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="Low")]
    [OutputType()]
    [Alias("ln")]

    Param (
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { !(Test-Path -Path $_) } )]
        [Object] $Path,

        [Parameter(Position=2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path $_ } )]
        [Object] $Target
    )

    New-Item -Path $Path -ItemType SymbolicLink -Value $Target
}


function New-ProxyCommand {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="None")]
    [OutputType([System.Management.Automation.FunctionInfo])]
    [Alias()]

    Param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Object] $Original,

        [Parameter(Position=2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $New
    )

    $OriginalCommand = Get-Command $Original -ErrorAction Stop
    $Metadata = [System.Management.Automation.CommandMetadata]::New($OriginalCommand)
    $ProxyCommand = [System.Management.Automation.ProxyCommand]::Create($Metadata)
    New-Item -Path function:\ -Name global:$New -Value $ProxyCommand
}


function Remove-Directory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium")]
    [OutputType()]
    [Alias("rd")]

    Param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateScript( { Test-Path -Path $_ -PathType Container } )]
        [Object] $Path,

        # Allows the removal of hidden and read-only folders.
        [Parameter()]
        [Switch] $Force
    )

    Remove-Item -Path $Path -Recurse -Force:$Force
}


<#
.Synopsis
    Recursively removes empty subfolders.
.DESCRIPTION
    Removes all subfolders within target path that contains no child items.
.EXAMPLE
    Remove-EmptyFolders * -PassThru
.EXAMPLE
    Remove-EmpryFolders -LiteralPath "C:\Path\To\Folder" -Force
.INPUTS
    System.String[]
        File system path.
.OUTPUTS
    System.IO.DirectoryInfo[]
.NOTES
    TODO:
        Implement SupportsShouldProcess
#>
Function Remove-EmptyDirectory {
    [CmdletBinding(DefaultParameterSetName = "Path", ConfirmImpact = "High")]
    [OutputType([System.IO.DirectoryInfo[]])]
    [Alias()]

    Param (
        # Path to one or more locations that will have their empty subfolders removed.
        # Accepts wyldcards. Defaults to the current folder.
        [Parameter(
            ParameterSetName = "Path", Position = 0,
            ValueFromPipeline, ValueFromPipelineByPropertyName
            )]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [Alias("Name")]
        [String[]] $Path = $PWD,

        # Path to one or more locations that will have their empty subfolders removed.
        # Literal Paths are used exactly as typed.
        [Parameter(ParameterSetName = "LiteralPath", ValueFromPipelineByPropertyName)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
        [Alias("PSPath", "FullName")]
        [String[]] $LiteralPath,

        # Allows the removal of hidden and read-only folders.
        [Parameter()]
        [Switch] $Force,

        # Function returns an array containing the removed folders.
        [Parameter()]
        [Switch] $PassThru
    )

    Begin {
        [System.IO.DirectoryInfo[]] $Result = @()
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $LiteralPath = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
            $LiteralPath = Resolve-Path -LiteralPath $LiteralPath |
            Select-Object -ExpandProperty Path
        }

        ForEach ($RootFolder in $LiteralPath) {
            Write-Verbose ("Removing empty folders from: {0}" -f $RootFolder)
            $Count = 0
            while ($true) {
                $SubFolders = Get-ChildItem -LiteralPath $RootFolder `
                    -Directory -Recurse -Force:$Force
                if (($SubFolders | Measure-Object).Count -eq $Count) { Break }
                $Count = ($SubFolders | Measure-Object).Count

                $EmptyFolders = $SubFolders |
                    Where-Object { $_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0 }

                ForEach ($Folder In $EmptyFolders) {
                    Try {
                        Remove-Item -LiteralPath $Folder.FullName -Force:$Force -ErrorAction Stop
                        $Result += $Folder
                        Write-Verbose ("Removed: {0}" -f $Folder.FullName)
                    }
                    Catch [System.IO.IOException] {
                        Write-Warning (
                            "{0}: Can't remove {1}" -f $_.CategoryInfo.Category, $Folder.FullName
                        )
                    }
                    Catch { Throw $_ }
                }
            }
        }

        if ($PassThru) {
            $Result | Sort-Object -Property FullName
        }
    }
}


function Show-ColorPalette {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param()

    $Colors = @(
        "Black", "DarkGray", "Gray", "White", "Cyan", "DarkCyan", "Blue", "DarkBlue",
        "Green", "DarkGreen", "Yellow", "DarkYellow", "Red", "DarkRed", "Magenta", "DarkMagenta"
    )
    ForEach ($Color in $Colors) {
        Write-ColoredOutput "███████████████ $Color" $Color
    }
}


function Show-Path {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param()

    foreach ($Path in (Get-Path)) {
        if (Test-Path $Path) {
            Write-Output $Path
        }
        else {
            Write-ColoredOutput "$Path" Red
        }
    }
}


function Start-Shutdown {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String] $DateTime,

        [Parameter()]
        [Switch] $Restart
    )

    $ShutdownDateTime = Get-Date -Date $DateTime
    $CurrentDateTime = Get-Date
    $ShutdownDelay = ($ShutdownDateTime - $CurrentDateTime).TotalSeconds

    if ($ShutdownDelay -lt 0) { Throw "Invalid shutdown time: $ShutdownDateTime" }

    for ( $i = 1; $i -le $ShutdownDelay; $i++ ) {
        Write-Progress -Activity "Waiting for shutdown at: $ShutdownDateTime" `
            -SecondsRemaining ($ShutdownDelay - $i) `
            -PercentComplete (100 * $i / $ShutdownDelay) `
            -Status "Waiting"
        Start-Sleep -Seconds 1
    }

    Write-Progress -Activity "Waiting for shutdown time: $ShutdownDateTime" -Complete

    if ($Restart) { Restart-Computer -Force }
    else {Stop-Computer -Force}

}


<#
.Synopsis
    Test for Administrator privileges.
.DESCRIPTION
    Returns true if the current shell has Administrator privileges.
.EXAMPLE
    if (Test-Administrator) { Write-Out "I'm an admin!" }
.INPUTS
    None
.OUTPUTS
    System.Boolean
#>
function Test-Administrator {
    [CmdletBinding()]
    [OutputType([Boolean])]
    [Alias()]

    Param()

    Process {
        if (
            (
                [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
        ) {
            Write-Verbose "Current shell has administrator privileges."
            $True
        }
        else {
            Write-Verbose "Current shell doesn't have administrator privileges."
            $False
        }
    }
}


<#
.Synopsis
    Quickly replace text in files.
.DESCRIPTION
    Search files for instinces and replace text in files.
.EXAMPLE
    Update-TextFile -Path text.txt -Original "\t" -Substitute "    "
.INPUTS
    System.String[]
.OUTPUTS
    None
.NOTES
    TODO:
        Implement SupportsShouldProcess
#>
function Update-TextFile {
    [CmdletBinding(DefaultParameterSetName = "Path")]
    [OutputType()]
    [Alias()]

    Param (
        # Files to replace text into. Accepts wyldcards.
        [Parameter(
            ParameterSetName = "Path", Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName
        )]
        [ValidateScript({Test-Path -Path $_ })]
        [Alias("Name")]
        [String[]] $Path,

        # Files to replace text into. Literal Paths are used exactly as typed.
        [Parameter(
            ParameterSetName = "LiteralPath",
            Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName
        )]
        [ValidateScript({Test-Path -LiteralPath $_ })]
        [Alias("PSPath", "FullName")]
        [String[]] $LiteralPath,

        # Original text to be replaced. (Regex)
        [Parameter(Position = 1, Mandatory)]
        [Alias("Old")]
        [String] $Original,

        # Subtitute text that replaces the original. (Regex)
        [Parameter(Position = 2, Mandatory)]
        [Alias("New")]
        [String] $Substitute
    )

    Process {
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $LiteralPath = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
            $LiteralPath = Resolve-Path -LiteralPath $LiteralPath |
                Select-Object -ExpandProperty Path
        }

        ForEach ($File in $LiteralPath) {
            $OldContent = Get-Content -LiteralPath $File -Encoding UTF8
            $NewContent = $OldContent -replace $Original, $Substitute
            if ($NewContent -eq $OldContent) {
                Write-Verbose ("{0} unchanged." -f $File)
            }
            else {
                Set-Content -LiteralPath $File -Value $NewContent -Encoding "UTF8"
                Write-Verbose ("{0} updated." -f $File)
            }
        }

    }

}


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

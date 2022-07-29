<#
.SYNOPSIS
    My general-use functions.

.NOTES
    Version:        3.3.6
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2022-07-16
    License:        MIT

    TODO:
    - ValueFromPipeline
    - Input Validation
    - LitteralPath
    - ShouldProcess
    - ShouldContinue ?
    - Write-Verbose
    - Docstrings!
    - https://github.com/PowerShellOrg/Plaster

#>

Set-StrictMode -Version Latest

$DirSep = [IO.Path]::DirectorySeparatorChar
$PathSep = [IO.Path]::PathSeparator

Push-Location -Path $Null -StackName LocationStack


function Add-EnvPath {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([String[]])]
    Param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [String[]] $Path,

        [Parameter()] [Switch] $First,

        [Parameter()] [Switch] $PassThru
    )

    begin {
        [String[]] $newPath = Get-EnvPath
    }

    process {
        [String[]] $newItem = (Resolve-Path -Path $Path).Path.TrimEnd($DirSep)

        if ($First) {
            $newPath = $newItem + $newPath
        }
        else {
            $newPath += $newItem
        }
    }

    end {
        $newPath = Select-Object -InputObject $newPath -Unique
        if ($PSCmdlet.ShouldProcess('Env:PATH')) {
            $Env:PATH = Join-String -InputObject $newPath -Separator $PathSep
            if ($PassThru) { Get-EnvPath }
        }
    }
}


function Copy-File {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([IO.FileInfo])]
    Param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [Alias('Path')]
        [String] $Source,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Target,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $sourcePath = (Get-Item -Path $Source).FullName
        $targetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
        if (Test-Path -Path $targetPath -PathType Container) {
            $targetPath = Join-Path -Path $targetPath -ChildPath (Split-Path -Path $sourcePath -Leaf)
        }

        if ((Test-Path -Path $targetPath) -and -not $Force) {
            throw "Target already exists: $targetPath"
        }

        if (!($PSCmdlet.ShouldProcess($targetPath))) { return }

        Write-Verbose -Message "Copying: $sourcePath -> $targetPath"
        $progressArgs = @{
            Activity = 'Copying file'
            Status = Split-Path -Path $targetPath -Leaf
        }
        Write-Progress @progressArgs -PercentComplete 0

        try {
            $sourceFile = [IO.File]::OpenRead($sourcePath)
            $targetFile = [IO.File]::OpenWrite($targetPath)

            $buffer = [Byte[]]::New(4096)
            [Long] $total = [Long] $count = 0
            do {
                $count = $sourceFile.Read($buffer, 0, $buffer.Length)
                $targetFile.Write($buffer, 0, $count)
                $total += $count
                if ($total % 1mb -eq 0) {
                    Write-Progress @progressArgs -PercentComplete ([Int] ($total / $sourceFile.Length * 100))
                }
            } while ($count -gt 0)
            Write-Verbose -Message 'Copy done'
            Write-Progress @progressArgs -Status 'Done' -Completed
            if ($PassThru) { Get-Item -Path $targetPath }
        }
        catch {
            Remove-Item -Path $targetPath -ErrorAction Ignore
            Write-Verbose -Message 'Copy failed'
            Write-Progress @progressArgs -Status 'Failed'
            throw $_
        }
        finally {
            $sourceFile.Dispose()
            $targetFile.Dispose()
        }
    }
}

function Get-EnvPath {
    [CmdletBinding()]
    [OutputType([String[]])]
    Param()

    process {
        ($Env:PATH).Split($PathSep).Where({ $_.Length -gt 1 }).Trim().TrimEnd($DirSep)
    }
}


function Move-File {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([IO.FileInfo])]
    Param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [Alias('Path')]
        [String] $Source,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Target,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $sourceFile = Get-Item -Path $Source
        $targetFile = Copy-File -Source $sourceFile -Target $Target -Force:$Force -PassThru
        if ((Get-FileHash -Path $sourceFile).Hash -eq (Get-FileHash -Path $targetFile).Hash) {
            Write-Verbose -Message 'Copy successful, removing source file'
            Remove-Item -Path $sourceFile -Force:$Force
            if ($PassThru) { Get-Item -Path $targetFile }
        }
        else {
            throw "Failed to copy '$Source' to '$Target'"
        }
    }
}


function New-Directory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([IO.DirectoryInfo])]
    [Alias('md')]
    Param (
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { !(Test-Path -Path $_) } )]
        [String] $Path,

        [Parameter()] [Switch] $Go,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $directory = New-Item -Path $Path -ItemType Directory
        if ($Go) { Update-Location -Path $directory }
        if ($PassThru) { $directory }
    }
}


function New-Link {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([IO.DirectoryInfo])]
    [Alias('ln')]
    Param (
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { !(Test-Path -Path $_) } )]
        [Alias('Source')]
        [Object] $Path,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path $_ } )]
        [Alias('Value')]
        [Object] $Target,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $linkPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $targetPath = Resolve-Path $Target
        $link = New-Item -Path $linkPath -ItemType SymbolicLink -Value $targetPath
        if ($PassThru) { $link }
    }
}


function New-ProxyCommand {
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    [OutputType([Management.Automation.FunctionInfo])]
    Param(
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Object] $Value,

        [Parameter()] [Hashtable] $Default = @{},

        [Parameter()] [String] $Alias = '',

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $originalCommand = Get-Command -Name $Value -ErrorAction Stop
        $metadata = [Management.Automation.CommandMetadata]::New($originalCommand)
        $proxyCommand = [Management.Automation.ProxyCommand]::Create($metadata)
        $newCommand = New-SimpleFunction -Name $Name -Value $proxyCommand -Force:$Force -Alias:$Alias -PassThru

        if ($Null -ne $newCommand) {
            foreach ($key in $Default.Keys) {
                $Local:ErrorActionPreference = 'Ignore'
                $Global:PSDefaultParameterValues.Add("$Name`:$key", $Default[$key])
            }
        }

        if ($PassThru) { $newCommand }
    }
}


function New-SimpleFunction {
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    [OutputType([Management.Automation.FunctionInfo])]
    Param(
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [Object] $Value,

        [Parameter()] [String] $Alias = '',

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $newFunction = Get-Item -Path Function:$Name -ErrorAction Ignore
        if ($Null -eq $newFunction -or $Force) {
            $newItemArgs = @{
                Path = 'Function:'
                Name = "Global:$Name"
                Value = $Value
                Force = $Force
            }
            $newFunction = New-Item @newItemArgs
        }

        if ($Alias -and $Null -ne $NewFunction) {
            Set-Alias -Name $Alias -Value $newFunction -Force:$Force -Scope Global
        }

        if ($PassThru) { $newFunction }
    }
}


Function Remove-EmptyDirectory {
    <#
    .SYNOPSIS
        Recursively removes empty subfolders.
    .DESCRIPTION
        Removes all subfolders within target path that contains no child items.
    .EXAMPLE
        Remove-EmptyFolders * -PassThru
    .EXAMPLE
        Remove-EmpryFolders -LiteralPath "C:\Path\To\folder" -Force
    .INPUTS
        String[]
            File system path.
    .OUTPUTS
        IO.DirectoryInfo[]
    #>

    [CmdletBinding(DefaultParameterSetName = 'Path', ConfirmImpact = 'High', SupportsShouldProcess)]
    [OutputType([IO.DirectoryInfo[]])]
    Param (
        # Path to one or more locations that will have their empty subfolders removed.
        # Accepts wyldcards. Defaults to the current folder.
        [Parameter(ParameterSetName = 'Path', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [Alias('Name')]
        [String[]] $Path = $PWD,

        # Path to one or more locations that will have their empty subfolders removed.
        # Literal Paths are used exactly as typed.
        [Parameter(ParameterSetName = 'LiteralPath', ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [Alias('PSPath', 'FullName')]
        [String[]] $LiteralPath,

        # Allows the removal of hidden and read-only folders.
        [Parameter()] [Switch] $Force,

        # Function returns an array containing the removed folders.
        [Parameter()] [Switch] $PassThru
    )

    begin {
        $getFoldersArgs = @{
            Directory = $True
            Recurse = $True
            Force = $Force
        }
        [IO.DirectoryInfo[]] $result = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $targetFolders = (Resolve-Path -Path $Path).Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $targetFolders = (Resolve-Path -LiteralPath $LiteralPath).Path
        }

        foreach ($targetFolder in $targetFolders) {
            Write-Verbose -Message "Removing empty folders from: $targetFolder"
            $count = 0
            while ($True) {
                [IO.DirectoryInfo[]] $subFolders = Get-ChildItem -LiteralPath $targetFolder @getFoldersArgs
                $newCount = $subFolders.Length
                if ($newCount -eq $count) { Break }
                $count = $newCount

                $emptyFolders = $subFolders.Where({
                        $_.GetFiles().count -eq 0 -and $_.GetDirectories().count -eq 0
                    })

                foreach ($folder in $emptyFolders) {
                    try {
                        Remove-Item -LiteralPath $folder.FullName -Force:$Force -ErrorAction Stop
                        Write-Verbose -Message "Removed: $($folder.FullName)"
                        $result += $folder
                    }
                    catch [IO.IOException] {
                        Write-Warning -Message "$($_.CategoryInfo.Category): Can't remove $($folder.FullName)"
                    }
                    catch { throw $_ }
                }
            }
        }

    }

    end {
        if ($PassThru) { Sort-Object -InputObject $result -Property FullName }
    }
}


function Show-ColorPalette {
    [CmdletBinding()]
    [OutputType()]
    Param()

    process {
        @(
            'Black', 'DarkGray', 'Gray', 'White', 'Cyan', 'DarkCyan', 'Blue', 'DarkBlue',
            'Green', 'DarkGreen', 'Yellow', 'DarkYellow', 'Red', 'DarkRed', 'Magenta', 'DarkMagenta'
        ).ForEach({ Write-Color -Text "████ ★✓⚑♥ ████  $_" -Color $_ })
    }
}


function Show-EnvPath {
    [CmdletBinding()]
    [OutputType([String[]])]
    Param(
        [Parameter()] [Switch] $PassThru
    )

    process {
        [String[]] $result = @()
        foreach ($folder in (Get-EnvPath)) {
            if (Test-Path -Path $folder) {
                $folderItem = (Get-Item -Path $folder).FullName
                if ($result -contains $folderItem) {
                    Write-Color -Text $folderItem -Color Yellow
                }
                else {
                    Write-Color -Text $folderItem -Color Green
                    $result += $folderItem
                }
            }
            else {
                Write-Color -Text $folder -Color Red
            }
        }
        if ($PassThru) { $result }
    }
}


function Start-Shutdown {
    <#
    .SYNOPSIS
        Shutdowns the computer after a delay.
    .DESCRIPTION
        Will shutdown or restart the computer at the chosen time, or after a delay.
    .EXAMPLE
        Start-Shutdown "18:30"
    .EXAMPLE
        Start-Shutdown -DateTime "2022-06-18 18:30" -Restart
    .EXAMPLE
        Start-Shutdown -Seconds 30
    .EXAMPLE
        Start-Shutdown -Hours 2 -Minutes 30
    .INPUTS
        None
    .OUTPUTS
        None
    #>

    [CmdletBinding(DefaultParameterSetName = 'DateTime', ConfirmImpact = 'Medium', SupportsShouldProcess)]
    [OutputType()]
    Param(
        # Date and/or time, in the future at which to shutdown.
        [Parameter(Position = 1, Mandatory, ParameterSetName = 'DateTime')]
        [ValidateNotNullOrEmpty()]
        [DateTime] $DateTime,

        # Number of seconds to wait before the shutdown.
        [Parameter(ParameterSetName = 'Delay')]
        [ValidateNotNullOrEmpty()]
        [Double] $Seconds,

        # Number of minutes to wait before the shutdown.
        [Parameter(ParameterSetName = 'Delay')]
        [ValidateNotNullOrEmpty()]
        [Double] $Minutes,

        # Number of hours to wait before the shutdown.
        [Parameter(ParameterSetName = 'Delay')]
        [ValidateNotNullOrEmpty()]
        [Double] $Hours,

        # If true, will restart the computer after the shutdown.
        [Parameter()] [Switch] $Restart
    )

    process {
        if ($PsCmdlet.ParameterSetName -eq 'DateTime') {
            $total = ($DateTime - (Get-Date)).TotalSeconds
            if ($remaining -le 0) {
                throw "Shutdown time '$DateTime' must be in the future."
            }
        }
        else {
            $total = ($Hours * 60 + $Minutes) * 60 + $Seconds
            $DateTime = (Get-Date).AddSeconds($total)
            if ($total -lt 0) {
                throw "Delay '$Hours h $Minutes min $Seconds s' must be in the future."
            }
        }

        do {
            Start-Sleep -Seconds 1
            $remaining = [Math]::Max(0, ($DateTime - (Get-Date)).TotalSeconds)
            $progressArgs = @{
                Activity = "Shutdown at $DateTime "
                Status = 'Waiting...'
                SecondsRemaining = $remaining
                PercentComplete = 100 * $remaining / $total
            }
            Write-Progress @progressArgs
        } while ( $remaining -gt 0 )

        Write-Progress -Activity "Shutdown at $DateTime " -Complete
        if ($Restart) {
            Restart-Computer -Force
        }
        else {
            Stop-Computer -Force
        }
    }
}


function Test-Administrator {
    <#
    .SYNOPSIS
        Test for Administrator privileges.
    .DESCRIPTION
        Returns true if the current shell has Administrator privileges.
    .EXAMPLE
        if (Test-Administrator) { Write-Out "I'm an admin!" }
    .INPUTS
        None
    .OUTPUTS
        Boolean
    #>

    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    process {
        if ($IsWindows) {
            $user = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            $isAdmin = $user.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        }
        else {
            $isAdmin = (whoami) -eq 'root'
        }
        if ($isAdmin) {
            Write-Verbose -Message 'Current process has administrator privileges.'
            $True
        }
        else {
            Write-Verbose -Message "Current process doesn't have administrator privileges."
            $False
        }
    }
}


function Test-Command {
    <#
    .SYNOPSIS
        Test for the availability of a command.
    .DESCRIPTION
        Returns true if the command is found by the Get-Command cmdlet.
    .EXAMPLE
        if (Test-Command "Write-Out") { Write-Out "I exist!" }
    .INPUTS
        String
    .OUTPUTS
        Boolean
    #>

    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [Parameter(Position = 1, Mandatory)]
        [String] $Name
    )

    process {
        [Boolean] (Get-Command -Name $Name -ErrorAction Ignore)
    }

}


function Update-Location {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'No system state change.'
    )]
    [CmdletBinding()]
    [OutputType()]
    [Alias('cd')]
    Param(
        [Parameter(Position = 1, ValueFromPipeline)]
        [Object] $Path,

        [Parameter()] [Switch] $Follow
    )

    process {
        if ($Null -eq $Path) {
            Pop-Location -StackName LocationStack
        }
        elseif ($Follow) {
            $linkTarget = (Get-Item -Path $Path).LinkTarget ?? $Path
            Push-Location -Path $linkTarget -StackName LocationStack
        }
        else {
            Push-Location -Path $Path -StackName LocationStack
        }
    }
}


function Update-TextFile {
    <#
    .SYNOPSIS
        Quickly replace text in files.
    .DESCRIPTION
        Search files for instinces and replace text in files.
    .EXAMPLE
        Update-TextFile -Path *.txt -Original "\t" -Substitute "    "
    .INPUTS
        String[]
    .OUTPUTS
        None
    #>

    [CmdletBinding(DefaultParameterSetName = 'Path', ConfirmImpact = 'Medium', SupportsShouldProcess)]
    [OutputType([String[]])]
    Param (
        # Files to replace text into. Accepts wyldcards.
        [Parameter(ParameterSetName = 'Path', Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateScript({ Test-Path -Path $_ })]
        [Alias('Name')]
        [String[]] $Path,

        # Files to replace text into. Literal Paths are used exactly as typed.
        [Parameter(ParameterSetName = 'LiteralPath', Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ })]
        [Alias('PSPath', 'FullName')]
        [String[]] $LiteralPath,

        # Original text to be replaced. (Regex)
        [Parameter(Position = 2, Mandatory)]
        [Alias('Old')]
        [String] $Original,

        # Subtitute text that replaces the original. (Regex)
        [Parameter(Position = 3, Mandatory)]
        [Alias('New')]
        [String] $Substitute,

        # If true, returns the source file path.
        [Parameter()] [Switch] $PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $sourcePath = Resolve-Path -Path $Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $sourcePath = Resolve-Path -LiteralPath $LiteralPath
        }
        $sourcePath = $sourcePath.Path

        foreach ($file in $sourcePath) {
            $oldContent = Get-Content -LiteralPath $file -Encoding UTF8
            $newContent = $oldContent -replace $Original, $Substitute
            if ($newContent -eq $oldContent) {
                Write-Verbose -Message "$file unchanged."
            }
            else {
                Set-Content -LiteralPath $file -Value $newContent -Encoding UTF8
                Write-Verbose -Message "$file updated."
            }
        }

        if ($PassThru) { $sourcePath }
    }

}


function Write-Message {
    [CmdletBinding()]
    [OutputType()]
    Param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Text')]
        [String[]] $Message,

        [Parameter(Position = 2)]
        [ValidateSet('Normal', 'Header', 'Warning', 'Error')]
        [String] $Style = 'Normal',

        [Parameter()]
        [ValidateRange(0, 10)]
        [Int] $Pad,

        [Parameter()]
        [ValidateRange(0, 10)]
        [Int] $Tab,

        [Parameter()] [Switch] $Time,

        [Parameter()] [Switch] $NoNewline
    )

    begin {
        $format = @{
            Color = 'Gray'
            Pad = 0
            Tab = 0
        }
        switch ($Style) {
            'Header' {
                $format.Color = 'Cyan'
                $format.Pad = 1
                $format.Tab = 1
            }
            'Warning' { $format.Color = 'Yellow' }
            'Error' {
                $format.Color = 'Red'
                $format.Pad = 1
            }
        }
        if ('Pad' -in $PSBoundParameters.Keys) { $format.Pad = $Pad }
        if ('Tab' -in $PSBoundParameters.Keys) { $format.Tab = $Tab }

        $writeArgs = @{
            Color = $format.Color
            LinesAfter = $format.Pad
            LinesBefore = $format.Pad
            StartSpaces = 4 * $format.Tab
            NoNewLine = $NoNewline
            ShowTime = $Time
            DateTimeFormat = 'HH:mm:ss'
        }
    }

    process {
        Write-Color -Text $Message @writeArgs
    }
}

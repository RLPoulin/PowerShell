<#
.SYNOPSIS
    My general-use functions.

.NOTES
    Version:        4.2.0
    Author:         Robert Poulin
    Creation Date:  2016-06-09
    Updated:        2024-04-29
    License:        MIT

    TODO:
    - Reorganize modules
    - Improve types: Collections.Generic, Enum, PsCustomObject
    - ValueFromPipeline
    - Input Validation
    - LiteralPath
    - ShouldProcess
    - Write-Verbose / Write-Debug
    - Docstrings!
#>

Set-StrictMode -Version Latest

$DirSep = [IO.Path]::DirectorySeparatorChar
$PathSep = [IO.Path]::PathSeparator

enum MessageStyle {
    Normal
    Header
    Error
    Warning
    Verbose
    Debug
}

Push-Location -Path $Null -StackName LocationStack


function Add-EnvPath {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([String[]])]
    param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [String[]] $Path,

        [Parameter()] [Switch] $First,

        [Parameter()] [Switch] $PassThru
    )

    begin {
        [String[]] $pathItems = Get-EnvPath
    }

    process {
        [String[]] $newPathItems = (Resolve-Path -Path $Path).Path.TrimEnd($DirSep)

        if ($First) {
            $pathItems = $newPathItems + $pathItems
        }
        else {
            $pathItems += $newPathItems
        }
    }

    end {
        $pathItems = Select-Object -InputObject $pathItems -Unique
        if ($PSCmdlet.ShouldProcess('Env:PATH')) {
            $Env:PATH = Join-String -InputObject $pathItems -Separator $PathSep
        }
        if ($PassThru) { Get-EnvPath }
    }
}


function Copy-File {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([IO.FileInfo[]])]
    param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)] [Alias('Path')]
        [ValidateNotNullOrEmpty()] [ValidateScript({ Test-Path -Path $_ })]
        [String[]] $Source,

        [Parameter(Position = 2, Mandatory)] [Alias('Destination')]
        [ValidateNotNullOrEmpty()]
        [String] $Target,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    begin {
        $targetArg = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
        if (Test-Path -Path $targetArg -PathType Container) {
            Write-Debug "Target directory '$targetArg' exists"
        }
        elseif (Test-Path -Path $targetArg -PathType Leaf) {
            throw 'Target path must be a directory.'
        }
        else {
            Write-Debug "Creating target directory '$targetArg'"
            New-Directory -Path $targetArg -ErrorAction Stop
        }
    }

    process {
        foreach ($sourceArg in $Source) {
            $sourcePath = (Get-Item -Path $sourceArg).FullName
            $targetPath = Join-Path -Path $targetArg -ChildPath (Split-Path -Path $sourcePath -Leaf)
            Write-Debug "Source file: '$sourcePath'"
            Write-Debug "Target file: '$targetPath'"

            if ((Test-Path -Path $targetPath) -and !($Force)) {
                Write-Warning "Target already exists: $targetPath"
                continue
            }

            if (!($PSCmdlet.ShouldProcess($targetPath))) { continue }

            Write-Verbose "Copying to '$targetPath'"
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
                Write-Verbose 'Copy finished'
                $copyFinished = $true
            }
            catch {
                $copyFinished = $False
            }
            finally {
                $sourceFile.Dispose()
                $targetFile.Dispose()
            }
            if (
                $copyFinished -and
                ((Get-FileHash -Path $sourcePath).Hash -eq (Get-FileHash -Path $targetPath).Hash)
            ) {
                Write-Verbose 'File hashes match'
                Write-Progress @progressArgs -Status 'Succesful' -Completed
                if ($PassThru) { Get-Item -Path $targetPath }
            }
            else {
                Write-Warning "Copy of '$sourcePath' failed"
                Remove-Item -Path $targetPath -Force -ErrorAction Ignore
                Write-Progress @progressArgs -Status 'Failed'
                if ($PassThru) { $Null }
            }
        }
    }
}

function Get-EnvPath {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    process {
        [String[]] ($Env:PATH).Split($PathSep).Trim().TrimEnd($DirSep).Where({ $_.Length -gt 0 })
    }
}


function Move-File {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([IO.FileInfo[]])]
    param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()] [ValidateScript({ Test-Path -Path $_ })]
        [String[]] $Source,

        [Parameter(Position = 2, Mandatory)]
        [Alias('Destination')]
        [ValidateNotNullOrEmpty()]
        [String] $Target,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        foreach ($sourcePath in $Source) {
            $targetFile = (Copy-File -Source $sourcePath -Target $Target -Force:$Force -PassThru)[0]
            if ($Null -ne $targetFile) {
                Write-Verbose 'Copy successful, removing source file'
                Remove-Item -Path $sourcePath -Force:$Force
            }
            if ($PassThru) { $targetFile }
        }
    }
}


function New-Directory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([IO.DirectoryInfo[]])]
    [Alias('md')]
    param (
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()] [ValidateScript( { !(Test-Path -Path $_) } )]
        [String[]] $Path,

        [Parameter()] [Switch] $Go,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $directory = New-Item -Path $Path -ItemType Directory
        if ($PassThru) { $directory }
    }

    end {
        if ($Go) { Update-Location -Path $directory[-1] }
    }
}


function New-Link {
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    [OutputType([IO.FileSystemInfo])]
    [Alias('ln')]
    param (
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Source')]
        [Object] $Path,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()] [ValidateScript( { Test-Path -Path $_ } )]
        [Alias('Value')]
        [Object] $Target,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $targetPath = Resolve-Path $Target

        if (Test-Path -Path $Path -PathType Container) {
            $linkPath = Join-Path (Resolve-Path -Path $Path) (Split-Path $targetPath -Leaf)
        }
        else {
            $linkPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        }
        if (Test-Path -Path $linkPath) {
            $Force = $Force -or $PSCmdlet.ShouldContinue($linkPath, 'Overwrite')
            if (!($Force)) {
                throw "'$linkPath' already exists."
            }
        }

        if (!($Force -or $PSCmdlet.ShouldProcess($linkPath))) { return }
        $link = New-Item -Path $linkPath -ItemType SymbolicLink -Value $targetPath -Force:$Force

        if ($PassThru) { $link }
    }
}


function New-ProxyCommand {
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    [OutputType([Management.Automation.FunctionInfo])]
    param(
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
    param(
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

        if ($Alias -and $Null -ne $newFunction) {
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
    param (
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
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $targetFolders = (Resolve-Path -Path $Path).Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $targetFolders = (Resolve-Path -LiteralPath $LiteralPath).Path
        }

        [IO.DirectoryInfo[]] $removedFolders = @()
        foreach ($targetFolder in $targetFolders) {
            Write-Verbose "Removing empty folders from: $targetFolder"
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
                        Write-Verbose "Removed: $($folder.FullName)"
                        $removedFolders += $folder
                    }
                    catch [IO.IOException] {
                        Write-Warning -Message "$($_.CategoryInfo.Category): Can't remove $($folder.FullName)"
                    }
                    catch { throw $_ }
                }
            }
            if ($PassThru) { Sort-Object -InputObject $removedFolders -Property FullName }
        }
    }
}


function Show-ColorPalette {
    [CmdletBinding()]
    [OutputType()]
    param()

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
    param(
        [Parameter()] [Switch] $PassThru
    )

    process {
        [String[]] $pathEntries = @()
        foreach ($path in (Get-EnvPath)) {
            if (Test-Path -Path $path) {
                $pathName = (Get-Item -Path $path).FullName
                if ($pathEntries -contains $pathName) {
                    Write-Color -Text $pathName -Color Yellow
                }
                else {
                    Write-Color -Text $pathName -Color Green
                    $pathEntries += $pathName
                }
            }
            else {
                Write-Color -Text $path -Color Red
            }
        }
        if ($PassThru) { $pathEntries }
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
    param(
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
            if ($total -le 0) {
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

        $action = $Restart ? 'Reboot' : 'Shutdown'
        $timeString = ($DateTime.Date -eq (Get-Date).Date) ? $DateTime.ToLongTimeString() : $DateTime.ToString()
        $progressArgs = @{
            Activity = "$action at $timeString "
            Status = 'Waiting...'
        }

        if (!($PSCmdlet.ShouldProcess($timeString, $action))) { return }

        do {
            $remaining = [Math]::Max(0, ($DateTime - (Get-Date)).TotalSeconds)
            $progressArgs.SecondsRemaining = $remaining
            $progressArgs.PercentComplete = $remaining / $total * 100
            Write-Progress @progressArgs
            Start-Sleep -Seconds ($remaining -ge 120 ? 5 : 1)
        } while ( $remaining -gt 0 )

        Write-Progress -Activity $progressArgs.Activity -Complete
        if ($Restart) {
            Restart-Computer -Force -Confirm:$False
        }
        else {
            Stop-Computer -Force -Confirm:$False
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
    param()

    process {
        if ($IsWindows) {
            $user = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            $isAdmin = $user.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        }
        else {
            $isAdmin = (whoami) -eq 'root'
        }
        if ($isAdmin) {
            Write-Verbose 'Current process has administrator privileges.'
        }
        else {
            Write-Verbose "Current process doesn't have administrator privileges."
        }
        $isAdmin
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
    param(
        [Parameter(Position = 1, Mandatory)]
        [String] $Name
    )

    process {
        [Boolean] (Get-Command -Name $Name -ErrorAction Ignore)
    }

}


function Update-Location {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
    [OutputType()]
    [Alias('cd')]
    param(
        [Parameter(Position = 1, ValueFromPipeline)] $Path
    )

    process {
        if (!($PSCmdlet.ShouldProcess($Path))) { return }
        if ($Null -eq $Path) {
            Pop-Location -StackName LocationStack
        }
        else {
            $pushTarget = (Get-Item -Path $Path -ErrorAction Stop).LinkTarget ?? $Path
            Push-Location -Path $pushTarget -StackName LocationStack
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
    param (
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
            $sourcePath = (Resolve-Path -Path $Path).Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $sourcePath = (Resolve-Path -LiteralPath $LiteralPath).Path
        }

        foreach ($file in $sourcePath) {
            $oldContent = Get-Content -LiteralPath $file -Encoding UTF8
            $newContent = $oldContent -replace $Original, $Substitute
            if ($newContent -eq $oldContent) {
                Write-Verbose "$file unchanged."
            }
            else {
                Set-Content -LiteralPath $file -Value $newContent -Encoding UTF8
                Write-Verbose "$file updated."
            }
        }

        if ($PassThru) { $sourcePath }
    }

}


function Write-Message {
    [CmdletBinding()]
    [OutputType()]
    param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Text')]
        [String[]] $Message,

        [Parameter(Position = 2)]
        [MessageStyle] $Style = [MessageStyle]::Normal,

        [Parameter()] [String] $Prefix = $Null,

        [Parameter()] [ConsoleColor] $Color,

        [Parameter()] [ValidateRange(0, 40)] [Int] $Pad,

        [Parameter()] [ValidateRange(0, 40)] [Int] $Tab,

        [Parameter()] [Switch] $Time,

        [Parameter()] [Switch] $NoNewline,

        [Parameter()] [Switch] $PassThru,

        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference'),
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')

    )

    begin {
        $format = @{
            DateTimeFormat = 'HH:mm:ss'
            NoNewLine = $NoNewline
        }

        switch ($Style) {
            Normal {
                $prefixMessage = $Null
                $format.Color = [ConsoleColor]::Gray
            }
            Header {
                $prefixMessage = '* '
                $format.Color = [ConsoleColor]::Cyan
                $format.LinesAfter = 1
                $format.LinesBefore = 1
                $format.StartTab = 1
            }
            Error {
                $prefixMessage = 'ERROR: '
                $format.Color = [ConsoleColor]::Red
                $format.LinesAfter = 1
                $format.LinesBefore = 1
            }
            Warning {
                $prefixMessage = 'WARNING: '
                $format.Color = [ConsoleColor]::Yellow
            }
            Verbose {
                $prefixMessage = 'Verbose: '
                $format.Color = [ConsoleColor]::DarkYellow
                $format.NoConsoleOutput = ($VerbosePreference -eq 'SilentlyContinue') -and ($DebugPreference -eq 'SilentlyContinue')
            }
            Debug {
                $prefixMessage = 'Debug: '
                $format.Color = [ConsoleColor]::DarkGray
                $format.NoConsoleOutput = $DebugPreference -eq 'SilentlyContinue'
                $format.ShowTime = $True
            }
        }

        if ('Prefix' -in $PSBoundParameters.Keys) {
            $prefixMessage = $Prefix
        }
        if ('Time' -in $PSBoundParameters.Keys) {
            $format.ShowTime = $Time
        }
        if ('Color' -in $PSBoundParameters.Keys) {
            $format.Color = $Color
        }
        if ('Pad' -in $PSBoundParameters.Keys) {
            $format.LinesBefore = $Pad
            $format.LinesAfter = $Pad
        }
        if ('Tab' -in $PSBoundParameters.Keys) {
            $format.StartTab = $Tab
        }
        if ('Time' -in $PSBoundParameters.Keys) {
            $format.ShowTime = $Time
        }
    }

    process {
        foreach ($msg in $Message) {
            Write-Color -Text $prefixMessage, $msg @format
            if ($PassThru) {
                $msg
            }
        }
    }
}

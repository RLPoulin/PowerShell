<#
.SYNOPSIS
    The functions I use for sofware development.

.NOTES
    Version:        3.0.0
    Author:         Robert Poulin
    Creation Date:  2019-12-30
    Updated:        2022-07-06
    License:        MIT

    TODO:
    - Use full parameter names
    - ValueFromPipeline
    - Input Validation
    - Passthru/Outputs
    - LitteralPath
    - ShouldProcess
    - ShouldContinue ?
    - Write-Verbose
    - Split into submodules ?
    - Docstrings!

#>

Set-StrictMode -Version Latest


function Enter-Project {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Alias('proj')]
    Param (
        [Parameter(Position = 1)]
        [String] $Project = '.',

        [Parameter()]
        [Switch] $PassThru
    )

    process {
        if (Test-Path $Project) {
            Enter-Location $Project
        }
        else {
            Join-Path $Env:CodeFolder $Project | Enter-Location
        }

        if (Test-Path 'pyproject.toml') {
            Write-Message 'Python Environment:' 'Header'
            Enter-PythonEnvironment
        }
        if (Test-Path 'cargo.toml') {
            Write-Message 'Rust Environment:' 'Header'
            Show-RustSource
        }
        if (Test-Path '.git' -PathType Container) {
            Write-Message 'Git Status:' 'Header'
            git status --show-stash
        }
        if ($PassThru) { Get-GitStatus }
    }
}


function Enter-PythonEnvironment {
    [CmdletBinding()]
    [OutputType()]
    [Alias('act')]
    Param()

    process {
        Exit-VirtualEnvironment
        if (Test-Path '.venv\Scripts\Activate.ps1') {
            . '.venv\Scripts\Activate.ps1'
        }
        elseif (
            (Test-Command 'poetry') -and
            '[tool.poetry]' -in (Get-Content 'pyproject.toml' -ErrorAction SilentlyContinue)
        ) {
            . "$(poetry env info -p)\Scripts\activate.ps1"
        }
        Show-PythonSource
    }
}

function Exit-VirtualEnvironment {
    [CmdletBinding()]
    [OutputType()]
    [Alias('deact')]
    Param()

    process {
        if (Test-Path function:deactivate) {
            deactivate
        }
    }
}


function Receive-GitCommit {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Alias('pull')]
    Param(
        [Parameter()]
        [Switch] $PassThru
    )

    process {
        git pull --all --autostash
        if ($PassThru) { Get-GitStatus }
    }
}


function Send-GitCommit {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Alias('push')]
    Param(
        [Parameter()]
        [Switch] $PassThru
    )

    process {
        $status = Get-GitStatus
        if ($status.HasWorking -or $status.HasUntracked) {
            Write-Message 'Please commit any changes first:' 'Error'
            Write-Output $status.Working
            return
        }

        foreach ($Remote in (git remote)) {
            Write-Message "Pushing to $Remote" 'Header'
            git push "$Remote" --all --force-with-lease
            git push "$Remote" --tags
        }

        if ($PassThru) { Get-GitStatus }
    }
}


function Show-PythonSource {
    [CmdletBinding()]
    [OutputType()]
    [Alias('shpy')]
    Param()

    process {
        $python = (Get-Command python).Source
        $source = @(
            (Split-Path $python -Parent).Replace($Home, '~') + '\'
            Split-Path $python -Leaf
            " [$(& $python --version)]"
        )
        Write-Color $source -Color 'Green', 'DarkGreen', 'Gray'
    }
}


function Show-RustSource {
    [CmdletBinding()]
    [OutputType()]
    [Alias('shru')]
    Param()

    process {
        $rustc = (Get-Command rustc).Source
        $source = @(
            (Split-Path $rustc -Parent).Replace($Home, '~') + '\'
            Split-Path $rustc -Leaf
            " [$(& $rustc --version)]"
        )
        $toolchain = @(
            'active toolchain: '
            "$(& rustup show active-toolchain)"
        )
        Write-Color $source -Color 'Green', 'DarkGreen', 'Gray'
        Write-Color $toolchain -Color 'DarkYellow', 'Gray'
    }
}


function Update-Project {
    <#
    .SYNOPSIS
        Update all projects from remote repositories.
    .DESCRIPTION
        Will pull all remote repositories in the chosen directory and update python dependencies.
    .EXAMPLE
        Update-Projects -Path ~\MyProjects
    .INPUTS
        None
    .OUTPUTS
        None
    #>

    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    [OutputType()]
    [Alias('udp')]
    Param (
        # Location of the root folder containing the projects. Default: $Env:CodeFolder
        [Parameter(Position = 1, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [String] $Path = $Env:CodeFolder
    )

    begin {
        if (Test-Command 'poetry') {
            Remove-Item "$(poetry config cache-dir)\artifacts" -Recurse -ErrorAction SilentlyContinue
        }
    }

    process {
        Push-Location $Path -StackName 'ProjectUpdate'
        $folders = Get-ChildItem -Filter '.git' -Directory -Recurse -Depth 1 -Force

        foreach ($folder in $folders) {
            Push-Location $folder.Parent -StackName 'ProjectUpdate'
            Write-Message "Updating: $($folder.Parent.Name)..." 'Header'

            git fetch --all
            $Status = Get-GitStatus
            if ($Status.HasWorking -or $Status.AheadBy -gt 0) {
                Write-Message 'Repository is in development!' 'Error'
                Pop-Location
                Continue
            }
            Receive-GitCommit

            if (Test-Path 'pyproject.toml') {
                poetry install
            }

            Get-ChildItem -Recurse -Force "FETCH*-$($Env:COMPUTERNAME)*" | Remove-Item
            Pop-Location -StackName 'ProjectUpdate'
        }

        Pop-Location -StackName 'ProjectUpdate'
    }
}

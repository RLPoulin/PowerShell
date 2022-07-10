<#
.SYNOPSIS
    The functions I use for sofware development.

.NOTES
    Version:        3.0.1
    Author:         Robert Poulin
    Creation Date:  2019-12-30
    Updated:        2022-07-10
    License:        MIT

    TODO:
    - ValueFromPipeline
    - Input Validation
    - LitteralPath
    - ShouldProcess
    - ShouldContinue ?
    - Write-Verbose
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

        [Parameter()] [Switch] $PassThru
    )

    process {
        if (Test-Path -Path $Project) {
            Enter-Location -Path $Project
        }
        else {
            Enter-Location (Join-Path -Path $Env:CodeFolder -ChildPath $Project)
        }

        if (Test-Path -Path 'pyproject.toml') {
            Write-Message -Message 'Python Environment:' -Style 'Header'
            Enter-PythonEnvironment
        }
        if (Test-Path -Path 'cargo.toml') {
            Write-Message -Message 'Rust Environment:' -Style 'Header'
            Show-RustSource
        }
        if (Test-Path -Path '.git' -PathType Container) {
            Write-Message -Message 'Git Status:' -Style 'Header'
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
        if (Test-Path -Path '.venv\Scripts\Activate.ps1') {
            . '.venv\Scripts\Activate.ps1'
        }
        elseif (
            (Test-Command -Name 'poetry') -and
            '[tool.poetry]' -in (Get-Content -Path 'pyproject.toml' -ErrorAction SilentlyContinue)
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
        if (Test-Path -Path Function:deactivate) {
            deactivate
        }
    }
}


function Receive-GitCommit {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Alias('pull')]
    Param(
        [Parameter()] [Switch] $PassThru
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
        [Parameter()] [Switch] $All,

        [Parameter()] [Switch] $Force,

        [Parameter()] [Switch] $PassThru
    )

    process {
        $status = Get-GitStatus
        if ($status.HasWorking -or $status.HasUntracked) {
            if ($Force) {
                Write-Message -Message 'Repository has uncommited files.' -Style 'Warning'
            }
            else {
                Write-Message -Message 'Please commit any changes first:' -Style 'Error' -Pad 0
                Write-Output -InputObject $status.Working
                return
            }
        }

        if ($All) {
            foreach ($remote in (git remote)) {
                Write-Message -Message "Pushing to $remote" -Style 'Header'
                git push "$remote" --all --force-with-lease
                git push "$remote" --tags
            }
        }
        else {
            Write-Message -Message "Pushing to $($status.Upstream)" -Style 'Header'
            git push --force-with-lease
            git push --tags
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
        $python = (Get-Command -Name python).Source
        $source = @(
            (Split-Path -Path $python -Parent).Replace($Home, '~') + '\'
            Split-Path -Path $python -Leaf
            " [$(& $python --version)]"
        )
        Write-Color -Text $source -Color 'Green', 'DarkGreen', 'Gray'
    }
}


function Show-RustSource {
    [CmdletBinding()]
    [OutputType()]
    [Alias('shru')]
    Param()

    process {
        $rustc = (Get-Command -Name rustc).Source
        $source = @(
            (Split-Path -Path $rustc -Parent).Replace($Home, '~') + '\'
            Split-Path -Path $rustc -Leaf
            " [$(& $rustc --version)]"
        )
        $toolchain = @(
            'active toolchain: '
            "$(& rustup show active-toolchain)"
        )
        Write-Color -Text $source -Color 'Green', 'DarkGreen', 'Gray'
        Write-Color -Text $toolchain -Color 'DarkYellow', 'Gray'
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
        if (Test-Command -Name 'poetry') {
            Remove-Item -Path "$(poetry config cache-dir)\artifacts" -Recurse -ErrorAction SilentlyContinue
        }
    }

    process {
        Push-Location -Path $Path -StackName ProjectUpdate
        $folders = Get-ChildItem -Filter '.git' -Directory -Recurse -Depth 1 -Force

        foreach ($folder in $folders) {
            Push-Location -Path $folder.Parent -StackName ProjectUpdate
            Write-Message -Message "Updating: $($folder.Parent.Name)..." -Style 'Header'

            git fetch --all
            $Status = Get-GitStatus
            if ($Status.HasWorking -or $Status.AheadBy -gt 0) {
                Write-Message -Message 'Repository is in development!' -Style 'Error'
                Pop-Location -StackName ProjectUpdate
                Continue
            }
            Receive-GitCommit

            if (Test-Path -Path 'pyproject.toml') {
                poetry install
            }

            Get-ChildItem -Filter "FETCH*-$($Env:COMPUTERNAME)*" -Recurse -Force | Remove-Item
            Pop-Location -StackName ProjectUpdate
        }

        Pop-Location -StackName ProjectUpdate
    }
}

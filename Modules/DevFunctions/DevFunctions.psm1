<#
.Synopsis
    The functions I use for sofware development.

.NOTES
    Version:        2.7
    Author:         Robert Poulin
    Creation Date:  2019-12-30
    Updated:        2022-05-30
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest

Import-Module posh-git -NoClobber -Cmdlet Get-GitStatus
Import-Module MyFunctions -NoClobber -Cmdlet Write-ColoredOutput,Remove-Directory


# functions

function Enter-Project {
    [CmdletBinding()]
    [OutputType()]
    [Alias("proj")]

    Param (
        [Parameter(Position=1, ValueFromPipeline)]
        [String] $Project = "."
    )

    if (Test-Path $Project) {
        Set-Location $Project
    }
    else {
        Join-Path $Env:CodeFolder $Project | Set-Location -ErrorAction SilentlyContinue
    }

    Write-ColoredOutput "`n   Python Environment:`n" Magenta
    Enter-VirtualEnvironment $Project

    if (Test-Path ".git") {
        Write-ColoredOutput "`n   Git Status:`n" Magenta
        & git status --show-stash
    }
}


function Enter-VirtualEnvironment {
    [CmdletBinding()]
    [OutputType()]
    [Alias("act")]

    Param(
        [Parameter(Position=1, ValueFromPipeline)]
        [String] $Environment
    )

    if (Test-Path ".venv\Scripts\Activate.ps1") {
        & ".venv\Scripts\Activate.ps1"
    }
    elseif ((Test-Path "pyproject.toml") -and "[tool.poetry]" -in (get-content "pyproject.toml")) {
        . "$(poetry env info -p)\Scripts\activate.ps1"
    }

    Show-PythonSource
}

function Exit-VirtualEnvironment {
    [CmdletBinding()]
    [OutputType()]
    [Alias("deact")]

    Param()

    if (Test-Path function:deactivate) {
        deactivate
    }
}



function Receive-GitCommit {
    [CmdletBinding()]
    [OutputType()]
    [Alias("pull")]

    Param()

    git pull --all --autostash
}


function Send-GitCommit {
    [CmdletBinding()]
    [OutputType()]
    [Alias("push")]

    Param()

    $Status = Get-GitStatus
    if ($Status.HasWorking -or $Status.HasUntracked) {
        Write-ColoredOutput "Please commit any changes first:" -ForegroundColor Yellow
        Write-Output $Status.Working
        return
    }

    Foreach ($Remote in (Invoke-Expression "git remote")) {
        Write-ColoredOutput "`nPushing to $Remote" -ForegroundColor Magenta
        & git push "$Remote" --all --force-with-lease
        & git push "$Remote" --tags
    }
}


function Show-PythonSource {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param()

    $Python = (Get-Command python).Source
    $PyPath = (Split-Path $Python -Parent).Replace($Home, "~") + "\"
    $PyExe = Split-Path $Python -Leaf
    Write-ColoredOutput $PyPath Green -NoNewline
    Write-ColoredOutput $PyExe DarkGreen
    & $Python "-VV"
}


<#
.Synopsis
    Update all projects from remote repositories.
.DESCRIPTION
    Will pull all remote repositories in the chosen directory and update python
    dependencies.
.EXAMPLE
    Update-Projects -Path ~\MyProjects
.INPUTS
    None
.OUTPUTS
    None
#>
function Update-Projects {
    [CmdletBinding()]
    [OutputType()]
    [Alias("udp")]

    Param (
        # Location of the root folder containing the projects. Default: $Env:CodeFolder
        [Parameter(Position=1)]
        [String] $Path = $Env:CodeFolder
    )

    Begin {
        $Color = "Cyan"
        $ErrorColor = "Red"
        Push-Location $Path
        $ProjectFolders = Get-ChildItem -Recurse -Depth 1 -Force -Directory ".git"
        Remove-Directory "$(poetry config cache-dir)\artifacts" -ErrorAction SilentlyContinue
    }

    Process {
        ForEach ($Folder in $ProjectFolders) {
            Push-Location $Folder.Parent
            Write-ColoredOutput "`nUpdating: $($Folder.Parent.Name)...`n" $Color

            . git fetch --all
            $Status = Get-GitStatus
            if ($Status.HasWorking -or $Status.AheadBy -gt 0)  {
                Write-ColoredOutput "`nRepository is in development!`n" $ErrorColor
                Continue
            }
            Receive-GitCommit

            if (Test-Path "pyproject.toml") {
                Write-ColoredOutput "`nUpdating python dependencies...`n" $Color
                . poetry install
            }

            Pop-Location
        }
    }

    End {
        Get-ChildItem -Recurse -Force "FETCH*-$($Env:COMPUTERNAME)*" | Remove-Item
        Pop-Location
    }
}



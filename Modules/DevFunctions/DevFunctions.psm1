<#
.Synopsis
    The functions I use for sofware development.

.NOTES
    Version:        2.3
    Author:         Robert Poulin
    Creation Date:  2019-12-30
    Updated:        2021-11-11
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest

Import-Module posh-git -NoClobber -Cmdlet Get-GitStatus
Import-Module MyFunctions -NoClobber -Cmdlet Write-ColoredOutput


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


function Send-GitCommit {
    [CmdletBinding()]
    [OutputType()]
    [Alias("gitp")]

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

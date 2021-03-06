<#
.Synopsis
    The functions I use for sofware development.

.NOTES
    Version:        1.1
    Author:         Robert Poulin
    Creation Date:  2019-12-30
    Updated:        2020-03-17
    License:        MIT

#>

#Requires -Version 5

Set-StrictMode -Version Latest

Import-Module posh-git -NoClobber -Cmdlet Get-GitStatus
Import-Module Get-ChildItemColor -NoClobber
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
        Join-Path $CodeFolder $Project | Set-Location -ErrorAction SilentlyContinue
    }

    Write-ColoredOutput "`n   Python Environment:`n" Blue
    Enter-VirtualEnvironment $Project

    if (Test-Path ".git") {
        Write-ColoredOutput "`n   Git Status:`n" Blue
        Show-GitStatus
    }
    Get-ChildItemColorFormatWide
}


function Enter-VirtualEnvironment {
    [CmdletBinding()]
    [OutputType()]
    [Alias("venv")]

    Param(
        [Parameter(Position=1, ValueFromPipeline)]
        [String] $Environment
    )

    if (Test-Path ".venv\Scripts\Activate.ps1") {
        & ".venv\Scripts\Activate.ps1"
    }
    else {
        Set-PyEnv $Environment
    }
    Show-PythonSource
}


function Get-VirtualEnvName {
    [CmdletBinding()]
    [OutputType([String])]
    [Alias()]

    Param()

    $Python = (Get-Command python).Source.Split("\")
    if ($Python -contains "pyenv") {
        & pyenv global
    }
    elseif ($Python -contains ".venv") {
        $Python[-4]
    }
    elseif ($Python -contains "miniconda3") {
        $Env:CONDA_DEFAULT_ENV
    }
    elseif ($Python -contains "scoop") {
        "Scoop"
    }
    else {
        "???"
    }
}


function Invoke-Pip() { & python -m pip $Args }


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


function Set-PyEnv {
    [CmdletBinding()]
    [OutputType()]
    [Alias()]

    Param([String] $Version)

    $Versions = (& pyenv versions) | ForEach-Object { $_.Trim().Split()[0] }
    if ($Versions -contains $Version) {
        & pyenv global $Version
    }
    & pyenv rehash
}


function Show-GitStatus {
    [CmdletBinding()]
    [OutputType()]
    [Alias("gits")]

    Param()

    & git status --show-stash
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


function Submit-GitCommit {
    [CmdletBinding()]
    [OutputType()]
    [Alias("gitc")]

    Param([String] $Message)

    & git commit --all --message="$Message"
}


function Test-VirtualEnv {
    [CmdletBinding()]
    [OutputType([Boolean])]
    [Alias()]

    Param()

    [Boolean] (Get-Command python -ErrorAction SilentlyContinue)
}


# Aliases

Set-Alias -Name pip -Value Invoke-Pip -Option AllScope -Scope Global

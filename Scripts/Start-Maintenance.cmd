@REM Batch script to run Start-Maintenance.ps1
@ECHO off

IF [%~1]==[] (SET DELAY=10) ELSE (SET DELAY=%~1)

ECHO.
ECHO Updating Scoop
ECHO.
CALL scoop update scoop

ECHO.
ECHO Updating Powershell
ECHO.
CALL scoop update pwsh

ECHO.
ECHO Starting Maintenance
ECHO.
pwsh -NoProfile -NoLogo -File %~dp0\Start-Maintenance.ps1 -ShutdownDelay %DELAY%

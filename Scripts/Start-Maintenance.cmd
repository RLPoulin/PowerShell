@echo off

scoop update scoop
scoop update pwsh
echo.

pwsh -NoProfile -NoLogo -File %~dp0\Start-Maintenance.ps1
echo.

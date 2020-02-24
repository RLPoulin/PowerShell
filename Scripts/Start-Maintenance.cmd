@echo off

pwsh -NoProfile -NoLogo -File %~dp0\Start-Maintenance.ps1
echo.

scoop update pwsh

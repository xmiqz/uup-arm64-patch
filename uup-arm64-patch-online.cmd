@echo off
setlocal EnableExtensions
title UUP dump ARM64 adapter - online edition

rem ================================================================
rem  Online edition: downloads the latest native ARM64 tools
rem  (wimlib / 7-Zip / aria2), then runs the patcher.
rem
rem  Layout: keep uup-arm64-patch.cmd and fetch-arm64.ps1 next to
rem  this script, inside the extracted UUP dump package.
rem ================================================================

echo UUP dump ARM64 adapter - online edition
echo This downloads the latest ARM64 tools, then patches the package.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fetch-arm64.ps1"
if errorlevel 1 (
    echo.
    echo [X] Failed to download ARM64 tools.
    echo     Check your network / proxy, or use the offline edition.
    pause
    exit /b 1
)
echo.

call "%~dp0uup-arm64-patch.cmd"

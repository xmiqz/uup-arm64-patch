@echo off
setlocal EnableExtensions EnableDelayedExpansion
title UUP dump ARM64 adapter

rem ================================================================
rem  UUP dump ARM64 adapter
rem  Replaces x86/x64 converter tools with native ARM64 builds so
rem  the UUP - ISO conversion pipeline runs at full native speed
rem  on Windows on Arm devices (Snapdragon etc.).
rem
rem  Safe to re-run. Originals are backed up once:
rem    - files\uup-converter-wimlib.7z  ->  *.7z.bak
rem    - bin\ tools                     ->  bin_backup_x86\
rem ================================================================

set "SCRIPTDIR=%~dp0"

rem ---- locate target package (layout B: tool files sit in package root) ----
set "TARGET=%SCRIPTDIR%"
call :CHECKTARGET || (
    rem ---- layout A: whole tool folder was copied INTO the package ----
    for %%i in ("%SCRIPTDIR%..") do set "TARGET=%%~fi\"
)

echo Target : %TARGET%
echo.

call :CHECKTARGET || (
    echo [X] This is not an extracted UUP dump package.
    echo     Expected: uup_download_windows.cmd / convert-UUP.cmd /
    echo               files\uup-converter-wimlib.7z
    echo.
    echo Usage: copy the whole uup-arm64-patch folder into the
    echo extracted UUP dump package, then run this script.
    pause
    exit /b 1
)

set "RES=%SCRIPTDIR%arm64"
if not exist "%RES%\wimlib-imagex.exe" (
    echo [X] Required resource missing: arm64\wimlib-imagex.exe
    echo     Keep the arm64 folder next to this script.
    pause
    exit /b 1
)
if not exist "%RES%\libwim-15.dll" (
    echo [X] Required resource missing: arm64\libwim-15.dll
    pause
    exit /b 1
)

rem ---- is a conversion currently running? ----
set "WIMRUN="
tasklist /FI "IMAGENAME eq wimlib-imagex.exe" 2>nul | find /I "wimlib-imagex.exe" >nul && set "WIMRUN=1"

rem ---- locate a working 7z tool (x86 build is fine for patching) ----
set "SZ="
if exist "%TARGET%files\7zr.exe" set "SZ=%TARGET%files\7zr.exe"
if not defined SZ if exist "%TARGET%bin\7z.exe" set "SZ=%TARGET%bin\7z.exe"

echo ============ Step 1: patch converter archive ============
if exist "%TARGET%files\uup-converter-wimlib.7z" (
    if defined SZ (
        call :PATCHARCHIVE
    ) else (
        echo [!] No 7z tool found - skipped archive patch.
        echo     Run once after files\7zr.exe exists ^(any uup download does this^).
    )
) else (
    echo [!] files\uup-converter-wimlib.7z not found - skipped.
)
echo.

echo ============ Step 2: patch extracted bin\ tools ============
if exist "%TARGET%bin\wimlib-imagex.exe" (
    if defined WIMRUN (
        echo [!] wimlib-imagex.exe is running right now.
        echo     Live bin replacement SKIPPED to avoid corrupting the
        echo     current conversion. Re-run this tool after it finishes.
    ) else (
        call :PATCHBIN
    )
) else (
    echo [i] bin\ not extracted yet - archive patch above is enough;
    echo     the converter will extract native ARM64 tools itself.
)
echo.

echo ============ Step 3: optional aria2c ============
if exist "%RES%\aria2c.exe" (
    call :PATCHARIA2
) else (
    echo [i] arm64\aria2c.exe not provided - keeping stock downloader.
)
echo.

echo ============ Verification ============
if exist "%TARGET%bin\bin64\wimlib-imagex.exe" (
    "%TARGET%bin\bin64\wimlib-imagex.exe" --version 2>nul
    if exist "%TARGET%bin\wimlib-imagex.exe" (
        for /f "delims=" %%r in ('powershell -NoProfile -Command "$f=[IO.File]::ReadAllBytes('%TARGET%bin\wimlib-imagex.exe'); $pe=[BitConverter]::ToInt32($f,0x3C); '{0:x4}' -f [BitConverter]::ToUInt16($f,$pe+4)"') do set "MACH=%%r"
        if /i "!MACH!"=="aa64" (echo [OK] bin\wimlib-imagex.exe is native ARM64) else (echo [!] bin\wimlib-imagex.exe machine type: !MACH! ^(expected aa64^))
    )
) else (
    echo [i] Verify after extraction / next run.
)
if defined SZ if exist "%TARGET%files\uup-converter-wimlib.7z" (
    "%SZ%" t "%TARGET%files\uup-converter-wimlib.7z" >nul 2>&1 && echo [OK] converter archive integrity verified
)
echo.
echo ==================== Done ====================
echo wimlib is now native ARM64 wherever it matters.
echo Remaining x86 tools ^(PSFExtractor, SxSExpand, offlinereg^) are
echo light-load and stay emulated - impact is minimal.
echo.
echo Optional: drop 7z.exe+7z.dll, oscdimg.exe, aria2c.exe ^(ARM64^)
echo into the arm64\ folder and re-run to inject them too.
pause
exit /b 0

rem ================================================================
:CHECKTARGET
if exist "%TARGET%uup_download_windows.cmd" exit /b 0
if exist "%TARGET%convert-UUP.cmd" exit /b 0
if exist "%TARGET%files\uup-converter-wimlib.7z" exit /b 0
exit /b 1

rem ================================================================
:PATCHARCHIVE
if not exist "%TARGET%files\uup-converter-wimlib.7z.bak" (
    copy /Y "%TARGET%files\uup-converter-wimlib.7z" "%TARGET%files\uup-converter-wimlib.7z.bak" >nul
    echo [i] Original archive backed up to uup-converter-wimlib.7z.bak
)
rem -- stop uup_download_windows.cmd from re-downloading the stock archive
rem    (patched archive has a different sha256, aria2 would overwrite it)
if exist "%TARGET%files\converter_windows" (
    findstr /C:"uup-converter-wimlib" "%TARGET%files\converter_windows" >nul 2>&1 && (
        if not exist "%TARGET%files\converter_windows.bak" copy /Y "%TARGET%files\converter_windows" "%TARGET%files\converter_windows.bak" >nul
        powershell -NoProfile -Command "$p='%TARGET%files\converter_windows'; (Get-Content -LiteralPath $p -Raw) -replace '(?m)^https://\S*uup-converter-wimlib\S*\.7z\s*$\r?\n\s*out=uup-converter-wimlib\.7z\s*$\r?\n\s*checksum=[^\r\n]*\s*$','' | Set-Content -LiteralPath $p -NoNewline" >nul 2>&1
        findstr /C:"uup-converter-wimlib" "%TARGET%files\converter_windows" >nul 2>&1 && (
            echo [!] could not clean converter_windows - re-running the
            echo     download script may restore stock x86 tools
        ) || echo [OK] converter_windows: stock archive download disabled
    )
)
set "TMPD=%TARGET%\_a64tmp"
if exist "!TMPD!" rd /s /q "!TMPD!"
mkdir "!TMPD!\bin\bin64" 2>nul
copy /Y "%RES%\wimlib-imagex.exe" "!TMPD!\bin\" >nul
copy /Y "%RES%\libwim-15.dll" "!TMPD!\bin\" >nul
copy /Y "%RES%\wimlib-imagex.exe" "!TMPD!\bin\bin64\" >nul
copy /Y "%RES%\libwim-15.dll" "!TMPD!\bin\bin64\" >nul
rem optional native tools get injected into the archive as well
if exist "%RES%\7z.exe"  copy /Y "%RES%\7z.exe"  "!TMPD!\bin\" >nul
if exist "%RES%\7z.dll"  copy /Y "%RES%\7z.dll"  "!TMPD!\bin\" >nul
if exist "%RES%\oscdimg.exe" copy /Y "%RES%\oscdimg.exe" "!TMPD!\bin\cdimage.exe" >nul
pushd "!TMPD!"
"%SZ%" a -t7z -y "%TARGET%files\uup-converter-wimlib.7z" bin >nul 2>&1
set "RC=!ERRORLEVEL!"
popd
rd /s /q "!TMPD!" 2>nul
if !RC! equ 0 (
    echo [OK] converter archive now carries native ARM64 wimlib
) else (
    echo [X] failed to update converter archive ^(error !RC!^)
    if exist "%TARGET%files\uup-converter-wimlib.7z.bak" if not exist "%TARGET%files\uup-converter-wimlib.7z" copy /Y "%TARGET%files\uup-converter-wimlib.7z.bak" "%TARGET%files\uup-converter-wimlib.7z" >nul
)
exit /b 0

rem ================================================================
:PATCHBIN
if not exist "%TARGET%bin_backup_x86\wimlib-imagex.exe" (
    mkdir "%TARGET%bin_backup_x86\bin64" 2>nul
    copy /Y "%TARGET%bin\wimlib-imagex.exe" "%TARGET%bin_backup_x86\" >nul
    copy /Y "%TARGET%bin\libwim-15.dll"    "%TARGET%bin_backup_x86\" >nul
    copy /Y "%TARGET%bin\bin64\wimlib-imagex.exe" "%TARGET%bin_backup_x86\bin64\" >nul
    copy /Y "%TARGET%bin\bin64\libwim-15.dll"    "%TARGET%bin_backup_x86\bin64\" >nul
    echo [i] Original tools backed up to bin_backup_x86\
)
set "BINOK=1"
copy /Y "%RES%\wimlib-imagex.exe" "%TARGET%bin\" >nul 2>&1 || set "BINOK=0"
copy /Y "%RES%\libwim-15.dll"    "%TARGET%bin\" >nul 2>&1 || set "BINOK=0"
copy /Y "%RES%\wimlib-imagex.exe" "%TARGET%bin\bin64\" >nul 2>&1 || set "BINOK=0"
copy /Y "%RES%\libwim-15.dll"    "%TARGET%bin\bin64\" >nul 2>&1 || set "BINOK=0"
if exist "%RES%\7z.exe" if exist "%RES%\7z.dll" (
    copy /Y "%RES%\7z.exe" "%TARGET%bin\" >nul 2>&1 || set "BINOK=0"
    copy /Y "%RES%\7z.dll" "%TARGET%bin\" >nul 2>&1 || set "BINOK=0"
    echo [OK] native ARM64 7-Zip injected
)
if exist "%RES%\oscdimg.exe" (
    copy /Y "%RES%\oscdimg.exe" "%TARGET%bin\cdimage.exe" >nul 2>&1 || set "BINOK=0"
    echo [OK] native ARM64 oscdimg injected as cdimage.exe
)
if "!BINOK!"=="1" (
    echo [OK] live bin\ tools replaced with native ARM64 builds
) else (
    echo [X] some files were locked - re-run when no conversion is active
)
exit /b 0

rem ================================================================
:PATCHARIA2
copy /Y "%RES%\aria2c.exe" "%TARGET%files\aria2c.exe" >nul 2>&1
if errorlevel 1 (
    echo [!] could not replace files\aria2c.exe
    exit /b 0
)
echo [OK] native ARM64 aria2c installed
if exist "%TARGET%files\get_aria2.ps1" (
    powershell -NoProfile -Command "$p='%TARGET%files\get_aria2.ps1'; $h=(Get-FileHash -LiteralPath '%TARGET%files\aria2c.exe' -Algorithm SHA256).Hash.ToLower(); [IO.File]::WriteAllText($p, ((Get-Content -LiteralPath $p -Raw) -replace '[0-9a-f]{64}', $h)); Write-Output $h" > "%TEMP%\_a64hash.txt" 2>nul
    set /p NEWH=<"%TEMP%\_a64hash.txt"
    del "%TEMP%\_a64hash.txt" >nul 2>&1
    if defined NEWH (
        echo [OK] get_aria2.ps1 hash updated: !NEWH!
    ) else (
        echo [!] could not update get_aria2.ps1 - it may re-download the x86 build
    )
)
exit /b 0

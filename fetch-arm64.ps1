# fetch-arm64.ps1 - downloads latest native ARM64 tools for the UUP dump patcher
# Sources:
#   wimlib  : official wimlib.net Windows aarch64 build
#   7-Zip   : official github.com/ip7z/7zip latest release (arm64 installer SFX)
#   aria2   : community build github.com/minnyres/aria2-windows-arm64
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$res = Join-Path $PSScriptRoot 'arm64'
New-Item -ItemType Directory -Force -Path $res | Out-Null
$ProgressPreference = 'SilentlyContinue'

function Get-SevenZ {
    # find any usable 7z executable (x86 build is fine for extracting)
    $cands = @(
        (Join-Path $PSScriptRoot 'files\7zr.exe'),
        (Join-Path $PSScriptRoot '..\files\7zr.exe'),
        (Join-Path $PSScriptRoot 'bin\7z.exe'),
        (Join-Path $PSScriptRoot '..\bin\7z.exe'),
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

# ---------- wimlib ----------
if (-not (Test-Path "$res\wimlib-imagex.exe") -or -not (Test-Path "$res\libwim-15.dll")) {
    Write-Host '[1/3] Downloading wimlib 1.14.4 (official ARM64 build)...'
    $t = "$env:TEMP\wimlib-aarch64.zip"
    Invoke-WebRequest -Uri 'https://wimlib.net/downloads/wimlib-1.14.4-windows-aarch64-bin.zip' -OutFile $t -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $x = "$env:TEMP\wimlib-aarch64"
    if (Test-Path $x) { Remove-Item $x -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($t, $x)
    Copy-Item "$x\wimlib-imagex.exe" $res -Force
    Copy-Item "$x\libwim-15.dll"     $res -Force
    Write-Host '      wimlib OK'
} else {
    Write-Host '[1/3] wimlib already present'
}

# ---------- 7-Zip ----------
if (-not (Test-Path "$res\7z.exe") -or -not (Test-Path "$res\7z.dll")) {
    Write-Host '[2/3] Querying latest 7-Zip release...'
    $rel  = Invoke-RestMethod -Uri 'https://api.github.com/repos/ip7z/7zip/releases/latest'
    $ast  = $rel.assets | Where-Object { $_.name -match '^7z\d+-arm64\.exe$' } | Select-Object -First 1
    if ($ast) {
        Write-Host "      Downloading $($ast.name)..."
        $t = "$env:TEMP\$($ast.name)"
        Invoke-WebRequest -Uri $ast.browser_download_url -OutFile $t -UseBasicParsing
        $sz7 = Get-SevenZ
        if ($sz7) {
            # installer is a 7z SFX - extract just the two files we need
            & $sz7 e -y "-o$res" $t 7z.exe 7z.dll | Out-Null
            if ((Test-Path "$res\7z.exe") -and (Test-Path "$res\7z.dll")) {
                Write-Host '      7-Zip OK'
            } else {
                Write-Host '      7-Zip extraction failed'
            }
        } else {
            Write-Host '      No 7z extractor available - skipped.'
            Write-Host '      Run this once the UUP package has files\7zr.exe'
            Write-Host '      (after running its download script once).'
        }
    } else { Write-Host '      no arm64 asset found - skipped' }
} else {
    Write-Host '[2/3] 7-Zip already present'
}

# ---------- aria2 ----------
if (-not (Test-Path "$res\aria2c.exe")) {
    Write-Host '[3/3] Downloading aria2 (ARM64 community build)...'
    $rel  = Invoke-RestMethod -Uri 'https://api.github.com/repos/minnyres/aria2-windows-arm64/releases/latest'
    $ast  = $rel.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
    if ($ast) {
        $t = "$env:TEMP\aria2_arm64.zip"
        Invoke-WebRequest -Uri $ast.browser_download_url -OutFile $t -UseBasicParsing
        $x = "$env:TEMP\aria2_arm64"
        if (Test-Path $x) { Remove-Item $x -Recurse -Force }
        Expand-Archive -Path $t -DestinationPath $x -Force
        $exe = Get-ChildItem $x -Recurse -Filter aria2c.exe | Select-Object -First 1
        if ($exe) { Copy-Item $exe.FullName $res -Force; Write-Host '      aria2 OK' }
        else { Write-Host '      aria2c.exe not found in archive - skipped' }
    } else { Write-Host '      no zip asset found - skipped' }
} else {
    Write-Host '[3/3] aria2 already present'
}

Write-Host 'ARM64 resources ready.'

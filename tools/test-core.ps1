<#
.SYNOPSIS
    Builds and tests LarioCore on Windows.

.DESCRIPTION
    LarioCore is the Foundation-only domain layer, so it is the one part of
    LarioGo that compiles on the Windows development machine. The iOS app needs
    macOS + Xcode; the Vapor backend needs Linux or macOS.

    Locates a Swift toolchain in the usual install roots (including a D: install,
    used here because C: lacked the space) or honours $env:SWIFT_HOME.

.EXAMPLE
    pwsh tools/test-core.ps1
    pwsh tools/test-core.ps1 -Filter PlaceSearchTests
#>
[CmdletBinding()]
param(
    [string]$Filter,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

$candidates = @()
if ($env:SWIFT_HOME) { $candidates += $env:SWIFT_HOME }
$candidates += @(
    "D:\Swift\Toolchains",
    "$env:LOCALAPPDATA\Programs\Swift\Toolchains",
    "C:\Program Files\Swift\Toolchains"
)

$swiftBin = $null
foreach ($root in $candidates) {
    if (-not (Test-Path $root)) { continue }
    # Prefer the highest version present.
    $found = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "usr\bin" } |
        Where-Object { Test-Path (Join-Path $_ "swift.exe") } |
        Select-Object -First 1
    if ($found) { $swiftBin = $found; break }
}

if (-not $swiftBin) {
    Write-Error @"
No Swift toolchain found. Looked in:
$($candidates -join "`n")

Install with:  winget install --id Swift.Toolchain
If C: is short on space, install elsewhere and set SWIFT_HOME to the
Toolchains directory (e.g. D:\Swift\Toolchains).
"@
}

Write-Host "Using toolchain: $swiftBin" -ForegroundColor Cyan
$env:Path = "$swiftBin;$env:Path"

& (Join-Path $swiftBin "swift.exe") --version
if ($LASTEXITCODE -ne 0) { Write-Error "swift --version failed; the toolchain looks incomplete." }

$core = Join-Path (Split-Path $PSScriptRoot -Parent) "Core"
Push-Location $core
try {
    Write-Host "`n=== swift build ===" -ForegroundColor Cyan
    & swift build
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed." }

    if ($BuildOnly) { Write-Host "`nBuild OK (tests skipped)." -ForegroundColor Green; return }

    Write-Host "`n=== swift test ===" -ForegroundColor Cyan
    if ($Filter) { & swift test --filter $Filter } else { & swift test }
    if ($LASTEXITCODE -ne 0) { Write-Error "Tests failed." }

    Write-Host "`nCore build and tests passed." -ForegroundColor Green
}
finally {
    Pop-Location
}

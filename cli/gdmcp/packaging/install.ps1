[CmdletBinding()]
param(
    [string]$InstallRoot,
    [switch]$AddPath,
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ArchiveRoot = (Resolve-Path $PSScriptRoot).Path
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $env:LOCALAPPDATA "gdmcp\bin"
}

$manifestPath = Join-Path $ArchiveRoot "release-manifest.json"
$checksumsPath = Join-Path $ArchiveRoot "SHA256SUMS"
$manifest = $null

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Release manifest not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $checksumsPath)) {
    throw "Checksum file not found: $checksumsPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$executableName = [string]$manifest.executable
if ([string]::IsNullOrWhiteSpace($executableName) -or $executableName -match '[\\/]') {
    throw "Release manifest contains an invalid executable name."
}
$source = Join-Path $ArchiveRoot $executableName
$destination = Join-Path $InstallRoot $executableName

if ($Uninstall) {
    if ($DryRun) {
        Write-Host "Dry run: would remove $destination"
    } elseif (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Force
        Write-Host "Removed $destination"
    } else {
        Write-Host "Not installed: $destination"
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $source)) {
    throw "Release executable not found: $source"
}

$checksumLine = Get-Content -LiteralPath $checksumsPath | Where-Object {
    $_ -match '^\s*[0-9a-fA-F]{64}\s+\*?(.+?)\s*$'
} | Select-Object -First 1
if ($null -eq $checksumLine) {
    throw "Checksum file does not contain a valid SHA-256 entry."
}
$checksumParts = $checksumLine.Trim() -split '\s+', 2
$expectedName = $checksumParts[1].TrimStart('*')
if ($expectedName -ne $executableName) {
    throw "Checksum entry does not match manifest executable: $expectedName"
}
$expectedHash = $checksumParts[0].ToLowerInvariant()
$actualHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "SHA-256 verification failed for $source"
}

if ($DryRun) {
    Write-Host "Dry run: would install $source to $destination"
} else {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host "Installed $destination"
}

if ($AddPath) {
    Write-Host "Add this directory to your user PATH if desired: $InstallRoot"
    Write-Host "The installer does not modify persistent PATH automatically."
}

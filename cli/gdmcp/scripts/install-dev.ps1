[CmdletBinding()]
param(
    [string]$InstallRoot,
    [string]$ToolchainRoot,
    [switch]$Offline,
    [switch]$UseSystemCargo,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$DefaultStateRoot = Join-Path $RepoRoot ".gdmcp"
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $DefaultStateRoot "bin"
}
if ([string]::IsNullOrWhiteSpace($ToolchainRoot)) {
    $ToolchainRoot = $DefaultStateRoot
}
$Manifest = Join-Path $RepoRoot "cli\gdmcp\Cargo.toml"
$CargoHome = Join-Path $ToolchainRoot "cargo"
$RustupHome = Join-Path $ToolchainRoot "rustup"
$previousRustupHome = $env:RUSTUP_HOME
$previousCargoHome = $env:CARGO_HOME
$toolchainEnvironmentSet = $false

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
}

Write-Host "Repository: $RepoRoot"
Write-Host "Install root: $InstallRoot"
Write-Host "Toolchain root: $ToolchainRoot"
Write-Host "System Cargo: $UseSystemCargo"
Write-Host "Offline: $Offline"

if ($DryRun) {
    Write-Host "Dry run: no files, toolchains, PATH entries, or user configuration will be changed."
    exit 0
}

if (-not (Test-Path -LiteralPath $Manifest)) {
    throw "Cargo manifest not found: $Manifest"
}

$cargo = $null
if ($UseSystemCargo) {
    $systemCargo = Get-Command cargo -ErrorAction SilentlyContinue
    if ($null -ne $systemCargo) {
        $cargo = $systemCargo.Source
    }
}

$localCargo = Join-Path $CargoHome "bin\cargo.exe"
if ($null -eq $cargo -and (Test-Path -LiteralPath $localCargo)) {
    $cargo = $localCargo
}

if ($null -eq $cargo) {
    if ($Offline) {
        throw "Offline mode cannot bootstrap a missing project-local Rust toolchain."
    }

    New-Item -ItemType Directory -Force -Path $ToolchainRoot | Out-Null
    $rustupInit = Join-Path $ToolchainRoot "rustup-init.exe"
    if (-not (Test-Path -LiteralPath $rustupInit)) {
        Write-Host "Downloading rustup-init into the project-local toolchain root..."
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit
    }

    $env:RUSTUP_HOME = $RustupHome
    $env:CARGO_HOME = $CargoHome
    $toolchainEnvironmentSet = $true
    Invoke-Checked $rustupInit @("-y", "--no-modify-path", "--default-toolchain", "stable", "--profile", "minimal")
    $cargo = $localCargo
} elseif (-not $UseSystemCargo) {
    $env:RUSTUP_HOME = $RustupHome
    $env:CARGO_HOME = $CargoHome
    $toolchainEnvironmentSet = $true
}

if (-not (Test-Path -LiteralPath $cargo)) {
    throw "Cargo executable was not found after toolchain setup: $cargo"
}

if ($toolchainEnvironmentSet) {
    $rustup = Join-Path $CargoHome "bin\rustup.exe"
    if (-not (Test-Path -LiteralPath $rustup)) {
        throw "Rustup executable was not found for the project-local toolchain: $rustup"
    }
    Invoke-Checked $rustup @("component", "add", "rustfmt", "clippy", "--toolchain", "stable")
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
try {
    Invoke-Checked $cargo @("fmt", "--manifest-path", $Manifest, "--check")
    Invoke-Checked $cargo @("clippy", "--manifest-path", $Manifest, "--all-targets", "--locked", "--", "-D", "warnings")
    Invoke-Checked $cargo @("test", "--manifest-path", $Manifest, "--locked")
    Invoke-Checked $cargo @("build", "--manifest-path", $Manifest, "--release", "--locked")
} finally {
    if ($toolchainEnvironmentSet) {
        $env:RUSTUP_HOME = $previousRustupHome
        $env:CARGO_HOME = $previousCargoHome
    }
}

$binary = Join-Path $RepoRoot "cli\gdmcp\target\release\gdmcp.exe"
if (-not (Test-Path -LiteralPath $binary)) {
    throw "Release binary was not produced: $binary"
}
$destination = Join-Path $InstallRoot "gdmcp.exe"
if ($Force -or -not (Test-Path -LiteralPath $destination)) {
    Copy-Item -LiteralPath $binary -Destination $destination -Force
} else {
    throw "Install target exists. Re-run with -Force: $destination"
}

Write-Host "Installed gdmcp to $destination"
Write-Host "No persistent PATH or user Cargo configuration was changed."

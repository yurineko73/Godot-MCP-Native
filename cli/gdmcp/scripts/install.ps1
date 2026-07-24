param(
    [string]$InstallRoot = "$env:LOCALAPPDATA\gdmcp"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$Manifest = Join-Path $RepoRoot "cli\gdmcp\Cargo.toml"

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw "cargo was not found in PATH"
}

cargo install --path (Split-Path $Manifest) --root $InstallRoot --force
Write-Host "Installed gdmcp to $(Join-Path $InstallRoot 'bin'). Add that directory to PATH."

[CmdletBinding()]
param(
    [string]$Version,
    [string]$Target,
    [string]$OutputDir,
    [switch]$Clean,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$CliRoot = Join-Path $RepoRoot "cli\gdmcp"
$ManifestPath = Join-Path $CliRoot "Cargo.toml"
$LockfilePath = Join-Path $CliRoot "Cargo.lock"
$PackagingRoot = Join-Path $CliRoot "packaging"
$LocalStateRoot = Join-Path $RepoRoot ".gdmcp"
$LocalCargoHome = Join-Path $LocalStateRoot "cargo"
$LocalRustupHome = Join-Path $LocalStateRoot "rustup"
$LocalCargo = Join-Path $LocalCargoHome "bin\cargo.exe"
$previousRustupHome = $env:RUSTUP_HOME
$previousCargoHome = $env:CARGO_HOME
$localToolchainEnvironmentSet = $false

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "dist"
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Cargo manifest not found: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $LockfilePath)) {
    throw "Cargo.lock is required for reproducible packaging: $LockfilePath"
}

$cargoText = Get-Content -LiteralPath $ManifestPath -Raw
$versionMatch = [regex]::Match($cargoText, '(?m)^\s*version\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success) {
    throw "Package version was not found in $ManifestPath"
}
$sourceVersion = $versionMatch.Groups[1].Value
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $sourceVersion
} elseif ($Version -ne $sourceVersion) {
    throw "Version mismatch: requested $Version but Cargo.toml declares $sourceVersion"
}

if ([string]::IsNullOrWhiteSpace($Target)) {
    $rustc = Get-Command rustc -ErrorAction SilentlyContinue
    if ($null -eq $rustc) {
        throw "Target is required when rustc is not available on PATH."
    }
    $hostLine = & $rustc.Source -vV | Select-String '^host:' | Select-Object -First 1
    if ($null -eq $hostLine) {
        throw "Unable to determine the Rust host target."
    }
    $Target = ($hostLine.ToString() -split ':', 2)[1].Trim()
}
if ($Target -notmatch '^[A-Za-z0-9._-]+$') {
    throw "Target contains unsupported characters: $Target"
}

$archiveName = "gdmcp-$Version-$Target.zip"
$outputPath = Join-Path $OutputDir $archiveName
$stagingBase = [IO.Path]::GetFullPath($OutputDir)
$stagingPath = Join-Path $stagingBase ".staging\gdmcp-$Version-$Target"
$stagingPath = [IO.Path]::GetFullPath($stagingPath)

function Assert-WithinOutput {
    param([string]$PathToCheck)
    $root = $stagingBase.TrimEnd('\') + '\'
    if (-not $PathToCheck.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the output directory: $PathToCheck"
    }
}

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

Write-Host "Packaging gdmcp $Version for $Target"
Write-Host "Output: $outputPath"

if ($DryRun) {
    Write-Host "Dry run: no build, archive, or filesystem changes will be made."
    exit 0
}

$cargoCommand = Get-Command cargo -ErrorAction SilentlyContinue
if ($null -eq $cargoCommand) {
    $cargoCommand = Get-Command cargo.cmd -ErrorAction SilentlyContinue
}
if ($null -eq $cargoCommand -and (Test-Path -LiteralPath $LocalCargo)) {
    $cargo = $LocalCargo
    $env:RUSTUP_HOME = $LocalRustupHome
    $env:CARGO_HOME = $LocalCargoHome
    $localToolchainEnvironmentSet = $true
} elseif ($null -eq $cargoCommand) {
    throw "Cargo was not found on PATH or in .gdmcp. Run scripts/install-dev.ps1 first or use a release package."
} else {
    $cargo = if (-not [string]::IsNullOrWhiteSpace($cargoCommand.Source)) { $cargoCommand.Source } else { $cargoCommand.Path }
}

if (Test-Path -LiteralPath $stagingPath) {
    if (-not $Clean) {
        throw "Staging directory exists. Re-run with -Clean: $stagingPath"
    }
    Assert-WithinOutput $stagingPath
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null

try {
    Invoke-Checked $cargo @("fmt", "--manifest-path", $ManifestPath, "--check")
    Invoke-Checked $cargo @("clippy", "--manifest-path", $ManifestPath, "--all-targets", "--locked", "--", "-D", "warnings")
    Invoke-Checked $cargo @("test", "--manifest-path", $ManifestPath, "--locked")
    Invoke-Checked $cargo @("build", "--manifest-path", $ManifestPath, "--release", "--locked", "--target", $Target)

    $binary = Join-Path $CliRoot "target\$Target\release\gdmcp.exe"
    if (-not (Test-Path -LiteralPath $binary)) {
        $binary = Join-Path $CliRoot "target\release\gdmcp.exe"
    }
    if (-not (Test-Path -LiteralPath $binary)) {
        throw "Release binary was not produced: $binary"
    }

    Copy-Item -LiteralPath $binary -Destination (Join-Path $stagingPath "gdmcp.exe")
    Copy-Item -LiteralPath (Join-Path $PackagingRoot "install.ps1") -Destination (Join-Path $stagingPath "install.ps1")
    Copy-Item -LiteralPath (Join-Path $PackagingRoot "install.sh") -Destination (Join-Path $stagingPath "install.sh")
    Copy-Item -LiteralPath (Join-Path $PackagingRoot "README.md") -Destination (Join-Path $stagingPath "README.md")
    Copy-Item -LiteralPath (Join-Path $PackagingRoot "LICENSE") -Destination (Join-Path $stagingPath "LICENSE")

    $hash = (Get-FileHash -LiteralPath (Join-Path $stagingPath "gdmcp.exe") -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $stagingPath "SHA256SUMS") -Value ("{0}  gdmcp.exe" -f $hash) -Encoding utf8NoBOM
    $releaseManifest = [ordered]@{
        schema_version = 1
        package = "gdmcp"
        version = $Version
        target = $Target
        executable = "gdmcp.exe"
    }
    $releaseManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stagingPath "release-manifest.json") -Encoding utf8NoBOM

    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Force
    }
    Compress-Archive -Path (Join-Path $stagingPath "*") -DestinationPath $outputPath -CompressionLevel Optimal
    Write-Host "Created $outputPath"
} finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Assert-WithinOutput $stagingPath
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
    if ($localToolchainEnvironmentSet) {
        $env:RUSTUP_HOME = $previousRustupHome
        $env:CARGO_HOME = $previousCargoHome
    }
}

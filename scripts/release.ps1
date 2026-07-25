<#
.SYNOPSIS
    Automate Godot MCP Native release steps 1-5.
.DESCRIPTION
    Bumps plugin and CLI versions, runs tests, builds CLI packages,
    creates plugin archive, and creates a GitHub Release draft.
    Asset Library submission (step 6) and Quark upload (step 7) remain manual.
.PARAMETER Version
    New version number (e.g. "1.1.0"). Required.
.PARAMETER SkipTests
    Skip test suite (for quick iteration; not recommended for actual release).
.PARAMETER DryRun
    Preview changes without writing any files or creating a release.
.EXAMPLE
    .\scripts\release.ps1 -Version 1.1.0
    .\scripts\release.ps1 -Version 1.1.0 -SkipTests
    .\scripts\release.ps1 -Version 1.1.0 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [switch]$SkipTests,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PluginCfg = Join-Path $RepoRoot "addons\godot_mcp\plugin.cfg"
$CliReleaseJson = Join-Path $RepoRoot "addons\godot_mcp\cli_release.json"
$McpTypesGd = Join-Path $RepoRoot "addons\godot_mcp\native_mcp\mcp_types.gd"
$CargoToml = Join-Path $RepoRoot "cli\gdmcp\Cargo.toml"
$GodotExe = "F:\Godot\Godot_v4.6.1-stable_win64.exe"
$DistDir = Join-Path $RepoRoot "dist"
$PluginZip = Join-Path $DistDir "godot-mcp-native-$Version.zip"

function Write-Step { param([string]$Text) Write-Host ">>> $Text" -ForegroundColor Cyan }

# Step 1: Bump versions
Write-Step "Step 1: Bump version to $Version"

if (-not $DryRun) {
    $cfg = Get-Content $PluginCfg -Raw
    $cfg = $cfg -replace '(?m)^version="[^"]*"', "version=`"$Version`""
    Set-Content $PluginCfg $cfg -NoNewline

    $json = Get-Content $CliReleaseJson -Raw | ConvertFrom-Json
    $json.version = $Version
    $json | ConvertTo-Json -Depth 4 | Set-Content $CliReleaseJson -NoNewline

    $types = Get-Content $McpTypesGd -Raw
    $types = $types -replace 'const PLUGIN_VERSION\s*=\s*"[^"]*"', "const PLUGIN_VERSION = `"$Version`""
    Set-Content $McpTypesGd $types -NoNewline

    $cargo = Get-Content $CargoToml -Raw
    $cargo = $cargo -replace '(?m)^version\s*=\s*"[^"]*"', "version = `"$Version`""
    Set-Content $CargoToml $cargo -NoNewline

    # Update README version badges
    $readmes = @(
        (Join-Path $RepoRoot "README.md"),
        (Join-Path $RepoRoot "README.zh.md"),
        (Join-Path $RepoRoot "addons\godot_mcp\README.md"),
        (Join-Path $RepoRoot "addons\godot_mcp\README.zh.md")
    )
    foreach ($rm in $readmes) {
        if (Test-Path $rm) {
            $rmContent = Get-Content $rm -Raw
            $rmContent = $rmContent -replace 'Version-\d+\.\d+\.\d+', "Version-$Version"
            Set-Content $rm $rmContent -NoNewline
        }
    }

    Write-Host "  Updated: plugin.cfg, cli_release.json, mcp_types.gd, Cargo.toml, README badges (x4)"
} else {
    Write-Host "  [DRY RUN] Would update 8 files (4 version files + 4 README badges)"
}

# Step 2: Tests
if (-not $SkipTests) {
    Write-Step "Step 2: Run test suite"
    if (-not $DryRun) {
        Write-Host "  Rust tests..."
        $env:CARGO_HOME = Join-Path $RepoRoot ".gdmcp\cargo"
        $env:RUSTUP_HOME = Join-Path $RepoRoot ".gdmcp\rustup"
        $env:PATH = "$env:CARGO_HOME\bin;$env:PATH"
        cargo test --manifest-path cli/gdmcp/Cargo.toml
        if ($LASTEXITCODE -ne 0) { throw "Rust tests failed" }
        cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets -- -D warnings
        if ($LASTEXITCODE -ne 0) { throw "Clippy failed" }

        Write-Host "  GUT tests..."
        & $GodotExe --headless --path $RepoRoot -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
        if ($LASTEXITCODE -ne 0) { throw "GUT tests failed" }

        Write-Host "  Packaging tests..."
        python test/integration/test_gdmcp_packaging.py
        if ($LASTEXITCODE -ne 0) { throw "Packaging tests failed" }
        Write-Host "  All tests passed"
    } else {
        Write-Host "  [DRY RUN] Would run Rust + GUT + packaging tests"
    }
}

# Step 3: Build CLI
Write-Step "Step 3: Build CLI packages"
if (-not $DryRun) {
    $pkgScript = Join-Path $RepoRoot "cli\gdmcp\scripts\package.ps1"
    & $pkgScript -Version $Version -Target "x86_64-pc-windows-msvc"
    if ($LASTEXITCODE -ne 0) { throw "Windows package failed" }
    Write-Host "  dist/gdmcp-$Version-x86_64-pc-windows-msvc.zip"
} else {
    Write-Host "  [DRY RUN] Would build Windows x64 package"
}

# Step 4: Plugin archive
Write-Step "Step 4: Create plugin archive"
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
    Compress-Archive -Path "$RepoRoot\addons\godot_mcp\*" -DestinationPath $PluginZip -Force
    Write-Host "  $PluginZip"
} else {
    Write-Host "  [DRY RUN] Would create $PluginZip"
}

# Step 5: GitHub Release
Write-Step "Step 5: Create GitHub Release (draft)"
if (-not $DryRun) {
    $tag = "v$Version"
    $notes = "Plugin: godot-mcp-native-$Version.zip`nCLI: gdmcp-$Version-x86_64-pc-windows-msvc.zip"
    gh release create $tag --repo yurineko73/Godot-MCP-Native --draft --title "v$Version" --notes $notes `
        $PluginZip (Join-Path $DistDir "gdmcp-$Version-x86_64-pc-windows-msvc.zip")
    if ($LASTEXITCODE -ne 0) { throw "GitHub release creation failed" }
    Write-Host "  Draft created: https://github.com/yurineko73/Godot-MCP-Native/releases"
} else {
    Write-Host "  [DRY RUN] Would create GitHub Release draft"
}

Write-Host ""
Write-Host "=== Automated steps complete ===" -ForegroundColor Green
Write-Host "Manual steps remaining:"
Write-Host "  6. Submit plugin to Godot Asset Library"
Write-Host "  7. Upload to Quark cloud drive (page_url is pre-configured in cli_release.json)"
Write-Host "  8. Commit and push version changes"
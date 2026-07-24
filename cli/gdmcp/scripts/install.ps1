param(
    [string]$Version = "latest",
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\gdmcp"
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Write-Host "Place the gdmcp.exe release binary in $InstallDir and add that directory to PATH."
Write-Host "Requested version: $Version"

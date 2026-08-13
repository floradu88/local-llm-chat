<#
.SYNOPSIS
  Install Continue example config for VS Code (Case H).

.PARAMETER Force
  Overwrite existing %USERPROFILE%\.continue\config.json
#>
[CmdletBinding()]
param(
  [switch] $Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $RepoRoot "config\continue.config.example.json"
$destDir = Join-Path $HOME ".continue"
$dest = Join-Path $destDir "config.json"

if (-not (Test-Path $src)) {
  throw "Missing example config: $src"
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

if ((Test-Path $dest) -and -not $Force) {
  Write-Warning "Already exists: $dest"
  Write-Host "Re-run with -Force to overwrite, or merge manually from:"
  Write-Host "  $src"
  exit 0
}

Copy-Item $src $dest -Force
Write-Host "Wrote $dest"
Write-Host "Install the Continue extension in VS Code, reload, then select an Ollama model."
Write-Host "Ensure ollama list shows the model names in that config."

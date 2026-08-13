<#
.SYNOPSIS
  Index a project with Codegraph (local graph). Installs nothing if CLI missing — prints help.

.PARAMETER ProjectPath
  Project to index (default: current directory / toolkit repo when run from scripts).
#>
[CmdletBinding()]
param(
  [string] $ProjectPath = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectPath) {
  $ProjectPath = (Get-Location).Path
}
if (-not (Test-Path -LiteralPath $ProjectPath)) {
  throw "ProjectPath not found: $ProjectPath"
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

$cg = Get-Command codegraph -ErrorAction SilentlyContinue
if (-not $cg) {
  Write-Host "codegraph not on PATH."
  Write-Host "Install your Codegraph CLI, then re-run this script."
  Write-Host "Typical after install:"
  Write-Host "  cd `"$ProjectPath`""
  Write-Host "  codegraph init"
  exit 1
}

Push-Location $ProjectPath
try {
  Write-Host "Indexing: $ProjectPath"
  & codegraph init
  if ($LASTEXITCODE -ne 0) {
    throw "codegraph init failed with exit $LASTEXITCODE"
  }
  Write-Host "OK - .codegraph created/updated under $ProjectPath"
} finally {
  Pop-Location
}

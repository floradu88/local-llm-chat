<#
.SYNOPSIS
  Index a project with Codegraph (local graph). Installs via Install-Codegraph.ps1 if CLI missing.

.PARAMETER ProjectPath
  Project to index (default: current directory / toolkit repo when run from scripts).

.PARAMETER InstallIfMissing
  If codegraph is not on PATH, run Install-Codegraph.ps1 for this project (default: true).

.PARAMETER ForceInit
  Rebuild graph even when .codegraph exists.
#>
[CmdletBinding()]
param(
  [string] $ProjectPath = "",
  [bool] $InstallIfMissing = $true,
  [switch] $ForceInit
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
$graphDir = Join-Path $ProjectPath ".codegraph"

$cg = Get-Command codegraph -ErrorAction SilentlyContinue
if (-not $cg) {
  if ($InstallIfMissing) {
    Write-Host "codegraph not on PATH — running Install-Codegraph.ps1 (fnm → npm → agent install → init)..."
    $args = @{ ProjectPath = $ProjectPath }
    if ($ForceInit) { $args["ForceInit"] = $true }
    & (Join-Path $PSScriptRoot "Install-Codegraph.ps1") @args
    exit $LASTEXITCODE
  }
  Write-Host "codegraph not on PATH."
  Write-Host "Install with:"
  Write-Host "  .\scripts\Install-Codegraph.ps1 -ProjectPath `"$ProjectPath`""
  exit 1
}

if ((Test-Path -LiteralPath $graphDir) -and -not $ForceInit) {
  Write-Host "Already indexed: $graphDir"
  Write-Host "Pass -ForceInit to rebuild, or: codegraph init"
  exit 0
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

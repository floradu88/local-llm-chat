<#
.SYNOPSIS
  Elevated helper: run codegraph install WITH agent permissions (UAC).
  Called by Install-Codegraph.ps1 -Elevated.
#>
[CmdletBinding()]
param(
  [string] $Target = "cursor"
)

$ErrorActionPreference = "Stop"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

$cg = Get-Command codegraph -ErrorAction SilentlyContinue
if (-not $cg) {
  Write-Error "codegraph not on PATH in elevated session"
  exit 1
}

Write-Host "Elevated: codegraph install --yes --target=$Target --location=global"
& codegraph install --yes "--target=$Target" --location=global
exit $LASTEXITCODE

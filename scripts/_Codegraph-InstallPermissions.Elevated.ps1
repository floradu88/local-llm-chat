<#
.SYNOPSIS
  Elevated helper: run codegraph install WITH agent permissions (UAC).

.DESCRIPTION
  Invoked by Install-Codegraph.ps1 -Elevated. Activates fnm env when available
  so codegraph resolves from the preferred Node runtime.
#>
param(
  [string] $Target = "cursor"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
Add-FnmCommonPaths
[void](Initialize-FnmEnv)

$cg = Get-Command codegraph -ErrorAction SilentlyContinue
if (-not $cg) {
  Write-Error "codegraph not on PATH in elevated session"
  exit 1
}

Write-Host ("Elevated node source: {0}" -f (Get-NodeRuntimeInfo).Source)
Write-Host "Elevated: codegraph install --yes --target=$Target --location=global"
& codegraph install --yes "--target=$Target" --location=global
exit $LASTEXITCODE

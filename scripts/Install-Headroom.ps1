<#
.SYNOPSIS
  Install Headroom into a short-path Python venv (default C:\hr).

.DESCRIPTION
  Windows Store / user-site pip installs often fail because litellm (a Headroom
  dependency) exceeds MAX_PATH unless Long Paths are enabled (admin).

  This script creates a short venv and installs headroom-ai[proxy] there — no admin.

.PARAMETER VenvPath
  Virtualenv root. Default: C:\hr

.PARAMETER Force
  Recreate the venv and reinstall.

.PARAMETER CheckOnly
  Report whether headroom.exe exists; exit 0 if found.
#>
[CmdletBinding()]
param(
  [string] $VenvPath = "C:\hr",
  [switch] $Force,
  [switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$exe = Resolve-HeadroomExe -VenvPath $VenvPath
if ($CheckOnly) {
  if ($exe) {
    Write-Host "OK: headroom at $exe"
    exit 0
  }
  Write-Host "MISSING: headroom not found. Run: .\scripts\Install-Headroom.ps1"
  exit 1
}

$installed = Ensure-HeadroomShortVenv -VenvPath $VenvPath -ForceReinstall:$Force
Write-Host ""
Write-Host "Headroom ready: $installed"
Write-Host "Start proxy:  .\scripts\Start-HeadroomOllama.ps1"
Write-Host "Then wire:    .\scripts\Install-CursorConfig.ps1 -Headroom"
Write-Host "              .\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force"
exit 0

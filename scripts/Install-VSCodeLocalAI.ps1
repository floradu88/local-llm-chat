<#
.SYNOPSIS
  VS Code + local Ollama: ChatGPT-like (Continue) + Cursor-like agent (Cline).

.DESCRIPTION
  One-shot Case H stack:
    1) Install VS Code if missing (unless -SkipVSCodeInstall)
    2) Install-ContinueConfig.ps1 — sidebar chat + tab autocomplete
    3) Install-ClineConfig.ps1 — autonomous agent (files / terminal)
    4) Optional Test-VSCodeSetup.ps1 (full config check)

.PARAMETER Models
  Model tags for Continue. Default: ollama list (non-embed).

.PARAMETER ClineModel
  Model tag for Cline. Default: first Continue model.

.PARAMETER Headroom
  Point both extensions at Headroom :8787.

.PARAMETER Force
  Overwrite existing Continue / Cline configs.

.PARAMETER SkipVSCodeInstall
  Do not run Install-VSCode.ps1 when Code is missing.

.PARAMETER SkipContinue
  Skip Continue install/config.

.PARAMETER SkipCline
  Skip Cline install/config.

.PARAMETER SkipTest
  Do not run Test-VSCodeSetup.ps1 at the end.

.PARAMETER SkipRemoteDisable
  Do not run Disable-RemoteAIProviders.ps1 (remote providers stay as-is).

.PARAMETER CheckOnly
  Status only for Continue + Cline (exit 0 if both configured).
#>
[CmdletBinding()]
param(
  [string[]] $Models = @(),
  [string] $ClineModel = "",
  [switch] $Headroom,
  [switch] $Force,
  [switch] $SkipVSCodeInstall,
  [switch] $SkipContinue,
  [switch] $SkipCline,
  [switch] $SkipTest,
  [switch] $SkipRemoteDisable,
  [switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

Write-Section "VS Code Local AI (Continue + Cline -> Ollama)"

$info = Get-VSCodeInstallInfo
$cont = Get-ContinueOllamaConfigStatus
$cline = Get-ClineOllamaConfigStatus

Write-Host ("  VS Code:   {0}" -f $info.Installed)
Write-Host ("  Continue:  {0}" -f $cont.Configured)
Write-Host ("  Cline:     {0}" -f $cline.Configured)

if ($CheckOnly) {
  $ok = $info.Installed -and $cont.Configured -and $cline.Configured
  if ($ok) {
    Write-Host "  CheckOnly: Continue (chat) + Cline (agent) look configured"
    exit 0
  }
  Write-Host "  CheckOnly: incomplete - re-run without -CheckOnly (or Install-VSCodeLocalAI.ps1)"
  exit 1
}

if (-not $info.Installed -and -not $SkipVSCodeInstall) {
  Write-Section "Install VS Code"
  & (Join-Path $PSScriptRoot "Install-VSCode.ps1")
  $info = Get-VSCodeInstallInfo
}

if (-not $SkipContinue) {
  Write-Section "Continue (ChatGPT-like chat + autocomplete)"
  $cArgs = @{}
  if ($Models -and $Models.Count -gt 0) { $cArgs["Models"] = $Models }
  if ($Headroom) { $cArgs["Headroom"] = $true }
  if ($Force) { $cArgs["Force"] = $true }
  & (Join-Path $PSScriptRoot "Install-ContinueConfig.ps1") @cArgs
}

if (-not $SkipCline) {
  Write-Section "Cline (Cursor-like agent)"
  $clArgs = @{}
  if ($ClineModel) { $clArgs["Model"] = $ClineModel }
  elseif ($Models -and $Models.Count -gt 0) { $clArgs["Model"] = $Models[0] }
  if ($Headroom) { $clArgs["Headroom"] = $true }
  if ($Force) { $clArgs["Force"] = $true }
  & (Join-Path $PSScriptRoot "Install-ClineConfig.ps1") @clArgs
}

if (-not $SkipRemoteDisable) {
  Write-Section "Disable remote providers"
  $dArgs = @{ SkipCursor = $true }
  if ($Headroom) { $dArgs["Headroom"] = $true }
  if ($SkipContinue) { $dArgs["SkipContinue"] = $true }
  if ($SkipCline) { $dArgs["SkipCline"] = $true }
  & (Join-Path $PSScriptRoot "Disable-RemoteAIProviders.ps1") @dArgs
}

if (-not $SkipTest) {
  Write-Section "Verify"
  & (Join-Path $PSScriptRoot "Test-VSCodeSetup.ps1")
  exit $LASTEXITCODE
}

Write-Section "Done"
Write-Host "Reload VS Code."
Write-Host "  Continue: sidebar chat + tab autocomplete (ChatGPT / Copilot-like)"
Write-Host "  Cline:    agent panel for multi-file edits (Cursor-like)"
Write-Host "Verify later: .\scripts\Test-VSCodeSetup.ps1"
exit 0

<#
.SYNOPSIS
  One-shot bootstrap: env + Ollama install + coding model pulls for this repo.

.DESCRIPTION
  Intended for humans and local agents following AGENTS.md / docs/agent-setup-playbook.md.
  Configures Cursor → Ollama via Install-CursorConfig.ps1 when Cursor is present (unless -SkipCursorConfig).
  Configures VS Code Local AI (Continue chat + Cline agent) via Install-VSCodeLocalAI.ps1 (unless -SkipContinueConfig).

.PARAMETER Tier
  RAM tier for Pull-CodingModels: 8GB | 16GB | 32GB | Auto

.PARAMETER SkipInstall
  Skip Ollama install (already installed).

.PARAMETER SkipPull
  Skip model pulls.

.PARAMETER SkipHeadroomHint
  Omit Headroom reminder in the summary.

.PARAMETER ModelsRoot
  Override OLLAMA_MODELS path.

.PARAMETER InstallGpuDrivers
  Optional: run Install-GpuDrivers.ps1 -Install (admin/UAC). Skips when the
  guest is a VM with no NVIDIA device unless you also pass -ForceGpuDrivers.

.PARAMETER ForceGpuDrivers
  Pass -Force through to Install-GpuDrivers.ps1.

.PARAMETER SkipCursor
  Do not check/install Cursor for the current user.

.PARAMETER ForceCursor
  Re-run Cursor installer even if already present.

.PARAMETER SkipCursorConfig
  Do not write Cursor Models → Ollama settings (Install-CursorConfig.ps1).

.PARAMETER ForceCursorConfig
  Pass -Force to Install-CursorConfig.ps1 (replace non-Ollama base URL / write while Cursor running).

.PARAMETER SkipContinueConfig
  Do not run Install-VSCodeLocalAI / Continue → Ollama.

.PARAMETER ForceContinueConfig
  Pass -Force to VS Code Local AI install (overwrite Continue/Cline configs).

.PARAMETER SkipClineConfig
  Install Continue only (skip Cline agent) when wiring VS Code Local AI.

.PARAMETER SkipVSCodeInstall
  Do not auto-install VS Code when missing during Local AI setup.
#>
[CmdletBinding()]
param(
  [ValidateSet("8GB", "16GB", "32GB", "Auto")]
  [string] $Tier = "Auto",
  [switch] $SkipInstall,
  [switch] $SkipPull,
  [switch] $SkipHeadroomHint,
  [string] $ModelsRoot = "",
  [switch] $InstallGpuDrivers,
  [switch] $ForceGpuDrivers,
  [switch] $SkipCursor,
  [switch] $ForceCursor,
  [switch] $SkipCursorConfig,
  [switch] $ForceCursorConfig,
  [switch] $SkipContinueConfig,
  [switch] $ForceContinueConfig,
  [switch] $SkipClineConfig,
  [switch] $SkipVSCodeInstall
)

$ErrorActionPreference = "Stop"
$Scripts = $PSScriptRoot
$RepoRoot = Split-Path -Parent $Scripts
. (Join-Path $Scripts "_common.ps1")

$Tier = Resolve-CodingModelTier -Tier $Tier

Set-Location $RepoRoot
Write-Host "=== local-llm-chat machine setup ==="
Write-Host "Repo: $RepoRoot"
Write-Host "Tier: $Tier"
Write-Host ""

# 1) Env
$envArgs = @{ Persistent = $true }
if ($ModelsRoot) { $envArgs["ModelsRoot"] = $ModelsRoot }
Write-Host "[1/8] Set-OllamaEnv.ps1"
& (Join-Path $Scripts "Set-OllamaEnv.ps1") @envArgs

# 2) Install
if (-not $SkipInstall) {
  if (Test-OllamaCommand) {
    $ver = ollama --version
    Write-Host "[2/8] Ollama already on PATH: $ver - skipping install."
  }
  else {
    Write-Host "[2/8] Install-Ollama.ps1"
    & (Join-Path $Scripts "Install-Ollama.ps1")
    Add-OllamaToSessionPath
  }
}
else {
  Write-Host "[2/8] SkipInstall set - not installing."
  Add-OllamaToSessionPath
}

if (-not (Test-OllamaCommand)) {
  throw "ollama still not on PATH. Open a new PowerShell and re-run Setup-Machine.ps1 -SkipInstall, or check LocalAppData\Programs\Ollama."
}

# 3) Optional GPU drivers
Write-Host ""
if ($InstallGpuDrivers) {
  Write-Host "[3/8] Install-GpuDrivers.ps1 -Install (optional, admin)"
  $gpuArgs = @{ Install = $true }
  if ($ForceGpuDrivers) { $gpuArgs["Force"] = $true }
  & (Join-Path $Scripts "Install-GpuDrivers.ps1") @gpuArgs
} else {
  Write-Host "[3/8] Skip GPU drivers (opt-in: -InstallGpuDrivers)"
  Write-Host "  Detect/VM guidance: .\scripts\Install-GpuDrivers.ps1"
}

# 4) Cursor (check + per-user install if missing)
Write-Host ""
if (-not $SkipCursor) {
  Write-Host "[4/8] Install-Cursor.ps1 (check + current-user install if missing)"
  $cursorArgs = @{}
  if ($ForceCursor) { $cursorArgs["Force"] = $true }
  & (Join-Path $Scripts "Install-Cursor.ps1") @cursorArgs
} else {
  Write-Host "[4/8] SkipCursor set - not checking/installing Cursor"
}

# 5) Pulls
if (-not $SkipPull) {
  Write-Host "[5/8] Pull-CodingModels.ps1 -Tier $Tier"
  & (Join-Path $Scripts "Pull-CodingModels.ps1") -Tier $Tier -SkipSmoke
}
else {
  Write-Host "[5/8] SkipPull set - not pulling models."
  ollama list
}

# 6) Cursor → Ollama Models config
Write-Host ""
if ($SkipCursor -or $SkipCursorConfig) {
  Write-Host "[6/8] Skip Cursor Ollama config (-SkipCursor / -SkipCursorConfig)"
} else {
  Write-Host "[6/8] Install-CursorConfig.ps1 (Models → Ollama)"
  $cfgArgs = @{ SetAsDefault = $true }
  if ($ForceCursorConfig) { $cfgArgs["Force"] = $true }
  try {
    & (Join-Path $Scripts "Install-CursorConfig.ps1") @cfgArgs
  } catch {
    Write-Warning "Cursor Ollama config skipped: $_"
    Write-Host "  Quit Cursor and run: .\scripts\Install-CursorConfig.ps1"
  }
}

# 7) VS Code Local AI (Continue chat + Cline agent)
Write-Host ""
if ($SkipContinueConfig) {
  Write-Host "[7/8] SkipContinueConfig set - not wiring VS Code Local AI"
} else {
  Write-Host "[7/8] Install-VSCodeLocalAI.ps1 (Continue + Cline -> Ollama)"
  $vsArgs = @{ SkipTest = $true }
  if ($ForceContinueConfig) { $vsArgs["Force"] = $true }
  if ($SkipClineConfig) { $vsArgs["SkipCline"] = $true }
  if ($SkipVSCodeInstall) { $vsArgs["SkipVSCodeInstall"] = $true }
  try {
    & (Join-Path $Scripts "Install-VSCodeLocalAI.ps1") @vsArgs
  } catch {
    Write-Warning "VS Code Local AI skipped: $_"
    Write-Host "  Run: .\scripts\Install-VSCodeLocalAI.ps1 -Force"
  }
}

# 7b) Local-only: disable remote providers (Cursor + VS Code + Ollama cloud)
Write-Host ""
Write-Host "[7b] Disable-RemoteAIProviders.ps1 (local-only)"
try {
  $disArgs = @{}
  if ($ForceCursorConfig -or $ForceContinueConfig) { $disArgs["Force"] = $true }
  if ($SkipCursor -or $SkipCursorConfig) { $disArgs["SkipCursor"] = $true }
  if ($SkipContinueConfig) {
    $disArgs["SkipContinue"] = $true
    $disArgs["SkipCline"] = $true
  }
  & (Join-Path $Scripts "Disable-RemoteAIProviders.ps1") @disArgs
} catch {
  Write-Warning "Remote-provider disable skipped: $_"
  Write-Host "  Run: .\scripts\Disable-RemoteAIProviders.ps1"
}

# 8) Verify
Write-Host "[8/8] Test-LocalSetup.ps1"
& (Join-Path $Scripts "Test-LocalSetup.ps1")

Write-Host ""
Write-Host "=== Next (editor / tools) - see docs\integrations.md and README Cases H-K ==="
Write-Host "VS Code: .\scripts\Install-VSCodeLocalAI.ps1   then .\scripts\Test-VSCodeSetup.ps1"
Write-Host "Cursor:  .\scripts\Install-CursorConfig.ps1   (quit Cursor first if it overwrites)"
Write-Host "Local-only: .\scripts\Disable-RemoteAIProviders.ps1"
Write-Host "Codegraph: .\scripts\Install-Codegraph.ps1 -ProjectPath <repo>  (fnm preferred; system npm fallback)"
Write-Host "GPU check: .\scripts\Test-GpuSupport.ps1"
if (-not $SkipHeadroomHint) {
  Write-Host "Headroom: .\scripts\Start-HeadroomOllama.ps1  then Install-CursorConfig / Install-VSCodeLocalAI -Headroom"
}
Write-Host ""
Write-Host "Agent playbook: docs\agent-setup-playbook.md"
Write-Host "Done."

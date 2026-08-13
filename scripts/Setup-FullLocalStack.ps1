<#
.SYNOPSIS
  End-to-end local stack: install tools, download models, index code, verify.

.DESCRIPTION
  Scenario: after git clone, install everything needed to use local models + Codegraph.
  1) Ollama env + install + model pulls (Setup-Machine)
  2) Optional three example model pulls
  3) Continue config for VS Code
  4) codegraph init (index) when CLI is available
  5) Status + verify
  Prints Cursor wiring steps (manual).

.PARAMETER Tier
  8GB | 16GB | 32GB | Auto

.PARAMETER PullExampleModels
  Also pull qwen2.5-coder:7b, deepseek-coder-v2:16b, codellama:13b

.PARAMETER ProjectPath
  Path to index with codegraph (default: this repo). Use your app repo for real work.

.PARAMETER SkipInstall / SkipPull / SkipContinue / SkipCodegraph / SkipVerify
  Skip individual steps.

.PARAMETER ModelsRoot
  Optional OLLAMA_MODELS override.
#>
[CmdletBinding()]
param(
  [ValidateSet("8GB", "16GB", "32GB", "Auto")]
  [string] $Tier = "Auto",
  [switch] $PullExampleModels,
  [string] $ProjectPath = "",
  [switch] $SkipInstall,
  [switch] $SkipPull,
  [switch] $SkipContinue,
  [switch] $SkipCodegraph,
  [switch] $SkipVerify,
  [string] $ModelsRoot = ""
)

$ErrorActionPreference = "Stop"
$Scripts = $PSScriptRoot
$RepoRoot = Split-Path -Parent $Scripts
. (Join-Path $Scripts "_common.ps1")

if (-not $ProjectPath) {
  $ProjectPath = $RepoRoot
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

Set-Location $RepoRoot
Write-Host "=== Setup-FullLocalStack ==="
Write-Host "Repo toolkit: $RepoRoot"
Write-Host "Index project: $ProjectPath"
Write-Host "Tier: $Tier"
Write-Host ""

# --- 1) Ollama + models ---
Write-Host "[1/5] Setup-Machine.ps1 (Ollama + tier pulls)"
$setupArgs = @{
  Tier              = $Tier
  SkipHeadroomHint  = $true
}
if ($SkipInstall) { $setupArgs["SkipInstall"] = $true }
if ($SkipPull) { $setupArgs["SkipPull"] = $true }
if ($ModelsRoot) { $setupArgs["ModelsRoot"] = $ModelsRoot }
& (Join-Path $Scripts "Setup-Machine.ps1") @setupArgs

if ($PullExampleModels -and -not $SkipPull) {
  Write-Host ""
  Write-Host "[1b] Pull three example coding models"
  foreach ($m in @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b")) {
    Write-Host "  ollama pull $m"
    & (Join-Path $Scripts "Download-FromOllama.ps1") -Model $m
  }
}

# --- 2) Continue ---
Write-Host ""
if (-not $SkipContinue) {
  Write-Host "[2/5] Install-ContinueConfig.ps1"
  & (Join-Path $Scripts "Install-ContinueConfig.ps1") -Force
} else {
  Write-Host "[2/5] SkipContinue"
}

# --- 3) Codegraph index ---
Write-Host ""
if (-not $SkipCodegraph) {
  Write-Host "[3/5] Codegraph index: $ProjectPath"
  $cg = Get-Command codegraph -ErrorAction SilentlyContinue
  if (-not $cg) {
    Write-Warning "codegraph CLI not on PATH."
    Write-Host "  Install your Codegraph distribution, ensure 'codegraph' is on PATH, then re-run:"
    Write-Host "    codegraph init"
    Write-Host "  in: $ProjectPath"
  } else {
    Push-Location $ProjectPath
    try {
      Write-Host "  Running: codegraph init"
      & codegraph init
      if ($LASTEXITCODE -ne 0) {
        Write-Warning "codegraph init exited with $LASTEXITCODE"
      } else {
        Write-Host "  Codegraph index OK (.codegraph)"
      }
    } finally {
      Pop-Location
    }
  }
} else {
  Write-Host "[3/5] SkipCodegraph"
}

# --- 4) Status ---
Write-Host ""
Write-Host "[4/5] Show-SetupStatus.ps1"
& (Join-Path $Scripts "Show-SetupStatus.ps1")

# --- 5) Verify ---
Write-Host ""
if (-not $SkipVerify) {
  Write-Host "[5/5] Test-LocalSetup.ps1"
  & (Join-Path $Scripts "Test-LocalSetup.ps1") -SkipSmoke
} else {
  Write-Host "[5/5] SkipVerify"
}

Write-Host ""
Write-Host "=== Cursor (manual) ==="
Write-Host "Settings > Models:"
Write-Host "  Base URL: http://localhost:11434/v1"
Write-Host "  API key:  ollama"
Write-Host "  Model:    qwen2.5-coder:7b  (or deepseek-coder-v2:16b / codellama:13b)"
Write-Host ""
Write-Host "=== Next ==="
Write-Host "  GPU check:     .\scripts\Test-GpuSupport.ps1"
Write-Host "  Understand:    docs\code-understanding-prompts.md"
Write-Host "  Multi-model:   docs\multi-model-workflows.md"
Write-Host "  Index other app: .\scripts\Setup-FullLocalStack.ps1 -SkipInstall -SkipPull -ProjectPath 'D:\path\to\app'"
Write-Host "Done."

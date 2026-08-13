<#
.SYNOPSIS
  One-shot bootstrap: env + Ollama install + coding model pulls for this repo.

.DESCRIPTION
  Intended for humans and local agents following AGENTS.md / docs/agent-setup-playbook.md.
  Does not configure VS Code/Cursor GUI settings (prints those steps).

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
#>
[CmdletBinding()]
param(
  [ValidateSet("8GB", "16GB", "32GB", "Auto")]
  [string] $Tier = "Auto",
  [switch] $SkipInstall,
  [switch] $SkipPull,
  [switch] $SkipHeadroomHint,
  [string] $ModelsRoot = ""
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
Write-Host "[1/4] Set-OllamaEnv.ps1"
& (Join-Path $Scripts "Set-OllamaEnv.ps1") @envArgs

# 2) Install
if (-not $SkipInstall) {
  if (Test-OllamaCommand) {
    $ver = ollama --version
    Write-Host "[2/4] Ollama already on PATH: $ver - skipping install."
  }
  else {
    Write-Host "[2/4] Install-Ollama.ps1"
    & (Join-Path $Scripts "Install-Ollama.ps1")
    Add-OllamaToSessionPath
  }
}
else {
  Write-Host "[2/4] SkipInstall set - not installing."
  Add-OllamaToSessionPath
}

if (-not (Test-OllamaCommand)) {
  throw "ollama still not on PATH. Open a new PowerShell and re-run Setup-Machine.ps1 -SkipInstall, or check LocalAppData\Programs\Ollama."
}

# 3) Pulls
if (-not $SkipPull) {
  Write-Host "[3/4] Pull-CodingModels.ps1 -Tier $Tier"
  & (Join-Path $Scripts "Pull-CodingModels.ps1") -Tier $Tier -SkipSmoke
}
else {
  Write-Host "[3/4] SkipPull set - not pulling models."
  ollama list
}

# 4) Verify
Write-Host "[4/4] Test-LocalSetup.ps1"
& (Join-Path $Scripts "Test-LocalSetup.ps1")

Write-Host ""
Write-Host "=== Next (editor / tools) - see docs\integrations.md and README Cases H-K ==="
Write-Host "VS Code: .\scripts\Install-ContinueConfig.ps1"
Write-Host "Cursor: Models base URL http://localhost:11434/v1  key: ollama  model: (from ollama list)"
Write-Host "Codegraph: run 'codegraph init' in each project that needs the graph"
if (-not $SkipHeadroomHint) {
  Write-Host "Headroom: .\scripts\Start-HeadroomOllama.ps1  then base URL http://127.0.0.1:8787/v1"
}
Write-Host ""
Write-Host "Agent playbook: docs\agent-setup-playbook.md"
Write-Host "Done."

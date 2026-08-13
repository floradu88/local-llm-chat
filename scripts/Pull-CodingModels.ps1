<#
.SYNOPSIS
  Pull an opinionated set of coding models for a RAM tier.

.PARAMETER Tier
  8GB | 16GB | 32GB

.PARAMETER SkipSmoke
  Do not run a one-prompt smoke test after pulls.
#>
[CmdletBinding()]
param(
  [ValidateSet("8GB", "16GB", "32GB")]
  [string] $Tier = "16GB",
  [switch] $SkipSmoke
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

$sets = @{
  "8GB"  = @("qwen2.5-coder:3b", "starcoder2:3b")
  "16GB" = @("qwen2.5-coder:7b", "starcoder2:3b")
  "32GB" = @("qwen2.5-coder:14b", "codellama:13b", "starcoder2:7b")
}

$models = $sets[$Tier]
$list = $models -join ", "
Write-Host "Tier $Tier - pulling: $list"

foreach ($m in $models) {
  Write-Host ""
  Write-Host "=== ollama pull $m ==="
  ollama pull $m
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Pull failed for $m (exit $LASTEXITCODE). Continuing."
  }
}

Write-Host ""
Write-Host "Installed models:"
ollama list

if (-not $SkipSmoke) {
  $smoke = $models[0]
  Write-Host ""
  Write-Host "Smoke test: $smoke"
  ollama run $smoke "Reply with exactly: ok"
}

Write-Host ""
Write-Host "Done. Configure the editor: docs\integrations.md"

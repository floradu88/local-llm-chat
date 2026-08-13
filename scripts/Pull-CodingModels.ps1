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
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaCommand)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

$sets = @{
  "8GB"  = @("qwen2.5-coder:3b", "starcoder2:3b")
  "16GB" = @("qwen2.5-coder:7b", "starcoder2:3b")
  "32GB" = @("qwen2.5-coder:14b", "codellama:13b", "deepseek-coder-v2:16b", "starcoder2:7b")
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
  Write-Host "Smoke test (API): $smoke"
  try {
    $body = @{
      model  = $smoke
      prompt = "Reply with exactly: ok"
      stream = $false
      options = @{ num_predict = 8 }
    } | ConvertTo-Json -Compress
    $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -Body $body -ContentType "application/json" -TimeoutSec 180
    Write-Host ("Smoke OK: " + (($resp.response -replace "\s+", " ").Trim()))
  } catch {
    Write-Warning "Smoke generate failed: $_"
  }
}

Write-Host ""
Write-Host "Done. Configure the editor: docs\integrations.md"

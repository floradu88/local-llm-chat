<#
.SYNOPSIS
  Verify local Ollama setup for this repo (Case L).

.PARAMETER Model
  Optional model tag to smoke-test. Default: first from ollama list.

.PARAMETER SkipSmoke
  Skip the generate API smoke call.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [switch] $SkipSmoke
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_common.ps1")

$failed = 0
Write-Host "=== Test-LocalSetup ==="

Add-OllamaToSessionPath
if (Test-OllamaCommand) {
  Write-Host "[OK] ollama on PATH: $(ollama --version)"
} else {
  Write-Host "[FAIL] ollama not on PATH. Run .\scripts\Install-Ollama.ps1 or open a new terminal."
  $failed++
}

$names = @()
if (Test-OllamaApi) {
  $tags = Invoke-RestMethod http://127.0.0.1:11434/api/tags
  $names = @($tags.models | ForEach-Object { $_.name })
  Write-Host "[OK] API http://127.0.0.1:11434 - $($names.Count) model(s)"
  foreach ($n in $names) { Write-Host "     - $n" }
} else {
  Write-Host "[FAIL] Ollama API not reachable. Start Ollama from Start menu / tray."
  $failed++
}

$modelsRoot = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
if (-not $modelsRoot) { $modelsRoot = $env:OLLAMA_MODELS }
if ($modelsRoot) {
  Write-Host "[OK] OLLAMA_MODELS=$modelsRoot"
} else {
  Write-Host "[WARN] OLLAMA_MODELS unset (using Ollama default under user profile)"
}

if (-not $Model -and $names.Count -gt 0) {
  $Model = $names[0]
}

if (-not $SkipSmoke -and $Model -and (Test-OllamaApi)) {
  Write-Host "Smoke test (API generate, non-interactive): $Model"
  try {
    $body = @{
      model  = $Model
      prompt = "Reply with exactly: ok"
      stream = $false
      options = @{ num_predict = 8 }
    } | ConvertTo-Json -Compress
    $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -Body $body -ContentType "application/json" -TimeoutSec 120
    $snippet = ($resp.response -replace "\s+", " ").Trim()
    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + "..." }
    Write-Host "[OK] smoke response: $snippet"
  } catch {
    Write-Host "[FAIL] smoke generate: $_"
    $failed++
  }
} elseif (-not $Model) {
  Write-Host "[WARN] No model to smoke-test. Run .\scripts\Pull-CodingModels.ps1 -Tier 16GB"
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "RESULT: $failed check(s) failed. See README Case L troubleshooting."
  exit 1
}
Write-Host "RESULT: OK - local setup looks ready."
Write-Host "Next: README Cases H/I (editor), J (Headroom: Install-Headroom.ps1), K (Codegraph)."
exit 0

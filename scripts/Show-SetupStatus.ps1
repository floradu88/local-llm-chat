<#
.SYNOPSIS
  Green / yellow / red dashboard for README Cases A-M (and related checks).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")
Add-OllamaToSessionPath

function Write-Check {
  param([string] $Id, [ValidateSet("OK","WARN","FAIL")][string] $Status, [string] $Detail)
  $color = switch ($Status) { "OK" { "Green" } "WARN" { "Yellow" } "FAIL" { "Red" } }
  Write-Host ("[{0}] {1,-6} {2}" -f $Id, $Status, $Detail) -ForegroundColor $color
}

Write-Host "=== Show-SetupStatus (Cases A-M) ==="
Write-Host "Repo: $RepoRoot"
$ram = Get-SystemRamGB
if ($ram) { Write-Host "RAM: ${ram} GB (Auto tier => $(Resolve-CodingModelTier -Tier Auto))" }
Write-Host ""

# A/C install
if (Test-OllamaCommand) {
  Write-Check "A/C" "OK" "ollama on PATH: $(ollama --version)"
} else {
  Write-Check "A/C" "FAIL" "ollama missing - run Setup-Machine.ps1 or Install-Ollama.ps1"
}

# API
$names = @()
if (Test-OllamaApi) {
  $tags = Invoke-RestMethod http://127.0.0.1:11434/api/tags
  $names = @($tags.models | ForEach-Object { $_.name })
  Write-Check "API" "OK" ("{0} model(s) loaded" -f $names.Count)
} else {
  Write-Check "API" "FAIL" "API down - start Ollama tray app"
}

# D models path
$modelsRoot = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
if (-not $modelsRoot) { $modelsRoot = $env:OLLAMA_MODELS }
if ($modelsRoot) {
  Write-Check "D" "OK" "OLLAMA_MODELS=$modelsRoot"
} else {
  Write-Check "D" "WARN" "OLLAMA_MODELS unset (optional Case D)"
}

# Coding models present?
$codingHints = @("qwen2.5-coder", "starcoder2", "codellama", "deepseek-coder")
$hasCoding = $false
foreach ($n in $names) {
  foreach ($h in $codingHints) {
    if ($n -like "$h*") { $hasCoding = $true; break }
  }
  if ($hasCoding) { break }
}
if ($hasCoding) {
  Write-Check "E/F" "OK" "coding-related model tag found in ollama list"
} elseif ($names.Count -gt 0) {
  Write-Check "E/F" "WARN" "models exist but no coding tags - run Pull-CodingModels.ps1"
} else {
  Write-Check "E/F" "FAIL" "no models - run Pull-CodingModels.ps1 or Setup-Machine.ps1"
}

# H Continue
$continueCfg = Join-Path $HOME ".continue\config.json"
if (Test-Path $continueCfg) {
  Write-Check "H" "OK" "Continue config present: $continueCfg"
} else {
  Write-Check "H" "WARN" "Continue config missing - Install-ContinueConfig.ps1"
}

# I Cursor - cannot auto-detect settings reliably
Write-Check "I" "WARN" "Cursor: manually set base URL http://localhost:11434/v1 (cannot auto-verify)"

# J Headroom
if (Get-Command headroom -ErrorAction SilentlyContinue) {
  Write-Check "J" "OK" "headroom CLI on PATH"
} else {
  Write-Check "J" "WARN" "headroom not installed (optional) - Start-HeadroomOllama.ps1"
}

# K Codegraph
if (Test-Path (Join-Path $RepoRoot ".codegraph")) {
  Write-Check "K" "OK" ".codegraph exists in this repo"
} else {
  Write-Check "K" "WARN" "no .codegraph here (optional) - codegraph init"
}

# L verify script exists
$testScript = Join-Path $PSScriptRoot "Test-LocalSetup.ps1"
if (Test-Path $testScript) {
  Write-Check "L" "OK" "Test-LocalSetup.ps1 available"
} else {
  Write-Check "L" "FAIL" "Test-LocalSetup.ps1 missing"
}

# M URL downloader
if (Test-Path (Join-Path $PSScriptRoot "Download-FromUrl.ps1")) {
  Write-Check "M" "OK" "Download-FromUrl.ps1 available for ModelScope/GitHub"
} else {
  Write-Check "M" "FAIL" "Download-FromUrl.ps1 missing"
}

Write-Host ""
Write-Host "See FEATURES.md and README Cases A-M for next actions."

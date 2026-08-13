<#
.SYNOPSIS
  Green / yellow / red dashboard for README Cases A-O (and related checks).
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

Write-Host "=== Show-SetupStatus (Cases A-O) ==="
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

# H VS Code + Continue
$vsInfo = Get-VSCodeInstallInfo
if ($vsInfo.Installed) {
  Write-Check "H" "OK" ("VS Code installed ({0}): {1}" -f $vsInfo.Scope, $(if ($vsInfo.ExePath) { $vsInfo.ExePath } else { $vsInfo.CmdPath }))
} else {
  Write-Check "H" "WARN" "VS Code missing - install from code.visualstudio.com (User Installer)"
}
$cont = Get-ContinueOllamaConfigStatus
if ($cont.Configured) {
  Write-Check "H-cfg" "OK" ("Continue → {0} models: {1}" -f $cont.ApiBase, ($cont.Models -join ", "))
} else {
  Write-Check "H-cfg" "WARN" "run .\scripts\Install-ContinueConfig.ps1 (or Install-VSCodeConfig.ps1)"
}

# I Cursor
$cursorInfo = Get-CursorInstallInfo
if ($cursorInfo.Installed) {
  Write-Check "I" "OK" ("Cursor installed ({0}): {1}" -f $cursorInfo.Scope, $(if ($cursorInfo.ExePath) { $cursorInfo.ExePath } else { $cursorInfo.CmdPath }))
  $cfg = Get-CursorOllamaConfigStatus
  if ($cfg.Configured) {
    $remoteNote = if ($cfg.RemoteModelsDisabled) { "remote off" } else { "remote still on - re-run Install-CursorConfig.ps1" }
    Write-Check "I-cfg" "OK" ("Models → {0} (key={1}; {2})" -f $cfg.OpenAIBaseUrl, $(if ($cfg.ApiKeyPresent) { "set" } else { "missing" }), $remoteNote)
  } elseif ($cfg.Ok -eq $false -and $cfg.Message -match "state.vscdb missing|Launch Cursor") {
    Write-Check "I-cfg" "WARN" $cfg.Message
  } else {
    Write-Check "I-cfg" "WARN" "run .\scripts\Install-CursorConfig.ps1 then .\scripts\Test-CursorOllama.ps1 (quit Cursor first)"
  }
} else {
  Write-Check "I" "FAIL" "Cursor missing - run .\scripts\Install-Cursor.ps1"
}

# J Headroom
if (Get-Command headroom -ErrorAction SilentlyContinue) {
  Write-Check "J" "OK" "headroom CLI on PATH"
} else {
  Write-Check "J" "WARN" "headroom not installed (optional) - Start-HeadroomOllama.ps1"
}

# K Codegraph
$cgCmd = Get-Command codegraph -ErrorAction SilentlyContinue
if ($cgCmd) {
  Write-Check "K-cli" "OK" ("codegraph CLI: {0}" -f $cgCmd.Source)
} else {
  Write-Check "K-cli" "WARN" "codegraph CLI missing - .\scripts\Install-Codegraph.ps1"
}
if (Test-Path (Join-Path $RepoRoot ".codegraph")) {
  Write-Check "K" "OK" ".codegraph exists in this repo"
} else {
  Write-Check "K" "WARN" "no .codegraph here - .\scripts\Install-Codegraph.ps1 -ProjectPath <repo>"
}

# GPU (non-admin quick)
$gpuScript = Join-Path $PSScriptRoot "Test-GpuSupport.ps1"
$gpuInstall = Join-Path $PSScriptRoot "Install-GpuDrivers.ps1"
if (Test-Path $gpuScript) {
  Write-Check "GPU" "WARN" "run .\scripts\Test-GpuSupport.ps1 (add -Elevated for admin driver check)"
} else {
  Write-Check "GPU" "FAIL" "Test-GpuSupport.ps1 missing"
}
if (Test-Path $gpuInstall) {
  Write-Check "GPU-DRV" "WARN" "optional: .\scripts\Install-GpuDrivers.ps1 (-Install if NVIDIA visible)"
} else {
  Write-Check "GPU-DRV" "FAIL" "Install-GpuDrivers.ps1 missing"
}

# L verify script exists
$testScript = Join-Path $PSScriptRoot "Test-LocalSetup.ps1"
if (Test-Path $testScript) {
  Write-Check "L" "OK" "Test-LocalSetup.ps1 available"
} else {
  Write-Check "L" "FAIL" "Test-LocalSetup.ps1 missing"
}
$cursorTest = Join-Path $PSScriptRoot "Test-CursorOllama.ps1"
if (Test-Path $cursorTest) {
  Write-Check "L-cursor" "OK" "Test-CursorOllama.ps1 available (run for Models + chat smoke)"
} else {
  Write-Check "L-cursor" "FAIL" "Test-CursorOllama.ps1 missing"
}

# M URL downloader
if (Test-Path (Join-Path $PSScriptRoot "Download-FromUrl.ps1")) {
  Write-Check "M" "OK" "Download-FromUrl.ps1 available for ModelScope/GitHub"
} else {
  Write-Check "M" "FAIL" "Download-FromUrl.ps1 missing"
}

Write-Host ""
Write-Host "See FEATURES.md and README Cases A-O for next actions."

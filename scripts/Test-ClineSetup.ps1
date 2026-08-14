<#
.SYNOPSIS
  Verify Cline fully uses this repo's local Ollama setup (config + smoke).

.DESCRIPTION
  Checks that Install-ClineConfig.ps1 / Install-VSCodeLocalAI.ps1 wiring is complete:

    1. providers.json - lastUsedProvider=ollama, model + local baseUrl (/v1)
    2. globalState.json - act + plan modes both ollama, model + local base
    3. providers vs globalState model/base consistency
    4. No remote/cloud providers (unless -AllowRemoteModels)
    5. Configured model exists in ollama list
    6. Optional OpenAI-compatible smoke (same path Cline uses)

.PARAMETER Model
  Smoke model tag. Default: Cline-configured model.

.PARAMETER SkipSmoke
  Skip chat/completions smoke.

.PARAMETER AllowRemoteModels
  Do not fail when remote providers remain in Cline config.

.PARAMETER TimeoutSec
  Smoke timeout. Default: 120.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [switch] $SkipSmoke,
  [switch] $AllowRemoteModels,
  [int] $TimeoutSec = 120
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Check([string] $Level, [string] $Message) {
  Write-Host ("[{0}] {1}" -f $Level, $Message)
}

$failed = 0
$warnings = 0
Write-Host "=== Test-ClineSetup (repo local Ollama wiring) ==="

$paths = Get-ClineDataPaths
$info = Get-VSCodeInstallInfo

if ($info.Installed) {
  Write-Check "OK" ("VS Code installed ({0})" -f $info.Scope)
} else {
  Write-Check "WARN" "VS Code not installed - Cline config can still exist; run .\scripts\Install-VSCode.ps1"
  $warnings++
}

# --- providers.json ---
Write-Host ""
Write-Host "--- providers.json ---"
$provModel = $null
$provBase = $null
$provOk = $false
if (-not (Test-Path -LiteralPath $paths.ProvidersPath)) {
  Write-Check "FAIL" ("Missing: {0}" -f $paths.ProvidersPath)
  Write-Host "     Fix: .\scripts\Install-ClineConfig.ps1 -Force"
  $failed++
} else {
  Write-Check "OK" ("Found: {0}" -f $paths.ProvidersPath)
  try {
    $pcfg = Get-Content -LiteralPath $paths.ProvidersPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($pcfg.lastUsedProvider -eq "ollama") {
      Write-Check "OK" "lastUsedProvider = ollama"
    } else {
      Write-Check "FAIL" ("lastUsedProvider = '{0}' (want ollama)" -f $pcfg.lastUsedProvider)
      $failed++
    }
    if ($pcfg.providers -and $pcfg.providers.ollama -and $pcfg.providers.ollama.settings) {
      $s = $pcfg.providers.ollama.settings
      $provModel = [string]$s.model
      $provBase = [string]$s.baseUrl
      if ($provModel) {
        Write-Check "OK" ("ollama.settings.model = {0}" -f $provModel)
      } else {
        Write-Check "FAIL" "ollama.settings.model empty"
        $failed++
      }
      if ($provBase -and (Test-IsLocalLlmEndpoint $provBase)) {
        Write-Check "OK" ("ollama.settings.baseUrl = {0} (local)" -f $provBase)
        $provOk = [bool]$provModel
      } else {
        Write-Check "FAIL" ("ollama.settings.baseUrl not local: {0}" -f $provBase)
        $failed++
      }
      if ($provBase -and $provBase -notmatch "/v1/?$") {
        Write-Check "WARN" "baseUrl usually ends with /v1 for Cline OpenAI path (Install-ClineConfig writes .../v1)"
        $warnings++
      }
    } else {
      Write-Check "FAIL" "providers.ollama.settings missing"
      $failed++
    }
  } catch {
    Write-Check "FAIL" ("providers.json parse error: {0}" -f $_)
    $failed++
  }
}

# --- globalState.json ---
Write-Host ""
Write-Host "--- globalState.json ---"
$gsActModel = $null
$gsPlanModel = $null
$gsActBase = $null
$gsPlanBase = $null
$gsOk = $false
if (-not (Test-Path -LiteralPath $paths.GlobalStatePath)) {
  Write-Check "FAIL" ("Missing: {0}" -f $paths.GlobalStatePath)
  Write-Host "     Fix: .\scripts\Install-ClineConfig.ps1 -Force"
  $failed++
} else {
  Write-Check "OK" ("Found: {0}" -f $paths.GlobalStatePath)
  try {
    $gs = Get-Content -LiteralPath $paths.GlobalStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $actProv = [string]$gs.actModeApiProvider
    $planProv = [string]$gs.planModeApiProvider
    if ($actProv -eq "ollama") {
      Write-Check "OK" "actModeApiProvider = ollama"
    } else {
      Write-Check "FAIL" ("actModeApiProvider = '{0}' (want ollama)" -f $actProv)
      $failed++
    }
    if ($planProv -eq "ollama") {
      Write-Check "OK" "planModeApiProvider = ollama"
    } else {
      Write-Check "FAIL" ("planModeApiProvider = '{0}' (want ollama)" -f $planProv)
      $failed++
    }
    $gsActModel = [string]$gs.actModeOllamaModelId
    $gsPlanModel = [string]$gs.planModeOllamaModelId
    $gsActBase = [string]$(if ($gs.actModeOllamaBaseUrl) { $gs.actModeOllamaBaseUrl } else { $gs.ollamaBaseUrl })
    $gsPlanBase = [string]$(if ($gs.planModeOllamaBaseUrl) { $gs.planModeOllamaBaseUrl } else { $gs.ollamaBaseUrl })
    if ($gsActModel) {
      Write-Check "OK" ("actModeOllamaModelId = {0}" -f $gsActModel)
    } else {
      Write-Check "FAIL" "actModeOllamaModelId empty"
      $failed++
    }
    if ($gsPlanModel) {
      Write-Check "OK" ("planModeOllamaModelId = {0}" -f $gsPlanModel)
    } else {
      Write-Check "FAIL" "planModeOllamaModelId empty"
      $failed++
    }
    if ($gsActBase -and (Test-IsLocalLlmEndpoint $gsActBase)) {
      Write-Check "OK" ("act base = {0} (local)" -f $gsActBase)
    } else {
      Write-Check "FAIL" ("act Ollama base not local: {0}" -f $gsActBase)
      $failed++
    }
    if ($gsPlanBase -and (Test-IsLocalLlmEndpoint $gsPlanBase)) {
      Write-Check "OK" ("plan base = {0} (local)" -f $gsPlanBase)
    } else {
      Write-Check "FAIL" ("plan Ollama base not local: {0}" -f $gsPlanBase)
      $failed++
    }
    $gsOk = ($actProv -eq "ollama" -and $planProv -eq "ollama" -and $gsActModel -and $gsPlanModel -and
      (Test-IsLocalLlmEndpoint $gsActBase) -and (Test-IsLocalLlmEndpoint $gsPlanBase))
  } catch {
    Write-Check "FAIL" ("globalState.json parse error: {0}" -f $_)
    $failed++
  }
}

# --- consistency (fully wired by this repo) ---
Write-Host ""
Write-Host "--- providers vs globalState consistency ---"
$status = Get-ClineOllamaConfigStatus
$provRoot = if ($provBase) { $provBase.TrimEnd("/") -replace "/v1$", "" } else { "" }
$gsRoot = if ($gsActBase) { $gsActBase.TrimEnd("/") -replace "/v1$", "" } else { "" }
if ($provOk -and $gsOk) {
  if ($gsActModel -eq $gsPlanModel) {
    Write-Check "OK" "act and plan models match"
  } else {
    Write-Check "FAIL" ("act model '{0}' != plan model '{1}'" -f $gsActModel, $gsPlanModel)
    $failed++
  }
  if ($provModel -and $gsActModel -and ($provModel -eq $gsActModel)) {
    Write-Check "OK" ("providers model matches globalState ({0})" -f $provModel)
  } else {
    Write-Check "FAIL" ("providers model '{0}' != globalState '{1}' - re-run Install-ClineConfig.ps1 -Force" -f $provModel, $gsActModel)
    $failed++
  }
  if ($provRoot -and $gsRoot -and ($provRoot -eq $gsRoot)) {
    Write-Check "OK" ("base roots match ({0})" -f $provRoot)
  } elseif ($provRoot -or $gsRoot) {
    Write-Check "FAIL" ("base root mismatch providers='{0}' vs globalState='{1}'" -f $provRoot, $gsRoot)
    $failed++
  }
  Write-Check "OK" "Cline fully uses repo local setup (both config files)"
} elseif ($status.Configured) {
  Write-Check "WARN" ("Partial Cline config ({0}) - prefer both providers.json + globalState from Install-ClineConfig.ps1" -f $status.Source)
  $warnings++
} else {
  Write-Check "FAIL" "Cline not fully wired to local Ollama"
  $failed++
}

# --- local-only ---
Write-Host ""
Write-Host "--- local-only ---"
if ($status.LocalOnly) {
  Write-Check "OK" "No remote/cloud providers in Cline config"
} elseif ($status.Configured -or $provOk -or $gsOk) {
  if ($AllowRemoteModels) {
    Write-Check "WARN" ("Remotes still on: {0}" -f ($status.RemoteProviders -join ", "))
    $warnings++
  } else {
    Write-Check "FAIL" ("Remotes still on: {0}" -f ($status.RemoteProviders -join ", "))
    Write-Host "     Fix: .\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor"
    $failed++
  }
}

# --- Ollama + model ---
Write-Host ""
Write-Host "--- Ollama ---"
Add-OllamaToSessionPath
$ollamaNames = @()
if (Test-OllamaApi) {
  try {
    $tags = Invoke-RestMethod http://127.0.0.1:11434/api/tags
    $ollamaNames = @($tags.models | ForEach-Object { $_.name })
    Write-Check "OK" ("Ollama API up - {0} model(s)" -f $ollamaNames.Count)
  } catch {
    Write-Check "FAIL" "Ollama /api/tags failed: $_"
    $failed++
  }
} else {
  Write-Check "FAIL" "Ollama API not reachable at http://127.0.0.1:11434"
  $failed++
}

$cfgModel = if ($provModel) { $provModel } elseif ($gsActModel) { $gsActModel } else { $status.Model }
if ($cfgModel -and $ollamaNames.Count -gt 0) {
  if ($ollamaNames -contains $cfgModel) {
    Write-Check "OK" ("Configured model in ollama list: {0}" -f $cfgModel)
  } else {
    Write-Check "FAIL" ("Configured model '{0}' not in ollama list - pull it or re-run Install-ClineConfig.ps1" -f $cfgModel)
    $failed++
  }
}

# --- smoke ---
if (-not $SkipSmoke -and ($provOk -or $status.Configured)) {
  Write-Host ""
  Write-Host "--- smoke (OpenAI path Cline uses) ---"
  $smokeModel = if ($Model) { $Model } elseif ($cfgModel) { $cfgModel } elseif ($ollamaNames.Count -gt 0) { $ollamaNames[0] } else { "" }
  if (-not $smokeModel) {
    Write-Check "FAIL" "No model for smoke"
    $failed++
  } else {
    $root = if ($provRoot) { $provRoot } elseif ($gsRoot) { $gsRoot } elseif ($status.BaseUrl) {
      $status.BaseUrl.TrimEnd("/") -replace "/v1$", ""
    } else { "http://127.0.0.1:11434" }
    $uri = "$root/v1/chat/completions"
    Write-Host ("POST {0} model={1}" -f $uri, $smokeModel)
    try {
      $body = @{
        model      = $smokeModel
        messages   = @(@{ role = "user"; content = "Reply with exactly: ok" })
        max_tokens = 8
        stream     = $false
      } | ConvertTo-Json -Depth 5 -Compress
      $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer ollama" } -TimeoutSec $TimeoutSec
      $snippet = (($resp.choices[0].message.content -replace "\s+", " ").Trim())
      if (-not $snippet) { $snippet = "(empty)" }
      if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + "..." }
      Write-Check "OK" ("chat/completions: {0}" -f $snippet)
    } catch {
      Write-Check "FAIL" ("Smoke failed: {0}" -f $_)
      if ($root -match "8787") {
        Write-Host "     Tip: .\scripts\Install-Headroom.ps1 then .\scripts\Start-HeadroomOllama.ps1"
      }
      $failed++
    }
  }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host ('RESULT: {0} check(s) failed ({1} warning(s)).' -f $failed, $warnings)
  Write-Host "Fix: .\scripts\Install-ClineConfig.ps1 -Force"
  Write-Host "     or .\scripts\Install-VSCodeLocalAI.ps1 -Force"
  Write-Host "Full VS Code: .\scripts\Test-VSCodeSetup.ps1"
  exit 1
}

Write-Host "RESULT: Cline uses the repo local setup."
if ($warnings -gt 0) {
  Write-Host ('({0} warning(s) - review above)' -f $warnings)
}
exit 0

<#
.SYNOPSIS
  Disable remote/cloud AI providers for Cursor + VS Code (Continue/Cline) and optionally Ollama cloud.

.DESCRIPTION
  Local-only enforcement:
    - Cursor: disable catalog/cloud models (Install-CursorConfig -DisableRemote path)
    - Continue: strip non-local models from ~/.continue/config.json; telemetry off;
      neutralize config.yaml cloud refs when present
    - Cline: keep only ollama (local) in ~/.cline providers + act/plan modes
    - VS Code / Cursor settings.json: disable GitHub Copilot + built-in chat AI features
    - Ollama: OLLAMA_NO_CLOUD=1 + ~/.ollama/server.json disable_ollama_cloud (unless -KeepOllamaCloud)

  Does not uninstall extensions. Opt out pieces with -Skip* / -KeepRemoteModels.

.PARAMETER CheckOnly
  Report local-only status; exit 0 if all targeted surfaces are local-only.

.PARAMETER SkipCursor
  Do not touch Cursor state.vscdb.

.PARAMETER SkipContinue
  Do not sanitize Continue config.

.PARAMETER SkipCline
  Do not sanitize Cline providers.

.PARAMETER SkipEditorSettings
  Do not write Copilot/chat disable keys to settings.json.

.PARAMETER KeepRemoteModels
  Cursor: leave cloud catalog models enabled.

.PARAMETER KeepOllamaCloud
  Do not set OLLAMA_NO_CLOUD / server.json flag.

.PARAMETER Force
  Pass -Force through to Cursor config (needed if Cursor is running).

.PARAMETER Headroom
  Prefer Headroom :8787 when (re)wiring Cursor/Continue/Cline.
#>
[CmdletBinding()]
param(
  [switch] $CheckOnly,
  [switch] $SkipCursor,
  [switch] $SkipContinue,
  [switch] $SkipCline,
  [switch] $SkipEditorSettings,
  [switch] $KeepRemoteModels,
  [switch] $KeepOllamaCloud,
  [switch] $Force,
  [switch] $Headroom
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

function Write-Check([string] $Level, [string] $Message) {
  Write-Host ("[{0}] {1}" -f $Level, $Message)
}

function Backup-TextFile([string] $Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $dir = Join-Path (Split-Path -Parent $Path) "local-llm-chat-backups"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $dest = Join-Path $dir ("{0}.{1}.bak" -f (Split-Path -Leaf $Path), $stamp)
  Copy-Item -LiteralPath $Path -Destination $dest -Force
  return $dest
}

function Disable-ContinueRemoteProviders {
  $info = Get-VSCodeInstallInfo
  $path = $info.ContinueConfig
  $yamlPath = Join-Path $info.ContinueDir "config.yaml"
  $changed = $false

  if (Test-Path -LiteralPath $path) {
    Backup-TextFile $path | Out-Null
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $kept = @()
    foreach ($m in @($cfg.models)) {
      if (Test-ContinueModelEntryIsLocal $m) { $kept += $m }
    }
    if ($kept.Count -eq 0) {
      Write-Warning "Continue had no local models left after filter; re-run Install-ContinueConfig.ps1 -Force"
    } else {
      $tab = $cfg.tabAutocompleteModel
      if (-not (Test-ContinueModelEntryIsLocal $tab)) {
        $first = $kept[0]
        $tab = @{
          title    = ("Autocomplete ({0})" -f $first.model)
          provider = [string]$first.provider
          model    = [string]$first.model
          apiBase  = [string]$first.apiBase
        }
        if ($first.apiKey) { $tab["apiKey"] = [string]$first.apiKey }
      }
      $modelParts = @()
      foreach ($e in $kept) {
        $modelParts += ($e | ConvertTo-Json -Compress -Depth 8)
      }
      $tabJson = $tab | ConvertTo-Json -Compress -Depth 8
      $json = "{`"models`":[`n  " + ($modelParts -join ",`n  ") + "`n],`"tabAutocompleteModel`":" + $tabJson + ",`"allowAnonymousTelemetry`":false`n}"
      [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
      $changed = $true
    }
  } else {
    Write-Warning "Continue config missing - run Install-ContinueConfig.ps1"
  }

  if (Test-Path -LiteralPath $yamlPath) {
    Backup-TextFile $yamlPath | Out-Null
    $raw = Get-Content -LiteralPath $yamlPath -Raw -Encoding UTF8
    $blocked = $false
    foreach ($hostPat in @("api.openai.com", "api.anthropic.com", "openrouter.ai", "api.x.ai", "api.groq.com", "generativelanguage.googleapis")) {
      if ($raw -like "*$hostPat*") { $blocked = $true; break }
    }
    if ($blocked -or $raw -match "provider:\s*(anthropic|gemini|groq|xai|openrouter|bedrock|openai)\b") {
      $note = @"
# Neutralized by local-llm-chat Disable-RemoteAIProviders.ps1
# Previous config.yaml backed up beside this file.
# Use config.json (Ollama/local only). Remove this file or replace with local models.
name: Local only
version: 1.0.0
schema: v1
models: []
"@
      [System.IO.File]::WriteAllText($yamlPath, $note, [System.Text.UTF8Encoding]::new($false))
      $changed = $true
      Write-Host "  Neutralized cloud refs in config.yaml (prefer config.json)"
    }
  }

  return $changed
}

function Disable-ClineRemoteProviders {
  $paths = Get-ClineDataPaths
  $status = Get-ClineOllamaConfigStatus
  $model = if ($status.Model) { $status.Model } else {
    try { @(Get-OllamaInstalledModelNames | Where-Object { $_ -notmatch "embed" } | Select-Object -First 1)[0] } catch { "qwen2.5-coder:7b" }
  }
  $baseRoot = if ($Headroom) { "http://127.0.0.1:8787" } else { "http://localhost:11434" }
  if ($status.BaseUrl -and (Test-IsLocalLlmEndpoint $status.BaseUrl)) {
    $baseRoot = $status.BaseUrl.TrimEnd("/") -replace "/v1$", ""
  }
  $providerBase = "$baseRoot/v1"

  New-Item -ItemType Directory -Force -Path $paths.SettingsDir | Out-Null
  if (Test-Path -LiteralPath $paths.ProvidersPath) { Backup-TextFile $paths.ProvidersPath | Out-Null }
  if (Test-Path -LiteralPath $paths.GlobalStatePath) { Backup-TextFile $paths.GlobalStatePath | Out-Null }

  $providers = @{
    version          = 1
    lastUsedProvider = "ollama"
    providers        = @{
      ollama = @{
        tokenSource = "manual"
        updatedAt   = (Get-Date).ToUniversalTime().ToString("o")
        settings    = @{
          provider = "ollama"
          model    = $model
          baseUrl  = $providerBase
        }
      }
    }
  }
  [System.IO.File]::WriteAllText($paths.ProvidersPath, ($providers | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

  $gsObj = [ordered]@{
    ollamaBaseUrl         = $baseRoot
    actModeApiProvider    = "ollama"
    actModeOllamaModelId  = $model
    actModeOllamaBaseUrl  = $baseRoot
    planModeApiProvider   = "ollama"
    planModeOllamaModelId = $model
    planModeOllamaBaseUrl = $baseRoot
    welcomeViewCompleted  = $true
  }
  if (Test-Path -LiteralPath $paths.GlobalStatePath) {
    try {
      $gs = Get-Content -LiteralPath $paths.GlobalStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $gs.PSObject.Properties) {
        if (-not $gsObj.Contains($p.Name)) { $gsObj[$p.Name] = $p.Value }
      }
    } catch { }
  }
  # Force local providers even if preserved keys had cloud ids
  $gsObj["actModeApiProvider"] = "ollama"
  $gsObj["planModeApiProvider"] = "ollama"
  $gsObj["actModeOllamaModelId"] = $model
  $gsObj["planModeOllamaModelId"] = $model
  $gsObj["actModeOllamaBaseUrl"] = $baseRoot
  $gsObj["planModeOllamaBaseUrl"] = $baseRoot
  $gsObj["ollamaBaseUrl"] = $baseRoot
  [System.IO.File]::WriteAllText($paths.GlobalStatePath, ($gsObj | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
  return $true
}

Write-Section "Disable remote AI providers (local-only)"

$failed = 0
$cursorStatus = $null
$contStatus = $null
$clineStatus = $null

if (-not $SkipCursor) {
  $cursorStatus = Get-CursorOllamaConfigStatus
  Write-Check $(if ($cursorStatus.RemoteModelsDisabled) { "OK" } else { "WARN" }) (
    "Cursor remote/catalog disabled: {0}" -f $(if ($null -ne $cursorStatus.RemoteModelsDisabled) { $cursorStatus.RemoteModelsDisabled } else { "unknown" })
  )
}
if (-not $SkipContinue) {
  $contRemote = Get-ContinueRemoteProviderStatus
  Write-Check $(if ($contRemote.LocalOnly) { "OK" } else { "WARN" }) (
    "Continue local-only: {0} (remote entries: {1})" -f $contRemote.LocalOnly, $(if ($contRemote.RemoteEntries.Count) { $contRemote.RemoteEntries -join ", " } else { "none" })
  )
}
if (-not $SkipCline) {
  $clineStatus = Get-ClineOllamaConfigStatus
  Write-Check $(if ($clineStatus.LocalOnly) { "OK" } else { "WARN" }) (
    "Cline local-only: {0} (remote: {1})" -f $clineStatus.LocalOnly, $(if ($clineStatus.RemoteProviders.Count) { $clineStatus.RemoteProviders -join ", " } else { "none" })
  )
}

if ($CheckOnly) {
  if (-not $SkipCursor -and -not $cursorStatus.RemoteModelsDisabled) { $failed++ }
  if (-not $SkipContinue) {
    $cr = Get-ContinueRemoteProviderStatus
    if (-not $cr.LocalOnly) { $failed++ }
  }
  if (-not $SkipCline -and -not (Get-ClineOllamaConfigStatus).LocalOnly) { $failed++ }
  if ($failed -gt 0) {
    Write-Host "CheckOnly: not fully local-only - re-run without -CheckOnly"
    exit 1
  }
  Write-Host "CheckOnly: targeted surfaces look local-only"
  exit 0
}

# Apply
if (-not $SkipCursor -and -not $KeepRemoteModels) {
  Write-Section "Cursor cloud/catalog models"
  $cArgs = @{}
  if ($Force) { $cArgs["Force"] = $true }
  if ($Headroom) { $cArgs["Headroom"] = $true }
  try {
    & (Join-Path $PSScriptRoot "Install-CursorConfig.ps1") @cArgs
  } catch {
    Write-Warning "Cursor remote disable skipped: $_"
    Write-Host "  Quit Cursor and run: .\scripts\Install-CursorConfig.ps1"
    $failed++
  }
}

if (-not $SkipContinue) {
  Write-Section "Continue (strip remote providers)"
  try {
    if (Disable-ContinueRemoteProviders) {
      Write-Host "  Continue config sanitized (telemetry off, local models only)"
    }
  } catch {
    Write-Warning "Continue sanitize failed: $_"
    $failed++
  }
}

if (-not $SkipCline) {
  Write-Section "Cline (ollama-only providers)"
  try {
    [void](Disable-ClineRemoteProviders)
    Write-Host "  Cline providers.json + globalState forced to local Ollama"
  } catch {
    Write-Warning "Cline sanitize failed: $_"
    $failed++
  }
}

if (-not $SkipEditorSettings) {
  Write-Section "Editor settings (disable Copilot / built-in chat AI)"
  $settings = Get-EditorLocalOnlySettingsHashtable
  $vs = Get-VSCodeInstallInfo
  if ($vs.SettingsPath) {
    try {
      Merge-JsonSettingsFile -Path $vs.SettingsPath -Settings $settings
      Write-Host ("  Wrote {0}" -f $vs.SettingsPath)
    } catch {
      Write-Warning "VS Code settings merge failed: $_"
      $failed++
    }
  }
  $cu = Get-CursorInstallInfo
  $cursorSettings = Join-Path $cu.UserDataPath "User\settings.json"
  if ($cu.Installed) {
    try {
      Merge-JsonSettingsFile -Path $cursorSettings -Settings $settings
      Write-Host ("  Wrote {0}" -f $cursorSettings)
    } catch {
      Write-Warning "Cursor settings merge failed: $_"
      $failed++
    }
  }
}

if (-not $KeepOllamaCloud) {
  Write-Section "Ollama cloud"
  try {
    $serverJson = Set-OllamaCloudDisabled -Persistent
    Write-Host "  OLLAMA_NO_CLOUD=1 (User) + $serverJson"
    Write-Host "  Restart Ollama tray app for cloud disable to fully apply."
  } catch {
    Write-Warning "Ollama cloud disable failed: $_"
    $failed++
  }
}

Write-Section "Verify"
$okCursor = $true
$okCont = $true
$okCline = $true
if (-not $SkipCursor -and -not $KeepRemoteModels) {
  $cs = Get-CursorOllamaConfigStatus
  $okCursor = [bool]$cs.RemoteModelsDisabled
  Write-Check $(if ($okCursor) { "OK" } else { "FAIL" }) ("Cursor remote disabled: {0}" -f $okCursor)
  if (-not $okCursor) { $failed++ }
}
if (-not $SkipContinue) {
  $cr = Get-ContinueRemoteProviderStatus
  $okCont = [bool]$cr.LocalOnly
  Write-Check $(if ($okCont) { "OK" } else { "FAIL" }) ("Continue local-only: {0}" -f $okCont)
  if (-not $okCont) { $failed++ }
}
if (-not $SkipCline) {
  $cl = Get-ClineOllamaConfigStatus
  $okCline = [bool]$cl.LocalOnly
  Write-Check $(if ($okCline) { "OK" } else { "FAIL" }) ("Cline local-only: {0}" -f $okCline)
  if (-not $okCline) { $failed++ }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "RESULT: $failed issue(s). Fix Cursor (quit app) / Continue / Cline, then re-run."
  exit 1
}
Write-Host "RESULT: OK - remote/cloud providers disabled for targeted Cursor + VS Code surfaces."
Write-Host "Reload VS Code / Cursor. Note: Cursor account features may still exist; Models catalog is toggled off."
exit 0

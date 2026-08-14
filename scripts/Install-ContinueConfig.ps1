<#
.SYNOPSIS
  Find installed VS Code and wire Continue → local Ollama models (ChatGPT-like chat + autocomplete).

.DESCRIPTION
  Locates Code.exe / code CLI, optionally installs the Continue extension, and writes
  %USERPROFILE%\.continue\config.json with models from ollama list (or -Models).

  Mirrors Install-CursorConfig.ps1 for the VS Code + Continue path.

.PARAMETER ApiBase
  Continue apiBase. Default for Ollama provider: http://localhost:11434
  (no /v1). With -Headroom, uses http://127.0.0.1:8787/v1 and provider openai.

.PARAMETER Models
  Model tags to put in Continue config. Default: installed Ollama tags
  (falls back to README examples).

.PARAMETER Headroom
  Point Continue at Headroom OpenAI-compatible proxy (provider openai).

.PARAMETER Force
  Overwrite existing ~/.continue/config.json.

.PARAMETER CheckOnly
  Report VS Code path + Continue config status; exit 0 if configured, 1 otherwise.

.PARAMETER SkipExtension
  Do not run `code --install-extension Continue.continue`.

.PARAMETER AutocompleteModel
  Optional tab-autocomplete model tag. Default: smallest coding tag found, else first model.
#>
[CmdletBinding()]
param(
  [string] $ApiBase = "http://localhost:11434",
  [string[]] $Models = @(),
  [switch] $Headroom,
  [switch] $Force,
  [switch] $CheckOnly,
  [switch] $SkipExtension,
  [string] $AutocompleteModel = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

function Get-ContinueSystemMessage([string] $Model) {
  return ("You are a local coding assistant via Ollama ({0}). For local-llm-chat setup tasks, follow AGENTS.md and prefer scripts under scripts/ (Setup-Machine.ps1). Only use trusted model sources from docs/trusted-sources.md." -f $Model)
}

function New-ContinueModelEntry {
  param(
    [string] $Model,
    [string] $ApiBase,
    [string] $Provider,
    [string] $ApiKey = ""
  )
  $title = if ($Provider -eq "openai") {
    "{0} (Headroom/OpenAI → Ollama)" -f $Model
  } else {
    "{0} (Ollama)" -f $Model
  }
  $entry = @{
    title         = $title
    provider      = $Provider
    model         = $Model
    apiBase       = $ApiBase
    systemMessage = (Get-ContinueSystemMessage -Model $Model)
  }
  if ($Provider -eq "openai" -and $ApiKey) {
    $entry["apiKey"] = $ApiKey
  }
  return $entry
}

if ($Headroom) {
  $ApiBase = "http://127.0.0.1:8787/v1"
}

$provider = if ($Headroom -or $ApiBase -match "8787") { "openai" } else { "ollama" }
# Ollama provider expects host without /v1; OpenAI-compatible expects /v1
if ($provider -eq "ollama") {
  $ApiBase = $ApiBase.TrimEnd("/") -replace "/v1$", ""
} else {
  $ApiBase = $ApiBase.TrimEnd("/")
  if ($ApiBase -notmatch "/v1$") { $ApiBase = "$ApiBase/v1" }
}

$info = Get-VSCodeInstallInfo
Write-Section "VS Code install"
Write-Host ("  Installed:  {0}" -f $info.Installed)
Write-Host ("  Scope:      {0}" -f $info.Scope)
if ($info.Insiders) { Write-Host "  Edition:    Insiders" }
if ($info.ExePath) { Write-Host ("  Exe:        {0}" -f $info.ExePath) }
if ($info.CmdPath) { Write-Host ("  CLI:        {0}" -f $info.CmdPath) }
Write-Host ("  User data:  {0}" -f $info.UserDataPath)
Write-Host ("  Continue:   {0}" -f $info.ContinueConfig)

$status = Get-ContinueOllamaConfigStatus
Write-Section "Current Continue config"
Write-Host ("  Configured: {0}" -f $status.Configured)
Write-Host ("  ApiBase:    {0}" -f $(if ($status.ApiBase) { $status.ApiBase } else { "(none)" }))
if ($status.Models.Count -gt 0) {
  Write-Host ("  Models:     {0}" -f ($status.Models -join ", "))
}
if ($status.Message) { Write-Host ("  Note:       {0}" -f $status.Message) }

if ($CheckOnly) {
  if (-not $info.Installed) {
    Write-Host "  CheckOnly: VS Code not found"
    exit 1
  }
  if ($status.Configured) {
    Write-Host "  CheckOnly: Continue looks configured for local models"
    exit 0
  }
  Write-Host "  CheckOnly: not configured - re-run without -CheckOnly"
  exit 1
}

if (-not $info.Installed) {
  Write-Warning "VS Code not found. Install from https://code.visualstudio.com/ (User Installer) then re-run."
  Write-Host "Continue config can still be written without VS Code; extension install will be skipped."
}

# Resolve models
$modelList = @($Models | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
if ($modelList.Count -eq 0) {
  try {
    $modelList = @(Get-OllamaInstalledModelNames | Where-Object {
      $_ -notmatch "embed|nomic-embed"
    })
  } catch { }
}
if ($modelList.Count -eq 0) {
  $modelList = @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b")
  Write-Warning "No local Ollama tags found; writing README example names (pull them if missing)."
}

$autoModel = $AutocompleteModel.Trim()
if (-not $autoModel) {
  $small = @($modelList | Where-Object { $_ -match ":3b\b|:1\.|tiny|mini" } | Select-Object -First 1)
  if ($small) { $autoModel = [string]$small[0] } else { $autoModel = $modelList[0] }
}

# Extension
if (-not $SkipExtension -and $info.CmdPath) {
  Write-Section "Continue extension"
  Write-Host "  Installing Continue.continue via VS Code CLI..."
  $prevEa = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $info.CmdPath --install-extension Continue.continue --force 2>&1 | ForEach-Object { Write-Host ("  {0}" -f $_) }
    $extExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEa
  }
  if ($extExit -ne 0) {
    Write-Warning "Extension install exited $extExit - install Continue manually from the marketplace, then reload VS Code."
  } else {
    Write-Host "  Continue extension OK"
  }
} elseif (-not $SkipExtension) {
  Write-Warning "No code CLI found - skip extension install. In VS Code: Extensions → search Continue."
}

# Write config
$dest = $info.ContinueConfig
$destDir = $info.ContinueDir
if ((Test-Path -LiteralPath $dest) -and -not $Force) {
  Write-Warning "Already exists: $dest"
  Write-Host "Re-run with -Force to overwrite, or merge manually."
  Write-Host "Target models would be: $($modelList -join ', ')"
  exit 0
}

Write-Section "Write Continue config"
Write-Host ("  Provider: {0}" -f $provider)
Write-Host ("  ApiBase:  {0}" -f $ApiBase)
Write-Host ("  Models:   {0}" -f ($modelList -join ", "))
Write-Host ("  Autocomplete: {0}" -f $autoModel)

$entries = @()
foreach ($m in $modelList) {
  $entries += ,(New-ContinueModelEntry -Model $m -ApiBase $ApiBase -Provider $provider -ApiKey "ollama")
}

$tabAutocomplete = @{
  title    = ("Autocomplete ({0})" -f $autoModel)
  provider = $provider
  model    = $autoModel
  apiBase  = $ApiBase
}
if ($provider -eq "openai") {
  $tabAutocomplete["apiKey"] = "ollama"
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

# Build JSON without JavaScriptSerializer (PS hashtables can circular-ref under it)
$modelJsonParts = @()
foreach ($e in $entries) {
  $modelJsonParts += ($e | ConvertTo-Json -Compress -Depth 6)
}
$tabJson = $tabAutocomplete | ConvertTo-Json -Compress -Depth 6
$json = "{`"models`":[`n  " + ($modelJsonParts -join ",`n  ") + "`n],`"tabAutocompleteModel`":" + $tabJson + ",`"allowAnonymousTelemetry`":false`n}"

[System.IO.File]::WriteAllText($dest, $json, [System.Text.UTF8Encoding]::new($false))

Write-Section "Done"
Write-Host "Wrote $dest (local models only; allowAnonymousTelemetry=false)"
Write-Host "Reload VS Code, open Continue (ChatGPT-like chat), and select an Ollama model."
Write-Host "Tab autocomplete uses: $autoModel"
Write-Host "Disable remotes (Cursor+VS Code): .\scripts\Disable-RemoteAIProviders.ps1"
Write-Host "For Cursor-like agent in VS Code: .\scripts\Install-ClineConfig.ps1"
Write-Host "Full stack + verify: .\scripts\Install-VSCodeLocalAI.ps1"
Write-Host "Verify Continue: .\scripts\Test-ContinueOllama.ps1"
Write-Host "Full VS Code check: .\scripts\Test-VSCodeSetup.ps1"
exit 0

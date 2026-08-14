<#
.SYNOPSIS
  Find VS Code and wire Cline → local Ollama (Cursor-like agent).

.DESCRIPTION
  Installs the Cline extension (saoudrizwan.claude-dev) when possible and writes
  Ollama provider settings the same way `ollama launch cline` does:
    %USERPROFILE%\.cline\data\settings\providers.json
    %USERPROFILE%\.cline\data\globalState.json

.PARAMETER BaseUrl
  Ollama root URL (no /v1). Default: http://localhost:11434
  providers.json stores BaseUrl + /v1 (OpenAI-compatible).

.PARAMETER Model
  Ollama tag for act/plan modes. Default: first installed coding tag.

.PARAMETER Headroom
  Point Cline at Headroom OpenAI proxy (http://127.0.0.1:8787).

.PARAMETER Force
  Overwrite existing Cline Ollama settings.

.PARAMETER CheckOnly
  Report status; exit 0 if configured for local Ollama.

.PARAMETER SkipExtension
  Do not install the Cline marketplace extension.
#>
[CmdletBinding()]
param(
  [string] $BaseUrl = "http://localhost:11434",
  [string] $Model = "",
  [switch] $Headroom,
  [switch] $Force,
  [switch] $CheckOnly,
  [switch] $SkipExtension
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

if ($Headroom) {
  $BaseUrl = "http://127.0.0.1:8787"
}

$BaseUrl = $BaseUrl.TrimEnd("/") -replace "/v1$", ""
$providerBase = "$BaseUrl/v1"

$info = Get-VSCodeInstallInfo
$paths = Get-ClineDataPaths
Write-Section "VS Code / Cline paths"
Write-Host ("  VS Code:        {0}" -f $info.Installed)
if ($info.CmdPath) { Write-Host ("  CLI:            {0}" -f $info.CmdPath) }
Write-Host ("  providers.json: {0}" -f $paths.ProvidersPath)
Write-Host ("  globalState:    {0}" -f $paths.GlobalStatePath)

$status = Get-ClineOllamaConfigStatus
Write-Section "Current Cline config"
Write-Host ("  Configured: {0}" -f $status.Configured)
Write-Host ("  Model:      {0}" -f $(if ($status.Model) { $status.Model } else { "(none)" }))
Write-Host ("  Base URL:   {0}" -f $(if ($status.BaseUrl) { $status.BaseUrl } else { "(none)" }))
Write-Host ("  Source:     {0}" -f $(if ($status.Source) { $status.Source } else { "(none)" }))

if ($CheckOnly) {
  if ($status.Configured) {
    Write-Host "  CheckOnly: Cline looks wired to local Ollama"
    Write-Host "  Deeper check: .\scripts\Test-ClineSetup.ps1"
    exit 0
  }
  Write-Host "  CheckOnly: not configured - re-run without -CheckOnly"
  exit 1
}

if ($status.Configured -and -not $Force) {
  Write-Warning "Cline already configured for local Ollama ($($status.Model)). Re-run with -Force to overwrite."
  exit 0
}

# Resolve model
$modelTag = $Model.Trim()
if (-not $modelTag) {
  try {
    $modelTag = @(Get-OllamaInstalledModelNames | Where-Object {
      $_ -notmatch "embed|nomic-embed"
    } | Select-Object -First 1)[0]
  } catch { }
}
if (-not $modelTag) {
  $modelTag = "qwen2.5-coder:7b"
  Write-Warning "No local Ollama tags found; using $modelTag (pull it if missing)."
}

# Extension
if (-not $SkipExtension -and $info.CmdPath) {
  Write-Section "Cline extension"
  Write-Host "  Installing saoudrizwan.claude-dev via VS Code CLI..."
  $prevEa = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $info.CmdPath --install-extension saoudrizwan.claude-dev --force 2>&1 | ForEach-Object { Write-Host ("  {0}" -f $_) }
    $extExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEa
  }
  if ($extExit -ne 0) {
    Write-Warning "Extension install exited $extExit - install Cline from the marketplace, then reload VS Code."
  } else {
    Write-Host "  Cline extension OK"
  }
} elseif (-not $SkipExtension) {
  Write-Warning "No code CLI - skip extension. In VS Code: Extensions → search Cline (saoudrizwan.claude-dev)."
}

Write-Section "Write Cline Ollama config"
Write-Host ("  Model:         {0}" -f $modelTag)
Write-Host ("  Ollama root:   {0}" -f $BaseUrl)
Write-Host ("  Provider URL:  {0}" -f $providerBase)

New-Item -ItemType Directory -Force -Path $paths.SettingsDir | Out-Null

# providers.json (modern; matches ollama launch cline)
$providers = @{
  version           = 1
  lastUsedProvider  = "ollama"
  providers         = @{
    ollama = @{
      tokenSource = "manual"
      updatedAt   = (Get-Date).ToUniversalTime().ToString("o")
      settings    = @{
        provider = "ollama"
        model    = $modelTag
        baseUrl  = $providerBase
      }
    }
  }
}
$providersJson = $providers | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($paths.ProvidersPath, $providersJson, [System.Text.UTF8Encoding]::new($false))

# globalState.json (legacy act/plan mode keys)
$gs = @{}
if (Test-Path -LiteralPath $paths.GlobalStatePath) {
  try {
    $gs = Get-Content -LiteralPath $paths.GlobalStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    # Convert PSCustomObject to hashtable-ish via JSON roundtrip for mutation
    $gs = $gs | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  } catch {
    $gs = @{}
  }
}

# Build a fresh object we control
$gsObj = [ordered]@{
  ollamaBaseUrl           = $BaseUrl
  actModeApiProvider      = "ollama"
  actModeOllamaModelId    = $modelTag
  actModeOllamaBaseUrl    = $BaseUrl
  planModeApiProvider     = "ollama"
  planModeOllamaModelId   = $modelTag
  planModeOllamaBaseUrl   = $BaseUrl
  welcomeViewCompleted    = $true
}
# Preserve other keys from existing globalState when possible
if ($gs -is [System.Management.Automation.PSCustomObject]) {
  foreach ($p in $gs.PSObject.Properties) {
    if (-not $gsObj.Contains($p.Name)) {
      $gsObj[$p.Name] = $p.Value
    }
  }
}
$gsJson = ($gsObj | ConvertTo-Json -Depth 20)
[System.IO.File]::WriteAllText($paths.GlobalStatePath, $gsJson, [System.Text.UTF8Encoding]::new($false))

Write-Section "Done"
Write-Host "Wrote providers.json + globalState.json for Ollama."
Write-Host "Reload VS Code, open Cline, confirm Provider=Ollama and model=$modelTag."
Write-Host "Tip: set Context Window >= 32k in Cline settings for agent work."
Write-Host "Disable remotes (Cursor+VS Code): .\scripts\Disable-RemoteAIProviders.ps1"
Write-Host "Verify: .\scripts\Test-ClineSetup.ps1"
Write-Host "Full VS Code: .\scripts\Test-VSCodeSetup.ps1"
exit 0

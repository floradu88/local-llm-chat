<#
.SYNOPSIS
  Verify VS Code is fully configured for local Ollama (Case H).

.DESCRIPTION
  Full stack check (exit 0 only when all required pieces pass):

    1. VS Code installed (Code.exe / code CLI)
    2. Extensions: Continue + Cline
    3. Continue -> Ollama (config, local-only, optional smoke)
    4. Cline -> Ollama (config, local-only, optional smoke)
    5. VS Code User mcp.json has Codegraph (fnm-friendly launch)
    6. Editor settings disable Copilot / built-in chat AI (warn if missing)
    7. Ollama API reachable

  Alias-friendly name: also invoked as the deep check behind Test-VSCodeOllama.ps1.

.PARAMETER Model
  Smoke model tag.

.PARAMETER SkipSmoke
  Skip Ollama / OpenAI-compatible smoke calls.

.PARAMETER SkipContinue
  Skip Continue checks.

.PARAMETER SkipCline
  Skip Cline checks.

.PARAMETER SkipExtensions
  Skip marketplace extension presence checks.

.PARAMETER SkipMcp
  Skip VS Code mcp.json Codegraph check.

.PARAMETER SkipEditorSettings
  Skip Copilot/chat local-only settings check.

.PARAMETER AllowRemoteModels
  Do not fail when Continue/Cline still have remote providers.

.PARAMETER TimeoutSec
  Smoke timeout. Default: 120.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [switch] $SkipSmoke,
  [switch] $SkipContinue,
  [switch] $SkipCline,
  [switch] $SkipExtensions,
  [switch] $SkipMcp,
  [switch] $SkipEditorSettings,
  [switch] $AllowRemoteModels,
  [int] $TimeoutSec = 120
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Check([string] $Level, [string] $Message) {
  Write-Host ("[{0}] {1}" -f $Level, $Message)
}

function Get-VSCodeExtensionIds {
  param($Info)
  $ids = @()
  if (-not $Info.CmdPath) { return $ids }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = & $Info.CmdPath --list-extensions 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
      $ids = @($raw | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }
  } catch { }
  finally {
    $ErrorActionPreference = $prev
  }
  return $ids
}

function Test-VSCodeLocalOnlySettings {
  param([string] $SettingsPath)
  if (-not (Test-Path -LiteralPath $SettingsPath)) {
    return [pscustomobject]@{ Ok = $false; Missing = @("settings.json"); Detail = "missing" }
  }
  try {
    $cfg = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{ Ok = $false; Missing = @("parse-error"); Detail = "$_" }
  }
  $missing = @()
  $copilot = $cfg.'github.copilot.enable'
  $copilotOff = $false
  if ($null -ne $copilot) {
    try {
      if ($copilot.'*' -eq $false) { $copilotOff = $true }
    } catch {
      if ("$copilot" -match 'False|false') { $copilotOff = $true }
    }
  }
  if (-not $copilotOff) { $missing += "github.copilot.enable[*]=false" }
  if ($cfg.'chat.disableAIFeatures' -ne $true) { $missing += "chat.disableAIFeatures=true" }
  return [pscustomobject]@{
    Ok      = ($missing.Count -eq 0)
    Missing = $missing
    Detail  = if ($missing.Count -eq 0) { "local-only settings present" } else { ($missing -join ", ") }
  }
}

$failed = 0
$warnings = 0
Write-Host "=== Test-VSCodeSetup (full VS Code local AI) ==="

# 1) VS Code install
$info = Get-VSCodeInstallInfo
if ($info.Installed) {
  Write-Check "OK" ("VS Code installed ({0}): {1}" -f $info.Scope, $(if ($info.ExePath) { $info.ExePath } else { $info.CmdPath }))
  if ($info.CmdPath) {
    Write-Check "OK" ("code CLI: {0}" -f $info.CmdPath)
  } else {
    Write-Check "WARN" "code CLI missing - extension checks limited"
    $warnings++
  }
} else {
  Write-Check "FAIL" "VS Code missing - .\scripts\Install-VSCode.ps1"
  $failed++
}

# 2) Extensions
if (-not $SkipExtensions) {
  Write-Host ""
  Write-Host "--- Extensions ---"
  if (-not $info.CmdPath) {
    Write-Check "WARN" "Skip extension list (no code CLI)"
    $warnings++
  } else {
    $extIds = Get-VSCodeExtensionIds -Info $info
    $needContinue = "Continue.continue"
    $needCline = "saoudrizwan.claude-dev"
    if ($extIds -contains $needContinue) {
      Write-Check "OK" ("Continue extension: {0}" -f $needContinue)
    } else {
      Write-Check "FAIL" ("Continue extension missing - .\scripts\Install-ContinueConfig.ps1")
      $failed++
    }
    if ($extIds -contains $needCline) {
      Write-Check "OK" ("Cline extension: {0}" -f $needCline)
    } else {
      Write-Check "FAIL" ("Cline extension missing - .\scripts\Install-ClineConfig.ps1")
      $failed++
    }
  }
}

# 3) Ollama
Write-Host ""
Write-Host "--- Ollama ---"
Add-OllamaToSessionPath
$ollamaNames = @()
if (Test-OllamaApi) {
  try {
    $tags = Invoke-RestMethod http://127.0.0.1:11434/api/tags
    $ollamaNames = @($tags.models | ForEach-Object { $_.name })
    Write-Check "OK" ("Ollama API - {0} model(s)" -f $ollamaNames.Count)
  } catch {
    Write-Check "FAIL" "/api/tags failed: $_"
    $failed++
  }
} else {
  Write-Check "FAIL" "Ollama API down - start Ollama"
  $failed++
}

# 4) Continue
if (-not $SkipContinue) {
  Write-Host ""
  Write-Host "--- Continue (ChatGPT-like) ---"
  $contArgs = @{}
  if ($Model) { $contArgs["Model"] = $Model }
  if ($SkipSmoke) { $contArgs["SkipSmoke"] = $true }
  $contArgs["TimeoutSec"] = $TimeoutSec
  & (Join-Path $PSScriptRoot "Test-ContinueOllama.ps1") @contArgs
  if ($LASTEXITCODE -ne 0) { $failed++ }

  if ($AllowRemoteModels) {
    $cont = Get-ContinueOllamaConfigStatus
    if (-not $cont.LocalOnly) {
      Write-Check "WARN" "Continue has remote entries (-AllowRemoteModels set)"
      $warnings++
    }
  }
}

# 5) Cline
if (-not $SkipCline) {
  Write-Host ""
  Write-Host "--- Cline (Cursor-like agent) ---"
  $cline = Get-ClineOllamaConfigStatus
  if ($cline.Configured) {
    Write-Check "OK" ("Cline model: {0}" -f $cline.Model)
    Write-Check "OK" ("Cline base:  {0} ({1})" -f $cline.BaseUrl, $cline.Source)
    if ($cline.LocalOnly) {
      Write-Check "OK" "Cline local-only (no cloud providers)"
    } elseif ($AllowRemoteModels) {
      Write-Check "WARN" ("Cline remotes still on: {0}" -f ($cline.RemoteProviders -join ", "))
      $warnings++
    } else {
      Write-Check "FAIL" ("Cline still has remote providers: {0}" -f ($cline.RemoteProviders -join ", "))
      Write-Host "     Fix: .\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor"
      $failed++
    }
    if ($ollamaNames.Count -gt 0 -and $ollamaNames -notcontains $cline.Model) {
      Write-Check "FAIL" ("Cline model '{0}' not in ollama list" -f $cline.Model)
      $failed++
    } else {
      Write-Check "OK" "Cline model present in ollama list"
    }
  } else {
    Write-Check "FAIL" "Cline not wired - .\scripts\Install-ClineConfig.ps1"
    $failed++
  }

  if (-not $SkipSmoke -and $cline.Configured) {
    $smokeModel = if ($Model) { $Model } elseif ($cline.Model) { $cline.Model } elseif ($ollamaNames.Count -gt 0) { $ollamaNames[0] } else { "" }
    if (-not $smokeModel) {
      Write-Check "FAIL" "No model for Cline smoke"
      $failed++
    } else {
      $root = if ($cline.BaseUrl) { $cline.BaseUrl.TrimEnd("/") -replace "/v1$", "" } else { "http://127.0.0.1:11434" }
      $uri = "$root/v1/chat/completions"
      Write-Host ("Smoke (Cline path): POST {0} model={1}" -f $uri, $smokeModel)
      try {
        $body = @{
          model      = $smokeModel
          messages   = @(@{ role = "user"; content = "Reply with exactly: ok" })
          max_tokens = 8
          stream     = $false
        } | ConvertTo-Json -Depth 5 -Compress
        $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer ollama" } -TimeoutSec $TimeoutSec
        $snippet = (($resp.choices[0].message.content -replace "\s+", " ").Trim())
        if (-not $snippet) { $snippet = "(empty)" }
        if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + "..." }
        Write-Check "OK" ("chat/completions: {0}" -f $snippet)
      } catch {
        Write-Check "FAIL" ("Cline path smoke failed: {0}" -f $_)
        if ($root -match "8787") {
          Write-Host "     Tip: .\scripts\Install-Headroom.ps1 then .\scripts\Start-HeadroomOllama.ps1"
        }
        $failed++
      }
    }
  }
}

# 6) MCP JSON
if (-not $SkipMcp) {
  Write-Host ""
  Write-Host "--- Codegraph MCP (VS Code) ---"
  $mcp = Get-CodegraphMcpJsonStatus
  if ($mcp.VSCodeHas) {
    Write-Check "OK" ("VS Code mcp.json has codegraph ({0})" -f $mcp.VSCodePath)
    Write-Check "OK" ("MCP launch mode: {0}" -f $mcp.LaunchMode)
  } else {
    Write-Check "FAIL" ("VS Code mcp.json missing codegraph - .\scripts\Install-Codegraph.ps1")
    Write-Host ("     Expected: {0}" -f $mcp.VSCodePath)
    $failed++
  }
}

# 7) Editor local-only settings
if (-not $SkipEditorSettings) {
  Write-Host ""
  Write-Host "--- Editor local-only settings ---"
  $setCheck = Test-VSCodeLocalOnlySettings -SettingsPath $info.SettingsPath
  if ($setCheck.Ok) {
    Write-Check "OK" ("settings.json local-only flags ({0})" -f $info.SettingsPath)
  } else {
    Write-Check "WARN" ("settings.json incomplete: {0}" -f $setCheck.Detail)
    Write-Host "     Fix: .\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor"
    $warnings++
  }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "RESULT: $failed check(s) failed ($warnings warning(s))."
  Write-Host "Fix: .\scripts\Install-VSCodeLocalAI.ps1 -Force"
  Write-Host "     .\scripts\Install-Codegraph.ps1"
  Write-Host "     .\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor"
  Write-Host "Re-test: .\scripts\Test-VSCodeSetup.ps1"
  exit 1
}
Write-Host ("RESULT: OK - VS Code is fully configured for local Ollama ({0} warning(s))." -f $warnings)
Write-Host "Continue = chat/autocomplete; Cline = agent; MCP = Codegraph. Reload VS Code if needed."
exit 0

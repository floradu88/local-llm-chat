<#
.SYNOPSIS
  Verify Cursor → local Ollama integration (Models config + OpenAI-compatible smoke).

.DESCRIPTION
  Checks:
    1. Cursor is installed and state.vscdb is readable
    2. openAIBaseUrl / useOpenAIKey / API key look wired for Ollama (or Headroom)
    3. Local model tags are enabled; cloud/catalog models are disabled (unless -AllowRemoteModels)
    4. Enabled tags exist in ollama list (when API is up)
    5. POST {baseUrl}/chat/completions succeeds (same path Cursor uses)

  Exit 0 = OK; exit 1 = one or more checks failed.

.PARAMETER Model
  Tag for the chat smoke test. Default: first enabled Cursor model that exists in ollama list,
  else first ollama tag.

.PARAMETER SkipSmoke
  Skip the /v1/chat/completions call.

.PARAMETER AllowRemoteModels
  Do not fail when cloud/catalog models are still enabled.

.PARAMETER TimeoutSec
  Smoke request timeout. Default: 120.
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
Write-Host "=== Test-CursorOllama ==="

# 1) Cursor install
$info = Get-CursorInstallInfo
if ($info.Installed) {
  Write-Check "OK" ("Cursor installed ({0}): {1}" -f $info.Scope, $(if ($info.ExePath) { $info.ExePath } else { $info.CmdPath }))
} else {
  Write-Check "FAIL" "Cursor not installed - run .\scripts\Install-Cursor.ps1"
  $failed++
  Write-Host ""
  Write-Host "RESULT: $failed check(s) failed."
  exit 1
}

# 2) Models / state.vscdb
$status = Get-CursorOllamaConfigStatus
if ($status.Configured) {
  Write-Check "OK" ("Models base URL: {0}" -f $status.OpenAIBaseUrl)
} else {
  Write-Check "FAIL" ("Models not wired: {0}" -f $(if ($status.Message) { $status.Message } else { "run .\scripts\Install-CursorConfig.ps1 (quit Cursor first)" }))
  $failed++
}

if ($status.UseOpenAIKey) {
  Write-Check "OK" "useOpenAIKey = true"
} elseif ($status.Configured) {
  Write-Check "FAIL" "useOpenAIKey is false"
  $failed++
}

if ($status.ApiKeyPresent) {
  Write-Check "OK" "OpenAI API key stored in Cursor"
} elseif ($status.Configured) {
  Write-Check "FAIL" "No cursorAuth/openAIKey - re-run Install-CursorConfig.ps1"
  $failed++
}

$enabled = @($status.ModelOverrideEnabled | Where-Object { $_ })
if ($enabled.Count -gt 0) {
  Write-Check "OK" ("Enabled models: {0}" -f ($enabled -join ", "))
} elseif ($status.Configured) {
  Write-Check "FAIL" "No models in modelOverrideEnabled - re-run Install-CursorConfig.ps1"
  $failed++
}

if ($AllowRemoteModels) {
  if ($status.RemoteModelsDisabled) {
    Write-Check "OK" ("Remote/catalog models disabled ({0} entries)" -f $status.CatalogDisabledCount)
  } else {
    Write-Check "WARN" "Remote/catalog models still enabled (-AllowRemoteModels set)"
  }
} else {
  if ($status.RemoteModelsDisabled) {
    Write-Check "OK" ("Remote/catalog models disabled ({0} entries)" -f $status.CatalogDisabledCount)
  } else {
    Write-Check "FAIL" "Remote/catalog models still enabled - quit Cursor; .\scripts\Install-CursorConfig.ps1"
    $failed++
  }
}

# 3) Ollama API + model overlap
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
  Write-Check "FAIL" "Ollama API not reachable at http://127.0.0.1:11434 - start Ollama"
  $failed++
}

$overlap = @()
if ($enabled.Count -gt 0 -and $ollamaNames.Count -gt 0) {
  $overlap = @($enabled | Where-Object { $ollamaNames -contains $_ })
  if ($overlap.Count -gt 0) {
    Write-Check "OK" ("Enabled tags present in ollama list: {0}" -f ($overlap -join ", "))
  } else {
    Write-Check "FAIL" ("None of Cursor enabled tags are installed. Enabled=[{0}] ollama=[{1}]" -f ($enabled -join ", "), ($ollamaNames -join ", "))
    $failed++
  }
}

# Resolve smoke model
if (-not $Model) {
  if ($overlap.Count -gt 0) { $Model = $overlap[0] }
  elseif ($ollamaNames.Count -gt 0) { $Model = $ollamaNames[0] }
}

# 4) OpenAI-compatible smoke (what Cursor calls)
if ($SkipSmoke) {
  Write-Check "WARN" "Smoke skipped (-SkipSmoke)"
} elseif (-not $status.OpenAIBaseUrl) {
  Write-Check "WARN" "Smoke skipped (no base URL configured)"
} elseif (-not $Model) {
  Write-Check "FAIL" "No model for smoke - pull one then re-run"
  $failed++
} else {
  $base = $status.OpenAIBaseUrl.TrimEnd("/")
  if ($base -notmatch "/v1$") { $base = "$base/v1" }
  $uri = "$base/chat/completions"
  Write-Host ("Smoke: POST {0} model={1}" -f $uri, $Model)
  try {
    $bodyObj = @{
      model       = $Model
      messages    = @(@{ role = "user"; content = "Reply with exactly: ok" })
      max_tokens  = 8
      stream      = $false
    }
    $body = $bodyObj | ConvertTo-Json -Depth 5 -Compress
    $headers = @{ Authorization = "Bearer ollama" }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec $TimeoutSec
    $content = $null
    if ($resp.choices -and $resp.choices.Count -gt 0) {
      $content = $resp.choices[0].message.content
    }
    $snippet = (($content -replace "\s+", " ").Trim())
    if (-not $snippet) { $snippet = "(empty content)" }
    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + "..." }
    Write-Check "OK" ("chat/completions response: {0}" -f $snippet)
  } catch {
    Write-Check "FAIL" ("chat/completions smoke failed: {0}" -f $_)
    if ($base -match "8787") {
      Write-Host "     Tip: start Headroom first - .\scripts\Start-HeadroomOllama.ps1"
    }
    $failed++
  }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "RESULT: $failed check(s) failed."
  Write-Host "Fix: quit Cursor, run .\scripts\Install-CursorConfig.ps1, ensure Ollama is running, then re-test."
  exit 1
}
Write-Host "RESULT: OK - Cursor → local Ollama path looks working."
Write-Host "In Cursor: Settings > Models should show only local tags; pick one and chat."
exit 0

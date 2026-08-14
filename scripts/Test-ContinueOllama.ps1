<#
.SYNOPSIS
  Verify Continue → local Ollama (ChatGPT-like chat + autocomplete config + smoke).

.PARAMETER Model
  Tag for smoke. Default: first Continue model present in ollama list.

.PARAMETER SkipSmoke
  Skip generate / chat API call.

.PARAMETER TimeoutSec
  Smoke timeout. Default: 120.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [switch] $SkipSmoke,
  [int] $TimeoutSec = 120
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Check([string] $Level, [string] $Message) {
  Write-Host ("[{0}] {1}" -f $Level, $Message)
}

$failed = 0
Write-Host "=== Test-ContinueOllama ==="

$info = Get-VSCodeInstallInfo
if ($info.Installed) {
  Write-Check "OK" ("VS Code installed ({0})" -f $info.Scope)
} else {
  Write-Check "WARN" "VS Code not installed - Continue config can still work; run .\scripts\Install-VSCode.ps1"
}

$status = Get-ContinueOllamaConfigStatus
if ($status.Configured) {
  Write-Check "OK" ("Continue config: {0}" -f $status.Path)
  Write-Check "OK" ("ApiBase: {0}" -f $status.ApiBase)
  Write-Check "OK" ("Chat models: {0}" -f ($status.Models -join ", "))
} else {
  Write-Check "FAIL" ("Continue not wired: {0}" -f $status.Message)
  $failed++
}

if ($status.HasAutocomplete) {
  Write-Check "OK" "tabAutocompleteModel present"
} elseif ($status.Configured) {
  Write-Check "WARN" "No tabAutocompleteModel - re-run Install-ContinueConfig.ps1 -Force"
}

if ($status.LocalOnly) {
  Write-Check "OK" "Continue local-only (no cloud providers in config)"
} elseif ($status.Configured) {
  Write-Check "FAIL" ("Continue still has remote providers: {0}" -f ($status.RemoteEntries -join ", "))
  Write-Host "     Fix: .\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor"
  $failed++
}

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
  Write-Check "FAIL" "Ollama API not reachable"
  $failed++
}

$overlap = @()
if ($status.Models.Count -gt 0 -and $ollamaNames.Count -gt 0) {
  $overlap = @($status.Models | Where-Object { $ollamaNames -contains $_ })
  if ($overlap.Count -gt 0) {
    Write-Check "OK" ("Configured tags installed: {0}" -f ($overlap -join ", "))
  } else {
    Write-Check "FAIL" "None of Continue models are in ollama list"
    $failed++
  }
}

if (-not $Model) {
  if ($overlap.Count -gt 0) { $Model = $overlap[0] }
  elseif ($ollamaNames.Count -gt 0) { $Model = $ollamaNames[0] }
}

if ($SkipSmoke) {
  Write-Check "WARN" "Smoke skipped"
} elseif (-not $Model) {
  Write-Check "FAIL" "No model for smoke"
  $failed++
} else {
  $apiBase = if ($status.ApiBase) { $status.ApiBase.TrimEnd("/") } else { "http://127.0.0.1:11434" }
  Write-Host ("Smoke via Continue apiBase={0} model={1}" -f $apiBase, $Model)
  try {
    if ($apiBase -match "/v1$") {
      $uri = "$apiBase/chat/completions"
      $body = @{
        model = $Model
        messages = @(@{ role = "user"; content = "Reply with exactly: ok" })
        max_tokens = 8
        stream = $false
      } | ConvertTo-Json -Depth 5 -Compress
      $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer ollama" } -TimeoutSec $TimeoutSec
      $snippet = (($resp.choices[0].message.content -replace "\s+", " ").Trim())
    } else {
      $uri = "$apiBase/api/generate"
      $body = @{
        model = $Model
        prompt = "Reply with exactly: ok"
        stream = $false
        options = @{ num_predict = 8 }
      } | ConvertTo-Json -Compress
      $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec
      $snippet = (($resp.response -replace "\s+", " ").Trim())
    }
    if (-not $snippet) { $snippet = "(empty)" }
    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + "..." }
    Write-Check "OK" ("smoke response: {0}" -f $snippet)
  } catch {
    Write-Check "FAIL" ("smoke failed: {0}" -f $_)
    $failed++
  }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "RESULT: $failed check(s) failed."
  Write-Host "Fix: .\scripts\Install-ContinueConfig.ps1 -Force"
  exit 1
}
Write-Host "RESULT: OK - Continue -> Ollama looks working."
exit 0

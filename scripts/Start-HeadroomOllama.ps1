<#
.SYNOPSIS
  Start Headroom proxy forwarding OpenAI-compatible traffic to local Ollama.

.PARAMETER Port
  Headroom listen port (default 8787)

.PARAMETER OllamaUrl
  Ollama OpenAI-compatible base, default http://127.0.0.1:11434/v1

.PARAMETER SkipInstall
  Do not pip install headroom-ai[proxy]
#>
[CmdletBinding()]
param(
  [int] $Port = 8787,
  [string] $OllamaUrl = "http://127.0.0.1:11434/v1",
  [switch] $SkipInstall
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaApi)) {
  throw "Ollama API not reachable at http://127.0.0.1:11434. Start Ollama first."
}

$headroom = Get-Command headroom -ErrorAction SilentlyContinue
if (-not $headroom -and -not $SkipInstall) {
  Write-Host "Installing headroom-ai[proxy] for current user..."
  python -m pip install --user "headroom-ai[proxy]"
  $headroom = Get-Command headroom -ErrorAction SilentlyContinue
}

if (-not $headroom) {
  throw "headroom CLI not found. Install: pip install --user `"headroom-ai[proxy]`" and ensure Python Scripts are on PATH."
}

$env:OPENAI_TARGET_API_URL = $OllamaUrl
Write-Host "OPENAI_TARGET_API_URL=$OllamaUrl"
Write-Host "Starting Headroom on http://127.0.0.1:$Port"
Write-Host "Point Cursor/clients at http://127.0.0.1:$Port/v1  (API key: ollama)"
Write-Host "Ctrl+C to stop.`n"

& headroom proxy --port $Port --openai-api-url $OllamaUrl

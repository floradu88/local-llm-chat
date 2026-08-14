<#
.SYNOPSIS
  Start Headroom proxy forwarding OpenAI-compatible traffic to local Ollama.

.DESCRIPTION
  Prefers the short-path venv from Install-Headroom.ps1 (default C:\hr) so
  litellm installs without Windows Long Path / admin. Falls back to PATH /
  user-site Scripts when present.

.PARAMETER Port
  Headroom listen port (default 8787)

.PARAMETER OllamaUrl
  Ollama OpenAI-compatible base, default http://127.0.0.1:11434/v1

.PARAMETER VenvPath
  Short venv used for install/run (default C:\hr)

.PARAMETER SkipInstall
  Do not create/install the short venv; only use an existing headroom.exe

.PARAMETER ForceInstall
  Recreate the short venv before starting
#>
[CmdletBinding()]
param(
  [int] $Port = 8787,
  [string] $OllamaUrl = "http://127.0.0.1:11434/v1",
  [string] $VenvPath = "C:\hr",
  [switch] $SkipInstall,
  [switch] $ForceInstall
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaApi)) {
  throw "Ollama API not reachable at http://127.0.0.1:11434. Start Ollama first."
}

$headroomExe = Resolve-HeadroomExe -VenvPath $VenvPath
if ((-not $headroomExe -or $ForceInstall) -and -not $SkipInstall) {
  $headroomExe = Ensure-HeadroomShortVenv -VenvPath $VenvPath -ForceReinstall:$ForceInstall
} elseif (-not $headroomExe) {
  throw @"
headroom CLI not found.
Install (no admin, short path):  .\scripts\Install-Headroom.ps1
Or:                              .\scripts\Start-HeadroomOllama.ps1   (auto-installs into $VenvPath)

Avoid: pip install --user with Microsoft Store Python — long litellm paths fail without admin Long Paths.
"@
}

$env:OPENAI_TARGET_API_URL = $OllamaUrl
Write-Host "Using: $headroomExe"
Write-Host "OPENAI_TARGET_API_URL=$OllamaUrl"
Write-Host "Starting Headroom on http://127.0.0.1:$Port"
Write-Host "Point Cursor/clients at http://127.0.0.1:$Port/v1  (API key: ollama)"
Write-Host "Ctrl+C to stop.`n"

& $headroomExe proxy --port $Port --openai-api-url $OllamaUrl
exit $LASTEXITCODE

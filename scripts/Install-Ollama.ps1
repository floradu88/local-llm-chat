<#
.SYNOPSIS
  Install Ollama on Windows via the official install script (per-user, typically no admin).

.PARAMETER InstallDir
  Optional custom binary directory (sets OLLAMA_INSTALL_DIR).

.PARAMETER SkipStart
  Do not attempt to hit the API after install.
#>
[CmdletBinding()]
param(
  [string] $InstallDir = "",
  [switch] $SkipStart
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if ($InstallDir) {
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $env:OLLAMA_INSTALL_DIR = (Resolve-Path $InstallDir).Path
  Write-Host "OLLAMA_INSTALL_DIR=$($env:OLLAMA_INSTALL_DIR)"
}

Write-Host "Downloading and running official Ollama Windows installer..."
irm https://ollama.com/install.ps1 | iex

Add-OllamaToSessionPath

if (-not (Test-OllamaCommand)) {
  Write-Warning "ollama not on PATH yet. Open a new PowerShell window, or add: $($env:LOCALAPPDATA)\Programs\Ollama"
  exit 1
}

Write-Host "Installed: $(ollama --version)"

if (-not $SkipStart) {
  Write-Host "Waiting for API on http://localhost:11434 ..."
  $ok = $false
  for ($i = 0; $i -lt 30; $i++) {
    if (Test-OllamaApi -TimeoutSec 2) {
      $ok = $true
      break
    }
    Start-Sleep -Seconds 2
  }
  if ($ok) {
    Write-Host "Ollama API is reachable."
  } else {
    Write-Warning "API not reachable yet. Start Ollama from the Start menu / tray, then retry."
  }
}

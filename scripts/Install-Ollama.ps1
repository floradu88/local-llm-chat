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

if ($InstallDir) {
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $env:OLLAMA_INSTALL_DIR = (Resolve-Path $InstallDir).Path
  Write-Host "OLLAMA_INSTALL_DIR=$($env:OLLAMA_INSTALL_DIR)"
}

Write-Host "Downloading and running official Ollama Windows installer..."
irm https://ollama.com/install.ps1 | iex

# Ensure current session can see the per-user install
$ollamaBin = Join-Path $env:LOCALAPPDATA "Programs\Ollama"
if (Test-Path $ollamaBin) {
  if ($env:Path -notlike "*$ollamaBin*") {
    $env:Path = "$ollamaBin;$env:Path"
  }
}

$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollamaCmd) {
  Write-Warning "ollama not on PATH yet. Open a new PowerShell window, or add: $ollamaBin"
  exit 1
}

Write-Host "Installed: $(ollama --version)"

if (-not $SkipStart) {
  Write-Host "Waiting for API on http://localhost:11434 ..."
  $ok = $false
  for ($i = 0; $i -lt 30; $i++) {
    try {
      Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 2 | Out-Null
      $ok = $true
      break
    } catch {
      Start-Sleep -Seconds 2
    }
  }
  if ($ok) {
    Write-Host "Ollama API is reachable."
  } else {
    Write-Warning "API not reachable yet. Start Ollama from the Start menu / tray, then retry."
  }
}

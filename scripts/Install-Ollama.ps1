<#
.SYNOPSIS
  Install Ollama on Windows via the official install script (per-user, typically no admin).

.DESCRIPTION
  Downloads https://ollama.com/install.ps1 to disk, prints SHA256, optionally verifies
  against -ExpectedSha256 or config/installer-pins.json (id: ollama-install-ps1),
  then runs it with powershell -File (does NOT use irm|iex).

.PARAMETER InstallDir
  Optional custom binary directory (sets OLLAMA_INSTALL_DIR).

.PARAMETER SkipStart
  Do not attempt to hit the API after install.

.PARAMETER ExpectedSha256
  Optional SHA256 of install.ps1. If omitted, uses config/installer-pins.json when present.
#>
[CmdletBinding()]
param(
  [string] $InstallDir = "",
  [switch] $SkipStart,
  [string] $ExpectedSha256 = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if ($InstallDir) {
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $env:OLLAMA_INSTALL_DIR = (Resolve-Path $InstallDir).Path
  Write-Host "OLLAMA_INSTALL_DIR=$($env:OLLAMA_INSTALL_DIR)"
}

if (-not $ExpectedSha256) {
  $ExpectedSha256 = Get-InstallerPinSha256 -Id "ollama-install-ps1"
  if ($ExpectedSha256) {
    Write-Host "Using SHA256 pin from config/installer-pins.json (ollama-install-ps1)"
  }
}

Write-Host "Downloading and running official Ollama Windows installer (verified download path)..."
$exit = Invoke-VerifiedRemoteScript `
  -Url "https://ollama.com/install.ps1" `
  -ExpectedSha256 $ExpectedSha256 `
  -AllowedHosts @("ollama.com", "www.ollama.com")

if ($exit -ne 0 -and $null -ne $exit) {
  Write-Warning ("Ollama install script exited {0}" -f $exit)
}

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

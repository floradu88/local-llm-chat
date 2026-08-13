<#
.SYNOPSIS
  Set OLLAMA_MODELS (and optional install dir) for this machine — User scope, no admin.

.PARAMETER ModelsRoot
  Folder for Ollama model blobs. Default: <repo>/models/ollama

.PARAMETER InstallDir
  Optional OLLAMA_INSTALL_DIR for the official installer.

.PARAMETER Persistent
  Write User environment variables (survives new terminals).
#>
[CmdletBinding()]
param(
  [string] $ModelsRoot = "",
  [string] $InstallDir = "",
  [switch] $Persistent
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ModelsRoot) {
  $ModelsRoot = Join-Path $RepoRoot "models\ollama"
}

New-Item -ItemType Directory -Force -Path $ModelsRoot | Out-Null
$ModelsRoot = (Resolve-Path $ModelsRoot).Path

$env:OLLAMA_MODELS = $ModelsRoot
Write-Host "Session OLLAMA_MODELS=$ModelsRoot"

if ($InstallDir) {
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $InstallDir = (Resolve-Path $InstallDir).Path
  $env:OLLAMA_INSTALL_DIR = $InstallDir
  Write-Host "Session OLLAMA_INSTALL_DIR=$InstallDir"
}

if ($Persistent) {
  [Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $ModelsRoot, "User")
  Write-Host "Persisted User OLLAMA_MODELS=$ModelsRoot"
  if ($InstallDir) {
    [Environment]::SetEnvironmentVariable("OLLAMA_INSTALL_DIR", $InstallDir, "User")
    Write-Host "Persisted User OLLAMA_INSTALL_DIR=$InstallDir"
  }
  Write-Host "Quit and relaunch the Ollama tray app (or open a new terminal) so the service sees the new path."
}

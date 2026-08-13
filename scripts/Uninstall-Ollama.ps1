<#
.SYNOPSIS
  Help remove Ollama and optional local model folders for this toolkit (no admin required for guidance).

.PARAMETER RemoveModelsRoot
  If OLLAMA_MODELS (User) is set, delete that folder after confirmation.

.PARAMETER RemoveRepoGguf
  Delete .\models\gguf contents (keeps .gitkeep).

.PARAMETER Yes
  Skip confirmation prompts.
#>
[CmdletBinding()]
param(
  [switch] $RemoveModelsRoot,
  [switch] $RemoveRepoGguf,
  [switch] $Yes
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

Write-Host "=== Uninstall-Ollama helper ==="
Write-Host "1) Uninstall the Ollama app via Windows Settings > Apps > Ollama (per-user uninstall)."
Write-Host "2) Optionally clear model storage below."
Write-Host ""

$modelsRoot = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
if ($modelsRoot) {
  Write-Host "User OLLAMA_MODELS=$modelsRoot"
} else {
  Write-Host "OLLAMA_MODELS unset. Default models usually under $env:USERPROFILE\.ollama"
}

function Confirm-OrYes {
  param([string] $Message)
  if ($Yes) { return $true }
  $r = Read-Host "$Message [y/N]"
  return ($r -eq "y" -or $r -eq "Y")
}

if ($RemoveModelsRoot) {
  if (-not $modelsRoot) {
    Write-Warning "No User OLLAMA_MODELS set; nothing to remove for -RemoveModelsRoot."
  } elseif (Confirm-OrYes "Delete model folder $modelsRoot ?") {
    if (Test-Path $modelsRoot) {
      Remove-Item -LiteralPath $modelsRoot -Recurse -Force
      Write-Host "Removed $modelsRoot"
    }
    [Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $null, "User")
    Write-Host "Cleared User OLLAMA_MODELS"
  }
}

if ($RemoveRepoGguf) {
  $gguf = Join-Path $RepoRoot "models\gguf"
  if (Confirm-OrYes "Delete contents of $gguf (keep .gitkeep)?") {
    Get-ChildItem -Path $gguf -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne ".gitkeep" } |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned $gguf"
  }
}

Write-Host ""
Write-Host "Done. Reinstall later with: .\scripts\Setup-Machine.ps1 -Tier Auto"

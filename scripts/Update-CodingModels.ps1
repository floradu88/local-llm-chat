<#
.SYNOPSIS
  Re-pull (update) coding models for a RAM tier.

.PARAMETER Tier
  8GB | 16GB | 32GB | Auto
#>
[CmdletBinding()]
param(
  [ValidateSet("8GB", "16GB", "32GB", "Auto")]
  [string] $Tier = "Auto",
  [switch] $SkipSmoke
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaCommand)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

$resolved = Resolve-CodingModelTier -Tier $Tier
Write-Host "Update-CodingModels: tier $resolved (requested: $Tier)"
& (Join-Path $PSScriptRoot "Pull-CodingModels.ps1") -Tier $resolved -SkipSmoke:$SkipSmoke

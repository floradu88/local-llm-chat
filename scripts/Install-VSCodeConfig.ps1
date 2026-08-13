<#
.SYNOPSIS
  Alias for Install-ContinueConfig.ps1 (VS Code + Continue → Ollama).

.DESCRIPTION
  Same behavior as Install-ContinueConfig.ps1 — find VS Code, install Continue,
  write ~/.continue/config.json for local Ollama. Named to mirror Install-CursorConfig.ps1.
#>
[CmdletBinding()]
param(
  [string] $ApiBase = "http://localhost:11434",
  [string[]] $Models = @(),
  [switch] $Headroom,
  [switch] $Force,
  [switch] $CheckOnly,
  [switch] $SkipExtension,
  [string] $AutocompleteModel = ""
)

$ErrorActionPreference = "Stop"
$argsHash = @{
  ApiBase = $ApiBase
}
if ($Models -and $Models.Count -gt 0) { $argsHash["Models"] = $Models }
if ($Headroom) { $argsHash["Headroom"] = $true }
if ($Force) { $argsHash["Force"] = $true }
if ($CheckOnly) { $argsHash["CheckOnly"] = $true }
if ($SkipExtension) { $argsHash["SkipExtension"] = $true }
if ($AutocompleteModel) { $argsHash["AutocompleteModel"] = $AutocompleteModel }

& (Join-Path $PSScriptRoot "Install-ContinueConfig.ps1") @argsHash
exit $LASTEXITCODE

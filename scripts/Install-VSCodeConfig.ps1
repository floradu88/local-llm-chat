<#
.SYNOPSIS
  Alias for Install-VSCodeLocalAI.ps1 (Continue chat + Cline agent → Ollama).

.DESCRIPTION
  Preferred VS Code entry point (Case H). For Continue-only, call Install-ContinueConfig.ps1.
#>
[CmdletBinding()]
param(
  [string[]] $Models = @(),
  [string] $ClineModel = "",
  [switch] $Headroom,
  [switch] $Force,
  [switch] $SkipVSCodeInstall,
  [switch] $SkipContinue,
  [switch] $SkipCline,
  [switch] $SkipTest,
  [switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
$argsHash = @{}
if ($Models -and $Models.Count -gt 0) { $argsHash["Models"] = $Models }
if ($ClineModel) { $argsHash["ClineModel"] = $ClineModel }
if ($Headroom) { $argsHash["Headroom"] = $true }
if ($Force) { $argsHash["Force"] = $true }
if ($SkipVSCodeInstall) { $argsHash["SkipVSCodeInstall"] = $true }
if ($SkipContinue) { $argsHash["SkipContinue"] = $true }
if ($SkipCline) { $argsHash["SkipCline"] = $true }
if ($SkipTest) { $argsHash["SkipTest"] = $true }
if ($CheckOnly) { $argsHash["CheckOnly"] = $true }

& (Join-Path $PSScriptRoot "Install-VSCodeLocalAI.ps1") @argsHash
exit $LASTEXITCODE

<#
.SYNOPSIS
  Verify VS Code Local AI (Continue + Cline -> Ollama). Thin wrapper for Test-VSCodeSetup.ps1.

.DESCRIPTION
  Prefer Test-VSCodeSetup.ps1 for the full Case H check (extensions, MCP, local-only settings).
  This script keeps the older name and forwards all parameters.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [switch] $SkipSmoke,
  [switch] $SkipContinue,
  [switch] $SkipCline,
  [switch] $SkipExtensions,
  [switch] $SkipMcp,
  [switch] $SkipEditorSettings,
  [switch] $AllowRemoteModels,
  [int] $TimeoutSec = 120
)

$ErrorActionPreference = "Stop"
$argsHash = @{
  TimeoutSec = $TimeoutSec
}
if ($Model) { $argsHash["Model"] = $Model }
if ($SkipSmoke) { $argsHash["SkipSmoke"] = $true }
if ($SkipContinue) { $argsHash["SkipContinue"] = $true }
if ($SkipCline) { $argsHash["SkipCline"] = $true }
if ($SkipExtensions) { $argsHash["SkipExtensions"] = $true }
if ($SkipMcp) { $argsHash["SkipMcp"] = $true }
if ($SkipEditorSettings) { $argsHash["SkipEditorSettings"] = $true }
if ($AllowRemoteModels) { $argsHash["AllowRemoteModels"] = $true }

& (Join-Path $PSScriptRoot "Test-VSCodeSetup.ps1") @argsHash
exit $LASTEXITCODE

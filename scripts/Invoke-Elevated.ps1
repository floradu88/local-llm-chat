<#
.SYNOPSIS
  Launch a PowerShell script elevated (UAC). Use only when a check needs admin.

.PARAMETER ScriptPath
  Path to .ps1 (relative to repo scripts\ or absolute).

.PARAMETER ArgumentList
  Extra arguments passed to the elevated script.

.EXAMPLE
  .\scripts\Invoke-Elevated.ps1 -ScriptPath .\scripts\Test-GpuSupport.Elevated.ps1 -ArgumentList @('-OutFile', "$env:TEMP\gpu-admin.txt")

.EXAMPLE
  .\scripts\Invoke-Elevated.ps1 -ScriptPath .\scripts\Test-GpuSupport.ps1 -ArgumentList @('-Elevated')
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ScriptPath,
  [string[]] $ArgumentList = @()
)

$ErrorActionPreference = "Stop"

if (-not [System.IO.Path]::IsPathRooted($ScriptPath)) {
  $ScriptPath = Join-Path (Get-Location) $ScriptPath
}
if (-not (Test-Path -LiteralPath $ScriptPath)) {
  throw "Script not found: $ScriptPath"
}
$ScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path

$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $ArgumentList
Write-Host "Elevating (approve UAC if prompted):"
Write-Host "  $ScriptPath"
if ($ArgumentList.Count) {
  Write-Host ("  Args: {0}" -f ($ArgumentList -join " "))
}

$p = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru -Wait
Write-Host "Elevated exit code: $($p.ExitCode)"
exit $p.ExitCode

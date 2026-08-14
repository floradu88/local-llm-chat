<#
.SYNOPSIS
  Launch a PowerShell script elevated (UAC). Use only when a check needs admin.

.DESCRIPTION
  Only elevates .ps1 files that resolve under this repo's scripts\ directory
  (infosec P2). Blocks path traversal / arbitrary script elevation.

.PARAMETER ScriptPath
  Path to .ps1 (relative to repo scripts\ or absolute under scripts\).

.PARAMETER ArgumentList
  Extra arguments passed to the elevated script.

.PARAMETER AllowOutsideRepo
  Dangerous opt-out: allow elevating any existing .ps1 (not recommended).

.EXAMPLE
  .\scripts\Invoke-Elevated.ps1 -ScriptPath .\scripts\Test-GpuSupport.Elevated.ps1 -ArgumentList @('-OutFile', "$env:TEMP\gpu-admin.txt")

.EXAMPLE
  .\scripts\Invoke-Elevated.ps1 -ScriptPath .\scripts\Test-GpuSupport.ps1 -ArgumentList @('-Elevated')
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ScriptPath,
  [string[]] $ArgumentList = @(),
  [switch] $AllowOutsideRepo
)

$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptsRoot

if (-not [System.IO.Path]::IsPathRooted($ScriptPath)) {
  # Prefer resolve relative to caller cwd, then relative to scripts\
  $candidate = Join-Path (Get-Location) $ScriptPath
  if (-not (Test-Path -LiteralPath $candidate)) {
    $candidate = Join-Path $scriptsRoot (Split-Path -Leaf $ScriptPath)
  }
  if (-not (Test-Path -LiteralPath $candidate) -and (Test-Path -LiteralPath (Join-Path $scriptsRoot $ScriptPath))) {
    $candidate = Join-Path $scriptsRoot $ScriptPath
  }
  $ScriptPath = $candidate
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
  throw "Script not found: $ScriptPath"
}
$ScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path

if ($ScriptPath -notmatch '\.ps1$') {
  throw "Only .ps1 scripts may be elevated: $ScriptPath"
}

if (-not $AllowOutsideRepo) {
  $scriptsFull = (Resolve-Path -LiteralPath $scriptsRoot).Path.TrimEnd('\')
  # Case-insensitive prefix check (Windows paths)
  if (-not $ScriptPath.StartsWith($scriptsFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
      -not $ScriptPath.Equals($scriptsFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw @"
Refusing to elevate script outside repo scripts\:
  $ScriptPath
Allowed root:
  $scriptsFull

Pass -AllowOutsideRepo only if you intentionally trust that path.
Repo: $repoRoot
"@
  }
}

$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $ArgumentList
Write-Host "Elevating (approve UAC if prompted):"
Write-Host "  $ScriptPath"
if ($ArgumentList.Count) {
  Write-Host ("  Args: {0}" -f ($ArgumentList -join " "))
}

$p = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru -Wait
Write-Host "Elevated exit code: $($p.ExitCode)"
exit $p.ExitCode

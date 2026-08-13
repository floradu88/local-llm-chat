<#
.SYNOPSIS
  Download a .gguf (or any file) from a direct URL into models/gguf (ModelScope / GitHub Releases).

.PARAMETER Url
  HTTPS URL to the file.

.PARAMETER OutDir
  Destination folder. Default: models/gguf/direct

.PARAMETER FileName
  Optional override for saved filename.

.PARAMETER Force
  Re-download even if the destination file already exists.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $Url,
  [string] $OutDir = "",
  [string] $FileName = "",
  [switch] $Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not $OutDir) {
  $OutDir = Join-Path $RepoRoot "models\gguf\direct"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

if (-not $FileName) {
  $FileName = [Uri]::UnescapeDataString((Split-Path -Leaf ([Uri]$Url).AbsolutePath))
}
if (-not $FileName) {
  throw "Could not derive filename; pass -FileName"
}

$dest = Join-Path $OutDir $FileName
if (-not $Force -and (Test-LocalFilePresent -Path $dest)) {
  $sizeMb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
  Write-Host "Skip download (already on disk, $sizeMb MB): $dest"
  Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"
  return
}

Write-Host "Downloading:"
Write-Host "  $Url"
Write-Host "  -> $dest"

# Prefer BITS for large files when available; fall back to Invoke-WebRequest
$usedBits = $false
try {
  if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
    Start-BitsTransfer -Source $Url -Destination $dest -ErrorAction Stop
    $usedBits = $true
  }
} catch {
  Write-Warning "BITS transfer failed; falling back to Invoke-WebRequest. $_"
}

if (-not $usedBits) {
  Invoke-WebRequest -Uri $Url -OutFile $dest
}

$sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
Write-Host "Saved ($sizeMb MB): $dest"
Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"

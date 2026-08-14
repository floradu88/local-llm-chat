<#
.SYNOPSIS
  Download a .gguf (or any file) from a direct URL into models/gguf (ModelScope / GitHub Releases).

.DESCRIPTION
  HTTPS only (unless -AllowHttp). Host must be on the trusted allowlist (docs/trusted-sources.md)
  unless -SkipAllowlist. Optional -ExpectedSha256 fails closed on mismatch.

.PARAMETER Url
  HTTPS URL to the file.

.PARAMETER OutDir
  Destination folder. Default: models/gguf/direct

.PARAMETER FileName
  Optional override for saved filename.

.PARAMETER Force
  Re-download even if the destination file already exists.

.PARAMETER ExpectedSha256
  Optional SHA256 (64 hex). Verified after download.

.PARAMETER AllowedHosts
  Override allowlist (defaults to Get-DefaultTrustedDownloadHosts).

.PARAMETER SkipAllowlist
  Do not enforce host allowlist (not recommended).

.PARAMETER AllowHttp
  Allow http:// URLs (default: HTTPS only).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $Url,
  [string] $OutDir = "",
  [string] $FileName = "",
  [switch] $Force,
  [string] $ExpectedSha256 = "",
  [string[]] $AllowedHosts = @(),
  [switch] $SkipAllowlist,
  [switch] $AllowHttp
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not $OutDir) {
  $OutDir = Join-Path $RepoRoot "models\gguf\direct"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

if (-not $SkipAllowlist) {
  if (-not (Test-UrlHostAllowlisted -Url $Url -AllowedHosts $AllowedHosts -AllowHttp:$AllowHttp)) {
    throw ("URL host not allowlisted (or not HTTPS): {0}`nPass -AllowedHosts / -SkipAllowlist only if you trust the source.`nSee docs/trusted-sources.md" -f $Url)
  }
} elseif (-not $AllowHttp) {
  $u = [Uri]$Url
  if ($u.Scheme -ne "https") {
    throw "Only HTTPS URLs are allowed unless -AllowHttp is set."
  }
}

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
  if ($ExpectedSha256) {
    Assert-FileSha256 -Path $dest -ExpectedSha256 $ExpectedSha256 | Out-Null
    Write-Host "  Existing file SHA256 verified."
  } else {
    Write-Host ("  SHA256: {0}" -f (Get-FileSha256Hex -Path $dest))
  }
  Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"
  return
}

Write-Host "Downloading:"
Write-Host "  $Url"
Write-Host "  -> $dest"

[void](Save-RemoteFile -Url $Url -Destination $dest -ExpectedSha256 $ExpectedSha256 `
    -AllowedHosts $AllowedHosts -SkipAllowlist:$SkipAllowlist)

$sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
Write-Host "Saved ($sizeMb MB): $dest"
Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"

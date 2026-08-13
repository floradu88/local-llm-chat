<#
.SYNOPSIS
  Download GGUF (or selected files) from Hugging Face Hub into models/gguf.

.PARAMETER Repo
  Hub id, e.g. bartowski/Qwen2.5-Coder-7B-Instruct-GGUF

.PARAMETER File
  Exact filename inside the repo.

.PARAMETER Include
  Glob pattern for huggingface-cli, e.g. *Q4_K_M.gguf

.PARAMETER OutDir
  Destination folder. Default: <repo>/models/gguf/<Repo>

.PARAMETER Token
  HF token for gated models (or set HF_TOKEN / HUGGING_FACE_HUB_TOKEN).

.PARAMETER Url
  Direct HTTPS URL to a .gguf file (fallback without huggingface-cli).

.PARAMETER Force
  Re-download even if matching .gguf files are already under OutDir.
#>
[CmdletBinding()]
param(
  [string] $Repo = "",
  [string] $File = "",
  [string] $Include = "",
  [string] $OutDir = "",
  [string] $Token = "",
  [string] $Url = "",
  [switch] $Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

if ($Token) {
  $env:HF_TOKEN = $Token
  $env:HUGGING_FACE_HUB_TOKEN = $Token
}

function Get-HfCli {
  $cmd = Get-Command huggingface-cli -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command hf -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

if ($Url) {
  if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot "models\gguf\direct"
  }
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $name = Split-Path -Leaf ([Uri]$Url).AbsolutePath
  $dest = Join-Path $OutDir $name
  if (-not $Force -and (Test-LocalFilePresent -Path $dest)) {
    $sizeMb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
    Write-Host "Skip download (already on disk, $sizeMb MB): $dest"
    Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"
    return
  }
  Write-Host "Downloading $Url -> $dest"
  Invoke-WebRequest -Uri $Url -OutFile $dest
  Write-Host "Saved: $dest"
  Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath `"$dest`" -Name <local-name>"
  return
}

if (-not $Repo) {
  throw "Specify -Repo org/name, or -Url https://.../file.gguf"
}

if (-not $OutDir) {
  $safe = $Repo -replace "/", [IO.Path]::DirectorySeparatorChar
  $OutDir = Join-Path $RepoRoot "models\gguf\$safe"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

# Skip when a matching GGUF is already present (exact -File, or any *.gguf for -Include / whole repo)
if (-not $Force) {
  $existing = @()
  if ($File) {
    $candidate = Join-Path $OutDir $File
    if (Test-LocalFilePresent -Path $candidate) {
      $existing = @(Get-Item -LiteralPath $candidate)
    }
  } else {
    $existing = @(Get-ChildItem -Path $OutDir -Recurse -Filter "*.gguf" -File -ErrorAction SilentlyContinue)
    if ($Include -and $existing.Count -gt 0) {
      # Convert simple *foo* globs to wildcard match
      $existing = @($existing | Where-Object { $_.Name -like $Include })
    }
  }
  if ($existing.Count -gt 0) {
    Write-Host "Skip download (already on disk under $OutDir):"
    foreach ($f in $existing) {
      $mb = [math]::Round($f.Length / 1MB, 1)
      Write-Host ("  {0} ({1} MB)" -f $f.FullName, $mb)
    }
    Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath <path-to.gguf> -Name <local-name>"
    Write-Host "(Re-download with -Force if you need a fresh copy.)"
    return
  }
}

$hf = Get-HfCli
if (-not $hf) {
  Write-Host "huggingface-cli not found. Installing huggingface_hub for current user..."
  python -m pip install --user "huggingface_hub[cli]"
  Add-PythonUserScriptsToPath
  $hf = Get-HfCli
  if (-not $hf) {
    $candidates = Get-ChildItem -Path $env:LOCALAPPDATA, $env:APPDATA -Filter "huggingface-cli.exe" -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    if (-not $candidates) {
      $candidates = Get-ChildItem -Path $env:LOCALAPPDATA, $env:APPDATA -Filter "hf.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    }
    if ($candidates) { $hf = $candidates }
  }
}

if ($hf) {
  # Both `hf download` and `huggingface-cli download` share this shape
  $downloadArgs = @("download", $Repo, "--local-dir", $OutDir)
  if ($File) {
    $downloadArgs += $File
  }
  if ($Include) {
    $downloadArgs += @("--include", $Include)
  }
  Write-Host "Running: $hf $($downloadArgs -join ' ')"
  & $hf @downloadArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Hugging Face download failed with exit $LASTEXITCODE"
  }
} else {
  if (-not $File) {
    throw "Neither huggingface-cli nor hf found, and -File was not set for a direct URL construct. Install: pip install --user `"huggingface_hub[cli]`" or pass -Url."
  }
  $direct = "https://huggingface.co/$Repo/resolve/main/$File"
  $dest = Join-Path $OutDir $File
  Write-Host "Downloading $direct -> $dest"
  Invoke-WebRequest -Uri $direct -OutFile $dest
}

Write-Host "Files under: $OutDir"
Get-ChildItem -Path $OutDir -Recurse -Filter "*.gguf" -ErrorAction SilentlyContinue |
  ForEach-Object { Write-Host "  $($_.FullName)" }
Write-Host "Next: .\scripts\Import-GGUF.ps1 -GgufPath <path-to.gguf> -Name <local-name>"

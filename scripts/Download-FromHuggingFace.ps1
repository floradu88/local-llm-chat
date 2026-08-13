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
#>
[CmdletBinding()]
param(
  [string] $Repo = "",
  [string] $File = "",
  [string] $Include = "",
  [string] $OutDir = "",
  [string] $Token = "",
  [string] $Url = ""
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

<#
.SYNOPSIS
  Check for Cursor and install the per-user Windows build if missing.

.DESCRIPTION
  Detects Cursor under %LOCALAPPDATA%\Programs\Cursor or Program Files / PATH.
  If not installed (or -Force), installs for the current user only (no admin):
    1) winget Anysphere.Cursor (user-friendly when available)
    2) else official user-setup EXE from cursor.com API (silent Inno Setup)

.PARAMETER CheckOnly
  Report install status and exit 0 if present, 1 if missing (no install).

.PARAMETER Force
  Run the installer even when Cursor is already present.

.PARAMETER SkipWinget
  Skip winget and download the official user-setup EXE directly.

.PARAMETER SkipLaunchKill
  Do not stop Cursor.exe if the installer auto-launches it.
#>
[CmdletBinding()]
param(
  [switch] $CheckOnly,
  [switch] $Force,
  [switch] $SkipWinget,
  [switch] $SkipLaunchKill
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

$info = Get-CursorInstallInfo
Write-Section "Cursor status"
Write-Host ("  Installed: {0}" -f $info.Installed)
Write-Host ("  Scope:     {0}" -f $info.Scope)
if ($info.ExePath) { Write-Host ("  Exe:       {0}" -f $info.ExePath) }
if ($info.CmdPath) { Write-Host ("  CLI:       {0}" -f $info.CmdPath) }

if ($CheckOnly) {
  if ($info.Installed) {
    Write-Host "  CheckOnly: present"
    exit 0
  }
  Write-Host "  CheckOnly: Cursor not found. Re-run without -CheckOnly to install for current user."
  exit 1
}

if ($info.Installed -and -not $Force) {
  Write-Host "  Already installed - skipping install."
  Write-Host "  Wire models: config\cursor-openai-local.example.md (Case I)"
  exit 0
}

Write-Section "Install (current user)"
$installed = $false

# --- 1) winget ---
if (-not $SkipWinget) {
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host "  Trying winget Anysphere.Cursor (per-user when supported)..."
    try {
      $wgArgs = @(
        "install",
        "--id", "Anysphere.Cursor",
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
      )
      # Prefer user scope when winget supports it
      $wgArgs += @("--scope", "user")
      & winget @wgArgs
      $code = $LASTEXITCODE
      # Some winget builds reject --scope user; retry without it
      if ($code -ne 0) {
        Write-Host "  winget --scope user failed (exit $code); retrying without scope..."
        $wgArgs = @(
          "install",
          "--id", "Anysphere.Cursor",
          "--exact",
          "--silent",
          "--accept-package-agreements",
          "--accept-source-agreements",
          "--disable-interactivity"
        )
        & winget @wgArgs
        $code = $LASTEXITCODE
      }
      Start-Sleep -Seconds 2
      if ((Get-CursorInstallInfo).Installed) {
        $installed = $true
        Write-Host "  winget install OK"
      } elseif ($code -eq 0) {
        # winget reported success but path not visible yet
        $installed = $true
        Write-Host "  winget reported success (refresh PATH / Start Menu if Cursor is missing)"
      } else {
        Write-Warning "winget install exit $code - falling back to user-setup EXE"
      }
    } catch {
      Write-Warning "winget failed: $_ - falling back to user-setup EXE"
    }
  } else {
    Write-Host "  winget not on PATH - using official user-setup EXE"
  }
}

# --- 2) Official user-setup EXE ---
if (-not $installed) {
  $api = "https://cursor.com/api/download?platform=win32-x64-user&releaseTrack=stable"
  Write-Host "  Resolving user installer from: $api"
  $meta = Invoke-RestMethod -Uri $api -TimeoutSec 60
  $downloadUrl = [string]$meta.downloadUrl
  $version = [string]$meta.version
  if (-not $downloadUrl) {
    throw "Could not resolve Cursor user-setup download URL from API"
  }
  Write-Host ("  Version: {0}" -f $version)
  Write-Host ("  URL:     {0}" -f $downloadUrl)

  $dir = Join-Path $env:TEMP "local-llm-chat-cursor"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $installer = Join-Path $dir ("CursorUserSetup-x64-{0}.exe" -f $version)
  Write-Host ("  Downloading to: {0}" -f $installer)
  try {
    Start-BitsTransfer -Source $downloadUrl -Destination $installer -ErrorAction Stop
  } catch {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installer -UseBasicParsing
  }
  if (-not (Test-Path -LiteralPath $installer)) {
    throw "Download missing: $installer"
  }

  $log = Join-Path $dir "cursor-user-setup.log"
  $args = @(
    "/CURRENTUSER",
    "/VERYSILENT",
    "/SP-",
    "/NORESTART",
    "/SUPPRESSMSGBOXES",
    "/LOG=$log"
  )
  Write-Host "  Running silent per-user installer..."
  $p = Start-Process -FilePath $installer -ArgumentList $args -PassThru -Wait
  Write-Host ("  Installer exit code: {0}" -f $p.ExitCode)
  Write-Host ("  Log: {0}" -f $log)

  if (-not $SkipLaunchKill) {
    Start-Sleep -Seconds 2
    Get-Process -Name "Cursor" -ErrorAction SilentlyContinue | ForEach-Object {
      Write-Host "  Stopping auto-launched Cursor.exe (pid $($_.Id))"
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
  }

  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne $null) {
    # Inno Setup often returns 0; non-zero is a real failure
    Write-Warning "Installer returned $($p.ExitCode)"
  }
}

$after = Get-CursorInstallInfo
Write-Section "Result"
Write-Host ("  Installed: {0}" -f $after.Installed)
Write-Host ("  Scope:     {0}" -f $after.Scope)
if ($after.ExePath) { Write-Host ("  Exe:       {0}" -f $after.ExePath) }

if (-not $after.Installed) {
  Write-Warning "Cursor still not detected. Open a new shell or install from https://cursor.com/download (Windows user setup)."
  exit 1
}

Write-Host ""
Write-Host "Next (Case I - wire local Ollama):"
Write-Host "  Settings > Models"
Write-Host "    Base URL: http://localhost:11434/v1"
Write-Host "    API key:  ollama"
Write-Host "    Model:    tag from ollama list (e.g. qwen2.5-coder:7b)"
Write-Host "  Checklist: config\cursor-openai-local.example.md"
exit 0

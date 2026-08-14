<#
.SYNOPSIS
  Check for VS Code and install the per-user Windows build if missing.

.DESCRIPTION
  Detects Code.exe under %LOCALAPPDATA%\Programs\Microsoft VS Code or Program Files.
  If not installed (or -Force), installs for the current user when possible:
    1) winget Microsoft.VisualStudioCode (--scope user)
    2) else official User Installer EXE (silent)

.PARAMETER CheckOnly
  Report install status and exit 0 if present, 1 if missing (no install).

.PARAMETER Force
  Run the installer even when VS Code is already present.

.PARAMETER SkipWinget
  Skip winget and download the official user installer directly.
#>
[CmdletBinding()]
param(
  [switch] $CheckOnly,
  [switch] $Force,
  [switch] $SkipWinget
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

$info = Get-VSCodeInstallInfo
Write-Section "VS Code status"
Write-Host ("  Installed: {0}" -f $info.Installed)
Write-Host ("  Scope:     {0}" -f $info.Scope)
if ($info.ExePath) { Write-Host ("  Exe:       {0}" -f $info.ExePath) }
if ($info.CmdPath) { Write-Host ("  CLI:       {0}" -f $info.CmdPath) }

if ($CheckOnly) {
  if ($info.Installed) {
    Write-Host "  CheckOnly: present"
    exit 0
  }
  Write-Host "  CheckOnly: VS Code not found. Re-run without -CheckOnly to install for current user."
  exit 1
}

if ($info.Installed -and -not $Force) {
  Write-Host "  Already installed - skipping install."
  Write-Host "  Wire local AI: .\scripts\Install-VSCodeLocalAI.ps1  (Case H)"
  exit 0
}

Write-Section "Install (prefer current user)"
$installed = $false

if (-not $SkipWinget) {
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host "  Trying winget Microsoft.VisualStudioCode (user scope when supported)..."
    try {
      $wgArgs = @(
        "install",
        "--id", "Microsoft.VisualStudioCode",
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity",
        "--scope", "user"
      )
      & winget @wgArgs
      if ($LASTEXITCODE -eq 0) { $installed = $true }
      else {
        Write-Warning "winget user-scope exited $LASTEXITCODE; retrying without --scope..."
        $wgArgs = @(
          "install",
          "--id", "Microsoft.VisualStudioCode",
          "--exact",
          "--silent",
          "--accept-package-agreements",
          "--accept-source-agreements",
          "--disable-interactivity"
        )
        & winget @wgArgs
        if ($LASTEXITCODE -eq 0) { $installed = $true }
      }
    } catch {
      Write-Warning "winget failed: $_"
    }
  } else {
    Write-Host "  winget not found - using official User Installer."
  }
}

if (-not $installed) {
  $tmp = Join-Path $env:TEMP ("VSCodeUserSetup-{0}.exe" -f [guid]::NewGuid().ToString("n"))
  $url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
  Write-Host "  Downloading VS Code User Installer..."
  Write-Host "  $url"
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  Write-Host "  Running silent user install..."
  $p = Start-Process -FilePath $tmp -ArgumentList "/VERYSILENT","/NORESTART","/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath" -Wait -PassThru
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne $null) {
    Write-Warning "Installer exit code: $($p.ExitCode)"
  } else {
    $installed = $true
  }
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 2
$info = Get-VSCodeInstallInfo
Write-Section "Result"
Write-Host ("  Installed: {0}" -f $info.Installed)
if ($info.ExePath) { Write-Host ("  Exe:       {0}" -f $info.ExePath) }
if ($info.CmdPath) { Write-Host ("  CLI:       {0}" -f $info.CmdPath) }

if (-not $info.Installed) {
  Write-Warning "VS Code still not detected. Install manually: https://code.visualstudio.com/ (User Installer)"
  exit 1
}

Write-Host "  Next: .\scripts\Install-VSCodeLocalAI.ps1"
exit 0

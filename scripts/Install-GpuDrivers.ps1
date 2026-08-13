<#
.SYNOPSIS
  Optional NVIDIA GPU driver install helper - with VM / passthrough guidance.

.DESCRIPTION
  Detects whether this Windows OS is a VM and whether a real NVIDIA device is
  visible to the guest. Answers: can a VM use a GPU with Ollama?

  - Bare metal + NVIDIA: yes -> optional Studio/Game Ready driver download/install
  - VM + NVIDIA (passthrough / GPU-P / GRID / cloud GPU): yes -> install guest drivers
  - VM without NVIDIA: no -> installing drivers here cannot reach the host GPU

  Driver install always needs admin (UAC). Default mode is detect-only.

.PARAMETER Install
  Download the latest WHQL DCH driver for a matching GeForce series and launch
  the installer elevated. Skipped when no NVIDIA device is visible (unless -Force).

.PARAMETER OpenDownloadPage
  Open the official NVIDIA drivers page in the browser (safest fallback).

.PARAMETER Branch
  Studio (default, better for LLM/creator) or GameReady. Both satisfy Ollama
  when version is new enough (>= ~551).

.PARAMETER Force
  Attempt download/install even when environment says drivers will not help
  (e.g. VM with only a virtual display).

.PARAMETER DownloadDir
  Where to save the installer (default: %TEMP%\local-llm-chat-nvidia).

.PARAMETER SkipDownload
  With -Install, only print the resolved URL (no download).
#>
[CmdletBinding()]
param(
  [switch] $Install,
  [switch] $OpenDownloadPage,
  [ValidateSet("Studio", "GameReady")]
  [string] $Branch = "Studio",
  [switch] $Force,
  [string] $DownloadDir = "",
  [switch] $SkipDownload
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

$envInfo = Get-OllamaGpuEnvironment

Write-Section "Machine"
Write-Host ("  Manufacturer: {0}" -f $envInfo.Manufacturer)
Write-Host ("  Model:        {0}" -f $envInfo.Model)
Write-Host ("  Virtual machine: {0}" -f $envInfo.IsVirtualMachine)
if ($envInfo.IsVirtualMachine) {
  Write-Host ("  Hypervisor:   {0}" -f $envInfo.Hypervisor)
  Write-Host ("  HypervisorPresent flag: {0}" -f $envInfo.HypervisorPresent)
  foreach ($e in $envInfo.VmEvidence) {
    Write-Host ("    evidence: {0}" -f $e)
  }
}

Write-Section "NVIDIA in this OS"
if ($envInfo.NvidiaPresent) {
  foreach ($a in $envInfo.NvidiaAdapters) {
    Write-Host ("  {0}" -f $a.Name)
    Write-Host ("    Driver={0}  DEV_{1}  Status={2}" -f $a.DriverVersion, $a.DeviceId, $a.Status)
  }
} else {
  Write-Host "  No NVIDIA device visible to this OS"
}

Write-Section "Can a VM use a GPU with Ollama?"
if (-not $envInfo.IsVirtualMachine) {
  Write-Host "  Not a VM - use the physical GPU path below."
} elseif ($envInfo.NvidiaPresent) {
  Write-Host "  YES - this guest already sees an NVIDIA device."
  Write-Host "  Typical setups: PCIe passthrough, Hyper-V GPU-P, GRID/vGPU, cloud GPU VM."
} else {
  Write-Host "  NO (not yet) - guest has no NVIDIA device."
  Write-Host "  The host GPU is invisible until the hypervisor exposes it."
  Write-Host "  Then install NVIDIA drivers inside the guest and re-run this script."
}

Write-Section "Guidance"
foreach ($g in $envInfo.Guidance) {
  Write-Host ("  - {0}" -f $g)
}
Write-Host "  Docs: https://docs.ollama.com/gpu"
Write-Host "  Drivers: https://www.nvidia.com/Download/index.aspx"

$officialPage = "https://www.nvidia.com/Download/index.aspx"

if ($OpenDownloadPage -or (-not $Install -and -not $envInfo.CanInstallDrivers)) {
  if ($OpenDownloadPage) {
    Write-Section "Open download page"
    Start-Process $officialPage
    Write-Host "  Opened: $officialPage"
  }
}

if (-not $Install) {
  Write-Section "Optional install"
  Write-Host "  Detect-only (default). To download + elevate installer:"
  Write-Host "    .\scripts\Install-GpuDrivers.ps1 -Install"
  Write-Host "  Or open NVIDIA's page:"
  Write-Host "    .\scripts\Install-GpuDrivers.ps1 -OpenDownloadPage"
  if ($envInfo.CanInstallDrivers) {
    exit 0
  } elseif ($envInfo.IsVirtualMachine -and -not $envInfo.NvidiaPresent) {
    exit 3
  } else {
    exit 2
  }
}

# --- Install path ---
Write-Section "Install"
if (-not $envInfo.CanInstallDrivers -and -not $Force) {
  Write-Warning "Environment does not look ready for NVIDIA driver install in this OS."
  Write-Host "  Re-run with -Force to override, or -OpenDownloadPage."
  if ($envInfo.IsVirtualMachine -and -not $envInfo.NvidiaPresent) {
    Write-Host "  Fix the hypervisor first (passthrough / GPU-P / cloud GPU), then install."
  }
  exit 3
}

$gpuName = ""
if ($envInfo.NvidiaAdapters -and $envInfo.NvidiaAdapters.Count -gt 0) {
  $gpuName = [string]$envInfo.NvidiaAdapters[0].Name
}

$ids = Get-NvidiaDriverLookupIds -GpuName $gpuName
# Studio channel: dltype often ignored by Ajax; we still prefer Studio messaging + page.
$ajax = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php" +
  "?func=DriverManualLookup" +
  "&psid=$($ids.ProductSeriesId)" +
  "&pfid=$($ids.ProductId)" +
  "&osID=$($ids.OsId)" +
  "&languageCode=1033" +
  "&isWHQL=1" +
  "&dch=1" +
  "&sort1=0" +
  "&numberOfResults=1"

Write-Host ("  GPU name for lookup: {0}" -f $(if ($gpuName) { $gpuName } else { "(none - using modern GeForce series)" }))
Write-Host ("  Branch preference:   {0}" -f $Branch)
Write-Host "  Querying NVIDIA AjaxDriverService..."

$downloadUrl = $null
$version = $null
try {
  $resp = Invoke-WebRequest -Uri $ajax -UseBasicParsing -TimeoutSec 60
  $payload = $resp.Content | ConvertFrom-Json
  if ($payload.IDS -and $payload.IDS.Count -gt 0) {
    $info = $payload.IDS[0].downloadInfo
    $version = [string]$info.Version
    $downloadUrl = [string]$info.DownloadURL
  }
} catch {
  Write-Warning ("Driver lookup failed: {0}" -f $_)
}

if (-not $downloadUrl) {
  Write-Warning "Could not resolve an automatic download URL for this GPU series."
  Write-Host "  Opening official page instead (pick your exact GPU + $Branch)."
  Start-Process $officialPage
  Write-Host "  For enterprise/GRID/vGPU: use NVIDIA enterprise driver downloads for that product."
  exit 4
}

Write-Host ("  Latest WHQL DCH version: {0}" -f $version)
Write-Host ("  URL: {0}" -f $downloadUrl)

if ($SkipDownload) {
  Write-Host "  SkipDownload set - not downloading."
  exit 0
}

if (-not $DownloadDir) {
  $DownloadDir = Join-Path $env:TEMP "local-llm-chat-nvidia"
}
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
$installer = Join-Path $DownloadDir ("{0}-nvidia-driver.exe" -f $version)

Write-Host ("  Downloading to: {0}" -f $installer)
try {
  Start-BitsTransfer -Source $downloadUrl -Destination $installer -ErrorAction Stop
} catch {
  Write-Host "  BITS failed; falling back to Invoke-WebRequest..."
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installer -UseBasicParsing
}

if (-not (Test-Path -LiteralPath $installer)) {
  throw "Download missing: $installer"
}
$len = (Get-Item -LiteralPath $installer).Length
Write-Host ("  Downloaded {0:N1} MB" -f ($len / 1MB))

Write-Host "  Launching elevated installer (UAC). Accept the NVIDIA license in the UI."
Write-Host "  Prefer Custom -> Graphics Driver only if offered; reboot if prompted."
try {
  $p = Start-Process -FilePath $installer -Verb RunAs -PassThru -Wait
  Write-Host ("  Installer exit code: {0}" -f $p.ExitCode)
} catch {
  Write-Warning ("Elevation failed or cancelled: {0}" -f $_)
  Write-Host "  Run the file manually as Administrator:"
  Write-Host "    $installer"
  exit 5
}

Write-Host ""
Write-Host "Next: reboot if required, start Ollama, then:"
Write-Host "  .\scripts\Test-GpuSupport.ps1"
exit 0

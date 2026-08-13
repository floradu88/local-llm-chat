<#
.SYNOPSIS
  Check whether this Windows machine can use a GPU with Ollama (non-admin by default).

.DESCRIPTION
  Reports display adapters, nvidia-smi if available, Ollama log hints, and whether the
  GPU meets Ollama NVIDIA requirements (compute capability 5.0+, modern driver).

.PARAMETER Elevated
  Re-launch an elevated (UAC) driver/device check and merge results.

.PARAMETER OutFile
  Optional path to write a text report.
#>
[CmdletBinding()]
param(
  [switch] $Elevated,
  [string] $OutFile = ""
)

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")
Add-OllamaToSessionPath

$report = New-Object System.Collections.Generic.List[string]
function Add-Line([string] $s) {
  [void]$report.Add($s)
  Write-Host $s
}

Add-Line "=== Test-GpuSupport (non-admin) ==="
Add-Line ("Time: {0}" -f (Get-Date -Format o))
Add-Line ("Repo: {0}" -f $RepoRoot)
Add-Line ""

# --- Adapters ---
Add-Line "--- Display adapters ---"
$adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
$nvidiaName = $null
foreach ($a in $adapters) {
  $ram = if ($a.AdapterRAM -and $a.AdapterRAM -gt 0) {
    "{0:N1} GB" -f ($a.AdapterRAM / 1GB)
  } else {
    "n/a"
  }
  Add-Line ("  {0}" -f $a.Name)
  Add-Line ("    Driver={0}  Date={1}  Status={2}  AdapterRAM={3}" -f $a.DriverVersion, $a.DriverDate, $a.Status, $ram)
  if ($a.Name -match "NVIDIA|GeForce|Quadro|Tesla|RTX|GTX") {
    $nvidiaName = $a.Name
  }
}
if ($adapters.Count -eq 0) {
  Add-Line "  (none found)"
}
Add-Line ""

# --- nvidia-smi ---
Add-Line "--- nvidia-smi ---"
$nvsmiList = New-Object System.Collections.Generic.List[string]
$cmd = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
  [void]$nvsmiList.Add($cmd.Source)
}
foreach ($candidate in @(
    (Join-Path $env:ProgramFiles "NVIDIA Corporation\NVSMI\nvidia-smi.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "NVIDIA Corporation\NVSMI\nvidia-smi.exe"),
    (Join-Path $env:SystemRoot "System32\nvidia-smi.exe")
  )) {
  if ($candidate -and (Test-Path -LiteralPath $candidate) -and -not ($nvsmiList -contains $candidate)) {
    [void]$nvsmiList.Add($candidate)
  }
}

$driverVersion = $null
$gpuSmiName = $null
$vramMiB = $null
if ($nvsmiList.Count -gt 0) {
  $nvsmi = $nvsmiList[0]
  Add-Line "  Path: $nvsmi"
  try {
    $smi = & $nvsmi 2>&1 | Out-String
    foreach ($line in ($smi -split "`r?`n")) {
      Add-Line ("  {0}" -f $line)
    }
    if ($smi -match "Driver Version:\s*([0-9.]+)") {
      $driverVersion = $Matches[1]
    }
    if ($smi -match "\|\s+\d+\s+(GeForce[^\|]+?)\s+WDDM") {
      $gpuSmiName = $Matches[1].Trim()
    }
    if ($smi -match "(\d+)MiB\s*/\s*(\d+)MiB") {
      $vramMiB = [int]$Matches[2]
    }
  } catch {
    Add-Line ("  ERROR running nvidia-smi: {0}" -f $_)
  }
} else {
  Add-Line "  nvidia-smi NOT found (NVIDIA driver tools missing or not on PATH)"
}
Add-Line ""

# --- Known too-old heuristics ---
$ccTooOld = $false
$ccNote = ""
$checkName = if ($gpuSmiName) { $gpuSmiName } elseif ($nvidiaName) { $nvidiaName } else { "" }
if ($checkName -match "GT 650M|GT 640M|GT 635M|GT 630M|GT 620M|GTX 6[0-9]{2}M|GeForce [456][0-9]{2}M") {
  $ccTooOld = $true
  $ccNote = "Likely Kepler / CUDA CC ~3.x - below Ollama minimum CC 5.0"
} elseif ($checkName -match "HD Graphics 4000|HD Graphics 3000|HD Graphics 2500") {
  $ccNote = "Intel iGPU is too old for useful Ollama GPU offload"
}

# --- Ollama logs ---
Add-Line "--- Ollama inference hints (logs) ---"
$logDir = Join-Path $env:LOCALAPPDATA "Ollama"
$ollamaCpuOnly = $null
$ollamaVram = $null
if (Test-Path $logDir) {
  $logFiles = Get-ChildItem $logDir -Filter "server*.log" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
  $found = $false
  foreach ($lf in $logFiles) {
    $hits = Select-String -Path $lf.FullName -Pattern "inference compute|total_vram|discovering available GPUs|CUDA|vulkan|library=cpu|library=cuda" -CaseSensitive:$false -ErrorAction SilentlyContinue |
      Select-Object -Last 15
    if ($hits) {
      $found = $true
      Add-Line ("  From {0}:" -f $lf.Name)
      foreach ($h in $hits) {
        Add-Line ("    {0}" -f $h.Line.Trim())
        if ($h.Line -match "library=cpu") { $ollamaCpuOnly = $true }
        if ($h.Line -match "library=cuda|library=rocm|library=vulkan") { $ollamaCpuOnly = $false }
        if ($h.Line -match 'total_vram="([^"]+)"') { $ollamaVram = $Matches[1] }
      }
      break
    }
  }
  if (-not $found) {
    Add-Line "  No GPU-related lines in recent server*.log (start Ollama once to generate logs)"
  }
} else {
  Add-Line "  No %LOCALAPPDATA%\Ollama log folder yet"
}

Add-Line ""
Add-Line "--- Ollama live API ---"
if (Test-OllamaApi) {
  Add-Line "  API OK http://127.0.0.1:11434"
  try {
    if (Test-OllamaCommand) {
      $psOut = ollama ps 2>&1 | Out-String
      foreach ($line in ($psOut -split "`r?`n" | Where-Object { $_.Trim() })) {
        Add-Line ("  ollama ps: {0}" -f $line)
      }
    }
  } catch { }
} else {
  Add-Line "  API not reachable (start Ollama tray app for live checks)"
}

Add-Line ""
Add-Line "--- Requirements (Ollama NVIDIA) ---"
Add-Line "  Official: compute capability 5.0+ ; driver roughly 550+ (newer for some GPUs)"
Add-Line "  Docs: https://docs.ollama.com/gpu"

# Verdict
Add-Line ""
Add-Line "=== VERDICT (non-admin) ==="
$usable = $false
$reasons = New-Object System.Collections.Generic.List[string]

if (-not $nvidiaName -and -not $gpuSmiName) {
  [void]$reasons.Add("No NVIDIA GPU detected for CUDA path")
}
if ($ccTooOld) {
  [void]$reasons.Add($ccNote)
}
if ($driverVersion) {
  try {
    $major = [int]($driverVersion.Split(".")[0])
    if ($major -lt 550) {
      [void]$reasons.Add("Driver $driverVersion is below Ollama typical 550+ requirement")
    }
  } catch { }
}
if ($ollamaCpuOnly -eq $true -or $ollamaVram -eq "0 B") {
  [void]$reasons.Add("Ollama logs show CPU-only inference (vram=$ollamaVram)")
}
if ($vramMiB -and $vramMiB -lt 4096 -and -not $ccTooOld) {
  [void]$reasons.Add("VRAM ${vramMiB} MiB is tight for most coding models (4GB+ recommended)")
}

if ($reasons.Count -eq 0 -and ($nvidiaName -or $gpuSmiName) -and $driverVersion) {
  $usable = $true
  Add-Line "  GPU likely usable with Ollama (still confirm with a model load + ollama ps)."
} else {
  Add-Line "  GPU acceleration for Ollama: NOT usable / not supported on this machine."
  foreach ($r in $reasons) {
    Add-Line ("    - {0}" -f $r)
  }
  if ($ccNote -and -not $ccTooOld) {
    Add-Line ("    - {0}" -f $ccNote)
  }
  Add-Line "  Practical path: run on CPU (use -Tier 8GB or 16GB coding models)."
}

# --- Elevated section ---
if ($Elevated) {
  Add-Line ""
  Add-Line "=== Elevated admin check (UAC) ==="
  $outElev = Join-Path $env:TEMP ("ollama-gpu-admin-{0}.txt" -f [guid]::NewGuid().ToString("N"))
  $elevScript = Join-Path $PSScriptRoot "Test-GpuSupport.Elevated.ps1"
  if (-not (Test-Path $elevScript)) {
    Add-Line "  Missing helper: $elevScript"
  } else {
    try {
      $p = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $elevScript, "-OutFile", $outElev) `
        -Verb RunAs -PassThru -Wait
      Add-Line ("  Elevated process exit code: {0}" -f $p.ExitCode)
    } catch {
      Add-Line ("  Elevation failed or cancelled: {0}" -f $_)
    }
    if (Test-Path $outElev) {
      Get-Content $outElev | ForEach-Object { Add-Line ("  {0}" -f $_) }
      Remove-Item $outElev -Force -ErrorAction SilentlyContinue
    } else {
      Add-Line "  No elevated output (UAC denied or elevation unavailable in this session)."
    }
  }
}

if ($OutFile) {
  $dir = Split-Path -Parent $OutFile
  if ($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $report | Set-Content -Path $OutFile -Encoding utf8
  Write-Host ""
  Write-Host "Report written: $OutFile"
}

if ($usable) { exit 0 } else { exit 2 }

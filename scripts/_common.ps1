# Shared helpers for local-llm-chat scripts (dot-source from other scripts).
# Usage: . (Join-Path $PSScriptRoot "_common.ps1")

function Get-RepoRoot {
  Split-Path -Parent $PSScriptRoot
}

function Add-OllamaToSessionPath {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Ollama"),
    $env:OLLAMA_INSTALL_DIR
  ) | Where-Object { $_ -and (Test-Path $_) }

  foreach ($dir in $candidates) {
    if ($env:Path -notlike "*$dir*") {
      $env:Path = "$dir;$env:Path"
    }
  }
}

function Test-OllamaCommand {
  Add-OllamaToSessionPath
  return [bool](Get-Command ollama -ErrorAction SilentlyContinue)
}

function Test-OllamaApi {
  param([int] $TimeoutSec = 3)
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec $TimeoutSec | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Get-OllamaModelsRoots {
  $roots = @()
  foreach ($candidate in @(
      $env:OLLAMA_MODELS,
      (Join-Path (Split-Path -Parent $PSScriptRoot) "models\ollama"),
      (Join-Path $env:USERPROFILE ".ollama\models")
    )) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      $full = (Resolve-Path -LiteralPath $candidate).Path
      if ($roots -notcontains $full) {
        $roots += $full
      }
    }
  }
  return $roots
}

function Get-OllamaInstalledModelNames {
  <#
  .SYNOPSIS
    Names Ollama already has locally (on-disk manifests first, then API).
  #>
  $list = New-Object System.Collections.ArrayList

  # Prefer on-disk manifests (fast; works when the API/tray is down)
  foreach ($root in @(Get-OllamaModelsRoots)) {
    $manifestRoot = Join-Path $root "manifests"
    if (-not (Test-Path -LiteralPath $manifestRoot)) { continue }
    Get-ChildItem -LiteralPath $manifestRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $rel = $_.FullName.Substring($manifestRoot.Length).TrimStart("\", "/")
      $parts = $rel -split "[\\/]"
      if ($parts.Count -lt 2) { return }
      $hostPart = $parts[0]
      $n = $null
      if ($hostPart -eq "registry.ollama.ai" -and $parts.Count -ge 4 -and $parts[1] -eq "library") {
        $n = "{0}:{1}" -f $parts[2], $parts[3]
      } elseif ($hostPart -eq "hf.co" -and $parts.Count -ge 3) {
        $n = "hf.co/{0}" -f ($parts[1..($parts.Count - 1)] -join "/")
      }
      if ($n -and ($list -notcontains $n)) { [void]$list.Add($n) }
    }
  }

  try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2
    foreach ($m in @($tags.models)) {
      $n = ([string]$m.name).Trim()
      if ($n -and ($list -notcontains $n)) { [void]$list.Add($n) }
    }
  } catch { }

  return @($list.ToArray())
}

function Test-OllamaModelInstalled {
  <#
  .SYNOPSIS
    True if the model tag is already available locally (skip re-download).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name
  )
  $want = $Name.Trim()
  if (-not $want) { return $false }

  $installed = @(Get-OllamaInstalledModelNames)
  foreach ($have in $installed) {
    if ([string]::Equals($have, $want, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  # Accept bare name when only :latest exists, and vice versa
  $wantBase = $want
  $wantTag = "latest"
  if ($want -match "^(?<base>.+):(?<tag>[^:/]+)$") {
    $wantBase = $Matches["base"]
    $wantTag = $Matches["tag"]
  }
  foreach ($have in $installed) {
    $haveBase = $have
    $haveTag = "latest"
    if ($have -match "^(?<base>.+):(?<tag>[^:/]+)$") {
      $haveBase = $Matches["base"]
      $haveTag = $Matches["tag"]
    }
    if ([string]::Equals($haveBase, $wantBase, [StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals($haveTag, $wantTag, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
    if ($want -notmatch ":" -and
        [string]::Equals($haveBase, $want, [StringComparison]::OrdinalIgnoreCase) -and
        $haveTag -eq "latest") {
      return $true
    }
  }

  return $false
}

function Test-LocalFilePresent {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [long] $MinBytes = 1
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }
  try {
    return ((Get-Item -LiteralPath $Path).Length -ge $MinBytes)
  } catch {
    return $false
  }
}

function Get-CursorExeCandidates {
  @(
    (Join-Path $env:LOCALAPPDATA "Programs\Cursor\Cursor.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles} "Cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles} "cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Cursor\Cursor.exe")
  ) | Where-Object { $_ }
}

function Get-CursorInstallInfo {
  <#
  .SYNOPSIS
    Locate Cursor.exe (prefer per-user install under LocalAppData).
  #>
  $exe = $null
  $scope = "None"
  foreach ($candidate in @(Get-CursorExeCandidates)) {
    if (Test-Path -LiteralPath $candidate) {
      $exe = (Resolve-Path -LiteralPath $candidate).Path
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) {
        $scope = "User"
      } else {
        $scope = "Machine"
      }
      break
    }
  }

  $cmd = $null
  $c = Get-Command cursor -ErrorAction SilentlyContinue
  if ($c -and $c.Source) {
    $cmd = $c.Source
    if (-not $exe) {
      # cursor.cmd often lives under resources\app\bin
      $maybe = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $cmd))) "Cursor.exe"
      if (Test-Path -LiteralPath $maybe) {
        $exe = (Resolve-Path -LiteralPath $maybe).Path
        if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) { $scope = "User" } else { $scope = "Machine" }
      }
    }
  }

  $userData = Join-Path $env:APPDATA "Cursor"
  $settings = Join-Path $userData "User\settings.json"
  $stateDb = Join-Path $userData "User\globalStorage\state.vscdb"
  $nodeHelper = $null
  if ($exe) {
    $maybeNode = Join-Path (Split-Path -Parent $exe) "resources\app\resources\helpers\node.exe"
    if (Test-Path -LiteralPath $maybeNode) {
      $nodeHelper = (Resolve-Path -LiteralPath $maybeNode).Path
    }
  }

  return [pscustomobject]@{
    Installed      = [bool]($exe -or $cmd)
    ExePath        = $exe
    CmdPath        = $cmd
    Scope          = $scope
    UserDataPath   = $userData
    SettingsPath   = $settings
    StateDbPath    = $stateDb
    NodeHelperPath = $nodeHelper
  }
}

function Test-CursorInstalled {
  return [bool]((Get-CursorInstallInfo).Installed)
}

function Test-CursorProcessRunning {
  return [bool](Get-Process -Name "Cursor" -ErrorAction SilentlyContinue)
}

function Get-VSCodeExeCandidates {
  @(
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code Insiders\Code - Insiders.exe"),
    (Join-Path ${env:ProgramFiles} "Microsoft VS Code\Code.exe"),
    (Join-Path ${env:ProgramFiles} "Microsoft VS Code Insiders\Code - Insiders.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft VS Code\Code.exe")
  ) | Where-Object { $_ }
}

function Get-VSCodeInstallInfo {
  <#
  .SYNOPSIS
    Locate VS Code Code.exe (prefer per-user install under LocalAppData).
  #>
  $exe = $null
  $scope = "None"
  $insiders = $false
  foreach ($candidate in @(Get-VSCodeExeCandidates)) {
    if (Test-Path -LiteralPath $candidate) {
      $exe = (Resolve-Path -LiteralPath $candidate).Path
      $insiders = ($exe -match "Insiders")
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) {
        $scope = "User"
      } else {
        $scope = "Machine"
      }
      break
    }
  }

  $cmd = $null
  $c = Get-Command code -ErrorAction SilentlyContinue
  if ($c -and $c.Source) {
    $cmd = $c.Source
  }
  if (-not $cmd -and $exe) {
    $binName = if ($insiders) { "code-insiders.cmd" } else { "code.cmd" }
    $maybeCmd = Join-Path (Split-Path -Parent $exe) "bin\$binName"
    if (Test-Path -LiteralPath $maybeCmd) {
      $cmd = (Resolve-Path -LiteralPath $maybeCmd).Path
    }
  }
  if (-not $exe -and $cmd) {
    # code.cmd lives under ...\Microsoft VS Code\bin
    $root = Split-Path -Parent (Split-Path -Parent $cmd)
    $maybeExe = Join-Path $root "Code.exe"
    if (-not (Test-Path -LiteralPath $maybeExe)) {
      $maybeExe = Join-Path $root "Code - Insiders.exe"
    }
    if (Test-Path -LiteralPath $maybeExe) {
      $exe = (Resolve-Path -LiteralPath $maybeExe).Path
      $insiders = ($exe -match "Insiders")
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) { $scope = "User" } else { $scope = "Machine" }
    }
  }

  $userData = if ($insiders) {
    Join-Path $env:APPDATA "Code - Insiders"
  } else {
    Join-Path $env:APPDATA "Code"
  }

  $continueDir = Join-Path $HOME ".continue"
  $continueConfig = Join-Path $continueDir "config.json"

  return [pscustomobject]@{
    Installed       = [bool]($exe -or $cmd)
    ExePath         = $exe
    CmdPath         = $cmd
    Scope           = $scope
    Insiders        = $insiders
    UserDataPath    = $userData
    SettingsPath    = (Join-Path $userData "User\settings.json")
    ContinueDir     = $continueDir
    ContinueConfig  = $continueConfig
  }
}

function Test-VSCodeInstalled {
  return [bool]((Get-VSCodeInstallInfo).Installed)
}

function Get-ContinueOllamaConfigStatus {
  <#
  .SYNOPSIS
    Check ~/.continue/config.json for Ollama (or Headroom) wiring.
  #>
  $info = Get-VSCodeInstallInfo
  $path = $info.ContinueConfig
  if (-not (Test-Path -LiteralPath $path)) {
    return [pscustomobject]@{
      Ok          = $true
      Configured  = $false
      Path        = $path
      ApiBase     = $null
      Models      = @()
      Message     = "Continue config missing"
      InstallInfo = $info
    }
  }

  try {
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      Ok          = $false
      Configured  = $false
      Path        = $path
      ApiBase     = $null
      Models      = @()
      Message     = "Continue config JSON invalid: $_"
      InstallInfo = $info
    }
  }

  $models = @()
  $apiBase = $null
  foreach ($m in @($cfg.models)) {
    $provider = [string]$m.provider
    $base = [string]$m.apiBase
    if ($provider -match "^(ollama|openai)$" -and $base -match "11434|8787|localhost|127\.0\.0\.1") {
      $models += [string]$m.model
      if (-not $apiBase) { $apiBase = $base }
    }
  }

  $configured = $models.Count -gt 0
  return [pscustomobject]@{
    Ok          = $true
    Configured  = $configured
    Path        = $path
    ApiBase     = $apiBase
    Models      = $models
    Message     = if ($configured) { "Continue wired to local models" } else { "Continue config has no local Ollama/OpenAI models" }
    InstallInfo = $info
  }
}

function Get-CursorOllamaConfigStatus {
  <#
  .SYNOPSIS
    Read Cursor openAIBaseUrl / useOpenAIKey / enabled models from state.vscdb.
  #>
  $info = Get-CursorInstallInfo
  if (-not $info.Installed) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $false
      Configured    = $false
      Message       = "Cursor not installed"
      InstallInfo   = $info
    }
  }
  if (-not (Test-Path -LiteralPath $info.StateDbPath)) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $true
      Configured    = $false
      Message       = "Cursor user data / state.vscdb missing (launch Cursor once, then re-run)"
      InstallInfo   = $info
    }
  }
  if (-not $info.NodeHelperPath) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $true
      Configured    = $false
      Message       = "Cursor bundled node.exe not found; cannot read state.vscdb"
      InstallInfo   = $info
    }
  }

  $helper = Join-Path $PSScriptRoot "_Set-CursorOllamaState.cjs"
  if (-not (Test-Path -LiteralPath $helper)) {
    throw "Missing helper: $helper"
  }

  $prevEa = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = & $info.NodeHelperPath --no-warnings $helper status --db $info.StateDbPath 2>&1
    $exit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEa
  }
  $text = (($raw | ForEach-Object { "$_" }) -join "`n").Trim()
  if ($exit -ne 0) {
    return [pscustomobject]@{
      Ok          = $false
      Installed   = $true
      Configured  = $false
      Message     = "Failed to read Cursor state: $text"
      InstallInfo = $info
      Raw         = $text
    }
  }

  $json = $text | ConvertFrom-Json
  return [pscustomobject]@{
    Ok                   = [bool]$json.ok
    Installed            = $true
    Configured           = [bool]$json.configuredForOllama
    OpenAIBaseUrl        = $json.openAIBaseUrl
    UseOpenAIKey         = [bool]$json.useOpenAIKey
    ApiKeyPresent        = [bool]$json.apiKeyPresent
    ModelOverrideEnabled = @($json.modelOverrideEnabled)
    Message              = if ($json.configuredForOllama) { "Cursor wired to local OpenAI-compatible endpoint" } else { "Cursor not yet configured for Ollama" }
    InstallInfo          = $info
    Raw                  = $json
  }
}

function Get-PythonUserScriptsPath {
  try {
    $path = & python -c "import site,sys; print(site.USER_BASE)" 2>$null
    if ($path) {
      return (Join-Path $path.Trim() "Scripts")
    }
  } catch { }
  return $null
}

function Add-PythonUserScriptsToPath {
  $scripts = Get-PythonUserScriptsPath
  if ($scripts -and (Test-Path $scripts) -and ($env:Path -notlike "*$scripts*")) {
    $env:Path = "$scripts;$env:Path"
  }
}

function Get-SystemRamGB {
  try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    return [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
  } catch {
    try {
      $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
      return [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
    } catch {
      return $null
    }
  }
}

function Resolve-CodingModelTier {
  param([string] $Tier = "Auto")
  if ($Tier -and $Tier -ne "Auto") {
    return $Tier
  }
  $gb = Get-SystemRamGB
  if (-not $gb) {
    Write-Warning "Could not detect RAM; defaulting to 16GB tier."
    return "16GB"
  }
  Write-Host "Detected system RAM: ${gb} GB"
  if ($gb -lt 12) { return "8GB" }
  if ($gb -lt 24) { return "16GB" }
  return "32GB"
}

function Get-CodingModelsForTier {
  param([Parameter(Mandatory = $true)][string] $Tier)
  $sets = @{
    "8GB"  = @("qwen2.5-coder:3b", "starcoder2:3b")
    "16GB" = @("qwen2.5-coder:7b", "starcoder2:3b")
    "32GB" = @("qwen2.5-coder:14b", "codellama:13b", "deepseek-coder-v2:16b", "starcoder2:7b")
  }
  if (-not $sets.ContainsKey($Tier)) {
    throw "Unknown tier: $Tier"
  }
  return ,$sets[$Tier]
}

function Get-VirtualMachineInfo {
  <#
  .SYNOPSIS
    Detect whether this OS is running inside a VM and guess the hypervisor.
  #>
  $info = [ordered]@{
    IsVirtualMachine = $false
    Hypervisor       = "None"
    Manufacturer     = ""
    Model            = ""
    HypervisorPresent = $false
    Evidence         = @()
  }

  try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $info.Manufacturer = [string]$cs.Manufacturer
    $info.Model = [string]$cs.Model
    if ($cs.PSObject.Properties.Name -contains "HypervisorPresent") {
      $info.HypervisorPresent = [bool]$cs.HypervisorPresent
    }
  } catch { }

  $blob = ("{0} {1}" -f $info.Manufacturer, $info.Model)
  $evidence = New-Object System.Collections.Generic.List[string]

  # HypervisorPresent is also True on bare metal with Hyper-V / VBS - note only, do not decide alone.
  if ($info.HypervisorPresent) {
    [void]$evidence.Add("Win32_ComputerSystem.HypervisorPresent=True (also common on bare metal with Hyper-V/VBS)")
  }

  $patterns = @(
    @{ Re = "VMware"; Name = "VMware" },
    @{ Re = "VirtualBox|innotek|Oracle.*Virtual"; Name = "VirtualBox" },
    @{ Re = "Hyper-V|Virtual Machine"; Name = "Hyper-V" },
    @{ Re = "QEMU|KVM|KVM Virtual|Standard PC \(Q35|Standard PC \(i440FX"; Name = "QEMU/KVM" },
    @{ Re = "Xen|HVM domU"; Name = "Xen" },
    @{ Re = "Parallels"; Name = "Parallels" },
    @{ Re = "Bochs"; Name = "Bochs" },
    @{ Re = "Amazon EC2|Google Compute|Microsoft Corporation.*Virtual"; Name = "Cloud VM" }
  )
  foreach ($p in $patterns) {
    if ($blob -match $p.Re) {
      $info.IsVirtualMachine = $true
      if ($info.Hypervisor -eq "None") { $info.Hypervisor = $p.Name }
      [void]$evidence.Add("Model/Manufacturer match: $($p.Name)")
    }
  }

  # Virtual display adapters often present even when Model string is ambiguous
  try {
    $adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    foreach ($a in $adapters) {
      $n = [string]$a.Name
      if ($n -match "Hyper-V Video|VMware SVGA|VMware WDDM|VirtualBox Graphics|QXL|Virtio.?GPU") {
        $info.IsVirtualMachine = $true
        [void]$evidence.Add("Virtual display adapter: $n")
        if ($info.Hypervisor -eq "None") {
          if ($n -match "Hyper-V") { $info.Hypervisor = "Hyper-V" }
          elseif ($n -match "VMware") { $info.Hypervisor = "VMware" }
          elseif ($n -match "VirtualBox") { $info.Hypervisor = "VirtualBox" }
          elseif ($n -match "QXL|Virtio") { $info.Hypervisor = "QEMU/KVM" }
        }
      }
    }
  } catch { }

  $info.Evidence = @($evidence.ToArray())
  return [pscustomobject]$info
}

function Get-NvidiaDisplayAdapters {
  $result = @()
  try {
    $adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
  } catch {
    $adapters = @()
  }
  foreach ($a in $adapters) {
    $name = [string]$a.Name
    $pnp = [string]$a.PNPDeviceID
    $isNvidia = ($name -match "NVIDIA|GeForce|Quadro|Tesla|RTX|GTX|GRID") -or ($pnp -match "VEN_10DE")
    if (-not $isNvidia) { continue }
    $devId = $null
    if ($pnp -match "DEV_([0-9A-Fa-f]{4})") {
      $devId = ([string]$Matches[1]).ToUpperInvariant()
    }
    $result += [pscustomobject]@{
      Name           = $name
      DriverVersion  = [string]$a.DriverVersion
      PNPDeviceID    = $pnp
      DeviceId       = $devId
      Status         = [string]$a.Status
    }
  }
  return $result
}

function Get-OllamaGpuEnvironment {
  <#
  .SYNOPSIS
    Summarize whether this machine (including VMs) can use a GPU with Ollama,
    and whether installing NVIDIA drivers in this OS makes sense.
  #>
  $vm = Get-VirtualMachineInfo
  $nvidia = @(Get-NvidiaDisplayAdapters)
  $nvidiaPresent = $nvidia.Count -gt 0

  $virtualOnly = $false
  if ($vm.IsVirtualMachine -and -not $nvidiaPresent) {
    $virtualOnly = $true
  }

  $canUseGpu = $false
  $canInstallDrivers = $false
  $guidance = New-Object System.Collections.Generic.List[string]

  if ($nvidiaPresent) {
    $canUseGpu = $true
    $canInstallDrivers = $true
    if ($vm.IsVirtualMachine) {
      [void]$guidance.Add("VM with an NVIDIA device visible - GPU acceleration is possible (passthrough, GPU-P, GRID/vGPU, or cloud GPU).")
      [void]$guidance.Add("Install NVIDIA drivers inside this guest (GeForce/Studio for consumer passthrough; GRID/vGPU drivers for enterprise/cloud vGPU).")
      [void]$guidance.Add("After install, restart the guest and run .\scripts\Test-GpuSupport.ps1")
    } else {
      [void]$guidance.Add("Bare metal NVIDIA GPU detected - install current Studio/Game Ready drivers (>= 551.61 for Ollama).")
    }
  } elseif ($vm.IsVirtualMachine) {
    [void]$guidance.Add("This OS looks like a VM ($($vm.Hypervisor)) with no NVIDIA device in the guest.")
    [void]$guidance.Add("Installing NVIDIA drivers here will NOT unlock a host GPU - the hypervisor must expose one first.")
    [void]$guidance.Add("Options: PCIe passthrough (Hyper-V DDA / VMware / Proxmox), Hyper-V GPU Partitioning (GPU-P), or a cloud GPU VM.")
    [void]$guidance.Add("Until then, run Ollama on CPU (.\scripts\Setup-Machine.ps1 -Tier 8GB or 16GB).")
  } else {
    [void]$guidance.Add("No NVIDIA GPU detected for the CUDA path. Ollama can still run on CPU.")
    [void]$guidance.Add("AMD: use ROCm/Vulkan per Ollama Windows docs. Intel iGPU is usually not useful for coding models.")
  }

  return [pscustomobject]@{
    IsVirtualMachine   = [bool]$vm.IsVirtualMachine
    Hypervisor         = $vm.Hypervisor
    HypervisorPresent  = [bool]$vm.HypervisorPresent
    VmEvidence         = $vm.Evidence
    Manufacturer       = $vm.Manufacturer
    Model              = $vm.Model
    NvidiaPresent      = $nvidiaPresent
    NvidiaAdapters     = $nvidia
    VirtualDisplayOnly = $virtualOnly
    CanUseGpuWithOllama = $canUseGpu
    CanInstallDrivers  = $canInstallDrivers
    Guidance           = @($guidance)
  }
}

function Get-NvidiaDriverLookupIds {
  <#
  .SYNOPSIS
    Heuristic NVIDIA product-series / product IDs for AjaxDriverService lookup.
  #>
  param([string] $GpuName = "")

  # osID 57 = Windows 10/11 64-bit (DCH). pfid picks a representative chip in-series.
  # Series IDs evolve; lookup fails -> caller should open the download page.
  $psid = 129  # GeForce RTX 40 Series (default modern desktop)
  $pfid = 985  # RTX 4090 stand-in for latest GRD/Studio channel

  if ($GpuName -match "RTX\s*50") { $psid = 139; $pfid = 1025 }
  elseif ($GpuName -match "RTX\s*40") { $psid = 129; $pfid = 985 }
  elseif ($GpuName -match "RTX\s*30") { $psid = 120; $pfid = 929 }
  elseif ($GpuName -match "RTX\s*20|TITAN RTX") { $psid = 101; $pfid = 859 }
  elseif ($GpuName -match "GTX\s*16") { $psid = 101; $pfid = 907 }
  elseif ($GpuName -match "GTX\s*10") { $psid = 101; $pfid = 845 }
  elseif ($GpuName -match "Quadro|RTX A|Tesla|GRID") {
    # Enterprise: still try GeForce channel; caller should prefer NVIDIA enterprise page if this fails
    $psid = 129; $pfid = 985
  }

  return [pscustomobject]@{
    ProductSeriesId = $psid
    ProductId       = $pfid
    OsId            = 57
  }
}

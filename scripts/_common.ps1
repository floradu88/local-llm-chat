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

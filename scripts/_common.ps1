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

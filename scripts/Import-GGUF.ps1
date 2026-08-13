<#
.SYNOPSIS
  Create an Ollama model from a local GGUF file (Modelfile + ollama create).

.PARAMETER GgufPath
  Path to .gguf

.PARAMETER Name
  Local Ollama model name

.PARAMETER Context
  num_ctx (default 8192)

.PARAMETER Temperature
  sampling temperature (default 0.2)

.PARAMETER System
  System prompt

.PARAMETER Template
  Optional Modelfile template path

.PARAMETER KeepModelfile
  Keep generated Modelfile next to the GGUF

.PARAMETER Force
  Re-create even if an Ollama model with this name already exists.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $GgufPath,
  [Parameter(Mandatory = $true)]
  [string] $Name,
  [int] $Context = 8192,
  [double] $Temperature = 0.2,
  [string] $System = "You are a careful coding assistant for the local-llm-chat repo. Prefer correct, minimal changes. For installing or configuring Ollama/local models on this machine, follow AGENTS.md and docs/agent-setup-playbook.md and run scripts/Setup-Machine.ps1. Use only trusted sources in docs/trusted-sources.md. Never commit model weights or tokens.",
  [string] $Template = "",
  [switch] $KeepModelfile,
  [switch] $Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaCommand)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

if (-not (Test-Path $GgufPath)) {
  throw "GGUF not found: $GgufPath"
}

if (-not $Force -and (Test-OllamaModelInstalled -Name $Name)) {
  Write-Host "Skip import (Ollama model already on disk): $Name"
  Write-Host "Re-run with -Force to recreate from GGUF."
  exit 0
}

$GgufPath = (Resolve-Path $GgufPath).Path
# Modelfile prefers forward slashes on Windows
$fromPath = $GgufPath -replace "\\", "/"

if (-not $Template) {
  $Template = Join-Path $RepoRoot "config\Modelfile.coder.template"
}

$body = @"
FROM $fromPath
PARAMETER temperature $Temperature
PARAMETER num_ctx $Context
SYSTEM $System
"@

if (Test-Path $Template) {
  $tpl = Get-Content -Raw $Template
  $body = $tpl.
    Replace("{{FROM}}", $fromPath).
    Replace("{{TEMPERATURE}}", "$Temperature").
    Replace("{{NUM_CTX}}", "$Context").
    Replace("{{SYSTEM}}", $System)
}

$modelfile = Join-Path ([IO.Path]::GetTempPath()) ("Modelfile." + [Guid]::NewGuid().ToString("N"))
Set-Content -Path $modelfile -Value $body -Encoding utf8
Write-Host "Modelfile:`n$body"

Write-Host "Creating Ollama model '$Name'..."
ollama create $Name -f $modelfile
$code = $LASTEXITCODE

if ($KeepModelfile) {
  $keep = Join-Path (Split-Path $GgufPath) "Modelfile.$Name"
  Copy-Item $modelfile $keep -Force
  Write-Host "Kept Modelfile at $keep"
}
Remove-Item $modelfile -Force -ErrorAction SilentlyContinue

if ($code -ne 0) {
  throw "ollama create failed with exit $code"
}

Write-Host "Done. Try: ollama run $Name"
ollama show $Name

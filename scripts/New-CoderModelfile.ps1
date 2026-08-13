<#
.SYNOPSIS
  Generate a coding-tuned Modelfile from a base Ollama model or a GGUF path.

.PARAMETER FromModel
  Existing Ollama tag to FROM (e.g. qwen2.5-coder:7b)

.PARAMETER GgufPath
  Local GGUF path (alternative to FromModel)

.PARAMETER Name
  Suggested model name (commented in output header)

.PARAMETER OutFile
  Where to write the Modelfile

.PARAMETER Context
  num_ctx

.PARAMETER Temperature
  temperature
#>
[CmdletBinding()]
param(
  [string] $FromModel = "",
  [string] $GgufPath = "",
  [string] $Name = "coder",
  [string] $OutFile = "",
  [int] $Context = 8192,
  [double] $Temperature = 0.2,
  [string] $System = "You are a careful coding assistant for the local-llm-chat repo. Prefer correct, minimal changes. For installing or configuring Ollama/local models on this machine, follow AGENTS.md and docs/agent-setup-playbook.md and run scripts/Setup-Machine.ps1. Use only trusted sources in docs/trusted-sources.md. Never commit model weights or tokens."
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

if ($GgufPath) {
  if (-not (Test-Path $GgufPath)) { throw "GGUF not found: $GgufPath" }
  $from = ((Resolve-Path $GgufPath).Path) -replace "\\", "/"
} elseif ($FromModel) {
  $from = $FromModel
} else {
  throw "Specify -FromModel or -GgufPath"
}

if (-not $OutFile) {
  $OutFile = Join-Path $RepoRoot "config\Modelfile.$Name.generated"
}

$templatePath = Join-Path $RepoRoot "config\Modelfile.coder.template"
if (Test-Path $templatePath) {
  $body = (Get-Content -Raw $templatePath).
    Replace("{{FROM}}", $from).
    Replace("{{TEMPERATURE}}", "$Temperature").
    Replace("{{NUM_CTX}}", "$Context").
    Replace("{{SYSTEM}}", $System)
} else {
  $body = @"
FROM $from
PARAMETER temperature $Temperature
PARAMETER num_ctx $Context
SYSTEM $System
"@
}

$header = "# Generated for ollama create $Name`n"
Set-Content -Path $OutFile -Value ($header + $body) -Encoding utf8
Write-Host "Wrote $OutFile"
Write-Host "Create with: ollama create $Name -f `"$OutFile`""

<#
.SYNOPSIS
  Run sample coding prompts against a local Ollama model (API, non-interactive).

.PARAMETER Model
  Ollama tag. Default: first coding-like model, else first listed model.

.PARAMETER PromptsFile
  Markdown/text file; non-empty lines that look like numbered prompts are used.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [string] $PromptsFile = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaApi)) {
  throw "Ollama API not reachable. Start Ollama first."
}

if (-not $PromptsFile) {
  $PromptsFile = Join-Path $RepoRoot "config\sample-prompts.md"
}
if (-not (Test-Path $PromptsFile)) {
  throw "Prompts file not found: $PromptsFile"
}

$tags = Invoke-RestMethod http://127.0.0.1:11434/api/tags
$names = @($tags.models | ForEach-Object { $_.name })
if ($names.Count -eq 0) {
  throw "No models installed. Run Pull-CodingModels.ps1 first."
}

if (-not $Model) {
  $coding = $names | Where-Object { $_ -match "coder|starcoder|codellama|deepseek" } | Select-Object -First 1
  $Model = if ($coding) { $coding } else { $names[0] }
}

$prompts = Get-Content $PromptsFile |
  Where-Object { $_ -match '^\d+\.\s+' } |
  ForEach-Object { $_ -replace '^\d+\.\s+', '' }

if ($prompts.Count -eq 0) {
  throw "No numbered prompts found in $PromptsFile"
}

Write-Host "=== Eval-CodingModel ==="
Write-Host "Model: $Model"
Write-Host "Prompts: $($prompts.Count)"
Write-Host ""

$i = 0
foreach ($p in $prompts) {
  $i++
  Write-Host "----- [$i/$($prompts.Count)] $p"
  $body = @{
    model   = $Model
    prompt  = $p
    stream  = $false
    options = @{ num_predict = 256; temperature = 0.2 }
  } | ConvertTo-Json -Compress
  try {
    $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -Body $body -ContentType "application/json" -TimeoutSec 300
    $text = ($resp.response -replace "\s+$", "")
    if ($text.Length -gt 500) { $text = $text.Substring(0, 500) + "`n..." }
    Write-Host $text
  } catch {
    Write-Warning "Prompt $i failed: $_"
  }
  Write-Host ""
}

Write-Host "Done. Adjust prompts in config\sample-prompts.md"

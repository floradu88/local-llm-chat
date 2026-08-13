<#
.SYNOPSIS
  Pull a model from the Ollama Library, or from Hugging Face via hf.co bridge.

.PARAMETER Model
  Ollama library tag, e.g. qwen2.5-coder:7b

.PARAMETER HuggingFaceRepo
  Hub repo like org/name — pulls via ollama as hf.co/org/name[:Quant]

.PARAMETER Quant
  Optional quant suffix for HF bridge (e.g. Q4_K_M)
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [string] $HuggingFaceRepo = "",
  [string] $Quant = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

if ($HuggingFaceRepo) {
  $tag = "hf.co/$HuggingFaceRepo"
  if ($Quant) { $tag = "$tag`:$Quant" }
  Write-Host "Pulling $tag ..."
  ollama pull $tag
  exit $LASTEXITCODE
}

if (-not $Model) {
  throw "Specify -Model <tag> or -HuggingFaceRepo <org/repo>."
}

Write-Host "Pulling $Model ..."
ollama pull $Model
exit $LASTEXITCODE

<#
.SYNOPSIS
  Pull a model from the Ollama Library, or from Hugging Face via hf.co bridge.

.PARAMETER Model
  Ollama library tag, e.g. qwen2.5-coder:7b

.PARAMETER HuggingFaceRepo
  Hub repo like org/name — pulls via ollama as hf.co/org/name[:Quant]

.PARAMETER Quant
  Optional quant suffix for HF bridge (e.g. Q4_K_M)

.PARAMETER Force
  Re-pull even if the model is already installed locally.
#>
[CmdletBinding()]
param(
  [string] $Model = "",
  [string] $HuggingFaceRepo = "",
  [string] $Quant = "",
  [switch] $Force
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaCommand)) {
  throw "ollama not found on PATH. Run .\scripts\Install-Ollama.ps1 first."
}

function Invoke-OllamaPull([string] $Tag) {
  if (-not $Force -and (Test-OllamaModelInstalled -Name $Tag)) {
    Write-Host "Skip pull (already on disk): $Tag"
    return 0
  }
  Write-Host "Pulling $Tag ..."
  ollama pull $Tag
  return $LASTEXITCODE
}

if ($HuggingFaceRepo) {
  $tag = "hf.co/$HuggingFaceRepo"
  if ($Quant) { $tag = "$tag`:$Quant" }
  exit (Invoke-OllamaPull $tag)
}

if (-not $Model) {
  throw "Specify -Model <tag> or -HuggingFaceRepo <org/repo>."
}

exit (Invoke-OllamaPull $Model)

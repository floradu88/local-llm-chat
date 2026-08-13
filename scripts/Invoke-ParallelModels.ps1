<#
.SYNOPSIS
  Send the same prompt to multiple Ollama models in parallel and print results.

.PARAMETER Prompt
  User prompt text.

.PARAMETER Models
  Ollama tags. Default: the three repo example models.

.PARAMETER MaxParallel
  Max concurrent jobs (default 3). Lower on CPU-only machines.

.PARAMETER NumPredict
  Max tokens to generate per model.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $Prompt,
  [string[]] $Models = @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b"),
  [int] $MaxParallel = 3,
  [int] $NumPredict = 256,
  [double] $Temperature = 0.2
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaApi)) {
  throw "Ollama API not reachable at http://127.0.0.1:11434"
}

if ($MaxParallel -lt 1) { $MaxParallel = 1 }
Write-Host "=== Invoke-ParallelModels ==="
Write-Host "Models: $($Models -join ', ')"
Write-Host "MaxParallel: $MaxParallel"
Write-Host "Prompt: $Prompt"
Write-Host ""

$queue = [System.Collections.Generic.Queue[string]]::new()
foreach ($m in $Models) { $queue.Enqueue($m) }

$running = @()
$results = @()

function Start-ModelJob([string] $model) {
  return Start-Job -ScriptBlock {
    param($model, $prompt, $numPredict, $temperature)
    $started = Get-Date
    try {
      $body = @{
        model   = $model
        prompt  = $prompt
        stream  = $false
        options = @{ num_predict = $numPredict; temperature = $temperature }
      } | ConvertTo-Json -Compress
      $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" `
        -ContentType "application/json" -Body $body -TimeoutSec 900
      [pscustomobject]@{
        Model    = $model
        Ok       = $true
        Response = $resp.response
        Seconds  = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        Error    = $null
      }
    } catch {
      [pscustomobject]@{
        Model    = $model
        Ok       = $false
        Response = $null
        Seconds  = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        Error    = "$_"
      }
    }
  } -ArgumentList $model, $Prompt, $NumPredict, $Temperature
}

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($running.Count -lt $MaxParallel -and $queue.Count -gt 0) {
    $next = $queue.Dequeue()
    Write-Host "Starting: $next"
    $running += Start-ModelJob $next
  }

  $finished = @($running | Where-Object { $_.State -ne "Running" })
  foreach ($j in $finished) {
    $r = Receive-Job $j -ErrorAction SilentlyContinue
    if ($r) { $results += $r }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
  }
  $running = @($running | Where-Object { $_.State -eq "Running" })
  if ($running.Count -gt 0 -and $finished.Count -eq 0) {
    Start-Sleep -Milliseconds 400
  }
}

foreach ($r in $results) {
  Write-Host ""
  Write-Host "===== $($r.Model) ($($r.Seconds)s) ====="
  if ($r.Ok) {
    Write-Host $r.Response
  } else {
    Write-Warning $r.Error
  }
}

Write-Host ""
Write-Host "Done. See docs\multi-model-workflows.md"

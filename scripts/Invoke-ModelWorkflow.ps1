<#
.SYNOPSIS
  Run a simple multi-model workflow against local Ollama.

.PARAMETER Workflow
  DraftReview | PlanImplement | CompareJudge

.PARAMETER Task
  User task / question.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("DraftReview", "PlanImplement", "CompareJudge")]
  [string] $Workflow,
  [Parameter(Mandatory = $true)]
  [string] $Task,
  [string] $DraftModel = "qwen2.5-coder:7b",
  [string] $ReviewModel = "codellama:13b",
  [string] $PlanModel = "deepseek-coder-v2:16b",
  [string] $ImplementModel = "qwen2.5-coder:7b",
  [string] $JudgeModel = "qwen2.5-coder:7b",
  [string[]] $Models = @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b"),
  [int] $NumPredict = 400,
  [int] $MaxParallel = 3
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

if (-not (Test-OllamaApi)) {
  throw "Ollama API not reachable at http://127.0.0.1:11434"
}

function Invoke-OllamaGenerate([string] $Model, [string] $Prompt, [int] $Predict = 400) {
  $body = @{
    model   = $Model
    prompt  = $Prompt
    stream  = $false
    options = @{ num_predict = $Predict; temperature = 0.2 }
  } | ConvertTo-Json -Compress
  $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" `
    -ContentType "application/json" -Body $body -TimeoutSec 900
  return $resp.response
}

Write-Host "=== Invoke-ModelWorkflow: $Workflow ==="
Write-Host "Task: $Task"
Write-Host ""

switch ($Workflow) {
  "DraftReview" {
    Write-Host "[1/2] Draft with $DraftModel ..."
    $draft = Invoke-OllamaGenerate -Model $DraftModel -Prompt @"
You are a coding assistant. Solve the task with minimal correct code.
Task: $Task
"@ -Predict $NumPredict
    Write-Host $draft
    Write-Host ""
    Write-Host "[2/2] Review with $ReviewModel ..."
    $review = Invoke-OllamaGenerate -Model $ReviewModel -Prompt @"
You are a strict code reviewer. Improve correctness and clarity. Return the improved solution.
Task: $Task
Draft:
$draft
"@ -Predict $NumPredict
    Write-Host $review
  }

  "PlanImplement" {
    Write-Host "[1/2] Plan with $PlanModel ..."
    $plan = Invoke-OllamaGenerate -Model $PlanModel -Prompt @"
Create a short step-by-step implementation plan (no full code yet).
Task: $Task
"@ -Predict ([math]::Min(300, $NumPredict))
    Write-Host $plan
    Write-Host ""
    Write-Host "[2/2] Implement with $ImplementModel ..."
    $code = Invoke-OllamaGenerate -Model $ImplementModel -Prompt @"
Implement the task using this plan. Return code and brief notes.
Task: $Task
Plan:
$plan
"@ -Predict $NumPredict
    Write-Host $code
  }

  "CompareJudge" {
    Write-Host "[1/2] Parallel generate across: $($Models -join ', ')"
    $tmpPrompt = "Answer clearly and correctly.`nTask: $Task"
    $parallelScript = Join-Path $PSScriptRoot "Invoke-ParallelModels.ps1"
    # Capture by re-implementing a compact parallel gather for judge input
    $jobs = @()
    foreach ($m in $Models) {
      $jobs += Start-Job -ScriptBlock {
        param($model, $prompt, $predict)
        $body = @{
          model = $model; prompt = $prompt; stream = $false
          options = @{ num_predict = $predict; temperature = 0.2 }
        } | ConvertTo-Json -Compress
        try {
          $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" `
            -ContentType "application/json" -Body $body -TimeoutSec 900
          "MODEL: $model`n$($resp.response)"
        } catch {
          "MODEL: $model`nERROR: $_"
        }
      } -ArgumentList $m, $tmpPrompt, ([math]::Min(220, $NumPredict))
    }
    $jobs | Wait-Job | Out-Null
    $bundle = ($jobs | ForEach-Object { Receive-Job $_; "---`n" }) -join "`n"
    $jobs | Remove-Job -Force
    Write-Host $bundle
    Write-Host ""
    Write-Host "[2/2] Judge with $JudgeModel ..."
    $verdict = Invoke-OllamaGenerate -Model $JudgeModel -Prompt @"
You are a judge. Compare the candidate answers. Pick the best one for the task and explain briefly why. Then print the winning answer.
Task: $Task
Candidates:
$bundle
"@ -Predict $NumPredict
    Write-Host $verdict
  }
}

Write-Host ""
Write-Host "Done. See docs\multi-model-workflows.md"

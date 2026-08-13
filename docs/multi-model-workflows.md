# Multiple models: parallel use and workflows

Ollama serves **one API** (`http://127.0.0.1:11434`) and can host **several model tags**. You choose the model per request. This machine is often **CPU-only** — keep concurrency low and prefer small models when running in parallel.

Primary example tags from this repo:

- `qwen2.5-coder:7b`
- `deepseek-coder-v2:16b`
- `codellama:13b`

## Concepts

| Mode | What happens | When to use |
|------|----------------|-------------|
| **Switch** | One model at a time in the editor; change the selected tag | Everyday chat / Continue / Cursor |
| **Parallel** | Several HTTP requests at once to different (or same) models | Compare answers, fan-out brainstorming |
| **Workflow (sequential)** | Model A output becomes Model B input | Draft → review, summarize → implement |
| **Roles** | Small/fast vs large/slow tags for different jobs | Autocomplete vs deep refactor |

Ollama may keep multiple models in memory if RAM allows (`OLLAMA_MAX_LOADED_MODELS`, `keep_alive`). If RAM is tight, the second load will evict the first — parallel still works, but slower (reload cost).

```powershell
# Optional (User env, then restart Ollama tray)
[Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "2", "User")
```

Check what is loaded:

```powershell
ollama ps
```

---

## 1) Switch models in the editor (simplest)

### Continue (VS Code)

`config/continue.config.example.json` already lists the three example models. After `Install-ContinueConfig.ps1`, pick the active model in the Continue UI.

- Chat / agent: `qwen2.5-coder:7b` or `deepseek-coder-v2:16b` or `codellama:13b`
- Tab autocomplete: keep a **small** tag (e.g. `qwen2.5-coder:3b`) so it stays fast while chat uses a larger model

### Cursor

Add each tag as a selectable model (same base URL `http://localhost:11434/v1`, key `ollama`). Switch model in the chat model picker — only one generates at a time unless you open multiple chats/agents.

---

## 2) Parallel requests (PowerShell)

Same prompt to all three example models at once:

```powershell
cd D:\code\projects\local-llm-chat
.\scripts\Invoke-ParallelModels.ps1 `
  -Prompt "Write a PowerShell function that reverses a string. Code only." `
  -Models @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b")
```

Or two lighter models on a small machine:

```powershell
.\scripts\Invoke-ParallelModels.ps1 `
  -Prompt "Explain async/await in one paragraph." `
  -Models @("qwen2.5-coder:3b", "starcoder2:3b") `
  -MaxParallel 2
```

What it does: starts background jobs, each POSTs to `/api/generate` with a different `model`, then prints labeled results.

Manual pattern (copy-paste):

```powershell
$prompt = "List 3 edge cases for a login API."
$models = @("qwen2.5-coder:7b", "codellama:13b")
$jobs = foreach ($m in $models) {
  Start-Job -ScriptBlock {
    param($model, $prompt)
    $body = @{ model = $model; prompt = $prompt; stream = $false; options = @{ num_predict = 200; temperature = 0.2 } } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json" -Body $body -TimeoutSec 600
  } -ArgumentList $m, $prompt
}
$jobs | Wait-Job | Out-Null
foreach ($j in $jobs) {
  $r = Receive-Job $j
  Write-Host "===== $($r.model) ====="
  Write-Host $r.response
}
$jobs | Remove-Job
```

---

## 3) Workflows (sequential pipelines)

### Workflow A — Draft then review

1. Fast/small model drafts code  
2. Stronger model reviews / hardens it  

```powershell
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow DraftReview `
  -Task "PowerShell: read a CSV and print the unique values of column Name" `
  -DraftModel "qwen2.5-coder:7b" `
  -ReviewModel "codellama:13b"
```

### Workflow B — Plan then implement

1. Model plans steps  
2. Another model writes the code from that plan  

```powershell
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow PlanImplement `
  -Task "Add retry with exponential backoff to an Invoke-RestMethod call" `
  -PlanModel "deepseek-coder-v2:16b" `
  -ImplementModel "qwen2.5-coder:7b"
```

### Workflow C — Compare then pick (parallel + merge)

1. Parallel fan-out (section 2)  
2. Feed all answers into one “judge” model  

```powershell
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow CompareJudge `
  -Task "Best way to parse JSON in PowerShell 5.1?" `
  -Models @("qwen2.5-coder:7b", "codellama:13b", "deepseek-coder-v2:16b") `
  -JudgeModel "qwen2.5-coder:7b"
```

### Workflow D — Editor + Codegraph (tooling, not two LLMs)

1. Codegraph answers structural questions (symbols, callers)  
2. Local coder model edits using that context  

Keep `codegraph` MCP enabled; ask the agent to use Codegraph tools first, then generate with your selected Ollama model.

### Workflow E — Headroom + model

Headroom compresses context; it does **not** replace a second model. Pattern:

1. `.\scripts\Start-HeadroomOllama.ps1`  
2. Cursor/Continue → `http://127.0.0.1:8787/v1`  
3. Still pick **one** generation model per request; switch tags as needed  

---

## 4) Role split (recommended default)

| Role | Suggested tag | Notes |
|------|----------------|-------|
| Autocomplete | `qwen2.5-coder:3b` or `starcoder2:3b` | Low latency |
| Daily chat / edits | `qwen2.5-coder:7b` | Balanced |
| Heavy review / hard bugs | `deepseek-coder-v2:16b` or `codellama:13b` | More RAM; run alone if needed |

On CPU-only / low VRAM machines: avoid loading two large 13B+ models at once; use **sequential** workflows instead of parallel for those tags.

---

## 5) OpenAI-compatible parallel clients

Any client that can set `model` per request works:

```powershell
# Chat Completions shape (Ollama)
$body = @{
  model = "qwen2.5-coder:7b"
  messages = @(@{ role = "user"; content = "Say hi" })
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/v1/chat/completions" `
  -ContentType "application/json" -Body $body -Headers @{ Authorization = "Bearer ollama" }
```

Run several of these in `Start-Job` / `ForEach-Object -Parallel` (PowerShell 7+) with different `model` values.

---

## RAM / GPU reminders

- GPU / VM check: `.\scripts\Test-GpuSupport.ps1`
- Optional drivers: `.\scripts\Install-GpuDrivers.ps1` (VM needs host passthrough first)
- If verdict is CPU-only, prefer **sequential** workflows and **MaxParallel 1–2**
- Unload: `ollama stop <tag>`
- Model pulls skip tags already on disk; refresh with `Update-CodingModels.ps1` or `-Force`

## Related

- Example pulls: README (three models)
- Continue multi-model config: `config/continue.config.example.json`
- Cursor install + Models checklist: `Install-Cursor.ps1`, `config/cursor-openai-local.example.md`
- Scripts: `Invoke-ParallelModels.ps1`, `Invoke-ModelWorkflow.ps1`
- Features: [FEATURES.md](../FEATURES.md)
- Code map/understand prompts: [code-understanding-prompts.md](code-understanding-prompts.md)

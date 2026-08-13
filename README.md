# Local LLM Chat (Ollama)

Run coding LLMs **on your machine** with [Ollama](https://ollama.com), then use them from **VS Code**, **Cursor**, **Codegraph**, and **Headroom** — without admin rights when possible.

Model weights are **not** in git. After clone you install Ollama and download models onto this machine.

## First time after `git clone`

Open **PowerShell** in the repo root (the folder that contains `README.md` and `scripts\`).

```powershell
cd D:\code\projects\local-llm-chat   # your clone path
Get-ChildItem scripts\*.ps1          # sanity check
```

If scripts are blocked by execution policy (current user only, no admin):

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Pick **one** common case below.

---

### Case A — Fresh machine (most common)

No Ollama yet. ~16 GB RAM. Want coding models + later IDE wiring.

```powershell
.\scripts\Setup-Machine.ps1 -Tier Auto
# or: -Tier 16GB
```

That sets `OLLAMA_MODELS` to `.\models\ollama`, installs Ollama (per-user, no admin), pulls models for your RAM tier (or the tier you pass), and prints editor next steps.

**Other RAM tiers:**

```powershell
.\scripts\Setup-Machine.ps1 -Tier 8GB    # light laptop
.\scripts\Setup-Machine.ps1 -Tier 16GB
.\scripts\Setup-Machine.ps1 -Tier 32GB   # more headroom / larger models
.\scripts\Show-SetupStatus.ps1           # green/red checklist
```

---

### Case B — Ollama already installed

Keep your existing Ollama; only set this repo’s model folder and pull coding models.

```powershell
.\scripts\Set-OllamaEnv.ps1 -Persistent
.\scripts\Setup-Machine.ps1 -Tier 16GB -SkipInstall
```

Or pull only:

```powershell
.\scripts\Set-OllamaEnv.ps1 -Persistent
.\scripts\Pull-CodingModels.ps1 -Tier 16GB
```

---

### Case C — Step by step (no one-shot script)

```powershell
.\scripts\Set-OllamaEnv.ps1 -Persistent
.\scripts\Install-Ollama.ps1
.\scripts\Pull-CodingModels.ps1 -Tier 16GB
ollama list
Invoke-RestMethod http://localhost:11434/api/tags
```

---

### Case D — Models on another drive (disk full on C:)

```powershell
.\scripts\Set-OllamaEnv.ps1 -ModelsRoot "E:\ollama-models" -Persistent
.\scripts\Setup-Machine.ps1 -Tier 16GB -ModelsRoot "E:\ollama-models"
```

Quit and relaunch the Ollama tray app after changing `OLLAMA_MODELS`.

---

### Case E — Only one small model (slow network / little disk)

```powershell
.\scripts\Set-OllamaEnv.ps1 -Persistent
.\scripts\Install-Ollama.ps1
.\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:3b
ollama run qwen2.5-coder:3b "Say ready"
```

---

### Case F — Import a GGUF from Hugging Face

After Ollama is installed (Case A/B/C first):

```powershell
.\scripts\Download-FromHuggingFace.ps1 `
  -Repo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" `
  -Include "*Q4_K_M.gguf"

# Use the real path printed by the download script:
.\scripts\Import-GGUF.ps1 `
  -GgufPath ".\models\gguf\bartowski\Qwen2.5-Coder-7B-Instruct-GGUF\<file>.Q4_K_M.gguf" `
  -Name "qwen25-coder-local"

ollama run qwen25-coder-local
```

Gated Hub models: set `$env:HF_TOKEN = "hf_..."` (or `-Token`) after accepting the license on Hugging Face. More sources: [docs/install-models-from-web.md](docs/install-models-from-web.md), [docs/trusted-sources.md](docs/trusted-sources.md).

---

### Case G — Hugging Face via Ollama (`hf.co` bridge)

```powershell
.\scripts\Download-FromOllama.ps1 `
  -HuggingFaceRepo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" `
  -Quant Q4_K_M
```

---

### Case H — Wire VS Code (Continue) after models work

```powershell
# models must already show in: ollama list
.\scripts\Install-ContinueConfig.ps1
```

Install the **Continue** extension in VS Code, reload, pick an Ollama model from the config. Details: [docs/integrations.md](docs/integrations.md).

---

### Case I — Wire Cursor after models work

1. Cursor **Settings → Models**
2. Base URL: `http://localhost:11434/v1`
3. API key: `ollama`
4. Model name: exact tag from `ollama list` (e.g. `qwen2.5-coder:7b`)

Checklist: [config/cursor-openai-local.example.md](config/cursor-openai-local.example.md).

---

### Case J — Headroom in front of Ollama (optional)

```powershell
.\scripts\Start-HeadroomOllama.ps1
```

Then point Cursor/clients at `http://127.0.0.1:8787/v1` (key still `ollama`). Leave this terminal open while using Headroom.

---

### Case K — Codegraph on this (or another) project

```powershell
codegraph init
```

Structural MCP tools use the local graph. Pull embeddings only if your Codegraph build needs them:

```powershell
.\scripts\Download-FromOllama.ps1 -Model nomic-embed-text
```

---

### Case L — Verify everything

```powershell
.\scripts\Test-LocalSetup.ps1
# optional: .\scripts\Test-LocalSetup.ps1 -Model qwen2.5-coder:7b
```

| Symptom | Fix |
|---------|-----|
| `ollama` not found | New PowerShell window; or add `%LOCALAPPDATA%\Programs\Ollama` to user PATH |
| API connection refused | Start Ollama from Start menu / system tray |
| Script won’t run | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Pull too large / OOM | Re-run with `-Tier 8GB` or Case E |
| Execution / SmartScreen blocks installer | Allow `OllamaSetup.exe` or ask IT to whitelist |

---

### Case M — ModelScope / GitHub Releases direct URL

```powershell
.\scripts\Download-FromUrl.ps1 -Url "https://.../model.Q4_K_M.gguf" -OutDir ".\models\gguf\external"
.\scripts\Import-GGUF.ps1 -GgufPath ".\models\gguf\external\model.Q4_K_M.gguf" -Name "external-coder"
```

---

### Suggested order for a brand-new clone

1. **Case A** (or B if Ollama exists) — includes verify via `Test-LocalSetup`  
2. **Case L** again if anything looked wrong  
3. **Case H** and/or **Case I** (editor)  
4. Optional: **Case J** (Headroom), **Case K** (Codegraph), **Case F/G/M** (extra models)

Agents/LLMs in this repo: read [AGENTS.md](AGENTS.md), [FEATURES.md](FEATURES.md), and [docs/agent-setup-playbook.md](docs/agent-setup-playbook.md). Cursor always loads [`.cursor/rules/local-llm-setup.mdc`](.cursor/rules/local-llm-setup.mdc).

**Note:** [LM Studio](https://lmstudio.ai) is an alternative desktop UI; this repo standardizes on **Ollama** as the primary runtime.

## Architecture

```text
VS Code / Cursor ──► (optional) Headroom :8787 ──► Ollama :11434 ──► local models
Codegraph MCP ─────────────────────────────────────► project .codegraph/ (+ optional Ollama)
```

## Prerequisites

- Windows 10 **22H2+** (or Windows 11)
- Enough disk for models (often 4–40+ GB each)
- Optional GPU: NVIDIA (driver ≥ 551.61) or AMD (ROCm/Vulkan) — see [Ollama Windows docs](https://docs.ollama.com/windows)
- PowerShell 5.1+ (Windows built-in is fine)

## Best local coding models

| Model | Why use it |
|-------|------------|
| **Qwen2.5-Coder** | Strong code reasoning; many sizes (3B–32B) |
| **DeepSeek-Coder-V2** | Broad language coverage; large context options |
| **CodeLlama** | Meta’s widely supported code family |
| **StarCoder2** | Fast, lighter everyday coding help |

| System RAM (approx) | Suggested Ollama pulls |
|---------------------|------------------------|
| 8–12 GB | `qwen2.5-coder:3b`, `starcoder2:3b` |
| 16 GB | `qwen2.5-coder:7b`, `starcoder2:3b` |
| 32 GB+ | `qwen2.5-coder:14b`, `codellama:13b`, `deepseek-coder-v2:16b`, `starcoder2:7b` |

## Repo layout

```text
AGENTS.md       instructions for local agents / LLMs
docs/           setup playbook, trusted sources, imports, integrations
scripts/        PowerShell install / download / import / Headroom / Setup-Machine
config/         Modelfile + Continue / Cursor examples
models/gguf/    downloaded .gguf files (gitignored)
models/ollama/  optional OLLAMA_MODELS root (gitignored)
```

## Docs

| Doc | Contents |
|-----|----------|
| [FEATURES.md](FEATURES.md) | Feature checklist + machine checks + nice-to-haves |
| [AGENTS.md](AGENTS.md) | Instructions for local agents / LLMs |
| [docs/agent-setup-playbook.md](docs/agent-setup-playbook.md) | Machine bootstrap checklist |
| [docs/powershell-ollama-setup.md](docs/powershell-ollama-setup.md) | Install Ollama, env vars, verify API |
| [docs/trusted-sources.md](docs/trusted-sources.md) | Which hosts/orgs to trust |
| [docs/install-models-from-web.md](docs/install-models-from-web.md) | Ollama Library, Hugging Face, ModelScope, Modelfile |
| [docs/integrations.md](docs/integrations.md) | Continue, Cursor, Codegraph, Headroom |

## Scripts

| Script | Role |
|--------|------|
| `scripts/Setup-Machine.ps1` | **One-shot** after clone: env + install + pull + verify (`-Tier Auto`) |
| `scripts/Show-SetupStatus.ps1` | Green/red dashboard for Cases A–M |
| `scripts/Test-LocalSetup.ps1` | Verify PATH, API, models (Case L) |
| `scripts/Update-CodingModels.ps1` | Re-pull / refresh tier models |
| `scripts/Uninstall-Ollama.ps1` | Uninstall guidance + optional model cleanup |
| `scripts/Eval-CodingModel.ps1` | Run sample coding prompts against a local model |
| `scripts/Set-OllamaEnv.ps1` | Set `OLLAMA_MODELS` / install dir |
| `scripts/Install-Ollama.ps1` | Official per-user install |
| `scripts/Install-ContinueConfig.ps1` | Copy Continue config for VS Code (Case H) |
| `scripts/Download-FromOllama.ps1` | `ollama pull` (+ optional `hf.co` bridge) |
| `scripts/Download-FromHuggingFace.ps1` | Download GGUF to `models/gguf` |
| `scripts/Download-FromUrl.ps1` | Direct URL (ModelScope / GitHub Releases) |
| `scripts/Import-GGUF.ps1` | Register local GGUF with `ollama create` |
| `scripts/New-CoderModelfile.ps1` | Generate a coding-tuned Modelfile |
| `scripts/Pull-CodingModels.ps1` | Opinionated pulls by RAM tier / Auto |
| `scripts/Start-HeadroomOllama.ps1` | Headroom proxy → Ollama `/v1` |
| `scripts/_common.ps1` | Shared helpers (dot-sourced; not run alone) |

## License note

Respect each model’s license (Qwen, DeepSeek, Meta Llama/CodeLlama, BigCode StarCoder2, etc.) before redistributing weights.

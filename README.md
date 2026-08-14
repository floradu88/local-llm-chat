# Local LLM Chat (Ollama)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Run coding LLMs **on your machine** with [Ollama](https://ollama.com), then use them from **VS Code**, **Cursor**, **Codegraph**, and **Headroom** — without admin rights when possible.

Model weights are **not** in git. After clone you install Ollama and download models onto this machine.

**Author:** [Radu Florescu](https://github.com/floradu88) · **Repo:** [floradu88/local-llm-chat](https://github.com/floradu88/local-llm-chat) · **License:** [MIT](LICENSE) (use as-is; keep the copyright notice for credit)


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

### Copy-paste: three example coding models (from this project)

These are the three primary coding models used as examples in this repo (Ollama Library tags):

| # | Model | Example tag | Good for |
|---|--------|-------------|----------|
| 1 | **Qwen2.5-Coder** | `qwen2.5-coder:7b` | Default coding assistant |
| 2 | **DeepSeek-Coder-V2** | `deepseek-coder-v2:16b` | Strong multi-language / larger context (needs more RAM) |
| 3 | **CodeLlama** | `codellama:13b` | Meta code family, widely supported |

```powershell
# Requires Ollama installed and running (Case A/B/C first)
# Scripts skip tags already on disk (-Force to re-pull)
.\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:7b
.\scripts\Download-FromOllama.ps1 -Model deepseek-coder-v2:16b
.\scripts\Download-FromOllama.ps1 -Model codellama:13b

ollama list
ollama run qwen2.5-coder:7b "Say ready"
```

On low RAM / CPU-only machines, prefer smaller tags first (`qwen2.5-coder:3b`, `starcoder2:3b`) or `.\scripts\Pull-CodingModels.ps1 -Tier 8GB`.

---

### Case A — Fresh machine (most common)

No Ollama yet. Want coding models + later IDE wiring.

**Full scenario** (install tools, download models, index code, verify):

```powershell
.\scripts\Setup-FullLocalStack.ps1 -Tier Auto -PullExampleModels
# Index another app instead of this repo:
# .\scripts\Setup-FullLocalStack.ps1 -Tier Auto -PullExampleModels -ProjectPath "D:\path\to\your-app"
```

**Ollama-only one shot:**

```powershell
.\scripts\Setup-Machine.ps1 -Tier Auto
# or: -Tier 16GB
```

That sets `OLLAMA_MODELS` to `.\models\ollama`, installs Ollama (per-user, no admin), checks/installs **Cursor** if missing, pulls models for your RAM tier **skipping tags already on disk**, wires **Cursor Models → Ollama** and **VS Code Local AI (Continue + Cline)** when possible, then verifies.

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

### Case B2 — Air-gap / offline re-wire (no downloads)

When Ollama and models already exist and you must not download installers or pulls:

```powershell
.\scripts\Setup-Machine.ps1 -AirGap
# or full stack without npm/Codegraph download:
.\scripts\Setup-FullLocalStack.ps1 -AirGap
```

Still points editors at local Ollama and runs `Disable-RemoteAIProviders`. Marketplace extension installs may need network if Continue/Cline are missing.

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

### Case H — Wire VS Code Local AI (Continue + Cline) after models work

Gives you **ChatGPT-like chat + autocomplete** (Continue) and a **Cursor-like agent** (Cline) on local Ollama.

```powershell
.\scripts\Install-VSCode.ps1                 # per-user install if Code missing
.\scripts\Install-VSCodeLocalAI.ps1          # Continue + Cline + Test-VSCodeSetup
.\scripts\Install-VSCodeLocalAI.ps1 -CheckOnly
.\scripts\Test-VSCodeSetup.ps1               # full config check anytime
# alias: .\scripts\Test-VSCodeOllama.ps1
# pieces:
# .\scripts\Install-ContinueConfig.ps1 -Force   # chat only
# .\scripts\Install-ClineConfig.ps1 -Force      # agent only
# .\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force
```

Reload VS Code: use **Continue** for sidebar chat / tab complete; use **Cline** for multi-file agent tasks. Checklist: [config/vscode-ollama-local.example.md](config/vscode-ollama-local.example.md). Details: [docs/integrations.md](docs/integrations.md).

**Disable remote/cloud providers** (OpenAI, Cursor catalog, Grok, Copilot, …):

```powershell
# Quit Cursor first, then:
.\scripts\Disable-RemoteAIProviders.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
```

See [config/local-only-ai.example.md](config/local-only-ai.example.md).

---

### Case I — Wire Cursor after models work

**Install / check Cursor (per-user, no admin):**

```powershell
.\scripts\Install-Cursor.ps1            # skip if already installed
.\scripts\Install-Cursor.ps1 -CheckOnly # status only (exit 1 if missing)
```

**Configure Models → local Ollama from PowerShell** (finds install + `%APPDATA%\Cursor`, writes `state.vscdb`):

```powershell
# Quit Cursor first, then:
.\scripts\Install-CursorConfig.ps1
.\scripts\Install-CursorConfig.ps1 -CheckOnly
.\scripts\Test-CursorOllama.ps1          # config + /v1/chat/completions smoke
# .\scripts\Install-CursorConfig.ps1 -Headroom   # after Install-Headroom + Start-HeadroomOllama
```

That sets base URL `http://localhost:11434/v1`, API key `ollama`, enables tags from `ollama list`, and **disables Cursor cloud/catalog models** (use `-KeepRemoteModels` to leave them on). Restart Cursor afterward.

Manual UI fallback: Settings → Models with the same URL/key. Checklist: [config/cursor-openai-local.example.md](config/cursor-openai-local.example.md).

---

### Case J — Headroom in front of Ollama (optional)

Uses a **short-path venv** at `C:\hr` (no admin). Avoid `pip install --user` with Microsoft Store Python — `litellm` hits Windows path-length limits unless Long Paths are enabled (admin).

```powershell
.\scripts\Install-Headroom.ps1          # once: creates C:\hr + installs headroom-ai[proxy]
.\scripts\Start-HeadroomOllama.ps1      # auto-installs into C:\hr if missing
```

Then point Cursor/clients at Headroom:

```powershell
.\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force
# and/or:
.\scripts\Install-CursorConfig.ps1 -Headroom
```

Or set base URL `http://127.0.0.1:8787/v1` (key still `ollama`) in the UI. Leave the Headroom terminal open while using it.

If install still fails with long-path errors, either keep using `C:\hr`, or (with admin) enable Long Paths: https://pip.pypa.io/warnings/enable-long-paths

---

### Case K — Codegraph on this (or another) project

Install Node via **fnm** (preferred, no admin; system npm only if fnm fails), install Codegraph CLI, wire agents, **update Cursor + VS Code MCP JSON**, then `codegraph init` if `.codegraph` is missing:

```powershell
# This toolkit repo:
.\scripts\Install-Codegraph.ps1

# Or your app:
.\scripts\Install-Codegraph.ps1 -ProjectPath "D:\path\to\your-app"
.\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath "D:\path\to\your-app"
# .\scripts\Install-Codegraph.ps1 -WriteWorkspaceMcp -ProjectPath "D:\path\to\your-app"
```

MCP files: `%USERPROFILE%\.cursor\mcp.json` and `%APPDATA%\Code\User\mcp.json` (see [config/codegraph-mcp.example.md](config/codegraph-mcp.example.md)).

Alias for init-only when CLI already exists: `.\scripts\Initialize-Codegraph.ps1 -ProjectPath "..."`.

Structural MCP tools use the local graph. Pull embeddings only if your Codegraph build needs them:

```powershell
.\scripts\Download-FromOllama.ps1 -Model nomic-embed-text
```

---

### Case L — Verify everything

```powershell
.\scripts\Test-LocalSetup.ps1
.\scripts\Show-SetupStatus.ps1
.\scripts\Install-ContinueConfig.ps1 -CheckOnly
.\scripts\Install-ClineConfig.ps1 -CheckOnly
.\scripts\Test-ClineSetup.ps1                # Cline fully on local Ollama (config + smoke)
.\scripts\Test-VSCodeSetup.ps1
# alias: .\scripts\Test-VSCodeOllama.ps1
.\scripts\Install-Headroom.ps1 -CheckOnly
.\scripts\Install-CursorConfig.ps1 -CheckOnly
.\scripts\Test-CursorOllama.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
# optional: .\scripts\Test-LocalSetup.ps1 -Model qwen2.5-coder:7b
```

| Symptom | Fix |
|---------|-----|
| `ollama` not found | New PowerShell window; or add `%LOCALAPPDATA%\Programs\Ollama` to user PATH |
| API connection refused | Start Ollama from Start menu / system tray |
| Script won’t run | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Pull too large / OOM | Re-run with `-Tier 8GB` or Case E |
| Execution / SmartScreen blocks installer | Allow `OllamaSetup.exe` or ask IT to whitelist |
| H-agent / H-agent-test red (Cline) | `.\scripts\Install-ClineConfig.ps1 -Force` then `.\scripts\Test-ClineSetup.ps1` |
| H / H-cfg / H-agent red | `.\scripts\Install-VSCodeLocalAI.ps1 -Force` then `.\scripts\Test-VSCodeSetup.ps1` |
| L-vscode red | `.\scripts\Test-VSCodeSetup.ps1` (script missing) or re-run LocalAI |
| Remote models still on | Quit Cursor; `.\scripts\Disable-RemoteAIProviders.ps1` |
| I-cfg red (Cursor Models) | Quit Cursor; `.\scripts\Install-CursorConfig.ps1` then `.\scripts\Test-CursorOllama.ps1` |
| J red (Headroom) | `.\scripts\Install-Headroom.ps1` (short venv `C:\hr`; avoid Store Python `pip --user`) |
| K / K-cli / K-node red (Codegraph) | `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` (fnm preferred) |

---

### Case M — ModelScope / GitHub Releases direct URL

```powershell
.\scripts\Download-FromUrl.ps1 -Url "https://.../model.Q4_K_M.gguf" -OutDir ".\models\gguf\external"
.\scripts\Import-GGUF.ps1 -GgufPath ".\models\gguf\external\model.Q4_K_M.gguf" -Name "external-coder"
```

---

### Case N — Check GPU for Ollama (non-admin, then admin)

**Non-admin first** (adapters, `nvidia-smi`, Ollama logs, verdict):

```powershell
cd D:\code\projects\local-llm-chat
.\scripts\Test-GpuSupport.ps1
.\scripts\Test-GpuSupport.ps1 -OutFile "$env:TEMP\ollama-gpu-report.txt"
```

**Admin / elevated** (UAC — pnputil, driverquery, elevated nvidia-smi). Same checks we ran manually before:

```powershell
# Option 1: built-in switch (non-admin report + admin section)
.\scripts\Test-GpuSupport.ps1 -Elevated
.\scripts\Test-GpuSupport.ps1 -Elevated -OutFile "$env:TEMP\ollama-gpu-full.txt"

# Option 2: elevate helper script only
$out = "$env:TEMP\gpu-admin-only.txt"
.\scripts\Invoke-Elevated.ps1 `
  -ScriptPath ".\scripts\Test-GpuSupport.Elevated.ps1" `
  -ArgumentList @("-OutFile", $out)
Get-Content $out

# Option 3: raw Start-Process -Verb RunAs (equivalent)
$script = (Resolve-Path ".\scripts\Test-GpuSupport.Elevated.ps1").Path
Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
  "-NoProfile", "-ExecutionPolicy", "Bypass",
  "-File", $script, "-OutFile", $out
)
```

More copy-paste samples: [docs/powershell-admin-examples.md](docs/powershell-admin-examples.md).

On unsupported GPUs (e.g. Kepler GT 650M / old drivers), Ollama stays on **CPU** — use smaller coding tiers. Admin rights do not unlock Ollama CUDA on that hardware.

**Optional NVIDIA driver install** (admin/UAC; skipped for VMs with no GPU in the guest):

```powershell
# Detect only — answers "can this VM use a GPU?"
.\scripts\Install-GpuDrivers.ps1

# Download + elevate installer when an NVIDIA device is visible
.\scripts\Install-GpuDrivers.ps1 -Install

# Or open NVIDIA's official picker
.\scripts\Install-GpuDrivers.ps1 -OpenDownloadPage

# Opt-in during machine setup:
.\scripts\Setup-Machine.ps1 -Tier Auto -InstallGpuDrivers
```

| Guest situation | Can Ollama use a GPU? |
|-----------------|------------------------|
| Bare metal NVIDIA | Yes, with current drivers (CC 5.0+) |
| VM **with** NVIDIA device (passthrough / GPU-P / GRID / cloud GPU) | Yes — install guest NVIDIA drivers |
| VM **without** NVIDIA (Hyper-V Video / VMware SVGA / VirtualBox only) | No — expose a GPU from the host first |

---

### Case O — Multiple models in parallel and in workflows

Switch models in Continue/Cursor, or run scripts:

```powershell
# Parallel: same prompt to the three example models
.\scripts\Invoke-ParallelModels.ps1 `
  -Prompt "Write a PowerShell function that reverses a string. Code only." `
  -Models @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b")

# Sequential workflow: draft then review
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow DraftReview `
  -Task "PowerShell: unique values of CSV column Name"

# Plan then implement
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow PlanImplement `
  -Task "Add retry with exponential backoff to Invoke-RestMethod"

# Parallel compare + judge
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow CompareJudge `
  -Task "Best way to parse JSON in PowerShell 5.1?"
```

Full patterns (editor roles, Headroom, Codegraph): [docs/multi-model-workflows.md](docs/multi-model-workflows.md).

Prompts to map/understand code faster: [docs/code-understanding-prompts.md](docs/code-understanding-prompts.md).

---

### Suggested order for a brand-new clone

1. **Case A** (or B if Ollama exists) — `Setup-Machine.ps1` installs Ollama/Cursor, pulls models, wires **Cursor** + **VS Code Local AI (Continue + Cline)** to Ollama, then verifies
2. **Case L** / `Show-SetupStatus.ps1` — confirm H/H-cfg/H-agent, I/I-cfg, and L-vscode are green
3. Re-run **Case H** / **Case I** only if editor config was skipped or failed (`Install-VSCodeLocalAI.ps1` then `Test-VSCodeSetup.ps1` / quit Cursor then `Install-CursorConfig.ps1`)
4. Optional: **Case N** (GPU), **Case J** (Headroom + `-Headroom` on editor scripts), **Case K** (Codegraph), **Case F/G/M** (extra models)

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
- Optional GPU: NVIDIA (driver ≥ 551.61) or AMD (ROCm/Vulkan) — see [Ollama Windows docs](https://docs.ollama.com/windows) and `Install-GpuDrivers.ps1`
- PowerShell 5.1+ (Windows built-in is fine)
- Optional: Cursor desktop (installed by `Install-Cursor.ps1` / `Setup-Machine.ps1` if missing; Models wired by `Install-CursorConfig.ps1`)
- Optional: VS Code Local AI — Continue chat + Cline agent (`Install-VSCodeLocalAI.ps1` / `Install-VSCodeConfig.ps1`; pieces: `Install-VSCode.ps1`, `Install-ContinueConfig.ps1`, `Install-ClineConfig.ps1`)

## Best local coding models

| Model | Why use it | Example Ollama tag |
|-------|------------|--------------------|
| **Qwen2.5-Coder** | Strong code reasoning; many sizes (3B–32B) | `qwen2.5-coder:7b` |
| **DeepSeek-Coder-V2** | Broad language coverage; large context options | `deepseek-coder-v2:16b` |
| **CodeLlama** | Meta’s widely supported code family | `codellama:13b` |
| **StarCoder2** (optional light) | Fast everyday help | `starcoder2:3b` |

Copy-paste pulls for the three primary examples are at the top of **First time after git clone**.

| System RAM (approx) | Suggested Ollama pulls |
|---------------------|------------------------|
| 8–12 GB | `qwen2.5-coder:3b`, `starcoder2:3b` |
| 16 GB | `qwen2.5-coder:7b`, `starcoder2:3b` |
| 32 GB+ | `qwen2.5-coder:14b`, `codellama:13b`, `deepseek-coder-v2:16b`, `starcoder2:7b` |

## Repo layout

```text
AGENTS.md       instructions for local agents / LLMs
FEATURES.md     shipped features + per-machine checklist
docs/           setup playbook, trusted sources, imports, integrations
scripts/        PowerShell install / download / import / Cursor / VS Code Local AI (Continue+Cline) / GPU / Headroom / Setup-Machine
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
| [docs/multi-model-workflows.md](docs/multi-model-workflows.md) | Parallel models + draft/review/plan workflows |
| [docs/code-understanding-prompts.md](docs/code-understanding-prompts.md) | Copy-paste prompts to map/understand code faster |
| [docs/powershell-admin-examples.md](docs/powershell-admin-examples.md) | Elevated / UAC PowerShell examples (GPU checks) |
| [docs/powershell-ollama-setup.md](docs/powershell-ollama-setup.md) | Install Ollama, env vars, verify API |
| [docs/trusted-sources.md](docs/trusted-sources.md) | Which hosts/orgs to trust |
| [docs/infosec-swot.md](docs/infosec-swot.md) | Infosec analysis & SWOT (trust boundaries, hardening backlog) |
| [docs/egress-hardening.md](docs/egress-hardening.md) | Optional firewall / proxy / air-gap egress guidance |
| [config/installer-pins.example.json](config/installer-pins.example.json) | Optional SHA256 pins for Ollama/Cursor/VS Code installers |
| [docs/install-models-from-web.md](docs/install-models-from-web.md) | Ollama Library, Hugging Face, ModelScope, Modelfile |
| [docs/integrations.md](docs/integrations.md) | Continue, Cursor, Codegraph, Headroom |

## Scripts

| Script | Role |
|--------|------|
| `scripts/Setup-FullLocalStack.ps1` | **Full scenario:** Ollama + Cursor + models + Continue + codegraph init + verify |
| `scripts/Initialize-Codegraph.ps1` | Index a project (`codegraph init`); runs `Install-Codegraph.ps1` if CLI missing |
| `scripts/Install-Codegraph.ps1` | fnm preferred → npm Codegraph → agent install → **Cursor + VS Code mcp.json** → init |

| `scripts/Setup-Machine.ps1` | **One-shot** after clone: env + Ollama + Cursor install + pulls + Cursor/VS Code Local AI config + verify (`-Tier Auto`) |
| `scripts/Show-SetupStatus.ps1` | Green/red dashboard for Cases A–O (VS Code H/H-cfg/H-agent, Cursor I/I-cfg, L-vscode, GPU-DRV, …) |
| `scripts/Invoke-ParallelModels.ps1` | Same prompt to multiple models concurrently |
| `scripts/Invoke-ModelWorkflow.ps1` | DraftReview / PlanImplement / CompareJudge pipelines |
| `scripts/Test-GpuSupport.ps1` | Non-admin GPU/Ollama/VM check; `-Elevated` for admin UAC driver check |
| `scripts/Test-GpuSupport.Elevated.ps1` | Admin-only helper (pnputil / driverquery / nvidia-smi) |
| `scripts/Install-GpuDrivers.ps1` | Optional NVIDIA drivers + VM GPU guidance (`-Install` / `-OpenDownloadPage`) |
| `scripts/Invoke-Elevated.ps1` | Generic `Start-Process -Verb RunAs` launcher for any script |
| `scripts/Test-LocalSetup.ps1` | Verify PATH, API, models (Case L) |
| `scripts/Test-CursorOllama.ps1` | Verify Cursor Models config + OpenAI `/v1/chat/completions` smoke |
| `scripts/Test-ContinueOllama.ps1` | Verify Continue chat config + Ollama smoke |
| `scripts/Test-ClineSetup.ps1` | Verify Cline fully uses repo local setup (providers + globalState + smoke) |
| `scripts/Test-VSCodeSetup.ps1` | Full VS Code Case H check (extensions, Continue, Cline via Test-ClineSetup, MCP, local-only) |
| `scripts/Test-VSCodeOllama.ps1` | Alias for Test-VSCodeSetup.ps1 |
| `scripts/Disable-RemoteAIProviders.ps1` | Disable remote/cloud providers for Cursor + VS Code (+ Ollama cloud) |
| `scripts/Update-CodingModels.ps1` | Force re-pull / refresh tier models |
| `scripts/Uninstall-Ollama.ps1` | Uninstall guidance + optional model cleanup |
| `scripts/Eval-CodingModel.ps1` | Run sample coding prompts against a local model |
| `scripts/Set-OllamaEnv.ps1` | Set `OLLAMA_MODELS` / install dir |
| `scripts/Install-Ollama.ps1` | Official per-user install |
| `scripts/Install-ContinueConfig.ps1` | Wire Continue → Ollama (ChatGPT-like chat + autocomplete) |
| `scripts/Install-ClineConfig.ps1` | Wire Cline → Ollama (Cursor-like agent in VS Code) |
| `scripts/Install-VSCode.ps1` | Check/install VS Code (per-user when possible) |
| `scripts/Install-VSCodeLocalAI.ps1` | Case H one-shot: VS Code + Continue + Cline + verify |
| `scripts/Install-VSCodeConfig.ps1` | Alias for Install-VSCodeLocalAI.ps1 |
| `scripts/Install-Cursor.ps1` | Check Cursor; install per-user if missing (Case I) |
| `scripts/Install-CursorConfig.ps1` | Find Cursor + wire Models → local Ollama; disable cloud models (`-KeepRemoteModels` to opt out) |
| `scripts/Download-FromOllama.ps1` | `ollama pull` (+ `hf.co` bridge); skips if already on disk (`-Force` to re-pull) |
| `scripts/Download-FromHuggingFace.ps1` | Download GGUF to `models/gguf` (skips existing; `-Force`) |
| `scripts/Download-FromUrl.ps1` | Direct URL (ModelScope / GitHub Releases); skips existing file |
| `scripts/Import-GGUF.ps1` | Register local GGUF with `ollama create` (skips existing name) |
| `scripts/New-CoderModelfile.ps1` | Generate a coding-tuned Modelfile |
| `scripts/Pull-CodingModels.ps1` | Opinionated pulls by RAM tier / Auto (skips installed tags) |
| `scripts/Install-Headroom.ps1` | Short-path venv (`C:\hr`) + `headroom-ai[proxy]` (avoids long-path pip failures) |
| `scripts/Start-HeadroomOllama.ps1` | Headroom proxy → Ollama `/v1` (uses `C:\hr` or PATH) |
| `scripts/_common.ps1` | Shared helpers (dot-sourced; not run alone) |

## License and credits

This repository (docs, PowerShell scripts, and config examples) is released under the [MIT License](LICENSE) — **Copyright (c) 2026 Radu Florescu**.

You may use, copy, modify, and redistribute it **as is** or adapted, including commercially, provided you **keep the copyright notice and license text** in copies or substantial portions (that is how credit is preserved).

The software is provided **without warranty**.

### Citing / attributing

If you fork, blog, or ship a derivative based on this toolkit, please credit:

- **Radu Florescu** — [github.com/floradu88/local-llm-chat](https://github.com/floradu88/local-llm-chat)

Example:

```text
Based on local-llm-chat by Radu Florescu (MIT) — https://github.com/floradu88/local-llm-chat
```

### Third-party / model licenses (separate)

This repo does **not** redistribute model weights. Respect each model’s own license (Qwen, DeepSeek, Meta Llama/CodeLlama, BigCode StarCoder2, etc.) and the terms of Ollama, VS Code, Cursor, Continue, Cline, Headroom, and Codegraph before redistributing those products or weights.

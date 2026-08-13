# Agent setup playbook (machine bootstrap)

Use this when a human or local agent must **set up this repo on a Windows machine**. Prefer `.\scripts\Setup-Machine.ps1` when possible.

## Preconditions

- Windows 10 22H2+ or Windows 11
- PowerShell 5.1+
- Network for first-time Ollama + model downloads
- Disk space for models (plan 10–50+ GB)
- **No admin required** for default Ollama per-user install

## Step 0 — open the repo

```powershell
cd D:\code\projects\local-llm-chat   # or wherever this repo was cloned
```

Confirm `AGENTS.md`, `README.md`, and `scripts\` exist.

## Step 1 — full bootstrap (recommended)

Pick RAM tier: `8GB`, `16GB`, or `32GB`.

```powershell
.\scripts\Setup-FullLocalStack.ps1 -Tier Auto -PullExampleModels
# or Ollama-only:
.\scripts\Setup-Machine.ps1 -Tier 16GB
```

Flags:

| Flag | Effect |
|------|--------|
| `-Tier 8GB\|16GB\|32GB` | Which coding models to pull |
| `-SkipInstall` | Ollama already installed |
| `-SkipPull` | Skip model pulls |
| `-SkipHeadroomHint` | Less console output about Headroom |
| `-InstallGpuDrivers` | Optional NVIDIA driver download + UAC install |
| `-ForceGpuDrivers` | Force driver install attempt (e.g. odd VM layouts) |
| `-SkipCursor` | Do not check/install Cursor |
| `-ForceCursor` | Re-run Cursor installer even if present |

What it does:

1. Sets `OLLAMA_MODELS` to `.\models\ollama` (User env)
2. Installs Ollama via official script (if needed)
3. Pulls tier coding models
4. Runs `Test-LocalSetup.ps1` and prints Continue / Cursor / Codegraph / Headroom next steps

## Step 2 — verify

```powershell
.\scripts\Test-LocalSetup.ps1
```

Manual equivalent:

```powershell
ollama --version
ollama list
Invoke-RestMethod http://localhost:11434/api/tags
```

Smoke:

```powershell
ollama run qwen2.5-coder:7b "Say ready"
```

(Use a tag that appears in `ollama list`.)

## Step 3 — editor (required for “local models in the IDE”)

Follow [integrations.md](integrations.md) and README Cases H/I:

**VS Code:**

```powershell
.\scripts\Install-ContinueConfig.ps1
```

Then install the Continue extension; set model to an installed tag.

**Cursor:**

```powershell
.\scripts\Install-Cursor.ps1   # installs for current user if missing
```

Then Models → base URL `http://localhost:11434/v1`, API key `ollama`, model = Ollama tag. Checklist: `config\cursor-openai-local.example.md`.

## Step 4 — optional Headroom

```powershell
.\scripts\Start-HeadroomOllama.ps1
```

Then Cursor base URL → `http://127.0.0.1:8787/v1`.

## Step 5 — optional Codegraph

```powershell
codegraph init
```

Structural tools use the local graph. Pull `nomic-embed-text` only if your Codegraph build needs embeddings.

## Alternate: import from Hugging Face

If Library tags are not enough:

```powershell
.\scripts\Download-FromHuggingFace.ps1 -Repo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" -Include "*Q4_K_M.gguf"
.\scripts\Import-GGUF.ps1 -GgufPath ".\models\gguf\..." -Name "qwen25-coder-local"
```

Details: [install-models-from-web.md](install-models-from-web.md), [trusted-sources.md](trusted-sources.md).

## Agent checklist (copy/paste)

- [ ] Repo root opened; README Cases A-M reviewed
- [ ] `Setup-Machine.ps1` succeeded (or manual steps in README)
- [ ] `Test-LocalSetup.ps1` reports OK
- [ ] Continue and/or Cursor pointed at Ollama
- [ ] (Optional) Headroom on 8787
- [ ] (Optional) `codegraph init` in target projects

## Failure handling

| Problem | Action |
|---------|--------|
| `ollama` not found | New terminal after install; check `%LOCALAPPDATA%\Programs\Ollama` on PATH |
| API down | Start Ollama from Start menu / tray |
| Pull OOM / too large | Re-run with `-Tier 8GB` |
| HF gated | Set `HF_TOKEN`, accept license on Hub |
| No admin / policy blocks EXE | Document block; user must allow OllamaSetup or use IT whitelist |

## Source of truth

- [README.md](../README.md) - first-time Cases A-M after clone
- [AGENTS.md](../AGENTS.md) - how agents should behave in this repo
- [powershell-ollama-setup.md](powershell-ollama-setup.md) - detailed install
- Scripts under `../scripts/` - do not reinvent installers

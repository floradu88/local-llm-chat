# Agent setup playbook (machine bootstrap)

Use this when a human or local agent must **set up this repo on a Windows machine**. Prefer `.\scripts\Setup-Machine.ps1` when possible.

## Preconditions

- Windows 10 22H2+ or Windows 11
- PowerShell 5.1+
- Network for first-time Ollama + model downloads
- Disk space for models (plan 10–50+ GB)
- **No admin required** for default Ollama / Cursor per-user installs
- Optional admin (UAC) only for NVIDIA driver install / elevated GPU diagnostics

## Step 0 — open the repo

```powershell
cd D:\code\projects\local-llm-chat   # or wherever this repo was cloned
```

Confirm `AGENTS.md`, `README.md`, `FEATURES.md`, and `scripts\` exist.

## Step 1 — full bootstrap (recommended)

Pick RAM tier: `8GB`, `16GB`, or `32GB` (or `Auto`).

```powershell
.\scripts\Setup-FullLocalStack.ps1 -Tier Auto -PullExampleModels
# or Ollama + Cursor + pulls:
.\scripts\Setup-Machine.ps1 -Tier 16GB
```

Flags:

| Flag | Effect |
|------|--------|
| `-Tier 8GB\|16GB\|32GB\|Auto` | Which coding models to pull |
| `-SkipInstall` | Ollama already installed |
| `-SkipPull` | Skip model pulls |
| `-SkipHeadroomHint` | Less console output about Headroom |
| `-InstallGpuDrivers` | Optional NVIDIA driver download + UAC install |
| `-ForceGpuDrivers` | Force driver install attempt (e.g. odd VM layouts) |
| `-SkipCursor` | Do not check/install Cursor |
| `-ForceCursor` | Re-run Cursor installer even if present |
| `-SkipCursorConfig` | Do not run `Install-CursorConfig.ps1` |
| `-ForceCursorConfig` | Pass `-Force` to Cursor Ollama config (quit Cursor first preferred) |
| `-SkipContinueConfig` | Do not run `Install-VSCodeLocalAI.ps1` |
| `-ForceContinueConfig` | Pass `-Force` (overwrite Continue/Cline configs) |
| `-SkipClineConfig` | Continue only (skip Cline agent) |
| `-SkipVSCodeInstall` | Do not auto-install VS Code when missing |

What `Setup-Machine.ps1` does:

1. Sets `OLLAMA_MODELS` to `.\models\ollama` (User env)
2. Installs Ollama via official script (if needed)
3. Optional GPU drivers when `-InstallGpuDrivers`
4. Checks Cursor; installs **current-user** build if missing (unless `-SkipCursor`)
5. Pulls tier coding models (**skips tags already on disk**; use `Update-CodingModels.ps1` or `-Force` to refresh)
6. Wires **Cursor Models → Ollama** via `Install-CursorConfig.ps1` (unless `-SkipCursorConfig`; quit Cursor if open)
7. Wires **VS Code Local AI** via `Install-VSCodeLocalAI.ps1` (unless `-SkipContinueConfig`) — Continue (chat) + Cline (agent)
8. Runs `Disable-RemoteAIProviders.ps1` (Cursor catalog remotes, Continue/Cline cloud providers, Copilot/chat settings, Ollama cloud)
9. Runs `Test-LocalSetup.ps1` and prints GPU / Headroom next steps

`Setup-FullLocalStack.ps1` also force-refreshes VS Code Local AI and runs `Install-Codegraph.ps1` for `-ProjectPath` when available.

## Step 2 — verify

```powershell
.\scripts\Test-LocalSetup.ps1
.\scripts\Show-SetupStatus.ps1
.\scripts\Install-Cursor.ps1 -CheckOnly
.\scripts\Install-CursorConfig.ps1 -CheckOnly
.\scripts\Test-CursorOllama.ps1
.\scripts\Test-VSCodeSetup.ps1
.\scripts\Test-ClineSetup.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
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

`Setup-Machine.ps1` already runs these unless skipped. Re-run manually per [integrations.md](integrations.md) and README Cases H/I:

**VS Code Local AI (Continue chat + Cline agent):**

```powershell
.\scripts\Install-VSCode.ps1              # if missing
.\scripts\Install-VSCodeLocalAI.ps1       # Continue + Cline + verify
# alias: .\scripts\Install-VSCodeConfig.ps1
.\scripts\Test-VSCodeSetup.ps1            # full Case H check
# alias: .\scripts\Test-VSCodeOllama.ps1
# pieces: Install-ContinueConfig.ps1 / Install-ClineConfig.ps1
```

Reload VS Code: **Continue** = ChatGPT-like chat/autocomplete; **Cline** = Cursor-like agent. Checklist: `config\vscode-ollama-local.example.md`.

**Cursor:**

```powershell
.\scripts\Install-Cursor.ps1          # installs for current user if missing
# Quit Cursor, then:
.\scripts\Install-CursorConfig.ps1    # wires Models → Ollama (state.vscdb)
.\scripts\Test-CursorOllama.ps1       # config + /v1/chat/completions smoke
.\scripts\Install-CursorConfig.ps1 -CheckOnly
```

Checklist: `config\cursor-openai-local.example.md`. By default cloud/catalog models are disabled; pass `-KeepRemoteModels` to keep them. Manual Models UI still works as a fallback (base URL `http://localhost:11434/v1`, key `ollama`).

## Step 4 — optional GPU

```powershell
.\scripts\Test-GpuSupport.ps1
.\scripts\Install-GpuDrivers.ps1              # detect / VM guidance
.\scripts\Install-GpuDrivers.ps1 -Install     # download + UAC when NVIDIA is visible
```

A **VM** can use a GPU with Ollama only if the guest already sees an NVIDIA device (passthrough / GPU-P / GRID / cloud GPU). Otherwise stay on CPU tiers.

## Step 5 — optional Headroom

Uses short-path venv `C:\hr` (avoids Windows long-path / Store Python pip failures; no admin):

```powershell
.\scripts\Install-Headroom.ps1
.\scripts\Start-HeadroomOllama.ps1
.\scripts\Install-CursorConfig.ps1 -Headroom
.\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force
```

Then use base URL `http://127.0.0.1:8787/v1` (key `ollama`) if configuring the UI by hand.

## Step 6 — optional Codegraph

```powershell
.\scripts\Install-Codegraph.ps1                              # this toolkit
.\scripts\Install-Codegraph.ps1 -ProjectPath "D:\path\to\app" # your app
.\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath "D:\path\to\app"
# Optional UAC for the agent-permissions pass:
# .\scripts\Install-Codegraph.ps1 -Elevated -ProjectPath "D:\path\to\app"
```

Flow: **fnm** (preferred, no admin) → Node → `npm i -g @colbymchenry/codegraph` → `codegraph install --no-permissions` → `codegraph install` (with permissions) → **update Cursor + VS Code mcp.json** → `codegraph init` if `.codegraph` missing. System `node`/`npm` is used **only if fnm fails** (pass `-RequireFnm` to forbid fallback; `-SkipFnm` to force system only).

Structural tools use the local graph. Pull `nomic-embed-text` only if your Codegraph build needs embeddings.

## Alternate: import from Hugging Face

If Library tags are not enough:

```powershell
.\scripts\Download-FromHuggingFace.ps1 -Repo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" -Include "*Q4_K_M.gguf"
.\scripts\Import-GGUF.ps1 -GgufPath ".\models\gguf\..." -Name "qwen25-coder-local"
```

Downloads and imports **skip when the file / Ollama name already exists** unless you pass `-Force`.

Details: [install-models-from-web.md](install-models-from-web.md), [trusted-sources.md](trusted-sources.md).

## Agent checklist (copy/paste)

- [ ] Repo root opened; README Cases A–O and FEATURES.md reviewed
- [ ] `Setup-Machine.ps1` succeeded (or manual steps in README)
- [ ] `Test-LocalSetup.ps1` / `Show-SetupStatus.ps1` report OK
- [ ] Cursor installed (`Install-Cursor.ps1 -CheckOnly`) and Models wired (`Test-CursorOllama.ps1`)
- [ ] VS Code Local AI wired (`Test-VSCodeSetup.ps1` / `Install-VSCodeLocalAI.ps1`)
- [ ] Remotes disabled (`Disable-RemoteAIProviders.ps1 -CheckOnly`)
- [ ] (Optional) Codegraph: `Install-Codegraph.ps1 -CheckOnly -ProjectPath <repo>`
- [ ] (Optional) GPU checked / drivers installed
- [ ] (Optional) Headroom on 8787 (`Install-Headroom.ps1` / `Start-HeadroomOllama.ps1`, then `Install-CursorConfig.ps1 -Headroom` / `Install-VSCodeLocalAI.ps1 -Headroom`)

## Failure handling

| Problem | Action |
|---------|--------|
| `ollama` not found | New terminal after install; check `%LOCALAPPDATA%\Programs\Ollama` on PATH |
| API down | Start Ollama from Start menu / tray |
| Pull OOM / too large | Re-run with `-Tier 8GB` |
| Pull skipped unexpectedly | Confirm tag in `ollama list` / manifests; use `-Force` or `Update-CodingModels.ps1` |
| HF gated | Set `HF_TOKEN`, accept license on Hub |
| Cursor missing | `.\scripts\Install-Cursor.ps1` (per-user; no admin) |
| Cursor Models not wired | Quit Cursor; `.\scripts\Install-CursorConfig.ps1` then `.\scripts\Test-CursorOllama.ps1` |
| VS Code Local AI incomplete | `.\scripts\Install-VSCodeLocalAI.ps1 -Force` then `.\scripts\Test-VSCodeSetup.ps1` |
| Remote/cloud models still on | Quit Cursor; `.\scripts\Disable-RemoteAIProviders.ps1` |
| Headroom missing / long-path pip fail | `.\scripts\Install-Headroom.ps1` (uses `C:\hr`; do not `pip --user` with Store Python) |
| Codegraph missing | `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` |
| VM has no GPU in guest | Expose GPU from host first; `Install-GpuDrivers.ps1` explains this |
| No admin / policy blocks EXE | Document block; user must allow OllamaSetup / CursorSetup or use IT whitelist |

## Source of truth

- [README.md](../README.md) - first-time Cases A–O after clone
- [FEATURES.md](../FEATURES.md) - shipped features + per-machine checklist
- [AGENTS.md](../AGENTS.md) - how agents should behave in this repo
- [powershell-ollama-setup.md](powershell-ollama-setup.md) - detailed install
- Scripts under `../scripts/` - do not reinvent installers

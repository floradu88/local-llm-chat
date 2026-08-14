# Agent instructions — local-llm-chat

You are working in the **local-llm-chat** repo. Its purpose is to install and run **local coding LLMs via Ollama** on Windows (no admin when possible), pull or import models from trusted sources, and wire **VS Code Local AI (Continue + Cline)**, **Cursor**, **Codegraph**, and **Headroom**.

## Always do this first

1. Read [README.md](README.md) — especially **First time after git clone** (Cases A–O) — and [FEATURES.md](FEATURES.md).
2. To **set up this machine**, follow [docs/agent-setup-playbook.md](docs/agent-setup-playbook.md) or run:

```powershell
cd <repo-root>
.\scripts\Setup-FullLocalStack.ps1 -Tier Auto -PullExampleModels
.\scripts\Show-SetupStatus.ps1
```

3. Prefer existing scripts under `scripts/` over inventing new install commands.
4. Never commit model weights (`.gguf`, blobs under `models/`), tokens, or `.env` secrets.

## Repo map

| Path | Role |
|------|------|
| `scripts/` | PowerShell: env, Ollama/Cursor/VS Code Local AI (Continue+Cline)/Codegraph/GPU install+config, pull/download/import, Headroom, full machine setup |
| `docs/` | Human + agent docs (setup, trusted sources, web import, integrations) |
| `config/` | Modelfile template, Continue example, VS Code + Cursor checklists |
| `models/gguf/` | Downloaded GGUF (gitignored) |
| `models/ollama/` | Optional `OLLAMA_MODELS` root (gitignored) |

## Setup order (canonical)

1. `.\scripts\Set-OllamaEnv.ps1 -Persistent`
2. `.\scripts\Install-Ollama.ps1`
3. `.\scripts\Install-Cursor.ps1` (skips if already installed; per-user)
4. `.\scripts\Pull-CodingModels.ps1 -Tier <8GB|16GB|32GB|Auto>` (skips tags already on disk; `-Force` to re-pull)
5. Wire **Cursor** → Ollama: quit Cursor if open, then `.\scripts\Install-CursorConfig.ps1` (finds install + writes Models into `state.vscdb`; disables cloud/catalog models by default; `-KeepRemoteModels` to keep them)
6. Wire **VS Code Local AI**: `.\scripts\Install-VSCodeLocalAI.ps1` then `.\scripts\Test-VSCodeSetup.ps1`
7. Local-only: `.\scripts\Disable-RemoteAIProviders.ps1` (disables Cursor catalog remotes, Continue/Cline cloud providers, Copilot/built-in chat, Ollama cloud)
8. `.\scripts\Test-LocalSetup.ps1` / `.\scripts\Show-SetupStatus.ps1` / `.\scripts\Test-CursorOllama.ps1` / `.\scripts\Test-VSCodeSetup.ps1`
9. Optional: `.\scripts\Install-GpuDrivers.ps1` / `Test-GpuSupport.ps1` (VM needs host GPU passthrough first)
10. Optional: `.\scripts\Install-Headroom.ps1` then `.\scripts\Start-HeadroomOllama.ps1` then `Install-CursorConfig.ps1 -Headroom` and/or `Install-VSCodeLocalAI.ps1 -Headroom -Force`
11. Optional: `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` (**fnm preferred**; updates **Cursor + VS Code mcp.json**; system npm only if fnm fails → agent install → `codegraph init`)

One-shot: `.\scripts\Setup-Machine.ps1` (env + Ollama + Cursor install + pulls + **Cursor config** + **VS Code Local AI** + **Disable-RemoteAIProviders** + verify). Use `-SkipCursor` / `-SkipCursorConfig` / `-SkipContinueConfig` / `-SkipClineConfig` / `-InstallGpuDrivers` / `-AirGap` as needed.

Editor details: [docs/integrations.md](docs/integrations.md), Cases H/I in README, `config/vscode-ollama-local.example.md`, `config/cursor-openai-local.example.md`, `config/local-only-ai.example.md`.

Security docs: [docs/trusted-sources.md](docs/trusted-sources.md), [docs/infosec-swot.md](docs/infosec-swot.md), [docs/egress-hardening.md](docs/egress-hardening.md), `config/installer-pins.example.json`.

## Trusted sources only

Follow [docs/trusted-sources.md](docs/trusted-sources.md):

1. Ollama Library  
2. Hugging Face (official orgs / known GGUF packagers)  
3. `hf.co/...` via Ollama  
4. ModelScope / upstream GitHub Releases → `Download-FromUrl.ps1` + `Import-GGUF.ps1` (HTTPS allowlist; prefer `-ExpectedSha256`)  

Do not fetch models from random Drive/Telegram/unsigned mirrors. Prefer `Install-Ollama.ps1` (no `irm|iex`). For offline re-wire use `Setup-Machine.ps1 -AirGap`.

## When the user asks to “set up local models”

- Run or guide `Setup-Machine.ps1` with an appropriate `-Tier` from their RAM (`-AirGap` if no downloads allowed).
- Verify with `.\scripts\Test-LocalSetup.ps1`, `.\scripts\Show-SetupStatus.ps1`, `.\scripts\Test-VSCodeSetup.ps1` (alias `Test-VSCodeOllama.ps1`), `.\scripts\Test-ClineSetup.ps1`, and `.\scripts\Test-CursorOllama.ps1` (H/H-cfg/H-agent, I/I-cfg, L-vscode should go green).
- Cursor: `Install-Cursor.ps1` then quit Cursor and `Install-CursorConfig.ps1`.
- VS Code: `Install-VSCodeLocalAI.ps1` (Continue chat + Cline agent); or Continue-only / Cline-only scripts.
- Local-only remotes: `Disable-RemoteAIProviders.ps1` (OpenAI/Cursor/Grok/Copilot/etc.).
- Headroom (optional): `Install-Headroom.ps1` then `Start-HeadroomOllama.ps1` (short venv `C:\hr`; avoid Store Python `pip --user`).
- Point them at [docs/integrations.md](docs/integrations.md), [docs/egress-hardening.md](docs/egress-hardening.md), and the config checklists under `config/`.
- For Hugging Face GGUF: `Download-FromHuggingFace.ps1` then `Import-GGUF.ps1` (both skip if already present unless `-Force`).
- For ModelScope/GitHub URL: `Download-FromUrl.ps1` (allowlisted HTTPS; optional `-ExpectedSha256`) then `Import-GGUF.ps1`.
- For GPU questions / VMs: `Test-GpuSupport.ps1` and `Install-GpuDrivers.ps1` (guest needs a visible NVIDIA device).

## When answering coding questions in this workspace

- Treat this repo’s docs/scripts as the source of truth for local LLM ops.
- Use Codegraph MCP tools for other codebases when available; this repo is mostly docs/scripts (no app runtime).

## Out of scope

- Shipping weights in git  
- Requiring admin / Windows services unless the user asks (GPU driver install is the main optional UAC path)  
- Treating LM Studio as primary (Ollama is primary; LM Studio is optional alternative UI only)  
- Configuring Hyper-V/VMware GPU passthrough on the host (document only)

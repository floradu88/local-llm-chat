# Agent instructions — local-llm-chat

You are working in the **local-llm-chat** repo. Its purpose is to install and run **local coding LLMs via Ollama** on Windows (no admin when possible), pull or import models from trusted sources, and wire **VS Code (Continue)**, **Cursor**, **Codegraph**, and **Headroom**.

## Always do this first

1. Read [README.md](README.md) for layout and quick start.
2. To **set up this machine**, follow [docs/agent-setup-playbook.md](docs/agent-setup-playbook.md) or run:

```powershell
cd <repo-root>
.\scripts\Setup-Machine.ps1 -Tier 16GB
```

3. Prefer existing scripts under `scripts/` over inventing new install commands.
4. Never commit model weights (`.gguf`, blobs under `models/`), tokens, or `.env` secrets.

## Repo map

| Path | Role |
|------|------|
| `scripts/` | PowerShell: env, Ollama install, pull/download/import, Headroom, full machine setup |
| `docs/` | Human + agent docs (setup, trusted sources, web import, integrations) |
| `config/` | Modelfile template, Continue example, Cursor checklist |
| `models/gguf/` | Downloaded GGUF (gitignored) |
| `models/ollama/` | Optional `OLLAMA_MODELS` root (gitignored) |

## Setup order (canonical)

1. `.\scripts\Set-OllamaEnv.ps1 -Persistent`
2. `.\scripts\Install-Ollama.ps1`
3. `.\scripts\Pull-CodingModels.ps1 -Tier <8GB|16GB|32GB>` (or download/import from HF — see docs)
4. Wire editor: [docs/integrations.md](docs/integrations.md)
5. Optional: `.\scripts\Start-HeadroomOllama.ps1`
6. Optional: `codegraph init` in projects that need the graph

One-shot: `.\scripts\Setup-Machine.ps1` (does 1–3 and prints editor steps).

## Trusted sources only

Follow [docs/trusted-sources.md](docs/trusted-sources.md):

1. Ollama Library  
2. Hugging Face (official orgs / known GGUF packagers)  
3. `hf.co/...` via Ollama  
4. ModelScope / upstream GitHub Releases → same GGUF import path  

Do not fetch models from random Drive/Telegram/unsigned mirrors.

## When the user asks to “set up local models”

- Run or guide `Setup-Machine.ps1` with an appropriate `-Tier` from their RAM.
- Verify with `ollama list` and `Invoke-RestMethod http://localhost:11434/api/tags`.
- Point them at Continue/Cursor config under `config/` and [docs/integrations.md](docs/integrations.md).
- For Hugging Face GGUF: `Download-FromHuggingFace.ps1` then `Import-GGUF.ps1`.

## When answering coding questions in this workspace

- Treat this repo’s docs/scripts as the source of truth for local LLM ops.
- Use Codegraph MCP tools for other codebases when available; this repo is mostly docs/scripts (no app runtime).

## Out of scope

- Shipping weights in git  
- Requiring admin / Windows services unless the user asks  
- Treating LM Studio as primary (Ollama is primary)

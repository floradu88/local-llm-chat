# Integrations: VS Code, Cursor, Codegraph, Headroom

Assume Ollama is running on `http://localhost:11434` and you have at least one coding model (`ollama list`).

If this machine is not set up yet, run `.\scripts\Setup-Machine.ps1` first (see [AGENTS.md](../AGENTS.md) and [agent-setup-playbook.md](agent-setup-playbook.md)). Local agents in this workspace are steered by those files plus `.cursor/rules/local-llm-setup.mdc`.

## VS Code Local AI — ChatGPT-like + Cursor-like

| Goal | Extension | What you get |
|------|-----------|--------------|
| ChatGPT-like | **Continue** | Sidebar chat, inline edit, **tab autocomplete** |
| Cursor-like agent | **Cline** | Multi-file edits, terminal tools, autonomous tasks |
| Both | `Install-VSCodeLocalAI.ps1` | Install/wire both + `Test-VSCodeSetup.ps1` |

One-shot (Case H):

```powershell
.\scripts\Install-VSCode.ps1              # if Code missing (per-user)
.\scripts\Install-VSCodeLocalAI.ps1       # Continue + Cline + Test-VSCodeSetup
.\scripts\Test-VSCodeSetup.ps1            # full config check
.\scripts\Install-VSCodeLocalAI.ps1 -CheckOnly
# alias:
.\scripts\Install-VSCodeConfig.ps1
# alias for test:
.\scripts\Test-VSCodeOllama.ps1
```

`Test-VSCodeSetup.ps1` verifies: VS Code install, Continue + Cline extensions, Ollama reachability, Continue/Cline local-only config (+ optional smoke), VS Code `mcp.json` Codegraph entry, and Copilot/chat local-only settings (warn).

Checklist: [config/vscode-ollama-local.example.md](../config/vscode-ollama-local.example.md).

### Continue only (chat + autocomplete)

```powershell
.\scripts\Install-ContinueConfig.ps1 -Force
.\scripts\Test-ContinueOllama.ps1
```

Writes `%USERPROFILE%\.continue\config.json` from `ollama list`. Manual copy:

```powershell
Copy-Item .\config\continue.config.example.json $HOME\.continue\config.json
```

Continue talks to Ollama at `http://localhost:11434` (no API key). With `-Headroom`, provider `openai` at `http://127.0.0.1:8787/v1` (key `ollama`).

### Cline only (agent)

```powershell
.\scripts\Install-ClineConfig.ps1 -Force
```

Installs marketplace id `saoudrizwan.claude-dev` and writes the same files as `ollama launch cline`:

- `%USERPROFILE%\.cline\data\settings\providers.json`
- `%USERPROFILE%\.cline\data\globalState.json`

Reload VS Code → Cline → Provider **Ollama**, Context Window ≥ **32k**.

### Headroom (both)

```powershell
.\scripts\Install-Headroom.ps1              # once: short venv C:\hr (avoids long-path pip failures)
.\scripts\Start-HeadroomOllama.ps1
.\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force
```

## Local-only (disable remote / cloud providers)

Block OpenAI, Anthropic, Grok, Gemini, Cursor catalog, Copilot, etc.:

```powershell
# Quit Cursor first, then:
.\scripts\Disable-RemoteAIProviders.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
```

Checklist: [config/local-only-ai.example.md](../config/local-only-ai.example.md). `Setup-Machine.ps1` and `Install-VSCodeLocalAI.ps1` run the VS Code side by default.

## Cursor — local OpenAI-compatible endpoint

Install or verify the desktop app (per-user, no admin):

```powershell
.\scripts\Install-Cursor.ps1
```

### Configure from PowerShell (recommended)

Quit Cursor, then:

```powershell
.\scripts\Install-CursorConfig.ps1
.\scripts\Install-CursorConfig.ps1 -CheckOnly
```

The script locates Cursor under `%LOCALAPPDATA%\Programs\Cursor` (or Program Files) and writes Models settings into `%APPDATA%\Cursor\User\globalStorage\state.vscdb` (base URL `http://localhost:11434/v1`, key `ollama`, enabled Ollama tags, **cloud/catalog models disabled**). Use `-KeepRemoteModels` to leave Cursor cloud models enabled. Restart Cursor afterward.

Verify:

```powershell
.\scripts\Test-CursorOllama.ps1
```

### Manual UI

1. Cursor Settings → **Models**.
2. Enable OpenAI-compatible / override base URL:
   - **Base URL:** `http://localhost:11434/v1`
   - **API key:** `ollama` (any non-empty string; Ollama ignores it)
   - **Model:** exact Ollama tag, e.g. `qwen2.5-coder:7b`

See [config/cursor-openai-local.example.md](../config/cursor-openai-local.example.md).

### Via Headroom (context compression)

1. Install (short venv `C:\hr`) and start the proxy:

```powershell
.\scripts\Install-Headroom.ps1
.\scripts\Start-HeadroomOllama.ps1
```

2. Point Cursor at Headroom:

```powershell
.\scripts\Install-CursorConfig.ps1 -Headroom
# or Models UI: Base URL http://127.0.0.1:8787/v1  key ollama
```

Traffic: Cursor → Headroom → Ollama. Headroom shrinks tool/context payload size; it does not replace a strong coding model.

## Headroom → Ollama

**Preferred (no admin):** short venv at `C:\hr` — Store/user-site pip often fails because `litellm` exceeds Windows MAX_PATH without Long Paths (admin).

```powershell
.\scripts\Install-Headroom.ps1              # creates C:\hr, installs headroom-ai[proxy]
.\scripts\Start-HeadroomOllama.ps1 -Port 8787
# Internally aims OpenAI-compatible traffic at http://127.0.0.1:11434/v1
```

Avoid on Store Python:

```powershell
# Often fails: OSError / long path under litellm\proxy\guardrails\...
pip install --user "headroom-ai[proxy]"
```

Manual (after Install-Headroom):

```powershell
$env:OPENAI_TARGET_API_URL = "http://127.0.0.1:11434/v1"
C:\hr\Scripts\headroom.exe proxy --port 8787 --openai-api-url http://127.0.0.1:11434/v1
```

Health check:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/livez
```

Point any OpenAI-compatible client at `http://127.0.0.1:8787/v1`.

## Codegraph

Codegraph builds a **local** structural index (`.codegraph/`) so agents can query call graphs without dumping whole files into the LLM.

### Install (fnm preferred → system npm fallback → agent wire → init)

No admin for the default path. Order:

1. **fnm** + Node LTS (per-user) — **preferred**
2. If fnm fails: fall back to **system** `node`/`npm` only
3. `npm i -g @colbymchenry/codegraph` (via the preferred runtime)
4. `codegraph install --yes --no-permissions` (MCP wire without agent auto-allow)
5. `codegraph install --yes` (second pass **with** agent permissions)
6. Update **MCP JSON** for Cursor (`~/.cursor/mcp.json`) **and** VS Code (`%APPDATA%\Code\User\mcp.json`) — prefers fnm `aliases\default\node.exe` + Codegraph npm-shim
7. `codegraph init` in the target repo if `.codegraph` is missing

```powershell
.\scripts\Install-Codegraph.ps1
.\scripts\Install-Codegraph.ps1 -ProjectPath "D:\path\to\your-app"
.\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath "D:\path\to\your-app"
# Also write portable .cursor/mcp.json + .vscode/mcp.json in the project:
# .\scripts\Install-Codegraph.ps1 -WriteWorkspaceMcp -ProjectPath "D:\path\to\your-app"
# Force fnm only (no system fallback):
# .\scripts\Install-Codegraph.ps1 -RequireFnm
# System npm only (not recommended):
# .\scripts\Install-Codegraph.ps1 -SkipFnm
```

MCP checklist: [config/codegraph-mcp.example.md](../config/codegraph-mcp.example.md).

`Setup-FullLocalStack.ps1` calls this for `-ProjectPath` (default: this toolkit). Init-only helper: `Initialize-Codegraph.ps1` (auto-runs install if CLI missing).

Manual equivalent (fnm preferred):

```powershell
# preferred:
winget install Schniz.fnm --scope user
fnm install lts-latest
fnm use lts-latest
# then:
npm i -g @colbymchenry/codegraph
codegraph install --yes --target=cursor --no-permissions
codegraph install --yes --target=cursor
cd your-project
codegraph init
```

- Structural MCP tools work from the local AST/graph index (offline).
- Only pull Ollama models for Codegraph if **your** Codegraph build documents an LLM or embedding requirement (e.g. agentic query or vector search). Example embed model: `nomic-embed-text`.

```powershell
.\scripts\Download-FromOllama.ps1 -Model nomic-embed-text
```

Keep indexing local-first: do not send the repo to a cloud embed API unless you intentionally choose a cloud provider.

Restart **Cursor** and **VS Code** after `Install-Codegraph.ps1` so MCP reloads from `~/.cursor/mcp.json` and `%APPDATA%\Code\User\mcp.json`. Ensure `codegraph init` has been run in the workspace so tools resolve symbols.

**Faster understanding:** use Codegraph first, then prompts from [code-understanding-prompts.md](code-understanding-prompts.md).

## Suggested daily loop

1. Ollama tray / `ollama serve` running.
2. Optional: `.\scripts\Install-Headroom.ps1` then `.\scripts\Start-HeadroomOllama.ps1`, then `Install-CursorConfig.ps1 -Headroom` and/or `Install-VSCodeLocalAI.ps1 -Headroom -Force`.
3. VS Code Local AI **or** Cursor already wired (`Install-VSCodeLocalAI.ps1` / `Install-CursorConfig.ps1`).
4. Codegraph MCP available after `codegraph init` in the project.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Continue / Cline / Cursor cannot reach model | `Invoke-RestMethod http://localhost:11434/api/tags` |
| VS Code Local AI incomplete | `.\scripts\Install-VSCodeLocalAI.ps1 -Force` then `.\scripts\Test-VSCodeSetup.ps1` |
| Continue only | `.\scripts\Install-ContinueConfig.ps1 -Force` |
| Cline only | `.\scripts\Install-ClineConfig.ps1 -Force` |
| VS Code missing | `.\scripts\Install-VSCode.ps1` |
| Cursor not installed | `.\scripts\Install-Cursor.ps1` |
| Cursor Models not wired | Quit Cursor; `.\scripts\Install-CursorConfig.ps1` then `.\scripts\Test-CursorOllama.ps1` |
| Remote/cloud models still available | `.\scripts\Disable-RemoteAIProviders.ps1` (quit Cursor first) |
| Wrong model name | Must match `ollama list` exactly |
| Pull downloaded again | Scripts skip by default; unexpected re-pull → check tag / use manifests; intentional refresh → `-Force` |
| Headroom CLI missing / long-path pip fail | `.\scripts\Install-Headroom.ps1` (short venv `C:\hr`; avoid `pip --user` with Store Python) |
| Headroom 502 / empty | Ollama up; URL ends with `/v1` for OpenAI path; proxy running on :8787 |
| Out of memory | Smaller tag/quant; `ollama stop <model>`; close other GPU apps |
| GPU unused / VM | `.\scripts\Test-GpuSupport.ps1` and `.\scripts\Install-GpuDrivers.ps1` |
| Codegraph empty / CLI missing | `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` |
| Codegraph empty | Run `codegraph init` in the project root (or Install-Codegraph.ps1) |
| Cline weak agent results | Larger coding model; Context Window ≥ 32k; enable Compact Prompt in Cline |

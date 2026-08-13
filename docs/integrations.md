# Integrations: VS Code, Cursor, Codegraph, Headroom

Assume Ollama is running on `http://localhost:11434` and you have at least one coding model (`ollama list`).

If this machine is not set up yet, run `.\scripts\Setup-Machine.ps1` first (see [AGENTS.md](../AGENTS.md) and [agent-setup-playbook.md](agent-setup-playbook.md)). Local agents in this workspace are steered by those files plus `.cursor/rules/local-llm-setup.mdc`.

## VS Code — Continue

Find VS Code and wire Continue from PowerShell (Case H):

```powershell
.\scripts\Install-ContinueConfig.ps1
# same script:
.\scripts\Install-VSCodeConfig.ps1
.\scripts\Install-ContinueConfig.ps1 -CheckOnly
```

That locates `Code.exe` / `code` CLI, installs the **Continue** extension when possible, and writes `%USERPROFILE%\.continue\config.json` using tags from `ollama list` (or `-Models`). Reload VS Code and select a model.

Manual alternative: copy the example and install the extension yourself:

```powershell
Copy-Item .\config\continue.config.example.json $HOME\.continue\config.json
# or:
.\scripts\Install-ContinueConfig.ps1 -SkipExtension -Force
```

Continue talks to Ollama directly at `http://localhost:11434` (no API key required for local). With `-Headroom`, it uses provider `openai` at `http://127.0.0.1:8787/v1` (key `ollama`).

To use **multiple models**: keep several entries in the Continue config and switch in the UI; for parallel/workflow scripts see [multi-model-workflows.md](multi-model-workflows.md).

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

1. Start the proxy:

```powershell
.\scripts\Start-HeadroomOllama.ps1
```

2. Point Cursor at Headroom:

```powershell
.\scripts\Install-CursorConfig.ps1 -Headroom
# or Models UI: Base URL http://127.0.0.1:8787/v1  key ollama
```

Traffic: Cursor → Headroom → Ollama. Headroom shrinks tool/context payload size; it does not replace a strong coding model.

## Headroom → Ollama

Install (user site, no admin if pip allows):

```powershell
pip install --user "headroom-ai[proxy]"
```

Start:

```powershell
.\scripts\Start-HeadroomOllama.ps1 -Port 8787
# Internally aims OpenAI-compatible traffic at http://127.0.0.1:11434/v1
```

Manual:

```powershell
$env:OPENAI_TARGET_API_URL = "http://127.0.0.1:11434/v1"
headroom proxy --port 8787 --openai-api-url http://127.0.0.1:11434/v1
```

Health check:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/livez
```

Point any OpenAI-compatible client at `http://127.0.0.1:8787/v1`.

## Codegraph

Codegraph builds a **local** structural index (`.codegraph/`) so agents can query call graphs without dumping whole files into the LLM.

### Install (fnm → npm → agent wire → init)

No admin for the default path. Order:

1. **fnm** + Node LTS (per-user)
2. `npm i -g @colbymchenry/codegraph`
3. `codegraph install --yes --no-permissions` (MCP wire without agent auto-allow)
4. `codegraph install --yes` (second pass **with** agent permissions)
5. `codegraph init` in the target repo if `.codegraph` is missing

```powershell
.\scripts\Install-Codegraph.ps1
.\scripts\Install-Codegraph.ps1 -ProjectPath "D:\path\to\your-app"
.\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath "D:\path\to\your-app"
# Optional UAC for the permissions pass:
# .\scripts\Install-Codegraph.ps1 -Elevated -ProjectPath "D:\path\to\your-app"
```

`Setup-FullLocalStack.ps1` calls this for `-ProjectPath` (default: this toolkit). Init-only helper: `Initialize-Codegraph.ps1` (auto-runs install if CLI missing).

Manual equivalent:

```powershell
# fnm + node (if needed), then:
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

Restart Cursor after `codegraph install` so MCP reloads. Ensure `codegraph init` has been run in the workspace so tools resolve symbols.

**Faster understanding:** use Codegraph first, then prompts from [code-understanding-prompts.md](code-understanding-prompts.md).

## Suggested daily loop

1. Ollama tray / `ollama serve` running.
2. Optional: `.\scripts\Start-HeadroomOllama.ps1`, then `Install-CursorConfig.ps1 -Headroom` and/or `Install-ContinueConfig.ps1 -Headroom -Force`.
3. VS Code Continue **or** Cursor already wired via `Install-ContinueConfig.ps1` / `Install-CursorConfig.ps1` (or Models UI → Ollama / Headroom).
4. Codegraph MCP available after `codegraph init` in the project.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Continue / Cursor cannot reach model | `Invoke-RestMethod http://localhost:11434/api/tags` |
| VS Code / Continue not wired | `.\scripts\Install-ContinueConfig.ps1` (alias `Install-VSCodeConfig.ps1`) |
| Cursor not installed | `.\scripts\Install-Cursor.ps1` |
| Cursor Models not wired | Quit Cursor; `.\scripts\Install-CursorConfig.ps1` then `.\scripts\Test-CursorOllama.ps1` |
| Wrong model name | Must match `ollama list` exactly |
| Pull downloaded again | Scripts skip by default; unexpected re-pull → check tag / use manifests; intentional refresh → `-Force` |
| Headroom 502 / empty | Ollama up; URL ends with `/v1` for OpenAI path |
| Out of memory | Smaller tag/quant; `ollama stop <model>`; close other GPU apps |
| GPU unused / VM | `.\scripts\Test-GpuSupport.ps1` and `.\scripts\Install-GpuDrivers.ps1` |
| Codegraph empty / CLI missing | `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` |
| Codegraph empty | Run `codegraph init` in the project root (or Install-Codegraph.ps1) |

# Integrations: VS Code, Cursor, Codegraph, Headroom

Assume Ollama is running on `http://localhost:11434` and you have at least one coding model (`ollama list`).

If this machine is not set up yet, run `.\scripts\Setup-Machine.ps1` first (see [AGENTS.md](../AGENTS.md) and [agent-setup-playbook.md](agent-setup-playbook.md)). Local agents in this workspace are steered by those files plus `.cursor/rules/local-llm-setup.mdc`.

## VS Code — Continue

1. Install the [Continue](https://marketplace.visualstudio.com/items?itemName=Continue.continue) extension.
2. Copy the example config:

```powershell
Copy-Item .\config\continue.config.example.json $HOME\.continue\config.json
```

Or merge the Ollama block into your existing Continue config. Set `model` to a tag from `ollama list` (e.g. `qwen2.5-coder:7b`).

3. Reload VS Code and select that model in Continue.

Continue talks to Ollama directly at `http://localhost:11434` (no API key required for local).

## Cursor — local OpenAI-compatible endpoint

### Direct to Ollama

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

2. In Cursor Models:
   - **Base URL:** `http://127.0.0.1:8787/v1`
   - **API key:** `ollama`
   - **Model:** same Ollama tag

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

Typical flow:

```powershell
# In each project you care about
codegraph init
```

- Structural MCP tools work from the local AST/graph index (offline).
- Only pull Ollama models for Codegraph if **your** Codegraph build documents an LLM or embedding requirement (e.g. agentic query or vector search). Example embed model: `nomic-embed-text`.

```powershell
.\scripts\Download-FromOllama.ps1 -Model nomic-embed-text
```

Keep indexing local-first: do not send the repo to a cloud embed API unless you intentionally choose a cloud provider.

If Cursor already has the Codegraph MCP server configured, ensure `codegraph init` has been run in the workspace so tools resolve symbols.

## Suggested daily loop

1. Ollama tray / `ollama serve` running.
2. Optional: `.\scripts\Start-HeadroomOllama.ps1`.
3. VS Code Continue **or** Cursor base URL → Ollama (or Headroom).
4. Codegraph MCP available after `codegraph init` in the project.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Continue / Cursor cannot reach model | `Invoke-RestMethod http://localhost:11434/api/tags` |
| Wrong model name | Must match `ollama list` exactly |
| Headroom 502 / empty | Ollama up; URL ends with `/v1` for OpenAI path |
| Out of memory | Smaller tag/quant; `ollama stop <model>`; close other GPU apps |
| Codegraph empty | Run `codegraph init` in the project root |

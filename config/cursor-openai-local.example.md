# Cursor → local Ollama (checklist)

## Direct (no Headroom)

1. Open **Cursor Settings → Models**.
2. Add / enable an OpenAI-compatible provider:
   - Base URL: `http://localhost:11434/v1`
   - API key: `ollama`
3. Model name must match `ollama list` exactly, for example:
   - `qwen2.5-coder:7b`
   - `starcoder2:3b`
   - `coder` (if you created a custom Modelfile alias)

## Via Headroom

1. Run `.\scripts\Start-HeadroomOllama.ps1` from this repo.
2. Base URL: `http://127.0.0.1:8787/v1`
3. API key: `ollama`
4. Same model tag as above.

## Verify Ollama first

```powershell
ollama list
Invoke-RestMethod http://localhost:11434/api/tags
```

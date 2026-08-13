# Cursor → local Ollama (checklist)

## Example model tags (copy-paste)

After pulling the three primary examples from README:

- `qwen2.5-coder:7b`
- `deepseek-coder-v2:16b`
- `codellama:13b`

```powershell
ollama pull qwen2.5-coder:7b
ollama pull deepseek-coder-v2:16b
ollama pull codellama:13b
ollama list
```

## Direct (no Headroom)

1. Open **Cursor Settings → Models**.
2. Add / enable an OpenAI-compatible provider:
   - Base URL: `http://localhost:11434/v1`
   - API key: `ollama`
3. Model name must match `ollama list` exactly (use one of the three tags above).

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

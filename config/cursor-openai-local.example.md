# Cursor → local Ollama (checklist)

## Install Cursor (if needed)

Per-user install (no admin); skips when already present:

```powershell
.\scripts\Install-Cursor.ps1
.\scripts\Install-Cursor.ps1 -CheckOnly
```

## Configure Models from PowerShell (recommended)

Quit Cursor, then:

```powershell
.\scripts\Install-CursorConfig.ps1
.\scripts\Install-CursorConfig.ps1 -CheckOnly
# Via Headroom proxy:
# .\scripts\Install-CursorConfig.ps1 -Headroom
# Keep Cursor cloud models enabled (opt out of local-only):
# .\scripts\Install-CursorConfig.ps1 -KeepRemoteModels
```

The script finds Cursor under `%LOCALAPPDATA%\Programs\Cursor` (or Program Files), writes `%APPDATA%\Cursor\User\globalStorage\state.vscdb`:

| Setting | Value |
|---------|--------|
| Override OpenAI Base URL | `http://localhost:11434/v1` |
| OpenAI API key | `ollama` (any non-empty string) |
| Enabled models | tags from `ollama list` (or README examples) |
| Cloud / catalog models | **disabled by default** (toggle off in Models UI) |

Restart Cursor afterward. Defaults Composer/Cmd-K to the first local tag when remotes are disabled. Optional: `-SetAsDefault` / `-KeepRemoteModels`.

## Example model tags (copy-paste)

After pulling the three primary examples from README (skips if already on disk):

- `qwen2.5-coder:7b`
- `deepseek-coder-v2:16b`
- `codellama:13b`

```powershell
.\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:7b
.\scripts\Download-FromOllama.ps1 -Model deepseek-coder-v2:16b
.\scripts\Download-FromOllama.ps1 -Model codellama:13b
ollama list
.\scripts\Install-CursorConfig.ps1 -Models qwen2.5-coder:7b,deepseek-coder-v2:16b,codellama:13b
```

## Manual UI (if script skipped)

1. Open **Cursor Settings → Models**.
2. Add / enable an OpenAI-compatible provider:
   - Base URL: `http://localhost:11434/v1`
   - API key: `ollama`
3. Model name must match `ollama list` exactly (use one of the three tags above).
4. Turn **off** cloud/catalog models you do not want; keep only local tags on.

## Via Headroom

1. Run `.\scripts\Start-HeadroomOllama.ps1` from this repo.
2. `.\scripts\Install-CursorConfig.ps1 -Headroom` **or** set Base URL `http://127.0.0.1:8787/v1` in the UI.
3. API key: `ollama`
4. Same model tag as above.

## Verify Ollama first

```powershell
ollama list
Invoke-RestMethod http://localhost:11434/api/tags
.\scripts\Show-SetupStatus.ps1
.\scripts\Test-CursorOllama.ps1
```

`Test-CursorOllama.ps1` checks Models wiring (including remote models disabled) and smokes `POST …/v1/chat/completions` the same way Cursor does.

Also run `.\scripts\Disable-RemoteAIProviders.ps1` to strip remotes from Continue/Cline and disable Copilot/built-in chat AI (see [local-only-ai.example.md](local-only-ai.example.md)).

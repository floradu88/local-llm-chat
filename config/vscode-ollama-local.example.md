# VS Code → local Ollama (Continue chat + Cline agent)

## Roles

| Experience | Extension | Script |
|------------|-----------|--------|
| ChatGPT-like chat + tab autocomplete | **Continue** | `Install-ContinueConfig.ps1` |
| Cursor-like agent (files / terminal) | **Cline** | `Install-ClineConfig.ps1` |
| Both (+ optional VS Code install) | — | **`Install-VSCodeLocalAI.ps1`** (alias `Install-VSCodeConfig.ps1`) |

## One-shot (recommended)

```powershell
.\scripts\Install-VSCode.ps1              # if Code missing
.\scripts\Install-VSCodeLocalAI.ps1       # Continue + Cline + verify
.\scripts\Test-VSCodeSetup.ps1           # full check (extensions, Continue, Cline, MCP, local-only)
# alias: .\scripts\Test-VSCodeOllama.ps1
.\scripts\Install-VSCodeLocalAI.ps1 -CheckOnly
```

`Test-VSCodeSetup.ps1` covers: Code.exe / `code` CLI, Continue + Cline extensions, Continue + Cline → Ollama (local-only + optional smoke), VS Code User `mcp.json` Codegraph, Copilot/chat settings (warn), Ollama API.

## Continue only (chat / autocomplete)

```powershell
.\scripts\Install-ContinueConfig.ps1 -Force
.\scripts\Test-ContinueOllama.ps1
```

Writes `%USERPROFILE%\.continue\config.json` with models from `ollama list`.

## Cline only (agent)

```powershell
.\scripts\Install-ClineConfig.ps1 -Force
.\scripts\Test-ClineSetup.ps1
```

Writes (same layout as `ollama launch cline`):

- `%USERPROFILE%\.cline\data\settings\providers.json`
- `%USERPROFILE%\.cline\data\globalState.json`

`Test-ClineSetup.ps1` confirms both files, act/plan modes, model/base consistency, local-only, and smokes `/v1/chat/completions`.

Reload VS Code → open Cline → Provider **Ollama**, Context Window ≥ 32k.

## Headroom

```powershell
.\scripts\Install-Headroom.ps1              # once: C:\hr short venv (no admin)
.\scripts\Start-HeadroomOllama.ps1
.\scripts\Install-VSCodeLocalAI.ps1 -Headroom -Force
```

Avoid `pip install --user "headroom-ai[proxy]"` with Microsoft Store Python (long-path / litellm failures).

## Manual marketplace IDs

- Continue: `Continue.continue`
- Cline: `saoudrizwan.claude-dev`

## Local-only (no OpenAI / Grok / Copilot remotes)

```powershell
.\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor
.\scripts\Test-VSCodeSetup.ps1
```

Full Cursor+VS Code checklist: [local-only-ai.example.md](local-only-ai.example.md).

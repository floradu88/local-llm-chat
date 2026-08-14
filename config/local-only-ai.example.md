# Local-only AI (disable remote providers)

Block cloud/catalog models and known remote providers for **Cursor** and **VS Code** (Continue + Cline), and optionally **Ollama cloud**.

## One-shot

```powershell
# Quit Cursor first (recommended), then:
.\scripts\Disable-RemoteAIProviders.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
```

What it does:

| Surface | Action |
|---------|--------|
| Cursor Models | Disable OpenAI/Anthropic/Grok/Gemini/Composer catalog entries; keep local Ollama tags |
| Continue | Keep only local `ollama` / localhost OpenAI-compatible models; `allowAnonymousTelemetry=false`; neutralize cloud `config.yaml` |
| Cline | Force `providers.json` + act/plan modes to **ollama** only (drops Anthropic/OpenAI/OpenRouter/…) |
| VS Code + Cursor `settings.json` | Disable GitHub Copilot + built-in Chat AI features |
| Ollama | `OLLAMA_NO_CLOUD=1` + `~/.ollama/server.json` `disable_ollama_cloud` |

## Opt-outs

```powershell
.\scripts\Disable-RemoteAIProviders.ps1 -KeepRemoteModels   # leave Cursor catalog on
.\scripts\Disable-RemoteAIProviders.ps1 -KeepOllamaCloud
.\scripts\Disable-RemoteAIProviders.ps1 -SkipCursor
.\scripts\Disable-RemoteAIProviders.ps1 -SkipContinue -SkipCline
.\scripts\Disable-RemoteAIProviders.ps1 -SkipEditorSettings
```

## Verify

```powershell
.\scripts\Test-CursorOllama.ps1      # fails if Cursor remotes still on
.\scripts\Test-VSCodeSetup.ps1      # fails if Continue/Cline still have remotes
.\scripts\Test-ClineSetup.ps1       # Cline providers + globalState + smoke
# alias: .\scripts\Test-VSCodeOllama.ps1
.\scripts\Show-SetupStatus.ps1
```

## Limits

- This toggles **editor/extension config**, not a network firewall.
- Cursor may still show account UI; cloud models should be off in Models.
- Reload VS Code / Cursor after running. Restart Ollama tray for cloud disable.
- For firewall / proxy / `-AirGap` see [docs/egress-hardening.md](../docs/egress-hardening.md).

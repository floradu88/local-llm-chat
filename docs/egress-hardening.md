# Egress hardening (optional, regulated environments)

This toolkit is **local-first** but several steps still use HTTPS when not in `-AirGap` mode. Use this guide when policy requires locking down outbound traffic.

**Related:** [infosec-swot.md](infosec-swot.md), [trusted-sources.md](trusted-sources.md), `Setup-Machine.ps1 -AirGap`.

## What still needs the network (normal setup)

| Purpose | Typical hosts |
|---------|----------------|
| Ollama install script | `ollama.com` |
| Ollama model pulls | `registry.ollama.ai` (and CDN endpoints Ollama uses) |
| Cursor installer / winget | `cursor.com`, Microsoft Store/winget CDNs |
| VS Code installer / extensions | `code.visualstudio.com`, `marketplace.visualstudio.com`, Azure CDNs |
| Hugging Face / ModelScope GGUF | `huggingface.co`, `*.huggingface.co`, `modelscope.cn` |
| fnm / Codegraph | `api.github.com`, `objects.githubusercontent.com`, `registry.npmjs.org` |
| Headroom pip | `pypi.org`, `files.pythonhosted.org` |
| NVIDIA drivers (optional) | `www.nvidia.com`, `*.download.nvidia.com`, `gfwsl.geforce.com` |

Loopback stays local: `127.0.0.1:11434` (Ollama), `127.0.0.1:8787` (Headroom).

## Recommended profiles

### 1) Developer laptop (default)

- Allow user HTTPS outbound.
- Prefer `Disable-RemoteAIProviders.ps1` so editors do not target SaaS LLMs by config.
- Optional: pin installer hashes via `config/installer-pins.json` (see `installer-pins.example.json`).

### 2) Air-gap re-wire (no new downloads)

```powershell
.\scripts\Setup-Machine.ps1 -AirGap
```

Requires Ollama + models already on disk. Skips installer/model/GPU downloads. Still configures local editors when present.

### 3) Regulated / firewall allowlist

Allow **outbound HTTPS (443)** only to the hosts you actually use, for example:

```text
ollama.com
registry.ollama.ai
huggingface.co
cdn-lfs.huggingface.co
github.com
api.github.com
objects.githubusercontent.com
registry.npmjs.org
pypi.org
files.pythonhosted.org
code.visualstudio.com
marketplace.visualstudio.com
cursor.com
```

Block or do not allowlist SaaS LLM APIs if policy forbids them, for example:

```text
api.openai.com
api.anthropic.com
generativelanguage.googleapis.com
api.x.ai
*.openrouter.ai
```

**Note:** Config-level disable (`Disable-RemoteAIProviders.ps1`) is not a firewall. Pair both when compliance requires it.

## Windows Firewall sketch (admin)

Example: allow Ollama outbound HTTPS only (adjust as needed; test carefully):

```powershell
# Requires admin. Illustrative — tune RemoteAddress / program paths for your build.
New-NetFirewallRule -DisplayName "Ollama HTTPS out" -Direction Outbound -Action Allow `
  -Program "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" -Protocol TCP -RemotePort 443
```

Prefer organization MDM / proxy policies over one-off rules when available.

## Proxy environments

- Set user/system `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` as required by IT.
- Ensure `NO_PROXY` includes `127.0.0.1,localhost` so Ollama/Headroom stay direct.
- `pip` / `npm` may need their own proxy config (`pip.ini`, `.npmrc`).

## Verify local-only editors

```powershell
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
.\scripts\Test-CursorOllama.ps1
.\scripts\Test-VSCodeSetup.ps1
.\scripts\Test-ClineSetup.ps1
```

## Limits

- Marketplace extension updates and `winget` upgrades need Microsoft endpoints.
- Ollama may use additional CDN hostnames beyond `registry.ollama.ai` — capture with a proxy log if allowlisting is strict.
- Local agents (Cline / Cursor Agent / MCP) can still read/write files on the machine; egress control does not sandbox tools.

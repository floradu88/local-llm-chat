# PowerShell: install and configure Ollama (no admin)

Ollama on Windows installs **per user** by default — no Administrator rights required. Official docs: [docs.ollama.com/windows](https://docs.ollama.com/windows).

## 1. (Recommended) set model storage

Models can be tens of GB. Point them at this repo’s `models/ollama` folder (or any drive with space):

```powershell
cd D:\code\projects\local-llm-chat
.\scripts\Set-OllamaEnv.ps1 -Persistent
```

That sets a **User** environment variable `OLLAMA_MODELS` (not Machine/admin).

Manual equivalent:

```powershell
[Environment]::SetEnvironmentVariable(
  "OLLAMA_MODELS",
  "D:\code\projects\local-llm-chat\models\ollama",
  "User"
)
```

If Ollama is already running, quit the tray app and start it again (or open a **new** PowerShell) so it picks up the variable.

### Optional custom install directory

```powershell
$env:OLLAMA_INSTALL_DIR = "D:\Tools\Ollama"
# or when running the GUI installer:
# OllamaSetup.exe /DIR="D:\Tools\Ollama"
```

## 2. Install Ollama

```powershell
.\scripts\Install-Ollama.ps1
```

Or one-liner (official):

```powershell
irm https://ollama.com/install.ps1 | iex
```

Default binary location: `%LOCALAPPDATA%\Programs\Ollama` (added to your **user** PATH).

## 3. Verify

```powershell
ollama --version

# API should answer on loopback
Invoke-RestMethod http://localhost:11434/api/tags
```

Smoke chat:

```powershell
ollama run qwen2.5-coder:3b "Write a PowerShell function that reverses a string."
```

## Example coding models (copy-paste)

```powershell
ollama pull qwen2.5-coder:7b
ollama pull deepseek-coder-v2:16b
ollama pull codellama:13b
```

Primary examples for this repo (see README). Exact tags: [ollama.com/library](https://ollama.com/library).

Tier helper (optional):

```powershell
.\scripts\Pull-CodingModels.ps1 -Tier Auto
# Or a single tag:
.\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:7b
```

Already-installed tags are **skipped** (prints `Skip pull (already on disk)`). To refresh:

```powershell
.\scripts\Update-CodingModels.ps1 -Tier Auto
# or: .\scripts\Pull-CodingModels.ps1 -Tier Auto -Force
# or: .\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:7b -Force
```

Useful commands:

| Command | Purpose |
|---------|---------|
| `ollama pull <tag>` | Download / update a model |
| `ollama list` | Installed models |
| `ollama run <tag>` | Interactive chat |
| `ollama show <tag>` | Modelfile / params |
| `ollama rm <tag>` | Delete a model |
| `ollama stop <tag>` | Unload from memory |

### RAM tiers (approx)

| RAM | Pulls |
|-----|-------|
| 8–12 GB | `qwen2.5-coder:3b`, `starcoder2:3b` |
| 16 GB | `qwen2.5-coder:7b`, `starcoder2:3b` |
| 32 GB+ | `qwen2.5-coder:14b`, `codellama:13b`, larger DeepSeek-Coder-V2 tags |

## 5. Coding-tuned local alias (optional)

```powershell
.\scripts\New-CoderModelfile.ps1 -FromModel qwen2.5-coder:7b -Name coder -OutFile .\config\Modelfile.coder.generated
ollama create coder -f .\config\Modelfile.coder.generated
```

Typical parameters for code: lower temperature (`0.1`–`0.3`), larger `num_ctx` if RAM allows (`8192`–`32768`).

## 6. GPU notes

- **NVIDIA:** install current Game Ready / Studio drivers (≥ 551.61 recommended).
  - Detect / optional install: `.\scripts\Install-GpuDrivers.ps1` (add `-Install` for download + UAC).
  - Check usability: `.\scripts\Test-GpuSupport.ps1`
- **VMs:** a guest can use a GPU **only if** the hypervisor exposes one (PCIe passthrough, Hyper-V GPU-P, GRID/vGPU, or a cloud GPU VM). A VM that only has Hyper-V Video / VMware SVGA / VirtualBox graphics cannot use the host GPU; installing NVIDIA drivers in that guest will not help.
- **AMD:** ROCm v7 / HIP7 or Vulkan; see Ollama Windows troubleshooting if the wrong GPU is selected (`GGML_VK_VISIBLE_DEVICES`).
- CPU-only works; it is slower.

## 7. Where files live

| Path | Contents |
|------|----------|
| `%LOCALAPPDATA%\Programs\Ollama` | Binaries |
| `%LOCALAPPDATA%\Ollama` | Logs / updates |
| `%USERPROFILE%\.ollama` | Default models (if `OLLAMA_MODELS` unset) |
| `.\models\ollama` | Models when using this repo’s env script |

## 8. Uninstall

Settings → Apps → Ollama → Uninstall. If you set `OLLAMA_MODELS`, remove that folder yourself to reclaim disk.

## Next

- Verify: `.\scripts\Test-LocalSetup.ps1` / `.\scripts\Show-SetupStatus.ps1`
- Cursor: `.\scripts\Install-Cursor.ps1` then quit Cursor and `.\scripts\Install-CursorConfig.ps1`
- VS Code: `.\scripts\Install-ContinueConfig.ps1` (alias `Install-VSCodeConfig.ps1`)
- GPU: `.\scripts\Test-GpuSupport.ps1` / `.\scripts\Install-GpuDrivers.ps1`
- Import from Hugging Face / other sources: [install-models-from-web.md](install-models-from-web.md)
- Trusted hosts: [trusted-sources.md](trusted-sources.md)
- Editor + Headroom + Codegraph: [integrations.md](integrations.md)
- Features checklist: [FEATURES.md](../FEATURES.md)

# Install models from the web

Download coding LLMs onto disk, then register them with Ollama. Preferred sources: [trusted-sources.md](trusted-sources.md).

## Disk layout

```text
models/
  gguf/          # raw .gguf from Hugging Face / ModelScope / GitHub
  ollama/        # Ollama blob store when OLLAMA_MODELS points here
```

```powershell
.\scripts\Set-OllamaEnv.ps1 -Persistent
```

## Path A — Ollama Library (simplest)

```powershell
.\scripts\Download-FromOllama.ps1 -Model qwen2.5-coder:7b
ollama list
ollama run qwen2.5-coder:7b
```

Batch by RAM tier:

```powershell
.\scripts\Pull-CodingModels.ps1 -Tier 16GB
# Refresh / re-download even if present:
.\scripts\Pull-CodingModels.ps1 -Tier 16GB -Force
# or:
.\scripts\Update-CodingModels.ps1 -Tier Auto
```

**Skip if already on disk:** `Download-FromOllama.ps1` and `Pull-CodingModels.ps1` check Ollama manifests / API and print `Skip pull (already on disk)` instead of re-downloading. Pass `-Force` to pull again.

## Path B — Hugging Face → Ollama bridge

When a Hub repo publishes GGUF for Ollama:

```powershell
.\scripts\Download-FromOllama.ps1 -HuggingFaceRepo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" -Quant Q4_K_M
```

Ollama pulls from `hf.co/...` and registers the tag locally. No separate Modelfile needed. Same skip/`-Force` behavior as Path A.

## Path C — Hugging Face GGUF file → local import

### 1. Download

Requires [huggingface_hub](https://huggingface.co/docs/huggingface_hub) (recommended):

```powershell
pip install --user "huggingface_hub[cli]"
.\scripts\Download-FromHuggingFace.ps1 `
  -Repo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" `
  -Include "*Q4_K_M.gguf"
# Re-download: add -Force
```

Or pass a direct file URL / filename:

```powershell
.\scripts\Download-FromHuggingFace.ps1 `
  -Repo "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" `
  -File "Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
```

Gated repos:

```powershell
$env:HF_TOKEN = "hf_..."   # or -Token
.\scripts\Download-FromHuggingFace.ps1 -Repo "meta-llama/..." -Include "*.gguf"
```

If a matching `.gguf` is already under the out dir, the script **skips** (use `-Force` to fetch again).

### 2. Import into Ollama

```powershell
.\scripts\Import-GGUF.ps1 `
  -GgufPath ".\models\gguf\bartowski\Qwen2.5-Coder-7B-Instruct-GGUF\Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" `
  -Name "qwen25-coder-local" `
  -Context 8192 `
  -Temperature 0.2
```

This writes a Modelfile and runs `ollama create`. If the Ollama name already exists, import is skipped unless you pass `-Force`.

### 3. Optional coding template

```powershell
.\scripts\New-CoderModelfile.ps1 `
  -GgufPath "D:\path\to\model.Q4_K_M.gguf" `
  -Name "coder" `
  -OutFile ".\config\Modelfile.coder.generated"
ollama create coder -f .\config\Modelfile.coder.generated
```

Example Modelfile body:

```text
FROM D:/code/projects/local-llm-chat/models/gguf/.../model.Q4_K_M.gguf
PARAMETER temperature 0.2
PARAMETER num_ctx 8192
SYSTEM You are a careful coding assistant for the local-llm-chat repo. Prefer correct, minimal changes. For installing or configuring Ollama/local models on this machine, follow AGENTS.md and docs/agent-setup-playbook.md and run scripts/Setup-Machine.ps1. Use only trusted sources in docs/trusted-sources.md. Never commit model weights or tokens.
```

## Path D — ModelScope or any direct URL

1. Copy the download URL for the `.gguf` from [modelscope.cn](https://modelscope.cn) (or upstream GitHub Releases).
2. Download into this repo:

```powershell
.\scripts\Download-FromUrl.ps1 `
  -Url "https://example.com/path/model.Q4_K_M.gguf" `
  -OutDir ".\models\gguf\modelscope\my-model"
# Skips if the destination file already exists; add -Force to re-download
```

3. Import:

```powershell
.\scripts\Import-GGUF.ps1 -GgufPath ".\models\gguf\modelscope\my-model\model.Q4_K_M.gguf" -Name "my-coder"
```

Cross-check the model card against the Hugging Face original (name, license, quant).

## Path E — GitHub Releases

1. Download the `.gguf` from the **upstream** project’s Releases only (or use `Download-FromUrl.ps1`).
2. Save under `models/gguf/` → `Import-GGUF.ps1`.

## Verify

```powershell
ollama list
ollama show <your-model-name>
ollama run <your-model-name> "Explain what a PowerShell pipeline is in one sentence."
```

OpenAI-compatible API (for editors / Headroom):

```powershell
Invoke-RestMethod http://localhost:11434/api/tags
# Chat Completions-compatible base: http://localhost:11434/v1
```

## Example coding models (copy-paste)

Primary examples used across this repo:

```powershell
ollama pull qwen2.5-coder:7b
ollama pull deepseek-coder-v2:16b
ollama pull codellama:13b
```

See README **Copy-paste: three example coding models**.

## Next

Wire editors (finds installs + writes config):

```powershell
.\scripts\Install-VSCodeLocalAI.ps1    # VS Code Continue + Cline
.\scripts\Test-VSCodeSetup.ps1         # full Case H verify
.\scripts\Install-CursorConfig.ps1     # quit Cursor first
```

Also: Codegraph / Headroom — [integrations.md](integrations.md).

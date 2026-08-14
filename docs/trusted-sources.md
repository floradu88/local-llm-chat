# Trusted sources for local coding models

Use these hosts when downloading runtimes or weights. Prefer **signed / official** channels over random mirrors.

## Runtime (always first)

| Source | URL | Notes |
|--------|-----|-------|
| **Ollama** | [ollama.com](https://ollama.com), [docs.ollama.com](https://docs.ollama.com) | Installer + Library. Per-user Windows install, no admin. Use `.\scripts\Install-Ollama.ps1` (download + optional SHA pin; no `irm\|iex`). |

Do **not** install Ollama from third-party “repack” EXE sites. Optional pins: copy [installer-pins.example.json](../config/installer-pins.example.json) → `config/installer-pins.json`.

## Model catalogs (preferred order)

### 1. Ollama Library (best default)

- Site: [ollama.com/library](https://ollama.com/library)
- Command: `ollama pull <tag>` or `.\scripts\Download-FromOllama.ps1`
- Coding tags to start with: `qwen2.5-coder`, `deepseek-coder-v2`, `codellama`, `starcoder2`
- Embeddings (if a tool needs them): `nomic-embed-text`

Trust: same publisher as the runtime; tags are curated.

### 2. Hugging Face Hub

- Site: [huggingface.co](https://huggingface.co)
- Script: `.\scripts\Download-FromHuggingFace.ps1`

**Prefer these orgs / packagers:**

| Kind | Examples |
|------|----------|
| Official model orgs | `Qwen`, `deepseek-ai`, `meta-llama`, `bigcode`, `microsoft`, `google` |
| Well-known GGUF packagers | `bartowski`, `ggml-org`, `lmstudio-community` (check model card + quant) |
| Legacy GGUF (verify dates) | `TheBloke` |

**Bridge into Ollama** (when the HF repo publishes GGUF for Ollama):

```powershell
.\scripts\Download-FromOllama.ps1 -HuggingFaceRepo "org/repo" -Quant Q4_K_M
# equivalent idea: ollama pull hf.co/org/repo:Q4_K_M
```

Gated models (e.g. some Llama) need a Hugging Face account + license accept + token — pass `-Token` or set `HF_TOKEN`. Never commit tokens.

### 3. ModelScope

- Site: [modelscope.cn](https://modelscope.cn)
- Use when Hugging Face is slow or blocked.
- Script: `.\scripts\Download-FromUrl.ps1 -Url "<gguf-url>"` then `.\scripts\Import-GGUF.ps1`
- Hosts must be HTTPS and allowlisted (ModelScope / GitHub / HF CDNs). Prefer `-ExpectedSha256 <hex>` when the model card publishes a checksum.
- Cross-check the model card against the Hugging Face original (name, license, quant).

### 4. Upstream GitHub Releases

- Only from the **model author's** org (e.g. official release assets).
- Script: `.\scripts\Download-FromUrl.ps1` then `Import-GGUF.ps1`.

## Quantization (quick guide)

| Quant | Tradeoff |
|-------|----------|
| **Q4_K_M** | Good default quality / size for coding |
| Q5_K_M / Q6 | Better quality, more RAM/VRAM |
| Q8 / FP16 | Highest fidelity; needs lots of memory |

Smaller quants fit more context or weaker machines; larger quants improve answer quality.

## Do not use (for this toolkit)

- Random Google Drive / Telegram / Discord “model packs”
- Unsigned torrents with no checksums
- Unknown websites mirroring `OllamaSetup.exe`
- Weights with no license or mismatched model cards
- `irm … | iex` one-liners when a repo script exists (`Install-Ollama.ps1`)

Scripts **enforce** HTTPS host allowlists for `Download-FromUrl.ps1` and installer downloads. Pair with [egress-hardening.md](egress-hardening.md) / `Setup-Machine.ps1 -AirGap` when policy requires locked egress.

## License reminder

Before redistributing or commercial use, read each model’s license (Qwen, DeepSeek, Llama/CodeLlama, BigCode StarCoder2, etc.).

For UK/US/EU AI-regulation orientation (not legal advice), see [LEGAL.md](../LEGAL.md) and [ai-legal-and-compliance.md](ai-legal-and-compliance.md).

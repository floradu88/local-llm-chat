# Features checklist — local-llm-chat

Use this file to track what the **repo ships**, what to **check on each machine**, and **nice-to-haves**.

Legend: `[x]` done in repo / verified · `[ ]` not done yet · `(machine)` must be done on each PC

## Core (repo)

- [x] Non-admin Ollama install (`Install-Ollama.ps1`)
- [x] `OLLAMA_MODELS` / env helper (`Set-OllamaEnv.ps1`)
- [x] One-shot bootstrap (`Setup-Machine.ps1`)
- [x] Tiered coding model pulls (`Pull-CodingModels.ps1`)
- [x] Ollama Library + `hf.co` download (`Download-FromOllama.ps1`)
- [x] Hugging Face GGUF download (`Download-FromHuggingFace.ps1`)
- [x] Direct URL download — ModelScope / GitHub (`Download-FromUrl.ps1`)
- [x] GGUF → Ollama import (`Import-GGUF.ps1`)
- [x] Coding Modelfile helper (`New-CoderModelfile.ps1`)
- [x] Continue example + installer (`Install-ContinueConfig.ps1`)
- [x] Cursor checklist (`config/cursor-openai-local.example.md`)
- [x] Headroom → Ollama proxy (`Start-HeadroomOllama.ps1`)
- [x] Codegraph docs (`docs/integrations.md`)
- [x] Trusted sources doc
- [x] Agent instructions (`AGENTS.md`, Cursor/Continue rules)
- [x] First-time-after-clone cases in README (A–M)
- [x] Verify script (`Test-LocalSetup.ps1`)
- [x] Expanded `.gitignore` for weights/secrets
- [x] RAM auto-detect tier (`-Tier Auto`)
- [x] Setup status dashboard (`Show-SetupStatus.ps1`)
- [x] Model refresh / update pulls (`Update-CodingModels.ps1`)
- [x] Uninstall / cleanup helper (`Uninstall-Ollama.ps1`)
- [x] Sample prompts + eval (`config/sample-prompts.md`, `Eval-CodingModel.ps1`)

## Machine checklist (run after clone)

Mark these on each PC after setup:

- [ ] `(machine)` Ran `Setup-Machine.ps1` (or Cases A–C)
- [ ] `(machine)` `OLLAMA_MODELS` points at preferred disk (Case D optional)
- [ ] `(machine)` Coding models present (`qwen2.5-coder` / `starcoder2` / …) — not only custom tags
- [ ] `(machine)` `Test-LocalSetup.ps1` / `Show-SetupStatus.ps1` green
- [ ] `(machine)` VS Code Continue configured (Case H)
- [ ] `(machine)` Cursor base URL → Ollama (Case I)
- [ ] `(machine)` Headroom installed if desired (Case J)
- [ ] `(machine)` `codegraph init` where needed (Case K)

Quick status:

```powershell
.\scripts\Show-SetupStatus.ps1
```

## Nice-to-haves (implemented)

| Feature | Script / file | Notes |
|---------|---------------|-------|
| RAM → tier Auto | `Resolve-CodingModelTier` in `_common.ps1`; `-Tier Auto` on Setup/Pull/Update | under 12 GB → 8GB, under 24 → 16GB, else 32GB |

| Cases A–M dashboard | `Show-SetupStatus.ps1` | Green/red/yellow checks |
| Refresh model pulls | `Update-CodingModels.ps1` | Re-pulls tier set |
| Uninstall / cleanup | `Uninstall-Ollama.ps1` | Guidance + optional model folder wipe |
| Sample prompts / eval | `config/sample-prompts.md`, `Eval-CodingModel.ps1` | Short coding prompts via API |

## Still optional / not planned

- [ ] Custom VS Code extension (out of scope)
- [ ] LM Studio as primary runtime (Ollama-first)
- [ ] Bundle weights in git (never)
- [ ] Admin Windows service / NSSM
- [ ] Auto-write Cursor `settings.json` (fragile across versions)
- [ ] GPU driver installer
- [ ] Native ModelScope SDK client (URL download is enough)

## How to use

1. After clone: follow README Cases, or `.\scripts\Setup-Machine.ps1 -Tier Auto`
2. Check this file’s **Machine checklist**
3. Re-run `.\scripts\Show-SetupStatus.ps1` until core rows are green
4. Tick machine boxes above when done on that PC

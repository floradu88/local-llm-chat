# Features checklist — local-llm-chat

Use this file to track what the **repo ships**, what to **check on each machine**, and **nice-to-haves**.

Legend: `[x]` done in repo · `[ ]` not done / out of scope · `(machine)` must be done on each PC

## Core (repo) — all done

- [x] Non-admin Ollama install (`Install-Ollama.ps1`)
- [x] `OLLAMA_MODELS` / env helper (`Set-OllamaEnv.ps1`)
- [x] Full local stack bootstrap (`Setup-FullLocalStack.ps1`)
- [x] Codegraph index helper (`Initialize-Codegraph.ps1`)
- [x] One-shot bootstrap (`Setup-Machine.ps1`) — env, Ollama, Cursor install, pulls, Cursor + VS Code Local AI (Continue + Cline) → Ollama, verify
- [x] Tiered coding model pulls (`Pull-CodingModels.ps1`)
- [x] Skip re-download when model/file already on disk (`Test-OllamaModelInstalled` / `Test-LocalFilePresent`; `-Force` to refresh)
- [x] Three example coding models documented (Qwen2.5-Coder, DeepSeek-Coder-V2, CodeLlama)
- [x] Ollama Library + `hf.co` download (`Download-FromOllama.ps1`)
- [x] Hugging Face GGUF download (`Download-FromHuggingFace.ps1`)
- [x] Direct URL download — ModelScope / GitHub (`Download-FromUrl.ps1`)
- [x] GGUF → Ollama import (`Import-GGUF.ps1`) — skips if name already exists unless `-Force`
- [x] Coding Modelfile helper (`New-CoderModelfile.ps1`)
- [x] Continue / VS Code chat config (`Install-ContinueConfig.ps1`) — finds Code.exe, installs Continue, writes models from `ollama list`
- [x] Cline / VS Code agent config (`Install-ClineConfig.ps1`) — Cursor-like agent → Ollama (`~/.cline` providers + globalState)
- [x] VS Code Local AI one-shot (`Install-VSCodeLocalAI.ps1` / `Install-VSCodeConfig.ps1`) — Continue + Cline + verify
- [x] VS Code install helper (`Install-VSCode.ps1`)
- [x] VS Code Local AI full setup test (`Test-VSCodeSetup.ps1`; alias `Test-VSCodeOllama.ps1`)
- [x] Continue smoke test (`Test-ContinueOllama.ps1`)
- [x] Disable remote/cloud providers (`Disable-RemoteAIProviders.ps1`) for Cursor + Continue + Cline + Copilot/chat settings + Ollama cloud
- [x] Local-only checklist (`config/local-only-ai.example.md`)
- [x] VS Code checklist (`config/vscode-ollama-local.example.md`)
- [x] Cursor check + per-user install (`Install-Cursor.ps1`; winget or official user-setup EXE)
- [x] Cursor → Ollama Models config from PowerShell (`Install-CursorConfig.ps1`; finds install + writes `state.vscdb`; disables cloud/catalog models unless `-KeepRemoteModels`)
- [x] Cursor → Ollama integration test (`Test-CursorOllama.ps1`; config + `/v1/chat/completions` smoke)
- [x] Cursor checklist (`config/cursor-openai-local.example.md`)
- [x] Headroom → Ollama proxy (`Install-Headroom.ps1` short venv `C:\hr` + `Start-HeadroomOllama.ps1`)
- [x] Codegraph install + init (`Install-Codegraph.ps1` — **fnm preferred**, system npm fallback; Cursor + VS Code **mcp.json**; agent install; `codegraph init`; `Initialize-Codegraph.ps1`)
- [x] Codegraph MCP checklist (`config/codegraph-mcp.example.md`)
- [x] Codegraph docs (`docs/integrations.md`)
- [x] Trusted sources doc
- [x] Infosec SWOT / threat boundaries (`docs/infosec-swot.md`)
- [x] Agent instructions (`AGENTS.md`, Cursor/Continue rules)
- [x] First-time-after-clone cases in README (A–O)
- [x] Multi-model parallel + workflows (`Invoke-ParallelModels.ps1`, `Invoke-ModelWorkflow.ps1`, `docs/multi-model-workflows.md`)
- [x] Code-understanding prompt library (`docs/code-understanding-prompts.md`)
- [x] Verify script (`Test-LocalSetup.ps1`)
- [x] Expanded `.gitignore` for weights/secrets
- [x] RAM auto-detect tier (`-Tier Auto`)
- [x] Setup status dashboard (`Show-SetupStatus.ps1`) — Cursor + VS Code Local AI (H/H-cfg/H-agent, I/I-cfg, L-vscode) + GPU-DRV rows
- [x] Model refresh / update pulls (`Update-CodingModels.ps1` — always `-Force` re-pull)
- [x] Uninstall / cleanup helper (`Uninstall-Ollama.ps1`)
- [x] GPU support check non-admin + elevated (`Test-GpuSupport.ps1`) — includes VM / passthrough section
- [x] Optional NVIDIA driver install + VM GPU guidance (`Install-GpuDrivers.ps1`)
- [x] Elevated script launcher (`Invoke-Elevated.ps1`)
- [x] Admin PowerShell examples doc (`docs/powershell-admin-examples.md`)
- [x] MIT license + README credits (`LICENSE`, README License and credits)

## Nice-to-haves — all done

- [x] RAM → tier Auto (`Resolve-CodingModelTier` in `_common.ps1`)
- [x] Cases A–O status dashboard (`Show-SetupStatus.ps1`)
- [x] Refresh model pulls (`Update-CodingModels.ps1`)
- [x] Skip existing Ollama tags / GGUF files on pull/download
- [x] Uninstall / cleanup (`Uninstall-Ollama.ps1`)
- [x] GPU usable with Ollama? (`Test-GpuSupport.ps1` + `-Elevated`)
- [x] Optional GPU drivers / VM passthrough guidance (`Install-GpuDrivers.ps1`; `-InstallGpuDrivers` on setup)
- [x] Cursor present? auto-install current user (`Install-Cursor.ps1`; `-SkipCursor` / `-ForceCursor` on setup)
- [x] Cursor Models → Ollama via PowerShell (`Install-CursorConfig.ps1`; `-SkipCursorConfig` / `-ForceCursorConfig` on setup)
- [x] VS Code Local AI → Ollama via PowerShell (`Install-VSCodeLocalAI.ps1`; Continue + Cline; `-SkipContinueConfig` / `-SkipClineConfig` / `-ForceContinueConfig` on setup)
- [x] Elevate any script (`Invoke-Elevated.ps1`)
- [x] Admin examples Patterns A/B/C (`docs/powershell-admin-examples.md`)
- [x] Sample coding eval prompts
- [x] Multi-model parallel fan-out (`Invoke-ParallelModels.ps1`)
- [x] Multi-model sequential workflows (`Invoke-ModelWorkflow.ps1`)
- [x] Multi-model docs (`docs/multi-model-workflows.md`)
- [x] Code map/understand prompts (`docs/code-understanding-prompts.md`)

## Machine checklist (per PC — not automatic)

Mark these on each machine after you run setup:

- [ ] `(machine)` Ran `Setup-Machine.ps1` (or Cases A–C)
- [ ] `(machine)` Pulled the three example models (or tier set) — re-runs skip if already on disk
- [ ] `(machine)` `OLLAMA_MODELS` points at preferred disk (Case D optional)
- [ ] `(machine)` `Test-LocalSetup.ps1` / `Show-SetupStatus.ps1` green
- [ ] `(machine)` VS Code Local AI configured (`Test-VSCodeSetup.ps1` / Case H — Continue chat + Cline agent; alias `Test-VSCodeOllama.ps1`)
- [ ] `(machine)` Cursor installed (`Install-Cursor.ps1 -CheckOnly`) + Models → Ollama (`Test-CursorOllama.ps1`; Case I)
- [ ] `(machine)` Remotes disabled (`Disable-RemoteAIProviders.ps1 -CheckOnly`)
- [ ] `(machine)` Headroom installed if desired (`Install-Headroom.ps1` / Case J — short venv `C:\hr`)
- [ ] `(machine)` Codegraph CLI + index + MCP (`Install-Codegraph.ps1 -CheckOnly -ProjectPath <repo>`; Case K; fnm preferred)
- [ ] `(machine)` GPU check run (`Test-GpuSupport.ps1`; `-Elevated` optional)
- [ ] `(machine)` GPU drivers if needed (`Install-GpuDrivers.ps1`; VM needs passthrough first)

```powershell
.\scripts\Show-SetupStatus.ps1
.\scripts\Install-Cursor.ps1 -CheckOnly
.\scripts\Test-CursorOllama.ps1
.\scripts\Test-VSCodeSetup.ps1
# alias: .\scripts\Test-VSCodeOllama.ps1
.\scripts\Disable-RemoteAIProviders.ps1 -CheckOnly
.\scripts\Install-Codegraph.ps1 -CheckOnly
.\scripts\Install-Headroom.ps1 -CheckOnly
.\scripts\Test-GpuSupport.ps1
.\scripts\Install-GpuDrivers.ps1
```

## Out of scope (intentionally not built)

- [ ] Custom VS Code extension
- [ ] LM Studio as primary runtime (Ollama-first)
- [ ] Bundle weights in git (never)
- [ ] Admin Windows service / NSSM
- [ ] Native ModelScope SDK client (URL download is enough)
- [ ] Hypervisor GPU passthrough setup (document only; host-side config is out of scope)

## How to use

1. After clone: README Cases, or `.\scripts\Setup-Machine.ps1 -Tier Auto` (Cursor install + Cursor/VS Code Ollama config unless skipped)
2. Optional: `-InstallGpuDrivers` / three example models from README / Case J Headroom (`Install-Headroom.ps1`)
3. `.\scripts\Show-SetupStatus.ps1` until core rows are green (including H/H-cfg/H-agent, I/I-cfg, L-vscode; J when using Headroom)
4. Tick **Machine checklist** items on that PC

# Continue / local chat — this workspace

When the user asks to set up local models or this project on a machine:

1. Read `AGENTS.md`, `FEATURES.md`, `README.md` (Cases A–O), and `docs/agent-setup-playbook.md`.
2. Run `.\scripts\Setup-Machine.ps1 -Tier <8GB|16GB|32GB|Auto>` from the repo root (tier from their RAM). That:
   - checks/installs Cursor unless `-SkipCursor`
   - wires Cursor Models → Ollama unless `-SkipCursorConfig` (quit Cursor if it is open)
   - wires VS Code Continue → Ollama unless `-SkipContinueConfig` (`Install-ContinueConfig.ps1` / `Install-VSCodeConfig.ps1`)
3. Verify with `.\scripts\Test-LocalSetup.ps1` and `.\scripts\Show-SetupStatus.ps1` (look for green H/H-cfg and I/I-cfg).
4. If editors were skipped or failed: `.\scripts\Install-ContinueConfig.ps1` and/or quit Cursor then `.\scripts\Install-CursorConfig.ps1`. See `docs/integrations.md`.
5. Optional GPU: `.\scripts\Test-GpuSupport.ps1` / `.\scripts\Install-GpuDrivers.ps1`.
6. Optional Codegraph: `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` (fnm → npm → agent install → init).

Pulls and GGUF downloads skip files/tags already on disk; use `-Force` or `Update-CodingModels.ps1` to refresh.

Use only sources listed in `docs/trusted-sources.md`. Do not commit `.gguf` files or tokens.

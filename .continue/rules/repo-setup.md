# Continue / local chat — this workspace

When the user asks to set up local models or this project on a machine:

1. Read `AGENTS.md`, `FEATURES.md`, `README.md` (Cases A–O), and `docs/agent-setup-playbook.md`.
2. Run `.\scripts\Setup-Machine.ps1 -Tier <8GB|16GB|32GB|Auto>` from the repo root (tier from their RAM). That also checks/installs Cursor for the current user unless `-SkipCursor`.
3. Verify with `.\scripts\Test-LocalSetup.ps1` and `.\scripts\Show-SetupStatus.ps1`.
4. Point Continue/Cursor at Ollama: `.\scripts\Install-ContinueConfig.ps1` and/or `.\scripts\Install-Cursor.ps1` + `docs/integrations.md`.
5. Optional GPU: `.\scripts\Test-GpuSupport.ps1` / `.\scripts\Install-GpuDrivers.ps1`.

Pulls and GGUF downloads skip files/tags already on disk; use `-Force` or `Update-CodingModels.ps1` to refresh.

Use only sources listed in `docs/trusted-sources.md`. Do not commit `.gguf` files or tokens.

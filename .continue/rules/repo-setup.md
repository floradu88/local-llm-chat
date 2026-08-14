# Continue / local chat — this workspace

When the user asks to set up local models or this project on a machine:

1. Read `AGENTS.md`, `FEATURES.md`, `README.md` (Cases A–O), and `docs/agent-setup-playbook.md`.
2. Run `.\scripts\Setup-Machine.ps1 -Tier <8GB|16GB|32GB|Auto>` from the repo root (tier from their RAM). That:
   - checks/installs Cursor unless `-SkipCursor`
   - wires Cursor Models → Ollama unless `-SkipCursorConfig` (quit Cursor if it is open)
   - wires VS Code Local AI (Continue chat + Cline agent) unless `-SkipContinueConfig` (`Install-VSCodeLocalAI.ps1`)
3. Verify with `.\scripts\Test-LocalSetup.ps1`, `.\scripts\Show-SetupStatus.ps1`, `.\scripts\Test-VSCodeSetup.ps1` (alias `Test-VSCodeOllama.ps1`), and `.\scripts\Test-CursorOllama.ps1` (look for green H/H-cfg/H-agent, I/I-cfg, L-vscode).
4. If editors were skipped or failed: `.\scripts\Install-VSCodeLocalAI.ps1 -Force` and/or quit Cursor then `.\scripts\Install-CursorConfig.ps1`. See `docs/integrations.md`.
5. Local-only remotes: `.\scripts\Disable-RemoteAIProviders.ps1` (quit Cursor first). Checklist: `config/local-only-ai.example.md`.
6. Optional GPU: `.\scripts\Test-GpuSupport.ps1` / `.\scripts\Install-GpuDrivers.ps1`.
7. Optional Headroom: `.\scripts\Install-Headroom.ps1` then `.\scripts\Start-HeadroomOllama.ps1` (short venv `C:\hr`; avoid `pip --user` with Store Python).
8. Optional Codegraph: `.\scripts\Install-Codegraph.ps1 -ProjectPath <repo>` (fnm preferred; updates Cursor + VS Code mcp.json; system npm only if fnm fails).

Pulls and GGUF downloads skip files/tags already on disk; use `-Force` or `Update-CodingModels.ps1` to refresh.

Use only sources listed in `docs/trusted-sources.md`. Do not commit `.gguf` files or tokens.

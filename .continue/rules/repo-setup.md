# Continue / local chat — this workspace

When the user asks to set up local models or this project on a machine:

1. Read `AGENTS.md`, `README.md` (Cases A-M), and `docs/agent-setup-playbook.md`.
2. Run `.\scripts\Setup-Machine.ps1 -Tier <8GB|16GB|32GB>` from the repo root (tier from their RAM).
3. Verify with `.\scripts\Test-LocalSetup.ps1`.
4. Point Continue/Cursor at Ollama: `.\scripts\Install-ContinueConfig.ps1` and/or `docs/integrations.md`.

Use only sources listed in `docs/trusted-sources.md`. Do not commit `.gguf` files or tokens.

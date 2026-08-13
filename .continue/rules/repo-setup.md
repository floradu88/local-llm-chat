# Continue / local chat — this workspace

When the user asks to set up local models or this project on a machine:

1. Read `AGENTS.md` and `docs/agent-setup-playbook.md`.
2. Run `.\scripts\Setup-Machine.ps1 -Tier <8GB|16GB|32GB>` from the repo root (tier from their RAM).
3. Verify with `ollama list` and `http://localhost:11434/api/tags`.
4. Point Continue/Cursor at Ollama per `docs/integrations.md`.

Use only sources listed in `docs/trusted-sources.md`. Do not commit `.gguf` files or tokens.

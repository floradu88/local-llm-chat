# Codegraph MCP JSON (Cursor + VS Code)

`Install-Codegraph.ps1` merges a **codegraph** MCP server into both editors (unless `-SkipMcpJson`):

| Editor | File | Top-level key |
|--------|------|----------------|
| Cursor | `%USERPROFILE%\.cursor\mcp.json` | `mcpServers` |
| VS Code | `%APPDATA%\Code\User\mcp.json` | `servers` |

## Launch command (fnm preferred)

Global configs prefer a stable fnm Node + npm shim so MCP works when the GUI app has no shell `PATH`:

```text
command: %APPDATA%\fnm\aliases\default\node.exe
args:    [ npm-shim.js, serve, --mcp, --path, ${workspaceFolder} ]
```

Fallback: `%APPDATA%\npm\codegraph.cmd`, then bare `codegraph` on PATH.

## Apply / verify

```powershell
.\scripts\Install-Codegraph.ps1 -ProjectPath .
.\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath .
# also write portable workspace files:
# .\scripts\Install-Codegraph.ps1 -WriteWorkspaceMcp -ProjectPath .
```

Workspace files (optional `-WriteWorkspaceMcp`):

- `.cursor/mcp.json` — Cursor project MCP (`mcpServers`, portable `codegraph` command)
- `.vscode/mcp.json` — VS Code project MCP (`servers`, portable `codegraph` command)

Restart Cursor and VS Code after updating MCP JSON.

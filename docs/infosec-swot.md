# Infosec analysis & SWOT — local-llm-chat

**Scope:** This repository (PowerShell install/config toolkit for local Ollama + editor wiring on Windows).  
**Not in scope:** Hardening of Ollama/Cursor/VS Code/Continue/Cline/Headroom upstream binaries themselves (vendor risk), or enterprise MDM policy design.  
**Date:** 2026-08-14 · **Stance:** local-first, prefer no admin, config-level remote disable (not a network firewall).

---

## 1. What this repo is (security lens)

`local-llm-chat` is a **bootstrap and configuration toolkit**. It does not ship model weights or a custom AI runtime. It:

| Does | Security implication |
|------|----------------------|
| Downloads installers / CLIs (Ollama, Cursor, VS Code, fnm, NVIDIA drivers, pip/npm packages) | **Supply-chain** trust in HTTPS origins |
| Pulls or imports GGUF / Ollama tags | **Integrity / provenance** of weights |
| Writes user editor state (`state.vscdb`, Continue/Cline configs, `settings.json`, MCP JSON) | **Integrity of IDE AI routing** |
| Optionally elevates (GPU drivers, Codegraph permissions helper) | **Privilege escalation surface** (UAC-gated) |
| Starts local proxies (Headroom → Ollama) | **Local network / process** exposure |
| Encourages agent tools (Cline, Cursor Agent, Codegraph MCP) | **Prompt-injection → tool abuse** if remotes or weak models |

---

## 2. Trust boundaries (architecture)

```mermaid
flowchart TB
  subgraph External["External trust domains"]
    OLL["ollama.com / Library"]
    HF["Hugging Face / ModelScope / GitHub Releases"]
    CUR["cursor.com"]
    VSC["code.visualstudio.com"]
    GH["GitHub releases (fnm)"]
    NV["NVIDIA driver CDN"]
    PY["PyPI (headroom-ai / litellm)"]
    NPM["npm (@colbymchenry/codegraph)"]
  end

  subgraph Host["Windows user session"]
    PS["PowerShell scripts\n(this repo)"]
    OLLA["Ollama :11434\n(loopback)"]
    HR["Headroom :8787\n(optional)"]
    ED["Cursor / VS Code\n+ Continue / Cline"]
    MCP["MCP: Codegraph\n(node + local DB)"]
    DISK["models/ · C:\\hr · AppData configs"]
  end

  subgraph Cloud["Cloud AI (intended off)"]
    REM["OpenAI / Anthropic / Grok /\nCopilot / Cursor catalog"]
  end

  External -->|HTTPS download / pull| PS
  PS -->|install / configure| OLLA
  PS -->|Install-Headroom| HR
  PS -->|state.vscdb / mcp.json / settings| ED
  PS -->|npm / mcp.json| MCP
  ED -->|prompts / tools| OLLA
  ED -.->|via Headroom| HR
  HR --> OLLA
  ED -.->|Disable-RemoteAIProviders\nblocks by config| REM
  PS --> DISK
  OLLA --> DISK
```

**Primary trust assumption:** the human operator runs scripts from a clone they control, and outbound HTTPS to documented vendors is acceptable.

---

## 3. Attack surface map

```mermaid
flowchart LR
  subgraph High["Higher impact if abused"]
    A1["irm \| iex\nInstall-Ollama.ps1"]
    A2["Invoke-Elevated.ps1\n+ ExecutionPolicy Bypass"]
    A3["Cursor state.vscdb write"]
    A4["MCP / Cline agent tools"]
    A5["Download-FromUrl.ps1\n(any URL)"]
  end

  subgraph Med["Medium"]
    B1["pip install headroom\n(large dep tree)"]
    B2["npm i -g codegraph"]
    B3["Installer EXE download\n(Cursor/VS Code/NVIDIA)"]
    B4["HF_TOKEN / env secrets"]
  end

  subgraph Low["Lower / mitigated by design"]
    C1["Local-only config scripts"]
    C2[".gitignore weights/tokens"]
    C3["trusted-sources.md guidance"]
    C4["Per-user installs (no admin default)"]
  end
```

### Notable script behaviors

| Control / behavior | Location | Risk note |
|--------------------|----------|-----------|
| `irm https://ollama.com/install.ps1 \| iex` | `Install-Ollama.ps1` | Classic **remote code execution as user** if CDN/site compromised or TLS MITM with broken trust store |
| Arbitrary URL download, no checksum | `Download-FromUrl.ps1` | Operator can fetch malicious GGUF/binary; no allowlist beyond docs |
| UAC elevate + `-ExecutionPolicy Bypass` | `Invoke-Elevated.ps1` | Correct for drivers; dangerous if caller passes a **tampered** script path |
| Mutates Cursor SQLite state | `Install-CursorConfig.ps1` / `_Set-CursorOllamaState.cjs` | Can redirect model traffic; backups exist for some files, not a full DB restore story |
| Writes global MCP JSON | `Install-Codegraph.ps1` / `_common.ps1` | Spawns Node + Codegraph under editor; expands agent capability |
| Config-only remote disable | `Disable-RemoteAIProviders.ps1` | **Not** a firewall; extensions/UI can still be re-enabled; network egress remains possible |
| Loopback API checks | tests / smoke scripts | Good default; does not prove Ollama is bound only to localhost forever |

---

## 4. SWOT

### Strengths

- **Local-first product intent:** Ollama + optional `OLLAMA_NO_CLOUD`, Headroom on loopback, editors pointed at `127.0.0.1` / `localhost`.
- **Explicit remote-disable path:** `Disable-RemoteAIProviders.ps1` + checklists (`config/local-only-ai.example.md`) + tests (`Test-CursorOllama`, `Test-VSCodeSetup`).
- **Trusted-source doctrine:** `docs/trusted-sources.md` steers away from Drive/Telegram/unsigned mirrors; AGENTS/rules reinforce “no random weights.”
- **Secret / weight hygiene in git:** `.gitignore` covers `.gguf`, tokens, `.env`, `.codegraph/`, local tool state.
- **Least privilege by default:** per-user Ollama/Cursor/VS Code/fnm/Headroom (`C:\hr`); admin only for GPU drivers / optional elevated helpers.
- **Config backups** before several Continue/settings mutations (`local-llm-chat-backups`).
- **Operational verify scripts:** status dashboard and smoke tests reduce “silently still on cloud” misconfiguration.
- **Short-path Headroom venv:** avoids broken Store-Python installs that push users toward unsafe workarounds.

### Weaknesses

- **Supply-chain soft spots:** `irm | iex` for Ollama; installer downloads without **pinned hashes**; PyPI/npm transitive deps (Headroom/litellm/transformers, Codegraph) are large and mutable.
- **`Download-FromUrl.ps1` trust is entirely human:** no scheme/host allowlist, no SHA-256 verify, no size/type policy beyond “save file.”
- **Remote disable is soft control:** settings/state toggles, not host firewall, AppLocker, or egress proxy; Cursor account UI and future product changes can drift.
- **High-capability local agents:** Cline/Cursor Agent + MCP can read/write files and run commands — **prompt injection** against a coding model is an infosec issue even when “local.”
- **Privileged helpers are generic:** `Invoke-Elevated.ps1` will elevate whatever `-ScriptPath` you pass (no path allowlist to `scripts\` only).
- **No formal threat model / SBOM / signed releases** for this toolkit’s own scripts (integrity depends on git remote trust).
- **Token handling is documented, not enforced:** `HF_TOKEN` / `-Token` paths rely on operator discipline (gitignore helps if files are named conventionally).

### Opportunities

- Pin **SHA-256** (or authenticode) for Ollama/Cursor/VS Code/fnm/NVIDIA artifacts; fail closed on mismatch.
- Replace or wrap `irm | iex` with download-to-disk → hash check → `powershell -File`.
- Add **URL allowlist** + optional checksum params to `Download-FromUrl.ps1` / HF downloads.
- Document and optionally script **Windows Firewall** rules: allow outbound only to needed hosts; block editor egress except loopback when “air-gapped mode” is selected.
- Add an **infosec / air-gap profile** script: local-only + no URL download + no pip/npm unless already present.
- Path-constrain `Invoke-Elevated.ps1` to repo `scripts\` (and known elevated helpers).
- Publish a short **operator runbook**: what data leaves the machine (telemetry toggles, model cards, MCP), what stays local.
- Integrity note for GGUF: prefer HF `resolve` URLs with commit SHA; record checksums next to imports.

### Threats

```mermaid
flowchart TB
  T1["Compromised vendor CDN\nor malicious release"] --> I1["User-level malware\nvia installer / iex"]
  T2["Malicious or trojaned\nGGUF / ollama tag"] --> I2["Untrusted model behavior\n+ prompt injection"]
  T3["PyPI / npm package\ncompromise"] --> I3["Headroom / Codegraph\nruntime backdoor"]
  T4["Operator re-enables\ncloud models"] --> I4["Source code / prompts\nexfil to SaaS"]
  T5["Tampered local scripts\n+ UAC approve"] --> I5["Elevated installers\n/ driver path abuse"]
  T6["MCP / agent tool abuse\nvia crafted repo content"] --> I6["Local file / shell\nimpact under user"]

  I2 --> I6
  I4 --> Data["Confidentiality loss"]
  I1 --> Data
  I3 --> Data
  I5 --> Integrity["System integrity loss"]
  I6 --> Integrity
```

| Threat | Likelihood (typical laptop) | Impact | Notes |
|--------|----------------------------|--------|-------|
| Accidental cloud re-enable / Copilot | Medium | High (IP leakage) | Soft controls only |
| Bad GGUF from non-trusted URL | Medium if users ignore docs | Medium–High | No checksum gate |
| Vendor installer compromise | Low | High | Shared industry risk |
| Prompt injection → Cline tools | Medium in agentic use | Medium–High | Local ≠ safe |
| Privilege abuse via elevated helper | Low (needs UAC) | High | Path not constrained |
| Secrets committed | Low (gitignore) | High | Naming bypasses possible |

---

## 5. Control coverage vs common goals

| Goal | Current coverage | Gap |
|------|------------------|-----|
| Keep coding prompts/code off SaaS LLMs | Strong *intent* + config scripts + tests | Not enforceable against determined user or product updates |
| Avoid untrusted model mirrors | Documented | Not enforced in `Download-FromUrl` |
| Minimize admin | Strong default | GPU path still elevates |
| Protect secrets in git | Strong `.gitignore` | No pre-commit secret scanner in-repo |
| Supply-chain for runtimes | Official HTTPS URLs | No pin/verify |
| Local API exposure | Scripts assume loopback | No continuous bind-address audit |
| Agent tool safety | Out of band (user judgment) | No deny-list / sandbox for Cline |

---

## 6. Recommended hardening backlog (priority)

1. **P0 — Document operator threat model** (this file) and link from README — **done**.
2. **P1 — Hash-verify installers**; stop raw `irm | iex` where practical — **done** (`Save-RemoteFile` / `Invoke-VerifiedRemoteScript`; `Install-Ollama.ps1` downloads then `-File`; Cursor/VS Code/fnm use allowlist + SHA print/optional pin via `config/installer-pins.example.json`).
3. **P1 — Allowlist + checksum** on `Download-FromUrl.ps1` — pending.
4. **P2 — Constrain `Invoke-Elevated.ps1`** to `scripts\*.ps1` under the repo root — pending.
5. **P2 — Optional “air-gap” switch** on setup — pending.
6. **P3 — Egress guidance** (firewall / proxy) for regulated environments — pending.
7. **P3 — Dependabot/renovate or lockfiles** — pending.

---

## 7. Residual risk statement

For a **developer workstation** that already trusts Microsoft Store / vendor HTTPS and runs IDE agents, this toolkit **improves** confidentiality posture versus default cloud Copilot/Cursor catalog use, provided operators follow `trusted-sources.md` and keep `Disable-RemoteAIProviders` green.

It does **not** provide:

- Guaranteed air-gapping  
- Malware-resistant supply chain  
- Protection against malicious or jailbroken *local* models with tool access  
- Compliance certification (SOC2, FedRAMP, etc.)

Treat **local agentic coding** as still “code execution under the interactive user,” with models as an untrusted input channel.

---

## 8. Related docs

| Doc | Role |
|-----|------|
| [trusted-sources.md](trusted-sources.md) | Allowed download origins |
| [local-only-ai.example.md](../config/local-only-ai.example.md) | Remote-disable checklist |
| [integrations.md](integrations.md) | Editor / Headroom / Codegraph wiring |
| [powershell-admin-examples.md](powershell-admin-examples.md) | When UAC is actually needed |
| [AGENTS.md](../AGENTS.md) | Agent rules: no secrets/weights in git |

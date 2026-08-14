# Prompts for mapping and understanding code (local models)

Use these with **Ollama** (Continue / Cursor / `ollama run`) and, when available, **Codegraph** tools first so the model sees structure instead of whole-file dumps.

Keep prompts **short and scoped**. Local models work better with one job per message.

Example models: `qwen2.5-coder:7b`, `deepseek-coder-v2:16b`, `codellama:13b`.

---

## Before you prompt (faster context)

```powershell
# Install + index (fnm preferred; system npm only if fnm fails)
.\scripts\Install-Codegraph.ps1 -ProjectPath .

# Optional: ask the agent to use Codegraph MCP tools first
# (callers / callees / explore), then answer with the local model.
```

In Cursor/Continue, attach only the **active file** or a **small selection**, or paste Codegraph tool output — not the entire repo.

---

## 1) Map the codebase (orientation)

**Entry points**

```text
Using only the files/context I provided (and Codegraph if available): list the main entry points of this project (CLI, HTTP routes, main(), app bootstrap). For each, give file path + one-line role. Do not invent files.
```

**Folder map**

```text
Summarize what each top-level directory is for in 1 short bullet each. Flag anything that looks like generated or vendor code. Be concise.
```

**Dependency sketch**

```text
From this context, sketch a dependency map: which modules call which. Use "A -> B" lines only. Mark uncertain edges with "?".
```

---

## 2) Understand one symbol / feature

**Explain symbol**

```text
Explain what SYMBOL_NAME does, where it is defined, and what calls it. Prefer call-graph facts over guessing. Output:
1) purpose (2 sentences)
2) inputs/outputs
3) important callees
4) risks / side effects
```

**Trace a flow**

```text
Trace the runtime path for: USER_ACTION_OR_FEATURE.
List steps as numbered file:function hops. Stop when you hit I/O or an external API. If unknown, say UNKNOWN.
```

**Data shape**

```text
For TYPE_OR_DTO_NAME, list fields and where they are populated or consumed. Table: field | set in | read in.
```

---

## 3) Faster reading of a file you pasted

**Skeleton first**

```text
Do not rewrite the file. Produce a skeleton outline:
- exports / public API
- main types
- side-effecting functions
- dead or suspicious code (if any)
Max 15 bullets.
```

**Contract**

```text
Extract the public contract of this file: function signatures + one-line behavior each. Ignore private helpers unless they are critical.
```

**Complexity hotspots**

```text
Identify the 3 hardest-to-follow parts of this code. For each: why it's hard, and one clarifying rename or extract that would help. No full rewrite.
```

---

## 4) Change-impact (before you edit)

```text
I want to change: SHORT_CHANGE_DESCRIPTION.
Using Codegraph/callers if available: what else must be updated? List files/symbols that would break. Separate Must-change vs Maybe-related.
```

```text
Find all usages of SYMBOL_NAME (or nearest equivalents). Group by: tests, production, scripts. If you cannot search, say what to search for.
```

---

## 5) Debug with a local model

```text
Bug: SHORT_SYMPTOM.
Given this stack/log/code, list the top 3 likely root causes with file:function suspects. Then the single best next check to confirm.
```

```text
Here is a failing test / error message:
ERROR_TEXT
Map it to the responsible code path in 5 steps or fewer.
```

---

## 6) Pair with Codegraph (agent instructions)

Paste this as a system/user preamble when the agent has Codegraph MCP:

```text
For codebase questions: use Codegraph tools first (explore/search/callers/callees/impact) before reading many files. Summarize graph facts, then answer. Prefer precise symbol names. Do not dump large files into context.
```

Example user ask:

```text
How does authentication reach the database in this repo? Use Codegraph to find the path, then explain in plain language with file references.
```

---

## 7) Multi-model workflows (optional)

Use a small/fast model to **map**, a stronger model to **deep-dive**:

```powershell
# Map / outline with a lighter or default coder
.\scripts\Invoke-ModelWorkflow.ps1 `
  -Workflow PlanImplement `
  -Task "Map entry points and auth flow; then outline where to add logging" `
  -PlanModel "qwen2.5-coder:7b" `
  -ImplementModel "codellama:13b"
```

Or parallel compare of “what does this module do?”:

```powershell
.\scripts\Invoke-ParallelModels.ps1 `
  -Prompt "From the following code, list responsibilities in <=8 bullets. CODE: ..." `
  -Models @("qwen2.5-coder:7b", "codellama:13b")
```

See [multi-model-workflows.md](multi-model-workflows.md).

---

## Prompt tips for local models

| Do | Don't |
|----|--------|
| One question, one scope | "Explain the whole repo" |
| Ask for bullets / tables | Long essays |
| "Do not invent files" | Assume missing context is true |
| Paste Codegraph results | Paste 20 files at once |
| Name the symbol exactly | Vague "the login stuff" |

Replace placeholders like `SYMBOL_NAME`, `USER_ACTION_OR_FEATURE`, `SHORT_CHANGE_DESCRIPTION` before sending.

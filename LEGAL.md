# AI usage, law & compliance (UK / US / EU)

> **Not legal advice.** This document is a practical orientation for operators of **local-llm-chat**. Laws change; facts matter (who you are, what you automate, whose data you process). For business-critical or regulated use, ask a qualified lawyer in your jurisdiction.

**Short answer:** Using this toolkit to run **open coding models locally** for your own development work is **not, by itself, illegal** under current UK, US, or EU rules. Compliance risk comes mainly from **how you use** the models (data, decisions, outputs, model licences)—not from installing Ollama or wiring editors.

| Audience | Typical takeaway |
|----------|------------------|
| Individual developer on a personal PC | Low regulatory AI-Act “provider” exposure; still respect **model licences**, **copyright** of code/docs you paste, and **employer** policies |
| Company using this for internal coding | Treat as an **AI system you deploy**; check **GDPR/UK GDPR**, sector rules, and whether any use is **high-risk** under the EU AI Act |
| Someone redistributing models or offering AI-as-a-service | Different story — **provider** / commercial rules may apply; this repo does **not** ship weights |

**Detailed notes:** [docs/ai-legal-and-compliance.md](docs/ai-legal-and-compliance.md)  
**Related:** [docs/trusted-sources.md](docs/trusted-sources.md) · [docs/infosec-swot.md](docs/infosec-swot.md) · [docs/egress-hardening.md](docs/egress-hardening.md) · [LICENSE](LICENSE) (MIT for **this repo’s scripts/docs only**)

## What this repo is (legally relevant)

- MIT-licensed **scripts and docs** to install/configure **Ollama** and editors on Windows.
- **Does not** redistribute model weights (`.gguf` / blobs are gitignored).
- Models come from **third parties** (Ollama Library, Hugging Face, etc.) under **their** terms.
- Optional **local-only** wiring (`Disable-RemoteAIProviders.ps1`) reduces sending prompts to cloud SaaS—but is **not** a legal shield by itself.

## What usually *does* create legal risk

1. **Ignoring a model’s licence** (e.g. Llama / Qwen / CodeLlama terms, geographic or commercial limits).
2. **Pasting confidential / personal data** into prompts or agent tools without a lawful basis (GDPR / UK GDPR / employer confidentiality).
3. Using AI for **regulated decisions** (hiring, credit, biometric ID, etc.) without the right regime—may be **high-risk** or restricted under the **EU AI Act**.
4. **Publishing** model outputs that infringe others’ copyright, or claiming pure AI text as human-authored where that matters.
5. **Export / sanctions** controls if you move certain software or models across restricted borders (rare for typical coding tags; check your model card).

## Practical checklist (operators)

- [ ] Read each pulled model’s **licence / model card** before commercial or redistribution use.
- [ ] Prefer **local** inference for sensitive code; use `-AirGap` / local-only scripts when policy forbids cloud AI.
- [ ] Do not commit secrets or client data; see `.gitignore` and [infosec-swot.md](docs/infosec-swot.md).
- [ ] If you are an EU/UK organisation: document the tool as part of your **AI / DPIA** inventory when it processes personal data.
- [ ] Agents (Cline / Cursor Agent) can **edit files and run commands**—same duty of care as giving a junior engineer access.

## Official starting points

| Region | Starting points |
|--------|-----------------|
| **EU** | [AI Act overview](https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai) · [GPAI Q&A](https://digital-strategy.ec.europa.eu/en/faqs/general-purpose-ai-models-ai-act-questions-answers) · GDPR |
| **UK** | [AI regulation research briefing](https://commonslibrary.parliament.uk/research-briefings/cbp-10003/) · [ICO guidance on AI & data protection](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/artificial-intelligence/) · UK GDPR / DPA 2018 |
| **US** | Sectoral + state rules (no single federal “AI ban”); [Copyright Office AI materials](https://www.copyright.gov/ai/); FTC / agency guidance for unfair practices; **model licence** terms |

Last reviewed for this repo: **2026-08-14**. Re-check before relying on it for compliance decisions.

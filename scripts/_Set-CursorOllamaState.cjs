#!/usr/bin/env node
/**
 * Read/write Cursor applicationUser persistent storage in state.vscdb.
 * Invoked by Install-CursorConfig.ps1 via Cursor's bundled Node (node:sqlite).
 *
 * Usage:
 *   node _Set-CursorOllamaState.cjs status --db <path>
 *   node _Set-CursorOllamaState.cjs apply --db <path> --base-url <url> --api-key <key> --models <csv> [--set-default] [--force] [--disable-remote]
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { DatabaseSync } = require("node:sqlite");

const APP_USER_KEY =
  "src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser";
const OPENAI_KEY_STORAGE = "cursorAuth/openAIKey";

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        out[key] = true;
      } else {
        out[key] = next;
        i++;
      }
    } else {
      out._.push(a);
    }
  }
  return out;
}

function openDb(dbPath) {
  if (!fs.existsSync(dbPath)) {
    throw new Error(`state.vscdb not found: ${dbPath}`);
  }
  return new DatabaseSync(dbPath);
}

function readAppUser(db) {
  const row = db.prepare("SELECT value FROM ItemTable WHERE key = ?").get(APP_USER_KEY);
  if (!row || row.value == null) {
    return {};
  }
  const raw = Buffer.isBuffer(row.value) ? row.value.toString("utf8") : String(row.value);
  return JSON.parse(raw);
}

function writeAppUser(db, data) {
  const json = JSON.stringify(data);
  const existing = db.prepare("SELECT key FROM ItemTable WHERE key = ?").get(APP_USER_KEY);
  if (existing) {
    db.prepare("UPDATE ItemTable SET value = ? WHERE key = ?").run(json, APP_USER_KEY);
  } else {
    db.prepare("INSERT INTO ItemTable (key, value) VALUES (?, ?)").run(APP_USER_KEY, json);
  }
}

function readOpenAIKeyPresent(db) {
  const row = db.prepare("SELECT length(value) AS len FROM ItemTable WHERE key = ?").get(OPENAI_KEY_STORAGE);
  return !!(row && row.len > 0);
}

function writeOpenAIKey(db, apiKey) {
  const existing = db.prepare("SELECT key FROM ItemTable WHERE key = ?").get(OPENAI_KEY_STORAGE);
  if (existing) {
    db.prepare("UPDATE ItemTable SET value = ? WHERE key = ?").run(apiKey, OPENAI_KEY_STORAGE);
  } else {
    db.prepare("INSERT INTO ItemTable (key, value) VALUES (?, ?)").run(OPENAI_KEY_STORAGE, apiKey);
  }
}

function normalizeBaseUrl(url) {
  return String(url || "").trim().replace(/\/+$/, "");
}

function ensureAiSettings(data) {
  if (!data.aiSettings || typeof data.aiSettings !== "object") {
    data.aiSettings = {};
  }
  if (!Array.isArray(data.aiSettings.modelOverrideEnabled)) {
    data.aiSettings.modelOverrideEnabled = [];
  }
  if (!Array.isArray(data.aiSettings.modelOverrideDisabled)) {
    data.aiSettings.modelOverrideDisabled = [];
  }
  if (!Array.isArray(data.aiSettings.userAddedModels)) {
    data.aiSettings.userAddedModels = [];
  }
  if (!data.aiSettings.modelConfig || typeof data.aiSettings.modelConfig !== "object") {
    data.aiSettings.modelConfig = {};
  }
  return data.aiSettings;
}

function catalogModelNames(data) {
  const names = new Set();
  const catalog = Array.isArray(data.availableDefaultModels2) ? data.availableDefaultModels2 : [];
  for (const m of catalog) {
    if (m && m.name) names.add(String(m.name));
  }
  // Common cloud / routed ids even if catalog not loaded yet
  for (const extra of [
    "default",
    "composer-2",
    "composer-2-fast",
    "composer-2.5",
    "gpt-5",
    "gpt-5.1",
    "gpt-5.2",
    "gpt-5.3-codex",
    "gpt-5.4",
    "gpt-5.5",
    "gpt-5.6-sol",
    "gpt-5.6-terra",
    "gpt-5.6-luna",
    "claude-4-sonnet",
    "claude-4.5-sonnet",
    "claude-4.6-sonnet",
    "claude-opus-4",
    "claude-opus-4.5",
    "claude-opus-4.6",
    "claude-opus-5",
    "claude-sonnet-4",
    "claude-sonnet-4-5",
    "claude-sonnet-4-6",
    "grok-4.5",
    "grok-4.6",
    "grok-code",
    "gemini-2.5-pro",
    "gemini-3.1-pro",
    "gemini-3.6-flash",
    "o3",
    "o4-mini",
    "chatgpt-4o",
    "gpt-4o",
    "gpt-4.1",
    "claude-3.5-sonnet",
    "claude-3.7-sonnet",
    "cursor-small",
    "cursor-fast",
  ]) {
    names.add(extra);
  }
  return names;
}

function disableRemoteModels(data, localModels) {
  const ai = ensureAiSettings(data);
  const local = new Set(localModels.map(String));
  const catalog = catalogModelNames(data);

  // Enable only local Ollama tags (custom / user-added)
  ai.modelOverrideEnabled = Array.from(local);
  ai.userAddedModels = Array.from(local);

  // Disable every catalog / cloud model not in the local set
  const disabled = new Set();
  for (const name of catalog) {
    if (!local.has(name)) disabled.add(name);
  }
  // Keep previously disabled items that are still not local
  for (const name of ai.modelOverrideDisabled || []) {
    if (!local.has(String(name))) disabled.add(String(name));
  }
  ai.modelOverrideDisabled = Array.from(disabled);

  // BYOK / OpenAI-override model list + local provider ids
  data.availableAPIKeyModels = Array.from(local);
  data.localProviderModelIds = Array.from(local);
  data.localProviderAgentModelIds = Array.from(local);

  return {
    enabled: ai.modelOverrideEnabled,
    disabledCount: ai.modelOverrideDisabled.length,
  };
}

function status(dbPath) {
  const db = openDb(dbPath);
  try {
    const data = readAppUser(db);
    const base = data.openAIBaseUrl == null ? null : normalizeBaseUrl(data.openAIBaseUrl);
    const enabled = (data.aiSettings && data.aiSettings.modelOverrideEnabled) || [];
    const disabled = (data.aiSettings && data.aiSettings.modelOverrideDisabled) || [];
    const catalog = catalogModelNames(data);
    // A catalog model is "remote still on" if it is not in modelOverrideDisabled
    // (defaultOn models show unless disabled). Count disabled intersection with catalog.
    const catalogDisabled = [...catalog].filter((n) => disabled.includes(n));
    const result = {
      ok: true,
      dbPath,
      openAIBaseUrl: base,
      useOpenAIKey: !!data.useOpenAIKey,
      apiKeyPresent: readOpenAIKeyPresent(db),
      modelOverrideEnabled: enabled,
      modelOverrideDisabledCount: disabled.length,
      catalogDisabledCount: catalogDisabled.length,
      remoteModelsDisabled: catalogDisabled.length >= Math.max(5, Math.floor(catalog.size * 0.5)),
      configuredForOllama:
        !!data.useOpenAIKey &&
        !!base &&
        (base.includes("11434") || base.includes("8787")),
    };
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  } finally {
    db.close();
  }
}

function apply(args) {
  const dbPath = args["db"];
  const baseUrl = normalizeBaseUrl(args["base-url"]);
  const apiKey = String(args["api-key"] || "ollama").trim();
  const modelsCsv = String(args["models"] || "").trim();
  const models = modelsCsv
    ? modelsCsv.split(",").map((m) => m.trim()).filter(Boolean)
    : [];
  const setDefault = !!args["set-default"];
  const force = !!args["force"];
  const disableRemote = !!args["disable-remote"];
  const backupDir = args["backup-dir"] || null;

  if (!dbPath) throw new Error("--db required");
  if (!baseUrl) throw new Error("--base-url required");

  const db = openDb(dbPath);
  try {
    const before = readAppUser(db);
    const prevBase = before.openAIBaseUrl == null ? null : normalizeBaseUrl(before.openAIBaseUrl);
    if (
      prevBase &&
      prevBase !== baseUrl &&
      !force &&
      !prevBase.includes("11434") &&
      !prevBase.includes("8787")
    ) {
      const err = {
        ok: false,
        error: `Existing openAIBaseUrl is ${prevBase}. Re-run with --force to replace.`,
        openAIBaseUrl: prevBase,
      };
      process.stdout.write(JSON.stringify(err, null, 2) + "\n");
      process.exitCode = 2;
      return;
    }

    if (backupDir) {
      fs.mkdirSync(backupDir, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, "-");
      const backupFile = path.join(backupDir, `applicationUser-${stamp}.json`);
      fs.writeFileSync(backupFile, JSON.stringify(before, null, 2), "utf8");
    }

    const data = { ...before };
    data.openAIBaseUrl = baseUrl;
    data.useOpenAIKey = true;

    const ai = ensureAiSettings(data);
    let remoteInfo = null;

    if (disableRemote) {
      remoteInfo = disableRemoteModels(data, models);
    } else {
      const enabled = new Set(ai.modelOverrideEnabled.map(String));
      for (const m of models) enabled.add(m);
      ai.modelOverrideDisabled = (ai.modelOverrideDisabled || []).filter((m) => !enabled.has(String(m)));
      ai.modelOverrideEnabled = Array.from(enabled);
      const added = new Set((ai.userAddedModels || []).map(String));
      for (const m of models) added.add(m);
      ai.userAddedModels = Array.from(added);
    }

    // Prefer local default whenever we disable remote, or when asked
    if ((setDefault || disableRemote) && models.length > 0) {
      const primary = models[0];
      const slots = ["composer", "cmd-k", "plan-execution", "quick-agent", "background-composer", "spec", "deep-search"];
      for (const slot of slots) {
        const cur = ai.modelConfig[slot] && typeof ai.modelConfig[slot] === "object" ? ai.modelConfig[slot] : {};
        ai.modelConfig[slot] = {
          ...cur,
          modelName: primary,
          maxMode: false,
          selectedModels: [{ modelId: primary, parameters: [] }],
        };
      }
    }

    db.exec("BEGIN");
    writeAppUser(db, data);
    if (apiKey) writeOpenAIKey(db, apiKey);
    db.exec("COMMIT");

    const result = {
      ok: true,
      dbPath,
      openAIBaseUrl: baseUrl,
      useOpenAIKey: true,
      apiKeyWritten: !!apiKey,
      modelsEnabled: models,
      modelOverrideEnabled: ai.modelOverrideEnabled,
      remoteModelsDisabled: !!disableRemote,
      remoteDisabledCount: remoteInfo ? remoteInfo.disabledCount : null,
      setDefault: (setDefault || disableRemote) && models.length > 0 ? models[0] : null,
    };
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  } catch (e) {
    try {
      db.exec("ROLLBACK");
    } catch (_) {}
    throw e;
  } finally {
    db.close();
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0] || "status";
  if (cmd === "status") {
    if (!args.db) throw new Error("--db required");
    status(args.db);
    return;
  }
  if (cmd === "apply") {
    apply(args);
    return;
  }
  throw new Error(`Unknown command: ${cmd}`);
}

try {
  main();
} catch (e) {
  process.stderr.write(String(e && e.stack ? e.stack : e) + "\n");
  process.exit(1);
}

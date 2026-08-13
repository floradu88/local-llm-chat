<#
.SYNOPSIS
  Find installed Cursor and wire Models → local Ollama (OpenAI-compatible).

.DESCRIPTION
  Locates Cursor.exe / user data under %APPDATA%\Cursor, then writes:
    - openAIBaseUrl  (default http://localhost:11434/v1)
    - useOpenAIKey   = true
    - cursorAuth/openAIKey (placeholder "ollama"; Ollama ignores it)
    - aiSettings.modelOverrideEnabled += installed Ollama tags

  Updates Cursor's state.vscdb via the bundled Node helper (node:sqlite).
  Quit Cursor before applying (or pass -Force while it is running — may be overwritten).

.PARAMETER BaseUrl
  OpenAI-compatible base URL. Default: http://localhost:11434/v1

.PARAMETER ApiKey
  Value stored as Cursor's OpenAI API key. Default: ollama

.PARAMETER Models
  Model tags to enable in Cursor. Default: tags from ollama list / on-disk manifests
  (falls back to the three README examples if none found).

.PARAMETER Headroom
  Shortcut: BaseUrl = http://127.0.0.1:8787/v1 (requires Start-HeadroomOllama.ps1).

.PARAMETER SetAsDefault
  Set Composer / Cmd-K / plan / quick-agent selection to the first model.

.PARAMETER Force
  Replace a non-Ollama existing openAIBaseUrl; allow apply while Cursor is running.

.PARAMETER CheckOnly
  Print install path + current Ollama wiring status; exit 0 if configured, 1 otherwise.

.PARAMETER SkipApiKey
  Do not write cursorAuth/openAIKey (only base URL + model list).
#>
[CmdletBinding()]
param(
  [string] $BaseUrl = "http://localhost:11434/v1",
  [string] $ApiKey = "ollama",
  [string[]] $Models = @(),
  [switch] $Headroom,
  [switch] $SetAsDefault,
  [switch] $Force,
  [switch] $CheckOnly,
  [switch] $SkipApiKey
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

if ($Headroom) {
  $BaseUrl = "http://127.0.0.1:8787/v1"
}

$info = Get-CursorInstallInfo
Write-Section "Cursor install"
Write-Host ("  Installed:  {0}" -f $info.Installed)
Write-Host ("  Scope:      {0}" -f $info.Scope)
if ($info.ExePath) { Write-Host ("  Exe:        {0}" -f $info.ExePath) }
if ($info.CmdPath) { Write-Host ("  CLI:        {0}" -f $info.CmdPath) }
Write-Host ("  User data:  {0}" -f $info.UserDataPath)
Write-Host ("  State DB:   {0}" -f $info.StateDbPath)
if ($info.NodeHelperPath) { Write-Host ("  Node:       {0}" -f $info.NodeHelperPath) }

if (-not $info.Installed) {
  Write-Warning "Cursor not found. Install first: .\scripts\Install-Cursor.ps1"
  exit 1
}

$status = Get-CursorOllamaConfigStatus
Write-Section "Current Models config"
Write-Host ("  Configured: {0}" -f $status.Configured)
Write-Host ("  Base URL:   {0}" -f $(if ($status.OpenAIBaseUrl) { $status.OpenAIBaseUrl } else { "(none)" }))
Write-Host ("  Use key:    {0}" -f $status.UseOpenAIKey)
Write-Host ("  Key stored: {0}" -f $status.ApiKeyPresent)
if ($status.ModelOverrideEnabled.Count -gt 0) {
  Write-Host ("  Enabled:    {0}" -f ($status.ModelOverrideEnabled -join ", "))
}
if (-not $status.Ok -and $status.Message) {
  Write-Host ("  Note:       {0}" -f $status.Message)
}

if ($CheckOnly) {
  if ($status.Configured) {
    Write-Host "  CheckOnly: Ollama/OpenAI override looks configured"
    exit 0
  }
  Write-Host "  CheckOnly: not configured - re-run without -CheckOnly"
  exit 1
}

if (-not (Test-Path -LiteralPath $info.StateDbPath)) {
  throw "Missing $($info.StateDbPath). Launch Cursor once so it creates user data, quit Cursor, then re-run this script."
}
if (-not $info.NodeHelperPath) {
  throw "Cursor bundled node.exe not found under the install. Re-install Cursor or configure Models manually (config\cursor-openai-local.example.md)."
}

$running = Test-CursorProcessRunning
if ($running -and -not $Force) {
  Write-Warning "Cursor.exe is running. Quit Cursor completely, then re-run this script (state.vscdb must not be locked/overwritten)."
  Write-Host "Or pass -Force to write anyway (Cursor may overwrite on exit)."
  exit 1
}
if ($running -and $Force) {
  Write-Warning "Cursor is running and -Force was set; writing state.vscdb anyway."
}

# Resolve models
$modelList = @($Models | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
if ($modelList.Count -eq 0) {
  try {
    $modelList = @(Get-OllamaInstalledModelNames | Where-Object {
      $_ -notmatch "embed|nomic-embed"
    })
  } catch { }
}
if ($modelList.Count -eq 0) {
  $modelList = @("qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:13b")
  Write-Warning "No local Ollama tags found; enabling README example names (pull them if missing)."
}

Write-Section "Apply"
Write-Host ("  Target URL: {0}" -f $BaseUrl)
Write-Host ("  API key:    {0}" -f $(if ($SkipApiKey) { "(skipped)" } else { $ApiKey }))
Write-Host ("  Models:     {0}" -f ($modelList -join ", "))

$helper = Join-Path $PSScriptRoot "_Set-CursorOllamaState.cjs"
$backupDir = Join-Path $info.UserDataPath "User\globalStorage\local-llm-chat-backups"
$keyArg = if ($SkipApiKey) { "" } else { $ApiKey }

$argList = @(
  $helper,
  "apply",
  "--db", $info.StateDbPath,
  "--base-url", $BaseUrl,
  "--api-key", $keyArg,
  "--models", ($modelList -join ","),
  "--backup-dir", $backupDir
)
if ($SetAsDefault) { $argList += "--set-default" }
if ($Force) { $argList += "--force" }

$prevEa = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $raw = & $info.NodeHelperPath --no-warnings @argList 2>&1
  $exit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $prevEa
}
$text = (($raw | ForEach-Object { "$_" }) -join "`n").Trim()
if ($exit -ne 0) {
  Write-Host $text
  throw "Failed to update Cursor state.vscdb (exit $exit)"
}

try {
  $result = $text | ConvertFrom-Json
} catch {
  Write-Host $text
  throw "Helper returned non-JSON output"
}

if (-not $result.ok) {
  Write-Warning $result.error
  exit 2
}

Write-Host "  Wrote openAIBaseUrl + useOpenAIKey (+ API key unless skipped)"
Write-Host ("  Enabled models: {0}" -f ($result.modelOverrideEnabled -join ", "))
if ($result.setDefault) {
  Write-Host ("  Default model:  {0}" -f $result.setDefault)
}
Write-Host ("  Backup JSON:    {0}" -f $backupDir)

Write-Section "Done"
Write-Host "Restart Cursor, then open Settings > Models and confirm:"
Write-Host ("  Base URL: {0}" -f $BaseUrl)
Write-Host ("  API key:  {0}" -f $(if ($SkipApiKey) { "(unchanged)" } else { $ApiKey }))
Write-Host "  Pick an enabled Ollama tag in the model picker."
Write-Host "Verify Ollama: Invoke-RestMethod http://localhost:11434/api/tags"
exit 0

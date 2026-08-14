<#
.SYNOPSIS
  Install Codegraph via fnm (preferred) + Node, wire agents, then init a project graph.

.DESCRIPTION
  Ordered Windows flow matching this toolkit:

  1) Prefer fnm (Fast Node Manager) for Node/npm - install fnm if needed (no admin)
     Fall back to system node/npm ONLY if fnm fails (unless -RequireFnm)
  2) npm i -g @colbymchenry/codegraph (using the preferred Node from step 1)
  3) codegraph install --yes --no-permissions   (wire MCP first without agent auto-allow)
  4) codegraph install --yes                    (second pass WITH agent permissions)
     Optional: -Elevated runs step 4 via UAC (Invoke-Elevated.ps1)
  5) Update MCP JSON for Cursor (~/.cursor/mcp.json) and VS Code (%APPDATA%\Code\User\mcp.json)
     Prefer fnm default node.exe + npm-shim so GUI editors work without shell PATH
  6) codegraph init in -ProjectPath if .codegraph is missing (or -ForceInit)

.PARAMETER ProjectPath
  Repo to index (default: this toolkit repo). Skips init when .codegraph already exists unless -ForceInit.

.PARAMETER NodeVersion
  Node version for fnm (default: lts-latest).

.PARAMETER Target
  codegraph install --target value (default: cursor). Use auto|all|cursor,claude|...

.PARAMETER SkipFnm
  Use system Node/npm only (do not try fnm). Not recommended.

.PARAMETER RequireFnm
  Fail if fnm cannot provide Node (do not fall back to system npm).

.PARAMETER SkipAgentInstall
  Skip both codegraph install passes (CLI + init only).

.PARAMETER SkipMcpJson
  Do not write/merge ~/.cursor/mcp.json and VS Code User/mcp.json.

.PARAMETER WriteWorkspaceMcp
  Also write portable .cursor/mcp.json and .vscode/mcp.json under -ProjectPath.

.PARAMETER SkipPermissionsPass
  Only run the --no-permissions install pass (skip the second permissions pass).

.PARAMETER Elevated
  Run the permissions install pass elevated (UAC). Rarely required; MCP writes are normally per-user.

.PARAMETER ForceInit
  Re-run codegraph init even when .codegraph already exists.

.PARAMETER CheckOnly
  Report fnm/node/codegraph/.codegraph status; exit 0 if CLI present and project indexed.
#>
[CmdletBinding()]
param(
  [string] $ProjectPath = "",
  [string] $NodeVersion = "lts-latest",
  [string] $Target = "cursor",
  [switch] $SkipFnm,
  [switch] $RequireFnm,
  [switch] $SkipAgentInstall,
  [switch] $SkipMcpJson,
  [switch] $WriteWorkspaceMcp,
  [switch] $SkipPermissionsPass,
  [switch] $Elevated,
  [switch] $ForceInit,
  [switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

function Write-Section([string] $Title) {
  Write-Host ""
  Write-Host "=== $Title ==="
}

function Ensure-CodegraphCli {
  # Always refresh fnm env so npm/codegraph resolve from preferred runtime
  [void](Initialize-FnmEnv)

  $cg = Get-Command codegraph -ErrorAction SilentlyContinue
  if ($cg) {
    Write-Host ("  codegraph already on PATH: {0}" -f $cg.Source)
    return
  }

  $runtime = Get-NodeRuntimeInfo
  Write-Host ("  Using npm from: {0} ({1})" -f $runtime.Source, $runtime.NpmPath)
  Write-Host "  npm i -g @colbymchenry/codegraph"
  & npm i -g @colbymchenry/codegraph
  if ($LASTEXITCODE -ne 0) { throw "npm global install failed (exit $LASTEXITCODE)" }

  # npm global bin (user) + fnm env again
  try {
    $npmRoot = & npm root -g
    $npmBin = Split-Path -Parent $npmRoot
    if ($npmBin -and (Test-Path $npmBin) -and ($env:Path -notlike "*$npmBin*")) {
      $env:Path = "$npmBin;$env:Path"
    }
  } catch { }
  $roamingNpm = Join-Path $env:APPDATA "npm"
  if ((Test-Path $roamingNpm) -and ($env:Path -notlike "*$roamingNpm*")) {
    $env:Path = "$roamingNpm;$env:Path"
  }
  [void](Initialize-FnmEnv)

  if (-not (Get-Command codegraph -ErrorAction SilentlyContinue)) {
    throw "codegraph still not on PATH after npm install. Open a new shell and re-run."
  }
  Write-Host ("  codegraph: {0}" -f ((Get-Command codegraph).Source))
}

function Invoke-CodegraphAgentInstall {
  param(
    [string] $Target,
    [switch] $NoPermissions
  )
  [void](Initialize-FnmEnv)
  $args = @("install", "--yes", "--target=$Target", "--location=global")
  if ($NoPermissions) { $args += "--no-permissions" }
  Write-Host ("  codegraph {0}" -f ($args -join " "))
  & codegraph @args
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "codegraph install exited $LASTEXITCODE (continue; check agent MCP config)"
  }
}

$RepoRoot = Get-RepoRoot
if (-not $ProjectPath) { $ProjectPath = $RepoRoot }
if (-not (Test-Path -LiteralPath $ProjectPath)) {
  throw "ProjectPath not found: $ProjectPath"
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$graphDir = Join-Path $ProjectPath ".codegraph"

Add-FnmCommonPaths
[void](Initialize-FnmEnv)
$runtime = Get-NodeRuntimeInfo

Write-Section "Codegraph status"
Write-Host ("  Project:    {0}" -f $ProjectPath)
Write-Host ("  .codegraph: {0}" -f (Test-Path -LiteralPath $graphDir))
Write-Host ("  fnm:        {0}" -f $(if ($runtime.FnmPresent) { $runtime.FnmPath } else { "(missing)" }))
Write-Host ("  node:       {0}" -f $(if ($runtime.NodePresent) { "{0} ({1})" -f $runtime.NodeVersion, $runtime.Source } else { "(missing)" }))
Write-Host ("  node path:  {0}" -f $(if ($runtime.NodePath) { $runtime.NodePath } else { "(none)" }))
Write-Host ("  codegraph:  {0}" -f $(if (Get-Command codegraph -EA SilentlyContinue) { (Get-Command codegraph).Source } else { "(missing)" }))
$mcpStatus = Get-CodegraphMcpJsonStatus
Write-Host ("  Cursor MCP: {0} ({1})" -f $(if ($mcpStatus.CursorHas) { "OK" } else { "missing codegraph" }), $mcpStatus.CursorPath)
Write-Host ("  VS Code MCP:{0} ({1})" -f $(if ($mcpStatus.VSCodeHas) { "OK" } else { "missing codegraph" }), $mcpStatus.VSCodePath)
Write-Host ("  MCP launch: {0}" -f $mcpStatus.LaunchMode)

if ($CheckOnly) {
  $okCli = [bool](Get-Command codegraph -ErrorAction SilentlyContinue)
  $okGraph = Test-Path -LiteralPath $graphDir
  $okMcp = $mcpStatus.CursorHas -and $mcpStatus.VSCodeHas
  if ($runtime.NodePresent -and -not $runtime.FromFnm -and $runtime.FnmPresent) {
    Write-Host "  Note: fnm is installed but active node is system - re-run without -CheckOnly to prefer fnm"
  }
  if ($okCli -and $okGraph -and $okMcp) {
    Write-Host ("  CheckOnly: codegraph CLI + index + Cursor/VS Code MCP OK (node via {0})" -f $runtime.Source)
    exit 0
  }
  Write-Host "  CheckOnly: incomplete (cli=$okCli graph=$okGraph cursorMcp=$($mcpStatus.CursorHas) vscodeMcp=$($mcpStatus.VSCodeHas)) - re-run without -CheckOnly"
  exit 1
}

# --- 1) Node runtime: fnm preferred, system npm only if fnm fails ---
Write-Section "1/5 Node runtime (fnm preferred)"
$runtime = Ensure-NodeRuntimePreferFnm -Version $NodeVersion -SkipFnm:$SkipFnm -RequireFnm:$RequireFnm
Write-Host ("  Active Node source: {0}" -f $runtime.Source)

# --- 2) CLI package ---
Write-Section "2/5 npm global @colbymchenry/codegraph"
Ensure-CodegraphCli

# --- 3) Agent wire: no-permissions then permissions ---
if (-not $SkipAgentInstall) {
  Write-Section "3/5 codegraph install (agents)"
  Write-Host "  Pass A: --no-permissions (MCP wire without agent auto-allow)"
  Invoke-CodegraphAgentInstall -Target $Target -NoPermissions

  if (-not $SkipPermissionsPass) {
    Write-Host "  Pass B: with agent permissions"
    if ($Elevated) {
      $elevHelper = Join-Path $PSScriptRoot "_Codegraph-InstallPermissions.Elevated.ps1"
      & (Join-Path $PSScriptRoot "Invoke-Elevated.ps1") -ScriptPath $elevHelper -ArgumentList @("-Target", $Target)
    } else {
      Invoke-CodegraphAgentInstall -Target $Target
    }
  } else {
    Write-Host "  SkipPermissionsPass set - left agents without auto-allow list"
  }
} else {
  Write-Section "3/5 SkipAgentInstall"
}

# --- 4) MCP JSON for Cursor + VS Code ---
if (-not $SkipMcpJson) {
  Write-Section "4/5 MCP JSON (Cursor + VS Code)"
  $mcpArgs = @{ ProjectPath = $ProjectPath }
  if ($WriteWorkspaceMcp) { $mcpArgs["WriteWorkspaceFiles"] = $true }
  $mcp = Update-CodegraphMcpJsonFiles @mcpArgs
  Write-Host ("  Launch mode: {0}" -f $mcp.LaunchMode)
  Write-Host ("  Command:     {0}" -f $mcp.Command)
  Write-Host ("  Cursor:      {0}" -f $mcp.CursorPath)
  Write-Host ("  VS Code:     {0}" -f $mcp.VSCodePath)
  foreach ($w in @($mcp.Workspace)) {
    Write-Host ("  Workspace:   {0}" -f $w)
  }
} else {
  Write-Section "4/5 SkipMcpJson"
}

# --- 5) init project if needed ---
Write-Section "5/5 codegraph init"
[void](Initialize-FnmEnv)
if ((Test-Path -LiteralPath $graphDir) -and -not $ForceInit) {
  Write-Host "  .codegraph already exists - skip init (pass -ForceInit to rebuild)"
} else {
  if (-not (Get-Command codegraph -ErrorAction SilentlyContinue)) {
    throw "codegraph CLI missing; cannot init"
  }
  Push-Location $ProjectPath
  try {
    Write-Host ("  Running: codegraph init  ({0})" -f $ProjectPath)
    & codegraph init
    if ($LASTEXITCODE -ne 0) {
      throw "codegraph init failed with exit $LASTEXITCODE"
    }
    Write-Host ("  OK - graph at {0}" -f $graphDir)
  } finally {
    Pop-Location
  }
}

Write-Section "Done"
Write-Host ("Node used via: {0}" -f (Get-NodeRuntimeInfo).Source)
$finalMcp = Get-CodegraphMcpJsonStatus
Write-Host ("Cursor MCP codegraph: {0}" -f $finalMcp.CursorHas)
Write-Host ("VS Code MCP codegraph: {0}" -f $finalMcp.VSCodeHas)
Write-Host "Restart Cursor and VS Code so MCP reloads."
Write-Host "Index another app: .\scripts\Install-Codegraph.ps1 -ProjectPath D:\path\to\app"
Write-Host ("Status:           .\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath {0}" -f $ProjectPath)
exit 0

<#
.SYNOPSIS
  Install Codegraph via fnm + Node (no admin), wire agents, then init a project graph.

.DESCRIPTION
  Ordered Windows flow matching this toolkit:

  1) Ensure fnm (Fast Node Manager) - per-user, no admin when possible
  2) Ensure Node LTS through fnm; npm i -g @colbymchenry/codegraph
  3) codegraph install --yes --no-permissions   (wire MCP first without agent auto-allow)
  4) codegraph install --yes                    (second pass WITH agent permissions)
     Optional: -Elevated runs step 4 via UAC (Invoke-Elevated.ps1)
  5) codegraph init in -ProjectPath if .codegraph is missing (or -ForceInit)

.PARAMETER ProjectPath
  Repo to index (default: this toolkit repo). Skips init when .codegraph already exists unless -ForceInit.

.PARAMETER NodeVersion
  Node version for fnm (default: lts-latest).

.PARAMETER Target
  codegraph install --target value (default: cursor). Use auto|all|cursor,claude|...

.PARAMETER SkipFnm
  Assume Node/npm already usable; skip fnm install/use.

.PARAMETER SkipAgentInstall
  Skip both codegraph install passes (CLI + init only).

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
  [switch] $SkipAgentInstall,
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

function Initialize-FnmEnv {
  $fnm = Get-Command fnm -ErrorAction SilentlyContinue
  if (-not $fnm) { return $false }
  try {
    $envOut = & fnm env --shell power-shell 2>$null
    if ($envOut) {
      $envOut | Out-String | Invoke-Expression
    }
  } catch {
    try {
      (& fnm env) | Out-String | Invoke-Expression
    } catch { }
  }
  return [bool](Get-Command node -ErrorAction SilentlyContinue)
}

function Install-FnmIfMissing {
  if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Write-Host "  fnm already on PATH"
    return
  }

  Write-Host "  Installing fnm (per-user, no admin)..."
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      & winget install --id Schniz.fnm -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --scope user
    } finally {
      $ErrorActionPreference = $prev
    }
    # Refresh common winget shim path
    $shim = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
    if ((Test-Path $shim) -and ($env:Path -notlike "*$shim*")) {
      $env:Path = "$shim;$env:Path"
    }
  }

  if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    # Portable zip into LocalAppData
    $fnmRoot = Join-Path $env:LOCALAPPDATA "fnm"
    New-Item -ItemType Directory -Force -Path $fnmRoot | Out-Null
    $api = "https://api.github.com/repos/Schniz/fnm/releases/latest"
    Write-Host "  Resolving fnm release from GitHub..."
    $rel = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "local-llm-chat" }
    $asset = @($rel.assets) | Where-Object { $_.name -match "fnm-windows\.zip$|windows.*\.zip$" } | Select-Object -First 1
    if (-not $asset) {
      throw "Could not find fnm Windows zip on GitHub releases. Install manually: winget install Schniz.fnm"
    }
    $zip = Join-Path $env:TEMP "fnm-windows.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $fnmRoot -Force
    $exe = Get-ChildItem -Path $fnmRoot -Recurse -Filter "fnm.exe" | Select-Object -First 1
    if (-not $exe) { throw "fnm.exe missing after extract" }
    if ($env:Path -notlike "*$($exe.DirectoryName)*") {
      $env:Path = "$($exe.DirectoryName);$env:Path"
    }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$($exe.DirectoryName)*") {
      [Environment]::SetEnvironmentVariable("Path", "$($exe.DirectoryName);$userPath", "User")
    }
  }

  if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    throw "fnm still not on PATH. Open a new shell or install from https://github.com/Schniz/fnm"
  }
  Write-Host "  fnm OK: $((Get-Command fnm).Source)"
}

function Ensure-NodeViaFnm {
  param([string] $Version)

  Write-Host ("  Ensuring Node ({0}) via fnm..." -f $Version)
  & fnm install $Version
  if ($LASTEXITCODE -ne 0) { throw "fnm install $Version failed (exit $LASTEXITCODE)" }
  & fnm use $Version
  & fnm default $Version
  [void](Initialize-FnmEnv)

  $node = Get-Command node -ErrorAction SilentlyContinue
  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $node -or -not $npm) {
    throw "node/npm not available after fnm use. Open a new PowerShell and re-run."
  }
  Write-Host ("  node: {0}" -f (& node -v))
  Write-Host ("  npm:  {0}" -f (& npm -v))
}

function Ensure-CodegraphCli {
  $cg = Get-Command codegraph -ErrorAction SilentlyContinue
  if ($cg) {
    Write-Host ("  codegraph already on PATH: {0}" -f $cg.Source)
    return
  }
  Write-Host "  npm i -g @colbymchenry/codegraph"
  & npm i -g @colbymchenry/codegraph
  if ($LASTEXITCODE -ne 0) { throw "npm global install failed (exit $LASTEXITCODE)" }

  # npm global bin (user)
  $npmRoot = & npm root -g
  $npmBin = Split-Path -Parent $npmRoot
  if ($npmBin -and (Test-Path $npmBin) -and ($env:Path -notlike "*$npmBin*")) {
    $env:Path = "$npmBin;$env:Path"
  }
  $roamingNpm = Join-Path $env:APPDATA "npm"
  if ((Test-Path $roamingNpm) -and ($env:Path -notlike "*$roamingNpm*")) {
    $env:Path = "$roamingNpm;$env:Path"
  }

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

Write-Section "Codegraph status"
Write-Host ("  Project:    {0}" -f $ProjectPath)
Write-Host ("  .codegraph: {0}" -f (Test-Path -LiteralPath $graphDir))
Write-Host ("  fnm:        {0}" -f $(if (Get-Command fnm -EA SilentlyContinue) { (Get-Command fnm).Source } else { "(missing)" }))
Write-Host ("  node:       {0}" -f $(if (Get-Command node -EA SilentlyContinue) { & node -v } else { "(missing)" }))
Write-Host ("  codegraph:  {0}" -f $(if (Get-Command codegraph -EA SilentlyContinue) { (Get-Command codegraph).Source } else { "(missing)" }))

if ($CheckOnly) {
  $okCli = [bool](Get-Command codegraph -ErrorAction SilentlyContinue)
  $okGraph = Test-Path -LiteralPath $graphDir
  if ($okCli -and $okGraph) {
    Write-Host "  CheckOnly: codegraph CLI + project index OK"
    exit 0
  }
  Write-Host "  CheckOnly: incomplete (cli=$okCli graph=$okGraph) - re-run without -CheckOnly"
  exit 1
}

# --- 1) fnm + Node (no admin) ---
if (-not $SkipFnm) {
  Write-Section "1/4 fnm + Node (no admin)"
  Install-FnmIfMissing
  [void](Initialize-FnmEnv)
  Ensure-NodeViaFnm -Version $NodeVersion
} else {
  Write-Section "1/4 SkipFnm"
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "-SkipFnm set but npm not on PATH"
  }
}

# --- 2) CLI package ---
Write-Section "2/4 npm global @colbymchenry/codegraph"
Ensure-CodegraphCli

# --- 3) Agent wire: no-permissions then permissions ---
if (-not $SkipAgentInstall) {
  Write-Section "3/4 codegraph install (agents)"
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
  Write-Section "3/4 SkipAgentInstall"
}

# --- 4) init project if needed ---
Write-Section "4/4 codegraph init"
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
Write-Host "Restart Cursor (or your agent) so Codegraph MCP reloads."
Write-Host "Index another app: .\scripts\Install-Codegraph.ps1 -ProjectPath D:\path\to\app"
Write-Host ("Status:           .\scripts\Install-Codegraph.ps1 -CheckOnly -ProjectPath {0}" -f $ProjectPath)
exit 0

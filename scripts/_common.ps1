# Shared helpers for local-llm-chat scripts (dot-source from other scripts).
# Usage: . (Join-Path $PSScriptRoot "_common.ps1")

function Get-RepoRoot {
  Split-Path -Parent $PSScriptRoot
}

function Add-OllamaToSessionPath {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Ollama"),
    $env:OLLAMA_INSTALL_DIR
  ) | Where-Object { $_ -and (Test-Path $_) }

  foreach ($dir in $candidates) {
    if ($env:Path -notlike "*$dir*") {
      $env:Path = "$dir;$env:Path"
    }
  }
}

function Test-OllamaCommand {
  Add-OllamaToSessionPath
  return [bool](Get-Command ollama -ErrorAction SilentlyContinue)
}

function Test-OllamaApi {
  param([int] $TimeoutSec = 3)
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec $TimeoutSec | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Get-OllamaModelsRoots {
  $roots = @()
  foreach ($candidate in @(
      $env:OLLAMA_MODELS,
      (Join-Path (Split-Path -Parent $PSScriptRoot) "models\ollama"),
      (Join-Path $env:USERPROFILE ".ollama\models")
    )) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      $full = (Resolve-Path -LiteralPath $candidate).Path
      if ($roots -notcontains $full) {
        $roots += $full
      }
    }
  }
  return $roots
}

function Get-OllamaInstalledModelNames {
  <#
  .SYNOPSIS
    Names Ollama already has locally (on-disk manifests first, then API).
  #>
  $list = New-Object System.Collections.ArrayList

  # Prefer on-disk manifests (fast; works when the API/tray is down)
  foreach ($root in @(Get-OllamaModelsRoots)) {
    $manifestRoot = Join-Path $root "manifests"
    if (-not (Test-Path -LiteralPath $manifestRoot)) { continue }
    Get-ChildItem -LiteralPath $manifestRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $rel = $_.FullName.Substring($manifestRoot.Length).TrimStart("\", "/")
      $parts = $rel -split "[\\/]"
      if ($parts.Count -lt 2) { return }
      $hostPart = $parts[0]
      $n = $null
      if ($hostPart -eq "registry.ollama.ai" -and $parts.Count -ge 4 -and $parts[1] -eq "library") {
        $n = "{0}:{1}" -f $parts[2], $parts[3]
      } elseif ($hostPart -eq "hf.co" -and $parts.Count -ge 3) {
        $n = "hf.co/{0}" -f ($parts[1..($parts.Count - 1)] -join "/")
      }
      if ($n -and ($list -notcontains $n)) { [void]$list.Add($n) }
    }
  }

  try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2
    foreach ($m in @($tags.models)) {
      $n = ([string]$m.name).Trim()
      if ($n -and ($list -notcontains $n)) { [void]$list.Add($n) }
    }
  } catch { }

  return @($list.ToArray())
}

function Test-OllamaModelInstalled {
  <#
  .SYNOPSIS
    True if the model tag is already available locally (skip re-download).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name
  )
  $want = $Name.Trim()
  if (-not $want) { return $false }

  $installed = @(Get-OllamaInstalledModelNames)
  foreach ($have in $installed) {
    if ([string]::Equals($have, $want, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  # Accept bare name when only :latest exists, and vice versa
  $wantBase = $want
  $wantTag = "latest"
  if ($want -match "^(?<base>.+):(?<tag>[^:/]+)$") {
    $wantBase = $Matches["base"]
    $wantTag = $Matches["tag"]
  }
  foreach ($have in $installed) {
    $haveBase = $have
    $haveTag = "latest"
    if ($have -match "^(?<base>.+):(?<tag>[^:/]+)$") {
      $haveBase = $Matches["base"]
      $haveTag = $Matches["tag"]
    }
    if ([string]::Equals($haveBase, $wantBase, [StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals($haveTag, $wantTag, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
    if ($want -notmatch ":" -and
        [string]::Equals($haveBase, $want, [StringComparison]::OrdinalIgnoreCase) -and
        $haveTag -eq "latest") {
      return $true
    }
  }

  return $false
}

function Test-LocalFilePresent {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [long] $MinBytes = 1
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }
  try {
    return ((Get-Item -LiteralPath $Path).Length -ge $MinBytes)
  } catch {
    return $false
  }
}

# --- Download integrity / host allowlists (infosec P1) ---

function Get-DefaultTrustedDownloadHosts {
  @(
    "ollama.com",
    "www.ollama.com",
    "github.com",
    "api.github.com",
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
    "github-releases.githubusercontent.com",
    "huggingface.co",
    "cdn-lfs.huggingface.co",
    "cdn-lfs-us-1.huggingface.co",
    "modelscope.cn",
    "www.modelscope.cn",
    "cursor.com",
    "www.cursor.com",
    "code.visualstudio.com",
    "update.code.visualstudio.com",
    "az764295.vo.msecnd.net",
    "vscode.download.prss.microsoft.com",
    "www.nvidia.com",
    "us.download.nvidia.com",
    "international.download.nvidia.com",
    "gfwsl.geforce.com"
  )
}

function Test-UrlHostAllowlisted {
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [string[]] $AllowedHosts = @(),
    [switch] $AllowHttp
  )
  if (-not $AllowedHosts -or $AllowedHosts.Count -eq 0) {
    $AllowedHosts = Get-DefaultTrustedDownloadHosts
  }
  try {
    $u = [Uri]$Url
  } catch {
    return $false
  }
  if (-not $AllowHttp -and $u.Scheme -ne "https") {
    return $false
  }
  $hostName = $u.Host.ToLowerInvariant()
  foreach ($h in $AllowedHosts) {
    $want = $h.ToLowerInvariant().Trim()
    if (-not $want) { continue }
    if ($hostName -eq $want -or $hostName.EndsWith("." + $want)) {
      return $true
    }
  }
  return $false
}

function Assert-UrlHostAllowlisted {
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [string[]] $AllowedHosts = @(),
    [switch] $AllowHttp
  )
  if (-not (Test-UrlHostAllowlisted -Url $Url -AllowedHosts $AllowedHosts -AllowHttp:$AllowHttp)) {
    $hosts = if ($AllowedHosts -and $AllowedHosts.Count) { $AllowedHosts -join ", " } else { (Get-DefaultTrustedDownloadHosts) -join ", " }
    throw ("URL host not allowlisted (or not HTTPS): {0}`nAllowed hosts: {1}`nSee docs/trusted-sources.md / docs/infosec-swot.md" -f $Url, $hosts)
  }
}

function Get-FileSha256Hex {
  param([Parameter(Mandatory = $true)][string] $Path)
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $hash.Hash.ToLowerInvariant()
}

function Assert-FileSha256 {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][string] $ExpectedSha256
  )
  $want = ($ExpectedSha256 -replace "\s", "").ToLowerInvariant()
  if ($want -notmatch '^[a-f0-9]{64}$') {
    throw ("ExpectedSha256 must be 64 hex chars, got: {0}" -f $ExpectedSha256)
  }
  $got = Get-FileSha256Hex -Path $Path
  if ($got -ne $want) {
    throw ("SHA256 mismatch for {0}`n  expected: {1}`n  actual:   {2}" -f $Path, $want, $got)
  }
  return $got
}

function Get-InstallerPinSha256 {
  param(
    [Parameter(Mandatory = $true)][string] $Id,
    [string] $PinsPath = ""
  )
  if (-not $PinsPath) {
    $PinsPath = Join-Path (Get-RepoRoot) "config\installer-pins.json"
  }
  if (-not (Test-Path -LiteralPath $PinsPath)) {
    return $null
  }
  try {
    $pins = Get-Content -LiteralPath $PinsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $entry = $pins.$Id
    if ($null -eq $entry) { return $null }
    if ($entry -is [string]) {
      if ([string]::IsNullOrWhiteSpace($entry)) { return $null }
      return $entry
    }
    if ($entry.sha256) {
      $s = [string]$entry.sha256
      if ([string]::IsNullOrWhiteSpace($s)) { return $null }
      return $s
    }
  } catch {
    Write-Warning ("Could not read installer pins from {0}: {1}" -f $PinsPath, $_)
  }
  return $null
}

function Save-RemoteFile {
  <#
  .SYNOPSIS
    Download a URL to disk with HTTPS host allowlist and optional SHA256 verify.
  #>
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [Parameter(Mandatory = $true)][string] $Destination,
    [string[]] $AllowedHosts = @(),
    [string] $ExpectedSha256 = "",
    [switch] $SkipAllowlist
  )
  if (-not $SkipAllowlist) {
    Assert-UrlHostAllowlisted -Url $Url -AllowedHosts $AllowedHosts
  }
  $dir = Split-Path -Parent $Destination
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $usedBits = $false
  try {
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
      Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
      $usedBits = $true
    }
  } catch {
    Write-Warning ("BITS transfer failed; falling back to Invoke-WebRequest. {0}" -f $_)
  }
  if (-not $usedBits) {
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
  }
  if (-not (Test-Path -LiteralPath $Destination)) {
    throw ("Download missing: {0}" -f $Destination)
  }
  $sha = Get-FileSha256Hex -Path $Destination
  Write-Host ("  SHA256: {0}" -f $sha)
  if ($ExpectedSha256) {
    Assert-FileSha256 -Path $Destination -ExpectedSha256 $ExpectedSha256 | Out-Null
    Write-Host "  SHA256 verified."
  }
  return $sha
}

function Invoke-VerifiedRemoteScript {
  <#
  .SYNOPSIS
    Download a remote .ps1 to disk (allowlisted), optionally verify SHA256, then run with -File (no irm|iex).
  #>
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [string] $ExpectedSha256 = "",
    [string[]] $AllowedHosts = @(),
    [string[]] $ArgumentList = @(),
    [string] $WorkDir = ""
  )
  if (-not $WorkDir) {
    $WorkDir = Join-Path $env:TEMP "local-llm-chat-scripts"
  }
  New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
  $leaf = [Uri]::UnescapeDataString((Split-Path -Leaf ([Uri]$Url).AbsolutePath))
  if (-not $leaf -or $leaf -notmatch '\.ps1$') {
    $leaf = "remote-install.ps1"
  }
  $dest = Join-Path $WorkDir $leaf
  Write-Host ("Downloading script: {0}" -f $Url)
  Write-Host ("  -> {0}" -f $dest)
  [void](Save-RemoteFile -Url $Url -Destination $dest -AllowedHosts $AllowedHosts -ExpectedSha256 $ExpectedSha256)
  $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $dest) + $ArgumentList
  Write-Host ("Running: powershell {0}" -f ($argList -join " "))
  $p = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Wait -PassThru -NoNewWindow
  return $p.ExitCode
}

# --- fnm / Node (prefer fnm; system npm only as fallback) ---

function Add-FnmCommonPaths {
  foreach ($dir in @(
      (Join-Path $env:LOCALAPPDATA "fnm"),
      (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
      (Join-Path $env:USERPROFILE ".local\bin"),
      (Join-Path $env:LOCALAPPDATA "Programs\fnm")
    )) {
    if ($dir -and (Test-Path -LiteralPath $dir) -and ($env:Path -notlike "*$dir*")) {
      $env:Path = "$dir;$env:Path"
    }
    $exe = Get-ChildItem -LiteralPath $dir -Filter "fnm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe -and ($env:Path -notlike "*$($exe.DirectoryName)*")) {
      $env:Path = "$($exe.DirectoryName);$env:Path"
    }
  }
}

function Initialize-FnmEnv {
  Add-FnmCommonPaths
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

function Test-NodeIsFromFnm {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) { return $false }
  $src = [string]$node.Source
  if ($src -match '(?i)[\\/]\.fnm[\\/]|[\\/]fnm_multishells[\\/]|[\\/]fnm[\\/]') { return $true }
  if ($env:FNM_MULTISHELL_PATH -and $src -like "$($env:FNM_MULTISHELL_PATH)*") { return $true }
  if ($env:FNM_DIR -and $src -like "$($env:FNM_DIR)*") { return $true }
  return $false
}

function Get-NodeRuntimeInfo {
  Add-FnmCommonPaths
  [void](Initialize-FnmEnv)
  $fnmCmd = Get-Command fnm -ErrorAction SilentlyContinue
  $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
  $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
  $fromFnm = Test-NodeIsFromFnm
  $source = if (-not $nodeCmd) { "none" } elseif ($fromFnm) { "fnm" } else { "system" }
  return [pscustomobject]@{
    FnmPresent   = [bool]$fnmCmd
    FnmPath      = if ($fnmCmd) { $fnmCmd.Source } else { $null }
    NodePresent  = [bool]$nodeCmd
    NodePath     = if ($nodeCmd) { $nodeCmd.Source } else { $null }
    NodeVersion  = if ($nodeCmd) { try { (& node -v).Trim() } catch { $null } } else { $null }
    NpmPresent   = [bool]$npmCmd
    NpmPath      = if ($npmCmd) { $npmCmd.Source } else { $null }
    FromFnm      = $fromFnm
    Source       = $source
  }
}

function Install-FnmIfMissing {
  Add-FnmCommonPaths
  if (Get-Command fnm -ErrorAction SilentlyContinue) {
    return $true
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
    $shim = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
    if ((Test-Path $shim) -and ($env:Path -notlike "*$shim*")) {
      $env:Path = "$shim;$env:Path"
    }
    Add-FnmCommonPaths
  }

  if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    $fnmRoot = Join-Path $env:LOCALAPPDATA "fnm"
    New-Item -ItemType Directory -Force -Path $fnmRoot | Out-Null
    $api = "https://api.github.com/repos/Schniz/fnm/releases/latest"
    Write-Host "  Resolving fnm release from GitHub..."
    $rel = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "local-llm-chat" }
    $asset = @($rel.assets) | Where-Object { $_.name -match "fnm-windows\.zip$|windows.*\.zip$" } | Select-Object -First 1
    if (-not $asset) {
      Write-Warning "Could not find fnm Windows zip on GitHub releases."
      return $false
    }
    $zip = Join-Path $env:TEMP "fnm-windows.zip"
    [void](Save-RemoteFile -Url $asset.browser_download_url -Destination $zip `
        -AllowedHosts @("github.com", "api.github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com", "github-releases.githubusercontent.com"))
    Expand-Archive -Path $zip -DestinationPath $fnmRoot -Force
    $exe = Get-ChildItem -Path $fnmRoot -Recurse -Filter "fnm.exe" | Select-Object -First 1
    if (-not $exe) {
      Write-Warning "fnm.exe missing after extract"
      return $false
    }
    if ($env:Path -notlike "*$($exe.DirectoryName)*") {
      $env:Path = "$($exe.DirectoryName);$env:Path"
    }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$($exe.DirectoryName)*") {
      [Environment]::SetEnvironmentVariable("Path", "$($exe.DirectoryName);$userPath", "User")
    }
  }

  Add-FnmCommonPaths
  return [bool](Get-Command fnm -ErrorAction SilentlyContinue)
}

function Ensure-NodeViaFnm {
  param([string] $Version = "lts-latest")

  if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    throw "fnm not on PATH"
  }
  Write-Host ("  Ensuring Node ({0}) via fnm..." -f $Version)
  & fnm install $Version
  if ($LASTEXITCODE -ne 0) { throw "fnm install $Version failed (exit $LASTEXITCODE)" }
  & fnm use $Version
  if ($LASTEXITCODE -ne 0) { throw "fnm use $Version failed (exit $LASTEXITCODE)" }
  & fnm default $Version
  [void](Initialize-FnmEnv)

  $node = Get-Command node -ErrorAction SilentlyContinue
  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $node -or -not $npm) {
    throw "node/npm not available after fnm use"
  }
  if (-not (Test-NodeIsFromFnm)) {
    Write-Warning ("  node resolved outside fnm multishell ({0}); PATH may need a new shell" -f $node.Source)
  }
  Write-Host ("  node (fnm): {0} @ {1}" -f (& node -v), $node.Source)
  Write-Host ("  npm (fnm):  {0} @ {1}" -f (& npm -v), $npm.Source)
}

function Ensure-NodeRuntimePreferFnm {
  <#
  .SYNOPSIS
    Prefer fnm-managed Node/npm; fall back to system Node/npm only if fnm fails.
  #>
  param(
    [string] $Version = "lts-latest",
    [switch] $SkipFnm,
    [switch] $RequireFnm
  )

  if ($SkipFnm) {
    Write-Host "  SkipFnm: using system node/npm only"
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $npm -or -not $node) {
      throw "-SkipFnm set but system node/npm not on PATH"
    }
    Write-Host ("  node (system): {0} @ {1}" -f (& node -v), $node.Source)
    return (Get-NodeRuntimeInfo)
  }

  $fnmOk = $false
  $fnmError = $null
  try {
    if (-not (Install-FnmIfMissing)) {
      throw "fnm install/detection failed"
    }
    Write-Host ("  fnm OK: {0}" -f (Get-Command fnm).Source)
    [void](Initialize-FnmEnv)
    Ensure-NodeViaFnm -Version $Version
    $fnmOk = $true
  } catch {
    $fnmError = $_
    Write-Warning ("  fnm path failed: {0}" -f $_)
  }

  if ($fnmOk) {
    return (Get-NodeRuntimeInfo)
  }

  if ($RequireFnm) {
    throw "fnm is required but failed: $fnmError"
  }

  Write-Host "  Falling back to system node/npm (fnm preferred but unavailable)..."
  $node = Get-Command node -ErrorAction SilentlyContinue
  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $node -or -not $npm) {
    throw "Neither fnm nor system node/npm is available. Install fnm (winget install Schniz.fnm) or Node.js, then re-run."
  }
  Write-Host ("  node (system fallback): {0} @ {1}" -f (& node -v), $node.Source)
  Write-Host ("  npm  (system fallback): {0} @ {1}" -f (& npm -v), $npm.Source)
  return (Get-NodeRuntimeInfo)
}

function Get-FnmDefaultNodePath {
  $fnmDir = $env:FNM_DIR
  if (-not $fnmDir) { $fnmDir = Join-Path $env:APPDATA "fnm" }
  foreach ($candidate in @(
      (Join-Path $fnmDir "aliases\default\node.exe"),
      (Join-Path $fnmDir "aliases\lts-latest\node.exe")
    )) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $versions = Join-Path $fnmDir "node-versions"
  if (Test-Path -LiteralPath $versions) {
    $node = Get-ChildItem -LiteralPath $versions -Recurse -Filter "node.exe" -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($node) { return $node.FullName }
  }
  return $null
}

function Get-CodegraphShimPath {
  $candidates = @(
    (Join-Path $env:APPDATA "npm\node_modules\@colbymchenry\codegraph\npm-shim.js"),
    (Join-Path $env:APPDATA "npm\node_modules\@colbymchenry\codegraph\dist\cli.js")
  )
  try {
    [void](Initialize-FnmEnv)
    $root = (& npm root -g 2>$null)
    if ($root) {
      $candidates = @(
        (Join-Path $root "@colbymchenry\codegraph\npm-shim.js"),
        (Join-Path $root "@colbymchenry\codegraph\dist\cli.js")
      ) + $candidates
    }
  } catch { }
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) {
      return (Resolve-Path -LiteralPath $c).Path
    }
  }
  return $null
}

function Get-CodegraphMcpLaunchInfo {
  <#
  .SYNOPSIS
    Resolve a GUI-safe Codegraph MCP launch command (prefer fnm default node + npm-shim).
  #>
  [void](Initialize-FnmEnv)
  $shim = Get-CodegraphShimPath
  $fnmNode = Get-FnmDefaultNodePath
  $cmdPath = Join-Path $env:APPDATA "npm\codegraph.cmd"

  if ($fnmNode -and $shim) {
    return [pscustomobject]@{
      Command = $fnmNode
      ArgList = @($shim, "serve", "--mcp", "--path", '${workspaceFolder}')
      Mode    = "fnm-node+shim"
      Shim    = $shim
      Node    = $fnmNode
    }
  }
  if ((Test-Path -LiteralPath $cmdPath) -and $shim) {
    return [pscustomobject]@{
      Command = (Resolve-Path -LiteralPath $cmdPath).Path
      ArgList = @("serve", "--mcp", "--path", '${workspaceFolder}')
      Mode    = "codegraph.cmd"
      Shim    = $shim
      Node    = $null
    }
  }
  return [pscustomobject]@{
    Command = "codegraph"
    ArgList = @("serve", "--mcp", "--path", '${workspaceFolder}')
    Mode    = "path-codegraph"
    Shim    = $shim
    Node    = $fnmNode
  }
}

function Get-CursorMcpJsonPath {
  Join-Path $env:USERPROFILE ".cursor\mcp.json"
}

function Get-VSCodeMcpJsonPath {
  $info = Get-VSCodeInstallInfo
  Join-Path $info.UserDataPath "User\mcp.json"
}

function Get-CodegraphMcpJsonStatus {
  $launch = Get-CodegraphMcpLaunchInfo
  $cursorPath = Get-CursorMcpJsonPath
  $vscodePath = Get-VSCodeMcpJsonPath
  $cursorOk = $false
  $vscodeOk = $false
  if (Test-Path -LiteralPath $cursorPath) {
    try {
      $j = Get-Content -LiteralPath $cursorPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $cursorOk = [bool]($j.mcpServers -and $j.mcpServers.codegraph)
    } catch { }
  }
  if (Test-Path -LiteralPath $vscodePath) {
    try {
      $j = Get-Content -LiteralPath $vscodePath -Raw -Encoding UTF8 | ConvertFrom-Json
      $vscodeOk = [bool]($j.servers -and $j.servers.codegraph)
    } catch { }
  }
  return [pscustomobject]@{
    CursorPath    = $cursorPath
    VSCodePath    = $vscodePath
    CursorHas     = $cursorOk
    VSCodeHas     = $vscodeOk
    LaunchMode    = $launch.Mode
    LaunchCommand = $launch.Command
  }
}

function Set-McpServerEntryInJsonFile {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][ValidateSet("cursor", "vscode")][string] $Flavor,
    [Parameter(Mandatory = $true)][string] $ServerName,
    [Parameter(Mandatory = $true)][string] $Command,
    [Parameter(Mandatory = $true)][string[]] $ArgList
  )

  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $rootKey = if ($Flavor -eq "cursor") { "mcpServers" } else { "servers" }
  $obj = [ordered]@{}
  if (Test-Path -LiteralPath $Path) {
    $bakDir = Join-Path $dir "local-llm-chat-backups"
    New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination (Join-Path $bakDir ("mcp-{0}.json.bak" -f $stamp)) -Force
    try {
      $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $existing.PSObject.Properties) {
        $obj[$p.Name] = $p.Value
      }
    } catch {
      Write-Warning "Could not parse existing $Path - rewriting with codegraph entry only"
      $obj = [ordered]@{}
    }
  }

  $servers = [ordered]@{}
  if ($obj.Contains($rootKey) -and $obj[$rootKey]) {
    $existingServers = $obj[$rootKey]
    if ($existingServers -is [System.Management.Automation.PSCustomObject]) {
      foreach ($p in $existingServers.PSObject.Properties) {
        $servers[$p.Name] = $p.Value
      }
    }
  }

  $servers[$ServerName] = [ordered]@{
    type    = "stdio"
    command = $Command
    args    = @($ArgList)
  }
  $obj[$rootKey] = $servers

  $json = ($obj | ConvertTo-Json -Depth 12)
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Update-CodegraphMcpJsonFiles {
  <#
  .SYNOPSIS
    Write/merge Codegraph MCP server into Cursor (~/.cursor/mcp.json) and VS Code (%APPDATA%\Code\User\mcp.json).
  #>
  param(
    [string] $ProjectPath = "",
    [switch] $WriteWorkspaceFiles,
    [switch] $PortableCommand
  )

  $launch = Get-CodegraphMcpLaunchInfo
  if ($PortableCommand) {
    $launch = [pscustomobject]@{
      Command = "codegraph"
      ArgList = @("serve", "--mcp", "--path", '${workspaceFolder}')
      Mode    = "path-codegraph"
    }
  }

  $cursorPath = Get-CursorMcpJsonPath
  $vscodePath = Get-VSCodeMcpJsonPath
  $serverArgs = [string[]]@($launch.ArgList)

  Set-McpServerEntryInJsonFile -Path $cursorPath -Flavor cursor -ServerName "codegraph" -Command $launch.Command -ArgList $serverArgs
  Set-McpServerEntryInJsonFile -Path $vscodePath -Flavor vscode -ServerName "codegraph" -Command $launch.Command -ArgList $serverArgs

  $workspace = @()
  if ($WriteWorkspaceFiles -and $ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $cursorWs = Join-Path $ProjectPath ".cursor\mcp.json"
    $vscodeWs = Join-Path $ProjectPath ".vscode\mcp.json"
    # Workspace files stay portable (command on PATH) so they are safe to commit
    $portableArgs = [string[]]@("serve", "--mcp", "--path", '${workspaceFolder}')
    Set-McpServerEntryInJsonFile -Path $cursorWs -Flavor cursor -ServerName "codegraph" -Command "codegraph" -ArgList $portableArgs
    Set-McpServerEntryInJsonFile -Path $vscodeWs -Flavor vscode -ServerName "codegraph" -Command "codegraph" -ArgList $portableArgs
    $workspace = @($cursorWs, $vscodeWs)
  }

  return [pscustomobject]@{
    CursorPath = $cursorPath
    VSCodePath = $vscodePath
    Workspace  = $workspace
    LaunchMode = $launch.Mode
    Command    = $launch.Command
    ArgList    = $serverArgs
  }
}

function Get-CursorExeCandidates {
  @(
    (Join-Path $env:LOCALAPPDATA "Programs\Cursor\Cursor.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles} "Cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles} "cursor\Cursor.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Cursor\Cursor.exe")
  ) | Where-Object { $_ }
}

function Get-CursorInstallInfo {
  <#
  .SYNOPSIS
    Locate Cursor.exe (prefer per-user install under LocalAppData).
  #>
  $exe = $null
  $scope = "None"
  foreach ($candidate in @(Get-CursorExeCandidates)) {
    if (Test-Path -LiteralPath $candidate) {
      $exe = (Resolve-Path -LiteralPath $candidate).Path
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) {
        $scope = "User"
      } else {
        $scope = "Machine"
      }
      break
    }
  }

  $cmd = $null
  $c = Get-Command cursor -ErrorAction SilentlyContinue
  if ($c -and $c.Source) {
    $cmd = $c.Source
    if (-not $exe) {
      # cursor.cmd often lives under resources\app\bin
      $maybe = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $cmd))) "Cursor.exe"
      if (Test-Path -LiteralPath $maybe) {
        $exe = (Resolve-Path -LiteralPath $maybe).Path
        if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) { $scope = "User" } else { $scope = "Machine" }
      }
    }
  }

  $userData = Join-Path $env:APPDATA "Cursor"
  $settings = Join-Path $userData "User\settings.json"
  $stateDb = Join-Path $userData "User\globalStorage\state.vscdb"
  $nodeHelper = $null
  if ($exe) {
    $maybeNode = Join-Path (Split-Path -Parent $exe) "resources\app\resources\helpers\node.exe"
    if (Test-Path -LiteralPath $maybeNode) {
      $nodeHelper = (Resolve-Path -LiteralPath $maybeNode).Path
    }
  }

  return [pscustomobject]@{
    Installed      = [bool]($exe -or $cmd)
    ExePath        = $exe
    CmdPath        = $cmd
    Scope          = $scope
    UserDataPath   = $userData
    SettingsPath   = $settings
    StateDbPath    = $stateDb
    NodeHelperPath = $nodeHelper
  }
}

function Test-CursorInstalled {
  return [bool]((Get-CursorInstallInfo).Installed)
}

function Test-CursorProcessRunning {
  return [bool](Get-Process -Name "Cursor" -ErrorAction SilentlyContinue)
}

function Get-VSCodeExeCandidates {
  @(
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code Insiders\Code - Insiders.exe"),
    (Join-Path ${env:ProgramFiles} "Microsoft VS Code\Code.exe"),
    (Join-Path ${env:ProgramFiles} "Microsoft VS Code Insiders\Code - Insiders.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft VS Code\Code.exe")
  ) | Where-Object { $_ }
}

function Get-VSCodeInstallInfo {
  <#
  .SYNOPSIS
    Locate VS Code Code.exe (prefer per-user install under LocalAppData).
  #>
  $exe = $null
  $scope = "None"
  $insiders = $false
  foreach ($candidate in @(Get-VSCodeExeCandidates)) {
    if (Test-Path -LiteralPath $candidate) {
      $exe = (Resolve-Path -LiteralPath $candidate).Path
      $insiders = ($exe -match "Insiders")
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) {
        $scope = "User"
      } else {
        $scope = "Machine"
      }
      break
    }
  }

  $cmd = $null
  $c = Get-Command code -ErrorAction SilentlyContinue
  if ($c -and $c.Source) {
    $cmd = $c.Source
  }
  if (-not $cmd -and $exe) {
    $binName = if ($insiders) { "code-insiders.cmd" } else { "code.cmd" }
    $maybeCmd = Join-Path (Split-Path -Parent $exe) "bin\$binName"
    if (Test-Path -LiteralPath $maybeCmd) {
      $cmd = (Resolve-Path -LiteralPath $maybeCmd).Path
    }
  }
  if (-not $exe -and $cmd) {
    # code.cmd lives under ...\Microsoft VS Code\bin
    $root = Split-Path -Parent (Split-Path -Parent $cmd)
    $maybeExe = Join-Path $root "Code.exe"
    if (-not (Test-Path -LiteralPath $maybeExe)) {
      $maybeExe = Join-Path $root "Code - Insiders.exe"
    }
    if (Test-Path -LiteralPath $maybeExe) {
      $exe = (Resolve-Path -LiteralPath $maybeExe).Path
      $insiders = ($exe -match "Insiders")
      if ($exe -like (Join-Path $env:LOCALAPPDATA "*")) { $scope = "User" } else { $scope = "Machine" }
    }
  }

  $userData = if ($insiders) {
    Join-Path $env:APPDATA "Code - Insiders"
  } else {
    Join-Path $env:APPDATA "Code"
  }

  $continueDir = Join-Path $HOME ".continue"
  $continueConfig = Join-Path $continueDir "config.json"

  return [pscustomobject]@{
    Installed       = [bool]($exe -or $cmd)
    ExePath         = $exe
    CmdPath         = $cmd
    Scope           = $scope
    Insiders        = $insiders
    UserDataPath    = $userData
    SettingsPath    = (Join-Path $userData "User\settings.json")
    ContinueDir     = $continueDir
    ContinueConfig  = $continueConfig
  }
}

function Test-VSCodeInstalled {
  return [bool]((Get-VSCodeInstallInfo).Installed)
}

function Get-ContinueOllamaConfigStatus {
  <#
  .SYNOPSIS
    Check ~/.continue/config.json for Ollama (or Headroom) wiring.
  #>
  $info = Get-VSCodeInstallInfo
  $path = $info.ContinueConfig
  if (-not (Test-Path -LiteralPath $path)) {
    return [pscustomobject]@{
      Ok          = $true
      Configured  = $false
      Path        = $path
      ApiBase     = $null
      Models      = @()
      HasAutocomplete = $false
      RemoteEntries = @()
      LocalOnly   = $false
      Message     = "Continue config missing"
      InstallInfo = $info
    }
  }

  try {
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      Ok          = $false
      Configured  = $false
      Path        = $path
      ApiBase     = $null
      Models      = @()
      HasAutocomplete = $false
      RemoteEntries = @("config.json:parse-error")
      LocalOnly   = $false
      Message     = "Continue config JSON invalid: $_"
      InstallInfo = $info
    }
  }

  $models = @()
  $apiBase = $null
  foreach ($m in @($cfg.models)) {
    $provider = [string]$m.provider
    $base = [string]$m.apiBase
    if ($provider -match "^(ollama|openai)$" -and $base -match "11434|8787|localhost|127\.0\.0\.1") {
      $models += [string]$m.model
      if (-not $apiBase) { $apiBase = $base }
    }
  }

  $configured = $models.Count -gt 0
  $hasAutocomplete = $false
  try {
    if ($cfg.tabAutocompleteModel -and $cfg.tabAutocompleteModel.model) {
      $hasAutocomplete = $true
    }
  } catch { }

  $remoteInfo = Get-ContinueRemoteProviderStatus
  return [pscustomobject]@{
    Ok               = $true
    Configured       = $configured
    Path             = $path
    ApiBase          = $apiBase
    Models           = $models
    HasAutocomplete  = $hasAutocomplete
    RemoteEntries    = @($remoteInfo.RemoteEntries)
    LocalOnly        = [bool]$remoteInfo.LocalOnly
    Message          = if ($configured) { "Continue wired to local models (chat + autocomplete)" } else { "Continue config has no local Ollama/OpenAI models" }
    InstallInfo      = $info
  }
}

function Get-ClineDataPaths {
  $root = Join-Path $HOME ".cline"
  $data = Join-Path $root "data"
  return [pscustomobject]@{
    Root            = $root
    DataDir         = $data
    ProvidersPath   = (Join-Path $data "settings\providers.json")
    GlobalStatePath = (Join-Path $data "globalState.json")
    SettingsDir     = (Join-Path $data "settings")
  }
}

function Get-ClineOllamaConfigStatus {
  <#
  .SYNOPSIS
    Check ~/.cline providers.json / globalState.json for Ollama (Cursor-like agent).
  #>
  $paths = Get-ClineDataPaths
  $info = Get-VSCodeInstallInfo
  $model = $null
  $baseUrl = $null
  $source = $null

  if (Test-Path -LiteralPath $paths.ProvidersPath) {
    try {
      $cfg = Get-Content -LiteralPath $paths.ProvidersPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.lastUsedProvider -eq "ollama" -and $cfg.providers -and $cfg.providers.ollama) {
        $settings = $cfg.providers.ollama.settings
        if ($settings) {
          $model = [string]$settings.model
          $baseUrl = [string]$settings.baseUrl
          $source = "providers.json"
        }
      }
    } catch { }
  }

  if (-not $model -and (Test-Path -LiteralPath $paths.GlobalStatePath)) {
    try {
      $gs = Get-Content -LiteralPath $paths.GlobalStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($gs.actModeApiProvider -eq "ollama" -or $gs.planModeApiProvider -eq "ollama") {
        $model = [string]$(if ($gs.actModeOllamaModelId) { $gs.actModeOllamaModelId } else { $gs.planModeOllamaModelId })
        $baseUrl = [string]$(if ($gs.actModeOllamaBaseUrl) { $gs.actModeOllamaBaseUrl } else { $gs.ollamaBaseUrl })
        $source = "globalState.json"
      }
    } catch { }
  }

  $localBase = $baseUrl -and ($baseUrl -match "11434|8787|localhost|127\.0\.0\.1")
  $configured = [bool]($model -and $localBase)

  $remoteProviders = @()
  if (Test-Path -LiteralPath $paths.ProvidersPath) {
    try {
      $pcfg = Get-Content -LiteralPath $paths.ProvidersPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($pcfg.providers) {
        foreach ($p in $pcfg.providers.PSObject.Properties) {
          $id = [string]$p.Name
          if ($id -and $id -ne "ollama" -and $id -ne "lmstudio") {
            $remoteProviders += $id
          } elseif ($id -eq "ollama") {
            $b = [string]$p.Value.settings.baseUrl
            if ($b -and -not (Test-IsLocalLlmEndpoint $b)) { $remoteProviders += "ollama(non-local)" }
          }
        }
      }
      if ($pcfg.lastUsedProvider -and $pcfg.lastUsedProvider -notin @("ollama", "lmstudio")) {
        $remoteProviders += ("lastUsed:" + $pcfg.lastUsedProvider)
      }
    } catch { }
  }
  if (Test-Path -LiteralPath $paths.GlobalStatePath) {
    try {
      $gs = Get-Content -LiteralPath $paths.GlobalStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($mode in @("actModeApiProvider", "planModeApiProvider")) {
        $v = [string]$gs.$mode
        if ($v -and $v -notin @("ollama", "lmstudio", "")) {
          $remoteProviders += ("${mode}:$v")
        }
      }
    } catch { }
  }
  $remoteProviders = @($remoteProviders | Select-Object -Unique)

  return [pscustomobject]@{
    Ok                 = $true
    Configured         = $configured
    Model              = $model
    BaseUrl            = $baseUrl
    Source             = $source
    Paths              = $paths
    RemoteProviders    = $remoteProviders
    LocalOnly          = ($configured -and $remoteProviders.Count -eq 0)
    Message            = if ($configured) { "Cline wired to local Ollama ($source)" } else { "Cline not configured for local Ollama" }
    InstallInfo        = $info
  }
}

function Test-IsLocalLlmEndpoint {
  param([string] $Url)
  if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
  $u = $Url.Trim().ToLowerInvariant()
  if ($u -match 'localhost|127\.0\.0\.1|\[::1\]') { return $true }
  if ($u -match ':11434|:8787') { return $true }
  return $false
}

function Get-CloudProviderIdList {
  @(
    "anthropic", "openai", "openai-native", "openai-codex", "openrouter", "bedrock",
    "gemini", "google", "vertex", "xai", "grok", "groq", "together", "fireworks",
    "deepseek", "mistral", "azure", "azure-openai", "vscode-lm", "copilot",
    "chatgpt", "cursor", "cline", "sambanova", "cerebras", "moonshot", "qwen",
    "huggingface", "nebius", "asksage", "watsonx", "ibm", "litellm", "requesty",
    "artificialanalysis", "claude", "gpt"
  )
}

function Test-ContinueModelEntryIsLocal {
  param($Entry)
  if (-not $Entry) { return $false }
  $provider = [string]$Entry.provider
  $base = [string]$Entry.apiBase
  if ($provider -eq "ollama") {
    if (-not $base) { return $true }
    return (Test-IsLocalLlmEndpoint $base)
  }
  if ($provider -eq "openai" -or $provider -eq "openai-compatible") {
    return (Test-IsLocalLlmEndpoint $base)
  }
  # lmstudio / llama.cpp local servers
  if ($provider -match "^(lmstudio|llamacpp|llama\.cpp)$") {
    return (Test-IsLocalLlmEndpoint $base) -or (-not $base)
  }
  return $false
}

function Get-ContinueRemoteProviderStatus {
  $info = Get-VSCodeInstallInfo
  $path = $info.ContinueConfig
  $yamlPath = Join-Path $info.ContinueDir "config.yaml"
  $remote = @()
  $localCount = 0

  if (Test-Path -LiteralPath $path) {
    try {
      $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($m in @($cfg.models)) {
        if (Test-ContinueModelEntryIsLocal $m) { $localCount++ }
        else {
          $label = "$(if ($m.provider) { $m.provider } else { '?' }):$(if ($m.model) { $m.model } else { '?' })"
          if ($m.apiBase -and -not (Test-IsLocalLlmEndpoint $m.apiBase)) {
            $label += "@$($m.apiBase)"
          }
          $remote += $label
        }
      }
      if ($cfg.tabAutocompleteModel -and -not (Test-ContinueModelEntryIsLocal $cfg.tabAutocompleteModel)) {
        $remote += "tabAutocomplete:$($cfg.tabAutocompleteModel.provider)/$($cfg.tabAutocompleteModel.model)"
      }
    } catch {
      $remote += "config.json:parse-error"
    }
  }

  if (Test-Path -LiteralPath $yamlPath) {
    try {
      $raw = Get-Content -LiteralPath $yamlPath -Raw -Encoding UTF8
      foreach ($pat in @("api\.openai\.com", "api\.anthropic\.com", "openrouter\.ai", "generativelanguage\.googleapis", "api\.x\.ai", "api\.groq\.com", "provider:\s*anthropic", "provider:\s*gemini", "provider:\s*groq", "provider:\s*xai", "provider:\s*openrouter", "provider:\s*bedrock")) {
        if ($raw -match $pat) { $remote += "config.yaml:$pat"; break }
      }
    } catch { }
  }

  return [pscustomobject]@{
    Path            = $path
    YamlPath        = $yamlPath
    LocalModelCount = $localCount
    RemoteEntries   = @($remote | Select-Object -Unique)
    LocalOnly       = ($remote.Count -eq 0 -and $localCount -gt 0)
  }
}

function Merge-JsonSettingsFile {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][hashtable] $Settings
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $obj = [ordered]@{}
  if (Test-Path -LiteralPath $Path) {
    try {
      $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $existing.PSObject.Properties) {
        $obj[$p.Name] = $p.Value
      }
    } catch {
      $bak = "$Path.bak-local-llm-chat"
      Copy-Item -LiteralPath $Path -Destination $bak -Force
    }
  }
  foreach ($k in $Settings.Keys) {
    $obj[$k] = $Settings[$k]
  }
  $json = ($obj | ConvertTo-Json -Depth 12)
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-EditorLocalOnlySettingsHashtable {
  return @{
    "github.copilot.enable"                        = @{ "*" = $false }
    "github.copilot.editor.enableAutoCompletions"  = $false
    "github.copilot.nexEditSuggestions.enabled"    = $false
    "chat.agent.enabled"                           = $false
    "chat.disableAIFeatures"                       = $true
  }
}

function Set-OllamaCloudDisabled {
  param([switch] $Persistent)
  $env:OLLAMA_NO_CLOUD = "1"
  if ($Persistent) {
    [Environment]::SetEnvironmentVariable("OLLAMA_NO_CLOUD", "1", "User")
  }
  $ollamaHome = Join-Path $HOME ".ollama"
  $serverJson = Join-Path $ollamaHome "server.json"
  New-Item -ItemType Directory -Force -Path $ollamaHome | Out-Null
  $cfg = @{}
  if (Test-Path -LiteralPath $serverJson) {
    try {
      $cfg = Get-Content -LiteralPath $serverJson -Raw -Encoding UTF8 | ConvertFrom-Json
      $hash = [ordered]@{}
      foreach ($p in $cfg.PSObject.Properties) { $hash[$p.Name] = $p.Value }
      $cfg = $hash
    } catch {
      $cfg = [ordered]@{}
    }
  } else {
    $cfg = [ordered]@{}
  }
  if ($cfg -isnot [System.Collections.IDictionary]) {
    $cfg = [ordered]@{}
  }
  $cfg["disable_ollama_cloud"] = $true
  $json = ($cfg | ConvertTo-Json -Depth 8)
  [System.IO.File]::WriteAllText($serverJson, $json, [System.Text.UTF8Encoding]::new($false))
  return $serverJson
}

function Get-CursorOllamaConfigStatus {
  <#
  .SYNOPSIS
    Read Cursor openAIBaseUrl / useOpenAIKey / enabled models from state.vscdb.
  #>
  $info = Get-CursorInstallInfo
  if (-not $info.Installed) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $false
      Configured    = $false
      Message       = "Cursor not installed"
      InstallInfo   = $info
    }
  }
  if (-not (Test-Path -LiteralPath $info.StateDbPath)) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $true
      Configured    = $false
      Message       = "Cursor user data / state.vscdb missing (launch Cursor once, then re-run)"
      InstallInfo   = $info
    }
  }
  if (-not $info.NodeHelperPath) {
    return [pscustomobject]@{
      Ok            = $false
      Installed     = $true
      Configured    = $false
      Message       = "Cursor bundled node.exe not found; cannot read state.vscdb"
      InstallInfo   = $info
    }
  }

  $helper = Join-Path $PSScriptRoot "_Set-CursorOllamaState.cjs"
  if (-not (Test-Path -LiteralPath $helper)) {
    throw "Missing helper: $helper"
  }

  $prevEa = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = & $info.NodeHelperPath --no-warnings $helper status --db $info.StateDbPath 2>&1
    $exit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEa
  }
  $text = (($raw | ForEach-Object { "$_" }) -join "`n").Trim()
  if ($exit -ne 0) {
    return [pscustomobject]@{
      Ok          = $false
      Installed   = $true
      Configured  = $false
      Message     = "Failed to read Cursor state: $text"
      InstallInfo = $info
      Raw         = $text
    }
  }

  $json = $text | ConvertFrom-Json
  return [pscustomobject]@{
    Ok                     = [bool]$json.ok
    Installed              = $true
    Configured             = [bool]$json.configuredForOllama
    OpenAIBaseUrl          = $json.openAIBaseUrl
    UseOpenAIKey           = [bool]$json.useOpenAIKey
    ApiKeyPresent          = [bool]$json.apiKeyPresent
    ModelOverrideEnabled   = @($json.modelOverrideEnabled)
    ModelOverrideDisabledCount = $(if ($null -ne $json.modelOverrideDisabledCount) { [int]$json.modelOverrideDisabledCount } else { 0 })
    CatalogDisabledCount   = $(if ($null -ne $json.catalogDisabledCount) { [int]$json.catalogDisabledCount } else { 0 })
    RemoteModelsDisabled   = [bool]$json.remoteModelsDisabled
    Message                = if ($json.configuredForOllama) { "Cursor wired to local OpenAI-compatible endpoint" } else { "Cursor not yet configured for Ollama" }
    InstallInfo            = $info
    Raw                    = $json
  }
}

function Get-PythonUserScriptsPath {
  try {
    $path = & python -c "import site,sys; print(site.USER_BASE)" 2>$null
    if ($path) {
      return (Join-Path $path.Trim() "Scripts")
    }
  } catch { }
  return $null
}

function Add-PythonUserScriptsToPath {
  $scripts = Get-PythonUserScriptsPath
  if ($scripts -and (Test-Path $scripts) -and ($env:Path -notlike "*$scripts*")) {
    $env:Path = "$scripts;$env:Path"
  }
}

function Get-DefaultHeadroomVenvPath {
  return "C:\hr"
}

function Resolve-HeadroomExe {
  param([string] $VenvPath = "")

  if (-not $VenvPath) {
    $VenvPath = Get-DefaultHeadroomVenvPath
  }

  $candidates = @(
    (Join-Path $VenvPath "Scripts\headroom.exe")
    (Join-Path $VenvPath "Scripts\headroom")
  )

  Add-PythonUserScriptsToPath
  $cmd = Get-Command headroom -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    $candidates = @($cmd.Source) + $candidates
  }

  $userScripts = Get-PythonUserScriptsPath
  if ($userScripts) {
    $candidates += (Join-Path $userScripts "headroom.exe")
  }

  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) {
      return (Resolve-Path -LiteralPath $c).Path
    }
  }
  return $null
}

function Ensure-HeadroomShortVenv {
  param(
    [string] $VenvPath = "C:\hr",
    [switch] $ForceReinstall
  )

  $py = Get-Command python -ErrorAction SilentlyContinue
  if (-not $py) {
    throw "python not found. Install Python 3.11+ from https://www.python.org/downloads/ (or Microsoft Store) and reopen the terminal."
  }

  $venvPython = Join-Path $VenvPath "Scripts\python.exe"
  $headroomExe = Join-Path $VenvPath "Scripts\headroom.exe"

  if ($ForceReinstall -and (Test-Path -LiteralPath $VenvPath)) {
    Write-Host "Removing existing venv: $VenvPath"
    Remove-Item -LiteralPath $VenvPath -Recurse -Force
  }

  if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "Creating short-path Headroom venv at $VenvPath (avoids Windows path-length limits)..."
    $parent = Split-Path -Parent $VenvPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    & python -m venv $VenvPath | Out-Host
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null -and -not (Test-Path -LiteralPath $venvPython)) {
      throw "Failed to create venv at $VenvPath. Pick a short writable path (e.g. C:\hr)."
    }
    if (-not (Test-Path -LiteralPath $venvPython)) {
      throw "Failed to create venv at $VenvPath. Pick a short writable path (e.g. C:\hr)."
    }
  }

  if (-not (Test-Path -LiteralPath $headroomExe) -or $ForceReinstall) {
    Write-Host "Installing headroom-ai[proxy] into $VenvPath ..."
    Write-Host "(Store/user-site installs often fail on Windows without long-path support; short venv avoids that.)"
    & $venvPython -m pip install --upgrade pip | Out-Host
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
      Write-Warning "pip upgrade returned exit $LASTEXITCODE (continuing)"
    }
    & $venvPython -m pip install "headroom-ai[proxy]" | Out-Host
    if (-not (Test-Path -LiteralPath $headroomExe)) {
      throw @"
headroom install failed in $VenvPath.
If you saw 'Windows Long Path support' / OSError Errno 2 under litellm:
  - Prefer this short venv (C:\hr) — do not use pip --user with Store Python.
  - Or enable long paths (admin): https://pip.pypa.io/warnings/enable-long-paths
Also ensure Python Scripts are reachable; this script uses $VenvPath\Scripts\headroom.exe directly.
"@
    }
  }

  $scriptsDir = Join-Path $VenvPath "Scripts"
  if ($env:Path -notlike "*$scriptsDir*") {
    $env:Path = "$scriptsDir;$env:Path"
  }

  return (Resolve-Path -LiteralPath $headroomExe).Path
}

function Get-SystemRamGB {
  try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    return [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
  } catch {
    try {
      $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
      return [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
    } catch {
      return $null
    }
  }
}

function Resolve-CodingModelTier {
  param([string] $Tier = "Auto")
  if ($Tier -and $Tier -ne "Auto") {
    return $Tier
  }
  $gb = Get-SystemRamGB
  if (-not $gb) {
    Write-Warning "Could not detect RAM; defaulting to 16GB tier."
    return "16GB"
  }
  Write-Host "Detected system RAM: ${gb} GB"
  if ($gb -lt 12) { return "8GB" }
  if ($gb -lt 24) { return "16GB" }
  return "32GB"
}

function Get-CodingModelsForTier {
  param([Parameter(Mandatory = $true)][string] $Tier)
  $sets = @{
    "8GB"  = @("qwen2.5-coder:3b", "starcoder2:3b")
    "16GB" = @("qwen2.5-coder:7b", "starcoder2:3b")
    "32GB" = @("qwen2.5-coder:14b", "codellama:13b", "deepseek-coder-v2:16b", "starcoder2:7b")
  }
  if (-not $sets.ContainsKey($Tier)) {
    throw "Unknown tier: $Tier"
  }
  return ,$sets[$Tier]
}

function Get-VirtualMachineInfo {
  <#
  .SYNOPSIS
    Detect whether this OS is running inside a VM and guess the hypervisor.
  #>
  $info = [ordered]@{
    IsVirtualMachine = $false
    Hypervisor       = "None"
    Manufacturer     = ""
    Model            = ""
    HypervisorPresent = $false
    Evidence         = @()
  }

  try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $info.Manufacturer = [string]$cs.Manufacturer
    $info.Model = [string]$cs.Model
    if ($cs.PSObject.Properties.Name -contains "HypervisorPresent") {
      $info.HypervisorPresent = [bool]$cs.HypervisorPresent
    }
  } catch { }

  $blob = ("{0} {1}" -f $info.Manufacturer, $info.Model)
  $evidence = New-Object System.Collections.Generic.List[string]

  # HypervisorPresent is also True on bare metal with Hyper-V / VBS - note only, do not decide alone.
  if ($info.HypervisorPresent) {
    [void]$evidence.Add("Win32_ComputerSystem.HypervisorPresent=True (also common on bare metal with Hyper-V/VBS)")
  }

  $patterns = @(
    @{ Re = "VMware"; Name = "VMware" },
    @{ Re = "VirtualBox|innotek|Oracle.*Virtual"; Name = "VirtualBox" },
    @{ Re = "Hyper-V|Virtual Machine"; Name = "Hyper-V" },
    @{ Re = "QEMU|KVM|KVM Virtual|Standard PC \(Q35|Standard PC \(i440FX"; Name = "QEMU/KVM" },
    @{ Re = "Xen|HVM domU"; Name = "Xen" },
    @{ Re = "Parallels"; Name = "Parallels" },
    @{ Re = "Bochs"; Name = "Bochs" },
    @{ Re = "Amazon EC2|Google Compute|Microsoft Corporation.*Virtual"; Name = "Cloud VM" }
  )
  foreach ($p in $patterns) {
    if ($blob -match $p.Re) {
      $info.IsVirtualMachine = $true
      if ($info.Hypervisor -eq "None") { $info.Hypervisor = $p.Name }
      [void]$evidence.Add("Model/Manufacturer match: $($p.Name)")
    }
  }

  # Virtual display adapters often present even when Model string is ambiguous
  try {
    $adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    foreach ($a in $adapters) {
      $n = [string]$a.Name
      if ($n -match "Hyper-V Video|VMware SVGA|VMware WDDM|VirtualBox Graphics|QXL|Virtio.?GPU") {
        $info.IsVirtualMachine = $true
        [void]$evidence.Add("Virtual display adapter: $n")
        if ($info.Hypervisor -eq "None") {
          if ($n -match "Hyper-V") { $info.Hypervisor = "Hyper-V" }
          elseif ($n -match "VMware") { $info.Hypervisor = "VMware" }
          elseif ($n -match "VirtualBox") { $info.Hypervisor = "VirtualBox" }
          elseif ($n -match "QXL|Virtio") { $info.Hypervisor = "QEMU/KVM" }
        }
      }
    }
  } catch { }

  $info.Evidence = @($evidence.ToArray())
  return [pscustomobject]$info
}

function Get-NvidiaDisplayAdapters {
  $result = @()
  try {
    $adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
  } catch {
    $adapters = @()
  }
  foreach ($a in $adapters) {
    $name = [string]$a.Name
    $pnp = [string]$a.PNPDeviceID
    $isNvidia = ($name -match "NVIDIA|GeForce|Quadro|Tesla|RTX|GTX|GRID") -or ($pnp -match "VEN_10DE")
    if (-not $isNvidia) { continue }
    $devId = $null
    if ($pnp -match "DEV_([0-9A-Fa-f]{4})") {
      $devId = ([string]$Matches[1]).ToUpperInvariant()
    }
    $result += [pscustomobject]@{
      Name           = $name
      DriverVersion  = [string]$a.DriverVersion
      PNPDeviceID    = $pnp
      DeviceId       = $devId
      Status         = [string]$a.Status
    }
  }
  return $result
}

function Get-OllamaGpuEnvironment {
  <#
  .SYNOPSIS
    Summarize whether this machine (including VMs) can use a GPU with Ollama,
    and whether installing NVIDIA drivers in this OS makes sense.
  #>
  $vm = Get-VirtualMachineInfo
  $nvidia = @(Get-NvidiaDisplayAdapters)
  $nvidiaPresent = $nvidia.Count -gt 0

  $virtualOnly = $false
  if ($vm.IsVirtualMachine -and -not $nvidiaPresent) {
    $virtualOnly = $true
  }

  $canUseGpu = $false
  $canInstallDrivers = $false
  $guidance = New-Object System.Collections.Generic.List[string]

  if ($nvidiaPresent) {
    $canUseGpu = $true
    $canInstallDrivers = $true
    if ($vm.IsVirtualMachine) {
      [void]$guidance.Add("VM with an NVIDIA device visible - GPU acceleration is possible (passthrough, GPU-P, GRID/vGPU, or cloud GPU).")
      [void]$guidance.Add("Install NVIDIA drivers inside this guest (GeForce/Studio for consumer passthrough; GRID/vGPU drivers for enterprise/cloud vGPU).")
      [void]$guidance.Add("After install, restart the guest and run .\scripts\Test-GpuSupport.ps1")
    } else {
      [void]$guidance.Add("Bare metal NVIDIA GPU detected - install current Studio/Game Ready drivers (>= 551.61 for Ollama).")
    }
  } elseif ($vm.IsVirtualMachine) {
    [void]$guidance.Add("This OS looks like a VM ($($vm.Hypervisor)) with no NVIDIA device in the guest.")
    [void]$guidance.Add("Installing NVIDIA drivers here will NOT unlock a host GPU - the hypervisor must expose one first.")
    [void]$guidance.Add("Options: PCIe passthrough (Hyper-V DDA / VMware / Proxmox), Hyper-V GPU Partitioning (GPU-P), or a cloud GPU VM.")
    [void]$guidance.Add("Until then, run Ollama on CPU (.\scripts\Setup-Machine.ps1 -Tier 8GB or 16GB).")
  } else {
    [void]$guidance.Add("No NVIDIA GPU detected for the CUDA path. Ollama can still run on CPU.")
    [void]$guidance.Add("AMD: use ROCm/Vulkan per Ollama Windows docs. Intel iGPU is usually not useful for coding models.")
  }

  return [pscustomobject]@{
    IsVirtualMachine   = [bool]$vm.IsVirtualMachine
    Hypervisor         = $vm.Hypervisor
    HypervisorPresent  = [bool]$vm.HypervisorPresent
    VmEvidence         = $vm.Evidence
    Manufacturer       = $vm.Manufacturer
    Model              = $vm.Model
    NvidiaPresent      = $nvidiaPresent
    NvidiaAdapters     = $nvidia
    VirtualDisplayOnly = $virtualOnly
    CanUseGpuWithOllama = $canUseGpu
    CanInstallDrivers  = $canInstallDrivers
    Guidance           = @($guidance)
  }
}

function Get-NvidiaDriverLookupIds {
  <#
  .SYNOPSIS
    Heuristic NVIDIA product-series / product IDs for AjaxDriverService lookup.
  #>
  param([string] $GpuName = "")

  # osID 57 = Windows 10/11 64-bit (DCH). pfid picks a representative chip in-series.
  # Series IDs evolve; lookup fails -> caller should open the download page.
  $psid = 129  # GeForce RTX 40 Series (default modern desktop)
  $pfid = 985  # RTX 4090 stand-in for latest GRD/Studio channel

  if ($GpuName -match "RTX\s*50") { $psid = 139; $pfid = 1025 }
  elseif ($GpuName -match "RTX\s*40") { $psid = 129; $pfid = 985 }
  elseif ($GpuName -match "RTX\s*30") { $psid = 120; $pfid = 929 }
  elseif ($GpuName -match "RTX\s*20|TITAN RTX") { $psid = 101; $pfid = 859 }
  elseif ($GpuName -match "GTX\s*16") { $psid = 101; $pfid = 907 }
  elseif ($GpuName -match "GTX\s*10") { $psid = 101; $pfid = 845 }
  elseif ($GpuName -match "Quadro|RTX A|Tesla|GRID") {
    # Enterprise: still try GeForce channel; caller should prefer NVIDIA enterprise page if this fails
    $psid = 129; $pfid = 985
  }

  return [pscustomobject]@{
    ProductSeriesId = $psid
    ProductId       = $pfid
    OsId            = 57
  }
}

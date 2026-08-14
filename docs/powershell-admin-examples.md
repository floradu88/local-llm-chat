# PowerShell: admin (elevated) examples

Most of this toolkit is **non-admin**. Use elevation only for driver/device diagnostics (or when Windows policy blocks a per-user install).

## Pattern A — built-in `-Elevated` switch (preferred for GPU)

```powershell
cd D:\code\projects\local-llm-chat   # your clone path

# 1) Non-admin first (always)
.\scripts\Test-GpuSupport.ps1

# 2) Same script + admin driver/device section (UAC prompt)
.\scripts\Test-GpuSupport.ps1 -Elevated

# 3) Save full report (non-admin + admin sections)
.\scripts\Test-GpuSupport.ps1 -Elevated -OutFile "$env:TEMP\ollama-gpu-report.txt"
notepad "$env:TEMP\ollama-gpu-report.txt"
```

## Pattern B — elevate any script via helper

```powershell
cd D:\code\projects\local-llm-chat

# Run the GPU elevated helper alone and write its output file
$out = Join-Path $env:TEMP "gpu-admin-only.txt"
.\scripts\Invoke-Elevated.ps1 `
  -ScriptPath ".\scripts\Test-GpuSupport.Elevated.ps1" `
  -ArgumentList @("-OutFile", $out)

Get-Content $out
```

## Pattern C — one-liner `Start-Process -Verb RunAs` (same idea)

```powershell
cd D:\code\projects\local-llm-chat
$out = "$env:TEMP\gpu-admin-only.txt"
$script = (Resolve-Path ".\scripts\Test-GpuSupport.Elevated.ps1").Path

Start-Process -FilePath "powershell.exe" -Verb RunAs -Wait -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $script,
  "-OutFile", $out
)

Get-Content $out
```

## What the elevated GPU check runs (admin)

These are the checks already wrapped in `Test-GpuSupport.Elevated.ps1`:

```powershell
# (inside elevated session)
whoami /groups | Select-String "Administrators"
pnputil /enum-devices /class Display
driverquery /v | Select-String "NVIDIA|nvlddmkm|BasicDisplay|Indirect"
& "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
```

## Other toolkit commands (usually stay non-admin)

```powershell
# Install / pull / verify / editor wire — no admin
.\scripts\Setup-Machine.ps1 -Tier Auto
.\scripts\Install-Cursor.ps1
.\scripts\Install-VSCodeLocalAI.ps1     # Continue chat + Cline agent
.\scripts\Install-CursorConfig.ps1      # quit Cursor first
.\scripts\Show-SetupStatus.ps1
.\scripts\Test-LocalSetup.ps1

# GPU detect / optional drivers (Install may prompt UAC)
.\scripts\Test-GpuSupport.ps1
.\scripts\Install-GpuDrivers.ps1
.\scripts\Install-GpuDrivers.ps1 -Install

# Only elevate if you need the GPU admin diagnostics block
.\scripts\Test-GpuSupport.ps1 -Elevated
```

## Notes

- Approving UAC does **not** make an unsupported GPU (e.g. GT 650M / Kepler) work with Ollama.
- Prefer **User** env vars (`Set-OllamaEnv.ps1 -Persistent`) over Machine-level changes.
- If UAC is denied, the non-admin report is still valid for Ollama CPU vs GPU verdict.
- VMs need a host-exposed NVIDIA device before guest driver install helps — see `Install-GpuDrivers.ps1`.
- Cursor install and Models config are per-user and do not need elevation (`Install-Cursor.ps1`, `Install-CursorConfig.ps1`).
- VS Code Local AI is per-user (`Install-VSCodeLocalAI.ps1` / Continue + Cline; verify with `Test-VSCodeSetup.ps1`).
- Headroom does **not** need admin when installed via `Install-Headroom.ps1` (`C:\hr`). Enabling Windows Long Paths (only needed for Store/user-site pip) **does** need admin — prefer the short venv instead.

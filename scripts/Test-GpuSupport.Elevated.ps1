# Elevated helper for Test-GpuSupport.ps1 (launched via UAC).
# Not meant to be run alone unless debugging.
param(
  [Parameter(Mandatory = $true)]
  [string] $OutFile
)

$ErrorActionPreference = "Continue"
$lines = New-Object System.Collections.Generic.List[string]
function Add-L([string] $s) { [void]$lines.Add($s) }

Add-L "Elevated whoami (Administrators group):"
whoami /groups | Select-String "S-1-5-32-544|Administrators" | ForEach-Object { Add-L $_.Line }
Add-L ""
Add-L "pnputil Display class:"
pnputil /enum-devices /class Display | ForEach-Object { Add-L $_ }
Add-L ""
Add-L "nvlddmkm / display drivers:"
driverquery /v | Select-String -Pattern "NVIDIA|nvlddmkm|BasicDisplay|Indirect" | Select-Object -First 50 | ForEach-Object { Add-L $_.Line }
Add-L ""
$nvsmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvsmi) {
  Add-L "nvidia-smi (elevated):"
  & $nvsmi | ForEach-Object { Add-L $_ }
} else {
  Add-L "nvidia-smi missing under Program Files"
}
Add-L ""
Add-L "Note: Admin cannot unlock Ollama GPU if the GPU is below CC 5.0 or the driver is too old."
$lines | Set-Content -Path $OutFile -Encoding utf8

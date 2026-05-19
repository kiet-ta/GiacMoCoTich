param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8765,
    [string]$Python = ".\.venv\Scripts\python.exe",
    [string]$Checkpoint = "",
    [switch]$AllowUntrained
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Python)) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw "Python was not found. Install Python 3.10 or pass -Python <path>."
    }
    $Python = $cmd.Source
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PYTHONPATH = "$root\ml_sidecar;$root\research\lewm"
$env:LEWM_ACTION_DIM = "8"
if ($Checkpoint -ne "") {
    $env:LEWM_CHECKPOINT = $Checkpoint
}
if ($AllowUntrained) {
    $env:LEWM_ALLOW_UNTRAINED = "1"
}

& $Python -m uvicorn lewm_sidecar.app:app --host $HostName --port $Port

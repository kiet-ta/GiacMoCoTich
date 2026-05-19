param(
    [ValidateSet("chapter_1", "chapter_2", "chapter_3")]
    [string]$Chapter = "chapter_2",
    [string]$Python = ".\.venv\Scripts\python.exe",
    [switch]$AllowMissing
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
$env:PYTHONPATH = "$root\research\lewm"
$suffix = $Chapter.Replace("_", "")
$config = Join-Path $root "research\lewm\configs\train_lewm_$suffix.yaml"
if ($Chapter -eq "chapter_1") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter1.yaml"
} elseif ($Chapter -eq "chapter_2") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter2.yaml"
} elseif ($Chapter -eq "chapter_3") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter3.yaml"
}

$argsList = @(
    "$root\research\lewm\scripts\inspect_dataset.py",
    "--config",
    $config,
    "--output",
    "$root\models\lewm\$Chapter\dataset_inspection.json"
)

if ($AllowMissing) {
    $argsList += "--allow-missing"
}

& $Python @argsList

param(
    [ValidateSet("chapter_1", "chapter_2", "chapter_3")]
    [string]$Chapter = "chapter_2",
    [string]$Python = ".\.venv\Scripts\python.exe"
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
$config = Join-Path $root "research\lewm\configs\train_lewm_$($Chapter.Replace('_', '')).yaml"
if ($Chapter -eq "chapter_1") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter1.yaml"
} elseif ($Chapter -eq "chapter_2") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter2.yaml"
} elseif ($Chapter -eq "chapter_3") {
    $config = Join-Path $root "research\lewm\configs\train_lewm_chapter3.yaml"
}

& $Python "$root\research\lewm\scripts\train.py" --config $config

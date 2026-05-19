param(
    [ValidateSet("human", "scripted")]
    [string]$Mode = "scripted",
    [ValidateSet("mixed", "melee_spam", "kite_bow", "corner_hold", "switch_bait")]
    [string]$Profile = "mixed",
    [int]$DurationSeconds = 180,
    [int]$ImageSize = 128,
    [double]$CaptureInterval = 0.10,
    [int]$Seed = 42,
    [string]$Godot = "godot",
    [switch]$UseML
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$godotArgs = @(
    "--path",
    $root,
    "--scene",
    "res://scenes/Chapter2Boss.tscn",
    "--",
    "--lewm-record",
    "--lewm-image-size=$ImageSize",
    "--lewm-capture-interval=$CaptureInterval",
    "--lewm-seed=$Seed"
)

if (-not $UseML) {
    $godotArgs += "--lewm-no-ml"
}

if ($Mode -eq "scripted") {
    $godotArgs += "--lewm-scripted"
    $godotArgs += "--lewm-scripted-profile=$Profile"
    $godotArgs += "--lewm-scripted-duration=$DurationSeconds"
}

& $Godot @godotArgs

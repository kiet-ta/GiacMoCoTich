param(
    [string]$GodotConsole = "D:\Godot\godot_console.exe"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GodotUserRoot = Join-Path $ProjectRoot ".codex_godot_user"
$AppData = Join-Path $GodotUserRoot "AppData"
$LocalAppData = Join-Path $GodotUserRoot "LocalAppData"

if (Test-Path $GodotUserRoot) {
    Remove-Item -LiteralPath $GodotUserRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $AppData, $LocalAppData | Out-Null

$env:APPDATA = $AppData
$env:LOCALAPPDATA = $LocalAppData

Push-Location $ProjectRoot
try {
    function Invoke-GodotCheck {
        param(
            [string]$FailureMessage,
            [string]$LogFile,
            [string[]]$Arguments
        )

        & $GodotConsole @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$FailureMessage with exit code $LASTEXITCODE" }

        if ((Test-Path $LogFile) -and (Select-String -Path $LogFile -Pattern "SCRIPT ERROR|Parse Error|ERROR:|Failed to load" -Quiet)) {
            Get-Content -Raw -LiteralPath $LogFile | Write-Error
            throw "$FailureMessage because Godot logged errors"
        }
    }

    & $GodotConsole --headless --path . --log-file godot_console_test.log --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot project parse failed with exit code $LASTEXITCODE" }
    if (Select-String -Path godot_console_test.log -Pattern "SCRIPT ERROR|Parse Error|ERROR:|Failed to load" -Quiet) {
        Get-Content -Raw -LiteralPath godot_console_test.log | Write-Error
        throw "Godot project parse logged errors"
    }

    Invoke-GodotCheck "GameRoot scene failed" "game_root_scene.log" @("--headless", "--path", ".", "--scene", "res://scenes/GameRoot.tscn", "--log-file", "game_root_scene.log", "--quit-after", "3")

    Invoke-GodotCheck "Chapter 1 scene failed" "chapter1.log" @("--headless", "--path", ".", "--scene", "res://scenes/Chapter1Forest.tscn", "--log-file", "chapter1.log", "--quit-after", "5")

    Invoke-GodotCheck "Chapter 2 scene failed" "chapter2.log" @("--headless", "--path", ".", "--scene", "res://scenes/Chapter2Boss.tscn", "--log-file", "chapter2.log", "--quit-after", "5")

    Invoke-GodotCheck "Chapter 3 scene failed" "chapter3.log" @("--headless", "--path", ".", "--scene", "res://scenes/Chapter3Climb.tscn", "--log-file", "chapter3.log", "--quit-after", "5")

    & $GodotConsole --headless --path . --script res://scripts/tests/SmokeTest.gd
    if ($LASTEXITCODE -ne 0) { throw "Smoke test failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

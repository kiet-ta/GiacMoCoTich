param(
    [ValidateSet("chapter_1", "chapter_2", "chapter_3")]
    [string]$Chapter = "chapter_2",
    [string]$GodotPath = "D:\Godot\godot.exe",
    [string]$Python = ".\.venv\Scripts\python.exe",
    [int]$ImageSize = 128,
    [double]$CaptureInterval = 0.10,
    [int]$BenchmarkBatchSize = 32,
    [int]$BenchmarkSteps = 30,
    [string]$SidecarHost = "127.0.0.1",
    [int]$SidecarPort = 8765,
    [switch]$CollectWithMl,
    [switch]$SkipGameplay,
    [switch]$SkipTrain,
    [switch]$SkipBenchmark,
    [switch]$NoSidecarRestart,
    [switch]$KeepExistingSidecar
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

function Invoke-LeWMStep {
    param(
        [string]$Name,
        [scriptblock]$Block
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Block
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "Step failed: $Name (exit code $LASTEXITCODE)"
    }
}

function Stop-LeWMSidecarOnPort {
    param([int]$Port)

    $matches = netstat -ano | Select-String -Pattern "^\s*TCP\s+\S+:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$"
    $pids = @()
    foreach ($match in $matches) {
        $pidText = $match.Matches[0].Groups[1].Value
        if ($pidText -ne "" -and $pidText -ne "0") {
            $pids += [int]$pidText
        }
    }
    $pids = $pids | Sort-Object -Unique
    foreach ($pidValue in $pids) {
        Write-Host "Stopping existing sidecar process on port ${Port}: PID $pidValue"
        Stop-Process -Id $pidValue -Force -ErrorAction Stop
    }
}

if (-not $SkipGameplay) {
    Invoke-LeWMStep "Open Godot and record human gameplay" {
        if (-not (Test-Path $GodotPath)) {
            throw "Godot executable was not found: $GodotPath"
        }

        $godotArgs = @(
            "--path",
            $root,
            "--",
            "--lewm-record",
            "--lewm-image-size=$ImageSize",
            "--lewm-capture-interval=$CaptureInterval"
        )
        if (-not $CollectWithMl) {
            $godotArgs += "--lewm-no-ml"
        }

        $game = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs -PassThru
        Write-Host "Godot started with PID $($game.Id). Play the game, then close the Godot game window to continue training."
        Wait-Process -Id $game.Id
        Write-Host "Godot closed. Continuing LeWM pipeline."
    }
}

Invoke-LeWMStep "Inspect LeWM dataset" {
    & "$root\tools\inspect_lewm_dataset.ps1" -Chapter $Chapter -Python $Python
}

if (-not $SkipTrain) {
    Invoke-LeWMStep "Train LeWM checkpoint" {
        & "$root\tools\train_lewm_chapter.ps1" -Chapter $Chapter -Python $Python
    }
}

Invoke-LeWMStep "Evaluate LeWM checkpoint" {
    & "$root\tools\evaluate_lewm_checkpoint.ps1" -Chapter $Chapter -Python $Python
}

if (-not $SkipBenchmark) {
    Invoke-LeWMStep "Benchmark LeWM training device" {
        & "$root\tools\benchmark_lewm_device.ps1" -Chapter $Chapter -Python $Python -BatchSize $BenchmarkBatchSize -Steps $BenchmarkSteps
    }
}

if (-not $NoSidecarRestart) {
    Invoke-LeWMStep "Restart LeWM sidecar with latest checkpoint" {
        $checkpoint = Join-Path $root "models\lewm\$Chapter\checkpoints\best.pt"
        if (-not (Test-Path $checkpoint)) {
            throw "Checkpoint was not found: $checkpoint"
        }

        if (-not $KeepExistingSidecar) {
            Stop-LeWMSidecarOnPort -Port $SidecarPort
        }

        $sidecarArgs = @(
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            "$root\tools\start_lewm_sidecar.ps1",
            "-HostName",
            $SidecarHost,
            "-Port",
            "$SidecarPort",
            "-Python",
            $Python,
            "-Checkpoint",
            $checkpoint
        )
        $sidecar = Start-Process -FilePath "powershell" -ArgumentList $sidecarArgs -WorkingDirectory $root -WindowStyle Hidden -PassThru
        Write-Host "Sidecar started with PID $($sidecar.Id)."

        $health = $null
        for ($i = 0; $i -lt 20; $i += 1) {
            Start-Sleep -Seconds 1
            try {
                $health = Invoke-RestMethod "http://${SidecarHost}:$SidecarPort/health" -TimeoutSec 3
                break
            } catch {
                $health = $null
            }
        }

        if ($null -eq $health) {
            throw "Sidecar did not become healthy on http://${SidecarHost}:$SidecarPort/health"
        }

        $health | ConvertTo-Json -Depth 5
    }
}

Write-Host ""
Write-Host "LeWM human training cycle completed." -ForegroundColor Green

[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    param([string]$Preferred)

    if ($Preferred -and (Test-Path $Preferred)) {
        return (Resolve-Path $Preferred).Path
    }

    foreach ($Candidate in @('godot', 'godot4', 'Godot_v4.6.2-stable_win64_console.exe', 'Godot_v4.6.2-stable_win64.exe')) {
        $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
        if ($Command) {
            return $Command.Source
        }
    }

    return $null
}

Write-Host 'Validating Obsidian Ring...' -ForegroundColor Cyan

$Required = @(
    'project.godot',
    'scenes/main.tscn',
    'scripts/main.gd',
    'data/teams.json',
    'data/rules.json',
    'docs/GAME_DESIGN.md'
)

foreach ($RelativePath in $Required) {
    $Path = Join-Path $Root $RelativePath
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $RelativePath"
    }
}

foreach ($JsonPath in @('data/teams.json', 'data/rules.json')) {
    $FullPath = Join-Path $Root $JsonPath
    $null = Get-Content -Raw $FullPath | ConvertFrom-Json
    Write-Host "JSON OK: $JsonPath" -ForegroundColor DarkGreen
}

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural and JSON validation passed; engine smoke test skipped.'
    exit 0
}

Write-Host "Godot: $Godot" -ForegroundColor DarkGray
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot headless validation failed with exit code $LASTEXITCODE"
}

Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

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
        if ($Command) { return $Command.Source }
    }

    return $null
}

Write-Host 'Validating Obsidian Ring...' -ForegroundColor Cyan

$JsonFiles = @(
    'data/teams.json',
    'data/rules.json',
    'data/courts.json',
    'data/league.json'
)

$Required = @(
    'project.godot',
    'scenes/main.tscn',
    'scripts/main.gd',
    'docs/GAME_DESIGN.md',
    'docs/QA.md'
) + $JsonFiles

foreach ($RelativePath in $Required) {
    $Path = Join-Path $Root $RelativePath
    if (-not (Test-Path $Path)) { throw "Missing required file: $RelativePath" }
}

foreach ($JsonPath in $JsonFiles) {
    $FullPath = Join-Path $Root $JsonPath
    $null = Get-Content -Raw $FullPath | ConvertFrom-Json
    Write-Host "JSON OK: $JsonPath" -ForegroundColor DarkGreen
}

$IdSets = @(
    @{ Path = 'data/teams.json'; Property = 'teams' },
    @{ Path = 'data/courts.json'; Property = 'courts' }
)

foreach ($Set in $IdSets) {
    $Data = Get-Content -Raw (Join-Path $Root $Set.Path) | ConvertFrom-Json
    $Items = $Data.($Set.Property)
    $Ids = @($Items | ForEach-Object { $_.id })
    if ($Ids.Count -ne @($Ids | Sort-Object -Unique).Count) {
        throw "Duplicate ids found in $($Set.Path)"
    }
    if (@($Ids | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw "Blank id found in $($Set.Path)"
    }
    Write-Host "IDs OK: $($Set.Path)" -ForegroundColor DarkGreen
}

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural, JSON and id validation passed; engine smoke test skipped.'
    exit 0
}

Write-Host "Godot: $Godot" -ForegroundColor DarkGray
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }

Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

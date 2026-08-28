[CmdletBinding()]
param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    param([string]$Preferred)
    if ($Preferred -and (Test-Path $Preferred)) { return (Resolve-Path $Preferred).Path }
    foreach ($Candidate in @('godot','godot4','Godot_v4.6.2-stable_win64_console.exe','Godot_v4.6.2-stable_win64.exe')) {
        $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
        if ($Command) { return $Command.Source }
    }
    return $null
}

Write-Host 'Validating Obsidian Ring...' -ForegroundColor Cyan
$Required = @(
    'project.godot','scenes/main.tscn','scripts/main.gd','scripts/content_catalog.gd',
    'scripts/match_rules.gd','scripts/team_play_rules.gd','scripts/league_rules.gd',
    'data/teams.json','data/rules.json','data/courts.json','data/league.json','data/player_roles.json',
    'docs/GAME_DESIGN.md','docs/ARCHITECTURE.md','docs/QA.md'
)
foreach ($RelativePath in $Required) {
    if (-not (Test-Path (Join-Path $Root $RelativePath))) { throw "Missing required file: $RelativePath" }
}

$Parsed = @{}
foreach ($JsonPath in @('data/teams.json','data/rules.json','data/courts.json','data/league.json','data/player_roles.json')) {
    $Data = Get-Content -Raw (Join-Path $Root $JsonPath) | ConvertFrom-Json
    $Parsed[$JsonPath] = $Data
    Write-Host "JSON OK: $JsonPath" -ForegroundColor DarkGreen
    foreach ($CollectionName in @('teams','rulesets','courts','roles')) {
        $Collection = $Data.$CollectionName
        if ($null -eq $Collection) { continue }
        $Ids = @($Collection | ForEach-Object { $_.id })
        if ($Ids -contains $null -or $Ids -contains '') { throw "Blank id in $JsonPath/$CollectionName" }
        if (@($Ids | Sort-Object -Unique).Count -ne $Ids.Count) { throw "Duplicate id in $JsonPath/$CollectionName" }
    }
}

$CourtIds = @($Parsed['data/courts.json'].courts | ForEach-Object { $_.id })
foreach ($Team in $Parsed['data/teams.json'].teams) {
    if ($Team.home_court -and $CourtIds -notcontains $Team.home_court) { throw "Team home_court not found: $($Team.id) -> $($Team.home_court)" }
    foreach ($Rating in @('attack','defence','speed','discipline')) {
        $Value = [int]$Team.$Rating
        if ($Value -lt 1 -or $Value -gt 10) { throw "Team rating out of range 1..10: $($Team.id).$Rating=$Value" }
    }
}

$RoleIds = @($Parsed['data/player_roles.json'].roles | ForEach-Object { $_.id })
foreach ($RequiredRole in @('runner','striker','guard')) {
    if ($RoleIds -notcontains $RequiredRole) { throw "Missing required player role: $RequiredRole" }
}
foreach ($Role in $Parsed['data/player_roles.json'].roles) {
    foreach ($Multiplier in @('speed','stamina','tackle','passing','shooting')) {
        if ([double]$Role.$Multiplier -le 0) { throw "Role multiplier must be positive: $($Role.id).$Multiplier" }
    }
}

$League = $Parsed['data/league.json'].league
if ([int]$League.win_points -le [int]$League.draw_points) { throw 'League win_points must exceed draw_points.' }
if ([int]$League.playoff_teams -gt @($Parsed['data/teams.json'].teams).Count) { throw 'playoff_teams cannot exceed team count.' }

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural, role, league and cross-reference validation passed; engine smoke test skipped.'
    exit 0
}
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

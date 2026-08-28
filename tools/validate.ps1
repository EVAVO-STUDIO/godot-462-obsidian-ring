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
    'scripts/match_rules.gd','scripts/team_play_rules.gd','scripts/league_rules.gd','scripts/season_save.gd',
    'data/teams.json','data/rules.json','data/courts.json','data/league.json','data/player_roles.json',
    'data/rosters.json','data/fixtures.json','docs/GAME_DESIGN.md','docs/ARCHITECTURE.md','docs/QA.md'
)
foreach ($RelativePath in $Required) {
    if (-not (Test-Path (Join-Path $Root $RelativePath))) { throw "Missing required file: $RelativePath" }
}

$Parsed = @{}
foreach ($JsonPath in @('data/teams.json','data/rules.json','data/courts.json','data/league.json','data/player_roles.json','data/rosters.json','data/fixtures.json')) {
    $Data = Get-Content -Raw (Join-Path $Root $JsonPath) | ConvertFrom-Json
    $Parsed[$JsonPath] = $Data
    Write-Host "JSON OK: $JsonPath" -ForegroundColor DarkGreen
    foreach ($CollectionName in @('teams','rulesets','courts','roles','rosters','rounds')) {
        $Collection = $Data.$CollectionName
        if ($null -eq $Collection) { continue }
        if ($CollectionName -in @('rosters','rounds')) { continue }
        $Ids = @($Collection | ForEach-Object { $_.id })
        if ($Ids -contains $null -or $Ids -contains '') { throw "Blank id in $JsonPath/$CollectionName" }
        if (@($Ids | Sort-Object -Unique).Count -ne $Ids.Count) { throw "Duplicate id in $JsonPath/$CollectionName" }
    }
}

$Teams = @($Parsed['data/teams.json'].teams)
$TeamIds = @($Teams | ForEach-Object { $_.id })
$CourtIds = @($Parsed['data/courts.json'].courts | ForEach-Object { $_.id })
foreach ($Team in $Teams) {
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

$AllPlayerIds = @()
$RosterTeamIds = @()
foreach ($Roster in $Parsed['data/rosters.json'].rosters) {
    if ($TeamIds -notcontains $Roster.team_id) { throw "Roster references unknown team: $($Roster.team_id)" }
    $RosterTeamIds += $Roster.team_id
    if (@($Roster.players).Count -lt 5) { throw "Roster must contain at least five players: $($Roster.team_id)" }
    foreach ($Player in $Roster.players) {
        if (-not $Player.id -or -not $Player.name) { throw "Roster player missing id/name: $($Roster.team_id)" }
        if ($RoleIds -notcontains $Player.role) { throw "Player references unknown role: $($Player.id) -> $($Player.role)" }
        if ([int]$Player.skill -lt 1 -or [int]$Player.skill -gt 10) { throw "Player skill out of range: $($Player.id)" }
        $AllPlayerIds += $Player.id
    }
}
if (@($RosterTeamIds | Sort-Object -Unique).Count -ne $TeamIds.Count) { throw 'Every team must have exactly one roster.' }
if (@($AllPlayerIds | Sort-Object -Unique).Count -ne $AllPlayerIds.Count) { throw 'Roster player ids must be globally unique.' }

$SeenRounds = @()
foreach ($Round in $Parsed['data/fixtures.json'].rounds) {
    $RoundNo = [int]$Round.round
    if ($RoundNo -le 0 -or $SeenRounds -contains $RoundNo) { throw "Invalid or duplicate fixture round: $RoundNo" }
    $SeenRounds += $RoundNo
    $SeenTeams = @()
    foreach ($Fixture in $Round.fixtures) {
        if ($TeamIds -notcontains $Fixture.home -or $TeamIds -notcontains $Fixture.away) { throw "Fixture references unknown team in round $RoundNo" }
        if ($Fixture.home -eq $Fixture.away) { throw "Team cannot play itself in round $RoundNo" }
        if ($SeenTeams -contains $Fixture.home -or $SeenTeams -contains $Fixture.away) { throw "Team appears twice in round $RoundNo" }
        $SeenTeams += @($Fixture.home,$Fixture.away)
    }
}

$League = $Parsed['data/league.json'].league
if ([int]$League.win_points -le [int]$League.draw_points) { throw 'League win_points must exceed draw_points.' }
if ([int]$League.playoff_teams -gt $Teams.Count) { throw 'playoff_teams cannot exceed team count.' }
if (@($Parsed['data/fixtures.json'].rounds).Count -ne [int]$League.season_rounds) { throw 'Fixture round count must equal league season_rounds.' }

$ProjectText = Get-Content -Raw (Join-Path $Root 'project.godot')
if ($ProjectText -notmatch 'SeasonSave="\*res://scripts/season_save.gd"') { throw 'SeasonSave autoload is not configured.' }

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural, save, roster, fixture, role and league validation passed; engine smoke test skipped.'
    exit 0
}
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

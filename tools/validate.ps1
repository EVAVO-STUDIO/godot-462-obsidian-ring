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

function Assert-UniqueIds($Collection, [string]$Label) {
    $Ids = @($Collection | ForEach-Object { $_.id })
    if ($Ids -contains $null -or $Ids -contains '') { throw "Blank id in $Label" }
    if (@($Ids | Sort-Object -Unique).Count -ne $Ids.Count) { throw "Duplicate id in $Label" }
}

Write-Host 'Validating Obsidian Ring...' -ForegroundColor Cyan
$Required = @(
    'project.godot','scenes/main.tscn','scripts/main.gd','scripts/content_catalog.gd',
    'scripts/match_rules.gd','scripts/team_play_rules.gd','scripts/league_rules.gd','scripts/roster_rules.gd',
    'scripts/discipline_rules.gd','scripts/playoff_rules.gd','scripts/season_save.gd','scripts/season_director.gd',
    'scripts/match_substitution_director.gd','scripts/fatigue_director.gd','tools/runtime_self_test.gd',
    'data/teams.json','data/rules.json','data/courts.json','data/league.json','data/player_roles.json','data/rosters.json','data/fixtures.json',
    'docs/GAME_DESIGN.md','docs/ARCHITECTURE.md','docs/QA.md'
)
foreach ($RelativePath in $Required) {
    if (-not (Test-Path (Join-Path $Root $RelativePath))) { throw "Missing required file: $RelativePath" }
}
foreach ($Forbidden in @('.github/workflows','.godot','build','dist')) {
    if (Test-Path (Join-Path $Root $Forbidden)) { throw "Forbidden generated/paid-CI path committed: $Forbidden" }
}

$Teams = Get-Content -Raw (Join-Path $Root 'data/teams.json') | ConvertFrom-Json
$Rules = Get-Content -Raw (Join-Path $Root 'data/rules.json') | ConvertFrom-Json
$Courts = Get-Content -Raw (Join-Path $Root 'data/courts.json') | ConvertFrom-Json
$LeagueData = Get-Content -Raw (Join-Path $Root 'data/league.json') | ConvertFrom-Json
$Roles = Get-Content -Raw (Join-Path $Root 'data/player_roles.json') | ConvertFrom-Json
$Rosters = Get-Content -Raw (Join-Path $Root 'data/rosters.json') | ConvertFrom-Json
$Fixtures = Get-Content -Raw (Join-Path $Root 'data/fixtures.json') | ConvertFrom-Json
Assert-UniqueIds $Teams.teams 'teams'
Assert-UniqueIds $Rules.rulesets 'rulesets'
Assert-UniqueIds $Courts.courts 'courts'
Assert-UniqueIds $Roles.roles 'roles'

$TeamIds = @($Teams.teams | ForEach-Object { $_.id })
$CourtIds = @($Courts.courts | ForEach-Object { $_.id })
$RoleIds = @($Roles.roles | ForEach-Object { $_.id })
foreach ($Team in $Teams.teams) {
    if ($CourtIds -notcontains $Team.home_court) { throw "Unknown team home court: $($Team.id) -> $($Team.home_court)" }
    foreach ($Rating in @('attack','defence','speed','discipline')) {
        $Value = [int]$Team.$Rating
        if ($Value -lt 1 -or $Value -gt 10) { throw "Team rating out of range: $($Team.id).$Rating=$Value" }
    }
}
foreach ($RequiredRole in @('runner','striker','guard')) { if ($RoleIds -notcontains $RequiredRole) { throw "Missing required role: $RequiredRole" } }
foreach ($Role in $Roles.roles) {
    foreach ($Field in @('speed','stamina','tackle','passing','shooting')) { if ([double]$Role.$Field -le 0) { throw "Role multiplier must be positive: $($Role.id).$Field" } }
    if ([int]$Role.toughness -lt 1 -or [int]$Role.toughness -gt 10) { throw "Role toughness out of range: $($Role.id)" }
}

$RosterTeams = @()
$PlayerIds = @()
foreach ($Roster in $Rosters.rosters) {
    if ($TeamIds -notcontains $Roster.team_id) { throw "Roster references unknown team: $($Roster.team_id)" }
    if ($RosterTeams -contains $Roster.team_id) { throw "Duplicate roster: $($Roster.team_id)" }
    $RosterTeams += $Roster.team_id
    if (@($Roster.players).Count -lt 5) { throw "Roster needs at least five players: $($Roster.team_id)" }
    $RosterRoles = @($Roster.players | ForEach-Object { $_.role })
    foreach ($RequiredRole in @('runner','striker','guard')) { if ($RosterRoles -notcontains $RequiredRole) { throw "Roster lacks $RequiredRole: $($Roster.team_id)" } }
    foreach ($Player in $Roster.players) {
        if (-not $Player.id -or -not $Player.name) { throw "Player missing id/name: $($Roster.team_id)" }
        if ($RoleIds -notcontains $Player.role) { throw "Unknown player role: $($Player.id) -> $($Player.role)" }
        if ([int]$Player.skill -lt 1 -or [int]$Player.skill -gt 10) { throw "Player skill out of range: $($Player.id)" }
        foreach ($Field in @('injury_matches','suspension_matches','booking_points')) {
            if ($null -ne $Player.$Field -and [int]$Player.$Field -lt 0) { throw "Negative player state: $($Player.id).$Field" }
        }
        $PlayerIds += $Player.id
    }
}
if (@($RosterTeams | Sort-Object -Unique).Count -ne $TeamIds.Count) { throw 'Every team must have exactly one roster.' }
if (@($PlayerIds | Sort-Object -Unique).Count -ne $PlayerIds.Count) { throw 'Player IDs must be globally unique.' }

$League = $LeagueData.league
$Career = $LeagueData.career
$Playoffs = $LeagueData.playoffs
if ([int]$League.win_points -le [int]$League.draw_points) { throw 'win_points must exceed draw_points.' }
if ([int]$League.draw_points -lt [int]$League.loss_points) { throw 'draw_points cannot be below loss_points.' }
if ([int]$League.playoff_teams -ne 4) { throw 'Current playoff implementation requires four qualifiers.' }
if ([int]$League.booking_threshold -lt 1 -or [int]$League.suspension_matches -lt 1) { throw 'Booking/suspension settings must be positive.' }
if ([int]$Career.training_cost_base -le 0 -or [int]$Career.medical_cost_base -le 0) { throw 'Training/medical costs must be positive.' }
if ([bool]$Playoffs.enabled) {
    if ($Playoffs.semifinal_pairing -ne '1v4_2v3') { throw 'Unsupported semifinal pairing.' }
    if ($Playoffs.draw_tiebreak -ne 'table_seed') { throw 'Unsupported playoff draw tiebreak.' }
    if ([int]$Playoffs.championship_purse -lt 0) { throw 'Championship purse cannot be negative.' }
}

$SeenRounds = @()
foreach ($Round in $Fixtures.rounds) {
    $RoundNo = [int]$Round.round
    if ($RoundNo -le 0 -or $SeenRounds -contains $RoundNo) { throw "Invalid fixture round: $RoundNo" }
    $SeenRounds += $RoundNo
    $SeenTeams = @()
    foreach ($Fixture in $Round.fixtures) {
        if ($TeamIds -notcontains $Fixture.home -or $TeamIds -notcontains $Fixture.away) { throw "Unknown fixture team in round $RoundNo" }
        if ($Fixture.home -eq $Fixture.away) { throw "Self fixture in round $RoundNo" }
        if ($SeenTeams -contains $Fixture.home -or $SeenTeams -contains $Fixture.away) { throw "Team appears twice in round $RoundNo" }
        $SeenTeams += @($Fixture.home,$Fixture.away)
    }
    if (@($SeenTeams | Sort-Object -Unique).Count -ne $TeamIds.Count) { throw "Every team must appear once in round $RoundNo" }
}
if (@($Fixtures.rounds).Count -ne [int]$League.season_rounds) { throw 'Fixture round count must equal season_rounds.' }

$ProjectText = Get-Content -Raw (Join-Path $Root 'project.godot')
foreach ($Autoload in @(
    'SeasonSave="*res://scripts/season_save.gd"',
    'SeasonDirector="*res://scripts/season_director.gd"',
    'MatchSubstitutionDirector="*res://scripts/match_substitution_director.gd"',
    'FatigueDirector="*res://scripts/fatigue_director.gd"'
)) {
    if (-not $ProjectText.Contains($Autoload)) { throw "Missing autoload: $Autoload" }
}
$SeasonDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/season_director.gd')
foreach ($Token in @('DisciplineRules.apply_booking','PlayoffRules.semifinal_pairings','championship_purse','SAVE_VERSION := 2','season_rounds')) {
    if (-not $SeasonDirectorText.Contains($Token)) { throw "SeasonDirector missing integration token: $Token" }
}
$SubText = Get-Content -Raw (Join-Path $Root 'scripts/match_substitution_director.gd')
foreach ($Token in @('KEY_V','SUBSTITUTIONS_PER_MATCH','request_emergency_substitution','_substitute_player','suspension_matches')) {
    if (-not $SubText.Contains($Token)) { throw "Match substitution director missing token: $Token" }
}
$FatigueText = Get-Content -Raw (Join-Path $Root 'scripts/fatigue_director.gd')
foreach ($Token in @('LOW_STAMINA_THRESHOLD','CRITICAL_STAMINA_THRESHOLD','base_speed_mult','request_emergency_substitution','performance_factor_for_stamina')) {
    if (-not $FatigueText.Contains($Token)) { throw "FatigueDirector missing token: $Token" }
}
$SaveText = Get-Content -Raw (Join-Path $Root 'scripts/season_save.gd')
foreach ($Token in @('_sanitize_table','_sanitize_rosters','MAX_FUNDS','max_reasonable_round')) {
    if (-not $SaveText.Contains($Token)) { throw "Season save missing hardening token: $Token" }
}

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural/data/director/save validation passed; runtime self-test and engine smoke test skipped.'
    exit 0
}

Write-Host 'Running deterministic runtime rules self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/runtime_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring runtime self-test failed with exit code $LASTEXITCODE" }

Write-Host 'Running Godot editor smoke test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

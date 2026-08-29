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
    'scripts/match_rules.gd','scripts/team_play_rules.gd','scripts/league_rules.gd','scripts/roster_rules.gd','scripts/roster_save_rules.gd',
    'scripts/discipline_rules.gd','scripts/discipline_policy_director.gd','scripts/playoff_rules.gd','scripts/season_save.gd','scripts/save_recovery_rules.gd','scripts/season_director.gd',
    'scripts/match_substitution_director.gd','scripts/condition_rules.gd','scripts/condition_director.gd','scripts/fatigue_director.gd',
    'scripts/court_hazard_rules.gd','scripts/court_hazard_director.gd','scripts/court_geometry_rules.gd','scripts/court_geometry_director.gd',
    'scripts/fixture_simulation_rules.gd','scripts/fixture_simulation_director.gd',
    'scripts/replay_guard_rules.gd','scripts/replay_guard_director.gd','scripts/season_end_rules.gd','scripts/season_end_director.gd',
    'scripts/foul_ledger_rules.gd','scripts/foul_ledger_director.gd','scripts/management_summary_rules.gd','scripts/management_summary_director.gd','scripts/standings_summary_rules.gd','scripts/standings_summary_director.gd',
    'tools/runtime_self_test.gd','tools/court_hazard_self_test.gd','tools/fixture_simulation_self_test.gd','tools/replay_guard_self_test.gd','tools/season_end_self_test.gd','tools/postseason_save_self_test.gd','tools/discipline_policy_self_test.gd','tools/persistence_self_test.gd',
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
$AllowedHazards = @('narrow_sidelines','low_friction','fast_walls')
foreach ($Court in $Courts.courts) {
    if ([double]$Court.width -le 0 -or [double]$Court.height -le 0) { throw "Court dimensions must be positive: $($Court.id)" }
    if ([double]$Court.rebound -le 0 -or [double]$Court.rebound -gt 1.25) { throw "Court rebound out of range: $($Court.id)" }
    foreach ($Hazard in @($Court.hazards)) { if ($AllowedHazards -notcontains $Hazard) { throw "Unknown court hazard: $($Court.id) -> $Hazard" } }
}
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

$RosterTeams = @(); $PlayerIds = @()
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
        foreach ($Field in @('injury_matches','suspension_matches','booking_points','fatigue_carry')) { if ($null -ne $Player.$Field -and [int]$Player.$Field -lt 0) { throw "Negative player state: $($Player.id).$Field" } }
        if ($null -ne $Player.fatigue_carry -and [int]$Player.fatigue_carry -gt 40) { throw "fatigue_carry out of range: $($Player.id)" }
        $PlayerIds += $Player.id
    }
}
if (@($RosterTeams | Sort-Object -Unique).Count -ne $TeamIds.Count) { throw 'Every team must have exactly one roster.' }
if (@($PlayerIds | Sort-Object -Unique).Count -ne $PlayerIds.Count) { throw 'Player IDs must be globally unique.' }

$League = $LeagueData.league; $Career = $LeagueData.career; $Playoffs = $LeagueData.playoffs
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
    'SeasonSave="*res://scripts/season_save.gd"','DisciplinePolicyDirector="*res://scripts/discipline_policy_director.gd"','SeasonDirector="*res://scripts/season_director.gd"',
    'MatchSubstitutionDirector="*res://scripts/match_substitution_director.gd"','ConditionDirector="*res://scripts/condition_director.gd"',
    'FatigueDirector="*res://scripts/fatigue_director.gd"','CourtHazardDirector="*res://scripts/court_hazard_director.gd"',
    'CourtGeometryDirector="*res://scripts/court_geometry_director.gd"','FixtureSimulationDirector="*res://scripts/fixture_simulation_director.gd"',
    'ReplayGuardDirector="*res://scripts/replay_guard_director.gd"','FoulLedgerDirector="*res://scripts/foul_ledger_director.gd"',
    'SeasonEndDirector="*res://scripts/season_end_director.gd"','ManagementSummaryDirector="*res://scripts/management_summary_director.gd"',
    'StandingsSummaryDirector="*res://scripts/standings_summary_director.gd"'
)) { if (-not $ProjectText.Contains($Autoload)) { throw "Missing autoload: $Autoload" } }

$DisciplineRulesText = Get-Content -Raw (Join-Path $Root 'scripts/discipline_rules.gd')
foreach ($Token in @('static var _booking_threshold','static var _suspension_length','configure','booking_threshold_override','suspension_length_override','total - threshold')) { if (-not $DisciplineRulesText.Contains($Token)) { throw "Discipline rules missing config token: $Token" } }
$DisciplinePolicyText = Get-Content -Raw (Join-Path $Root 'scripts/discipline_policy_director.gd')
foreach ($Token in @('process_priority = -250','DisciplineRules.configure','booking_threshold','suspension_matches')) { if (-not $DisciplinePolicyText.Contains($Token)) { throw "Discipline policy director missing token: $Token" } }
$SeasonDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/season_director.gd')
foreach ($Token in @(
    'process_priority = 80','DisciplineRules.apply_booking','FoulLedgerDirector','PlayoffRules.semifinal_pairings','championship_purse',
    'postseason_state','restore_postseason_state','LEGACY_SAVE_PATH','CANONICAL_SAVE_PATH','LEGACY_SAVE_VERSION','_load_legacy_state_if_needed',
    'if FileAccess.file_exists(CANONICAL_SAVE_PATH):'
)) { if (-not $SeasonDirectorText.Contains($Token)) { throw "SeasonDirector missing integration/migration-only token: $Token" } }
foreach ($ForbiddenToken in @('func _save_state()','FileAccess.open(LEGACY_SAVE_PATH, FileAccess.WRITE)','SAVE_PATH := "user://obsidian_ring_postseason.json"')) {
    if ($SeasonDirectorText.Contains($ForbiddenToken)) { throw "SeasonDirector still treats legacy postseason file as active persistence: $ForbiddenToken" }
}
$SubText = Get-Content -Raw (Join-Path $Root 'scripts/match_substitution_director.gd')
foreach ($Token in @('KEY_V','SUBSTITUTIONS_PER_MATCH','request_emergency_substitution','RosterRules.best_substitute_candidate')) { if (-not $SubText.Contains($Token)) { throw "Match substitution director missing token: $Token" } }
$RosterText = Get-Content -Raw (Join-Path $Root 'scripts/roster_rules.gd')
foreach ($Token in @('best_substitute_candidate','preferred_role','suspension_matches')) { if (-not $RosterText.Contains($Token)) { throw "Roster rules missing substitution token: $Token" } }
$RosterSaveText = Get-Content -Raw (Join-Path $Root 'scripts/roster_save_rules.gd')
foreach ($Token in @('merge_rosters','MUTABLE_FIELDS','fatigue_carry','suspension_until_round')) { if (-not $RosterSaveText.Contains($Token)) { throw "Roster save rules missing token: $Token" } }
$ConditionRulesText = Get-Content -Raw (Join-Path $Root 'scripts/condition_rules.gd')
foreach ($Token in @('MAX_FATIGUE_CARRY','carry_from_end_stamina','recover_bench_carry','starting_stamina','capture_stamina')) { if (-not $ConditionRulesText.Contains($Token)) { throw "Condition rules missing token: $Token" } }
$ConditionDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/condition_director.gd')
foreach ($Token in @('process_priority = 150','_played_stamina_by_id','_capture_participants','ConditionRules.capture_stamina','_capture_end_condition','ConditionRules.starting_stamina')) { if (-not $ConditionDirectorText.Contains($Token)) { throw "Condition director missing participant token: $Token" } }
$FatigueText = Get-Content -Raw (Join-Path $Root 'scripts/fatigue_director.gd')
foreach ($Token in @('LOW_STAMINA_THRESHOLD','MIN_PERFORMANCE_MULT','base_speed_mult','request_emergency_substitution')) { if (-not $FatigueText.Contains($Token)) { throw "Fatigue director missing token: $Token" } }
$HazardRulesText = Get-Content -Raw (Join-Path $Root 'scripts/court_hazard_rules.gd')
foreach ($Token in @('low_friction_drag_compensation','effective_rebound','vertical_margin')) { if (-not $HazardRulesText.Contains($Token)) { throw "Court hazard rules missing token: $Token" } }
$HazardDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/court_hazard_director.gd')
foreach ($Token in @('low_friction','fast_walls','narrow_sidelines','wall_rebound')) { if (-not $HazardDirectorText.Contains($Token)) { throw "Court hazard director missing token: $Token" } }
$GeometryRulesText = Get-Content -Raw (Join-Path $Root 'scripts/court_geometry_rules.gd')
foreach ($Token in @('REFERENCE_WIDTH','REFERENCE_HEIGHT','movement_rect','clamp_player')) { if (-not $GeometryRulesText.Contains($Token)) { throw "Court geometry rules missing token: $Token" } }
$GeometryDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/court_geometry_director.gd')
foreach ($Token in @('CourtGeometryRules.movement_rect','CourtGeometryRules.clamp_player','home_players','away_players')) { if (-not $GeometryDirectorText.Contains($Token)) { throw "Court geometry director missing token: $Token" } }
$FixtureRulesText = Get-Content -Raw (Join-Path $Root 'scripts/fixture_simulation_rules.gd')
foreach ($Token in @('deterministic_score','simulate_fixture','fixture_needs_simulation','team_played')) { if (-not $FixtureRulesText.Contains($Token)) { throw "Fixture simulation rules missing token: $Token" } }
$FixtureDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/fixture_simulation_director.gd')
foreach ($Token in @('_simulate_other_fixture','FixtureSimulationRules.fixture_needs_simulation','FixtureSimulationRules.simulate_fixture','LeagueRules.record_result')) { if (-not $FixtureDirectorText.Contains($Token)) { throw "Fixture simulation director missing token: $Token" } }
$ReplayRulesText = Get-Content -Raw (Join-Path $Root 'scripts/replay_guard_rules.gd')
foreach ($Token in @('is_regular_round','make_snapshot','snapshot_valid')) { if (-not $ReplayRulesText.Contains($Token)) { throw "Replay guard rules missing token: $Token" } }
$ReplayDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/replay_guard_director.gd')
foreach ($Token in @('REPLAY - EXHIBITION ONLY','CAREER STATE UNCHANGED','ReplayGuardRules.make_snapshot','ReplayGuardRules.is_regular_round')) { if (-not $ReplayDirectorText.Contains($Token)) { throw "Replay guard director missing token: $Token" } }
$FoulRulesText = Get-Content -Raw (Join-Path $Root 'scripts/foul_ledger_rules.gd')
foreach ($Token in @('controlled_actor','ai_tackler_actor','make_event')) { if (-not $FoulRulesText.Contains($Token)) { throw "Foul ledger rules missing token: $Token" } }
$FoulDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/foul_ledger_director.gd')
foreach ($Token in @('process_priority = 60','MAX_EVENTS','last_home_actor_id','last_away_actor_id','latest_event')) { if (-not $FoulDirectorText.Contains($Token)) { throw "Foul ledger director missing token: $Token" } }
$SeasonEndRulesText = Get-Content -Raw (Join-Path $Root 'scripts/season_end_rules.gd')
foreach ($Token in @('user_qualified','terminal_reason','NO_PLAYOFF_BERTH','SEMIFINAL_EXIT')) { if (-not $SeasonEndRulesText.Contains($Token)) { throw "Season end rules missing token: $Token" } }
$SeasonEndDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/season_end_director.gd')
foreach ($Token in @('process_priority = -100','action_erase_events','postseason_state','director.call("postseason_state")','SeasonEndRules.terminal_reason')) { if (-not $SeasonEndDirectorText.Contains($Token)) { throw "Season end director missing public state token: $Token" } }
foreach ($ForbiddenToken in @('get("_semifinal_winners")','get("_champion_id")')) { if ($SeasonEndDirectorText.Contains($ForbiddenToken)) { throw "Season end director still reads private postseason state: $ForbiddenToken" } }
$ManagementRulesText = Get-Content -Raw (Join-Path $Root 'scripts/management_summary_rules.gd')
foreach ($Token in @('player_line','foul_line','postseason_line')) { if (-not $ManagementRulesText.Contains($Token)) { throw "Management summary rules missing token: $Token" } }
$ManagementDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/management_summary_director.gd')
foreach ($Token in @('ManagementSummaryRules.player_line','FoulLedgerDirector','SeasonDirector','PanelContainer','postseason_state','director.call("postseason_state")')) { if (-not $ManagementDirectorText.Contains($Token)) { throw "Management summary director missing token: $Token" } }
foreach ($ForbiddenToken in @('get("_semifinal_winners")','get("_champion_id")')) { if ($ManagementDirectorText.Contains($ForbiddenToken)) { throw "Management summary still reads private postseason state: $ForbiddenToken" } }
$StandingsRulesText = Get-Content -Raw (Join-Path $Root 'scripts/standings_summary_rules.gd')
foreach ($Token in @('sorted_rows','row_line','playoff_cutoff_line','marker')) { if (-not $StandingsRulesText.Contains($Token)) { throw "Standings summary rules missing token: $Token" } }
$StandingsDirectorText = Get-Content -Raw (Join-Path $Root 'scripts/standings_summary_director.gd')
foreach ($Token in @('StandingsSummaryRules.sorted_rows','StandingsSummaryRules.row_line','StandingsSummaryRules.playoff_cutoff_line','league_table','playoff_teams')) { if (-not $StandingsDirectorText.Contains($Token)) { throw "Standings summary director missing token: $Token" } }
$RecoveryRulesText = Get-Content -Raw (Join-Path $Root 'scripts/save_recovery_rules.gd')
foreach ($Token in @('parse_supported_json','choose_primary_or_backup','source')) { if (-not $RecoveryRulesText.Contains($Token)) { throw "Season save recovery rules missing token: $Token" } }
$SaveText = Get-Content -Raw (Join-Path $Root 'scripts/season_save.gd')
foreach ($Token in @('SAVE_VERSION := 3','BACKUP_PATH','SaveRecoveryRules.choose_primary_or_backup','_backup_valid_primary','RosterSaveRules.merge_rosters','_sanitize_table','_sanitize_rosters','_postseason_snapshot','postseason_state','restore_postseason_state','_sanitize_postseason','_restore_postseason_deferred')) { if (-not $SaveText.Contains($Token)) { throw "Season save missing canonical recovery-state token: $Token" } }
foreach ($ForbiddenToken in @('director.get("_semifinal_winners")','director.get("_champion_id")','director.set("_semifinal_winners"','director.set("_champion_id"')) { if ($SaveText.Contains($ForbiddenToken)) { throw "Season save still accesses private postseason state: $ForbiddenToken" } }

$Godot = Resolve-Godot -Preferred $GodotBin
if (-not $Godot) {
    Write-Warning 'Godot executable not found. Structural/data/director/save validation passed; runtime self-tests and engine smoke test skipped.'
    exit 0
}
Write-Host 'Running deterministic runtime rules self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/runtime_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring runtime self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running discipline policy/management self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/discipline_policy_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring discipline policy self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running persistence/recovery self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/persistence_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring persistence self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running court hazard/geometry self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/court_hazard_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring court self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running AI fixture simulation self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/fixture_simulation_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring fixture simulation self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running replay guard self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/replay_guard_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring replay guard self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running season-end self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/season_end_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring season-end self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running canonical postseason-save self-test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --script res://tools/postseason_save_self_test.gd
if ($LASTEXITCODE -ne 0) { throw "Obsidian Ring postseason save self-test failed with exit code $LASTEXITCODE" }
Write-Host 'Running Godot editor smoke test...' -ForegroundColor DarkCyan
& $Godot --headless --path $Root --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
Write-Host 'Obsidian Ring validation passed.' -ForegroundColor Green

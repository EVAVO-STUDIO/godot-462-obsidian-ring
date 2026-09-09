class_name EvavoBootLaunchPolicy
extends RefCounted

const MODE_AUTO := &"auto"
const MODE_FULL := &"full"
const MODE_SKIP := &"skip"

const SETTING_SPLASH_MODE := "evavo/boot/splash_mode"
const ENV_SPLASH_MODE := "EVAVO_SPLASH_MODE"
const ENV_DEV_TEST := "EVAVO_DEV_TEST"
const ENV_QUICK_TEST := "EVAVO_QUICK_TEST"
const ENV_AGENT_QUICK_TEST := "EVAVO_AGENT_QUICK_TEST"
const ARG_SKIP := "--evavo-skip-splash"
const ARG_FULL := "--evavo-full-boot"
const ARG_MODE_PREFIX := "--evavo-splash="
const ARG_MODE_PREFIX_ALT := "--evavo-splash-mode="

func resolve(host: Node = null, options: Dictionary = {}) -> Dictionary:
    return resolve_snapshot({
        "requested_mode": _requested_mode(options),
        "headless": _is_headless(),
        "automation_or_dev_test": _is_ci_or_dev_test(),
        "full_game_launch": _is_full_game_launch(host),
        "platform": OS.get_name(),
        "display_server": DisplayServer.get_name()
    })

# Pure decision surface used by deterministic Godot tests and external agents.
# Runtime discovery stays in resolve(); policy precedence lives only here.
func resolve_snapshot(snapshot: Dictionary) -> Dictionary:
    var requested := _normalise_mode(snapshot.get("requested_mode", MODE_AUTO))
    var headless := bool(snapshot.get("headless", false))
    var ci_or_dev_test := bool(snapshot.get("automation_or_dev_test", false))
    var full_game_launch := bool(snapshot.get("full_game_launch", true))
    var show_splash := true
    var reason := &"full_game_launch"

    # A headless display cannot present an ident. Explicit full boot still tests the
    # surrounding boot lifecycle, but its visual phase is intentionally bypassed.
    if headless:
        show_splash = false
        reason = &"headless"
    elif requested == MODE_SKIP:
        show_splash = false
        reason = &"explicit_skip"
    elif requested == MODE_FULL:
        show_splash = true
        reason = &"explicit_full"
    elif ci_or_dev_test:
        show_splash = false
        reason = &"automation_or_dev_test"
    elif not full_game_launch:
        show_splash = false
        reason = &"partial_scene_run"

    return {
        "show_splash": show_splash,
        "reason": String(reason),
        "requested_mode": String(requested),
        "headless": headless,
        "automation_or_dev_test": ci_or_dev_test,
        "full_game_launch": full_game_launch,
        "platform": String(snapshot.get("platform", OS.get_name())),
        "display_server": String(snapshot.get("display_server", DisplayServer.get_name()))
    }

func _requested_mode(options: Dictionary) -> StringName:
    if options.has("splash_mode"):
        return _normalise_mode(options.get("splash_mode"))

    var command_line := _command_line_mode()
    if command_line != MODE_AUTO:
        return command_line

    var environment := String(OS.get_environment(ENV_SPLASH_MODE)).strip_edges()
    if not environment.is_empty():
        return _normalise_mode(environment)

    return _normalise_mode(ProjectSettings.get_setting(SETTING_SPLASH_MODE, "auto"))

func _command_line_mode() -> StringName:
    var args := OS.get_cmdline_args()
    for argument in args:
        var value := String(argument).strip_edges()
        if value == ARG_SKIP:
            return MODE_SKIP
        if value == ARG_FULL:
            return MODE_FULL
        if value.begins_with(ARG_MODE_PREFIX):
            return _normalise_mode(value.trim_prefix(ARG_MODE_PREFIX))
        if value.begins_with(ARG_MODE_PREFIX_ALT):
            return _normalise_mode(value.trim_prefix(ARG_MODE_PREFIX_ALT))
    return MODE_AUTO

func _normalise_mode(value: Variant) -> StringName:
    var text := String(value).strip_edges().to_lower()
    match text:
        "full", "show", "on", "true", "1":
            return MODE_FULL
        "skip", "off", "false", "0", "none":
            return MODE_SKIP
        _:
            return MODE_AUTO

func _is_headless() -> bool:
    return DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args()

func _is_ci_or_dev_test() -> bool:
    for variable in [ENV_DEV_TEST, ENV_QUICK_TEST, ENV_AGENT_QUICK_TEST, "CI", "GITHUB_ACTIONS"]:
        if _environment_truthy(variable):
            return true
    return false

func _environment_truthy(name: String) -> bool:
    var value := String(OS.get_environment(name)).strip_edges().to_lower()
    return value in ["1", "true", "yes", "on"]

func _is_full_game_launch(host: Node) -> bool:
    if host == null or host.get_tree() == null:
        return true
    var current_scene := host.get_tree().current_scene
    if current_scene == null:
        return true
    var current_path := String(current_scene.scene_file_path)
    var configured_main := String(ProjectSettings.get_setting("application/run/main_scene", ""))
    if current_path.is_empty() or configured_main.is_empty():
        return true
    return current_path == configured_main

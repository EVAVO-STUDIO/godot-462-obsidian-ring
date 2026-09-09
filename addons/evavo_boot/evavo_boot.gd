class_name EvavoProjectBoot
extends Control

const PublisherIdent = preload("res://addons/evavo_boot/publisher_ident.gd")
const BootLaunchPolicy = preload("res://addons/evavo_boot/boot_launch_policy.gd")

const SETTING_GAME_MAIN_SCENE := "evavo/boot/game_main_scene"
const SETTING_SPLASH_MODE := "evavo/boot/splash_mode"
const SETTING_LOGO_PATH := "evavo/boot/logo_path"
const SETTING_JINGLE_PATH := "evavo/boot/jingle_path"
const SETTING_SPARKLE_PATH := "evavo/boot/sparkle_path"
const SETTING_SPARKLE_FRAME_PATHS := "evavo/boot/sparkle_frame_paths"
const SETTING_DURATION := "evavo/boot/duration_seconds"
const SETTING_MINIMUM_SKIP := "evavo/boot/minimum_skip_seconds"
const SETTING_MAXIMUM := "evavo/boot/maximum_seconds"
const SETTING_SPARKLE_AT := "evavo/boot/sparkle_at_seconds"
const SETTING_LOGO_WIDTH := "evavo/boot/logo_width_ratio"
const SETTING_ALLOW_SKIP := "evavo/boot/allow_user_skip"
const SETTING_AUDIO_BUS := "evavo/boot/audio_bus"
const SETTING_BACKGROUND_COLOR := "evavo/boot/background_color"
const SETTING_PRELOAD_GAME := "evavo/boot/preload_game_scene"
const SETTING_IDENT_COMPLETED := "evavo/boot/ident_completed_for_process"

@export_file("*.tscn") var fallback_game_main_scene := ""

var _target_scene_path := ""
var _threaded_request_started := false
var _waiting_for_target := false
var _transition_started := false
var _ident: Control
var _status_label: Label
var _policy_decision: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_boot_surface()

    _target_scene_path = String(ProjectSettings.get_setting(SETTING_GAME_MAIN_SCENE, fallback_game_main_scene)).strip_edges()
    if not _validate_target_scene():
        return

    if bool(ProjectSettings.get_setting(SETTING_PRELOAD_GAME, true)):
        _threaded_request_started = ResourceLoader.load_threaded_request(_target_scene_path, "PackedScene") == OK

    if bool(ProjectSettings.get_setting(SETTING_IDENT_COMPLETED, false)):
        _policy_decision = {
            "show_splash": false,
            "reason": "already_completed_for_process",
            "requested_mode": "skip",
            "platform": OS.get_name(),
            "display_server": DisplayServer.get_name()
        }
    else:
        _policy_decision = BootLaunchPolicy.new().resolve(self)

    if not bool(_policy_decision.get("show_splash", true)):
        call_deferred("_continue_to_game", StringName(_policy_decision.get("reason", "policy_skip")))
        return

    _start_ident()

func _process(_delta: float) -> void:
    if not _waiting_for_target or _transition_started:
        return
    var packed := _try_get_target_scene()
    if packed != null:
        _change_to_game(packed)

func policy_snapshot() -> Dictionary:
    return _policy_decision.duplicate(true)

func _build_boot_surface() -> void:
    var background := ColorRect.new()
    background.name = "Background"
    background.color = _setting_color(SETTING_BACKGROUND_COLOR, Color(0.066, 0.071, 0.078, 1.0))
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    _status_label = Label.new()
    _status_label.name = "Status"
    _status_label.text = ""
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _status_label.add_theme_font_size_override("font_size", 16)
    _status_label.add_theme_color_override("font_color", Color(0.74, 0.76, 0.79, 1.0))
    _status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _status_label.position = Vector2(-150.0, -62.0)
    _status_label.size = Vector2(300.0, 30.0)
    _status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _status_label.visible = false
    add_child(_status_label)

func _start_ident() -> void:
    var ident := PublisherIdent.new()
    ident.logo_texture = _load_optional_texture(String(ProjectSettings.get_setting(SETTING_LOGO_PATH, "")))
    ident.jingle_stream = _load_optional_audio(String(ProjectSettings.get_setting(SETTING_JINGLE_PATH, "")))
    ident.sparkle_stream = _load_optional_audio(String(ProjectSettings.get_setting(SETTING_SPARKLE_PATH, "")))
    ident.sparkle_frames = _load_sparkle_frames(ProjectSettings.get_setting(SETTING_SPARKLE_FRAME_PATHS, []))
    ident.duration_seconds = float(ProjectSettings.get_setting(SETTING_DURATION, 3.6))
    ident.minimum_skip_seconds = float(ProjectSettings.get_setting(SETTING_MINIMUM_SKIP, 1.5))
    ident.maximum_seconds = float(ProjectSettings.get_setting(SETTING_MAXIMUM, 5.0))
    ident.sparkle_at_seconds = float(ProjectSettings.get_setting(SETTING_SPARKLE_AT, 0.92))
    ident.logo_width_ratio = float(ProjectSettings.get_setting(SETTING_LOGO_WIDTH, 0.42))
    ident.allow_skip = bool(ProjectSettings.get_setting(SETTING_ALLOW_SKIP, true))
    ident.audio_bus = StringName(ProjectSettings.get_setting(SETTING_AUDIO_BUS, "Master"))
    ident.background_color = _setting_color(SETTING_BACKGROUND_COLOR, Color(0.066, 0.071, 0.078, 1.0))
    ident.finished.connect(_on_ident_finished, CONNECT_ONE_SHOT)
    ident.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ident)
    _ident = ident

func _on_ident_finished(reason: StringName) -> void:
    _continue_to_game(reason)

func _continue_to_game(_reason: StringName) -> void:
    if _transition_started:
        return
    if _ident != null and is_instance_valid(_ident):
        _ident.queue_free()
        _ident = null

    var packed := _try_get_target_scene()
    if packed != null:
        _change_to_game(packed)
        return

    _waiting_for_target = true
    _status_label.text = "Loading…"
    _status_label.visible = true

func _try_get_target_scene() -> PackedScene:
    if _threaded_request_started:
        var progress: Array = []
        var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)
        match status:
            ResourceLoader.THREAD_LOAD_LOADED:
                var threaded = ResourceLoader.load_threaded_get(_target_scene_path)
                if threaded is PackedScene:
                    return threaded as PackedScene
                _fail_boot("EVAVO boot target did not load as a PackedScene: %s" % _target_scene_path)
            ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
                _fail_boot("EVAVO boot could not preload target scene: %s" % _target_scene_path)
        return null

    var loaded = load(_target_scene_path)
    if loaded is PackedScene:
        return loaded as PackedScene
    _fail_boot("EVAVO boot could not load target scene: %s" % _target_scene_path)
    return null

func _change_to_game(packed: PackedScene) -> void:
    if _transition_started:
        return
    _transition_started = true
    _waiting_for_target = false
    ProjectSettings.set_setting(SETTING_IDENT_COMPLETED, true)
    if _status_label != null:
        _status_label.visible = false
    var error := get_tree().change_scene_to_packed(packed)
    if error != OK:
        ProjectSettings.set_setting(SETTING_IDENT_COMPLETED, false)
        _transition_started = false
        _fail_boot("EVAVO boot scene transition failed with error %s" % error)

func _validate_target_scene() -> bool:
    if _target_scene_path.is_empty():
        _fail_boot("EVAVO boot is missing project setting '%s'." % SETTING_GAME_MAIN_SCENE)
        return false
    if _target_scene_path == scene_file_path:
        _fail_boot("EVAVO boot target points back to the boot scene and would recurse.")
        return false
    if not ResourceLoader.exists(_target_scene_path, "PackedScene"):
        _fail_boot("EVAVO boot target scene does not exist: %s" % _target_scene_path)
        return false
    return true

func _fail_boot(message: String) -> void:
    push_error(message)
    _waiting_for_target = false
    if _status_label != null:
        _status_label.text = "Boot error — see debugger"
        _status_label.visible = true

func _load_optional_texture(path: String) -> Texture2D:
    var clean := path.strip_edges()
    if clean.is_empty() or not ResourceLoader.exists(clean):
        return null
    var value = load(clean)
    if value is Texture2D:
        return value as Texture2D
    return null

func _load_optional_audio(path: String) -> AudioStream:
    var clean := path.strip_edges()
    if clean.is_empty() or not ResourceLoader.exists(clean):
        return null
    var value = load(clean)
    if value is AudioStream:
        return value as AudioStream
    return null

func _load_sparkle_frames(candidate: Variant) -> Array[Texture2D]:
    var result: Array[Texture2D] = []
    if candidate is Array or candidate is PackedStringArray:
        for entry in candidate:
            var texture := _load_optional_texture(String(entry))
            if texture != null:
                result.append(texture)
    return result

func _setting_color(key: String, fallback: Color) -> Color:
    var value = ProjectSettings.get_setting(key, fallback)
    if value is Color:
        return value as Color
    if value is String:
        return Color.from_string(String(value), fallback)
    return fallback

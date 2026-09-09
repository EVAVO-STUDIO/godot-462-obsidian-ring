class_name EvavoPublisherIdent
extends Control

signal finished(reason: StringName)
signal sparkle_fired

const FALLBACK_AUDIO_RATE := 16000

@export_category("Presentation")
@export var logo_texture: Texture2D
@export var duration_seconds := 3.6
@export var minimum_skip_seconds := 1.5
@export var maximum_seconds := 5.0
@export_range(0.20, 0.80, 0.01) var logo_width_ratio := 0.42
@export var sparkle_at_seconds := 0.92
@export var allow_skip := true
@export var background_color := Color(0.066, 0.071, 0.078, 1.0)

@export_category("Sparkle")
@export var sparkle_frames: Array[Texture2D] = []
@export_range(6.0, 24.0, 1.0) var sparkle_frame_fps := 12.0
@export var sparkle_size := Vector2(64.0, 64.0)
@export var sparkle_offset := Vector2(254.0, -92.0)

@export_category("Audio")
@export var jingle_stream: AudioStream
@export var sparkle_stream: AudioStream
@export_range(-40.0, 6.0, 0.5) var jingle_volume_db := -3.0
@export_range(-40.0, 6.0, 0.5) var sparkle_volume_db := -7.0
@export var audio_bus: StringName = &"Master"
@export var procedural_audio_fallback := true

var _elapsed := 0.0
var _finishing := false
var _sparkle_started := false
var _logo_host: Control
var _sparkle_texture: TextureRect
var _sparkle_fallback: Label
var _jingle: AudioStreamPlayer
var _sparkle_player: AudioStreamPlayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process(true)
    set_process_unhandled_input(true)
    _normalise_contract()

    if DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args():
        visible = false
        call_deferred("_finish_immediately", &"headless")
        return

    _build_visuals()
    _build_audio()
    _begin_presentation()

func _process(delta: float) -> void:
    if _finishing:
        return
    _elapsed += delta
    if not _sparkle_started and _elapsed >= sparkle_at_seconds:
        _fire_sparkle()
    if _sparkle_started:
        _update_sparkle_frame()
    if _elapsed >= maximum_seconds:
        _finish(&"watchdog")
    elif _elapsed >= duration_seconds:
        _finish(&"timeline")

func _unhandled_input(event: InputEvent) -> void:
    if not allow_skip or _finishing or _elapsed < minimum_skip_seconds:
        return
    var pressed := false
    if event is InputEventKey:
        pressed = event.pressed and not event.echo
    elif event is InputEventMouseButton:
        pressed = event.pressed
    elif event is InputEventJoypadButton:
        pressed = event.pressed
    elif event is InputEventScreenTouch:
        pressed = event.pressed
    if pressed:
        get_viewport().set_input_as_handled()
        _finish(&"skip")

func _normalise_contract() -> void:
    minimum_skip_seconds = clampf(minimum_skip_seconds, 0.0, 5.0)
    duration_seconds = clampf(duration_seconds, minimum_skip_seconds, 5.0)
    maximum_seconds = clampf(maximum_seconds, duration_seconds, 5.0)
    sparkle_at_seconds = clampf(sparkle_at_seconds, 0.2, maxf(0.2, duration_seconds - 0.35))
    sparkle_frame_fps = clampf(sparkle_frame_fps, 6.0, 24.0)

func _build_visuals() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var background := ColorRect.new()
    background.color = background_color
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)

    _logo_host = Control.new()
    _logo_host.custom_minimum_size = Vector2(620.0, 220.0)
    _logo_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_logo_host)

    if logo_texture != null:
        var logo := TextureRect.new()
        logo.texture = logo_texture
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _logo_host.add_child(logo)
    else:
        var wordmark := Label.new()
        wordmark.text = "EVAVO"
        wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        wordmark.add_theme_font_size_override("font_size", 86)
        wordmark.add_theme_color_override("font_color", Color.WHITE)
        wordmark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _logo_host.add_child(wordmark)

    if not sparkle_frames.is_empty():
        _sparkle_texture = TextureRect.new()
        _sparkle_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _sparkle_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        _sparkle_texture.size = sparkle_size
        _sparkle_texture.position = Vector2(310.0, 110.0) + sparkle_offset - sparkle_size * 0.5
        _sparkle_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _sparkle_texture.visible = false
        _logo_host.add_child(_sparkle_texture)
    else:
        _sparkle_fallback = Label.new()
        _sparkle_fallback.text = "✦"
        _sparkle_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _sparkle_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _sparkle_fallback.add_theme_font_size_override("font_size", 56)
        _sparkle_fallback.add_theme_color_override("font_color", Color.WHITE)
        _sparkle_fallback.size = Vector2(80.0, 80.0)
        _sparkle_fallback.position = Vector2(310.0, 110.0) + sparkle_offset - _sparkle_fallback.size * 0.5
        _sparkle_fallback.pivot_offset = _sparkle_fallback.size * 0.5
        _sparkle_fallback.modulate.a = 0.0
        _sparkle_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _logo_host.add_child(_sparkle_fallback)

    resized.connect(_fit_logo_to_viewport)
    _fit_logo_to_viewport()

func _fit_logo_to_viewport() -> void:
    if _logo_host == null:
        return
    var viewport_width := maxf(1.0, size.x)
    var viewport_height := maxf(1.0, size.y)
    var desired_width := minf(viewport_width * logo_width_ratio, viewport_height * 1.15)
    var scale_factor := clampf(desired_width / 620.0, 0.32, 1.25)
    _logo_host.scale = Vector2.ONE * scale_factor
    _logo_host.pivot_offset = _logo_host.size * 0.5

func _build_audio() -> void:
    if procedural_audio_fallback:
        if jingle_stream == null:
            jingle_stream = _make_fallback_jingle()
        if sparkle_stream == null:
            sparkle_stream = _make_fallback_sparkle()

    var resolved_bus := audio_bus
    if AudioServer.get_bus_index(resolved_bus) < 0:
        resolved_bus = &"Master"

    _jingle = AudioStreamPlayer.new()
    _jingle.stream = jingle_stream
    _jingle.volume_db = jingle_volume_db
    _jingle.bus = resolved_bus
    _jingle.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_jingle)

    _sparkle_player = AudioStreamPlayer.new()
    _sparkle_player.stream = sparkle_stream
    _sparkle_player.volume_db = sparkle_volume_db
    _sparkle_player.bus = resolved_bus
    _sparkle_player.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_sparkle_player)

func _make_fallback_jingle() -> AudioStreamWAV:
    var duration := minf(3.15, maximum_seconds)
    var sample_count := maxi(1, int(ceil(duration * FALLBACK_AUDIO_RATE)))
    var data := PackedByteArray()
    data.resize(sample_count * 2)

    for index in sample_count:
        var t := float(index) / float(FALLBACK_AUDIO_RATE)
        var attack := clampf(t / 0.18, 0.0, 1.0)
        var release := clampf((duration - t) / 0.55, 0.0, 1.0)
        var envelope := sin(attack * PI * 0.5) * sin(release * PI * 0.5)
        var rise := clampf(t / 1.2, 0.0, 1.0)
        var fundamental := lerpf(220.0, 261.63, rise)
        var value := (
            sin(TAU * fundamental * t) * 0.30
            + sin(TAU * 329.63 * t + 0.12) * 0.22
            + sin(TAU * 392.00 * t + 0.24) * 0.18
            + sin(TAU * 523.25 * t + 0.08) * 0.08
        ) * envelope
        _write_pcm16(data, index, value * 0.72)

    return _wav_from_pcm16(data)

func _make_fallback_sparkle() -> AudioStreamWAV:
    var duration := 0.34
    var sample_count := maxi(1, int(ceil(duration * FALLBACK_AUDIO_RATE)))
    var data := PackedByteArray()
    data.resize(sample_count * 2)

    for index in sample_count:
        var t := float(index) / float(FALLBACK_AUDIO_RATE)
        var envelope := pow(clampf(1.0 - (t / duration), 0.0, 1.0), 2.4)
        var value := (
            sin(TAU * 1318.51 * t) * 0.50
            + sin(TAU * 1975.53 * t + 0.18) * 0.28
            + sin(TAU * 2637.02 * t + 0.33) * 0.13
        ) * envelope
        _write_pcm16(data, index, value * 0.72)

    return _wav_from_pcm16(data)

func _wav_from_pcm16(data: PackedByteArray) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = FALLBACK_AUDIO_RATE
    stream.stereo = false
    stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
    stream.data = data
    return stream

func _write_pcm16(data: PackedByteArray, sample_index: int, value: float) -> void:
    var sample := clampi(int(round(clampf(value, -1.0, 1.0) * 32767.0)), -32767, 32767)
    var packed := sample & 0xffff
    var byte_index := sample_index * 2
    data[byte_index] = packed & 0xff
    data[byte_index + 1] = (packed >> 8) & 0xff

func _begin_presentation() -> void:
    modulate.a = 0.0
    if _logo_host != null:
        _logo_host.modulate.a = 0.0
    if _jingle != null and _jingle.stream != null:
        _jingle.play()

    var tween := create_tween().set_parallel(true)
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    if _logo_host != null:
        tween.tween_property(_logo_host, "modulate:a", 1.0, 0.50).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fire_sparkle() -> void:
    _sparkle_started = true
    sparkle_fired.emit()
    if _sparkle_player != null and _sparkle_player.stream != null:
        _sparkle_player.play()

    if _sparkle_texture != null:
        _sparkle_texture.texture = sparkle_frames[0]
        _sparkle_texture.visible = true
        return

    if _sparkle_fallback == null:
        return
    _sparkle_fallback.scale = Vector2(0.30, 0.30)
    _sparkle_fallback.rotation = -0.18
    _sparkle_fallback.modulate.a = 0.0
    var tween := create_tween().set_parallel(true)
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(_sparkle_fallback, "modulate:a", 1.0, 0.10)
    tween.tween_property(_sparkle_fallback, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_sparkle_fallback, "rotation", 0.08, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.chain().tween_interval(0.12)
    tween.chain().tween_property(_sparkle_fallback, "modulate:a", 0.0, 0.20)

func _update_sparkle_frame() -> void:
    if _sparkle_texture == null or sparkle_frames.is_empty():
        return
    var frame_elapsed := maxf(0.0, _elapsed - sparkle_at_seconds)
    var frame_index := int(floor(frame_elapsed * sparkle_frame_fps))
    if frame_index >= sparkle_frames.size():
        _sparkle_texture.visible = false
        return
    _sparkle_texture.texture = sparkle_frames[frame_index]
    _sparkle_texture.visible = true

func _finish(reason: StringName) -> void:
    if _finishing:
        return
    _finishing = true
    set_process_unhandled_input(false)

    var tween := create_tween().set_parallel(true)
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(self, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    if _jingle != null and _jingle.playing:
        tween.tween_property(_jingle, "volume_db", -36.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    if _sparkle_player != null and _sparkle_player.playing:
        tween.tween_property(_sparkle_player, "volume_db", -36.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.finished.connect(_on_exit_fade_finished.bind(reason), CONNECT_ONE_SHOT)

func _on_exit_fade_finished(reason: StringName) -> void:
    if _jingle != null:
        _jingle.stop()
    if _sparkle_player != null:
        _sparkle_player.stop()
    finished.emit(reason)

func _finish_immediately(reason: StringName) -> void:
    if _finishing:
        return
    _finishing = true
    finished.emit(reason)

extends Node3D

# An original low-poly rolling-ball prototype with a dusk sky, floating runway and orange blocks.

const TRACK_WIDTH := 8.2
const PLAYER_RADIUS := 0.52
const PLAYER_X_LIMIT := 4.4
const FALL_EDGE_X := 3.72
const FALL_GRAVITY := 9.8
const FALL_DURATION := 2.5
const SEGMENT_LENGTH := 9.5
const SEGMENT_COUNT := 18
const PLATFORM_GAP := 0.42
const SPAWN_Z := -104.0
const REMOVE_Z := 10.0
const PLAYER_Z := 0.0
const FINISH_DISTANCE := 3300.0
const LEVEL_1_END_DISTANCE := FINISH_DISTANCE * 0.25
const LEVEL_2_END_DISTANCE := FINISH_DISTANCE * 0.5
const LEVEL_3_END_DISTANCE := FINISH_DISTANCE * 0.75
const CRUISE_SPEED := 20.0
const BOOST_SPEED := 50.0
const SPEED_RAMP := 0.035
const STEER_SPEED := 6.8
const MUSIC_MIX_RATE := 22050.0
const MUSIC_STEP_DURATION := 0.242
const MUSIC_LEAD := [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 392.0]
const MUSIC_BASS := [65.41, 65.41, 73.42, 73.42, 55.0, 55.0, 61.74, 61.74]
const MUSIC_END_STEP_DURATION := 0.34
const MUSIC_END_LEAD := [293.66, 261.63, 220.0, 196.0, 164.81, 146.83]
const MUSIC_END_BASS := [73.42, 65.41, 55.0, 49.0, 41.2, 36.71]
const MUSIC_WIN_STEP_DURATION := 0.22
const MUSIC_WIN_LEAD := [392.0, 440.0, 523.25, 659.25, 783.99, 659.25]
const MUSIC_WIN_BASS := [98.0, 110.0, 130.81, 164.81, 196.0, 164.81]

var track_root: Node3D
var obstacle_root: Node3D
var pickup_root: Node3D
var finish_root: Node3D
var camera: Camera3D
var sun_light: DirectionalLight3D
var fill_light: OmniLight3D
var level_environment: Environment
var player_root: Node3D
var player_ball: MeshInstance3D
var music_player: AudioStreamPlayer
var music_generator: AudioStreamGenerator
var music_playback: AudioStreamGeneratorPlayback

var hud_label: Label
var hint_label: Label
var center_label: Label
var game_over_panel: ColorRect

var floor_segments: Array[Node3D] = []
var obstacles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []

var player_x := 0.0
var player_y := PLAYER_RADIUS + 0.02
var fall_velocity := 0.0
var fall_elapsed := 0.0
var fall_camera_position := Vector3.ZERO
var fall_camera_target := Vector3.ZERO
var speed := CRUISE_SPEED
var distance := 0.0
var pickups_collected := 0
var best_score := 0
var spawn_timer := 0.8
var game_over := false
var game_complete := false
var falling := false
var failure_text := ""
var current_level := 1
var level_two_active := false
var level_banner_timer := 0.0
var music_time := 0.0
var music_lead_phase := 0.0
var music_bass_phase := 0.0
var music_mode := 0 # 0: gameplay, 1: game over, 2: finish


func _ready() -> void:
	randomize()
	_setup_world()
	_setup_track()
	_setup_player()
	_setup_ui()
	_apply_level_theme()
	_setup_music()
	_reset_game()


func _process(delta: float) -> void:
	_fill_music()
	if level_banner_timer > 0.0:
		level_banner_timer = max(0.0, level_banner_timer - delta)
	if game_over or game_complete:
		_update_ui()
		return
	if falling:
		_update_fall(delta)
		return

	var steer := _get_steer_input()
	player_x = clamp(player_x + steer * STEER_SPEED * delta, -PLAYER_X_LIMIT, PLAYER_X_LIMIT)
	if abs(player_x) > FALL_EDGE_X:
		player_root.position = Vector3(player_x, player_y, PLAYER_Z)
		_update_camera(delta)
		_begin_fall()
		return
	var is_boosting := _is_boosting()
	var target_speed := BOOST_SPEED if is_boosting else CRUISE_SPEED
	target_speed += distance * SPEED_RAMP
	speed = move_toward(speed, target_speed, 10.0 * delta)
	distance += speed * delta
	spawn_timer -= delta
	if current_level == 1 and distance >= LEVEL_1_END_DISTANCE:
		_start_level(2)
	elif current_level == 2 and distance >= LEVEL_2_END_DISTANCE:
		_start_level(3)
	elif current_level == 3 and distance >= LEVEL_3_END_DISTANCE:
		_start_level(4)

	player_root.position = Vector3(player_x, player_y, PLAYER_Z)
	_update_camera(delta)
	player_ball.rotate_object_local(Vector3.RIGHT, speed * delta / PLAYER_RADIUS)
	player_ball.rotate_object_local(Vector3.FORWARD, -steer * 0.12)

	_update_track(delta)
	_update_obstacles(delta)
	_update_pickups(delta)
	_update_finish_line(delta)

	if distance >= FINISH_DISTANCE:
		_finish_game()
		return

	if spawn_timer <= 0.0:
		_spawn_course_pattern()
		spawn_timer = randf_range(1.15, 1.72) * max(0.62, CRUISE_SPEED / speed)

	_update_ui()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		get_tree().quit()
		get_viewport().set_input_as_handled()
		return

	var restart_pressed := key_event.keycode == KEY_SPACE or key_event.keycode == KEY_R or key_event.keycode == KEY_ENTER
	restart_pressed = restart_pressed or key_event.physical_keycode == KEY_SPACE or key_event.physical_keycode == KEY_R or key_event.physical_keycode == KEY_ENTER
	restart_pressed = restart_pressed or key_event.unicode == 32
	if (game_over or game_complete) and restart_pressed:
		get_viewport().set_input_as_handled()
		_reset_game()


func _setup_world() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 7.2, 11.5)
	camera.fov = 56.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, -24.0), Vector3.UP)

	sun_light = DirectionalLight3D.new()
	sun_light.shadow_enabled = true
	add_child(sun_light)

	fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0.0, 6.0, 4.0)
	fill_light.omni_range = 22.0
	add_child(fill_light)

	level_environment = Environment.new()
	level_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	level_environment.glow_enabled = false

	var world_environment := WorldEnvironment.new()
	world_environment.environment = level_environment
	add_child(world_environment)

	track_root = Node3D.new()
	track_root.name = "FloatingBlueTrack"
	add_child(track_root)

	obstacle_root = Node3D.new()
	obstacle_root.name = "OrangeBlocks"
	add_child(obstacle_root)

	pickup_root = Node3D.new()
	pickup_root.name = "LightOrbs"
	add_child(pickup_root)

	_setup_finish_line()


func _apply_level_theme() -> void:
	level_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	level_environment.fog_enabled = true

	if current_level == 1:
		sun_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
		sun_light.light_color = Color("b8c2cc")
		sun_light.light_energy = 0.82
		fill_light.light_color = Color("aab6c4")
		fill_light.light_energy = 0.32
		level_environment.background_mode = Environment.BG_COLOR
		level_environment.background_color = Color("151a24")
		level_environment.sky = null
		level_environment.background_energy_multiplier = 1.0
		level_environment.ambient_light_color = Color("7f8b99")
		level_environment.ambient_light_energy = 0.55
		level_environment.fog_light_color = Color("1b222d")
		level_environment.fog_light_energy = 0.7
		level_environment.fog_density = 0.004
	elif current_level == 2:
		sun_light.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
		sun_light.light_color = Color("faf4e8")
		sun_light.light_energy = 1.15
		fill_light.light_color = Color("8ea2bf")
		fill_light.light_energy = 0.55
		level_environment.background_mode = Environment.BG_SKY
		level_environment.sky = _create_second_level_sky()
		level_environment.background_energy_multiplier = 0.8
		level_environment.ambient_light_color = Color("d6e0e9")
		level_environment.ambient_light_energy = 0.82
		level_environment.fog_light_color = Color("faf4e8")
		level_environment.fog_light_energy = 0.5
		level_environment.fog_density = 0.0025
	elif current_level == 3:
		sun_light.rotation_degrees = Vector3(-24.0, -20.0, 0.0)
		sun_light.light_color = Color("ffd0b2")
		sun_light.light_energy = 1.0
		fill_light.light_color = Color("b56c82")
		fill_light.light_energy = 0.45
		level_environment.background_mode = Environment.BG_SKY
		level_environment.sky = _create_third_level_sky()
		level_environment.background_energy_multiplier = 0.85
		level_environment.ambient_light_color = Color("e0a0a4")
		level_environment.ambient_light_energy = 0.7
		level_environment.fog_light_color = Color("c87f85")
		level_environment.fog_light_energy = 0.55
		level_environment.fog_density = 0.003
	else:
		sun_light.rotation_degrees = Vector3(-8.0, 26.0, 0.0)
		sun_light.light_color = Color("d6f3df")
		sun_light.light_energy = 1.05
		fill_light.light_color = Color("65b6b0")
		fill_light.light_energy = 0.5
		level_environment.background_mode = Environment.BG_SKY
		level_environment.sky = _create_fourth_level_sky()
		level_environment.background_energy_multiplier = 0.9
		level_environment.ambient_light_color = Color("bce4dd")
		level_environment.ambient_light_energy = 0.78
		level_environment.fog_light_color = Color("75b7aa")
		level_environment.fog_light_energy = 0.55
		level_environment.fog_density = 0.0025

	if player_ball != null:
		var ball_material := player_ball.material_override as StandardMaterial3D
		if ball_material != null:
			ball_material.albedo_color = _theme_color("ball")

	if hud_label != null:
		var ui_color := _theme_color("ui")
		var shadow_color := _theme_color("shadow")
		var outline_color := _theme_color("outline")
		hud_label.add_theme_color_override("font_color", ui_color)
		hud_label.add_theme_color_override("font_shadow_color", shadow_color)
		hint_label.add_theme_color_override("font_color", _theme_color("hint"))
		center_label.add_theme_color_override("font_color", ui_color)
		center_label.add_theme_color_override("font_outline_color", outline_color)


func _theme_color(role: String) -> Color:
	match current_level:
		1:
			match role:
				"platform": return Color("28333f")
				"surface": return Color("3a4654")
				"edge": return Color("7f8b96")
				"marker": return Color("aab4bd")
				"ball": return Color("d7dcdf")
				"block": return Color("675b70")
				"block_top": return Color("8a7890")
				"pickup": return Color("73a99b")
				"pickup_emission": return Color("48796f")
				"ui": return Color("e1e7eb")
				"shadow": return Color("0c1017")
				"outline": return Color("37303e")
				"hint": return Color("bac4cb")
		2:
			match role:
				"platform": return Color("05085c")
				"surface": return Color("1b2071")
				"edge": return Color("1b2071")
				"marker": return Color("f5ffff")
				"ball": return Color("f5ffff")
				"block": return Color("fa9e43")
				"block_top": return Color("ffc35b")
				"pickup": return Color("faf4e8")
				"pickup_emission": return Color("faf4e8")
				"ui": return Color("f5ffff")
				"shadow": return Color("1b2071")
				"outline": return Color("1b2071")
				"hint": return Color("f5ffff")
		3:
			match role:
				"platform": return Color("4a2341")
				"surface": return Color("813c54")
				"edge": return Color("aa6574")
				"marker": return Color("f2c3a0")
				"ball": return Color("fff1e4")
				"block": return Color("d7654e")
				"block_top": return Color("f49a61")
				"pickup": return Color("f6d2a0")
				"pickup_emission": return Color("d08d64")
				"ui": return Color("fff1e4")
				"shadow": return Color("4a2341")
				"outline": return Color("5a2947")
				"hint": return Color("f0c4bb")
		4:
			match role:
				"platform": return Color("123c4e")
				"surface": return Color("1d6e70")
				"edge": return Color("64a7a1")
				"marker": return Color("d6f3df")
				"ball": return Color("f2fff8")
				"block": return Color("d6c95c")
				"block_top": return Color("f1eaa1")
				"pickup": return Color("d6f3df")
				"pickup_emission": return Color("7ab59f")
				"ui": return Color("e8fff7")
				"shadow": return Color("123c4e")
				"outline": return Color("1f5c5d")
				"hint": return Color("c4e6da")
	return Color.WHITE


func _create_second_level_sky() -> Sky:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5d7898")
	sky_material.sky_horizon_color = Color("faf4e8")
	sky_material.ground_bottom_color = Color("101826")
	sky_material.ground_horizon_color = Color("303641")
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.06
	var sky := Sky.new()
	sky.sky_material = sky_material
	return sky


func _create_third_level_sky() -> Sky:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3b2143")
	sky_material.sky_horizon_color = Color("f1a080")
	sky_material.ground_bottom_color = Color("27152f")
	sky_material.ground_horizon_color = Color("743d53")
	sky_material.sun_angle_max = 26.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	return sky


func _create_fourth_level_sky() -> Sky:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0d3448")
	sky_material.sky_horizon_color = Color("9bd4bd")
	sky_material.ground_bottom_color = Color("09202c")
	sky_material.ground_horizon_color = Color("1e666a")
	sky_material.sun_angle_max = 20.0
	sky_material.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_material
	return sky


func _start_level(next_level: int) -> void:
	current_level = next_level
	level_two_active = current_level == 2
	level_banner_timer = 2.8
	_clear_runtime_nodes()
	_rebuild_track()
	_apply_level_theme()
	spawn_timer = 0.65
	_update_ui()


func _rebuild_track() -> void:
	for segment in floor_segments:
		if is_instance_valid(segment):
			track_root.remove_child(segment)
			segment.queue_free()
	floor_segments.clear()
	_setup_track()


func _add_clouds() -> void:
	for i in range(12):
		var cloud := Node3D.new()
		cloud.position = Vector3(randf_range(-22.0, 22.0), randf_range(3.0, 10.0), randf_range(-100.0, -12.0))
		add_child(cloud)
		for puff in range(3):
			var sphere := _create_sphere(randf_range(1.1, 2.2), Color("8faabe"), 0.9)
			sphere.position = Vector3(float(puff) * 1.15, randf_range(-0.22, 0.22), randf_range(-0.3, 0.3))
			cloud.add_child(sphere)


func _setup_track() -> void:
	var platform_color := _theme_color("platform")
	var surface_color := _theme_color("surface")
	var edge_color := _theme_color("edge")
	var marker_color := _theme_color("marker")
	for i in range(SEGMENT_COUNT):
		var segment := Node3D.new()
		segment.position.z = -float(i) * SEGMENT_LENGTH
		track_root.add_child(segment)
		floor_segments.append(segment)

		var platform := _create_box(Vector3(TRACK_WIDTH, 0.22, SEGMENT_LENGTH - PLATFORM_GAP), platform_color, 0.52)
		platform.position.y = -0.13
		segment.add_child(platform)

		var top_surface := _create_box(Vector3(TRACK_WIDTH - 0.24, 0.035, SEGMENT_LENGTH - PLATFORM_GAP - 0.2), surface_color, 0.42)
		top_surface.position.y = 0.005
		segment.add_child(top_surface)

		for side in [-1, 1]:
			var edge := _create_box(Vector3(0.1, 0.11, SEGMENT_LENGTH - PLATFORM_GAP), edge_color, 0.42)
			edge.position = Vector3(float(side) * (TRACK_WIDTH * 0.5 - 0.18), 0.09, 0.0)
			segment.add_child(edge)

		if i % 3 == 1:
			var marker := _create_box(Vector3(0.32, 0.05, 1.65), marker_color, 0.35)
			marker.position = Vector3(0.0, 0.035, 0.0)
			segment.add_child(marker)


func _setup_player() -> void:
	player_root = Node3D.new()
	player_root.name = "RollingBall"
	player_root.position = Vector3(0.0, PLAYER_RADIUS + 0.02, PLAYER_Z)
	add_child(player_root)

	player_ball = _create_sphere(PLAYER_RADIUS, _theme_color("ball"), 0.18)
	player_ball.name = "PearlBall"
	player_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	player_root.add_child(player_ball)


func _setup_finish_line() -> void:
	finish_root = Node3D.new()
	finish_root.name = "FinishLine"
	finish_root.position = Vector3(0.0, 0.0, -FINISH_DISTANCE)
	add_child(finish_root)

	for side in [-1, 1]:
		var post := _create_box(Vector3(0.42, 4.3, 0.46), Color("f5ffff"), 0.35)
		post.position = Vector3(float(side) * 3.7, 2.15, 0.0)
		finish_root.add_child(post)
		for stripe_index in range(3):
			var stripe := _create_box(Vector3(0.46, 0.34, 0.5), Color("fa9e43"), 0.35)
			stripe.position = Vector3(float(side) * 3.7, 0.9 + float(stripe_index) * 1.18, 0.0)
			finish_root.add_child(stripe)

	var banner := _create_box(Vector3(7.8, 0.78, 0.38), Color("fa9e43"), 0.35)
	banner.position = Vector3(0.0, 4.15, 0.0)
	finish_root.add_child(banner)

	var finish_label := Label3D.new()
	finish_label.text = "FINISH"
	finish_label.font_size = 120
	finish_label.outline_size = 12
	finish_label.modulate = Color("f5ffff")
	finish_label.position = Vector3(0.0, 4.15, 0.23)
	finish_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	finish_label.pixel_size = 0.008
	finish_root.add_child(finish_label)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(20.0, 16.0)
	hud_label.size = Vector2(920.0, 42.0)
	hud_label.add_theme_font_size_override("font_size", 23)
	hud_label.add_theme_color_override("font_color", Color("f5ffff"))
	hud_label.add_theme_color_override("font_shadow_color", Color("1b2071"))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud_label)

	hint_label = Label.new()
	hint_label.position = Vector2(0.0, 557.0)
	hint_label.size = Vector2(960.0, 28.0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", Color("f5ffff"))
	layer.add_child(hint_label)

	game_over_panel = ColorRect.new()
	game_over_panel.position = Vector2.ZERO
	game_over_panel.size = Vector2(960.0, 600.0)
	game_over_panel.color = Color(0.02, 0.03, 0.08, 0.0)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game_over_panel)

	center_label = Label.new()
	center_label.position = Vector2(0.0, 205.0)
	center_label.size = Vector2(960.0, 170.0)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 34)
	center_label.add_theme_color_override("font_color", Color("f5ffff"))
	center_label.add_theme_color_override("font_outline_color", Color("1b2071"))
	center_label.add_theme_constant_override("outline_size", 7)
	layer.add_child(center_label)


func _setup_music() -> void:
	music_generator = AudioStreamGenerator.new()
	music_generator.mix_rate = MUSIC_MIX_RATE
	music_generator.buffer_length = 0.45

	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.stream = music_generator
	music_player.volume_db = -13.0
	add_child(music_player)
	music_player.play()


func _fill_music() -> void:
	if music_playback == null:
		music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if music_playback == null:
			return

	var frame_count := music_playback.get_frames_available()
	for _frame in range(frame_count):
		var step_duration := MUSIC_STEP_DURATION
		var lead_notes = MUSIC_LEAD
		var bass_notes = MUSIC_BASS
		if music_mode == 1:
			step_duration = MUSIC_END_STEP_DURATION
			lead_notes = MUSIC_END_LEAD
			bass_notes = MUSIC_END_BASS
		elif music_mode == 2:
			step_duration = MUSIC_WIN_STEP_DURATION
			lead_notes = MUSIC_WIN_LEAD
			bass_notes = MUSIC_WIN_BASS
		var step_index := int(music_time / step_duration) % lead_notes.size()
		var note_progress := fmod(music_time, step_duration) / step_duration
		var lead_frequency := float(lead_notes[step_index])
		var bass_frequency := float(bass_notes[step_index])
		music_lead_phase = fmod(music_lead_phase + TAU * lead_frequency / MUSIC_MIX_RATE, TAU)
		music_bass_phase = fmod(music_bass_phase + TAU * bass_frequency / MUSIC_MIX_RATE, TAU)

		var lead_envelope := pow(1.0 - note_progress, 2.2)
		var lead_gain := 0.10 if music_mode == 0 else 0.12
		var bass_gain := 0.045 if music_mode == 0 else 0.055
		var lead := sin(music_lead_phase) * lead_envelope * lead_gain
		var bass := sin(music_bass_phase) * bass_gain
		var sample := lead + bass
		music_playback.push_frame(Vector2(sample, sample))
		music_time += 1.0 / MUSIC_MIX_RATE


func _reset_game() -> void:
	_clear_runtime_nodes()
	var was_not_level_one := current_level != 1
	current_level = 1
	level_two_active = false
	level_banner_timer = 0.0
	if was_not_level_one:
		_rebuild_track()
		_apply_level_theme()
	player_x = 0.0
	player_y = PLAYER_RADIUS + 0.02
	fall_velocity = 0.0
	fall_elapsed = 0.0
	falling = false
	player_root.position = Vector3(player_x, player_y, PLAYER_Z)
	player_ball.rotation = Vector3.ZERO
	speed = CRUISE_SPEED
	distance = 0.0
	pickups_collected = 0
	spawn_timer = 0.6
	game_over = false
	game_complete = false
	failure_text = ""
	music_time = 0.0
	music_lead_phase = 0.0
	music_bass_phase = 0.0
	music_mode = 0
	finish_root.position.z = -FINISH_DISTANCE
	finish_root.visible = true
	camera.position = Vector3(0.0, 7.2, 11.5)
	camera.look_at(Vector3(0.0, 0.0, -24.0), Vector3.UP)
	game_over_panel.color.a = 0.0
	_update_ui()


func _clear_runtime_nodes() -> void:
	for item in obstacles:
		var node: Node3D = item["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	for item in pickups:
		var node: Node3D = item["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	obstacles.clear()
	pickups.clear()


func _update_track(delta: float) -> void:
	for segment in floor_segments:
		segment.position.z += speed * delta
		if segment.position.z > SEGMENT_LENGTH:
			segment.position.z -= SEGMENT_LENGTH * float(SEGMENT_COUNT)


func _update_finish_line(delta: float) -> void:
	finish_root.position.z += speed * delta


func _update_fall(delta: float) -> void:
	fall_elapsed += delta
	fall_velocity -= FALL_GRAVITY * delta
	player_y += fall_velocity * delta
	player_root.position = Vector3(player_x, player_y, PLAYER_Z)
	player_ball.rotate_object_local(Vector3.RIGHT, speed * delta / PLAYER_RADIUS)
	# Keep the forward-facing view fixed while the ball drops out of frame.
	camera.position = fall_camera_position
	camera.look_at(fall_camera_target, Vector3.UP)
	if fall_elapsed >= FALL_DURATION:
		_end_game("掉出悬浮赛道！")


func _update_camera(_delta: float) -> void:
	var camera_y := 7.2 if falling else player_y + 7.2
	var look_y := 0.0 if falling else player_y * 0.18
	camera.position = Vector3(player_x, camera_y, 11.5)
	camera.look_at(Vector3(player_x, look_y, -24.0), Vector3.UP)


func _begin_fall() -> void:
	falling = true
	fall_velocity = 0.0
	fall_elapsed = 0.0
	fall_camera_position = camera.position
	fall_camera_target = Vector3(player_x, player_y * 0.18, -24.0)


func _update_obstacles(delta: float) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var item := obstacles[i]
		var node: Node3D = item["node"] as Node3D
		var z := float(item["z"]) + speed * delta
		item["z"] = z
		obstacles[i] = item
		node.position.z = z

		if abs(z - PLAYER_Z) <= float(item["half_z"]) + PLAYER_RADIUS and abs(player_x - float(item["x"])) <= float(item["half_x"]) + PLAYER_RADIUS:
			_end_game("撞到橙色方块！")
			return

		if z > REMOVE_Z:
			node.queue_free()
			obstacles.remove_at(i)


func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var item := pickups[i]
		var node: Node3D = item["node"] as Node3D
		var z := float(item["z"]) + speed * delta
		item["z"] = z
		pickups[i] = item
		node.position.z = z
		node.rotate_y(delta * 5.0)
		node.position.y = 1.08 + sin((distance + float(item["phase"])) * 0.14) * 0.12

		if abs(z - PLAYER_Z) <= 0.82 and abs(player_x - float(item["x"])) <= 0.76:
			pickups_collected += 1
			node.queue_free()
			pickups.remove_at(i)
			continue

		if z > REMOVE_Z:
			node.queue_free()
			pickups.remove_at(i)


func _spawn_course_pattern() -> void:
	var pattern := randi() % 4
	if pattern == 0:
		_spawn_block(-2.45, SPAWN_Z, 1.25, 5.6)
		_spawn_pickup_line(1.5, SPAWN_Z - 1.8, 4)
	elif pattern == 1:
		_spawn_block(2.45, SPAWN_Z, 1.25, 5.6)
		_spawn_pickup_line(-1.5, SPAWN_Z - 1.8, 4)
	elif pattern == 2:
		_spawn_block(-2.45, SPAWN_Z, 1.25, 5.1)
		_spawn_block(2.45, SPAWN_Z, 1.25, 5.1)
		_spawn_pickup_line(0.0, SPAWN_Z - 1.8, 4)
	else:
		_spawn_block(0.0, SPAWN_Z, 1.5, 6.7)
		_spawn_pickup_line(-2.35, SPAWN_Z - 1.8, 3)
		_spawn_pickup_line(2.35, SPAWN_Z - 1.8, 3)


func _spawn_block(x: float, z: float, width: float, height: float) -> void:
	var root := Node3D.new()
	root.name = "OrangeBlock"
	root.position = Vector3(x, 0.0, z)
	obstacle_root.add_child(root)

	var block_color := _theme_color("block")
	var top_color := _theme_color("block_top")
	var block := _create_box(Vector3(width, height, 1.18), block_color, 0.48 if current_level != 1 else 0.72)
	block.position.y = height * 0.5
	root.add_child(block)

	var top := _create_box(Vector3(width - 0.12, 0.09, 1.04), top_color, 0.38 if current_level != 1 else 0.65)
	top.position.y = height + 0.045
	root.add_child(top)

	obstacles.append({
		"node": root,
		"x": x,
		"z": z,
		"half_x": width * 0.5,
		"half_z": 0.59,
	})


func _spawn_pickup_line(x: float, start_z: float, count: int) -> void:
	for i in range(count):
		var root := _create_pickup()
		var z := start_z - float(i) * 2.15
		root.position = Vector3(x, 1.08, z)
		pickup_root.add_child(root)
		pickups.append({
			"node": root,
			"x": x,
			"z": z,
			"phase": float(i) * 0.9,
		})


func _create_pickup() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldenLightOrb"
	var material := StandardMaterial3D.new()
	material.albedo_color = _theme_color("pickup")
	material.emission_enabled = true
	material.emission = _theme_color("pickup_emission")
	material.emission_energy_multiplier = 0.35 if current_level != 1 else 0.2
	material.metallic = 0.12
	material.roughness = 0.28

	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 16
	mesh.rings = 8
	orb.mesh = mesh
	orb.material_override = material
	root.add_child(orb)
	return root


func _create_box(size: Vector3, color: Color, roughness := 0.6) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.04
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _create_sphere(radius: float, color: Color, roughness := 0.35) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 14
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _get_steer_input() -> float:
	var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	if left == right:
		return 0.0
	return -1.0 if left else 1.0


func _is_boosting() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)


func _end_game(reason: String) -> void:
	game_over = true
	falling = false
	failure_text = reason
	_switch_music(1)
	game_over_panel.color.a = 0.72
	best_score = max(best_score, _current_score())
	_update_ui()


func _finish_game() -> void:
	game_complete = true
	_switch_music(2)
	finish_root.visible = false
	best_score = max(best_score, _current_score())
	_update_ui()


func _current_score() -> int:
	return int(distance) + pickups_collected * 25


func _switch_music(mode: int) -> void:
	if music_mode == mode:
		return
	music_mode = mode
	music_time = 0.0
	music_lead_phase = 0.0
	music_bass_phase = 0.0


func _level_title() -> String:
	var level_names := ["夜雾赛道", "晴空冲刺", "绯红黄昏", "极光绿洲"]
	return "第 %d 关：%s" % [current_level, level_names[current_level - 1]]


func _update_ui() -> void:
	var remaining_distance := int(max(0.0, FINISH_DISTANCE - distance))
	var level_name := _level_title()
	hud_label.text = "%s     %s     距离 %d / %dm     剩余 %dm     速度 %.1f m/s     光球 %d     得分 %d     最佳 %d" % [
		level_name,
		"SKY BALL RUN",
		int(distance),
		int(FINISH_DISTANCE),
		remaining_distance,
		speed,
		pickups_collected,
		_current_score(),
		best_score,
	]
	hint_label.text = "A / D 或 ← / → 左右滚动    |    鼠标左键 / W / ↑ / 空格 加速    |    边缘没有护栏，小心坠落    |    Esc 退出"
	center_label.visible = game_over or game_complete or level_banner_timer > 0.0
	if game_over:
		center_label.text = "%s\n按 空格 / R / Enter 重新开始" % failure_text
	elif game_complete:
		center_label.text = "抵达终点！\n按 空格 / R / Enter 再来一局"
	elif level_banner_timer > 0.0:
		center_label.text = "%s\n准备进入" % _level_title()

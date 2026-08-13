extends CanvasLayer

var game: Node
var main_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var menu_layer: Control
var menu_backdrop: ColorRect
var settings_volume: HSlider
var volume_value_label: Label
var settings_music: CheckButton
var settings_fullscreen: CheckButton
var menu_title: Label
var status_label: Label
var main_start_button: Button

func setup(game_node: Node) -> void:
	game = game_node
	_build_ui()
	show_main_menu()

func _build_ui() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)
	menu_backdrop = ColorRect.new()
	menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_backdrop.color = Color(0.005, 0.012, 0.04, 0.72)
	menu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(menu_backdrop)

	main_panel = _create_panel("SKY BALL RUN", "四关悬浮赛道 · 滚球跑酷原型")
	main_panel.position = Vector2(260, 92)
	main_panel.size = Vector2(440, 410)
	menu_layer.add_child(main_panel)
	var main_box := main_panel.get_child(0) as VBoxContainer
	main_start_button = _add_button(main_box, "开始游戏", _on_start_pressed)
	_add_button(main_box, "设置", _on_settings_pressed)
	_add_button(main_box, "退出游戏", _on_quit_pressed)
	status_label = Label.new()
	status_label.text = "A / D 移动 · W / 空格 加速 · Esc 暂停"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("9cb7c9"))
	main_box.add_child(status_label)

	pause_panel = _create_panel("已暂停", "赛道已暂停，准备好后继续")
	pause_panel.position = Vector2(300, 132)
	pause_panel.size = Vector2(360, 330)
	menu_layer.add_child(pause_panel)
	var pause_box := pause_panel.get_child(0) as VBoxContainer
	_add_button(pause_box, "继续游戏", _on_resume_pressed)
	_add_button(pause_box, "重新开始", _on_restart_pressed)
	_add_button(pause_box, "设置", _on_settings_pressed)
	_add_button(pause_box, "返回主菜单", _on_main_menu_pressed)

	settings_panel = _create_panel("设置", "设置会自动保存到本机")
	settings_panel.position = Vector2(220, 68)
	settings_panel.size = Vector2(520, 465)
	menu_layer.add_child(settings_panel)
	var settings_box := settings_panel.get_child(0) as VBoxContainer
	var volume_label := Label.new()
	volume_label.text = "主音量"
	volume_label.add_theme_font_size_override("font_size", 20)
	settings_box.add_child(volume_label)
	settings_volume = HSlider.new()
	settings_volume.min_value = 0.0
	settings_volume.max_value = 1.0
	settings_volume.step = 0.01
	settings_volume.custom_minimum_size = Vector2(0, 36)
	settings_volume.value_changed.connect(_on_volume_changed)
	settings_box.add_child(settings_volume)
	volume_value_label = Label.new()
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_value_label.add_theme_color_override("font_color", Color("a9c5d4"))
	settings_box.add_child(volume_value_label)
	settings_music = CheckButton.new()
	settings_music.text = "开启音乐"
	settings_music.toggled.connect(_on_music_toggled)
	settings_box.add_child(settings_music)
	settings_fullscreen = CheckButton.new()
	settings_fullscreen.text = "全屏模式"
	settings_fullscreen.toggled.connect(_on_fullscreen_toggled)
	settings_box.add_child(settings_fullscreen)
	_add_button(settings_box, "返回", _on_settings_back_pressed)

	_apply_theme()
	_hide_all()

func _create_panel(title_text: String, subtitle_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("a9c5d4"))
	box.add_child(subtitle)
	return panel

func _add_button(box: VBoxContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	box.add_child(button)
	return button

func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.03, 0.11, 0.94)
	panel_style.border_color = Color("fa9e43")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	for panel in [main_panel, pause_panel, settings_panel]:
		panel.add_theme_stylebox_override("panel", panel_style)

func _hide_all() -> void:
	menu_backdrop.visible = false
	main_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false

func show_main_menu() -> void:
	_hide_all()
	menu_backdrop.visible = true
	main_panel.visible = true
	main_start_button.grab_focus()
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP

func show_pause_menu() -> void:
	_hide_all()
	menu_backdrop.visible = true
	pause_panel.visible = true
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP

func show_settings() -> void:
	_hide_all()
	menu_backdrop.visible = true
	settings_panel.visible = true
	settings_volume.value = Settings.master_volume
	volume_value_label.text = "%d%%" % int(Settings.master_volume * 100.0)
	settings_music.button_pressed = Settings.music_enabled
	settings_fullscreen.button_pressed = Settings.fullscreen

func hide_menu() -> void:
	_hide_all()
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_start_pressed() -> void:
	game.start_new_game()
	hide_menu()

func _on_resume_pressed() -> void:
	game.resume_game()
	hide_menu()

func _on_restart_pressed() -> void:
	game.restart_from_menu()
	hide_menu()

func _on_main_menu_pressed() -> void:
	game.open_main_menu()
	show_main_menu()

func _on_settings_pressed() -> void:
	show_settings()

func _on_settings_back_pressed() -> void:
	if game.is_game_paused():
		show_pause_menu()
	else:
		show_main_menu()

func _on_quit_pressed() -> void:
	game.quit_game()

func _on_volume_changed(value: float) -> void:
	volume_value_label.text = "%d%%" % int(value * 100.0)
	Settings.set_master_volume(value)

func _on_music_toggled(value: bool) -> void:
	Settings.set_music_enabled(value)

func _on_fullscreen_toggled(value: bool) -> void:
	Settings.set_fullscreen(value)

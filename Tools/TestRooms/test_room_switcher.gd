class_name TestRoomSwitcher
extends PanelContainer

const ROOMS: Array[Dictionary] = [
	{
		"key": "1",
		"name": "Combat Proving Ground",
		"path": "res://Tools/TestRooms/test_room_combat.tscn",
		"desc": "Quadrants, Range Rings, Target Dummies, Weapons, Walls"
	},
	{
		"key": "2",
		"name": "Texture & Animation Gallery",
		"path": "res://Tools/TestRooms/test_room_assets.tscn",
		"desc": "PhasedAnimator, Line2D Whip 3-Slice, Shaders, Rule 12 Icon Audit"
	},
	{
		"key": "3",
		"name": "Boss & Swarm Stress Lab",
		"path": "res://Tools/TestRooms/test_room_boss_swarm.tscn",
		"desc": "Boss States (Amoeba/Franklin), Auto-Pause, N=500..5000 Benchmark"
	},
	{
		"key": "4",
		"name": "UI, Localization & Audio",
		"path": "res://Tools/TestRooms/test_room_ui_audio.tscn",
		"desc": "3-Locale Card Wall, Rule 14 Focus Graph, Audio Polyphony"
	},
	{
		"key": "5",
		"name": "Diorama Studio",
		"path": "res://TitleScreen/HowToPlay/diorama_studio.tscn",
		"desc": "Visual JSON snapshot recorder & playback sandbox"
	},
	{
		"key": "6",
		"name": "Survival World",
		"path": "res://World/world.tscn",
		"desc": "Main gameplay loop & horde survival map"
	},
	{
		"key": "7",
		"name": "Title Screen",
		"path": "res://TitleScreen/menu.tscn",
		"desc": "Main menu & settings"
	}
]

var _was_paused: bool = false
var room_buttons: Array[Button] = []

func _init() -> void:
	name = "TestRoomSwitcher"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme = load("res://Themes/DebugButtons.tres")
	z_index = 200

	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -210.0
	offset_top = -140.0
	offset_right = 210.0
	offset_bottom = 140.0

	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "TEST ROOM SWITCHER (F5)"
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var btn_close := Button.new()
	btn_close.text = " X "
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.custom_minimum_size = Vector2(20, 16)
	btn_close.pressed.connect(close_modal)
	header.add_child(btn_close)

	var hint := Label.new()
	hint.text = "Press 1-7 to jump instantly | Esc to close"
	hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	vbox.add_child(hint)

	# Rooms list
	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(list_vbox)

	for room in ROOMS:
		var r_path: String = room["path"]
		var r_btn := Button.new()
		r_btn.text = "[%s] %s" % [room["key"], room["name"]]
		r_btn.focus_mode = Control.FOCUS_NONE
		r_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		r_btn.tooltip_text = room["desc"]
		r_btn.custom_minimum_size = Vector2(0, 20)
		r_btn.pressed.connect(func(): switch_to_room(r_path))
		list_vbox.add_child(r_btn)
		room_buttons.append(r_btn)

func toggle_modal() -> void:
	if visible:
		close_modal()
	else:
		open_modal()

func open_modal() -> void:
	visible = true
	_was_paused = get_tree().paused if get_tree() else false
	if get_tree():
		get_tree().paused = true

func close_modal() -> void:
	visible = false
	if get_tree():
		get_tree().paused = _was_paused

func switch_to_room(path: String) -> void:
	visible = false
	if get_tree():
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(path)

func _is_cancel(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_cancel(event):
		close_modal()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var eff_key := DebugController.get_effective_keycode(event)
		if eff_key == KEY_F5:
			close_modal()
			get_viewport().set_input_as_handled()
			return
		var key_str := OS.get_keycode_string(eff_key)
		for room in ROOMS:
			if room["key"] == key_str:
				switch_to_room(room["path"])
				get_viewport().set_input_as_handled()
				return

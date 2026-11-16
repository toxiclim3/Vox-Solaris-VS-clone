class_name TestRoomBase
extends Node2D

const SwitcherClass = preload("res://Tools/TestRooms/test_room_switcher.gd")

var ui_layer: CanvasLayer = null
var top_bar: PanelContainer = null
var title_label: Label = null
var extra_buttons_bar: HBoxContainer = null
var legend_panel: PanelContainer = null
var switcher: Control = null
var debug_controller: DebugController = null
var camera: Camera2D = null

var grid_node: Node2D = null
var draw_grid: bool = true
var draw_range_rings: bool = true
var ring_centers: Array[Vector2] = [Vector2.ZERO]
var ring_radii: Array[float] = [50.0, 100.0, 180.0, 250.0]

func _ready() -> void:
	# Ensure time scale and unpaused
	get_tree().paused = false
	Engine.time_scale = 1.0

	_setup_camera()
	_setup_grid_visuals()
	_setup_ui()
	_setup_debug_controller()
	_setup_room()

func _setup_camera() -> void:
	if camera == null:
		camera = Camera2D.new()
		camera.name = "RoomCamera"
		camera.position = Vector2.ZERO
		add_child(camera)

func _setup_grid_visuals() -> void:
	grid_node = Node2D.new()
	grid_node.name = "FloorGrid"
	grid_node.z_index = -10
	add_child(grid_node)
	grid_node.draw.connect(_on_draw_grid)

func _on_draw_grid() -> void:
	if not grid_node:
		return
	if draw_grid:
		var grid_step := 32.0
		var extent := 600.0
		var grid_col := Color(1.0, 1.0, 1.0, 0.05)
		var axis_col_x := Color(0.9, 0.2, 0.2, 0.25)
		var axis_col_y := Color(0.2, 0.9, 0.2, 0.25)

		for x in range(-int(extent), int(extent) + 1, int(grid_step)):
			var col := axis_col_y if x == 0 else grid_col
			grid_node.draw_line(Vector2(x, -extent), Vector2(x, extent), col, 1.0)
		for y in range(-int(extent), int(extent) + 1, int(grid_step)):
			var col := axis_col_x if y == 0 else grid_col
			grid_node.draw_line(Vector2(-extent, y), Vector2(extent, y), col, 1.0)

	if draw_range_rings:
		var ring_col := Color(0.2, 0.75, 1.0, 0.22)
		for center in ring_centers:
			for r in ring_radii:
				grid_node.draw_arc(center, r, 0.0, TAU, 48, ring_col, 1.0)

func queue_grid_redraw() -> void:
	if grid_node:
		grid_node.queue_redraw()

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "TestRoomUI"
	ui_layer.layer = 90
	add_child(ui_layer)

	# Top bar
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.theme = load("res://Themes/DebugButtons.tres")
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 22)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.92)
	sb.border_color = Color(0.25, 0.35, 0.5, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	top_bar.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	top_bar.add_child(hbox)

	title_label = Label.new()
	title_label.text = _get_room_title()
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	hbox.add_child(title_label)

	var sep1 := VSeparator.new()
	hbox.add_child(sep1)

	var btn_switcher := Button.new()
	btn_switcher.text = "F5 Rooms"
	btn_switcher.pressed.connect(toggle_switcher)
	hbox.add_child(btn_switcher)

	var btn_legend := Button.new()
	btn_legend.text = "H Keys"
	btn_legend.pressed.connect(toggle_legend)
	hbox.add_child(btn_legend)

	var btn_reset := Button.new()
	btn_reset.text = "R Reset"
	btn_reset.pressed.connect(reset_room)
	hbox.add_child(btn_reset)

	var btn_title := Button.new()
	btn_title.text = "Bksp Title"
	btn_title.pressed.connect(switch_to_title)
	hbox.add_child(btn_title)

	var sep2 := VSeparator.new()
	hbox.add_child(sep2)

	extra_buttons_bar = HBoxContainer.new()
	extra_buttons_bar.add_theme_constant_override("separation", 3)
	hbox.add_child(extra_buttons_bar)

	# Keybind Legend Panel
	_build_legend_panel()

	# Switcher Modal
	switcher = SwitcherClass.new()
	ui_layer.add_child(switcher)

func _build_legend_panel() -> void:
	legend_panel = PanelContainer.new()
	legend_panel.name = "KeybindLegend"
	legend_panel.theme = load("res://Themes/DebugButtons.tres")
	legend_panel.visible = false
	legend_panel.z_index = 150

	legend_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend_panel.offset_left = -230.0
	legend_panel.offset_top = 26.0
	legend_panel.offset_right = -6.0
	legend_panel.offset_bottom = 260.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	sb.border_color = Color(0.3, 0.6, 0.9, 0.9)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	legend_panel.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(legend_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	legend_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "KEYBIND LEGEND"
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	header.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var btn_x := Button.new()
	btn_x.text = "X"
	btn_x.custom_minimum_size = Vector2(16, 14)
	btn_x.pressed.connect(toggle_legend)
	header.add_child(btn_x)

	# Universal keybinds
	_add_legend_section(vbox, "UNIVERSAL KEYS", [
		{"key": "F5 / Esc", "desc": "Room Switcher (Pause)"},
		{"key": "Bksp", "desc": "Return to Title Screen"},
		{"key": "H", "desc": "Toggle This Legend"},
		{"key": "R", "desc": "Reset Active Room"},
		{"key": "F1", "desc": "Debug Workbench"},
		{"key": "F2", "desc": "Telemetry / DPS HUD"},
		{"key": "F3", "desc": "Swarm & Layer-3 Visualizer"},
		{"key": "F4 / M5", "desc": "Freeze Simulation"},
		{"key": ".", "desc": "Step 1 Physics Frame (When Frozen)"}
	])

	# Room-specific keybinds
	var room_keys := _get_keybind_entries()
	if room_keys.size() > 0:
		_add_legend_section(vbox, "ROOM SHORTCUTS", room_keys)

func _add_legend_section(parent: VBoxContainer, header_text: String, entries: Array[Dictionary]) -> void:
	var h_lbl := Label.new()
	h_lbl.text = "— %s —" % header_text
	h_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	parent.add_child(h_lbl)

	for entry in entries:
		var row := HBoxContainer.new()
		parent.add_child(row)

		var k_lbl := Label.new()
		k_lbl.text = "[%s]" % entry["key"]
		k_lbl.custom_minimum_size = Vector2(64, 0)
		k_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
		row.add_child(k_lbl)

		var d_lbl := Label.new()
		d_lbl.text = entry["desc"]
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d_lbl)

func _setup_debug_controller() -> void:
	if not SettingsManager.is_debug_enabled():
		SettingsManager.debug_unlocked = true
	debug_controller = DebugController.new()
	debug_controller.switcher = switcher
	add_child(debug_controller)
	debug_controller.attach(ui_layer, self)

func toggle_switcher() -> void:
	if debug_controller and debug_controller.switcher:
		debug_controller.switcher.toggle_modal()
	elif switcher:
		switcher.toggle_modal()

func toggle_legend() -> void:
	if legend_panel:
		legend_panel.visible = not legend_panel.visible

func reset_room() -> void:
	_reset_room_state()

func switch_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://TitleScreen/menu.tscn")

func _is_esc(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			return true
	return false

func _is_backspace(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE:
			return true
	return false

func _has_open_modal() -> bool:
	if switcher and switcher.visible:
		return true
	if legend_panel and legend_panel.visible:
		return true
	if debug_controller and debug_controller.workbench and debug_controller.workbench.visible:
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() else null
	if focus is LineEdit or focus is TextEdit:
		return

	if _has_open_modal():
		var is_f5 := bool(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5)
		if _is_esc(event) or _is_backspace(event) or (is_f5 and switcher and switcher.visible):
			if switcher and switcher.visible:
				switcher.close_modal()
			if legend_panel and legend_panel.visible:
				legend_panel.visible = false
			if debug_controller and debug_controller.workbench and debug_controller.workbench.visible:
				debug_controller.workbench.close_modal()
			get_viewport().set_input_as_handled()
			return
		return

	if _is_esc(event):
		toggle_switcher()
		get_viewport().set_input_as_handled()
		return
	if _is_backspace(event):
		switch_to_title()
		get_viewport().set_input_as_handled()
		return

	if debug_controller and debug_controller.handle_key_event(event):
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return

	match kev.keycode:
		KEY_F5:
			toggle_switcher()
			get_viewport().set_input_as_handled()
			return
		KEY_H:
			toggle_legend()
			get_viewport().set_input_as_handled()
			return
		KEY_R:
			reset_room()
			get_viewport().set_input_as_handled()
			return

	if _handle_room_key(kev):
		get_viewport().set_input_as_handled()

# --- Subclass Extension Points ---

func _get_room_title() -> String:
	return "TEST ROOM"

func _get_keybind_entries() -> Array[Dictionary]:
	return []

func _setup_room() -> void:
	pass

func _reset_room_state() -> void:
	pass

func _handle_room_key(_event: InputEventKey) -> bool:
	return false

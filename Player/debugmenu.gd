# MarginContainer sliding quick-debug drawer (Hold Tab >=180ms to peek, Tap Tab <180ms to pin)
extends MarginContainer

class_name SlidingMenu

const TAP_THRESHOLD_MS: int = 180
const MENU_PADDING_OFFSET: float = 8.0

@export var slide_duration: float = 0.20
@export var menu_width: float = 160.0

var is_open: bool = false
var is_pinned: bool = false

var controller: Node = null

var _slide_tween: Tween = null
var _tab_press_msec: int = 0
var _opened_by_this_press: bool = false
var _more_expanded: bool = false

# UI refs for state synchronization
var _btn_pin: Button = null
var _btn_godmode: Button = null
var _btn_spawns: Button = null
var _btn_stats: Button = null
var _btn_hitbox: Button = null
var _btn_freeze: Button = null
var _speed_buttons: Dictionary = {}
var _btn_more_toggle: Button = null
var _more_box: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect_w := self.get_rect().size.x
	if rect_w > 10.0:
		menu_width = rect_w

	_set_menu_margin(menu_width + MENU_PADDING_OFFSET)
	self.visible = false
	get_viewport().size_changed.connect(_on_window_resized)

func rebuild_layout(ctrl: Node) -> void:
	controller = ctrl
	var padded := get_node_or_null("Padded container") as MarginContainer
	if padded:
		padded.add_theme_constant_override("margin_left", 6)
		padded.add_theme_constant_override("margin_top", 5)
		padded.add_theme_constant_override("margin_right", 6)
		padded.add_theme_constant_override("margin_bottom", 5)

	var vbox := get_node_or_null("Padded container/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 3)

	for ch in vbox.get_children():
		ch.queue_free()

	var dbg_theme: Theme = load("res://Themes/DebugButtons.tres")
	vbox.theme = dbg_theme

	# 1. Header row: Title + [Pin] + [F1 Bench]
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 2)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = tr("ui_debug")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.40))
	hdr.add_child(title)

	_btn_pin = _make_btn("Pin", 28, func(): set_pinned(not is_pinned))
	hdr.add_child(_btn_pin)

	var btn_bench := _make_btn("F1 Bench", 46, func(): _call_ctrl("toggle_workbench"))
	btn_bench.modulate = Color(0.75, 0.90, 1.0)
	hdr.add_child(btn_bench)

	vbox.add_child(HSeparator.new())

	# 2. Core Toggles 2x2
	var core_grid := _make_grid(2)
	vbox.add_child(core_grid)

	_btn_godmode = _make_btn("Godmode", 0, func(): _call_ctrl("toggle_godmode"); sync_state())
	_btn_spawns = _make_btn("Spawns", 0, func(): _call_ctrl("toggle_spawns"); sync_state())
	_btn_stats = _make_btn("F2 Stats", 0, func(): _call_ctrl("toggle_telemetry"); sync_state())
	_btn_hitbox = _make_btn("F3 Hitbox", 0, func(): _call_ctrl("toggle_visualizer"); sync_state())
	for b in [_btn_godmode, _btn_spawns, _btn_stats, _btn_hitbox]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		core_grid.add_child(b)

	# 3. Time Scale Strip
	vbox.add_child(_section_lbl("Simulation Speed & Time"))
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 2)
	vbox.add_child(spd_row)
	_speed_buttons.clear()
	for sp_pair in [[0.25, ".2x"], [0.5, ".5x"], [1.0, "1x"], [2.0, "2x"], [4.0, "4x"]]:
		var s_val: float = sp_pair[0]
		var sb := _make_btn(sp_pair[1], 24, func(): _call_ctrl("set_time_scale", [s_val]); sync_state())
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spd_row.add_child(sb)
		_speed_buttons[s_val] = sb

	var time_grid := _make_grid(2)
	vbox.add_child(time_grid)
	var b_t1 := _make_btn("+1 Min", 0, func(): _call_ctrl("advance_time_synced", [60]))
	var b_t5 := _make_btn("+5 Min", 0, func(): _call_ctrl("advance_time_synced", [300]))
	_btn_freeze = _make_btn("Freeze (F4/M5)", 0, func(): _call_ctrl("toggle_freeze"); sync_state())
	var b_step := _make_btn("Step (.)", 0, func(): _call_ctrl("step_one_physics_frame"); sync_state())
	for b in [b_t1, b_t5, _btn_freeze, b_step]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_grid.add_child(b)

	# 4. Progression & Combat Thresholds
	vbox.add_child(_section_lbl("XP, HP Thresholds & CDs"))
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 2)
	vbox.add_child(xp_row)
	var b_lvl := _make_btn("+1 Level", 0, func(): _call_ctrl("give_level"))
	var b_xp := _make_btn("+1k XP", 0, func(): _call_ctrl("give_xp", [1000]))
	for b in [b_lvl, b_xp]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_row.add_child(b)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 2)
	vbox.add_child(hp_row)
	for hp_pair in [[1.0, "100%"], [0.94, "94%"], [0.29, "29%"], [0.19, "19%"]]:
		var pct: float = hp_pair[0]
		var hb := _make_btn(hp_pair[1], 0, func(): _call_ctrl("set_hp_percent", [pct]))
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_row.add_child(hb)

	var react_row := HBoxContainer.new()
	react_row.add_theme_constant_override("separation", 2)
	vbox.add_child(react_row)
	var b_hit := _make_btn("Hit Self (10)", 0, func(): _call_ctrl("trigger_attacker_self_damage", [10.0]))
	var b_cd := _make_btn("Reset CDs", 0, func(): _call_ctrl("reset_item_cooldowns"))
	for b in [b_hit, b_cd]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		react_row.add_child(b)

	# 5. Sandbox Quick Actions
	vbox.add_child(_section_lbl("World & Sandbox"))
	var sb_grid := _make_grid(2)
	vbox.add_child(sb_grid)
	var b_clr := _make_btn("Clear Enemies", 0, func(): _call_ctrl("clear_all_enemies"))
	var b_mag := _make_btn("Magnet Gems", 0, func(): _call_ctrl("magnet_all_gems"))
	var b_dum := _make_btn("+Dummy", 0, func(): _call_ctrl("spawn_target_dummy", [false]))
	var b_boss := _make_btn("Boss / Wave...", 0, func(): _call_ctrl("open_workbench_tab", [1]))
	for b in [b_clr, b_mag, b_dum, b_boss]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb_grid.add_child(b)

	# 6. Collapsible Audio / Run Tray
	_btn_more_toggle = _make_btn("More (Audio / Run) >", 0, _toggle_more_tray)
	vbox.add_child(_btn_more_toggle)

	_more_box = VBoxContainer.new()
	_more_box.add_theme_constant_override("separation", 2)
	_more_box.visible = _more_expanded
	vbox.add_child(_more_box)

	var aud_grid := _make_grid(2)
	_more_box.add_child(aud_grid)
	var b_nn := _make_btn("Next Norm", 0, func(): _call_ctrl("next_normal_track"))
	var b_nb := _make_btn("Next Boss", 0, func(): _call_ctrl("next_boss_track"))
	var b_pm := _make_btn("Mute Music", 0, func(): _call_ctrl("pause_music"))
	var b_um := _make_btn("Play Music", 0, func(): _call_ctrl("unpause_music"))
	for b in [b_nn, b_nb, b_pm, b_um]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aud_grid.add_child(b)

	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 2)
	_more_box.add_child(run_row)
	var b_kill := _make_btn("Kill", 0, func(): _call_ctrl("kill_player"))
	b_kill.modulate = Color(1.0, 0.55, 0.55)
	var b_end := _make_btn("End Run", 0, func(): _call_ctrl("end_run_to_menu"))
	var b_quit := _make_btn("Quit", 0, func(): _call_ctrl("exit_game"))
	for b in [b_kill, b_end, b_quit]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		run_row.add_child(b)

	sync_state()

func _make_btn(label_txt: String, min_w: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label_txt
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 15)
	b.pressed.connect(cb)
	return b

func _make_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	return g

func _section_lbl(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.65, 0.82, 0.96))
	return l

func _toggle_more_tray() -> void:
	_more_expanded = not _more_expanded
	if _more_box:
		_more_box.visible = _more_expanded
	if _btn_more_toggle:
		_btn_more_toggle.text = "More (Audio / Run) v" if _more_expanded else "More (Audio / Run) >"

func _call_ctrl(method_name: String, args: Array = []) -> void:
	if controller and is_instance_valid(controller) and controller.has_method(method_name):
		controller.callv(method_name, args)

func sync_state() -> void:
	if _btn_pin:
		_btn_pin.modulate = Color(0.45, 1.0, 0.55) if is_pinned else Color.WHITE
		_btn_pin.text = "Unpin" if is_pinned else "Pin"

	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if _btn_godmode:
		var gm := bool(p.get("godmode")) if p else false
		_btn_godmode.modulate = Color(0.45, 1.0, 0.55) if gm else Color.WHITE
		_btn_godmode.text = "God: ON" if gm else "God: OFF"

	var spawner := get_tree().get_first_node_in_group("spawner") if get_tree() else null
	if _btn_spawns:
		var sp_on := bool(spawner.get("isSpawningActive")) if spawner else true
		_btn_spawns.modulate = Color(0.45, 1.0, 0.55) if sp_on else Color(1.0, 0.55, 0.55)
		_btn_spawns.text = "Spawns: ON" if sp_on else "Spawns: OFF"

	if _btn_stats and controller:
		var t_vis := bool(controller.telemetry.visible) if controller.get("telemetry") else false
		_btn_stats.modulate = Color(0.45, 1.0, 0.55) if t_vis else Color.WHITE

	if _btn_hitbox and controller:
		var v_vis := bool(controller.visualizer.visible) if controller.get("visualizer") else false
		_btn_hitbox.modulate = Color(0.45, 1.0, 0.55) if v_vis else Color.WHITE

	if _btn_freeze:
		var frz := get_tree().paused if get_tree() else false
		_btn_freeze.modulate = Color(0.45, 0.85, 1.0) if frz else Color.WHITE
		_btn_freeze.text = "Unfreeze (F4/M5)" if frz else "Freeze (F4/M5)"

	for s_val in _speed_buttons.keys():
		var active := is_equal_approx(Engine.time_scale, float(s_val))
		_speed_buttons[s_val].modulate = Color(0.45, 1.0, 0.55) if active else Color.WHITE

# --- Tab Hold-to-Peek / Tap-to-Pin State Machine ---

func set_pinned(pinned: bool) -> void:
	is_pinned = pinned
	if is_pinned and not is_open:
		open_menu()
	sync_state()

func handle_tab_pressed() -> void:
	_tab_press_msec = Time.get_ticks_msec()
	if not is_open:
		_opened_by_this_press = true
		open_menu()
	else:
		_opened_by_this_press = false

func handle_tab_released() -> void:
	var elapsed := Time.get_ticks_msec() - _tab_press_msec
	if _opened_by_this_press:
		if elapsed < TAP_THRESHOLD_MS:
			set_pinned(true)
		else:
			set_pinned(false)
			close_menu()
	else:
		set_pinned(false)
		close_menu()
	_opened_by_this_press = false

func toggle_menu() -> void:
	if is_open:
		set_pinned(false)
		close_menu()
	else:
		set_pinned(true)

func open_menu() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	sync_state()
	self.visible = true
	is_open = true
	_slide_tween = create_tween()
	_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_menu_margin, menu_width + MENU_PADDING_OFFSET, 0.0, slide_duration)

func close_menu() -> void:
	if is_pinned:
		return
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	is_open = false
	_slide_tween = create_tween()
	_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_menu_margin, 0.0, menu_width + MENU_PADDING_OFFSET, slide_duration)
	_slide_tween.tween_callback(func():
		if not is_open:
			self.visible = false
	)

func _set_menu_margin(value: float) -> void:
	add_theme_constant_override("margin_left", int(value))
	add_theme_constant_override("margin_right", int(-value))
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)

func _on_window_resized() -> void:
	await get_tree().process_frame
	var rect_w := self.get_rect().size.x
	if rect_w > 10.0:
		menu_width = rect_w
	if is_open:
		_set_menu_margin(0)
	else:
		_set_menu_margin(menu_width + MENU_PADDING_OFFSET)

func _on_gui_open_menu() -> void:
	open_menu()

func _on_gui_close_menu() -> void:
	close_menu()

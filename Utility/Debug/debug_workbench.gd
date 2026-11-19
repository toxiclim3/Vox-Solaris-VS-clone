class_name DebugWorkbench
extends PanelContainer

var controller: Node = null

var filter_edit: LineEdit
var status_label: Label
var tab_buttons: Array[Button] = []
var tab_containers: Array[Control] = []
var active_tab: int = 0

# Build matrix state
var build_list_vbox: VBoxContainer
var slot_summary_label: Label

# Sandbox state
var boss_buttons_box: Control
var selected_pool: String = "normal"
var selected_formation: String = "ring"
var pool_buttons: Dictionary = {}
var formation_buttons: Dictionary = {}

# Char & World state
var char_buttons_box: Control
var grant_starter_check: CheckBox
var diff_badge_label: Label
var custom_diff_vbox: VBoxContainer
var allow_tainted_check: CheckBox

# Presets state
var custom_slots_vbox: VBoxContainer

# Movement state
var move_mode_badge_label: Label
var move_btn_coupled: Button
var move_btn_vanilla: Button
var move_sliders: Dictionary = {}
var move_value_labels: Dictionary = {}

var _was_paused_before_open: bool = false

const BUILTIN_PRESETS := [
	{
		"id": "early_min5",
		"label": "Early (Min 5)",
		"desc": "Lv12, t=5:00, Tier 4 starter + core passives",
	},
	{
		"id": "mid_min10",
		"label": "Mid (Min 10)",
		"desc": "Lv25, t=10:00, 3 weapons + balanced passives",
	},
	{
		"id": "endgame_min15",
		"label": "Endgame (Min 15)",
		"desc": "Lv45, t=15:00, full build + endless + boss items",
	},
	{
		"id": "punished_tank",
		"label": "Punished Tank",
		"desc": "Punished, Lv20, t=7:00, Whip + Thorn/Defense kit",
	},
]

func _init() -> void:
	name = "DebugWorkbench"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme = load("res://Themes/DebugButtons.tres")
	z_index = 100

	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -260.0
	offset_top = -158.0
	offset_right = 260.0
	offset_bottom = 158.0

	_build_shell()

func setup(ctrl: Node) -> void:
	controller = ctrl
	_rebuild_boss_buttons()
	_rebuild_character_buttons()
	refresh_active_tab()

func _build_shell() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 3)
	add_child(root_vbox)

	# Header Row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "WORKBENCH"
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	header.add_child(title)

	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "Filter..."
	filter_edit.custom_minimum_size = Vector2(92, 16)
	filter_edit.text_changed.connect(_on_filter_changed)
	header.add_child(filter_edit)

	var tab_names := ["Build", "Sandbox", "World", "Presets", "Move"]
	for i in range(tab_names.size()):
		var tbtn := Button.new()
		tbtn.text = tab_names[i]
		tbtn.custom_minimum_size = Vector2(42, 16)
		var idx := i
		tbtn.pressed.connect(func(): switch_tab(idx))
		header.add_child(tbtn)
		tab_buttons.append(tbtn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var btn_reset_dps := Button.new()
	btn_reset_dps.text = "Reset DPS"
	btn_reset_dps.pressed.connect(_on_reset_dps_pressed)
	header.add_child(btn_reset_dps)

	var btn_csv := Button.new()
	btn_csv.text = "CSV"
	btn_csv.pressed.connect(_on_export_csv_pressed)
	header.add_child(btn_csv)

	var btn_close := Button.new()
	btn_close.text = "X (F1)"
	btn_close.pressed.connect(close_modal)
	header.add_child(btn_close)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Content stack
	var body_stack := PanelContainer.new()
	body_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner_sb: StyleBox = load("res://Themes/Shadowpanel.tres")
	if inner_sb:
		body_stack.add_theme_stylebox_override("panel", inner_sb)
	root_vbox.add_child(body_stack)

	var t0 := _build_tab_build_matrix()
	var t1 := _build_tab_sandbox()
	var t2 := _build_tab_char_world()
	var t3 := _build_tab_presets()
	var t4 := _build_tab_movement()
	tab_containers = [t0, t1, t2, t3, t4]
	for t in tab_containers:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_stack.add_child(t)

	status_label = Label.new()
	status_label.text = "F1 Bench | F2 Stats | F3 Hitbox | Tab Drawer"
	status_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.90))
	root_vbox.add_child(status_label)

	for i in range(tab_containers.size()):
		tab_containers[i].visible = (i == 0)
	for i in range(tab_buttons.size()):
		tab_buttons[i].modulate = Color(0.55, 1.0, 0.65) if i == 0 else Color.WHITE

func _build_tab_build_matrix() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(top_bar)

	var btn_max := Button.new()
	btn_max.text = "Max Equipped"
	btn_max.pressed.connect(_on_max_all_equipped_pressed)
	top_bar.add_child(btn_max)

	var btn_clear := Button.new()
	btn_clear.text = "Reset All Items"
	btn_clear.pressed.connect(_on_reset_all_items_pressed)
	top_bar.add_child(btn_clear)

	slot_summary_label = Label.new()
	slot_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(slot_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	build_list_vbox = VBoxContainer.new()
	build_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(build_list_vbox)

	return vbox

func _build_tab_sandbox() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(vbox)

	# Target Dummies
	vbox.add_child(_section_header("Target Dummies (World Space DPS / Hit Reaction)"))
	var dummy_row := HBoxContainer.new()
	dummy_row.add_theme_constant_override("separation", 4)
	vbox.add_child(dummy_row)

	var b_d1 := Button.new()
	b_d1.text = "+ Immortal DPS Dummy"
	b_d1.pressed.connect(func(): _call_ctrl("spawn_target_dummy", [false]); _set_status("Spawned immortal DPS dummy"))
	dummy_row.add_child(b_d1)

	var b_d2 := Button.new()
	b_d2.text = "+ Retaliation Dummy"
	b_d2.pressed.connect(func(): _call_ctrl("spawn_target_dummy", [true]); _set_status("Spawned retaliation dummy (10 dmg / 1.5s)"))
	dummy_row.add_child(b_d2)

	var b_d3 := Button.new()
	b_d3.text = "Clear Dummies"
	b_d3.pressed.connect(func(): _call_ctrl("clear_target_dummies"); _set_status("Cleared all dummies"))
	dummy_row.add_child(b_d3)

	# Boss Spawner
	vbox.add_child(_section_header("Boss Encounters"))
	boss_buttons_box = HFlowContainer.new()
	boss_buttons_box.add_theme_constant_override("h_separation", 4)
	boss_buttons_box.add_theme_constant_override("v_separation", 3)
	vbox.add_child(boss_buttons_box)

	var warn_row := HBoxContainer.new()
	warn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(warn_row)
	var b_warn := Button.new()
	b_warn.text = "Trigger Boss Warning Banner"
	b_warn.pressed.connect(func(): _call_ctrl("show_boss_warning"); _set_status("Emitted boss warning"))
	warn_row.add_child(b_warn)

	# Enemy Wave Spawner
	vbox.add_child(_section_header("Controlled Wave Spawner"))
	var pool_row := HBoxContainer.new()
	pool_row.add_theme_constant_override("separation", 3)
	vbox.add_child(pool_row)
	var lbl_pool := Label.new()
	lbl_pool.text = "Pool:"
	pool_row.add_child(lbl_pool)
	for p_key in ["easy", "normal", "hard"]:
		var btn := Button.new()
		btn.text = str(p_key).capitalize()
		var pk: String = str(p_key)
		btn.pressed.connect(func(): selected_pool = pk; _sync_sandbox_highlights())
		pool_row.add_child(btn)
		pool_buttons[pk] = btn

	var form_row := HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 3)
	vbox.add_child(form_row)
	var lbl_form := Label.new()
	lbl_form.text = "Formation:"
	form_row.add_child(lbl_form)
	for f_pair in [["ring", "Ring"], ["front", "Front Cluster"], ["surround", "Tight Surround"]]:
		var btn := Button.new()
		btn.text = f_pair[1]
		var fk: String = f_pair[0]
		btn.pressed.connect(func(): selected_formation = fk; _sync_sandbox_highlights())
		form_row.add_child(btn)
		formation_buttons[fk] = btn

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 4)
	vbox.add_child(count_row)
	var lbl_cnt := Label.new()
	lbl_cnt.text = "Spawn:"
	count_row.add_child(lbl_cnt)
	for n in [1, 25, 100, 500]:
		var btn := Button.new()
		btn.text = "+%d" % n
		var cnt: int = n
		btn.pressed.connect(func():
			_call_ctrl("spawn_debug_wave", [selected_pool, cnt, selected_formation])
			_set_status("Spawned +%d %s (%s)" % [cnt, selected_pool, selected_formation])
		)
		count_row.add_child(btn)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 4)
	vbox.add_child(util_row)
	var b_clr := Button.new()
	b_clr.text = "Clear All Enemies"
	b_clr.pressed.connect(func(): _call_ctrl("clear_all_enemies"); _set_status("Cleared swarm & enemy nodes"))
	util_row.add_child(b_clr)

	var b_mag := Button.new()
	b_mag.text = "Magnet All Gems"
	b_mag.pressed.connect(func(): _call_ctrl("magnet_all_gems"); _set_status("Magnetized all loot gems"))
	util_row.add_child(b_mag)

	var b_spw := Button.new()
	b_spw.text = "Toggle Auto-Spawns"
	b_spw.pressed.connect(func(): _call_ctrl("toggle_spawns"); _set_status("Toggled spawner active state"))
	util_row.add_child(b_spw)

	_sync_sandbox_highlights()
	return scroll

func _build_tab_char_world() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Character Switcher
	vbox.add_child(_section_header("Mid-Run Character Switcher"))
	char_buttons_box = HBoxContainer.new()
	char_buttons_box.add_theme_constant_override("separation", 4)
	vbox.add_child(char_buttons_box)

	grant_starter_check = CheckBox.new()
	grant_starter_check.text = "Also grant new character's starting weapon"
	grant_starter_check.button_pressed = true
	vbox.add_child(grant_starter_check)

	# Difficulty Modifiers
	vbox.add_child(_section_header("Difficulty & Live Custom Modifiers"))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 3)
	vbox.add_child(diff_row)

	for d_pair in [
		[GlobalEvents.Difficulty.EASY, "Easy"],
		[GlobalEvents.Difficulty.NORMAL, "Normal"],
		[GlobalEvents.Difficulty.HARD, "Hard"],
		[GlobalEvents.Difficulty.CUSTOM, "Custom"],
	]:
		var btn := Button.new()
		btn.text = d_pair[1]
		var diff_val: int = d_pair[0]
		btn.pressed.connect(func():
			GlobalEvents.current_difficulty = diff_val
			StatsManager.mark_run_tainted()
			_refresh_char_world_tab()
		)
		diff_row.add_child(btn)

	diff_badge_label = Label.new()
	diff_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_child(diff_badge_label)

	custom_diff_vbox = VBoxContainer.new()
	custom_diff_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(custom_diff_vbox)

	# Camera & World Controls
	vbox.add_child(_section_header("Camera, Environment & Stats Protection"))
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 3)
	vbox.add_child(cam_row)
	var cam_lbl := Label.new()
	cam_lbl.text = "Zoom:"
	cam_row.add_child(cam_lbl)
	for z in [0.5, 0.75, 1.0, 1.25, 1.5]:
		var btn := Button.new()
		btn.text = "%sx" % str(z)
		var zv: float = z
		btn.pressed.connect(func(): _call_ctrl("set_camera_zoom", [zv]); _set_status("Camera zoom %.2fx" % zv))
		cam_row.add_child(btn)

	var env_row := HBoxContainer.new()
	env_row.add_theme_constant_override("separation", 4)
	vbox.add_child(env_row)
	var b_bg := Button.new()
	b_bg.text = "Advance Background"
	b_bg.pressed.connect(func(): GlobalEvents.advanceBackground.emit(); StatsManager.mark_run_tainted())
	env_row.add_child(b_bg)

	var b_shk := Button.new()
	b_shk.text = "Shake Test"
	b_shk.pressed.connect(func(): GlobalEvents.camera_shake.emit(5.0, 0.35))
	env_row.add_child(b_shk)

	allow_tainted_check = CheckBox.new()
	allow_tainted_check.text = "Allow Stats Saving While Tainted"
	allow_tainted_check.toggled.connect(func(on: bool):
		StatsManager.allow_tainted_stats = on
		_set_status("Tainted stats saving: %s" % ("ON" if on else "OFF"))
	)
	vbox.add_child(allow_tainted_check)

	return scroll

func _build_tab_presets() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	vbox.add_child(_section_header("Built-In Benchmark Presets (One-Click Time + Build Sync)"))
	for p_info in BUILTIN_PRESETS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var btn := Button.new()
		btn.text = "Apply " + p_info["label"]
		btn.custom_minimum_size = Vector2(115, 16)
		var pid: String = p_info["id"]
		btn.pressed.connect(func():
			_call_ctrl("apply_preset", [pid])
			refresh_active_tab()
			_set_status("Applied preset: " + pid)
		)
		row.add_child(btn)

		var desc := Label.new()
		desc.text = p_info["desc"]
		desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		row.add_child(desc)

	vbox.add_child(_section_header("Custom Saved Build Slots (user://debug_presets.cfg)"))
	custom_slots_vbox = VBoxContainer.new()
	custom_slots_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(custom_slots_vbox)

	return scroll

const MOVE_SLIDER_SPECS := [
	["base_movement_speed", "Base Speed", 40.0, 160.0, 5.0, "%.0f px/s"],
	["bastion_in_time", "Bastion In Time", 0.05, 1.50, 0.05, "%.2fs"],
	["bastion_out_time", "Bastion Out Time", 0.05, 1.50, 0.05, "%.2fs"],
	["cooldown_floor", "Cooldown Floor", 0.05, 0.50, 0.01, "%.2fs"],
	["sidestep_distance", "Sidestep Dist", 30.0, 180.0, 1.0, "%.0f px"],
	["sidestep_cooldown", "Sidestep CD", 0.2, 8.0, 0.1, "%.1fs"],
	["forward_dash_distance", "Dash Dist", 50.0, 250.0, 5.0, "%.0f px"],
	["forward_dash_cooldown", "Dash CD", 0.2, 8.0, 0.1, "%.1fs"],
	["rock_stance_burst_duration", "Rock Burst Dur", 0.2, 4.0, 0.05, "%.2fs"],
	["rock_stance_burst_cd_mult", "Rock Burst Mult", 0.30, 1.00, 0.05, "x%.2f"],
	["rock_stance_icd", "Rock Stance ICD", 0.5, 10.0, 0.5, "%.1fs"],
	["rock_stance_armor_bonus", "Rock Armor Bonus", 0.0, 12.0, 1.0, "+%.0f"],
]

func _build_tab_movement() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	vbox.add_child(_section_header("Movement Combat Mode (A/B Toggle)"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	vbox.add_child(mode_row)

	move_btn_coupled = Button.new()
	move_btn_coupled.text = "Movement-Coupled"
	move_btn_coupled.focus_mode = Control.FOCUS_NONE
	move_btn_coupled.pressed.connect(func():
		_call_ctrl("set_movement_coupled", [true])
		_refresh_movement_tab()
		_set_status("Mode: Movement-Coupled")
	)
	mode_row.add_child(move_btn_coupled)

	move_btn_vanilla = Button.new()
	move_btn_vanilla.text = "Vanilla Timers"
	move_btn_vanilla.focus_mode = Control.FOCUS_NONE
	move_btn_vanilla.pressed.connect(func():
		_call_ctrl("set_movement_coupled", [false])
		_refresh_movement_tab()
		_set_status("Mode: Vanilla Timers")
	)
	mode_row.add_child(move_btn_vanilla)

	var btn_reset := Button.new()
	btn_reset.text = "Reset Defaults"
	btn_reset.focus_mode = Control.FOCUS_NONE
	btn_reset.pressed.connect(func():
		_call_ctrl("reset_movement_config")
		_refresh_movement_tab()
		_set_status("Reset MOVEMENT_CONFIG to defaults")
	)
	mode_row.add_child(btn_reset)

	move_mode_badge_label = Label.new()
	move_mode_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_mode_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_row.add_child(move_mode_badge_label)

	vbox.add_child(_section_header("Live Movement Coefficients"))
	for spec in MOVE_SLIDER_SPECS:
		var key: String = spec[0]
		var title: String = spec[1]
		var min_v: float = spec[2]
		var max_v: float = spec[3]
		var step_v: float = spec[4]
		var fmt: String = spec[5]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = title
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = min_v
		slider.max_value = max_v
		slider.step = step_v
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		var k := key
		var f := fmt
		slider.value_changed.connect(func(val: float):
			var store_val: Variant = int(round(val)) if k == "rock_stance_armor_bonus" else val
			_call_ctrl("set_movement_config_value", [k, store_val])
			if move_value_labels.has(k):
				move_value_labels[k].text = f % val
			_set_status("%s = %s" % [k, f % val])
		)
		row.add_child(slider)
		move_sliders[key] = slider

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(56, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		move_value_labels[key] = val_lbl

	return scroll

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	return lbl

func open_modal() -> void:
	if visible:
		return
	if get_tree():
		_was_paused_before_open = get_tree().paused
		get_tree().paused = true
	visible = true
	refresh_active_tab()

func close_modal() -> void:
	if not visible:
		return
	visible = false
	var vp := get_viewport()
	if vp:
		var focused := vp.gui_get_focus_owner()
		if focused != null and (focused == self or is_ancestor_of(focused)):
			focused.release_focus()
	if get_tree():
		var frozen := bool(controller.get("is_frozen_by_debug")) if controller else false
		get_tree().paused = true if frozen else _was_paused_before_open

func toggle_modal() -> void:
	if visible:
		close_modal()
	else:
		open_modal()

func switch_tab(idx: int) -> void:
	active_tab = clampi(idx, 0, tab_containers.size() - 1)
	for i in range(tab_containers.size()):
		tab_containers[i].visible = (i == active_tab)
	for i in range(tab_buttons.size()):
		tab_buttons[i].modulate = Color(0.55, 1.0, 0.65) if i == active_tab else Color.WHITE
	refresh_active_tab()

func refresh_active_tab() -> void:
	match active_tab:
		0: _refresh_build_matrix()
		1:
			_rebuild_boss_buttons()
			_sync_sandbox_highlights()
		2: _refresh_char_world_tab()
		3: _refresh_presets_tab()
		4: _refresh_movement_tab()

func _refresh_movement_tab() -> void:
	var coupled := GlobalEvents.is_movement_coupled()
	if move_mode_badge_label:
		move_mode_badge_label.text = "Active: " + ("Movement-Coupled" if coupled else "Vanilla Timers")
	if move_btn_coupled:
		move_btn_coupled.modulate = Color(0.55, 1.0, 0.65) if coupled else Color.WHITE
	if move_btn_vanilla:
		move_btn_vanilla.modulate = Color(0.55, 1.0, 0.65) if not coupled else Color.WHITE
	for spec in MOVE_SLIDER_SPECS:
		var key: String = spec[0]
		var fmt: String = spec[5]
		var cur_val := float(GlobalEvents.MOVEMENT_CONFIG.get(key, spec[2]))
		if move_sliders.has(key):
			(move_sliders[key] as HSlider).set_value_no_signal(cur_val)
		if move_value_labels.has(key):
			(move_value_labels[key] as Label).text = fmt % cur_val

func _on_filter_changed(_new_text: String) -> void:
	if active_tab == 0:
		_refresh_build_matrix()

func _collect_item_groups() -> Dictionary:
	var groups := {
		"weapon": {},
		"upgrade": {},
		"bossitem": {},
	}
	for uid in UpgradeDb.UPGRADES.keys():
		var data: Dictionary = UpgradeDb.UPGRADES[uid]
		var t: String = str(data.get("type", ""))
		if t == "item" or t == "endless":
			continue
		if not groups.has(t):
			continue
		var uid_str: String = str(uid)
		var base: String = uid_str.rstrip("0123456789")
		var tier: int = int(uid_str.right(uid_str.length() - base.length())) if uid_str.length() > base.length() else 1
		if not groups[t].has(base):
			groups[t][base] = {
				"base": base,
				"display": tr(str(data.get("displayname", base))),
				"icon": str(data.get("icon", "")),
				"max_tier": tier,
				"has_endless": UpgradeDb.UPGRADES.has(base + "_endless"),
			}
		else:
			groups[t][base]["max_tier"] = maxi(int(groups[t][base]["max_tier"]), tier)
	return groups

func _refresh_build_matrix() -> void:
	if build_list_vbox == null:
		return
	for ch in build_list_vbox.get_children():
		ch.queue_free()

	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var query := filter_edit.text.strip_edges().to_lower() if filter_edit else ""

	var wpn_used := 0
	var upg_used := 0
	var groups := _collect_item_groups()

	if p and is_instance_valid(p):
		for base in groups["weapon"].keys():
			if p.has_method("_get_highest_owned_tier") and p._get_highest_owned_tier(base) > 0:
				wpn_used += 1
		for base in groups["upgrade"].keys():
			if p.has_method("_get_highest_owned_tier") and p._get_highest_owned_tier(base) > 0:
				upg_used += 1
		if slot_summary_label:
			var max_w := int(p.get("max_weapon_slots")) if p.get("max_weapon_slots") != null else 0
			var max_u := int(p.get("max_upgrade_slots")) if p.get("max_upgrade_slots") != null else 0
			var endless_cnt: int = p.collected_endless.size() if p.get("collected_endless") is Dictionary else 0
			slot_summary_label.text = "Wpn: %d/%d | Upg: %d/%d | Endless: %d" % [
				wpn_used, max_w, upg_used, max_u, endless_cnt
			]

	var cat_order := [
		["weapon", "Weapons"],
		["upgrade", "Passive Upgrades"],
		["bossitem", "Boss Items"],
	]
	for cat_pair in cat_order:
		var cat_key: String = cat_pair[0]
		var cat_title: String = cat_pair[1]
		var entries: Array = groups[cat_key].values()
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a["display"]).nocasecmp_to(str(b["display"])) < 0
		)
		var filtered: Array = []
		for e in entries:
			if query == "" or str(e["display"]).to_lower().contains(query) or str(e["base"]).to_lower().contains(query):
				filtered.append(e)
		if filtered.is_empty():
			continue

		build_list_vbox.add_child(_section_header("%s (%d)" % [cat_title, filtered.size()]))
		for entry in filtered:
			build_list_vbox.add_child(_make_item_row(entry, p))

func _make_item_row(entry: Dictionary, player_node: Node) -> Control:
	var base: String = entry["base"]
	var max_tier: int = int(entry["max_tier"])
	var has_endless: bool = bool(entry["has_endless"])

	var cur_tier := 0
	var endless_cnt := 0
	if player_node and is_instance_valid(player_node):
		if player_node.has_method("_get_highest_owned_tier"):
			cur_tier = int(player_node._get_highest_owned_tier(base))
		if player_node.get("collected_endless") is Dictionary:
			endless_cnt = int(player_node.collected_endless.get(base, 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(12, 12)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if entry["icon"] != "" and ResourceLoader.exists(entry["icon"]):
		icon_rect.texture = load(entry["icon"])
	row.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = str(entry["display"])
	name_lbl.custom_minimum_size = Vector2(115, 0)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var btn_off := Button.new()
	btn_off.text = "Off"
	btn_off.custom_minimum_size = Vector2(22, 14)
	btn_off.modulate = Color(1.0, 0.55, 0.55) if cur_tier == 0 else Color(0.75, 0.75, 0.75)
	btn_off.pressed.connect(func():
		_call_ctrl("set_item_tier", [base, 0])
		_refresh_build_matrix()
	)
	row.add_child(btn_off)

	for t in range(1, max_tier + 1):
		var btn_t := Button.new()
		btn_t.text = str(t)
		btn_t.custom_minimum_size = Vector2(16, 14)
		var is_cur := (cur_tier == t)
		var is_owned := (cur_tier >= t)
		if is_cur:
			btn_t.modulate = Color(0.45, 1.0, 0.55)
		elif is_owned:
			btn_t.modulate = Color(0.75, 0.92, 0.78)
		var tier_val: int = t
		btn_t.pressed.connect(func():
			_call_ctrl("set_item_tier", [base, tier_val])
			_refresh_build_matrix()
		)
		row.add_child(btn_t)

	if has_endless:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var e_lbl := Label.new()
		e_lbl.text = "E:%d" % endless_cnt
		e_lbl.custom_minimum_size = Vector2(28, 0)
		e_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0) if endless_cnt > 0 else Color(0.6, 0.6, 0.65))
		row.add_child(e_lbl)

		for delta_pair in [[-1, "-1"], [1, "+1"], [5, "+5"]]:
			var eb := Button.new()
			eb.text = delta_pair[1]
			eb.custom_minimum_size = Vector2(20, 14)
			var dv: int = delta_pair[0]
			eb.pressed.connect(func():
				_call_ctrl("adjust_endless_stacks", [base, dv])
				_refresh_build_matrix()
			)
			row.add_child(eb)

	return row

func _rebuild_boss_buttons() -> void:
	if boss_buttons_box == null:
		return
	for ch in boss_buttons_box.get_children():
		ch.queue_free()

	var boss_paths: Array[String] = []
	var spawner: Node = get_tree().get_first_node_in_group("spawner") if is_inside_tree() else null
	if spawner and spawner.get("spawns_super") is Array:
		for info in spawner.spawns_super:
			if info != null and info.get("enemy") != null and info.enemy.resource_path != "":
				if not boss_paths.has(info.enemy.resource_path):
					boss_paths.append(info.enemy.resource_path)
	if boss_paths.is_empty():
		boss_paths = ["res://Enemy/Boss/enemy_super.tscn", "res://Enemy/Boss/dr_franklin.tscn"]

	for bp in boss_paths:
		var key: String = GlobalEvents.boss_names.get(bp, "")
		var label_txt: String = tr(key) if key != "" else bp.get_file().get_basename()
		var btn := Button.new()
		btn.text = "Spawn " + label_txt
		var path_copy := bp
		btn.pressed.connect(func():
			_call_ctrl("spawn_boss_now", [path_copy])
			_set_status("Queued boss: " + label_txt)
		)
		boss_buttons_box.add_child(btn)

func _sync_sandbox_highlights() -> void:
	for k in pool_buttons.keys():
		pool_buttons[k].modulate = Color(0.55, 1.0, 0.65) if k == selected_pool else Color.WHITE
	for k in formation_buttons.keys():
		formation_buttons[k].modulate = Color(0.55, 1.0, 0.65) if k == selected_formation else Color.WHITE

func _rebuild_character_buttons() -> void:
	if char_buttons_box == null:
		return
	for ch in char_buttons_box.get_children():
		ch.queue_free()
	for char_id in GlobalEvents.CHARACTERS.keys():
		var cdata: Dictionary = GlobalEvents.CHARACTERS[char_id]
		var btn := Button.new()
		var disp: String = tr(str(cdata.get("displayname", char_id)))
		var is_cur: bool = (GlobalEvents.selected_character == str(char_id))
		btn.text = ("* " + disp) if is_cur else disp
		btn.modulate = Color(0.55, 1.0, 0.65) if is_cur else Color.WHITE
		var cid: String = str(char_id)
		btn.pressed.connect(func():
			var gs: bool = grant_starter_check.button_pressed if grant_starter_check else true
			_call_ctrl("switch_character", [cid, gs])
			_refresh_char_world_tab()
			_set_status("Switched character to " + cid)
		)
		char_buttons_box.add_child(btn)

func _refresh_char_world_tab() -> void:
	_rebuild_character_buttons()
	if diff_badge_label:
		diff_badge_label.text = "Active: " + tr(GlobalEvents.get_difficulty_name())
	if allow_tainted_check:
		allow_tainted_check.set_pressed_no_signal(StatsManager.allow_tainted_stats)
	if custom_diff_vbox == null:
		return
	for ch in custom_diff_vbox.get_children():
		ch.queue_free()

	var specs := [
		["custom_enemy_spawn_modifier", "Enemy Spawn Rate", 0.1, 5.0, 0.2],
		["custom_enemy_hp_modifier", "Enemy HP Scale", 0.1, 5.0, 0.2],
		["custom_boss_hp_modifier", "Boss HP Scale", 0.1, 5.0, 0.2],
		["custom_player_regen_modifier", "Player Regen", 0.0, 5.0, 0.2],
		["custom_player_damage_modifier", "Player Damage", 0.1, 5.0, 0.2],
		["custom_xp_gain_modifier", "XP Gain Rate", 0.1, 5.0, 0.2],
	]
	for s in specs:
		var prop: String = s[0]
		var title: String = s[1]
		var min_v: float = s[2]
		var max_v: float = s[3]
		var step_v: float = s[4]
		var cur_v: float = float(GlobalEvents.get(prop))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		custom_diff_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = title
		lbl.custom_minimum_size = Vector2(110, 0)
		row.add_child(lbl)

		for d in [-step_v, step_v]:
			var b := Button.new()
			b.text = ("%.1f" % d) if d < 0.0 else ("+%.1f" % d)
			b.custom_minimum_size = Vector2(28, 14)
			var delta_v: float = d
			b.pressed.connect(func():
				var next_v := clampf(float(GlobalEvents.get(prop)) + delta_v, min_v, max_v)
				GlobalEvents.set(prop, next_v)
				GlobalEvents.current_difficulty = GlobalEvents.Difficulty.CUSTOM
				StatsManager.mark_run_tainted()
				_refresh_char_world_tab()
			)
			row.add_child(b)

		var val_lbl := Label.new()
		val_lbl.text = "x%.2f" % cur_v
		row.add_child(val_lbl)

func _refresh_presets_tab() -> void:
	if custom_slots_vbox == null:
		return
	for ch in custom_slots_vbox.get_children():
		ch.queue_free()

	var cfg := ConfigFile.new()
	cfg.load("user://debug_presets.cfg")

	for slot in [1, 2, 3]:
		var sec := "slot_%d" % slot
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		custom_slots_vbox.add_child(row)

		var has_slot := cfg.has_section(sec)
		var summary_txt := "(empty)"
		if has_slot:
			var s_char := str(cfg.get_value(sec, "character", "mage"))
			var s_time := int(cfg.get_value(sec, "time", 0))
			var s_lvl := int(cfg.get_value(sec, "level", 1))
			var s_items: Array = cfg.get_value(sec, "collected_upgrades", [])
			summary_txt = "%s | t=%ds Lv%d | %d upg" % [s_char, s_time, s_lvl, s_items.size()]

		var lbl := Label.new()
		lbl.text = "Slot %d: %s" % [slot, summary_txt]
		lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(lbl)

		var b_save := Button.new()
		b_save.text = "Save"
		var sl: int = slot
		b_save.pressed.connect(func():
			_call_ctrl("save_custom_preset", [sl])
			_refresh_presets_tab()
			_set_status("Saved custom preset slot %d" % sl)
		)
		row.add_child(b_save)

		var b_load := Button.new()
		b_load.text = "Load"
		b_load.disabled = not has_slot
		b_load.pressed.connect(func():
			_call_ctrl("load_custom_preset", [sl])
			refresh_active_tab()
			_set_status("Loaded custom preset slot %d" % sl)
		)
		row.add_child(b_load)

func _on_max_all_equipped_pressed() -> void:
	_call_ctrl("max_all_equipped")
	_refresh_build_matrix()
	_set_status("Maxed all equipped items")

func _on_reset_all_items_pressed() -> void:
	_call_ctrl("reset_all_upgrades")
	_refresh_build_matrix()
	_set_status("Reset all equipped items")

func _on_reset_dps_pressed() -> void:
	_call_ctrl("reset_dps_meter")
	_set_status("Reset DPS meter")

func _on_export_csv_pressed() -> void:
	if controller and controller.get("telemetry") != null:
		controller.telemetry.export_csv()
		_set_status("Exported user://debug_dps_export.csv")

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _call_ctrl(method_name: String, args: Array = []) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	if controller.has_method(method_name):
		controller.callv(method_name, args)

class_name TestRoomBossSwarm
extends TestRoomBase

const GuiClass = preload("res://Tools/TestRooms/test_room_gui.gd")

var player: CharacterBody2D = null
var mock_gui: Control = null
var swarm_manager: Node2D = null
var swarm_type_id: int = -1

# Boss instance & tracking
var active_boss: EnemyBody = null
var boss_status_lbl: Label = null
var hold_after_telegraph: bool = false
var _prev_boss_state: int = 0

# Godmode
var is_godmode: bool = true

# Benchmark state
var is_benchmarking: bool = false
var benchmark_tiers: Array[int] = [500, 1500, 3000, 5000]
var bench_tier_idx: int = 0
var bench_tier_timer: float = 0.0
const BENCH_TIER_DURATION: float = 5.0
var frame_times: Array[float] = []
var benchmark_results: Array[Dictionary] = []
var bench_status_lbl: Label = null

func _get_room_title() -> String:
	return "BOSS CHOREOGRAPHY & SWARM STRESS LAB"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "1", "desc": "Spawn Ancient Amoeba (Giant Amoeba Boss)"},
		{"key": "2", "desc": "Spawn Dr. Franklin (Directional Beam Boss)"},
		{"key": "Z / X / C / V", "desc": "Force Boss State (Chase / Dissolve or Telegraph / Attack / Recover)"},
		{"key": "N", "desc": "Toggle 'Hold After Telegraph' Breakpoint (Auto-Pauses)"},
		{"key": "G", "desc": "Toggle Godmode (Invulnerability)"},
		{"key": "B", "desc": "Start / Abort Automated Swarm Benchmark (500..5000 -> CSV)"},
		{"key": "+ / -", "desc": "Spawn / Despawn 500 Swarm Kobolds on Perimeter"},
		{"key": "M", "desc": "Clear Swarm Horde"}
	]

func _setup_room() -> void:
	ring_centers = [Vector2.ZERO]
	ring_radii = [100.0, 200.0, 300.0, 450.0]
	queue_grid_redraw()

	_setup_mock_gui()
	_setup_player()
	_setup_swarm()
	_setup_extra_topbar_buttons()

	# Spawn default Ancient Amoeba
	spawn_boss("amoeba")

func _setup_mock_gui() -> void:
	mock_gui = GuiClass.new()
	ui_layer.add_child(mock_gui)

func _setup_player() -> void:
	var p_scene := preload("res://Player/player.tscn")
	player = p_scene.instantiate()
	player.position = Vector2(0, 100)
	add_child(player)

	if player.get("gui") == null:
		player.set("gui", mock_gui)

	var p_cam := player.get_node_or_null("Camera2D") as Camera2D
	if p_cam:
		if camera:
			camera.enabled = false
		p_cam.enabled = true
		p_cam.make_current()

func _setup_swarm() -> void:
	var sm_scene := preload("res://Utility/swarm_manager.tscn")
	swarm_manager = sm_scene.instantiate()
	add_child(swarm_manager)

	var tex: Texture2D = load("res://Textures/Enemy/kolbold_weak.png")
	if tex:
		swarm_type_id = swarm_manager.register_enemy_type(tex, 16.0, 2, 1)

func _setup_extra_topbar_buttons() -> void:
	var btn_amoeba := Button.new()
	btn_amoeba.text = "1 Amoeba"
	btn_amoeba.pressed.connect(func(): spawn_boss("amoeba"))
	extra_buttons_bar.add_child(btn_amoeba)

	var btn_franklin := Button.new()
	btn_franklin.text = "2 Franklin"
	btn_franklin.pressed.connect(func(): spawn_boss("franklin"))
	extra_buttons_bar.add_child(btn_franklin)

	var btn_hold := Button.new()
	btn_hold.text = "Hold: OFF"
	btn_hold.pressed.connect(func(): _toggle_hold_after_telegraph(btn_hold))
	extra_buttons_bar.add_child(btn_hold)

	var btn_god := Button.new()
	btn_god.text = "Godmode: ON"
	btn_god.pressed.connect(func(): _toggle_godmode(btn_god))
	extra_buttons_bar.add_child(btn_god)

	var btn_bench := Button.new()
	btn_bench.text = "Benchmark (B)"
	btn_bench.pressed.connect(toggle_benchmark)
	extra_buttons_bar.add_child(btn_bench)

	bench_status_lbl = Label.new()
	bench_status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	extra_buttons_bar.add_child(bench_status_lbl)

func spawn_boss(type: String) -> void:
	if active_boss and is_instance_valid(active_boss):
		active_boss.queue_free()
		active_boss = null

	for ch in get_children():
		if ch.name.begins_with("franklin_telegraph") or ch.name.begins_with("Telegraph"):
			ch.queue_free()

	var scn_path := ""
	if type == "amoeba":
		scn_path = "res://Enemy/Boss/enemy_super.tscn"
	else:
		scn_path = "res://Enemy/Boss/dr_franklin.tscn"

	var scn: PackedScene = load(scn_path)
	if not scn:
		return

	active_boss = scn.instantiate()
	active_boss.position = Vector2(0, -60)
	add_child(active_boss)

	GlobalEvents.boss_spawned.emit(active_boss)

	if boss_status_lbl and is_instance_valid(boss_status_lbl):
		boss_status_lbl.queue_free()

	boss_status_lbl = Label.new()
	boss_status_lbl.name = "BossStateReadout"
	boss_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	active_boss.add_child(boss_status_lbl)
	boss_status_lbl.position = Vector2(-70, -50)

func _force_boss_state(state_idx: int) -> void:
	if not active_boss or not is_instance_valid(active_boss):
		return
	if active_boss.has_method("_start_attack"):
		# Dr. Franklin: 0: CHASE, 1: TELEGRAPHING, 2: RECOVERING
		match state_idx:
			0:
				if active_boss.has_method("_end_ability"):
					active_boss._end_ability()
				else:
					active_boss.set("state", 0)
			1:
				active_boss._start_attack()
			2, 3:
				if active_boss.has_method("_end_telegraph"):
					active_boss._end_telegraph()
				else:
					active_boss.set("state", 2)
	else:
		# Ancient Amoeba: 0: CHASE, 1: DISSOLVING, 2: TELEGRAPHING, 3: REAPPEARING
		match state_idx:
			0:
				if active_boss.has_method("end_ability"):
					active_boss.end_ability()
				else:
					active_boss.set("state", 0)
			1:
				if active_boss.has_method("start_dissolve"):
					active_boss.start_dissolve()
				else:
					active_boss.set("state", 1)
			2:
				if active_boss.has_method("start_telegraph"):
					active_boss.start_telegraph()
				else:
					active_boss.set("state", 2)
			3:
				if active_boss.has_method("start_reappear"):
					active_boss.start_reappear()
				else:
					active_boss.set("state", 3)

func _toggle_hold_after_telegraph(btn: Button = null) -> void:
	hold_after_telegraph = not hold_after_telegraph
	if btn:
		btn.text = "Hold: %s" % ("ON" if hold_after_telegraph else "OFF")
		btn.modulate = Color(1.0, 0.6, 0.6) if hold_after_telegraph else Color.WHITE

func _toggle_godmode(btn: Button = null) -> void:
	is_godmode = not is_godmode
	if btn:
		btn.text = "Godmode: %s" % ("ON" if is_godmode else "OFF")
		btn.modulate = Color(0.5, 1.0, 0.5) if is_godmode else Color.WHITE

func toggle_benchmark() -> void:
	if is_benchmarking:
		_abort_benchmark()
	else:
		_start_benchmark()

func _start_benchmark() -> void:
	is_benchmarking = true
	bench_tier_idx = 0
	bench_tier_timer = 0.0
	frame_times.clear()
	benchmark_results.clear()
	if swarm_manager:
		swarm_manager.clear_all()
	_apply_benchmark_tier()

func _apply_benchmark_tier() -> void:
	if not swarm_manager: return
	var target_n := benchmark_tiers[bench_tier_idx]
	var current_n: int = swarm_manager.swarm_data.size()
	var needed := target_n - current_n
	if needed > 0:
		for i in range(needed):
			var angle := randf() * TAU
			var dist := randf_range(150.0, 400.0)
			var pos := Vector2(cos(angle), sin(angle)) * dist
			swarm_manager.add_enemy(pos, 20.0, 20.0, 30.0, 1, 5, swarm_type_id)

func _abort_benchmark() -> void:
	is_benchmarking = false
	if bench_status_lbl:
		bench_status_lbl.text = "Benchmark Aborted"
	if swarm_manager:
		swarm_manager.clear_all()

func _finish_benchmark() -> void:
	is_benchmarking = false
	if bench_status_lbl:
		bench_status_lbl.text = "Bench Done -> user://swarm_benchmark.csv"

	# Export to CSV
	var file := FileAccess.open("user://swarm_benchmark.csv", FileAccess.WRITE)
	if file:
		file.store_line("Tier_N,Avg_FPS,Min_FPS,Avg_Frame_ms,P99_Frame_ms")
		for r in benchmark_results:
			file.store_line("%d,%.2f,%.2f,%.3f,%.3f" % [
				r["n"], r["avg_fps"], r["min_fps"], r["avg_ms"], r["p99_ms"]
			])
		file.close()

func _process(delta: float) -> void:
	# Godmode upkeep
	if is_godmode and player and is_instance_valid(player):
		player._set_hp(player.maxhp)

	# Boss state readout & hold-after-telegraph inspection
	if active_boss and is_instance_valid(active_boss):
		var cur_state: int = active_boss.get("state")
		var s_name := "STATE_%d" % cur_state
		var hit_active := true
		if "hitBox_shape" in active_boss and active_boss.hitBox_shape:
			hit_active = not active_boss.hitBox_shape.disabled

		if boss_status_lbl:
			boss_status_lbl.text = "State: %d | HitBox: %s\nTimer: %.1fs" % [
				cur_state,
				"ACTIVE" if hit_active else "MUTED",
				active_boss.get("state_timer")
			]

		# Breakpoint trigger: if telegraph just ended
		if hold_after_telegraph:
			# If transitioning from telegraph (state 2 on Amoeba, state 1 on Franklin)
			if _prev_boss_state != cur_state and (_prev_boss_state == 2 or _prev_boss_state == 1):
				get_tree().paused = true
		_prev_boss_state = cur_state

	# Benchmark logic
	if is_benchmarking:
		frame_times.append(delta)
		bench_tier_timer += delta

		var cur_tier_n := benchmark_tiers[bench_tier_idx]
		if bench_status_lbl:
			bench_status_lbl.text = "Bench N=%d (%.1fs/%.1fs)" % [
				cur_tier_n, bench_tier_timer, BENCH_TIER_DURATION
			]

		if bench_tier_timer >= BENCH_TIER_DURATION:
			# Compute stats
			var sum_time := 0.0
			var min_fps := 9999.0
			frame_times.sort()
			for ft in frame_times:
				sum_time += ft
				var cur_fps := 1.0 / ft if ft > 0.0 else 0.0
				if cur_fps < min_fps: min_fps = cur_fps
			var count := frame_times.size()
			var avg_ms := (sum_time / float(count)) * 1000.0 if count > 0 else 0.0
			var avg_fps := float(count) / sum_time if sum_time > 0.0 else 0.0
			var p99_idx := int(count * 0.99)
			var p99_ms := frame_times[p99_idx] * 1000.0 if count > 0 else 0.0

			benchmark_results.append({
				"n": cur_tier_n,
				"avg_fps": avg_fps,
				"min_fps": min_fps,
				"avg_ms": avg_ms,
				"p99_ms": p99_ms
			})

			bench_tier_idx += 1
			bench_tier_timer = 0.0
			frame_times.clear()

			if bench_tier_idx >= benchmark_tiers.size():
				_finish_benchmark()
			else:
				_apply_benchmark_tier()

func _handle_room_key(event: InputEventKey) -> bool:
	match DebugController.get_effective_keycode(event):
		KEY_1:
			spawn_boss("amoeba")
			return true
		KEY_2:
			spawn_boss("franklin")
			return true
		KEY_Z:
			_force_boss_state(0) # Chase
			return true
		KEY_X:
			_force_boss_state(1) # Dissolve / Telegraph
			return true
		KEY_C:
			_force_boss_state(2) # Telegraph / Recover
			return true
		KEY_V:
			_force_boss_state(3) # Reappear
			return true
		KEY_N:
			_toggle_hold_after_telegraph()
			return true
		KEY_G:
			_toggle_godmode()
			return true
		KEY_B:
			toggle_benchmark()
			return true
		KEY_EQUAL, KEY_PLUS:
			if swarm_manager:
				for i in range(500):
					var angle := randf() * TAU
					var dist := randf_range(160.0, 360.0)
					swarm_manager.add_enemy(Vector2(cos(angle), sin(angle)) * dist, 20.0, 20.0, 30.0, 1, 5, swarm_type_id)
			return true
		KEY_MINUS:
			if swarm_manager and swarm_manager.swarm_data.size() > 0:
				var to_remove: int = mini(500, swarm_manager.swarm_data.size())
				for i in range(to_remove):
					swarm_manager.swarm_data.pop_back()
				if swarm_manager.get("spatial_grid") is Dictionary:
					swarm_manager.spatial_grid.clear()
				if swarm_manager.has_method("_update_multimeshes"):
					swarm_manager._update_multimeshes()
			return true
		KEY_M:
			if swarm_manager:
				swarm_manager.clear_all()
			return true

	return false

func _reset_room_state() -> void:
	if is_benchmarking:
		_abort_benchmark()
	if swarm_manager:
		swarm_manager.clear_all()
	for ch in get_children():
		if ch.name.begins_with("franklin_telegraph") or ch.name.begins_with("Telegraph"):
			ch.queue_free()
	if active_boss:
		active_boss.queue_free()
		active_boss = null
	spawn_boss("amoeba")
	if player:
		player.position = Vector2(0, 100)
		player._set_hp(player.maxhp)

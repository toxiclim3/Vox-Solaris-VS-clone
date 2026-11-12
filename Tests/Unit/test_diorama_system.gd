# SPDX-License-Identifier: GPL-3.0-or-later
## test_diorama_system.gd
## Unit test suite for Diorama Studio and Diorama Player (Approach B: Sprite State Recorder/Replayer).
extends "res://Tests/test_base.gd"

const STUDIO_SCENE: String = "res://TitleScreen/HowToPlay/diorama_studio.tscn"
const PLAYER_SCENE: String = "res://TitleScreen/HowToPlay/diorama_player.tscn"
const TEST_CLIP_PATH: String = "res://TitleScreen/HowToPlay/recordings/test_suite_clip.json"

var studio_packed: PackedScene
var player_packed: PackedScene

func before_all() -> void:
	studio_packed = load(STUDIO_SCENE)
	player_packed = load(PLAYER_SCENE)
	_create_test_fixture()

func _create_test_fixture() -> void:
	var dir = "res://TitleScreen/HowToPlay/recordings"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var dummy_data = {
		"version": 1,
		"fps": 20.0,
		"duration": 0.1,
		"frame_count": 2,
		"stage_size": [640, 360],
		"frames": [
			[
				{
					"texture": "res://Textures/Player/player_sprite.png",
					"pos": [320.0, 180.0],
					"frame": 0,
					"hframes": 2,
					"vframes": 1,
					"flip_h": false,
					"flip_v": false,
					"rotation": 0.0,
					"scale": [1.0, 1.0],
					"modulate": [1.0, 1.0, 1.0, 1.0],
					"z_index": 0
				}
			],
			[
				{
					"texture": "res://Textures/Player/player_sprite.png",
					"pos": [325.0, 180.0],
					"frame": 1,
					"hframes": 2,
					"vframes": 1,
					"flip_h": false,
					"flip_v": false,
					"rotation": 0.0,
					"scale": [1.0, 1.0],
					"modulate": [1.0, 1.0, 1.0, 1.0],
					"z_index": 0
				}
			]
		]
	}
	var f = FileAccess.open(TEST_CLIP_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dummy_data))
		f.close()

func after_all() -> void:
	if FileAccess.file_exists(TEST_CLIP_PATH):
		DirAccess.remove_absolute(TEST_CLIP_PATH)

func _instantiate_studio() -> Node:
	var studio = studio_packed.instantiate()
	Engine.get_main_loop().root.add_child(studio)
	return studio

func _free_studio(studio: Node) -> void:
	if studio != null:
		if studio.is_inside_tree():
			Engine.get_main_loop().root.remove_child(studio)
		studio.free()

func _instantiate_player() -> Node:
	var player = player_packed.instantiate()
	Engine.get_main_loop().root.add_child(player)
	return player

func _free_player(player: Node) -> void:
	if player != null:
		if player.is_inside_tree():
			Engine.get_main_loop().root.remove_child(player)
		player.free()

func test_scenes_load_successfully() -> void:
	assert_true(studio_packed != null, "diorama_studio.tscn must be loadable")
	assert_true(player_packed != null, "diorama_player.tscn must be loadable")

func test_diorama_player_interface() -> void:
	var player = _instantiate_player()
	assert_true(player != null, "DioramaPlayer instance must not be null")
	assert_true(player.has_method("start_loop"), "DioramaPlayer must implement start_loop()")
	assert_true(player.has_method("stop_loop"), "DioramaPlayer must implement stop_loop()")
	assert_true(player.has_method("load_recording"), "DioramaPlayer must implement load_recording()")
	assert_true(player.has_method("load_recording_data"), "DioramaPlayer must implement load_recording_data()")
	assert_true(player.has_method("seek_frame"), "DioramaPlayer must implement seek_frame()")
	_free_player(player)

func test_diorama_studio_structure() -> void:
	var studio = _instantiate_studio()
	assert_true(studio != null, "DioramaStudio instance must not be null")

	var stage = studio.get_node_or_null("%Stage")
	assert_true(stage != null, "Studio must contain %Stage")

	var actors = studio.get_node_or_null("%Actors")
	assert_true(actors != null, "Studio must contain %Actors")

	var player_dummy = studio.get_node_or_null("%PlayerDummy")
	assert_true(player_dummy != null, "Studio must contain %PlayerDummy")

	var enemies = studio.get_node_or_null("%Enemies")
	assert_true(enemies != null, "Studio must contain %Enemies")

	var drops = studio.get_node_or_null("%Drops")
	assert_true(drops != null, "Studio must contain %Drops")

	var projectiles = studio.get_node_or_null("%Projectiles")
	assert_true(projectiles != null, "Studio must contain %Projectiles")

	_free_studio(studio)

func test_dummy_enemy_spawning() -> void:
	var studio = _instantiate_studio()
	var enemy_types = ["kobold_weak", "kobold_strong", "cyclops", "juggernaut"]

	for etype in enemy_types:
		var enemy = studio.spawn_enemy(etype, Vector2(100, 100))
		assert_true(enemy != null, "spawn_enemy('%s') must return a node" % etype)
		assert_eq(enemy.get_meta("enemy_type", ""), etype, "Enemy type metadata must match")
		assert_gt(int(enemy.get_meta("hp", 0)), 0, "Enemy hp must be positive")
		assert_gt(float(enemy.get_meta("speed", 0.0)), 0.0, "Enemy speed must be positive")
		var body = enemy.get_node_or_null("Body") as Sprite2D
		assert_true(body != null, "Enemy must have a Body Sprite2D")
		assert_true(body.texture != null, "Enemy body must have a valid texture")

	_free_studio(studio)

func test_enemy_damage_and_death_drop() -> void:
	var studio = _instantiate_studio()
	var enemy = studio.spawn_enemy("kobold_weak", Vector2(200, 150))
	var initial_drops = studio.get_node("%Drops").get_child_count()

	studio.hurt_enemy(enemy, 1)
	assert_eq(int(enemy.get_meta("hp", 0)), 1, "Enemy hp should decrease by 1")

	studio.kill_enemy(enemy)
	assert_true(enemy.get_meta("is_dead", false), "Enemy should be marked dead")

	# Verify XP gem dropped into %Drops
	var new_drops = studio.get_node("%Drops").get_child_count()
	assert_eq(new_drops, initial_drops + 1, "Killing an enemy must spawn an XP drop")

	_free_studio(studio)

func test_attack_spawning() -> void:
	var studio = _instantiate_studio()
	var projectiles_container = studio.get_node("%Projectiles")

	studio.trigger_attack("ice_spear", Vector2(400, 180))
	assert_gt(projectiles_container.get_child_count(), 0, "Ice spear should add projectile")

	studio.trigger_attack("javelin", Vector2(400, 180))
	assert_gt(projectiles_container.get_child_count(), 1, "Javelin should add projectile")

	studio.trigger_attack("lightning", Vector2(400, 180))
	assert_gt(projectiles_container.get_child_count(), 2, "Lightning should add projectile")

	_free_studio(studio)

func test_drops_spawning() -> void:
	var studio = _instantiate_studio()
	var drops_container = studio.get_node("%Drops")

	var gem = studio.spawn_drop("gem_green", Vector2(150, 150))
	assert_true(gem != null, "spawn_drop must return drop node")
	assert_eq(gem.get_meta("drop_type", ""), "gem_green", "Drop type must be gem_green")

	var magnet = studio.spawn_drop("magnet", Vector2(250, 250))
	assert_true(magnet != null, "spawn_drop must return magnet node")
	assert_eq(magnet.get_meta("drop_type", ""), "magnet", "Drop type must be magnet")

	assert_eq(drops_container.get_child_count(), 2, "Drops container should have 2 children")

	_free_studio(studio)

func test_recorder_snapshot_and_serialization() -> void:
	var studio = _instantiate_studio()
	studio.spawn_enemy("kobold_weak", Vector2(200, 150))
	studio.spawn_drop("gem_green", Vector2(300, 150))

	# Start recording
	studio.start_recording()
	assert_true(studio._is_recording, "Studio should be recording")

	# Capture a few frames manually
	studio._capture_frame()
	studio._capture_frame()

	assert_gt(studio._recorded_frames.size(), 1, "Frames should be captured")

	# Validate frame structure and required sprite track attributes
	var frame0 = studio._recorded_frames[0]
	assert_true(frame0 is Array, "Frame must be an Array")
	assert_gt(frame0.size(), 0, "Frame must contain active sprites")

	var required_sprite_keys = [
		"texture", "pos", "frame", "hframes", "flip_h",
		"rotation", "modulate", "scale", "z_index"
	]

	for spr in frame0:
		for k in required_sprite_keys:
			assert_has(spr, k, "Recorded sprite missing required field '%s'" % k)
		assert_true(spr["texture"] is String and not spr["texture"].is_empty(), "Texture must be non-empty String")
		assert_true(spr["pos"] is Array and spr["pos"].size() == 2, "Pos must be [x, y]")
		assert_true(spr["scale"] is Array and spr["scale"].size() == 2, "Scale must be [sx, sy]")
		assert_true(spr["modulate"] is Array and spr["modulate"].size() == 4, "Modulate must be [r, g, b, a]")

	# Save test clip
	studio._clip_name_edit.text = "test_suite_clip"
	studio.stop_recording()
	assert_true(not studio._is_recording, "Studio should have stopped recording")
	assert_true(FileAccess.file_exists(TEST_CLIP_PATH), "Recorded test clip file should exist on disk")

	_free_studio(studio)

func test_diorama_player_playback_and_pooling() -> void:
	assert_true(FileAccess.file_exists(TEST_CLIP_PATH), "Test clip must exist for playback test")

	var player = _instantiate_player()
	var loaded = player.load_recording(TEST_CLIP_PATH)
	assert_true(loaded, "DioramaPlayer must successfully load recorded clip")
	assert_gt(player.get_frame_count(), 0, "Player must have frames loaded")

	# Verify start_loop updates sprite pool
	player.start_loop()
	assert_true(player.is_playing(), "Player should be playing after start_loop")

	var pool_container = player.get_node("SpritePool")
	assert_true(pool_container != null, "SpritePool container must exist")
	assert_gt(pool_container.get_child_count(), 0, "Sprite pool must have instanced dummy Sprite2Ds")

	# Verify properties on pooled sprite
	var first_spr = pool_container.get_child(0) as Sprite2D
	assert_true(first_spr.visible, "Active pooled sprite should be visible")
	assert_true(first_spr.texture != null, "Pooled sprite should have texture applied")

	# Verify stop_loop hides all pooled sprites
	player.stop_loop()
	assert_true(not player.is_playing(), "Player should not be playing after stop_loop")
	for spr in pool_container.get_children():
		assert_true(not spr.visible, "All pooled sprites must be hidden when stopped")

	_free_player(player)

func test_diorama_player_in_memory_loading() -> void:
	var dummy_data = {
		"version": 1,
		"fps": 20.0,
		"duration": 0.1,
		"frame_count": 2,
		"frames": [
			[
				{
					"texture": "res://Textures/Player/player_sprite.png",
					"pos": [320.0, 180.0],
					"frame": 0,
					"hframes": 2,
					"vframes": 1,
					"flip_h": false,
					"flip_v": false,
					"rotation": 0.0,
					"scale": [1.0, 1.0],
					"modulate": [1.0, 1.0, 1.0, 1.0],
					"z_index": 0
				}
			],
			[
				{
					"texture": "res://Textures/Player/player_sprite.png",
					"pos": [330.0, 180.0],
					"frame": 1,
					"hframes": 2,
					"vframes": 1,
					"flip_h": true,
					"flip_v": false,
					"rotation": 0.5,
					"scale": [1.1, 1.1],
					"modulate": [1.0, 0.5, 0.5, 1.0],
					"z_index": 1
				}
			]
		]
	}

	var player = _instantiate_player()
	var ok = player.load_recording_data(dummy_data)
	assert_true(ok, "In-memory loading must succeed")
	assert_eq(player.get_frame_count(), 2, "Must report 2 frames")

	player.seek_frame(0)
	var pool = player.get_node("SpritePool")
	var spr0 = pool.get_child(0) as Sprite2D
	assert_eq(spr0.position, Vector2(320.0, 180.0), "Frame 0 position must match")
	assert_eq(spr0.frame, 0, "Frame 0 frame must match")
	assert_eq(spr0.flip_h, false, "Frame 0 flip_h must match")

	player.seek_frame(1)
	assert_eq(spr0.position, Vector2(330.0, 180.0), "Frame 1 position must match")
	assert_eq(spr0.frame, 1, "Frame 1 frame must match")
	assert_eq(spr0.flip_h, true, "Frame 1 flip_h must match")

	_free_player(player)

func test_sample_combat_recording_loads_and_replays() -> void:
	var sample_path = "res://TitleScreen/HowToPlay/recordings/sample_combat.json"
	assert_true(FileAccess.file_exists(sample_path), "sample_combat.json must exist")

	var player = _instantiate_player()
	var ok = player.load_recording(sample_path)
	assert_true(ok, "DioramaPlayer must successfully load sample_combat.json")
	assert_eq(player.get_frame_count(), 70, "sample_combat.json should have 70 frames")

	player.start_loop()
	assert_true(player.is_playing(), "Player must be playing after start_loop()")
	player._process(0.1) # Advance 2 frames
	assert_gt(player.get_current_frame(), 0, "Playback should advance frames")

	player.stop_loop()
	assert_false(player.is_playing(), "Player must stop after stop_loop()")
	_free_player(player)

func test_diorama_player_seek_during_loop_pause() -> void:
	var player = _instantiate_player()
	var ok = player.load_recording(TEST_CLIP_PATH)
	assert_true(ok, "Loading test clip must succeed")

	player.start_loop()
	player._is_loop_paused = true
	player._loop_pause_timer = 2.0

	player.seek_frame(1)
	assert_false(player._is_loop_paused, "seek_frame must cancel loop pause")
	assert_almost_eq(player._loop_pause_timer, 0.0, 0.001, "seek_frame must reset loop pause timer")
	assert_eq(player.get_current_frame(), 1, "Frame must seek to 1")

	_free_player(player)

func test_diorama_player_stale_texture_clearing() -> void:
	var dummy_data = {
		"version": 1,
		"fps": 20.0,
		"frames": [
			[
				{"texture": "res://Textures/Player/player_sprite.png", "pos": [0, 0], "frame": 0, "hframes": 1, "vframes": 1, "flip_h": false, "flip_v": false, "rotation": 0.0, "scale": [1, 1], "modulate": [1, 1, 1, 1], "z_index": 0}
			],
			[
				{"texture": "", "pos": [0, 0], "frame": 0, "hframes": 1, "vframes": 1, "flip_h": false, "flip_v": false, "rotation": 0.0, "scale": [1, 1], "modulate": [1, 1, 1, 1], "z_index": 0}
			]
		]
	}

	var player = _instantiate_player()
	player.load_recording_data(dummy_data)
	player.seek_frame(0)
	var pool = player.get_node("SpritePool")
	var spr = pool.get_child(0) as Sprite2D
	assert_not_null(spr.texture, "Frame 0 sprite must have texture")

	player.seek_frame(1)
	assert_null(spr.texture, "Frame 1 with empty texture must clear previous texture to prevent stale leaks")

	_free_player(player)

func test_diorama_studio_input_isolation_with_line_edit() -> void:
	var studio = _instantiate_studio()
	var enemies = studio.get_node("%Enemies")
	var initial_enemies = enemies.get_child_count()

	# Simulate focusing LineEdit
	studio._clip_name_edit.grab_focus()

	# Create simulated key press '1'
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_1
	ev.physical_keycode = KEY_1
	studio._unhandled_input(ev)

	assert_eq(enemies.get_child_count(), initial_enemies, "Typing when LineEdit has focus must NOT trigger staging spawn hotkeys")

	# Release focus and verify hotkey works
	studio._clip_name_edit.release_focus()
	studio._unhandled_input(ev)
	assert_eq(enemies.get_child_count(), initial_enemies + 1, "Hotkey must work when LineEdit does not have focus")

	_free_studio(studio)

func test_diorama_studio_effective_z_index_capture() -> void:
	var studio = _instantiate_studio()
	var actors = studio.get_node("%Actors")

	# Create parent node with z_index 2, child sprite with z_index -1
	var parent_node = Node2D.new()
	parent_node.z_index = 2
	actors.add_child(parent_node)

	var child_spr = Sprite2D.new()
	child_spr.texture = load("res://Textures/GUI/blob_shadow.png")
	child_spr.z_index = -1
	parent_node.add_child(child_spr)

	var frames: Array = []
	studio._collect_active_sprites(parent_node, frames)
	assert_eq(frames.size(), 1, "Must collect child sprite")
	assert_eq(frames[0]["z_index"], 1, "Effective z_index must be parent (2) + child (-1) = 1")

	parent_node.free()
	_free_studio(studio)

func test_diorama_studio_tornado_pierce() -> void:
	var studio = _instantiate_studio()
	var enemy1 = studio.spawn_enemy("kobold_weak", Vector2(300, 180))
	var enemy2 = studio.spawn_enemy("kobold_weak", Vector2(320, 180))

	studio.trigger_attack("tornado", Vector2(350, 180))
	var projs = studio.get_node("%Projectiles")
	assert_gt(projs.get_child_count(), 0, "Tornado projectile should be spawned")

	# Process 2 frames of projectiles
	studio._process_projectiles(0.05)

	# Tornado should hit enemy1 and still be alive
	assert_gt(projs.get_child_count(), 0, "Tornado must pierce and remain active after hitting first enemy")

	_free_studio(studio)

func test_amoeba_boss_spawning() -> void:
	var studio = _instantiate_studio()
	var amoeba = studio.spawn_enemy("amoeba", Vector2(250, 150))
	assert_not_null(amoeba, "spawn_enemy('amoeba') must return node")
	assert_true(amoeba.get_meta("is_boss", false), "Amoeba must be marked as boss")
	assert_eq(int(amoeba.get_meta("hp", 0)), 50, "Amoeba HP must be 50")
	assert_eq(float(amoeba.get_meta("speed", 0.0)), 34.0, "Amoeba speed must be 34.0")

	var body = amoeba.get_node_or_null("Body") as Sprite2D
	assert_not_null(body, "Amoeba must have Body Sprite2D")
	assert_not_null(body.texture, "Amoeba Body must have valid texture")
	assert_eq(body.texture.resource_path, "res://Textures/Enemy/giant_amoeba_new.png", "Amoeba texture path must match")
	assert_eq(body.scale, Vector2(2.0, 2.0), "Amoeba sprite scale must be (2, 2)")

	var giant_amoeba = studio.spawn_enemy("giant_amoeba", Vector2(200, 200))
	assert_not_null(giant_amoeba, "spawn_enemy('giant_amoeba') must return node")
	assert_true(giant_amoeba.get_meta("is_boss", false), "Giant Amoeba must be marked as boss")

	_free_studio(studio)

func test_amoeba_telegraph_lifecycle() -> void:
	var studio = _instantiate_studio()
	var amoeba = studio.spawn_enemy("amoeba", Vector2(200, 150))
	var projs = studio.get_node("%Projectiles")

	# Trigger attack targeting (300, 150)
	studio.trigger_amoeba_attack(Vector2(300, 150))
	assert_eq(amoeba.get_meta("boss_state", ""), "dissolving", "Amoeba should enter dissolving state")

	# Process 0.4s: halfway through dissolve (0.7s total)
	studio._process_enemies(0.4)
	var body = amoeba.get_node("Body") as Sprite2D
	assert_lt(body.scale.x, 2.0, "Body should shrink during dissolving")

	# Process 0.35s more (total 0.75s): should finish dissolve and enter telegraphing
	studio._process_enemies(0.35)
	assert_eq(amoeba.get_meta("boss_state", ""), "telegraphing", "Amoeba should enter telegraphing state")
	assert_false(body.visible, "Amoeba body should be hidden during telegraphing")

	var tele = amoeba.get_meta("telegraph_node", null) as Node2D
	assert_not_null(tele, "Telegraph node must be spawned")
	assert_true(is_instance_valid(tele), "Telegraph node must be valid in scene")

	var ring = tele.get_node_or_null("Ring") as Sprite2D
	var fill = tele.get_node_or_null("Fill") as Sprite2D
	assert_not_null(ring, "Telegraph must contain Ring Sprite2D")
	assert_not_null(fill, "Telegraph must contain Fill Sprite2D")
	assert_eq(ring.texture.resource_path, "res://Textures/Effects/telegraph_ring.png", "Ring must use telegraph_ring texture")
	assert_eq(fill.texture.resource_path, "res://Textures/Effects/telegraph_fill.png", "Fill must use telegraph_fill texture")

	# Process 0.8s during telegraph: fill should grow
	var fill_initial_scale = fill.scale.x
	studio._process_enemies(0.8)
	assert_gt(fill.scale.x, fill_initial_scale, "Fill scale must grow during telegraph phase")

	# Process 0.5s more (total 1.3s in telegraph, <= 0.8s remaining): reappear begins
	studio._process_enemies(0.5)
	assert_true(body.visible, "Amoeba body should become visible during reappear phase")

	# Process remaining 0.8s: burst should execute and reset boss to chase
	studio._process_enemies(0.8)
	assert_eq(amoeba.get_meta("boss_state", ""), "chase", "Amoeba should return to chase after burst")
	assert_eq(body.scale, Vector2(2.0, 2.0), "Amoeba scale should be restored to (2, 2)")

	_free_studio(studio)

func test_amoeba_telegraph_sprites_captured_by_recorder() -> void:
	var studio = _instantiate_studio()
	var amoeba = studio.spawn_enemy("amoeba", Vector2(200, 150))

	# Trigger attack and advance to telegraphing phase
	studio.trigger_amoeba_attack(Vector2(250, 150))
	studio._process_enemies(0.75) # Past dissolve into telegraphing

	var actors = studio.get_node("%Actors")
	var captured_sprites: Array = []
	studio._collect_active_sprites(actors, captured_sprites)

	var found_ring := false
	var found_fill := false
	for spr_data in captured_sprites:
		var tex_path: String = spr_data.get("texture", "")
		if tex_path == "res://Textures/Effects/telegraph_ring.png":
			found_ring = true
			assert_gt(spr_data["scale"][0], 0.0, "Ring scale must be positive")
		elif tex_path == "res://Textures/Effects/telegraph_fill.png":
			found_fill = true
			assert_gt(spr_data["scale"][0], 0.0, "Fill scale must be positive")

	assert_true(found_ring, "Ghost recorder must capture telegraph ring as Sprite2D")
	assert_true(found_fill, "Ghost recorder must capture telegraph fill as Sprite2D")

	_free_studio(studio)

func test_spawn_on_cursor_toggle_and_resolution() -> void:
	var studio = _instantiate_studio()

	# Default: spawn_on_cursor is false
	assert_false(studio._spawn_on_cursor, "spawn_on_cursor should default to false")
	var default_pos = studio._resolve_spawn_pos(Vector2.ZERO, 80.0)
	var expected_front = studio._get_player_spawn_offset(80.0)
	assert_eq(default_pos, expected_front, "When spawn_on_cursor is false, must resolve to player front offset")

	# Toggle ON
	studio.set_spawn_on_cursor(true)
	assert_true(studio._spawn_on_cursor, "set_spawn_on_cursor(true) must set flag to true")

	# Set simulated stage mouse pos
	studio._last_valid_stage_pos = Vector2(180, 220)
	var cursor_pos = studio._resolve_spawn_pos(Vector2.ZERO, 80.0)
	assert_eq(cursor_pos, Vector2(180, 220), "When spawn_on_cursor is true, must resolve to stage cursor position")

	# Explicit position should always override
	var explicit_pos = studio._resolve_spawn_pos(Vector2(50, 60), 80.0)
	assert_eq(explicit_pos, Vector2(50, 60), "Explicit position must always override cursor and offset")

	# Toggle back OFF
	studio.toggle_spawn_on_cursor()
	assert_false(studio._spawn_on_cursor, "toggle_spawn_on_cursor() must toggle flag back to false")

	_free_studio(studio)

func test_amoeba_death_drops_red_gem() -> void:
	var studio = _instantiate_studio()
	var drops = studio.get_node("%Drops")
	var initial_drops = drops.get_child_count()

	var amoeba = studio.spawn_enemy("amoeba", Vector2(220, 160))
	studio.kill_enemy(amoeba)

	assert_eq(drops.get_child_count(), initial_drops + 1, "Amoeba death must spawn drop")
	var drop = drops.get_child(drops.get_child_count() - 1)
	assert_eq(drop.get_meta("drop_type", ""), "gem_red", "Amoeba death drop must be red gem")

	_free_studio(studio)

func test_amoeba_multi_boss_trigger_and_telegraph_cleanup() -> void:
	var studio = _instantiate_studio()
	var amoeba1 = studio.spawn_enemy("amoeba", Vector2(200, 150))
	var amoeba2 = studio.spawn_enemy("amoeba", Vector2(400, 150))

	# Trigger attack 1: should pick amoeba1
	var picked1 = studio.trigger_amoeba_attack(Vector2(250, 150))
	assert_eq(picked1, amoeba1, "First trigger should pick amoeba1")
	assert_eq(amoeba1.get_meta("boss_state", ""), "dissolving", "amoeba1 should enter dissolving")

	# Trigger attack 2 while amoeba1 is busy: should pick amoeba2
	var picked2 = studio.trigger_amoeba_attack(Vector2(450, 150))
	assert_eq(picked2, amoeba2, "Second trigger should pick amoeba2 since amoeba1 is busy")
	assert_eq(amoeba2.get_meta("boss_state", ""), "dissolving", "amoeba2 should enter dissolving")

	# Advance amoeba1 into telegraphing
	studio._process_enemies(0.75)
	assert_eq(amoeba1.get_meta("boss_state", ""), "telegraphing", "amoeba1 should enter telegraphing")
	var tele1 = amoeba1.get_meta("telegraph_node", null) as Node2D
	assert_not_null(tele1, "Telegraph node must exist")

	# Re-trigger amoeba1 intentionally: verify old telegraph is freed and not leaked
	studio.start_amoeba_telegraph(amoeba1, Vector2(300, 150))
	assert_true(tele1.is_queued_for_deletion(), "Interrupted telegraph node must be queued for deletion to prevent leak")

	_free_studio(studio)

func test_amoeba_intangibility_while_dissolved_and_telegraphing() -> void:
	var studio = _instantiate_studio()
	var amoeba = studio.spawn_enemy("amoeba", Vector2(320, 180))
	var initial_hp = int(amoeba.get_meta("hp", 50))

	# Trigger attack to dissolve
	studio.trigger_amoeba_attack(Vector2(320, 180))
	assert_eq(amoeba.get_meta("boss_state", ""), "dissolving", "Amoeba should be dissolving")

	# Spawn projectile directly on top of dissolving amoeba
	var projs = studio.get_node("%Projectiles")
	var proj = Node2D.new()
	proj.position = amoeba.position
	proj.set_meta("dir", Vector2.ZERO)
	proj.set_meta("speed", 0.0)
	proj.set_meta("life", 2.0)
	proj.set_meta("pierce", 1)
	proj.set_meta("hit_enemies", [])
	proj.set_meta("is_projectile", true)
	proj.set_meta("damage", 10)
	projs.add_child(proj)

	studio._process_projectiles(0.1)
	assert_eq(int(amoeba.get_meta("hp", 0)), initial_hp, "Dissolved boss must be intangible to projectiles")

	# Advance to telegraphing (not yet reappearing)
	studio._process_enemies(0.75)
	assert_eq(amoeba.get_meta("boss_state", ""), "telegraphing", "Amoeba should be telegraphing")
	assert_false(amoeba.get_meta("is_reappearing", false), "Amoeba should not yet be reappearing")

	studio._process_projectiles(0.1)
	assert_eq(int(amoeba.get_meta("hp", 0)), initial_hp, "Underground boss before reappear must remain intangible")

	# Advance to reappear phase (<= 0.8s remaining)
	studio._process_enemies(1.3)
	assert_true(amoeba.get_meta("is_reappearing", false), "Amoeba should now be reappearing")

	# Projectile should now hit the reappearing boss
	studio._process_projectiles(0.1)
	assert_eq(int(amoeba.get_meta("hp", 0)), initial_hp - 10, "Reappearing boss should be hit by projectile")

	_free_studio(studio)

func test_amoeba_recording_round_trip_and_player_playback() -> void:
	var studio = _instantiate_studio()
	var amoeba = studio.spawn_enemy("amoeba", Vector2(300, 180))

	# Start recording
	studio.start_recording()
	assert_true(studio._is_recording, "Recording should be active")

	# Trigger amoeba telegraph
	studio.trigger_amoeba_attack(Vector2(350, 180))

	# Advance 20 frames (1 second total at 20 FPS): past dissolve into telegraph
	for i in range(20):
		studio._process(0.05)

	studio.stop_recording()
	assert_false(studio._is_recording, "Recording should be stopped")
	assert_gt(studio._recorded_frames.size(), 15, "Should have captured at least 15 frames")

	# Create player and load recorded frames directly
	var player = _instantiate_player()
	var payload = {
		"version": 1,
		"fps": 20.0,
		"duration": studio._record_elapsed,
		"frame_count": studio._recorded_frames.size(),
		"stage_size": [640, 360],
		"frames": studio._recorded_frames
	}
	var load_ok = player.load_recording_data(payload)
	assert_true(load_ok, "DioramaPlayer must successfully load amoeba recording payload")
	assert_eq(player.get_frame_count(), studio._recorded_frames.size(), "Frame count must match")

	# Seek to mid-telegraph frame (frame 18) and verify active sprites in pool
	player.seek_frame(18)
	var pool = player.get_node("SpritePool")
	var found_ring := false
	var found_fill := false
	for spr in pool.get_children():
		if spr is Sprite2D and spr.visible and spr.texture != null:
			var path = spr.texture.resource_path
			if path == "res://Textures/Effects/telegraph_ring.png":
				found_ring = true
			elif path == "res://Textures/Effects/telegraph_fill.png":
				found_fill = true

	assert_true(found_ring, "DioramaPlayer must replay telegraph ring")
	assert_true(found_fill, "DioramaPlayer must replay telegraph fill")

	# Verify background z_index is -100 so it doesn't occlude ground sprites
	var player_bg = player.get_node_or_null("BackgroundManager")
	if player_bg:
		assert_eq(player_bg.z_index, -100, "Background in DioramaPlayer must have z_index -100")

	_free_player(player)
	_free_studio(studio)



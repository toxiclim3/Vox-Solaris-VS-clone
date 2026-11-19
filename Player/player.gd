extends CharacterBody2D

@export var maxhp = 80
var base_maxhp = 80
var hp = maxhp
@export var regenPerSecond = 0.5 / 100 #regen percent of max hp, by default 0.5%
var base_regenPerSecond = 0.5 / 100
var last_movement = Vector2.UP
var hasWon = false
var time = 0
var godmode = false
var loggingEnabled = false
var suppress_upgrade_unpause: bool = false

var experience = 0
var experience_level = 1
var collected_experience = 0
var total_collected_experience = 0.0
var last_minute_total_experience = 0.0
var last_logged_time = -1

@export var hurtBadThreshold = 0.20
var hurtBadTriggered = false

var titleMenu = "res://TitleScreen/menu.tscn"

#Attacks removed as they are dynamic now

#UPGRADES
var collected_upgrades = []
var upgrade_options = []
var pending_levelups = 0  # Queue of level-ups waiting to be shown
var pending_boss_rewards = 0 # Queue of boss rewards waiting to be shown
var collected_endless = {} # Dictionary of "base_name" -> int count

# Base Stats
var base_armor = 0
var armor = 0
@export var base_movement_speed = 85.0
var movement_speed = 85.0
var base_spell_cooldown = 0.0
var spell_cooldown = 0.0
var base_spell_size = 0.0
var spell_size = 0.0
var base_additional_attacks = 0.0
var additional_attacks = 0.0

# XP gem grab range
const BASE_GRAB_RADIUS = 50.0

# Slot limits
var max_weapon_slots = 6
var max_upgrade_slots = 8

# Track Stat Modifiers
var stat_modifiers = {}

# Item mechanics
var lifesteal: float = 0.0
var armor_multiplier: float = 0.0
var reflected_damage: float = 0.0

# Javelin level tracked for global updates to Javelins
var javelin_level = 0
var javelin_endless_level = 0
var lightningrod_level = 0
var lightningrod_endless_level = 0
var willowisp_level = 0
var willowisp_explosion_scene = preload("res://Player/Attack/willowisp/willowisp_explosion.tscn")
var relic_drone_node = null
var joystick_vector := Vector2.ZERO

# Health-based items state
var glass_talisman_level: int = 0
var glass_talisman_damage_bonus: float = 0.0
var damage_multiplier: float = 1.0
const GLASS_TALISMAN_BONUSES = [0.0, 0.05, 0.10, 0.15, 0.25]

var warding_brooch_level: int = 0
var warding_brooch_charge: bool = false
var warding_brooch_timer: float = 0.0
var warding_brooch_speed_timer: float = 0.0
var last_warding_absorbed: float = 0.0
var last_warding_spillover: float = 0.0

var frenzy_charm_level: int = 0
var frenzy_charm_active: bool = false
const FRENZY_CHARM_BONUSES = [0.0, 0.10, 0.20, 0.30]

var impact_buckler_level: int = 0
var impact_buckler_cooldown: float = 0.0
var buckler_triggered: bool = false
var buckler_trigger_count: int = 0
const IMPACT_BUCKLER_COOLDOWNS = [0.0, 60.0, 40.0, 20.0]

# Passive tier caches for stride helpers
var speed_tier: int = 0
var scroll_tier: int = 0

# Layer 1 Movement Substrate
var stride_distance_total: float = 0.0
var stride_step_delta: float = 0.0
var is_anchored: bool = false
var bastion_charge: float = 0.0
var current_move_dir: Vector2 = Vector2.ZERO
var _last_emitted_anchored: bool = false
var _last_emitted_bastion_charge: float = 0.0

# Layer 2 Character Mobility (Spacebar)
var mobility_type: String = "sidestep"
var mobility_cooldown: float = 0.0
var sidestep_timer: float = 0.0
var sidestep_iframe_timer: float = 0.0
var sidestep_dir: Vector2 = Vector2.ZERO
var forward_dash_timer: float = 0.0
var forward_dash_dir: Vector2 = Vector2.ZERO
var forward_dash_distance_credited: bool = false
var impulse_primed: bool = false
var impulse_prime_timer: float = 0.0
var rock_stance_active: bool = false
var rock_stance_burst_timer: float = 0.0
var rock_stance_burst_icd: float = 0.0
var _rock_stance_from_input: bool = false

#Elite Graphics
var rt_light: PointLight2D = null

#Enemy Related
var enemy_close = []

@onready var sprite = $Sprite2D
@onready var walkTimer = get_node("%walkTimer")
@onready var regen_timer = get_node("%regenTimer")
@onready var grab_shape = get_node("GrabArea/CollisionShape2D")

@onready var weapons = get_node("%Weapons") # Dynamic weapons container

#GUI
@onready var gui = get_tree().get_first_node_in_group("gui")
@onready var healthBar = get_node("%HealthBar")
@onready var sndHurt = get_node("%snd_hurt")
@onready var sndHurtBad = get_node("%snd_hurt_bad")



#Signal
signal playerdeath
signal health_ratio_changed(current_ratio: float, previous_ratio: float)
signal mobility_triggered(mobility_type: String, direction: Vector2)
signal stance_changed(is_anchored: bool, bastion_charge: float)
signal rock_stance_burst_started(duration: float)
signal movement_prime_ready(source_id: String)
signal stride_distance_gained(delta_px: float)

func _init() -> void:
	if not health_ratio_changed.is_connected(_on_health_ratio_changed):
		health_ratio_changed.connect(_on_health_ratio_changed)

func _ready():
	base_movement_speed = float(GlobalEvents.MOVEMENT_CONFIG.get("base_movement_speed", 85.0))
	var active_char = GlobalEvents.selected_character
	if active_char != "" and GlobalEvents.CHARACTERS.has(active_char):
		var char_data = GlobalEvents.CHARACTERS[active_char]
		mobility_type = str(char_data.get("mobility_type", "sidestep"))
		if char_data.has("base_stats") and char_data["base_stats"].has("maxhp"):
			base_maxhp = char_data["base_stats"]["maxhp"]
			maxhp = base_maxhp
			hp = maxhp
		if char_data.has("starting_weapon") and char_data["starting_weapon"] != "":
			upgrade_character(char_data["starting_weapon"])
			
		# Load character texture if it exists
		if char_data.has("icon"):
			var tex = load(char_data["icon"])
			if tex:
				sprite.texture = tex
				
		# Apply color using shader to preserve shading and detail (Hue blend mode)
		if char_data.has("icon_color"):
			var mat = sprite.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("target_color", char_data["icon_color"])
				
				# Reset all flags to defaults first
				mat.set_shader_parameter("mix_hue", true)
				mat.set_shader_parameter("mix_saturation", false)
				mat.set_shader_parameter("mix_value", false)
				
				# Disable hue shift for pure white to preserve original colors (Mage fix)
				if char_data["icon_color"].r > 0.99 and char_data["icon_color"].g > 0.99 and char_data["icon_color"].b > 0.99:
					mat.set_shader_parameter("mix_hue", false)
				
				# Apply optional shader configurations (e.g., mix_saturation for The Punished)
				if char_data.has("shader_config"):
					var config = char_data["shader_config"]
					for key in config:
						mat.set_shader_parameter(key, config[key])
			
			# Reset self_modulate to default white to avoid double-tinting
			sprite.self_modulate = Color.WHITE
			
	attack()
	apply_stat_modifiers()
	gui.set_expbar(experience, calculate_experiencecap())
	gui.set_level_text(experience_level)
	healthBar.max_value = maxhp
	healthBar.value = hp
	GlobalEvents.enemy_died.connect(_on_enemy_died)
	GlobalEvents.boss_defeated.connect(_on_boss_defeated)
	GlobalEvents.player_dealt_damage.connect(_on_player_dealt_damage)
	if not GlobalEvents.movement_config_changed.is_connected(_on_movement_config_changed):
		GlobalEvents.movement_config_changed.connect(_on_movement_config_changed)
	
	# Ray Tracing (Elite)
	_setup_rt_light()
	SettingsManager.raytracing_settings_changed.connect(_on_rt_settings_changed)
	
	# Camera Zoom
	SettingsManager.camera_zoom_changed.connect(_on_camera_zoom_changed)
	_on_camera_zoom_changed(SettingsManager.camera_zoom)
	
	# Connect Virtual Joystick
	var joy = get_tree().get_first_node_in_group("gui_layer").get_node_or_null("%VirtualJoystick")
	if joy:
		joy.joystick_vector.connect(func(v): joystick_vector = v)
	
	# Set slot limits based on difficulty
	max_weapon_slots = GlobalEvents.get_max_weapon_slots()
	max_upgrade_slots = GlobalEvents.get_max_upgrade_slots()

func _setup_rt_light():
	if rt_light == null:
		rt_light = PointLight2D.new()
		rt_light.texture = load("res://Textures/GUI/light_gradient.png")
		rt_light.energy = 2.0
		rt_light.texture_scale = 2.0
		rt_light.color = Color(1.0, 0.9, 0.7) # Warm "Premium" light
		add_child(rt_light)
	rt_light.visible = SettingsManager.raytracing_enabled

func _on_rt_settings_changed(enabled: bool):
	if rt_light:
		rt_light.visible = enabled

func _on_camera_zoom_changed(zoom_val: float):
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.zoom = Vector2(zoom_val, zoom_val)

func _on_movement_config_changed() -> void:
	base_movement_speed = float(GlobalEvents.MOVEMENT_CONFIG.get("base_movement_speed", 85.0))
	if not GlobalEvents.is_movement_coupled():
		_cancel_active_mobility()
		is_anchored = false
		bastion_charge = 0.0
		stride_step_delta = 0.0
		rock_stance_burst_timer = 0.0
		_emit_stance_if_changed()
	apply_stat_modifiers()

func _physics_process(delta):
	movement(delta)
	update_health_items(delta)

func _set_hp(new_hp: float) -> void:
	var prev_ratio: float = float(hp) / float(maxhp) if maxhp > 0 else 0.0
	hp = clamp(new_hp, 0.0, float(maxhp))
	var cur_ratio: float = float(hp) / float(maxhp) if maxhp > 0 else 0.0
	if healthBar != null:
		healthBar.max_value = maxhp
		healthBar.value = hp
	if not is_equal_approx(cur_ratio, prev_ratio):
		health_ratio_changed.emit(cur_ratio, prev_ratio)

func _on_health_ratio_changed(current_ratio: float, previous_ratio: float) -> void:
	# Glass Talisman: active when HP >= 95%
	glass_talisman_damage_bonus = get_damage_bonus()
	damage_multiplier = get_damage_modifier()
	
	# Frenzy Charm: active when HP < 30%
	var prev_frenzy = (previous_ratio < 0.30)
	var cur_frenzy = (current_ratio < 0.30)
	if prev_frenzy != cur_frenzy:
		apply_stat_modifiers()
		
	# Warding Brooch: recharge check if healed to >= 90%
	if warding_brooch_level > 0 and not warding_brooch_charge:
		if current_ratio >= 0.90 and warding_brooch_timer >= 10.0:
			warding_brooch_charge = true
			
	# Impact Buckler: automatically triggers radial shockwave when HP drops below 20%
	if impact_buckler_level > 0:
		if current_ratio < 0.20 and previous_ratio >= 0.20:
			if impact_buckler_cooldown <= 0.0:
				trigger_impact_buckler()

func update_health_items(delta: float) -> void:
	# Warding brooch recharge: while HP >= 90%, gains protection charge after 10s out of combat
	if warding_brooch_level > 0 and not warding_brooch_charge:
		warding_brooch_timer += delta
		var cur_ratio = float(hp) / float(maxhp) if maxhp > 0 else 0.0
		if warding_brooch_timer >= 10.0 and cur_ratio >= 0.90:
			warding_brooch_charge = true
			
	# Warding brooch Tier 2 speed boost timer
	if warding_brooch_speed_timer > 0.0:
		warding_brooch_speed_timer -= delta
		if warding_brooch_speed_timer <= 0.0:
			warding_brooch_speed_timer = 0.0
			apply_stat_modifiers()
			
	# Impact buckler cooldown
	if impact_buckler_cooldown > 0.0:
		impact_buckler_cooldown -= delta
		if impact_buckler_cooldown < 0.0:
			impact_buckler_cooldown = 0.0

func get_damage_bonus() -> float:
	var cur_ratio = float(hp) / float(maxhp) if maxhp > 0 else 0.0
	if cur_ratio >= 0.95 and glass_talisman_level > 0:
		var endless_count = collected_endless.get("glasstalisman", 0)
		return GLASS_TALISMAN_BONUSES[clamp(glass_talisman_level, 0, 4)] + (0.02 * endless_count)
	return 0.0

func get_damage_modifier() -> float:
	return 1.0 + get_damage_bonus()

func get_attack_speed_bonus() -> float:
	var cur_ratio = float(hp) / float(maxhp) if maxhp > 0 else 0.0
	if cur_ratio < 0.30 and frenzy_charm_level > 0:
		return FRENZY_CHARM_BONUSES[clamp(frenzy_charm_level, 0, 3)]
	return 0.0

func get_rock_stance_burst_mult() -> float:
	if GlobalEvents.is_movement_coupled() and rock_stance_burst_timer > 0.0:
		return float(GlobalEvents.MOVEMENT_CONFIG.get("rock_stance_burst_cd_mult", 0.70))
	return 1.0

func calculate_cooldown(wait_time: float) -> float:
	return calculate_weapon_cooldown(wait_time, 1.0)

func calculate_weapon_cooldown(base_wait_time: float, movement_cd_mult: float = 1.0) -> float:
	var raw_floor := float(GlobalEvents.MOVEMENT_CONFIG.get("cooldown_floor", 0.05))
	var cd_floor := 0.05 if (is_nan(raw_floor) or not is_finite(raw_floor)) else maxf(0.05, raw_floor)
	var burst_mult := get_rock_stance_burst_mult()
	var effective_mult := movement_cd_mult if GlobalEvents.is_movement_coupled() else 1.0
	var raw: float = base_wait_time * (1.0 - float(spell_cooldown)) * burst_mult * effective_mult
	if is_nan(raw) or not is_finite(raw):
		return cd_floor
	return maxf(cd_floor, raw)

func absorb_warding_damage(incoming_damage: float) -> Dictionary:
	var capacity: float = float(maxhp) * 0.05
	var absorbed: float = 0.0
	var spillover: float = incoming_damage
	if warding_brooch_charge:
		warding_brooch_charge = false
		warding_brooch_timer = 0.0
		if incoming_damage <= capacity:
			absorbed = incoming_damage
			spillover = 0.0
		else:
			absorbed = capacity
			spillover = incoming_damage - capacity
		if warding_brooch_level >= 2:
			warding_brooch_speed_timer = 3.0
			apply_stat_modifiers()
	last_warding_absorbed = absorbed
	last_warding_spillover = spillover
	return {"absorbed": absorbed, "spillover": spillover}

func trigger_impact_buckler() -> void:
	impact_buckler_cooldown = IMPACT_BUCKLER_COOLDOWNS[clamp(impact_buckler_level, 0, 3)]
	buckler_triggered = true
	buckler_trigger_count += 1
	_spawn_buckler_shockwave()

func _spawn_buckler_shockwave() -> void:
	var shockwave_scene = load("res://Player/Attack/impact_buckler/impact_buckler_shockwave.tscn")
	if shockwave_scene:
		var sw = shockwave_scene.instantiate()
		sw.global_position = global_position
		if get_parent() != null:
			get_parent().add_child(sw)
		elif is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
			get_tree().current_scene.add_child(sw)
		else:
			add_child(sw)

func add_stride_distance(px: float) -> void:
	if px > 0.0 and GlobalEvents.is_movement_coupled():
		stride_distance_total += px
		stride_distance_gained.emit(px)

func get_stride_efficiency() -> float:
	var per_tier := float(GlobalEvents.MOVEMENT_CONFIG.get("stride_efficiency_per_speed_tier", 0.05))
	return 1.0 + per_tier * float(speed_tier)

func get_stride_threshold_mult() -> float:
	var per_tier := float(GlobalEvents.MOVEMENT_CONFIG.get("stride_threshold_reduction_per_scroll_tier", 0.05))
	return maxf(0.2, 1.0 - per_tier * float(scroll_tier))

func evaluate_heading_dot(target_pos: Vector2) -> float:
	if target_pos == Vector2.INF or not target_pos.is_finite():
		return 0.0
	var mov_dir := current_move_dir
	if mov_dir == Vector2.ZERO and velocity.length_squared() > 0.0001:
		mov_dir = velocity.normalized()
	if mov_dir == Vector2.ZERO:
		return 0.0
	var to_target := target_pos - global_position
	if to_target.length_squared() <= 0.0001:
		return 0.0
	return clampf(mov_dir.dot(to_target.normalized()), -1.0, 1.0)

func is_swarm_push_immune() -> bool:
	return sidestep_iframe_timer > 0.0 or rock_stance_active

func _can_process_mobility_input() -> bool:
	if not GlobalEvents.is_movement_coupled():
		return false
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree != null and tree.paused:
		return false
	var vp := get_viewport()
	if vp != null and vp.gui_get_focus_owner() != null:
		return false
	if gui != null and is_instance_valid(gui):
		var lp = gui.get("levelPanel")
		if lp is Control and lp.visible:
			return false
		var blp = gui.get("bossLevelPanel")
		if blp is Control and blp.visible:
			return false
		var dp = gui.get("deathPanel")
		if dp is Control and dp.visible:
			return false
	return true

func _emit_stance_if_changed() -> void:
	var hit_edge := (bastion_charge == 0.0 and _last_emitted_bastion_charge != 0.0) or (bastion_charge == 1.0 and _last_emitted_bastion_charge != 1.0)
	if is_anchored != _last_emitted_anchored or absf(bastion_charge - _last_emitted_bastion_charge) >= 0.01 or hit_edge:
		_last_emitted_anchored = is_anchored
		_last_emitted_bastion_charge = bastion_charge
		stance_changed.emit(is_anchored, bastion_charge)

func trigger_mobility(dir_override: Vector2 = Vector2.ZERO) -> bool:
	if not GlobalEvents.is_movement_coupled():
		return false
	match mobility_type:
		"sidestep":
			if mobility_cooldown > 0.0 or sidestep_timer > 0.0 or forward_dash_timer > 0.0:
				return false
			var dir := dir_override.normalized() if dir_override.length_squared() > 0.0001 else (current_move_dir if current_move_dir.length_squared() > 0.0001 else last_movement.normalized())
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var dur := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("sidestep_duration", 0.12)))
			sidestep_dir = dir
			sidestep_timer = dur
			sidestep_iframe_timer = dur
			mobility_cooldown = float(GlobalEvents.MOVEMENT_CONFIG.get("sidestep_cooldown", 2.5))
			is_anchored = false
			mobility_triggered.emit("sidestep", sidestep_dir)
			return true
		"forward_dash":
			if mobility_cooldown > 0.0 or forward_dash_timer > 0.0 or sidestep_timer > 0.0:
				return false
			var dir := dir_override.normalized() if dir_override.length_squared() > 0.0001 else (current_move_dir if current_move_dir.length_squared() > 0.0001 else last_movement.normalized())
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var dur := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("forward_dash_duration", 0.14)))
			forward_dash_dir = dir
			forward_dash_timer = dur
			forward_dash_distance_credited = false
			mobility_cooldown = float(GlobalEvents.MOVEMENT_CONFIG.get("forward_dash_cooldown", 3.5))
			is_anchored = false
			mobility_triggered.emit("forward_dash", forward_dash_dir)
			return true
		"rock_stance":
			set_rock_stance_held(true, dir_override)
			return true
	return false

func set_rock_stance_held(held: bool, aim_dir: Vector2 = Vector2.ZERO) -> void:
	if held and GlobalEvents.is_movement_coupled() and mobility_type == "rock_stance":
		if aim_dir.length_squared() > 0.0001:
			var norm_aim := aim_dir.normalized()
			last_movement = norm_aim
			if sprite != null:
				if norm_aim.x > 0.0:
					sprite.flip_h = true
				elif norm_aim.x < 0.0:
					sprite.flip_h = false
		if not rock_stance_active:
			rock_stance_active = true
			velocity = Vector2.ZERO
			is_anchored = true
			apply_stat_modifiers()
			var face_dir := last_movement.normalized() if last_movement.length_squared() > 0.0001 else Vector2.RIGHT
			mobility_triggered.emit("rock_stance", face_dir)
			if rock_stance_burst_icd <= 0.0:
				var burst_dur := float(GlobalEvents.MOVEMENT_CONFIG.get("rock_stance_burst_duration", 1.35))
				rock_stance_burst_timer = burst_dur
				rock_stance_burst_icd = float(GlobalEvents.MOVEMENT_CONFIG.get("rock_stance_icd", 4.0))
				attack()
				rock_stance_burst_started.emit(burst_dur)
	elif not held and rock_stance_active:
		rock_stance_active = false
		_rock_stance_from_input = false
		apply_stat_modifiers()

func _cancel_active_mobility() -> void:
	mobility_cooldown = 0.0
	sidestep_timer = 0.0
	sidestep_iframe_timer = 0.0
	forward_dash_timer = 0.0
	forward_dash_distance_credited = false
	impulse_primed = false
	impulse_prime_timer = 0.0
	rock_stance_burst_timer = 0.0
	rock_stance_burst_icd = 0.0
	_rock_stance_from_input = false
	if rock_stance_active:
		set_rock_stance_held(false)

func movement(delta: float = 1.0 / 60.0):
	if mobility_cooldown > 0.0:
		mobility_cooldown = maxf(0.0, mobility_cooldown - delta)
	if rock_stance_burst_icd > 0.0:
		rock_stance_burst_icd = maxf(0.0, rock_stance_burst_icd - delta)
	if impulse_prime_timer > 0.0:
		impulse_prime_timer = maxf(0.0, impulse_prime_timer - delta)
		if impulse_prime_timer <= 0.0:
			impulse_primed = false
	if rock_stance_burst_timer > 0.0:
		rock_stance_burst_timer = maxf(0.0, rock_stance_burst_timer - delta)
		if rock_stance_burst_timer <= 0.0:
			attack()

	var mov := Vector2.ZERO
	var mouse_brake := false
	if SettingsManager.mouse_control:
		var target_pos = get_global_mouse_position()
		var diff = target_pos - global_position
		mouse_brake = Input.is_action_pressed("click")
		if diff.length() > 15 and not mouse_brake: # Stop if close to player or holding LMB
			mov = diff.normalized()
	else:
		var x_mov = Input.get_action_strength("right") - Input.get_action_strength("left")
		var y_mov = Input.get_action_strength("down") - Input.get_action_strength("up")
		mov = Vector2(x_mov, y_mov)
		# Overlay joystick movement if no keyboard input is present
		if mov == Vector2.ZERO and joystick_vector != Vector2.ZERO:
			mov = joystick_vector

	if InputMap.has_action("mobility") and _can_process_mobility_input():
		if mobility_type == "rock_stance":
			var aim_dir := (get_global_mouse_position() - global_position) if SettingsManager.mouse_control else mov
			if Input.is_action_pressed("mobility"):
				_rock_stance_from_input = true
				set_rock_stance_held(true, aim_dir)
			elif _rock_stance_from_input:
				_rock_stance_from_input = false
				set_rock_stance_held(false)
		elif Input.is_action_just_pressed("mobility"):
			trigger_mobility(mov)
	elif rock_stance_active:
		set_rock_stance_held(false)

	if sidestep_iframe_timer > 0.0:
		sidestep_iframe_timer = maxf(0.0, sidestep_iframe_timer - delta)

	if sidestep_timer > 0.0:
		sidestep_timer = maxf(0.0, sidestep_timer - delta)
		var sidestep_dist := float(GlobalEvents.MOVEMENT_CONFIG.get("sidestep_distance", 84.0))
		var sidestep_dur := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("sidestep_duration", 0.12)))
		velocity = sidestep_dir * (sidestep_dist / sidestep_dur)
		current_move_dir = sidestep_dir
		is_anchored = false
	elif forward_dash_timer > 0.0:
		forward_dash_timer = maxf(0.0, forward_dash_timer - delta)
		var dash_dist := float(GlobalEvents.MOVEMENT_CONFIG.get("forward_dash_distance", 140.0))
		var dash_dur := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("forward_dash_duration", 0.14)))
		velocity = forward_dash_dir * (dash_dist / dash_dur)
		current_move_dir = forward_dash_dir
		is_anchored = false
		if forward_dash_timer <= 0.0 and not forward_dash_distance_credited:
			forward_dash_distance_credited = true
			add_stride_distance(dash_dist)
			impulse_primed = true
			impulse_prime_timer = float(GlobalEvents.MOVEMENT_CONFIG.get("impulse_prime_duration", 1.5))
			movement_prime_ready.emit("impulse")
	elif rock_stance_active:
		velocity = Vector2.ZERO
		current_move_dir = Vector2.ZERO
		is_anchored = true
	else:
		current_move_dir = mov.normalized() if mov != Vector2.ZERO else Vector2.ZERO
		if mov.x > 0:
			sprite.flip_h = true
		elif mov.x < 0:
			sprite.flip_h = false

		if mov != Vector2.ZERO:
			last_movement = current_move_dir
			if walkTimer.is_stopped():
				if sprite.frame >= sprite.hframes - 1:
					sprite.frame = 0
				else:
					sprite.frame += 1
				walkTimer.start()

		velocity = current_move_dir * movement_speed
		is_anchored = GlobalEvents.is_movement_coupled() and (mouse_brake or mov == Vector2.ZERO)

	if is_inside_tree():
		move_and_slide()

	var rv := get_real_velocity() if is_inside_tree() else Vector2.ZERO
	var real_dist := rv.length() * delta if (is_inside_tree() and GlobalEvents.is_movement_coupled() and rv.is_finite()) else 0.0
	stride_step_delta = real_dist
	if real_dist > 0.0:
		stride_distance_total += real_dist
		stride_distance_gained.emit(real_dist)

	if GlobalEvents.is_movement_coupled():
		var in_time := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("bastion_in_time", 0.45)))
		var out_time := maxf(0.01, float(GlobalEvents.MOVEMENT_CONFIG.get("bastion_out_time", 0.20)))
		if is_anchored:
			bastion_charge = minf(1.0, bastion_charge + delta / in_time)
		else:
			bastion_charge = maxf(0.0, bastion_charge - delta / out_time)
	else:
		is_anchored = false
		bastion_charge = 0.0

	_emit_stance_if_changed()

func attack():
	if weapons == null:
		return
	var cd_floor := maxf(0.05, float(GlobalEvents.MOVEMENT_CONFIG.get("cooldown_floor", 0.05)))
	for weapon in weapons.get_children():
		if weapon.has_method("attack"):
			weapon.attack()
		var timer = weapon.get("timer")
		if timer != null and timer is Timer and timer.wait_time < cd_floor:
			timer.wait_time = cd_floor
		var atk_timer = weapon.get("attackTimer")
		if atk_timer != null and atk_timer is Timer and atk_timer.wait_time < cd_floor:
			atk_timer.wait_time = cd_floor

func _on_regen_timer_timeout(): #regens regenPerSecond percent of maxHp every regenTimer timeout
	if hp < maxhp:
		var actual_regen = regenPerSecond * GlobalEvents.get_player_regen_modifier()
		_set_hp(hp + actual_regen*maxhp)
		if (hp >= (maxhp * hurtBadThreshold)) and hurtBadTriggered:
			hurtBadTriggered = false



func _on_hurt_box_hurt(damage, _angle, _knockback, _killer_source = "", attacker_node = null, _proc_coefficient = 1.0):
	if sidestep_iframe_timer > 0.0:
		return
	if damage > 0:
		GlobalEvents.player_took_damage.emit(damage, attacker_node)
		
		# Reflection logic (Thorn Ring)
		if reflected_damage > 0 and attacker_node and attacker_node.has_method("_on_hurt_box_hurt"):
			attacker_node._on_hurt_box_hurt(reflected_damage, Vector2.ZERO, 0, "Thorn Ring", self)

	if godmode == false:
		# Armor rework: Percentage reduction with diminishing returns (DR = Armor / (Armor + 40))
		var dr = float(armor) / (armor + 40.0)
		var actual_damage = damage * (1.0 - dr)
		actual_damage = clamp(actual_damage, 0.0, 999.0)
		
		# Taking damage resets Warding Brooch out-of-combat timer
		if actual_damage > 0:
			warding_brooch_timer = 0.0
			if warding_brooch_charge:
				var absorb_res = absorb_warding_damage(actual_damage)
				actual_damage = absorb_res["spillover"]
		
		if actual_damage > 0:
			if (hp >= (maxhp * hurtBadThreshold)) or hurtBadTriggered:
				sndHurt.play()
				GlobalEvents.camera_shake.emit(2.0, 0.2)
			else:
				sndHurtBad.play()
				hurtBadTriggered = true
				GlobalEvents.camera_shake.emit(3.0, 0.5)
			_set_hp(hp - actual_damage)
			
	if hp <= 0:
		death()

# Attacks are now managed by dynamic spawners


#enemy related logic
func _is_enemy_valid_target(body) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if body.get("is_dying") == true or (body.get("hp") != null and body.hp <= 0):
		return false
	if not body.visible:
		return false
	var sprite_node = body.get_node_or_null("EnemyBase/Sprite2D")
	if not sprite_node:
		sprite_node = body.get_node_or_null("Sprite2D")
	if sprite_node and not sprite_node.visible:
		return false
	var hurt_box = body.get_node_or_null("EnemyBase/HurtBox")
	if not hurt_box:
		hurt_box = body.get_node_or_null("HurtBox")
	if hurt_box:
		var cs = hurt_box.get_node_or_null("CollisionShape2D")
		if cs and cs.disabled:
			return false
	return true

func _collect_valid_targets() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for body in enemy_close:
		if is_instance_valid(body) and _is_enemy_valid_target(body):
			var pos: Vector2 = body.global_position
			var hp_val = body.get("hp")
			candidates.append({
				"pos": pos,
				"hp": float(hp_val) if hp_val != null else 0.0,
				"dist_sq": global_position.distance_squared_to(pos)
			})
	
	var tree := get_tree()
	if tree != null:
		var swarm = tree.get_first_node_in_group("swarm_manager")
		if swarm and "swarm_data" in swarm:
			for enemy in swarm.swarm_data:
				if not enemy.is_dead and enemy.hp > 0:
					var dist_sq := global_position.distance_squared_to(enemy.position)
					if dist_sq < 160000.0: # approx 400px radius
						candidates.append({
							"pos": enemy.position,
							"hp": float(enemy.hp),
							"dist_sq": dist_sq
						})
	return candidates

func get_random_target() -> Vector2:
	var candidates := _collect_valid_targets()
	if candidates.is_empty():
		return Vector2.INF
	return candidates.pick_random()["pos"]

func get_closest_target() -> Vector2:
	var closest_pos = Vector2.INF
	var min_dist = INF
	
	for candidate in _collect_valid_targets():
		var dist: float = candidate["dist_sq"]
		if dist < min_dist:
			min_dist = dist
			closest_pos = candidate["pos"]
			
	return closest_pos

func get_frontal_target() -> Vector2:
	var dir := last_movement.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP

	var closest_in_cone := Vector2.INF
	var min_cone_dist := INF
	var best_aligned_pos := Vector2.INF
	var best_dot := -2.0
	var best_aligned_dist := INF

	for candidate in _collect_valid_targets():
		var pos: Vector2 = candidate["pos"]
		var dist_sq: float = candidate["dist_sq"]
		var to_enemy := pos - global_position
		var dot := dir.dot(to_enemy.normalized()) if dist_sq > 0.0001 else 1.0

		if dot >= 0.5 and dist_sq < min_cone_dist:
			min_cone_dist = dist_sq
			closest_in_cone = pos

		if dot > best_dot + 0.0001 or (is_equal_approx(dot, best_dot) and dist_sq < best_aligned_dist):
			best_dot = dot
			best_aligned_dist = dist_sq
			best_aligned_pos = pos

	return closest_in_cone if closest_in_cone != Vector2.INF else best_aligned_pos

func get_strongest_target() -> Vector2:
	var best_pos := Vector2.INF
	var max_hp_found := -1.0
	var best_dist_sq := INF

	for candidate in _collect_valid_targets():
		var enemy_hp: float = candidate["hp"]
		var dist_sq: float = candidate["dist_sq"]
		if enemy_hp > max_hp_found + 0.001 or (is_equal_approx(enemy_hp, max_hp_found) and dist_sq < best_dist_sq):
			max_hp_found = enemy_hp
			best_dist_sq = dist_sq
			best_pos = candidate["pos"]

	return best_pos

func get_crowd_target() -> Vector2:
	var cell_enemies: Dictionary = {}
	var cell_min_dist: Dictionary = {}

	for candidate in _collect_valid_targets():
		var pos: Vector2 = candidate["pos"]
		var dist_sq: float = candidate["dist_sq"]
		var cell := Vector2i(int(floor(pos.x / 64.0)), int(floor(pos.y / 64.0)))
		if not cell_enemies.has(cell):
			cell_enemies[cell] = [pos]
			cell_min_dist[cell] = dist_sq
		else:
			cell_enemies[cell].append(pos)
			if dist_sq < cell_min_dist[cell]:
				cell_min_dist[cell] = dist_sq

	if cell_enemies.is_empty():
		return Vector2.INF

	var best_cell := Vector2i.ZERO
	var best_count := -1
	var best_dist_sq := INF

	for cell in cell_enemies.keys():
		var neighborhood_count := 0
		for cx in range(cell.x - 1, cell.x + 2):
			for cy in range(cell.y - 1, cell.y + 2):
				var neighbor := Vector2i(cx, cy)
				if cell_enemies.has(neighbor):
					neighborhood_count += cell_enemies[neighbor].size()

		var cell_dist: float = cell_min_dist[cell]
		if neighborhood_count > best_count or (neighborhood_count == best_count and cell_dist < best_dist_sq):
			best_count = neighborhood_count
			best_dist_sq = cell_dist
			best_cell = cell

	return cell_enemies[best_cell].pick_random()


func _on_enemy_detection_area_body_entered(body):
	if not enemy_close.has(body):
		enemy_close.append(body)

func _on_enemy_detection_area_body_exited(body):
	if enemy_close.has(body):
		enemy_close.erase(body)

#Xp related logic
func _on_grab_area_area_entered(area):
	if area.is_in_group("loot"):
		area.target = self

func _on_collect_area_area_entered(area):
	if area.is_in_group("loot"):
		var gem_exp = area.collect()
		calculate_experience(gem_exp)

func calculate_experience(gem_exp):
	var actual_exp = gem_exp * GlobalEvents.get_xp_gain_modifier()
	collected_experience += actual_exp
	total_collected_experience += actual_exp
	var leveled_up = false
	while true:
		var exp_required = calculate_experiencecap()
		if experience + collected_experience >= exp_required:
			collected_experience -= exp_required - experience
			experience_level += 1
			experience = 0
			pending_levelups += 1
			leveled_up = true
		else:
			experience += collected_experience
			collected_experience = 0
			break
	# Trigger the first reward menu only if one isn't already showing
	if (leveled_up or pending_boss_rewards > 0) and not gui.levelPanel.visible and not gui.bossLevelPanel.visible:
		_show_next_reward()
	if leveled_up:
		apply_stat_modifiers()
	gui.set_expbar(experience, calculate_experiencecap())

func calculate_experiencecap():
	var lvl = experience_level
	if lvl == 1: return 5
	elif lvl == 2: return 10
	elif lvl == 3: return 15
	elif lvl == 4: return 30
	elif lvl == 5: return 50
	elif lvl == 6: return 75
	elif lvl == 7: return 110
	elif lvl == 8: return 130
	elif lvl == 9: return 150
	elif lvl == 10: return 200
	elif lvl < 20:
		# Mid-game: Approx 2 levels/min instead of 1.5 (much smoother than previous +600)
		return 200 + (lvl - 10) * 250
	else:
		# Late-game: Approx 1.5 levels/min instead of 1 (reduced steep scaling jump)
		return 2700 + (lvl - 20) * 400



## Shows the next reward in queue (prioritize level-ups, then boss rewards)
func _show_next_reward():
	if pending_levelups > 0:
		pending_levelups -= 1
		levelup()
	elif pending_boss_rewards > 0:
		pending_boss_rewards -= 1
		boss_levelup()

func levelup():
	var current_visual_level = experience_level - pending_levelups
	if current_visual_level % GlobalEvents.backgroundInterval == 0:
		GlobalEvents.advanceBackground.emit()
	
	upgrade_options.clear()
	
	var options = 0
	var optionsmax = 3
	var options_list = []
	while options < optionsmax:
		var item = get_random_item()
		if item != null:
			options_list.append(item)
		elif not options_list.has("food"):
			options_list.append("food")
		options += 1
		
	# Fallback if somehow empty
	if options_list.size() == 0:
		options_list.append("food")
		
	gui.show_levelup(options_list, current_visual_level)
	get_tree().paused = true
	MusicController.focusMusic(false)

func boss_levelup():
	upgrade_options.clear()
	
	var options = 0
	var optionsmax = 3
	var options_list = []
	while options < optionsmax:
		var item = get_random_boss_item()
		if item == null: break
		options_list.append(item)
		options += 1
		
	if options_list.size() == 0:
		_show_next_reward()
		return

	gui.show_boss_levelup(options_list)
	get_tree().paused = true
	MusicController.focusMusic(false)



func apply_stat_modifiers():
	armor = base_armor
	movement_speed = base_movement_speed
	spell_cooldown = base_spell_cooldown
	spell_size = base_spell_size
	additional_attacks = base_additional_attacks
	var max_hp_percent_total = 0.0
	var xp_range_percent_total = 0.0
	var movement_speed_percent_total = 0.0
	regenPerSecond = base_regenPerSecond
	lifesteal = 0.0
	armor_multiplier = 0.0
	reflected_damage = 0.0
	
	for mod in stat_modifiers.values():
		for stat_name in mod.keys():
			match stat_name:
				"armor": armor += mod[stat_name]
				"movement_speed_percent": movement_speed_percent_total += mod[stat_name]
				"spell_cooldown": spell_cooldown += mod[stat_name]
				"spell_size": spell_size += mod[stat_name]
				"additional_attacks": additional_attacks += mod[stat_name]
				"max_hp_percent": max_hp_percent_total += mod[stat_name]
				"regen": regenPerSecond += mod[stat_name]
				"xp_range_percent": xp_range_percent_total += mod[stat_name]
				"lifesteal": lifesteal += mod[stat_name]
				"armor_multiplier": armor_multiplier += mod[stat_name]
				"reflected_damage": reflected_damage += mod[stat_name]
				
	# Apply character specific stats based on experience_level
	var active_char = GlobalEvents.selected_character
	if GlobalEvents.CHARACTERS.has(active_char):
		var char_data = GlobalEvents.CHARACTERS[active_char]
		# Base character stats
		if char_data.has("base_stats"):
			if char_data["base_stats"].has("maxhp"):
				var char_base_hp = char_data["base_stats"]["maxhp"]
				if base_maxhp == 80 or base_maxhp == char_base_hp:
					base_maxhp = char_base_hp
			for stat_name in char_data["base_stats"].keys():
				var val = char_data["base_stats"][stat_name]
				match stat_name:
					"armor": armor += val
					"movement_speed_percent": movement_speed_percent_total += val
					"spell_cooldown": spell_cooldown += val
					"spell_size": spell_size += val
					"additional_attacks": additional_attacks += val
					"max_hp_percent": max_hp_percent_total += val
					"regen": regenPerSecond += val
					"xp_range_percent": xp_range_percent_total += val
					"lifesteal": lifesteal += val
					"armor_multiplier": armor_multiplier += val
					"reflected_damage": reflected_damage += val
		# Scaled character stats based on progression towards scaling_max_level
		if char_data.has("scaling_stats") and experience_level > 1:
			var max_lvl = char_data.get("scaling_max_level", 20)
			# Fraction of completion from 0.0 (lvl 1) to 1.0 (lvl max_lvl)
			var progress = float(min(experience_level, max_lvl) - 1) / (max_lvl - 1)
			
			for stat_name in char_data["scaling_stats"].keys():
				var val = char_data["scaling_stats"][stat_name] * progress
				match stat_name:
					"armor": armor += val
					"movement_speed_percent": movement_speed_percent_total += val
					"spell_cooldown": spell_cooldown += val
					"spell_size": spell_size += val
					"additional_attacks": additional_attacks += val
					"max_hp_percent": max_hp_percent_total += val
					"regen": regenPerSecond += val
					"xp_range_percent": xp_range_percent_total += val
					"lifesteal": lifesteal += val
					"armor_multiplier": armor_multiplier += val
					"reflected_damage": reflected_damage += val
					
	# Apply Endless Stat Modifiers
	for base_name in collected_endless:
		var count = collected_endless[base_name]
		match base_name:
			"speed": movement_speed_percent_total += 0.02 * count
			"tome": spell_size += 0.02 * count # Relative to base
			"scroll": spell_cooldown += 0.02 * count
			"armor": armor += 1 * count
			"ringofaffinity": xp_range_percent_total += 0.05 * count
			"ring": # Multiplication (chance based)
				additional_attacks += 0.05 * count
			"thornring": reflected_damage += 5 * count
			"ringofrejuvenation": max_hp_percent_total += 0.05 * count # Scales max HP% by 5% per stack

	
	# Apply Warding Brooch Tier 2 speed boost if active
	if warding_brooch_speed_timer > 0.0:
		movement_speed_percent_total += 0.15

	# Apply Frenzy Charm attack speed bonus if active (HP < 30%)
	var frenzy_bonus = get_attack_speed_bonus()
	frenzy_charm_active = (frenzy_bonus > 0.0)
	spell_cooldown += frenzy_bonus

	# Update Glass Talisman damage values
	glass_talisman_damage_bonus = get_damage_bonus()
	damage_multiplier = get_damage_modifier()
	
	# Apply movement speed percent bonus
	movement_speed = base_movement_speed * (1.0 + movement_speed_percent_total)
	
	if GlobalEvents.is_movement_coupled() and rock_stance_active:
		armor += int(GlobalEvents.MOVEMENT_CONFIG.get("rock_stance_armor_bonus", 4))
	
	# Apply armor multiplier
	armor = int(armor * (1.0 + armor_multiplier))
	
	# Apply max HP percent bonus on top of base
	var new_maxhp = int(base_maxhp * (1.0 + max_hp_percent_total))
	if new_maxhp != maxhp:
		var ratio = float(hp) / float(maxhp) if maxhp > 0 else 1.0
		maxhp = new_maxhp
		_set_hp(max(1.0, ratio * maxhp))
	
	# Apply XP grab range
	grab_shape.shape.radius = BASE_GRAB_RADIUS * (1.0 + xp_range_percent_total)
	
	attack()

func upgrade_character(upgrade):
	var upgrade_data = UpgradeDb.UPGRADES.get(upgrade)
	if upgrade_data == null: return
	
	var type = upgrade_data["type"]
	
	# Check if it's a weapon (can be either 'weapon' or 'bossitem' if it has a spawner)
	var boss_weapons_with_spawner = ["glasslash", "vampireknives"]
	
	if upgrade.begins_with("relicdrone"):
		if not relic_drone_node:
			relic_drone_node = preload("res://Player/Attack/relicdrone/relicdrone.tscn").instantiate()
			add_child(relic_drone_node)
		
		var relic_lvl = int(upgrade.replace("relicdrone", ""))
		relic_drone_node.level = relic_lvl
		relic_drone_node.update_stats()
	elif type == "weapon" or (type == "bossitem" and boss_weapons_with_spawner.has(upgrade.rstrip("0123456789"))) or (upgrade.begins_with("occult_medallion") and type != "endless"):
		var base_name = upgrade.rstrip("0123456789")
		var folder_name = base_name.to_lower()
		var file_name = base_name.to_lower()
		
		var weapon_spawner = weapons.get_node_or_null(base_name)
		if weapon_spawner == null:
			var spawner_scene = load("res://Player/Attack/" + folder_name + "/" + file_name + "_spawner.gd")
			if spawner_scene:
				weapon_spawner = Node2D.new()
				weapon_spawner.set_script(spawner_scene)
				weapon_spawner.name = base_name
				weapons.add_child(weapon_spawner)
		if weapon_spawner:
			weapon_spawner.upgrade(upgrade)
			
	elif type == "upgrade" or type == "item" or type == "bossitem":
		if upgrade.begins_with("willowisp"):
			willowisp_level = int(upgrade.replace("willowisp", ""))
		elif upgrade.begins_with("glasstalisman"):
			glass_talisman_level = int(upgrade.replace("glasstalisman", ""))
		elif upgrade.begins_with("wardingbrooch"):
			warding_brooch_level = int(upgrade.replace("wardingbrooch", ""))
		elif upgrade.begins_with("frenzycharm"):
			frenzy_charm_level = int(upgrade.replace("frenzycharm", ""))
		elif upgrade.begins_with("impactbuckler"):
			impact_buckler_level = int(upgrade.replace("impactbuckler", ""))
		elif upgrade.begins_with("speed"):
			speed_tier = int(upgrade.replace("speed", ""))
		elif upgrade.begins_with("scroll"):
			scroll_tier = int(upgrade.replace("scroll", ""))
		
		if upgrade_data.has("stat_modifiers"):
			if type == "item" and upgrade == "food":
				_set_hp(hp + upgrade_data["stat_modifiers"]["hp"])
			else:
				stat_modifiers[upgrade] = upgrade_data["stat_modifiers"]
				apply_stat_modifiers()
		else:
			apply_stat_modifiers()
	elif type == "endless":
		var base_name = upgrade.trim_suffix("_endless")
		if not collected_endless.has(base_name):
			collected_endless[base_name] = 0
		collected_endless[base_name] += 1
		
		# Update weapon spawner if it exists
		var weapon_spawner = weapons.get_node_or_null(base_name)
		if weapon_spawner and weapon_spawner.has_method("upgrade"):
			weapon_spawner.upgrade(upgrade)
			
		apply_stat_modifiers()

				
	gui.adjust_gui_collection(upgrade)
	attack()
	upgrade_options.clear()
	if not upgrade in collected_upgrades:
		collected_upgrades.append(upgrade)
	gui.hide_level_panels()
	# Get the level that we just finished upgrading
	var current_visual_level = experience_level - pending_levelups
	
	# If more rewards are queued, show the next one; otherwise unpause
	if pending_levelups > 0 or pending_boss_rewards > 0:
		_show_next_reward()
	else:
		if not suppress_upgrade_unpause and is_inside_tree() and get_tree() != null:
			get_tree().paused = false
		MusicController.focusMusic(true)
	calculate_experience(0)
	
	if current_visual_level % GlobalEvents.musicInterval == 0:
		MusicController.playNext(MusicController.MusicType.NORMAL)


func _get_effective_type(upgrade_id: String) -> String:
	var item = UpgradeDb.UPGRADES.get(upgrade_id)
	if not item: return ""
	if item["type"] == "endless":
		if item["prerequisite"].size() > 0:
			var prereq_id = item["prerequisite"][0]
			var prereq_item = UpgradeDb.UPGRADES.get(prereq_id)
			if prereq_item:
				return prereq_item["type"]
	return item["type"]


func get_random_item():
	var standard_pool = []
	var endless_pool = []
	
	# Calculate current unique weapons and upgrades
	var unique_weapons = []
	var unique_upgrades = []
	for collected in collected_upgrades:
		var type = _get_effective_type(collected)
		var displayname = UpgradeDb.UPGRADES[collected]["displayname"]
		if type == "weapon" and not displayname in unique_weapons:
			unique_weapons.append(displayname)
		elif type == "upgrade" and not displayname in unique_upgrades:
			unique_upgrades.append(displayname)
	
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades: #Find already collected upgrades
			if UpgradeDb.UPGRADES[i]["type"] != "endless":
				continue
		
		if i in upgrade_options: #If the upgrade is already an option
			continue
			
		var type = _get_effective_type(i)
		if type == "item" or type == "bossitem": #Don't pick food or boss items in regular pool
			continue
			
		if UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0: #Check for PreRequisites
			var to_add = true
			for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
				if not n in collected_upgrades:
					to_add = false
			if to_add:
				if UpgradeDb.UPGRADES[i]["type"] == "endless":
					endless_pool.append(i)
				else:
					standard_pool.append(i)
		else:
			# This is a new item (level 1)
			if type == "weapon" and unique_weapons.size() >= max_weapon_slots:
				continue
			if type == "upgrade" and unique_upgrades.size() >= max_upgrade_slots:
				continue
				
			if UpgradeDb.UPGRADES[i]["type"] == "endless":
				endless_pool.append(i)
			else:
				standard_pool.append(i)

	var has_free_slots = unique_weapons.size() < max_weapon_slots or unique_upgrades.size() < max_upgrade_slots
	var dblist = []
	
	if standard_pool.size() > 0:
		if has_free_slots:
			# Deprioritize endless items: 10% chance to allow endless if free slots exist
			if randf() < 0.10 and endless_pool.size() > 0:
				dblist = standard_pool + endless_pool
			else:
				dblist = standard_pool
		else:
			# Slots are full, so we can see endless items normally
			dblist = standard_pool + endless_pool
	else:
		# Only endless items left
		dblist = endless_pool
			
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null


func get_random_boss_item():
	var standard_pool = []
	var endless_pool = []
	
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades:
			if UpgradeDb.UPGRADES[i]["type"] != "endless":
				continue
		
		if i in upgrade_options:
			continue
			
		var type = _get_effective_type(i)
		if type != "bossitem":
			continue
			
		if UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0:
			var to_add = true
			for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
				if not n in collected_upgrades:
					to_add = false
			if to_add:
				if UpgradeDb.UPGRADES[i]["type"] == "endless":
					endless_pool.append(i)
				else:
					standard_pool.append(i)
		else:
			if UpgradeDb.UPGRADES[i]["type"] == "endless":
				endless_pool.append(i)
			else:
				standard_pool.append(i)
				
	var dblist = []
	if standard_pool.size() > 0:
		# Deprioritize endless items in boss pool as well
		if randf() < 0.20 and endless_pool.size() > 0:
			dblist = standard_pool + endless_pool
		else:
			dblist = standard_pool
	else:
		dblist = endless_pool
			
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null



#timer
func change_time(argtime = 0):
	time = argtime
	gui.update_timer(time)
	
	if loggingEnabled and time > 0 and time % 30 == 0 and time != last_logged_time:
		_log_minute_data()
		last_logged_time = time

func _log_minute_data():
	var _current_second = time
	var _xp_this_interval = total_collected_experience - last_minute_total_experience
	last_minute_total_experience = total_collected_experience

	



func death():
	if gui.deathPanel.visible:
		return
	emit_signal("playerdeath")
	get_tree().paused = true
	
	StatsManager.register_end_run(hasWon)
	StatsManager.update_best_run(experience_level, GlobalEvents.time)
	
	gui.show_death_panel(hasWon)
	
	MusicController.focusMusic(false)
	if hasWon:
		MusicController.setLooping(false)
		MusicController.playSpecificTrack(MusicController.winMusic)

func _on_boss_defeated():
	if not hasWon:
		hasWon = true
		StatsManager.save_stats()
	pending_boss_rewards += 1
	if not gui.levelPanel.visible and not gui.bossLevelPanel.visible:
		_show_next_reward()

func _on_enemy_died(pos: Vector2, enemy_max_hp: float, _killer: String):
	if willowisp_level > 0:
		var chance = 0.15
		if willowisp_level >= 2:
			chance = 0.20
		
		# Apply a low proc coefficient (0.1) for chain reactions
		if _killer == "willowisp":
			chance *= 0.1
		
		if randf() < chance:
			var explosion = willowisp_explosion_scene.instantiate()
			explosion.global_position = pos
			
			var dmg = 5.0
			match willowisp_level:
				1, 2: dmg = 5.0
				3: dmg = 8.0
				4: dmg = 10.0 + (enemy_max_hp * 0.05)
			
			explosion.damage = dmg
			explosion.level = willowisp_level
			get_parent().call_deferred("add_child", explosion)

func _on_player_dealt_damage(damage: float, _target: Object, proc_coefficient: float):
	if hp > 0 and lifesteal > 0.0:
		# Heal by percentage of damage dealt, scaled by proc coefficient
		var heal_amount = damage * lifesteal * proc_coefficient
		if heal_amount > 0:
			_set_hp(hp + heal_amount)


func _get_upgrade_base_name(uid: String) -> String:
	if uid.ends_with("_endless"):
		return uid.trim_suffix("_endless")
	return uid.rstrip("0123456789")

func _get_upgrade_tier(uid: String) -> int:
	if uid.ends_with("_endless"):
		return -1
	var base_name := _get_upgrade_base_name(uid)
	if uid.length() <= base_name.length():
		return 0
	return int(uid.right(uid.length() - base_name.length()))

func _get_highest_owned_tier(base_name: String) -> int:
	var max_lvl := 0
	for uid in collected_upgrades:
		if _get_upgrade_base_name(uid) == base_name:
			var lvl := _get_upgrade_tier(uid)
			if lvl > max_lvl:
				max_lvl = lvl
	return max_lvl

func _is_spawner_item(upgrade_id: String, upgrade_data: Dictionary) -> bool:
	var type: String = upgrade_data.get("type", "")
	var base_name := _get_upgrade_base_name(upgrade_id)
	var boss_weapons_with_spawner := ["glasslash", "vampireknives"]
	return type == "weapon" or (type == "bossitem" and boss_weapons_with_spawner.has(base_name)) or (base_name == "occult_medallion" and type != "endless")

func _sync_special_passive_levels() -> void:
	willowisp_level = _get_highest_owned_tier("willowisp")
	glass_talisman_level = _get_highest_owned_tier("glasstalisman")
	warding_brooch_level = _get_highest_owned_tier("wardingbrooch")
	frenzy_charm_level = _get_highest_owned_tier("frenzycharm")
	impact_buckler_level = _get_highest_owned_tier("impactbuckler")
	speed_tier = _get_highest_owned_tier("speed")
	scroll_tier = _get_highest_owned_tier("scroll")
	javelin_level = _get_highest_owned_tier("javelin")
	javelin_endless_level = collected_endless.get("javelin", 0)
	lightningrod_level = _get_highest_owned_tier("lightningrod")
	lightningrod_endless_level = collected_endless.get("lightningrod", 0)
	if warding_brooch_level <= 0:
		warding_brooch_charge = false
		warding_brooch_timer = 0.0
		warding_brooch_speed_timer = 0.0
	if impact_buckler_level <= 0:
		impact_buckler_cooldown = 0.0
	if frenzy_charm_level <= 0:
		frenzy_charm_active = false
	if glass_talisman_level <= 0:
		glass_talisman_damage_bonus = 0.0
		damage_multiplier = 1.0

func _rebuild_weapon_spawner(base_name: String) -> void:
	if weapons == null:
		return
	var existing := weapons.get_node_or_null(base_name)
	if existing:
		weapons.remove_child(existing)
		existing.queue_free()
	
	var tiers: Array[int] = []
	for uid in collected_upgrades:
		if _get_upgrade_base_name(uid) == base_name:
			var t := _get_upgrade_tier(uid)
			if t > 0 and not tiers.has(t):
				tiers.append(t)
	tiers.sort()
	
	if tiers.is_empty():
		if base_name == "javelin":
			javelin_level = 0
			javelin_endless_level = 0
		elif base_name == "lightningrod":
			lightningrod_level = 0
			lightningrod_endless_level = 0
		return
	
	var folder_name := base_name.to_lower()
	var spawner_script = load("res://Player/Attack/" + folder_name + "/" + folder_name + "_spawner.gd")
	if not spawner_script:
		return
	var new_spawner := Node2D.new()
	new_spawner.set_script(spawner_script)
	new_spawner.name = base_name
	weapons.add_child(new_spawner)
	for t in tiers:
		var tier_id := base_name + str(t)
		if UpgradeDb.UPGRADES.has(tier_id):
			new_spawner.upgrade(tier_id)
	var endless_stacks: int = collected_endless.get(base_name, 0)
	var endless_id := base_name + "_endless"
	for _i in range(endless_stacks):
		if UpgradeDb.UPGRADES.has(endless_id):
			new_spawner.upgrade(endless_id)

func _sync_gui_collection_after_change(base_name_check: String) -> void:
	if gui == null or not is_instance_valid(gui):
		return
	if gui.has_method("refresh_gui_collection"):
		gui.refresh_gui_collection()
		return
	if not ("collectedWeapons" in gui and "collectedUpgrades" in gui and "collectedBossItems" in gui):
		return
	var still_owned := false
	for uid in collected_upgrades:
		if _get_upgrade_base_name(uid) == base_name_check:
			still_owned = true
			break
	if not still_owned:
		for container in [gui.collectedWeapons, gui.collectedUpgrades, gui.collectedBossItems]:
			if container == null:
				continue
			for child in container.get_children():
				if child.get("upgrade") != null:
					if _get_upgrade_base_name(str(child.upgrade)) == base_name_check:
						child.queue_free()

func grant_upgrade_with_prereqs(upgrade_id: String) -> void:
	var upgrade_data = UpgradeDb.UPGRADES.get(upgrade_id)
	if upgrade_data == null:
		return
	var is_endless: bool = (upgrade_data.get("type", "") == "endless")
	if upgrade_id in collected_upgrades and not is_endless:
		return
	var prereqs: Array = upgrade_data.get("prerequisite", [])
	for p in prereqs:
		grant_upgrade_with_prereqs(p)
	upgrade_character(upgrade_id)

## Removes a single upgrade from the player's collected list.
## Handles weapons, passives, special items, companion drone, and endless stacks.
func remove_upgrade(upgrade_id: String) -> void:
	if not upgrade_id in collected_upgrades:
		return
	var upgrade_data = UpgradeDb.UPGRADES.get(upgrade_id)
	if upgrade_data == null:
		return
	
	var type: String = upgrade_data["type"]
	var base_name := _get_upgrade_base_name(upgrade_id)
	
	if type == "endless":
		var current_stacks: int = collected_endless.get(base_name, 0)
		if current_stacks > 1:
			collected_endless[base_name] = current_stacks - 1
		else:
			collected_endless.erase(base_name)
			collected_upgrades.erase(upgrade_id)
		if weapons != null and weapons.get_node_or_null(base_name) != null:
			_rebuild_weapon_spawner(base_name)
	else:
		collected_upgrades.erase(upgrade_id)
		if base_name == "relicdrone":
			var remaining_lvl := _get_highest_owned_tier("relicdrone")
			if remaining_lvl <= 0:
				if relic_drone_node and is_instance_valid(relic_drone_node):
					if relic_drone_node.get_parent() == self:
						remove_child(relic_drone_node)
					relic_drone_node.queue_free()
					relic_drone_node = null
			elif relic_drone_node and is_instance_valid(relic_drone_node):
				relic_drone_node.level = remaining_lvl
				relic_drone_node.update_stats()
		elif _is_spawner_item(upgrade_id, upgrade_data):
			if _get_highest_owned_tier(base_name) <= 0:
				collected_endless.erase(base_name)
				collected_upgrades.erase(base_name + "_endless")
			_rebuild_weapon_spawner(base_name)
		else:
			stat_modifiers.erase(upgrade_id)
			if _get_highest_owned_tier(base_name) <= 0:
				collected_endless.erase(base_name)
				collected_upgrades.erase(base_name + "_endless")
	
	_sync_special_passive_levels()
	apply_stat_modifiers()
	_sync_gui_collection_after_change(base_name)

## Removes all levels of the given base item above `keep_level`.
## Pass keep_level=0 to remove completely.
func remove_upgrade_to_level(base_name: String, keep_level: int) -> void:
	var max_tier := 0
	for uid in UpgradeDb.UPGRADES.keys():
		if _get_upgrade_base_name(uid) == base_name:
			var t := _get_upgrade_tier(uid)
			if t > max_tier:
				max_tier = t
	if keep_level < max_tier:
		set_endless_stacks(base_name, 0)
	
	var to_remove: Array[String] = []
	for uid in collected_upgrades:
		if _get_upgrade_base_name(uid) == base_name:
			var lvl := _get_upgrade_tier(uid)
			if lvl > keep_level:
				to_remove.append(uid)
	to_remove.sort()
	to_remove.reverse()
	for uid in to_remove:
		remove_upgrade(uid)

func set_item_tier(base_name: String, target_tier: int) -> void:
	var prev_suppress := suppress_upgrade_unpause
	suppress_upgrade_unpause = true
	var current_tier := _get_highest_owned_tier(base_name)
	if target_tier <= 0:
		remove_upgrade_to_level(base_name, 0)
	elif target_tier < current_tier:
		remove_upgrade_to_level(base_name, target_tier)
	elif target_tier > current_tier:
		var target_id := base_name + str(target_tier)
		if UpgradeDb.UPGRADES.has(target_id):
			grant_upgrade_with_prereqs(target_id)
	suppress_upgrade_unpause = prev_suppress

func set_endless_stacks(base_name: String, target_count: int) -> void:
	var clamped_count: int = max(0, target_count)
	var endless_id := base_name + "_endless"
	if not UpgradeDb.UPGRADES.has(endless_id):
		return
	var prev_suppress := suppress_upgrade_unpause
	suppress_upgrade_unpause = true
	var current_count: int = collected_endless.get(base_name, 0)
	if clamped_count > current_count:
		var prereqs: Array = UpgradeDb.UPGRADES[endless_id].get("prerequisite", [])
		for p in prereqs:
			grant_upgrade_with_prereqs(p)
		for _i in range(clamped_count - current_count):
			upgrade_character(endless_id)
	elif clamped_count < current_count:
		if clamped_count == 0:
			collected_endless.erase(base_name)
			collected_upgrades.erase(endless_id)
		else:
			collected_endless[base_name] = clamped_count
		if weapons != null and weapons.get_node_or_null(base_name) != null:
			_rebuild_weapon_spawner(base_name)
		_sync_special_passive_levels()
		apply_stat_modifiers()
		_sync_gui_collection_after_change(base_name)
	suppress_upgrade_unpause = prev_suppress

func reset_all_upgrades() -> void:
	var prev_suppress := suppress_upgrade_unpause
	suppress_upgrade_unpause = true
	var bases: Array[String] = []
	for uid in collected_upgrades:
		var b := _get_upgrade_base_name(uid)
		if not bases.has(b):
			bases.append(b)
	for b in bases:
		remove_upgrade_to_level(b, 0)
	collected_upgrades.clear()
	collected_endless.clear()
	stat_modifiers.clear()
	_sync_special_passive_levels()
	apply_stat_modifiers()
	if gui != null and is_instance_valid(gui) and gui.has_method("refresh_gui_collection"):
		gui.refresh_gui_collection()
	suppress_upgrade_unpause = prev_suppress

func switch_character_mid_run(char_id: String, grant_starter: bool = true) -> void:
	if not GlobalEvents.CHARACTERS.has(char_id):
		return
	_cancel_active_mobility()
	GlobalEvents.selected_character = char_id
	var char_data: Dictionary = GlobalEvents.CHARACTERS[char_id]
	mobility_type = str(char_data.get("mobility_type", "sidestep"))
	var prev_ratio := float(hp) / float(maxhp) if maxhp > 0 else 1.0
	base_maxhp = char_data.get("base_stats", {}).get("maxhp", 80)
	
	if sprite != null:
		if char_data.has("icon"):
			var tex = load(char_data["icon"])
			if tex:
				sprite.texture = tex
		if char_data.has("icon_color"):
			var mat := sprite.material as ShaderMaterial
			if mat:
				var col: Color = char_data["icon_color"]
				mat.set_shader_parameter("target_color", col)
				mat.set_shader_parameter("mix_hue", true)
				mat.set_shader_parameter("mix_saturation", false)
				mat.set_shader_parameter("mix_value", false)
				if col.r > 0.99 and col.g > 0.99 and col.b > 0.99:
					mat.set_shader_parameter("mix_hue", false)
				if char_data.has("shader_config"):
					var config: Dictionary = char_data["shader_config"]
					for key in config:
						mat.set_shader_parameter(key, config[key])
			sprite.self_modulate = Color.WHITE
	
	if grant_starter and char_data.get("starting_weapon", "") != "":
		var prev_suppress := suppress_upgrade_unpause
		suppress_upgrade_unpause = true
		grant_upgrade_with_prereqs(char_data["starting_weapon"])
		suppress_upgrade_unpause = prev_suppress
	
	apply_stat_modifiers()
	_set_hp(max(1.0, prev_ratio * float(maxhp)))

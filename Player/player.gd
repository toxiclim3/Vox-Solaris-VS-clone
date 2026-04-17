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
@export var base_movement_speed = 75.0
var movement_speed = 75.0
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
var relic_drone_node = null
var joystick_vector := Vector2.ZERO

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

func _ready():
	var active_char = GlobalEvents.selected_character
	if active_char != "" and GlobalEvents.CHARACTERS.has(active_char):
		var char_data = GlobalEvents.CHARACTERS[active_char]
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
	_on_hurt_box_hurt(0,0,0)
	GlobalEvents.enemy_died.connect(_on_enemy_died)
	GlobalEvents.boss_defeated.connect(_on_boss_defeated)
	GlobalEvents.player_dealt_damage.connect(_on_player_dealt_damage)
	
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

func _physics_process(_delta):
	movement()

func movement():
	var mov = Vector2.ZERO
	if SettingsManager.mouse_control:
		var target_pos = get_global_mouse_position()
		var diff = target_pos - global_position
		if diff.length() > 15 and not Input.is_action_pressed("click"): # Stop if close to player or holding LMB
			mov = diff.normalized()
	else:
		var x_mov = Input.get_action_strength("right") - Input.get_action_strength("left")
		var y_mov = Input.get_action_strength("down") - Input.get_action_strength("up")
		mov = Vector2(x_mov,y_mov)
		
		# Overlay joystick movement if no keyboard input is present
		if mov == Vector2.ZERO and joystick_vector != Vector2.ZERO:
			mov = joystick_vector

	if mov.x > 0:
		sprite.flip_h = true
	elif mov.x < 0:
		sprite.flip_h = false

	if mov != Vector2.ZERO:
		last_movement = mov
		if walkTimer.is_stopped():
			if sprite.frame >= sprite.hframes - 1:
				sprite.frame = 0
			else:
				sprite.frame += 1
			walkTimer.start()
	
	velocity = mov.normalized()*movement_speed
	move_and_slide()

func attack():
	for weapon in weapons.get_children():
		if weapon.has_method("attack"):
			weapon.attack()

func _on_regen_timer_timeout(): #regens regenPerSecond percent of maxHp every regenTimer timeout
	if hp < maxhp:
		var actual_regen = regenPerSecond * GlobalEvents.get_player_regen_modifier()
		hp = clamp(hp + actual_regen*maxhp, 0, maxhp)	
		healthBar.max_value = maxhp
		healthBar.value = hp
		
		if (hp >= (maxhp * hurtBadThreshold)) and hurtBadTriggered:
			hurtBadTriggered = false



func _on_hurt_box_hurt(damage, _angle, _knockback, _killer_source = "", attacker_node = null, _proc_coefficient = 1.0):
	if damage > 0:
		GlobalEvents.player_took_damage.emit(damage, attacker_node)
		
		# Reflection logic (Thorn Ring)
		if reflected_damage > 0 and attacker_node and attacker_node.has_method("_on_hurt_box_hurt"):
			attacker_node._on_hurt_box_hurt(reflected_damage, Vector2.ZERO, 0, "Thorn Ring", self)

	if godmode == false:
		# Armor rework: Percentage reduction with diminishing returns (DR = Armor / (Armor + 40))
		var dr = float(armor) / (armor + 40.0)
		var actual_damage = damage * (1.0 - dr)
		
		# Ensure we don't heal from damage, and at least 0.1 damage is taken if hit (optional, keeping it simple for now)
		actual_damage = clamp(actual_damage, 0.0, 999.0)
		
		if actual_damage > 0:

			if (hp >= (maxhp * hurtBadThreshold)) or hurtBadTriggered:
				sndHurt.play()
				GlobalEvents.camera_shake.emit(2.0, 0.2)
			else:
				sndHurtBad.play()
				hurtBadTriggered = true
				GlobalEvents.camera_shake.emit(3.0, 0.5)
		hp -= actual_damage
	healthBar.max_value = maxhp
	healthBar.value = hp
	if hp <= 0:
		death()

# Attacks are now managed by dynamic spawners


#enemy related logic
func get_random_target():
	var targets = []
	for body in enemy_close:
		if is_instance_valid(body):
			targets.append(body.global_position)
	
	var swarm = get_tree().get_first_node_in_group("swarm_manager")
	if swarm:
		for enemy in swarm.swarm_data:
			if not enemy.is_dead and enemy.position.distance_squared_to(global_position) < 160000: # approx 400px radius
				targets.append(enemy.position)
				
	if targets.size() > 0:
		return targets.pick_random()
	else:
		return Vector2.INF

func get_closest_target():
	var closest_pos = Vector2.INF
	var min_dist = INF
	
	for body in enemy_close:
		if is_instance_valid(body):
			var dist = global_position.distance_squared_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_pos = body.global_position
				
	var swarm = get_tree().get_first_node_in_group("swarm_manager")
	if swarm:
		for enemy in swarm.swarm_data:
			if not enemy.is_dead:
				var dist = global_position.distance_squared_to(enemy.position)
				if dist < min_dist and dist < 160000:
					min_dist = dist
					closest_pos = enemy.position
					
	return closest_pos


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

	
	# Apply movement speed percent bonus
	movement_speed = base_movement_speed * (1.0 + movement_speed_percent_total)
	
	# Apply armor multiplier
	armor = int(armor * (1.0 + armor_multiplier))
	
	# Apply max HP percent bonus on top of base
	var new_maxhp = int(base_maxhp * (1.0 + max_hp_percent_total))
	if new_maxhp != maxhp:
		var ratio = float(hp) / float(maxhp)
		maxhp = new_maxhp
		hp = clamp(int(ratio * maxhp), 1, maxhp)
		healthBar.max_value = maxhp
		healthBar.value = hp
	
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
	elif type == "weapon" or (type == "bossitem" and boss_weapons_with_spawner.has(upgrade.rstrip("0123456789"))):
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
		if upgrade_data.has("stat_modifiers"):
			if type == "item" and upgrade == "food":
				hp += upgrade_data["stat_modifiers"]["hp"]
				hp = clamp(hp, 0, maxhp)
				healthBar.value = hp
			else:
				stat_modifiers[upgrade] = upgrade_data["stat_modifiers"]
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
	var dblist = []
	
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
				dblist.append(i)
		else:
			# This is a new item (level 1)
			if type == "weapon" and unique_weapons.size() >= max_weapon_slots:
				continue
			if type == "upgrade" and unique_upgrades.size() >= max_upgrade_slots:
				continue
				
			dblist.append(i)

			
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null


func get_random_boss_item():
	var dblist = []
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
				dblist.append(i)
		else:
			dblist.append(i)
			
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
	var current_second = time
	var xp_this_interval = total_collected_experience - last_minute_total_experience
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
	hasWon = true
	pending_boss_rewards += 1
	if not gui.levelPanel.visible and not gui.bossLevelPanel.visible:
		_show_next_reward()

func _on_enemy_died(_pos: Vector2, _enemy_max_hp: float, _killer: String):
	pass

func _on_player_dealt_damage(damage: float, _target: Object, proc_coefficient: float):
	if hp > 0 and lifesteal > 0.0:
		# Heal by percentage of damage dealt, scaled by proc coefficient
		var heal_amount = damage * lifesteal * proc_coefficient
		hp = clamp(hp + heal_amount, 0, maxhp)
		healthBar.value = hp


#Debug buttons
func _on_btn_give_xp_click_end() -> void:
	calculate_experience(100)
	
func _on_btn_give_level_click_end() -> void:
	var xpToGive = calculate_experiencecap()-experience
	calculate_experience(xpToGive)

func grant_upgrade_with_prereqs(upgrade_id: String):
	if upgrade_id in collected_upgrades:
		return
	var prereqs = UpgradeDb.UPGRADES[upgrade_id].get("prerequisite", [])
	for p in prereqs:
		grant_upgrade_with_prereqs(p)
	upgrade_character(upgrade_id)

## Removes a single upgrade from the player's collected list.
## For weapons: downgrades or removes the weapon spawner.
## For upgrades: removes the stat modifier.
func remove_upgrade(upgrade_id: String) -> void:
	if not upgrade_id in collected_upgrades:
		return
	var upgrade_data = UpgradeDb.UPGRADES.get(upgrade_id)
	if upgrade_data == null:
		return

	collected_upgrades.erase(upgrade_id)

	var type = upgrade_data["type"]
	var boss_weapons_with_spawner = ["glasslash", "vampireknives"]
	if type == "weapon" or (type == "bossitem" and boss_weapons_with_spawner.has(upgrade_id.rstrip("0123456789"))):
		var base_name = upgrade_id.rstrip("0123456789")
		var weapon_spawner = weapons.get_node_or_null(base_name)
		# Check if there is still a collected level for this weapon
		var remaining_level = ""
		var max_lvl = 0
		for uid in collected_upgrades:
			if uid.rstrip("0123456789") == base_name:
				var lvl = int(uid.right(uid.length() - base_name.length()))
				if lvl > max_lvl:
					max_lvl = lvl
					remaining_level = uid
		if remaining_level == "" and weapon_spawner:
			# No levels left — remove the spawner entirely
			weapon_spawner.queue_free()
		elif remaining_level != "" and weapon_spawner and weapon_spawner.has_method("upgrade"):
			# Downgrade the spawner to the remaining highest level
			weapon_spawner.upgrade(remaining_level)
	elif type == "upgrade":
		stat_modifiers.erase(upgrade_id)
		apply_stat_modifiers()

	# Update GUI collection (remove icon if no levels owned)
	var base_name_check = upgrade_id.rstrip("0123456789")
	var still_owned = false
	for uid in collected_upgrades:
		if uid.rstrip("0123456789") == base_name_check:
			still_owned = true
			break
	if not still_owned:
		# Remove from collectedWeapons or collectedUpgrades display
		for container in [gui.collectedWeapons, gui.collectedUpgrades, gui.collectedBossItems]:
			for child in container.get_children():
				if child.get("upgrade") != null:
					var child_base = child.upgrade.rstrip("0123456789")
					if child_base == base_name_check:
						child.queue_free()

## Removes all levels of the given base item above `keep_level`.
## Pass keep_level=0 to remove completely.
func remove_upgrade_to_level(base_name: String, keep_level: int) -> void:
	# Collect which upgrade IDs to remove (all levels > keep_level for this base)
	var to_remove: Array = []
	for uid in collected_upgrades:
		if uid.rstrip("0123456789") == base_name:
			var lvl = int(uid.right(uid.length() - base_name.length()))
			if lvl > keep_level:
				to_remove.append(uid)
	# Remove highest levels first so the weapon spawner stays valid
	to_remove.sort()
	to_remove.reverse()
	for uid in to_remove:
		remove_upgrade(uid)

func _on_btn_kill_player_click_end() -> void:
	death()

func _on_btn_damage_player_click_end() -> void:
	_on_hurt_box_hurt(10,0,0)

func _on_btn_toggle_godmode_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		godmode = true
	if toggled_on == false:
		godmode = false

func _on_btn_toggle_spawns_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		GlobalEvents.disableSpawns.emit()
	if toggled_on == false:
		GlobalEvents.enableSpawns.emit()

func _on_btn_next_normal_track_click_end() -> void:
	MusicController.playNext(MusicController.MusicType.NORMAL)

func _on_btn_next_boss_track_click_end() -> void:
	MusicController.playNext(MusicController.MusicType.BOSS)

func _on_btn_pause_music_click_end() -> void:
	MusicController.toggleMusic(false)

func _on_btn_unpause_music_click_end() -> void:
	MusicController.toggleMusic(true)

func _on_btn_timer_1m_click_end() -> void:
	GlobalEvents.time += 60

func _on_btn_timer_5m_click_end() -> void:
	GlobalEvents.time += 60 * 5

func _on_btn_exit_game_click_end() -> void:
	get_tree().quit()
	
func _on_btn_end_run_click_end() -> void:
	var _level = get_tree().change_scene_to_file(titleMenu)

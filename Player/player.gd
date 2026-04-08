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

var experience = 0
var experience_level = 1
var collected_experience = 0

@export var hurtBadThreshold = 0.20
var hurtBadTriggered = false

var titleMenu = "res://TitleScreen/menu.tscn"

#Attacks removed as they are dynamic now

#UPGRADES
var collected_upgrades = []
var upgrade_options = []
var pending_levelups = 0  # Queue of level-ups waiting to be shown
var pending_boss_rewards = 0 # Queue of boss rewards waiting to be shown

# Base Stats
var base_armor = 0
var armor = 0
@export var base_movement_speed = 75.0
var movement_speed = 75.0
var base_spell_cooldown = 0.0
var spell_cooldown = 0.0
var base_spell_size = 0.0
var spell_size = 0.0
var base_additional_attacks = 0
var additional_attacks = 0

# XP gem grab range
const BASE_GRAB_RADIUS = 50.0

# Track Stat Modifiers
var stat_modifiers = {}

# Javelin level tracked for global updates to Javelins
var javelin_level = 0

#Enemy Related
var enemy_close = []

@onready var sprite = $Sprite2D
@onready var walkTimer = get_node("%walkTimer")
@onready var regen_timer = get_node("%regenTimer")
@onready var grab_shape = get_node("GrabArea/CollisionShape2D")

@onready var weapons = get_node("%Weapons") # Dynamic weapons container

#GUI
@onready var gui = get_node("GUILayer/GUI")
@onready var healthBar = get_node("%HealthBar")
@onready var sndHurt = get_node("%snd_hurt")
@onready var sndHurtBad = get_node("%snd_hurt_bad")

@onready var pauseMenu = get_node("GUILayer/GUI/PauseMenu")
@onready var debugMenu = get_node("GUILayer/GUI/DebugMenu")

#Signal
signal playerdeath

func _ready():
	match GlobalEvents.playerItem:
		0:
			pass
		1:
			upgrade_character("icespear1")
		2:
			upgrade_character("javelin1")
		3: 
			upgrade_character("tornado1")
	attack()
	gui.set_expbar(experience, calculate_experiencecap())
	gui.set_level_text(experience_level)
	_on_hurt_box_hurt(0,0,0)
	GlobalEvents.boss_defeated.connect(_on_boss_defeated)
	

func _physics_process(_delta):
	movement()

func movement():
	var mov = Vector2.ZERO
	if SettingsManager.mouse_control:
		var target_pos = get_global_mouse_position()
		var diff = target_pos - global_position
		if diff.length() > 6: # Deadzone to prevent jitter
			mov = diff.normalized()
	else:
		var x_mov = Input.get_action_strength("right") - Input.get_action_strength("left")
		var y_mov = Input.get_action_strength("down") - Input.get_action_strength("up")
		mov = Vector2(x_mov,y_mov)

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



func _on_hurt_box_hurt(damage, _angle, _knockback):
	if godmode == false:
		var actual_damage = clamp(damage-armor, 0.0, 999.0)
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
	if enemy_close.size() > 0:
		return enemy_close.pick_random().global_position
	else:
		return Vector2.INF

func get_closest_target():
	if enemy_close.size() > 0:
		var closest = enemy_close[0]
		var min_dist = global_position.distance_squared_to(closest.global_position)
		for enemy in enemy_close:
			var dist = global_position.distance_squared_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
		return closest.global_position
	else:
		return Vector2.INF


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
	collected_experience += (gem_exp * GlobalEvents.get_xp_gain_modifier())
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
	gui.set_expbar(experience, calculate_experiencecap())

func calculate_experiencecap():
	var exp_cap = experience_level
	if experience_level < 20:
		exp_cap = experience_level*5
	elif experience_level < 40:
		exp_cap += 95 * (experience_level-19)*8
	else:
		exp_cap = 255 + (experience_level-39)*12
		
	return exp_cap
		


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
		options += 1
		
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
	
	for mod in stat_modifiers.values():
		for stat_name in mod.keys():
			match stat_name:
				"armor": armor += mod[stat_name]
				"movement_speed_percent": movement_speed_percent_total += mod[stat_name]
				"spell_cooldown": spell_cooldown += mod[stat_name]
				"spell_size": spell_size += mod[stat_name]
				"additional_attacks": additional_attacks += mod[stat_name]
				"max_hp_percent": max_hp_percent_total += mod[stat_name]
				"regen": regenPerSecond = mod[stat_name]
				"xp_range_percent": xp_range_percent_total += mod[stat_name]
	
	# Apply movement speed percent bonus
	movement_speed = base_movement_speed * (1.0 + movement_speed_percent_total)
	
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
	if type == "weapon" or (type == "bossitem" and upgrade.begins_with("glasslash")):
		var base_name = upgrade.rstrip("0123456789")
		var folder_name = base_name.capitalize()
		var file_name = base_name
		
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
			
	elif type == "upgrade" or type == "item":
		if upgrade_data.has("stat_modifiers"):
			if type == "item" and upgrade == "food":
				hp += upgrade_data["stat_modifiers"]["hp"]
				hp = clamp(hp, 0, maxhp)
			else:
				stat_modifiers[upgrade] = upgrade_data["stat_modifiers"]
				apply_stat_modifiers()
				
	gui.adjust_gui_collection(upgrade)
	attack()
	upgrade_options.clear()
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
	
func get_random_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades: #Find already collected upgrades
			pass
		elif i in upgrade_options: #If the upgrade is already an option
			pass
		elif UpgradeDb.UPGRADES[i]["type"] == "item" or UpgradeDb.UPGRADES[i]["type"] == "bossitem": #Don't pick food or boss items
			pass
		elif UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0: #Check for PreRequisites
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

func get_random_boss_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades:
			pass
		elif i in upgrade_options:
			pass
		elif UpgradeDb.UPGRADES[i]["type"] != "bossitem":
			pass
		elif UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0:
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
	if type == "weapon":
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

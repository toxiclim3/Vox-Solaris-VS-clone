extends CharacterBody2D

var hp = 80
var maxhp = 80
var regenPerSecond = 0.5 / 100 #regen percent of max hp, by default 0.5%
var last_movement = Vector2.UP
var time = 0
var godmode = false

var experience = 0
var experience_level = 1
var collected_experience = 0

var titleMenu = "res://TitleScreen/menu.tscn"

#Attacks removed as they are dynamic now

#UPGRADES
var collected_upgrades = []
var upgrade_options = []

# Base Stats
var base_armor = 0
var armor = 0
var base_movement_speed = 50.0
var movement_speed = 50.0
var base_spell_cooldown = 0.0
var spell_cooldown = 0.0
var base_spell_size = 0.0
var spell_size = 0.0
var base_additional_attacks = 0
var additional_attacks = 0

# Track Stat Modifiers
var stat_modifiers = {}

# Javelin level tracked for global updates to Javelins
var javelin_level = 0

#Enemy Related
var enemy_close = []

@onready var sprite = $Sprite2D
@onready var walkTimer = get_node("%walkTimer")
@onready var regen_timer = get_node("%regenTimer")

@onready var weapons = get_node("%Weapons") # Dynamic weapons container

#GUI
@onready var expBar = get_node("%ExperienceBar")
@onready var lblLevel = get_node("%lbl_level")
@onready var levelPanel = get_node("%LevelUp")
@onready var upgradeOptions = get_node("%UpgradeOptions")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var healthBar = get_node("%HealthBar")
@onready var lblTimer = get_node("%lblTimer")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var itemContainer = preload("res://Player/GUI/item_container.tscn")

@onready var deathPanel = get_node("%DeathPanel")
@onready var lblResult = get_node("%lbl_Result")
@onready var sndVictory = get_node("%snd_victory")
@onready var sndLose = get_node("%snd_lose")
@onready var sndHurt = get_node("%snd_hurt")
@onready var sndHurtBad = get_node("%snd_hurt_bad")

@onready var pauseMenu = get_node("GUILayer/GUI/PauseMenu")
@onready var debugMenu = get_node("GUILayer/GUI/DebugMenu")

#Signal
signal playerdeath

func _ready():
	upgrade_character("icespear1")
	attack()
	set_expbar(experience, calculate_experiencecap())
	lblLevel.text = str(tr("ui_level"),experience_level)
	_on_hurt_box_hurt(0,0,0)
	

func _physics_process(_delta):
	movement()

func movement():
	var x_mov = Input.get_action_strength("right") - Input.get_action_strength("left")
	var y_mov = Input.get_action_strength("down") - Input.get_action_strength("up")
	var mov = Vector2(x_mov,y_mov)
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
		hp = clamp(hp + regenPerSecond*maxhp, 0, maxhp)	
		healthBar.max_value = maxhp
		healthBar.value = hp

func _on_hurt_box_hurt(damage, _angle, _knockback):
	if godmode == false:
		var actual_damage = clamp(damage-armor, 0.0, 999.0)
		if actual_damage > 0:
			if hp >= (maxhp * 0.15):
				sndHurt.play()
			else:
				sndHurtBad.play()
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
		return Vector2.UP


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
	var exp_required = calculate_experiencecap()
	collected_experience += gem_exp
	if experience + collected_experience >= exp_required: #level up
		collected_experience -= exp_required-experience
		experience_level += 1
		experience = 0
		exp_required = calculate_experiencecap()
		levelup()
	else:
		experience += collected_experience
		collected_experience = 0
	
	set_expbar(experience, exp_required)

func calculate_experiencecap():
	var exp_cap = experience_level
	if experience_level < 20:
		exp_cap = experience_level*5
	elif experience_level < 40:
		exp_cap += 95 * (experience_level-19)*8
	else:
		exp_cap = 255 + (experience_level-39)*12
		
	return exp_cap
		
func set_expbar(set_value = 1, set_max_value = 100):
	expBar.value = set_value
	expBar.max_value = set_max_value

func levelup():
	sndLevelUp.play()
	lblLevel.text = str(tr("ui_level"),experience_level)
	if experience_level % GlobalEvents.backgroundInterval == 0:
		GlobalEvents.advanceBackground.emit()
	
	var tween = levelPanel.create_tween()
	tween.tween_property(levelPanel,"position",Vector2(220,50),0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.play()
	levelPanel.visible = true
	var options = 0
	var optionsmax = 3
	while options < optionsmax:
		var option_choice = itemOptions.instantiate()
		option_choice.item = get_random_item()
		upgradeOptions.add_child(option_choice)
		options += 1
	get_tree().paused = true
	MusicController.focusMusic(!levelPanel.visible)
	# Wait one frame for layout to compute sizes, then equalize all box widths
	await get_tree().process_frame
	_equalize_upgrade_option_widths()

func _equalize_upgrade_option_widths():
	var children = upgradeOptions.get_children()
	var max_width: float = 0.0
	for child in children:
		max_width = max(max_width, child.get_combined_minimum_size().x)
	for child in children:
		child.custom_minimum_size.x = max_width

func apply_stat_modifiers():
	armor = base_armor
	movement_speed = base_movement_speed
	spell_cooldown = base_spell_cooldown
	spell_size = base_spell_size
	additional_attacks = base_additional_attacks
	
	for mod in stat_modifiers.values():
		for stat_name in mod.keys():
			match stat_name:
				"armor": armor += mod[stat_name]
				"movement_speed": movement_speed += mod[stat_name]
				"spell_cooldown": spell_cooldown += mod[stat_name]
				"spell_size": spell_size += mod[stat_name]
				"additional_attacks": additional_attacks += mod[stat_name]
	
	attack()

func upgrade_character(upgrade):
	var upgrade_data = UpgradeDb.UPGRADES.get(upgrade)
	if upgrade_data == null: return
	
	var type = upgrade_data["type"]
	
	if type == "weapon":
		var base_name = upgrade.rstrip("0123456789")
		var folder_name = base_name.capitalize()
		var file_name = base_name
		if base_name == "icespear": 
			folder_name = "IceSpear"
			file_name = "ice_spear"
		
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
				
	adjust_gui_collection(upgrade)
	attack()
	var option_children = upgradeOptions.get_children()
	for i in option_children:
		i.queue_free()
	upgrade_options.clear()
	collected_upgrades.append(upgrade)
	levelPanel.visible = false
	levelPanel.position = Vector2(800,50)
	get_tree().paused = false
	calculate_experience(0)
	MusicController.focusMusic(!levelPanel.visible)	
	if experience_level % GlobalEvents.musicInterval == 0:
		MusicController.playNext(MusicController.MusicType.NORMAL)	
	
func get_random_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades: #Find already collected upgrades
			pass
		elif i in upgrade_options: #If the upgrade is already an option
			pass
		elif UpgradeDb.UPGRADES[i]["type"] == "item": #Don't pick food
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

#timer
func change_time(argtime = 0):
	time = argtime
	var get_m = int(time/60.0)
	var get_s = time % 60
	if get_m < 10:
		get_m = str(0,get_m)
	if get_s < 10:
		get_s = str(0,get_s)
	lblTimer.text = str(get_m,":",get_s)
	
	

func adjust_gui_collection(upgrade):
	var get_upgraded_displayname = UpgradeDb.UPGRADES[upgrade]["displayname"]
	var get_type = UpgradeDb.UPGRADES[upgrade]["type"]
	if get_type != "item":
		var get_collected_displaynames = []
		for i in collected_upgrades:
			get_collected_displaynames.append(UpgradeDb.UPGRADES[i]["displayname"])
		if not get_upgraded_displayname in get_collected_displaynames:
			var new_item = itemContainer.instantiate()
			new_item.upgrade = upgrade
			match get_type:
				"weapon":
					collectedWeapons.add_child(new_item)
				"upgrade":
					collectedUpgrades.add_child(new_item)

func death():
	deathPanel.visible = true
	emit_signal("playerdeath")
	get_tree().paused = true
	var tween = deathPanel.create_tween()
	tween.tween_property(deathPanel,"position",Vector2(220,50),3.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	MusicController.focusMusic(false)
	if time >= 300:
		lblResult.text = tr("result_win")
		sndVictory.play()
		MusicController.setLooping(false)
		MusicController.playSpecificTrack(MusicController.winMusic)
	else:
		lblResult.text = tr("result_lose")
		sndLose.play()


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

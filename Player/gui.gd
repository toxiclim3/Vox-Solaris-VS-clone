extends Control

var titleMenu = "res://TitleScreen/menu.tscn"

@onready var settings_menu = get_node("%SettingsMenu")
@onready var pause_menu = get_node("%PauseMenu")
@onready var debug_menu = get_node("%DebugMenu")
@onready var levelup_menu = get_node("%LevelUp")

@onready var giveItemMenu = get_node("%GiveItemMenu")
@onready var giveItemMainGrid = get_node("GiveItemMenu/ScrollContainer/VBoxContainer/MainGrid")
@onready var giveItemSubGrid = get_node("GiveItemMenu/ScrollContainer/VBoxContainer/SubGrid")
@onready var player = get_tree().get_first_node_in_group("player")

@onready var removeItemMenu = get_node("RemoveItemMenu")
@onready var removeItemMainGrid = get_node("RemoveItemMenu/ScrollContainer/VBoxContainer/MainGrid")
@onready var removeItemSubGrid = get_node("RemoveItemMenu/ScrollContainer/VBoxContainer/SubGrid")

@onready var expBar = get_node("%ExperienceBar")
@onready var lblLevel = get_node("%lbl_level")
@onready var lblTimer = get_node("%lblTimer")
@onready var levelPanel = get_node("%LevelUp")
@onready var upgradeOptions = get_node("%UpgradeOptions")
@onready var upgradeScroll = get_node("%UpgradeScroll")
@onready var bossLevelPanel = get_node("%BossLevelUp")
@onready var bossUpgradeOptions = get_node("%BossUpgradeOptions")
@onready var bossUpgradeScroll = get_node("%BossUpgradeScroll")
@onready var deathPanel = get_node("%DeathPanel")
@onready var lblResult = get_node("%lbl_Result")
@onready var sndVictory = get_node("%snd_victory")
@onready var sndLose = get_node("%snd_lose")
@onready var btnRestart = get_node("%btn_restart")
@onready var btnMenu = get_node("%btn_menu")
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var btnResume = get_node("PauseMenu/MarginContainer/PanelContainer/VBoxContainer2/VBoxContainer/btn_resume_run")
@onready var btnSettings = get_node("PauseMenu/MarginContainer/PanelContainer/VBoxContainer2/VBoxContainer/btn_settings")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var collectedBossItems = get_node("%CollectedBossItems")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var itemContainer = preload("res://Player/GUI/item_container.tscn")
@onready var lblTips = get_node("%lblTips")
@onready var btnPauseMobile = get_node_or_null("%btn_pause_mobile")

var tip_timer = 0.0
const TIP_ROTATION_TIME = 10.0
var tip_keys = [
	"tips_runInCircles",
	"tips_armor",
	"tips_movement",
	"tips_focus",
	"tips_bosses",
	"tips_redgems",
	"tips_xporb",
	"tips_cooldown",
	"tips_size",
	"tips_wincon",
	"tips_poisonbottle",
	"tips_ritualcircle",
	"tips_icespear_pierce",
	"tips_amoeba_boss",
	"tips_surrounded_graze",
	"tips_vibecoded",
	"tips_ror_promo",
	"tips_try_terraria",
	"tips_try_minecraft",
	"tips_try_mamasboy",
	"tips_box_sleep",
	"tips_green_person",
	"tips_inspiration",
	"tips_swag"
]

var _last_tip_key: String = ""

func set_level_text(level: int) -> void:
	lblLevel.text = str(tr("ui_level"), level)

func set_expbar(current: float, maximum: float) -> void:
	expBar.value = current
	expBar.max_value = maximum

func update_timer(time_seconds: int) -> void:
	var get_m = int(time_seconds/60.0)
	var get_s = time_seconds % 60
	var str_m = str(get_m)
	var str_s = str(get_s)
	if get_m < 10:
		str_m = "0" + str_m
	if get_s < 10:
		str_s = "0" + str_s
	lblTimer.text = str_m + ":" + str_s

func adjust_gui_collection(upgrade: String) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		
	if not player: 
		# This can happen during early initialization when upgrading characters. 
		# If the player is still Nil, we should wait until it registers in the group.
		return
		
	var get_upgraded_displayname = UpgradeDb.UPGRADES[upgrade]["displayname"]
	var get_type = UpgradeDb.UPGRADES[upgrade]["type"]
	if get_type != "item":
		var get_collected_displaynames = []
		for i in player.collected_upgrades:
			get_collected_displaynames.append(UpgradeDb.UPGRADES[i]["displayname"])
		if not get_upgraded_displayname in get_collected_displaynames:
			var new_item = itemContainer.instantiate()
			new_item.upgrade = upgrade
			match get_type:
				"weapon":
					collectedWeapons.add_child(new_item)
				"upgrade":
					collectedUpgrades.add_child(new_item)
				"bossitem":
					collectedBossItems.add_child(new_item)

func show_death_panel(hasWon: bool) -> void:
	if deathPanel.visible:
		return
	deathPanel.visible = true
	if btnPauseMobile:
		btnPauseMobile.visible = false
	var is_mobile = OS.get_name() in ["Android", "iOS"]
	var vp_size = get_viewport_rect().size
	var target_pos: Vector2
	
	if is_mobile:
		target_pos = Vector2.ZERO # Full rect anchors mean (0,0) is centered fill
	else:
		target_pos = (vp_size - deathPanel.size) / 2.0
		
	var start_pos = Vector2(target_pos.x, -deathPanel.size.y)
	deathPanel.position = start_pos
	var tween = deathPanel.create_tween()
	tween.tween_property(deathPanel, "position", target_pos, 3.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	if hasWon:
		lblResult.text = tr("result_win")
		sndVictory.play()
	else:
		lblResult.text = tr("result_lose")
		sndLose.play()

func hide_level_panels() -> void:
	levelPanel.visible = false
	bossLevelPanel.visible = false

func show_levelup(options_list: Array, current_visual_level: int) -> void:
	sndLevelUp.play()
	set_level_text(current_visual_level)
	for child in upgradeOptions.get_children():
		upgradeOptions.remove_child(child)
		child.queue_free()
	
	levelPanel.visible = true
	for item in options_list:
		var option_choice = itemOptions.instantiate()
		option_choice.item = item
		upgradeOptions.add_child(option_choice)
	# Native Godot UI layout will now automatically handle width and full-screen margins!

func show_boss_levelup(options_list: Array) -> void:
	sndLevelUp.play()
	for child in bossUpgradeOptions.get_children():
		bossUpgradeOptions.remove_child(child)
		child.queue_free()
		
	bossLevelPanel.visible = true
	for item in options_list:
		var option_choice = itemOptions.instantiate()
		option_choice.item = item
		bossUpgradeOptions.add_child(option_choice)
	# Native Godot UI layout will now automatically handle width and full-screen margins!

@export var transition_duration: float = 0.4
@export var gap: float = 0.5 * 8 * 8 # Расстояние между окнами

var pause_idle_x: float # Позиция паузы, когда она одна в центре
var settings_idle_x: float # Позиция настроек, когда они открыты

signal openMenu()
signal closeMenu()

# Запоминаем изначальный центр для возврата
var pause_original_x: float
var pause_hidden_x: float
var is_menu_open: bool = false
var pause_tween: Tween



func _ready() -> void:
	# Initial Scale
	apply_gui_scale(SettingsManager.gui_scale)
	
	# Mobile Pause & Visibility
	var is_mobile = OS.get_name() in ["Android", "iOS"]
	
	if is_mobile:
		_apply_mobile_layout_overrides()
	
	if btnPauseMobile:
		btnPauseMobile.visible = is_mobile
		btnPauseMobile.pressed.connect(toggle_menu)
	
	# Connect Death Panel buttons
	if btnRestart:
		btnRestart.click_end.connect(_on_btn_restart_click_end)
	if btnMenu:
		btnMenu.click_end.connect(_on_btn_menu_click_end)
	
	var mobile_joy = get_node_or_null("%VirtualJoystick")
	if mobile_joy:
		mobile_joy.visible = false # Managed by touch

	# Defer positioning until scaling and anchors have settled
	call_deferred("_initialize_pause_menu_position")
	
	# Handle window resizing
	get_viewport().size_changed.connect(_on_window_resized)
	
	# Remaining UI init
	settings_menu.hide()
	hide_level_panels()
	setup_give_item_menu()
	
	# Connect debug signals in code so they survive movement to World.tscn root
	call_deferred("_connect_debug_signals")

func _apply_mobile_layout_overrides():
	# Reduce margins for level up screens
	var lup_mc = get_node_or_null("%LUpMarginContainer")
	if lup_mc:
		lup_mc.add_theme_constant_override("margin_top", 8)
		lup_mc.add_theme_constant_override("margin_bottom", 8)
		
	var blup_mc = get_node_or_null("%BLUpMarginContainer")
	if blup_mc:
		blup_mc.add_theme_constant_override("margin_top", 8)
		blup_mc.add_theme_constant_override("margin_bottom", 8)

	# Expand Pause Menu and Death Panel width
	# On mobile, we want them nearly full width (100% per user request)
	if pause_menu:
		pause_menu.custom_minimum_size.x = 280 # Full-ish width on 320 effective width
		pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Enlarge all buttons in Pause Menu
		var pause_buttons = pause_menu.find_children("", "Button", true, false)
		for btn in pause_buttons:
			btn.custom_minimum_size.y = 40
		
	if deathPanel:
		deathPanel.custom_minimum_size.x = 280
		deathPanel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Enlarge all buttons in Death Panel and make them fill full width
		var death_buttons = deathPanel.find_children("", "Button", true, false)
		for btn in death_buttons:
			btn.custom_minimum_size.y = 48
			btn.size_flags_horizontal = Control.SIZE_FILL
			
		# On mobile, center the content within the full-screen panel
		var m_container = deathPanel.get_node_or_null("M")
		if m_container:
			var v_box = m_container.get_node_or_null("V")
			if v_box:
				v_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				v_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				v_box.custom_minimum_size.x = 200
	
	# Fix tip text alignment: RichTextLabel text defaults to left-aligned.
	# Enable BBCode so we can wrap content in [center] tags.
	if lblTips:
		lblTips.size_flags_horizontal = Control.SIZE_FILL
		lblTips.fit_content = false
		lblTips.bbcode_enabled = true
	
	# Bump HUD font sizes — 12px is hard to read at a glance on a real phone
	if lblTimer:
		lblTimer.add_theme_font_size_override("font_size", 16)
	if lblLevel:
		lblLevel.add_theme_font_size_override("font_size", 14)

func _on_window_resized():
	apply_gui_scale(SettingsManager.gui_scale)
	_initialize_pause_menu_position()

func _initialize_pause_menu_position():
	# Force show briefly to ensure anchors and containers calculate final rects
	var was_visible = pause_menu.visible
	pause_menu.show()
	# This is necessary because Godot doesn't calculate position for hidden anchored nodes correctly in _ready
	await get_tree().process_frame
	
	pause_original_x = pause_menu.position.x
	# The menu should be 8px off-screen when hidden. 
	# Since it's a child of the scaled GUI node, 0 is the left edge.
	pause_hidden_x = -pause_menu.size.x - 8
	
	if is_menu_open:
		pause_menu.position.x = pause_original_x
	else:
		pause_menu.position.x = pause_hidden_x
		pause_menu.visible = was_visible


func _connect_debug_signals():
	if not player or not is_instance_valid(player): 
		player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	# Find debug buttons and connect them if they aren't already
	var grid = get_node_or_null("%DebugMenu/Padded container/VBoxContainer/GridContainer")
	if grid:
		# 1. Buttons that connect to Player functions
		var player_btn_map = {
			"btn_end_run": player._on_btn_end_run_click_end,
			"btn_exit_game": player._on_btn_exit_game_click_end,
			"btn_give_xp": player._on_btn_give_xp_click_end,
			"btn_give_level": player._on_btn_give_level_click_end,
			"btn_kill_player": player._on_btn_kill_player_click_end,
			"btn_damage_player": player._on_btn_damage_player_click_end,
			"btn_next_normal_track": player._on_btn_next_normal_track_click_end,
			"btn_next_boss_track": player._on_btn_next_boss_track_click_end,
			"btn_pause_music": player._on_btn_pause_music_click_end,
			"btn_unpause_music": player._on_btn_unpause_music_click_end,
			"btn_timer_1m": player._on_btn_timer_1m_click_end,
			"btn_timer_5m": player._on_btn_timer_5m_click_end,
		}
		
		# 2. Buttons that connect to GUI (Self) functions
		var gui_btn_map = {
			"btn_give_item": _on_btn_give_item_click_end,
			"btn_remove_item": _on_btn_remove_item_click_end,
			"btn_show_warning": _on_btn_show_warning_click_end,
			"btn_spawn_boss": _on_btn_spawn_boss_click_end,
		}

		# Connect player-based buttons
		for btn_name in player_btn_map:
			var btn = grid.get_node_or_null(btn_name)
			if btn and btn.has_signal("click_end"):
				if not btn.click_end.is_connected(player_btn_map[btn_name]):
					btn.click_end.connect(player_btn_map[btn_name])
		
		# Connect gui-based buttons
		for btn_name in gui_btn_map:
			var btn = grid.get_node_or_null(btn_name)
			if btn and btn.has_signal("click_end"):
				if not btn.click_end.is_connected(gui_btn_map[btn_name]):
					btn.click_end.connect(gui_btn_map[btn_name])
		
		# Toggle buttons (mostly player-based)
		var god = grid.get_node_or_null("btn_toggle_godmode")
		if god and not god.toggled.is_connected(player._on_btn_toggle_godmode_toggled):
			god.toggled.connect(player._on_btn_toggle_godmode_toggled)
			
		var spawn = grid.get_node_or_null("btn_toggle_spawns")
		if spawn and not spawn.toggled.is_connected(player._on_btn_toggle_spawns_toggled):
			spawn.toggled.connect(player._on_btn_toggle_spawns_toggled)




func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	
	if event.is_action("debugMenu"):
		if debug_menu:
			if event.is_pressed():
				openMenu.emit()
			
			if event.is_released():
				closeMenu.emit()
		get_viewport().set_input_as_handled()
		
		
	if event.is_action_pressed("menu"):
		toggle_menu()
	elif event.is_action_pressed("ui_cancel") and pause_menu.visible:
		if settings_menu.visible:
			if settings_menu.is_focus_in_content():
				settings_menu.grab_initial_focus()
			else:
				close_settings()
		else:
			close_pause_menu()
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
	   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		if get_viewport().gui_get_focus_owner() == null:
			if levelPanel.visible or bossLevelPanel.visible or pause_menu.visible:
				_grab_context_focus()
				get_viewport().set_input_as_handled()
	if event.is_action_pressed("FreezeeverythingNOW!!!"):
		get_tree().paused = !get_tree().paused
		get_viewport().set_input_as_handled()


func toggle_menu():
	if !levelup_menu.visible:
		if pause_menu:
			is_menu_open = !is_menu_open
			if is_menu_open:
				open_pause_menu()
			else:
				close_pause_menu()

func open_pause_menu() -> void:
	if pause_tween:
		pause_tween.kill()
		
	change_random_tip()
	pause_menu.show()
	get_tree().paused = true
	MusicController.focusMusic(false)
	
	pause_tween = create_tween()
	pause_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pause_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pause_tween.tween_property(pause_menu, "position:x", pause_original_x, transition_duration)
	

func close_pause_menu() -> void:
	if pause_tween:
		pause_tween.kill()
		
	get_tree().paused = false
	MusicController.focusMusic(true)
	
	pause_tween = create_tween().set_parallel(true)
	pause_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pause_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pause_tween.tween_property(pause_menu, "position:x", pause_hidden_x, transition_duration)
	
	if settings_menu.visible:
		settings_menu.hide()
		
	pause_tween.chain().tween_callback(pause_menu.hide)


func open_settings() -> void:
	settings_menu.show()

func close_settings() -> void:
	settings_menu.hide()
	
#death menu buttons
func _on_btn_menu_click_end() -> void:
	get_tree().paused = false
	var _level = get_tree().change_scene_to_file(titleMenu)

func _on_btn_restart_click_end() -> void:
	GlobalEvents.restart_run()

#pause menu buttons
func _on_btn_exit_game_click_end() -> void:
	get_tree().quit()

func _on_btn_end_run_click_end() -> void:
	player.death()
	var _level = get_tree().change_scene_to_file(titleMenu)

func _on_btn_resume_run_click_end() -> void:
	toggle_menu()

func _on_btn_settings_click_end() -> void:
	if settings_menu.visible:
		close_settings()
	else:
		open_settings()

func _on_settings_menu_settings_closed() -> void:
	close_settings()

func _grab_context_focus() -> void:
	if levelPanel.visible:
		if upgradeOptions.get_child_count() > 0:
			upgradeOptions.get_child(0).grab_focus()
	elif bossLevelPanel.visible:
		if bossUpgradeOptions.get_child_count() > 0:
			bossUpgradeOptions.get_child(0).grab_focus()
	elif pause_menu.visible:
		if settings_menu.visible:
			settings_menu.grab_initial_focus()
		else:
			btnResume.grab_focus()

# Give Item Menu Logic
func setup_give_item_menu():
	var items = {}
	for i in UpgradeDb.UPGRADES:
		var dname = UpgradeDb.UPGRADES[i].get("displayname", i)
		if not items.has(dname):
			items[dname] = []
		items[dname].append(i)
		
	for dname in items.keys():
		var btn = Button.new()
		btn.text = tr(dname)
		btn.pressed.connect(func(name_key=dname):
			giveItemMainGrid.hide()
			giveItemSubGrid.show()
			for child in giveItemSubGrid.get_children():
				child.queue_free()
			
			var back_btn = Button.new()
			back_btn.text = tr("ui_backButton")
			back_btn.custom_minimum_size = Vector2(180, 40)
			back_btn.pressed.connect(func():
				giveItemSubGrid.hide()
				giveItemMainGrid.show()
			)
			giveItemSubGrid.add_child(back_btn)
			
			for lvl_id in items[name_key]:
				var lvl_btn = Button.new()
				var lvl_text = str(tr(UpgradeDb.UPGRADES[lvl_id].get("level", lvl_id)))
				lvl_btn.text = lvl_text
				lvl_btn.custom_minimum_size = Vector2(180, 40)
				lvl_btn.pressed.connect(func(id=lvl_id):
					player.grant_upgrade_with_prereqs(id)
					get_tree().paused = false
					giveItemMenu.visible = false
				)
				giveItemSubGrid.add_child(lvl_btn)
		)
		giveItemMainGrid.add_child(btn)

func _on_btn_give_item_click_end() -> void:
	get_tree().paused = true
	giveItemMainGrid.show()
	giveItemSubGrid.hide()
	giveItemMenu.visible = true

func _on_btn_close_give_item_pressed() -> void:
	get_tree().paused = false
	giveItemMenu.visible = false


func _on_btn_remove_item_click_end() -> void:
	# Rebuild the menu each time so it reflects current inventory
	for child in removeItemMainGrid.get_children():
		child.queue_free()
	for child in removeItemSubGrid.get_children():
		child.queue_free()
	
	# Group collected upgrades by base name
	var owned: Dictionary = {}
	for uid in player.collected_upgrades:
		var base_name = uid.rstrip("0123456789")
		if not owned.has(base_name):
			owned[base_name] = []
		owned[base_name].append(uid)
	
	if owned.is_empty():
		# Nothing to remove — show the menu anyway so player can see it's empty
		var lbl = Label.new()
		lbl.text = tr("debug_noItemsToRemove")
		removeItemMainGrid.add_child(lbl)
	else:
		for base_name in owned.keys():
			var levels: Array = owned[base_name]
			levels.sort()
			var first_id = levels[0]
			var dname = UpgradeDb.UPGRADES[first_id].get("displayname", base_name)
			var btn = Button.new()
			btn.text = tr(dname)
			btn.custom_minimum_size = Vector2(180, 40)
			btn.pressed.connect(func(b_name=base_name, lvls=levels):
				removeItemMainGrid.hide()
				removeItemSubGrid.show()
				for child in removeItemSubGrid.get_children():
					child.queue_free()
				
				# Back button
				var back_btn = Button.new()
				back_btn.text = tr("ui_backButton")
				back_btn.custom_minimum_size = Vector2(180, 40)
				back_btn.pressed.connect(func():
					removeItemSubGrid.hide()
					removeItemMainGrid.show()
				)
				removeItemSubGrid.add_child(back_btn)
				
				# Remove completely
				var max_lvl = int(lvls[-1].right(lvls[-1].length() - b_name.length()))
				var remove_all_btn = Button.new()
				remove_all_btn.text = tr("debug_removeCompletely")
				remove_all_btn.custom_minimum_size = Vector2(180, 40)
				remove_all_btn.pressed.connect(func(bn=b_name):
					player.remove_upgrade_to_level(bn, 0)
					get_tree().paused = false
					removeItemMenu.visible = false
				)
				removeItemSubGrid.add_child(remove_all_btn)
				
				# Remove to level X buttons (for each level above 1)
				for i in range(1, max_lvl):
					var keep_lvl = i
					var lvl_btn = Button.new()
					lvl_btn.text = tr("debug_removeToLevel") + " " + str(keep_lvl)
					lvl_btn.custom_minimum_size = Vector2(180, 40)
					lvl_btn.pressed.connect(func(bn=b_name, kl=keep_lvl):
						player.remove_upgrade_to_level(bn, kl)
						get_tree().paused = false
						removeItemMenu.visible = false
					)
					removeItemSubGrid.add_child(lvl_btn)
			)
			removeItemMainGrid.add_child(btn)
	
	get_tree().paused = true
	removeItemMainGrid.show()
	removeItemSubGrid.hide()
	removeItemMenu.visible = true


func _on_btn_close_remove_item_pressed() -> void:
	get_tree().paused = false
	removeItemMenu.visible = false


func _on_btn_show_warning_click_end() -> void:
	
	GlobalEvents.emit_signal("show_boss_warning", GlobalEvents.boss_warnings.get("generic"))


func _on_btn_spawn_boss_click_end() ->	void:
	GlobalEvents.queue_boss.emit()

func _process(delta: float) -> void:
	if pause_menu.visible:
		tip_timer += delta
		if tip_timer >= TIP_ROTATION_TIME:
			change_random_tip()

func change_random_tip() -> void:
	var available_keys = []
	for key in tip_keys:
		if key != _last_tip_key:
			available_keys.append(key)
	
	if available_keys.size() > 0:
		var new_key = available_keys.pick_random()
		_last_tip_key = new_key
		var tip_text = tr(new_key)
		if lblTips.bbcode_enabled:
			lblTips.text = "[center]" + tip_text + "[/center]"
		else:
			lblTips.text = tip_text
		tip_timer = 0.0

func apply_gui_scale(value: float) -> void:
	scale = Vector2(value, value)
	
	# Detach from full-rect anchors to stop engine warnings about overriding size
	anchor_right = 0.0
	anchor_bottom = 0.0
	
	var vp_size = get_viewport_rect().size
	set_deferred("size", vp_size / value)

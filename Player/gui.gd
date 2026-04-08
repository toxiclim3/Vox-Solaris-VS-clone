extends Control

var titleMenu = "res://TitleScreen/menu.tscn"

@onready var settings_menu = get_node("SettingsMenu")
@onready var pause_menu = get_node("PauseMenu")
@onready var debug_menu = get_node("DebugMenu")
@onready var levelup_menu = get_node("LevelUp")

@onready var giveItemMenu = get_node("GiveItemMenu")
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
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var collectedBossItems = get_node("%CollectedBossItems")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var itemContainer = preload("res://Player/GUI/item_container.tscn")
@onready var lblTips = get_node("%lblTips")

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
	var vp_size = get_viewport_rect().size
	var target_pos = (vp_size - deathPanel.size) / 2.0
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
		
	# Await process_frame safely inside gui.gd!
	await get_tree().process_frame
	var children = upgradeOptions.get_children()
	var max_width: float = 0.0
	for child in children:
		max_width = max(max_width, child.get_combined_minimum_size().x)
	for child in children:
		child.custom_minimum_size.x = max_width
	
	var desired_scroll_h = upgradeOptions.get_combined_minimum_size().y
	var vp_h = get_viewport_rect().size.y
	var max_scroll_h = vp_h * 0.65
	upgradeScroll.custom_minimum_size.y = min(desired_scroll_h, max_scroll_h)
	
	await get_tree().process_frame
	levelPanel.reset_size()
	var vp_size = get_viewport_rect().size
	var half_w = min(levelPanel.size.x, vp_size.x * 0.95) / 2.0
	var half_h = min(levelPanel.size.y, vp_size.y * 0.95) / 2.0
	levelPanel.offset_left = -half_w
	levelPanel.offset_right = half_w
	levelPanel.offset_top = -half_h
	levelPanel.offset_bottom = half_h

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
		
	await get_tree().process_frame
	var children = bossUpgradeOptions.get_children()
	var max_width: float = 0.0
	for child in children:
		max_width = max(max_width, child.get_combined_minimum_size().x)
	for child in children:
		child.custom_minimum_size.x = max_width
		
	var desired_scroll_h = bossUpgradeOptions.get_combined_minimum_size().y
	var vp_h = get_viewport_rect().size.y
	var max_scroll_h = vp_h * 0.65
	bossUpgradeScroll.custom_minimum_size.y = min(desired_scroll_h, max_scroll_h)
	
	await get_tree().process_frame
	bossLevelPanel.reset_size()
	var vp_size = get_viewport_rect().size
	var half_w = min(bossLevelPanel.size.x, vp_size.x * 0.95) / 2.0
	var half_h = min(bossLevelPanel.size.y, vp_size.y * 0.95) / 2.0
	bossLevelPanel.offset_left = -half_w
	bossLevelPanel.offset_right = half_w
	bossLevelPanel.offset_top = -half_h
	bossLevelPanel.offset_bottom = half_h

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


func _ready() -> void:
	# Запоминаем, где меню паузы стоит по умолчанию
	pause_original_x = pause_menu.position.x
	
	# Используем размер экрана, как и в SettingsMenu, чтобы не запрашивать size.x до компоновки интерфейса
	var screen_width: float = get_viewport_rect().size.x
	pause_hidden_x = -screen_width
	
	# Прячем меню паузы за левый край экрана
	pause_menu.position.x = pause_hidden_x
	pause_menu.hide()
	
	# Настройки теперь на отдельном CanvasLayer, позиционирование не требуется
	settings_menu.hide()
	setup_give_item_menu()
	




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
	change_random_tip()
	pause_menu.show()
	get_tree().paused = true
	MusicController.focusMusic(false)
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pause_menu, "position:x", pause_original_x, transition_duration)

func close_pause_menu() -> void:
	get_tree().paused = false
	MusicController.focusMusic(true)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pause_menu, "position:x", pause_hidden_x, transition_duration)
	
	if settings_menu.visible:
		settings_menu.hide()
		
	tween.chain().tween_callback(pause_menu.hide)


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

# Give Item Menu Logic
func setup_give_item_menu():
	var items = {}
	for i in UpgradeDb.UPGRADES:
		var base_name = i.rstrip("0123456789")
		if not items.has(base_name):
			items[base_name] = []
		items[base_name].append(i)
		
	for base_name in items.keys():
		var btn = Button.new()
		var first_id = items[base_name][0]
		var dname = UpgradeDb.UPGRADES[first_id].get("displayname", base_name)
		btn.text = tr(dname)
		btn.custom_minimum_size = Vector2(180, 40)
		btn.pressed.connect(func(b_name=base_name):
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
			
			for lvl_id in items[b_name]:
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
	var current_text = lblTips.text
	var available_keys = []
	for key in tip_keys:
		if tr(key) != current_text:
			available_keys.append(key)
	
	if available_keys.size() > 0:
		var new_key = available_keys.pick_random()
		lblTips.text = tr(new_key)
		tip_timer = 0.0

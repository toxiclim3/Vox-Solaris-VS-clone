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

@onready var boss_warning_panel = get_node("BossWarning")
@onready var boss_warning_label = get_node("BossWarning/Label")
@onready var snd_boss_warning = get_node("BossWarning/snd_boss_warning")

var boss_warning_tween: Tween

# Boss Bar
@onready var boss_bar_container = get_node("BossBarContainer")
@onready var boss_bar_progress = get_node("BossBarContainer/BossBarProgress")
@onready var boss_name_label = get_node("BossBarContainer/BossNameLabel")
@onready var boss_bar_particles = get_node("BossBarContainer/BossBarParticles")

var current_boss: EnemyBody = null
var boss_bar_tween: Tween

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
	
	# Прячем настройки за правый край экрана
	settings_menu.position.x = screen_width + gap
	settings_menu.hide()
	setup_give_item_menu()
	
	GlobalEvents.show_boss_warning.connect(_on_show_boss_warning)
	GlobalEvents.boss_spawned.connect(_on_boss_spawned)
	GlobalEvents.boss_defeated.connect(_on_boss_defeated)
	
	# Setup boss bar particles material
	_setup_boss_particles()

func _on_show_boss_warning(warning_key: String) -> void:
	boss_warning_label.text = tr(warning_key)
	boss_warning_panel.show()
	snd_boss_warning.play()
	
	if boss_warning_tween:
		boss_warning_tween.kill()
		
	boss_warning_tween = create_tween()
	boss_warning_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	boss_warning_tween.tween_property(boss_warning_panel, "position:y", 0.0, 0.5)
	
	get_tree().create_timer(5.0).timeout.connect(hide_boss_warning)

func hide_boss_warning() -> void:
	if not boss_warning_panel.visible:
		return
	if boss_warning_tween:
		boss_warning_tween.kill()
		
	boss_warning_tween = create_tween()
	boss_warning_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	boss_warning_tween.tween_property(boss_warning_panel, "position:y", -32.0, 0.5)
	boss_warning_tween.tween_callback(boss_warning_panel.hide)

func _on_btn_warning_dismiss_pressed() -> void:
	hide_boss_warning()

func _process(_delta: float) -> void:
	if current_boss and is_instance_valid(current_boss):
		boss_bar_progress.value = current_boss.hp

func _setup_boss_particles() -> void:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.gravity = Vector3(0, 40, 0)
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.76, 0.65, 0.5, 0.8)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(320, 2, 0)
	boss_bar_particles.process_material = mat
	boss_bar_particles.position = Vector2(boss_bar_container.size.x / 2.0 if boss_bar_container.size.x > 0 else 320, 20)

func _on_boss_spawned(boss: EnemyBody) -> void:
	current_boss = boss
	boss_bar_progress.max_value = boss.max_hp
	boss_bar_progress.value = boss.hp
	
	# Get the boss name via translation key
	var scene_path = boss.scene_file_path
	var name_key = GlobalEvents.boss_names.get(scene_path, "boss_name_generic")
	boss_name_label.text = tr(name_key)
	
	# Show and animate
	boss_bar_container.show()
	boss_bar_container.offset_top = -40.0
	boss_bar_container.offset_bottom = -17.0
	
	# Configure dust particles for entrance
	var dust_mat = boss_bar_particles.process_material as ParticleProcessMaterial
	if dust_mat:
		dust_mat.direction = Vector3(0, 1, 0)
		dust_mat.gravity = Vector3(0, 40, 0)
		dust_mat.initial_velocity_min = 15.0
		dust_mat.initial_velocity_max = 35.0
		dust_mat.scale_min = 1.5
		dust_mat.scale_max = 3.0
		dust_mat.color = Color(0.76, 0.65, 0.5, 0.8)
	boss_bar_particles.emitting = true
	
	if boss_bar_tween:
		boss_bar_tween.kill()
	
	# Get timer label reference
	var timer_label = get_tree().get_first_node_in_group("player")
	if timer_label:
		timer_label = timer_label.get_node_or_null("%lblTimer")
	
	boss_bar_tween = create_tween().set_parallel(true)
	boss_bar_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	boss_bar_tween.tween_property(boss_bar_container, "offset_top", 20.0, 0.8)
	boss_bar_tween.tween_property(boss_bar_container, "offset_bottom", 43.0, 0.8)
	if timer_label:
		boss_bar_tween.tween_property(timer_label, "self_modulate:a", 0.0, 0.4)

func _on_boss_defeated() -> void:
	# Configure smoke particles for exit
	var smoke_mat = boss_bar_particles.process_material as ParticleProcessMaterial
	if smoke_mat:
		smoke_mat.direction = Vector3(0, -1, 0)
		smoke_mat.gravity = Vector3(0, -10, 0)
		smoke_mat.initial_velocity_min = 8.0
		smoke_mat.initial_velocity_max = 20.0
		smoke_mat.scale_min = 3.0
		smoke_mat.scale_max = 6.0
		smoke_mat.color = Color(0.5, 0.5, 0.5, 0.6)
	boss_bar_particles.emitting = true
	
	if boss_bar_tween:
		boss_bar_tween.kill()
	
	# Get timer label reference
	var timer_label = get_tree().get_first_node_in_group("player")
	if timer_label:
		timer_label = timer_label.get_node_or_null("%lblTimer")
	
	boss_bar_tween = create_tween().set_parallel(true)
	boss_bar_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	boss_bar_tween.tween_property(boss_bar_container, "offset_top", -40.0, 0.6)
	boss_bar_tween.tween_property(boss_bar_container, "offset_bottom", -17.0, 0.6)
	if timer_label:
		boss_bar_tween.tween_property(timer_label, "self_modulate:a", 1.0, 0.5)
	boss_bar_tween.chain().tween_callback(func():
		boss_bar_container.hide()
		current_boss = null
	)

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
		var screen_width: float = get_viewport_rect().size.x
		tween.tween_property(settings_menu, "position:x", screen_width + gap, transition_duration)
		tween.chain().tween_callback(settings_menu.hide)
		
	tween.chain().tween_callback(pause_menu.hide)


func open_settings() -> void:
	settings_menu.show()
	
	var screen_width: float = get_viewport_rect().size.x
	var screen_center_x: float = screen_width / 2.0
	
	# 1. Считаем габариты всего визуального блока
	var total_width: float = pause_menu.size.x + gap + settings_menu.size.x
	
	# 2. Находим координату X, откуда этот блок должен начинаться, чтобы быть в центре
	var group_start_x: float = screen_center_x - (total_width / 2.0)
	
	# 3. Распределяем позиции
	var pause_target_x: float = group_start_x
	var settings_target_x: float = group_start_x + pause_menu.size.x + gap
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(pause_menu, "position:x", pause_target_x, transition_duration)
	tween.tween_property(settings_menu, "position:x", settings_target_x, transition_duration)

func close_settings() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Возвращаем меню паузы на его законное место слева
	tween.tween_property(pause_menu, "position:x", pause_original_x, transition_duration)
	
	# Настройки снова улетают вправо за экран
	var screen_width: float = get_viewport_rect().size.x
	tween.tween_property(settings_menu, "position:x", screen_width + gap, transition_duration)
	
	tween.chain().tween_callback(settings_menu.hide)
	
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

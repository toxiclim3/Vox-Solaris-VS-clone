extends Control

var titleMenu = "res://TitleScreen/menu.tscn"

@onready var settings_menu = get_node("%SettingsMenu")
@onready var pause_menu = get_node("%PauseMenu")
@onready var debug_menu = get_node("%DebugMenu")
@onready var levelup_menu = get_node("%LevelUp")

@onready var player = get_tree().get_first_node_in_group("player")

var debug_controller: Node = null
var _timer_hold_active: bool = false
var _timer_hold_time: float = 0.0
var _timer_hold_triggered: bool = false

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
	"tips_javelin",
	"tips_tornado",
	"tips_whip",
	"tips_ring_projectiles",
	"tips_ring_rejuvenation",
	"tips_ring_affinity",
	"tips_thornring",
	"tips_glasslash",
	"tips_vampireknives",
	"tips_relicdrone",
	"tips_meme_food",
	"tips_meme_franklin_home",
	"tips_meme_sinister_potion",
	"tips_meme_onion_rings",
	"tips_meme_rocket_launcher",
	"tips_meme_lime_industries",
	"tips_meme_you_can_do_it",
	"tips_amoeba_boss",
	"tips_franklin_boss",
	"tips_surrounded_graze",
	"tips_meme_vibecoded",
	"tips_meme_ror_promo",
	"tips_meme_try_terraria",
	"tips_meme_try_minecraft",
	"tips_meme_try_mamasboy",
	"tips_meme_box_sleep",
	"tips_meme_green_person",
	"tips_meme_inspiration",
	"tips_meme_swag"
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

func refresh_gui_collection() -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	for container in [collectedWeapons, collectedUpgrades, collectedBossItems]:
		if container == null:
			continue
		for ch in container.get_children():
			container.remove_child(ch)
			ch.queue_free()
	if not player:
		return
	var seen_displaynames: Array = []
	for uid in player.collected_upgrades:
		if not UpgradeDb.UPGRADES.has(uid):
			continue
		var data: Dictionary = UpgradeDb.UPGRADES[uid]
		var get_type: String = data.get("type", "")
		if get_type in ["item", "endless"]:
			continue
		var disp: String = data.get("displayname", uid)
		if disp in seen_displaynames:
			continue
		seen_displaynames.append(disp)
		var new_item = itemContainer.instantiate()
		new_item.upgrade = uid
		match get_type:
			"weapon":
				if collectedWeapons: collectedWeapons.add_child(new_item)
			"upgrade":
				if collectedUpgrades: collectedUpgrades.add_child(new_item)
			"bossitem":
				if collectedBossItems: collectedBossItems.add_child(new_item)

func show_death_panel(hasWon: bool) -> void:
	if deathPanel.visible:
		return
	
	# Clean up any open gameplay menus properly
	if is_menu_open:
		close_pause_menu()
		get_tree().paused = true # Ensure we stay paused, as close_pause_menu() unpauses the tree
	
	hide_level_panels()
	
	deathPanel.visible = true
	if btnPauseMobile:
		btnPauseMobile.visible = false
	var is_mobile = OS.get_name() in ["Android", "iOS"]
	var target_pos: Vector2
	
	if is_mobile:
		target_pos = Vector2.ZERO # Full rect anchors mean (0,0) is centered fill
	else:
		# Use local size (which is vp_size / gui_scale) to center correctly
		target_pos = (size - deathPanel.size) / 2.0
		
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

const LEVELUP_CARD_WIDTH: float = 148.0
const LEVELUP_CARD_SEPARATION: float = 8.0
const LEVELUP_PANEL_CHROME_WIDTH: float = 48.0
const LEVELUP_MIN_PANEL_WIDTH: float = 220.0
const LEVELUP_HORIZONTAL_MARGIN: float = 32.0

func _release_panel_focus(panel: Node) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var focused := vp.gui_get_focus_owner()
	if focused != null and (focused == panel or panel.is_ancestor_of(focused)):
		focused.release_focus()

func hide_level_panels() -> void:
	_release_panel_focus(levelPanel)
	_release_panel_focus(bossLevelPanel)
	levelPanel.visible = false
	bossLevelPanel.visible = false

func _populate_level_options(panel: PanelContainer, scroll: ScrollContainer, options_container: Container, options_list: Array) -> void:
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()

	var vp := get_viewport()
	if vp:
		var focused := vp.gui_get_focus_owner()
		if focused:
			focused.release_focus()

	panel.visible = true
	if scroll:
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0

	var is_mobile := OS.get_name() in ["Android", "iOS"]
	for item in options_list:
		var option_choice = itemOptions.instantiate()
		option_choice.item = item
		options_container.add_child(option_choice)
		if is_mobile:
			_apply_recursive_font_bump(option_choice, 4)
			if option_choice.has_method("on_font_size_bumped"):
				option_choice.on_font_size_bumped(4)

	_wire_option_focus_neighbors(options_container)
	_update_level_panel_width(panel, options_container)

func _wire_option_focus_neighbors(options_container: Container) -> void:
	var cards: Array[Control] = []
	for child in options_container.get_children():
		if child is Control:
			cards.append(child)
	var count := cards.size()
	for i in range(count):
		var card := cards[i]
		var self_path := card.get_path_to(card)
		card.focus_neighbor_top = self_path
		card.focus_neighbor_bottom = self_path
		card.focus_neighbor_left = card.get_path_to(cards[i - 1]) if i > 0 else self_path
		card.focus_neighbor_right = card.get_path_to(cards[i + 1]) if i < count - 1 else self_path
		card.focus_previous = card.focus_neighbor_left
		card.focus_next = card.focus_neighbor_right

func _update_level_panel_width(panel: PanelContainer, options_container: Container) -> void:
	if not panel or not options_container:
		return
	var count := maxi(1, options_container.get_child_count())
	var desired_w := maxf(
		LEVELUP_MIN_PANEL_WIDTH,
		count * LEVELUP_CARD_WIDTH + maxi(0, count - 1) * LEVELUP_CARD_SEPARATION + LEVELUP_PANEL_CHROME_WIDTH
	)
	var available_w := size.x
	if available_w <= 0.0:
		var vp_w := get_viewport_rect().size.x
		available_w = (vp_w / maxf(scale.x, 0.01)) if vp_w > 0.0 else 640.0
	var h_margin := 16.0 if OS.get_name() in ["Android", "iOS"] else LEVELUP_HORIZONTAL_MARGIN
	var max_w := maxf(LEVELUP_MIN_PANEL_WIDTH, available_w - h_margin)
	panel.custom_minimum_size.x = minf(desired_w, max_w)

func _refresh_visible_level_panel_widths() -> void:
	if levelPanel and levelPanel.visible:
		_update_level_panel_width(levelPanel, upgradeOptions)
	if bossLevelPanel and bossLevelPanel.visible:
		_update_level_panel_width(bossLevelPanel, bossUpgradeOptions)

func show_levelup(options_list: Array, current_visual_level: int) -> void:
	sndLevelUp.play()
	set_level_text(current_visual_level)
	_populate_level_options(levelPanel, upgradeScroll, upgradeOptions, options_list)

func show_boss_levelup(options_list: Array) -> void:
	sndLevelUp.play()
	_populate_level_options(bossLevelPanel, bossUpgradeScroll, bossUpgradeOptions, options_list)

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
	call_deferred("_init_debug_suite")

func _init_debug_suite() -> void:
	if debug_controller == null:
		debug_controller = load("res://Utility/Debug/debug_controller.gd").new()
		add_child(debug_controller)
	var world_root: Node = get_tree().current_scene if get_tree() else null
	if world_root == null and get_parent() and get_parent().get_parent():
		world_root = get_parent().get_parent()
	debug_controller.attach(self, world_root)
	if debug_menu and debug_menu.has_method("rebuild_layout"):
		debug_menu.rebuild_layout(debug_controller)
	if lblTimer:
		lblTimer.mouse_filter = Control.MOUSE_FILTER_STOP
		if not lblTimer.gui_input.is_connected(_on_timer_gui_input):
			lblTimer.gui_input.connect(_on_timer_gui_input)

func _on_timer_gui_input(event: InputEvent) -> void:
	if not SettingsManager.is_debug_enabled():
		return
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	if pressed:
		_timer_hold_active = true
		_timer_hold_time = 0.0
		_timer_hold_triggered = false
	elif released:
		_timer_hold_active = false
		_timer_hold_time = 0.0

func _apply_mobile_layout_overrides():
	# Recursively bump all font sizes by 4 points
	_apply_recursive_font_bump(self, 4)
	
	# Reduce margins for level up screens
	var lup_mc = get_node_or_null("%LUpMarginContainer")
	if lup_mc:
		lup_mc.add_theme_constant_override("margin_left", 8)
		lup_mc.add_theme_constant_override("margin_right", 8)
		lup_mc.add_theme_constant_override("margin_top", 8)
		lup_mc.add_theme_constant_override("margin_bottom", 8)
		
	var blup_mc = get_node_or_null("%BLUpMarginContainer")
	if blup_mc:
		blup_mc.add_theme_constant_override("margin_left", 8)
		blup_mc.add_theme_constant_override("margin_right", 8)
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
		lblTips.custom_minimum_size.y = 80 # Taller for mobile text support
	
	# HUD font sizes are already bumped by recursive function, but we can fine-tune if needed
	# (Previously manually boosted to 16/14, now they will be base+4)

func _apply_recursive_font_bump(node: Node, amount: int):
	if node is Label or node is RichTextLabel or node is Button:
		# Check for existing override, otherwise get from theme
		var current_size = node.get_theme_font_size("font_size")
		# Only apply if it looks like a standard small font or doesn't have an override yet
		# To avoid double-bumping if this is called multiple times
		node.add_theme_font_size_override("font_size", current_size + amount)
	
	for child in node.get_children():
		_apply_recursive_font_bump(child, amount)

func _on_window_resized():
	apply_gui_scale(SettingsManager.gui_scale)
	_initialize_pause_menu_position()
	call_deferred("_refresh_visible_level_panel_widths")
	
	if deathPanel.visible:
		var is_mobile = OS.get_name() in ["Android", "iOS"]
		if is_mobile:
			deathPanel.position = Vector2.ZERO
		else:
			# Update position to new center if screen resolution changed
			deathPanel.position = (size - deathPanel.size) / 2.0

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


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if SettingsManager.is_debug_enabled():
		if debug_controller and debug_controller.handle_key_event(event):
			get_viewport().set_input_as_handled()
			return

		if event.is_action("debugMenu"):
			if debug_menu:
				if event.is_pressed():
					if debug_menu.has_method("handle_tab_pressed"):
						debug_menu.handle_tab_pressed()
					else:
						openMenu.emit()
				elif event.is_released():
					if debug_menu.has_method("handle_tab_released"):
						debug_menu.handle_tab_released()
					else:
						closeMenu.emit()
			get_viewport().set_input_as_handled()
			return

	if debug_controller:
		var modal_cancel: bool = bool(event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE)))
		if debug_controller.workbench and debug_controller.workbench.visible:
			if modal_cancel:
				debug_controller.workbench.close_modal()
				get_viewport().set_input_as_handled()
				return
		if debug_controller.switcher and debug_controller.switcher.visible:
			if modal_cancel:
				debug_controller.switcher.close_modal()
				get_viewport().set_input_as_handled()
				return

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


func toggle_menu():
	if !levelup_menu.visible or !deathPanel.visible:
		if pause_menu:
			if not is_menu_open:
				open_pause_menu()
			else:
				close_pause_menu()

func open_pause_menu() -> void:
	is_menu_open = true
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
	is_menu_open = false
	if pause_tween:
		pause_tween.kill()
		
	_release_panel_focus(pause_menu)
	_release_panel_focus(settings_menu)
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
	_release_panel_focus(settings_menu)
	settings_menu.hide()
	
#death menu buttons
func _on_btn_menu_click_end() -> void:
	get_tree().paused = false
	var menu_path = titleMenu
	var status = ResourceLoader.load_threaded_get_status(menu_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(menu_path))
	else:
		get_tree().change_scene_to_file(menu_path)

func _on_btn_restart_click_end() -> void:
	GlobalEvents.restart_run()

#pause menu buttons
func _on_btn_exit_game_click_end() -> void:
	get_tree().quit()

func _on_btn_end_run_click_end() -> void:
	player.death()
	var menu_path = titleMenu
	var status = ResourceLoader.load_threaded_get_status(menu_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(menu_path))
	else:
		get_tree().change_scene_to_file(menu_path)

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

func _process(delta: float) -> void:
	if _timer_hold_active and not _timer_hold_triggered and SettingsManager.is_debug_enabled():
		_timer_hold_time += delta
		if _timer_hold_time >= 1.0:
			_timer_hold_triggered = true
			_timer_hold_active = false
			if debug_menu and debug_menu.has_method("toggle_menu"):
				debug_menu.toggle_menu()

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
	
	# Exclude Pause Menu and Settings from scaling on mobile to prevent "oversized" look
	var is_mobile = OS.get_name() in ["Android", "iOS"]
	if is_mobile:
		if pause_menu:
			pause_menu.scale = Vector2(1.0/value, 1.0/value)
		if settings_menu:
			settings_menu.scale = Vector2(1.0/value, 1.0/value)
		if deathPanel:
			deathPanel.scale = Vector2(1.0/value, 1.0/value)
	
	# Detach from full-rect anchors to stop engine warnings about overriding size
	anchor_right = 0.0
	anchor_bottom = 0.0
	
	var vp_size = get_viewport_rect().size
	set_deferred("size", vp_size / value)
	call_deferred("_refresh_visible_level_panel_widths")

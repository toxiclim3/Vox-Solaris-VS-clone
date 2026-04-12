extends CanvasLayer

signal settings_closed

@onready var audio_content = %AudioContentPanel
@onready var gameplay_content = %GameplayContentPanel
@onready var display_content = %DisplayContentPanel

@onready var audio_btn = %AudioBtn
@onready var gameplay_btn = %GameplayBtn
@onready var display_btn = %DisplayBtn
@onready var elite_btn = %EliteBtn

@onready var elite_content = %EliteContentPanel

@onready var profile_button = %ProfileButton
@onready var language_button = %LanguageButton
@onready var mouse_control_button = %MouseControlButton
@onready var screen_shake_button = %ScreenShakeButton

@onready var window_mode_button = %WindowModeButton
@onready var vsync_button = %VsyncButton
@onready var max_fps_button = %MaxFpsButton

@onready var confirmation_dialog = %ConfirmationDialog

enum Languages {en, ru, ua}
enum Tabs {AUDIO, GAMEPLAY, DISPLAY, ELITE}

var current_tab_id: int = Tabs.AUDIO

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	# Tab switching
	audio_btn.click_end.connect(_on_tab_pressed.bind(Tabs.AUDIO))
	gameplay_btn.click_end.connect(_on_tab_pressed.bind(Tabs.GAMEPLAY))
	display_btn.click_end.connect(_on_tab_pressed.bind(Tabs.DISPLAY))
	elite_btn.click_end.connect(_on_tab_pressed.bind(Tabs.ELITE))
	
	# Initial tab
	_on_tab_pressed(Tabs.AUDIO)
	
	# Elite settings init
	%TaaButton.button_pressed = SettingsManager.taa_enabled
	%TaaButton.toggled.connect(SettingsManager.set_taa)
	
	%FsrButton.button_pressed = SettingsManager.fsr_enabled
	%FsrButton.toggled.connect(SettingsManager.set_fsr)
	
	%DlssButton.button_pressed = SettingsManager.dlss_enabled
	%DlssButton.toggled.connect(_on_dlss_toggled)
	
	%RtButton.button_pressed = SettingsManager.raytracing_enabled
	%RtButton.toggled.connect(SettingsManager.set_raytracing)
	
	%ShadowButton.button_pressed = SettingsManager.shadows_enabled
	%ShadowButton.toggled.connect(SettingsManager.set_shadows)
	
	# Audio Profile
	profile_button.add_item("Full")
	profile_button.add_item("Grindfest")
	profile_button.select(SettingsManager.get_sound_profile_index())
	profile_button.item_selected.connect(_on_profile_selected)
	
	# Language
	language_button.add_item("English")
	language_button.add_item("Русский")
	language_button.add_item("Українська")
	var lang_index = 0
	match SettingsManager.language:
		"en": lang_index = Languages.en
		"ru": lang_index = Languages.ru
		"ua": lang_index = Languages.ua
	language_button.select(lang_index)
	language_button.item_selected.connect(_on_language_selected)
	
	# Gameplay toggles
	mouse_control_button.button_pressed = SettingsManager.mouse_control
	mouse_control_button.toggled.connect(_on_mouse_control_toggled)
	
	screen_shake_button.button_pressed = SettingsManager.screen_shake
	screen_shake_button.toggled.connect(_on_screen_shake_toggled)
	
	# Display settings
	window_mode_button.add_item("ui_window_windowed")
	window_mode_button.add_item("ui_window_fullscreen")
	window_mode_button.add_item("ui_window_borderless")
	window_mode_button.select(SettingsManager.window_mode)
	window_mode_button.item_selected.connect(_on_window_mode_selected)
	
	vsync_button.button_pressed = SettingsManager.vsync
	vsync_button.toggled.connect(_on_vsync_toggled)
	
	max_fps_button.add_item("ui_fps_unlimited")
	max_fps_button.set_item_metadata(0, 0)
	var fps_options = [30, 60, 120, 144, 240]
	for fps in fps_options:
		max_fps_button.add_item(str(fps))
		max_fps_button.set_item_metadata(max_fps_button.get_item_count() - 1, fps)
	
	# Select current FPS
	for i in range(max_fps_button.get_item_count()):
		if max_fps_button.get_item_metadata(i) == SettingsManager.max_fps:
			max_fps_button.select(i)
			break
	max_fps_button.item_selected.connect(_on_max_fps_selected)
	
	# Footer
	%CloseSettingsButton.click_end.connect(_on_close_settings_button_pressed)
	%btn_reset_stats.click_end.connect(_on_btn_reset_stats_click_end)
	confirmation_dialog.confirmed.connect(_on_confirmation_dialog_confirmed)

func _on_tab_pressed(tab: int) -> void:
	current_tab_id = tab
	audio_content.visible = (tab == Tabs.AUDIO)
	gameplay_content.visible = (tab == Tabs.GAMEPLAY)
	display_content.visible = (tab == Tabs.DISPLAY)
	elite_content.visible = (tab == Tabs.ELITE)
	
	# Visual feedback for buttons (optional, can be done with button groups/themes)
	# For now just simple toggle
	audio_btn.modulate = Color(1,1,1) if tab == Tabs.AUDIO else Color(0.7, 0.7, 0.7)
	gameplay_btn.modulate = Color(1,1,1) if tab == Tabs.GAMEPLAY else Color(0.7, 0.7, 0.7)
	display_btn.modulate = Color(1,1,1) if tab == Tabs.DISPLAY else Color(0.7, 0.7, 0.7)
	elite_btn.modulate = Color(1,1,1) if tab == Tabs.ELITE else Color(0.7, 0.7, 0.7)
	
	# Update focus neighbors
	_update_focus_neighbors(tab)

func _update_focus_neighbors(tab: int) -> void:
	var first_item: Control = null
	var items: Array[Control] = []
	
	match tab:
		Tabs.AUDIO:
			first_item = %VolSlider
			items = [%VolSlider, %MusicSlider, %SFXSlider, %ProfileButton]
		Tabs.GAMEPLAY:
			first_item = %LanguageButton
			items = [%LanguageButton, %MouseControlButton, %ScreenShakeButton, %btn_reset_stats]
		Tabs.DISPLAY:
			first_item = %WindowModeButton
			items = [%WindowModeButton, %VsyncButton, %MaxFpsButton]
		Tabs.ELITE:
			first_item = %TaaButton
			items = [%TaaButton, %FsrButton, %DlssButton, %RtButton, %ShadowButton]
	
	# Current Tab -> Right -> First Item
	var current_tab_btn: Button = null
	match tab:
		Tabs.AUDIO: current_tab_btn = audio_btn
		Tabs.GAMEPLAY: current_tab_btn = gameplay_btn
		Tabs.DISPLAY: current_tab_btn = display_btn
		Tabs.ELITE: current_tab_btn = elite_btn
	
	if current_tab_btn and first_item:
		current_tab_btn.focus_neighbor_right = current_tab_btn.get_path_to(first_item)
		for item in items:
			item.focus_neighbor_left = item.get_path_to(current_tab_btn)

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()
	hide()

func _on_profile_selected(index: int) -> void:
	var profiles = ["Full", "Grindfest"]
	SettingsManager.set_sound_profile(profiles[index])

func _on_language_selected(index: int) -> void:
	SettingsManager.set_language(Languages.keys()[index])

func _on_mouse_control_toggled(toggled_on: bool) -> void:
	SettingsManager.set_mouse_control(toggled_on)

func _on_screen_shake_toggled(toggled_on: bool) -> void:
	SettingsManager.set_screen_shake(toggled_on)

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.set_vsync(toggled_on)

func _on_max_fps_selected(index: int) -> void:
	SettingsManager.set_max_fps(max_fps_button.get_item_metadata(index))

func _on_btn_reset_stats_click_end() -> void:
	confirmation_dialog.popup_centered()

func _on_confirmation_dialog_confirmed() -> void:
	StatsManager.reset_stats()

func _on_dlss_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%DlssDeniedDialog.popup_centered()
		# Force toggle back off after a moment
		await get_tree().create_timer(0.1).timeout
		%DlssButton.button_pressed = false
	SettingsManager.set_dlss(false) # Always false for now, it's a joke

func grab_initial_focus() -> void:
	if visible:
		match current_tab_id:
			Tabs.GAMEPLAY: gameplay_btn.grab_focus()
			Tabs.DISPLAY: display_btn.grab_focus()
			Tabs.ELITE: elite_btn.grab_focus()
			Tabs.AUDIO, _: audio_btn.grab_focus()

func is_focus_in_content() -> bool:
	var focused = get_viewport().gui_get_focus_owner()
	if focused and focused is Control:
		if %AudioContentPanel.is_ancestor_of(focused) or %GameplayContentPanel.is_ancestor_of(focused) or %DisplayContentPanel.is_ancestor_of(focused) or %EliteContentPanel.is_ancestor_of(focused):
			return true
	return false

func _on_visibility_changed() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
	   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		if get_viewport().gui_get_focus_owner() == null:
			grab_initial_focus()
			get_viewport().set_input_as_handled()
		
	var is_cancel = false
	if event.is_action_pressed("ui_cancel"):
		is_cancel = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		is_cancel = true
		
	if is_cancel:
		if is_focus_in_content():
			grab_initial_focus()
			get_viewport().set_input_as_handled()
		else:
			_on_close_settings_button_pressed()
			get_viewport().set_input_as_handled()

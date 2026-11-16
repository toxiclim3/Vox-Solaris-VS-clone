class_name TestRoomUiAudio
extends TestRoomBase

var upgrade_keys: Array[String] = []
var current_up_idx: int = 0
var active_locale: String = "en"
var is_split_locale_view: bool = true

# UI containers
var cards_hbox: HBoxContainer = null
var current_item_lbl: Label = null
var locale_status_lbl: Label = null

# Focus visualizer
var show_focus_graph: bool = false
var focus_overlay: Control = null

# Audio deck
var music_mode_idx: int = 0 # 0: Normal, 1: Boss, 2: Title
var sfx_streams: Array[AudioStreamPlayer] = []
var audio_status_lbl: Label = null

func _get_room_title() -> String:
	return "UI, LOCALIZATION & AUDIO SOUNDBOARD"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "[ / ]", "desc": "Previous / Next Upgrade in Card Wall"},
		{"key": "L / Shift+L", "desc": "Cycle Locale (en/ru/ua) / Toggle 3-Locale Split vs Single View"},
		{"key": "N", "desc": "Toggle Rule 14 Focus-Neighbor Vector Graph"},
		{"key": "M", "desc": "Crossfade Music (Normal -> Boss -> Title)"},
		{"key": "P / X", "desc": "Trigger SFX Polyphony Burst (1 -> 10 -> 30 Streams)"}
	]

func _setup_room() -> void:
	# Gather all keys from UpgradeDb
	for k in UpgradeDb.UPGRADES.keys():
		if not k.ends_with("_endless"):
			upgrade_keys.append(k)

	_setup_card_wall()
	_setup_focus_visualizer()
	_setup_extra_topbar_buttons()

	_refresh_card_wall()

func _setup_card_wall() -> void:
	var root_panel := PanelContainer.new()
	root_panel.name = "CardWallPanel"
	root_panel.theme = load("res://Themes/DebugButtons.tres")
	root_panel.position = Vector2(-280, -110)
	root_panel.custom_minimum_size = Vector2(560, 220)
	add_child(root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(vbox)

	var h_info := HBoxContainer.new()
	vbox.add_child(h_info)

	current_item_lbl = Label.new()
	current_item_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	h_info.add_child(current_item_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_info.add_child(sp)

	locale_status_lbl = Label.new()
	locale_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	h_info.add_child(locale_status_lbl)

	cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards_hbox)

func _refresh_card_wall() -> void:
	if upgrade_keys.is_empty():
		return
	current_up_idx = posmod(current_up_idx, upgrade_keys.size())
	var up_id := upgrade_keys[current_up_idx]
	var data: Dictionary = UpgradeDb.UPGRADES[up_id]

	current_item_lbl.text = "Item: %s [%d/%d]" % [up_id, current_up_idx + 1, upgrade_keys.size()]
	locale_status_lbl.text = "Active Locale: %s | View: %s (L: Cycle | Shift+L: Toggle)" % [
		TranslationServer.get_locale(),
		"3-Locale Split" if is_split_locale_view else "Single Locale"
	]

	for c in cards_hbox.get_children():
		cards_hbox.remove_child(c)
		c.queue_free()

	# Create cards for EN, RU, UA (or single active locale)
	var card_nodes: Array[Control] = []
	var target_locales: Array = ["en", "ru", "ua"] if is_split_locale_view else [TranslationServer.get_locale()]
	for loc in target_locales:
		var card := _create_locale_card(data, loc)
		cards_hbox.add_child(card)
		card_nodes.append(card)

	# Wire Rule 14 horizontal focus navigation between the cards
	for i in range(card_nodes.size()):
		if i > 0:
			card_nodes[i].focus_neighbor_left = card_nodes[i].get_path_to(card_nodes[i - 1])
		if i < card_nodes.size() - 1:
			card_nodes[i].focus_neighbor_right = card_nodes[i].get_path_to(card_nodes[i + 1])

func _create_locale_card(data: Dictionary, loc: String) -> Control:
	var prev_loc := TranslationServer.get_locale()
	TranslationServer.set_locale(loc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 160)
	panel.focus_mode = Control.FOCUS_ALL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	sb.border_color = Color(0.3, 0.5, 0.8, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Loc badge
	var loc_lbl := Label.new()
	loc_lbl.text = "Locale: %s" % loc.to_upper()
	loc_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	vbox.add_child(loc_lbl)

	# Header (Icon + Name)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	header.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = tr(data.get("displayname", ""))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.4))
	header.add_child(name_lbl)

	# Details
	var desc_lbl := Label.new()
	desc_lbl.text = tr(data.get("details", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Overflow check
	var combined_len := desc_lbl.text.length()
	if combined_len > 110:
		var warn := Label.new()
		warn.text = "OVERFLOW RISK (%d chars)" % combined_len
		warn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		vbox.add_child(warn)

	TranslationServer.set_locale(prev_loc)
	return panel

func _setup_focus_visualizer() -> void:
	focus_overlay = Control.new()
	focus_overlay.name = "FocusGraphOverlay"
	focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(focus_overlay)
	focus_overlay.draw.connect(_on_draw_focus_graph)

func _on_draw_focus_graph() -> void:
	if not show_focus_graph or not focus_overlay:
		return

	var owner_ctrl := get_viewport().gui_get_focus_owner()
	if owner_ctrl and is_instance_valid(owner_ctrl) and owner_ctrl.is_visible_in_tree():
		var rect := owner_ctrl.get_global_rect()
		focus_overlay.draw_rect(rect, Color(1.0, 0.85, 0.2, 0.8), false, 2.0)

	# Scan focusable nodes
	var focusable: Array[Control] = []
	_collect_focusable(ui_layer, focusable)
	_collect_focusable(self, focusable)

	for c in focusable:
		if not c.is_visible_in_tree():
			continue
		var from_pt := c.get_global_position() + c.size * 0.5

		# Draw arrows to focus neighbors
		for neighbor_path in [c.focus_neighbor_left, c.focus_neighbor_right, c.focus_neighbor_top, c.focus_neighbor_bottom]:
			if neighbor_path.is_empty():
				continue
			var target := c.get_node_or_null(neighbor_path) as Control
			if target and is_instance_valid(target) and target.is_visible_in_tree():
				var to_pt: Vector2 = target.get_global_position() + target.size * 0.5
				focus_overlay.draw_line(from_pt, to_pt, Color(0.2, 0.9, 1.0, 0.6), 1.5)
				focus_overlay.draw_circle(to_pt, 3.0, Color(0.2, 0.9, 1.0, 0.8))

func _collect_focusable(node: Node, out_arr: Array[Control]) -> void:
	if node is Control:
		var c := node as Control
		if c.focus_mode != Control.FOCUS_NONE:
			out_arr.append(c)
	for child in node.get_children():
		_collect_focusable(child, out_arr)

func _setup_extra_topbar_buttons() -> void:
	var btn_prev := Button.new()
	btn_prev.text = "[ Prev"
	btn_prev.pressed.connect(func(): _cycle_item(-1))
	extra_buttons_bar.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "] Next"
	btn_next.pressed.connect(func(): _cycle_item(1))
	extra_buttons_bar.add_child(btn_next)

	var btn_loc := Button.new()
	btn_loc.text = "L Locale"
	btn_loc.pressed.connect(_cycle_locale)
	extra_buttons_bar.add_child(btn_loc)

	var btn_focus := Button.new()
	btn_focus.text = "N Focus Graph"
	btn_focus.pressed.connect(_toggle_focus_graph)
	extra_buttons_bar.add_child(btn_focus)

	var btn_music := Button.new()
	btn_music.text = "M Music"
	btn_music.pressed.connect(_cycle_music)
	extra_buttons_bar.add_child(btn_music)

	var btn_burst := Button.new()
	btn_burst.text = "P SFX Burst"
	btn_burst.pressed.connect(func(): _trigger_sfx_burst(10))
	extra_buttons_bar.add_child(btn_burst)

	audio_status_lbl = Label.new()
	audio_status_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	extra_buttons_bar.add_child(audio_status_lbl)

func _cycle_item(delta: int) -> void:
	current_up_idx = posmod(current_up_idx + delta, upgrade_keys.size())
	_refresh_card_wall()

func _cycle_locale() -> void:
	var cur := TranslationServer.get_locale()
	var next := "en"
	if cur == "en": next = "ru"
	elif cur == "ru": next = "ua"
	else: next = "en"
	TranslationServer.set_locale(next)
	_refresh_card_wall()

func _toggle_focus_graph() -> void:
	show_focus_graph = not show_focus_graph
	if focus_overlay:
		focus_overlay.queue_redraw()

func _cycle_music() -> void:
	music_mode_idx = (music_mode_idx + 1) % 3
	match music_mode_idx:
		0:
			MusicController.playNormalTrack()
			if audio_status_lbl: audio_status_lbl.text = "Music: Normal"
		1:
			MusicController.playBossTrack()
			if audio_status_lbl: audio_status_lbl.text = "Music: Boss"
		2:
			MusicController.playSpecificTrack(MusicController.titleMusic)
			if audio_status_lbl: audio_status_lbl.text = "Music: Title"

func _trigger_sfx_burst(count: int = 10) -> void:
	var sfx_res := load("res://Audio/SoundEffect/enemy_hit.ogg")
	if not sfx_res:
		sfx_res = load("res://Audio/SoundEffect/collectgem.mp3")

	for i in range(count):
		var p := AudioStreamPlayer.new()
		p.stream = sfx_res
		p.volume_db = -12.0
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()

	if audio_status_lbl:
		audio_status_lbl.text = "Burst: %d streams fired" % count

func _process(_delta: float) -> void:
	if show_focus_graph and focus_overlay:
		focus_overlay.queue_redraw()

func _toggle_locale_view_mode() -> void:
	is_split_locale_view = not is_split_locale_view
	_refresh_card_wall()

func _handle_room_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_BRACKETLEFT:
			_cycle_item(-1)
			return true
		KEY_BRACKETRIGHT:
			_cycle_item(1)
			return true
		KEY_L:
			if event.shift_pressed:
				_toggle_locale_view_mode()
			else:
				_cycle_locale()
			return true
		KEY_N:
			_toggle_focus_graph()
			return true
		KEY_M:
			_cycle_music()
			return true
		KEY_P, KEY_X:
			_trigger_sfx_burst(10)
			return true

	return false

func _reset_room_state() -> void:
	current_up_idx = 0
	TranslationServer.set_locale("en")
	is_split_locale_view = true
	show_focus_graph = false
	if focus_overlay:
		focus_overlay.queue_redraw()
	_refresh_card_wall()

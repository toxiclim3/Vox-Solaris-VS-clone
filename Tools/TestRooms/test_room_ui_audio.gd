class_name TestRoomUiAudio
extends TestRoomBase

const ItemOptionScene = preload("res://Utility/item_option.tscn")

var upgrade_keys: Array[String] = []
var current_up_idx: int = 0
var active_locale: String = "en"
var is_split_locale_view: bool = true

# UI containers
var cards_hbox: HBoxContainer = null
var current_item_lbl: Label = null
var locale_status_lbl: Label = null
var btn_view_mode: Button = null

# Focus visualizer
var show_focus_graph: bool = false
var focus_overlay: Control = null

# Audio deck & Music Player modal
var music_mode_idx: int = 0 # 0: Normal, 1: Boss, 2: Title
var sfx_streams: Array[AudioStreamPlayer] = []
var audio_status_lbl: Label = null
var music_modal: PanelContainer = null
var music_now_lbl: Label = null
var music_list_vbox: VBoxContainer = null

func _get_room_title() -> String:
	return "UI, LOCALIZATION & AUDIO SOUNDBOARD"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "[ / ]", "desc": "Previous / Next Upgrade in Card Wall"},
		{"key": "L / Shift+L", "desc": "Cycle Locale (en/ru/ua) / Toggle 3-Locale Split vs Single View"},
		{"key": "N", "desc": "Toggle Rule 14 Focus-Neighbor Vector Graph"},
		{"key": "M", "desc": "Open / Close Music Player Modal"},
		{"key": "P / X", "desc": "Trigger SFX Polyphony Burst (10 Streams)"}
	]

func _setup_room() -> void:
	# Gather all keys from UpgradeDb
	for k in UpgradeDb.UPGRADES.keys():
		if not k.ends_with("_endless"):
			upgrade_keys.append(k)

	_setup_card_wall()
	_setup_music_modal()
	_setup_focus_visualizer()
	_setup_extra_topbar_buttons()

	_refresh_card_wall()

func _setup_card_wall() -> void:
	var root_panel := PanelContainer.new()
	root_panel.name = "CardWallPanel"
	root_panel.theme = load("res://Themes/DebugButtons.tres")
	root_panel.set_anchors_preset(Control.PRESET_CENTER)
	root_panel.offset_left = -295.0
	root_panel.offset_top = -125.0
	root_panel.offset_right = 295.0
	root_panel.offset_bottom = 145.0
	ui_layer.add_child(root_panel)

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

	current_item_lbl.text = "Item: %s [%d/%d]" % [up_id, current_up_idx + 1, upgrade_keys.size()]
	locale_status_lbl.text = "Locale: %s | View: %s" % [
		TranslationServer.get_locale().to_upper(),
		"3-Locale Split" if is_split_locale_view else "Single Locale"
	]
	if btn_view_mode:
		btn_view_mode.text = "View: Split" if is_split_locale_view else "View: Single"

	for c in cards_hbox.get_children():
		cards_hbox.remove_child(c)
		c.queue_free()

	# Create real ItemOption cards for EN, RU, UA (or single active locale)
	var focus_targets: Array[Control] = []
	var target_locales: Array = ["en", "ru", "ua"] if is_split_locale_view else [TranslationServer.get_locale()]
	for loc in target_locales:
		var slot := _create_locale_card(up_id, loc)
		cards_hbox.add_child(slot["container"])
		focus_targets.append(slot["card"])

	# Wire Rule 14 horizontal focus navigation between the ItemOption cards
	for i in range(focus_targets.size()):
		if i > 0:
			focus_targets[i].focus_neighbor_left = focus_targets[i].get_path_to(focus_targets[i - 1])
		if i < focus_targets.size() - 1:
			focus_targets[i].focus_neighbor_right = focus_targets[i].get_path_to(focus_targets[i + 1])

func _create_locale_card(up_id: String, loc: String) -> Dictionary:
	var prev_loc := TranslationServer.get_locale()
	TranslationServer.set_locale(loc)

	var col_vbox := VBoxContainer.new()
	col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_theme_constant_override("separation", 3)

	var loc_lbl := Label.new()
	loc_lbl.text = "Locale: %s" % loc.to_upper()
	loc_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	col_vbox.add_child(loc_lbl)

	var card := ItemOptionScene.instantiate() as PanelContainer
	card.item = up_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_child(card)

	TranslationServer.set_locale(prev_loc)
	return {"container": col_vbox, "card": card}

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

	btn_view_mode = Button.new()
	btn_view_mode.text = "View: Split"
	btn_view_mode.pressed.connect(_toggle_locale_view_mode)
	extra_buttons_bar.add_child(btn_view_mode)

	var btn_focus := Button.new()
	btn_focus.text = "N Focus"
	btn_focus.pressed.connect(_toggle_focus_graph)
	extra_buttons_bar.add_child(btn_focus)

	var btn_music := Button.new()
	btn_music.text = "M Music"
	btn_music.pressed.connect(_toggle_music_modal)
	extra_buttons_bar.add_child(btn_music)

	var btn_burst := Button.new()
	btn_burst.text = "P SFX"
	btn_burst.pressed.connect(func(): _trigger_sfx_burst(10))
	extra_buttons_bar.add_child(btn_burst)

	audio_status_lbl = Label.new()
	audio_status_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	extra_buttons_bar.add_child(audio_status_lbl)

func _cycle_item(delta: int) -> void:
	current_up_idx = posmod(current_up_idx + delta, upgrade_keys.size())
	_refresh_card_wall()

func _cycle_locale() -> void:
	is_split_locale_view = false
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

func _setup_music_modal() -> void:
	music_modal = PanelContainer.new()
	music_modal.name = "MusicPlayerModal"
	music_modal.theme = load("res://Themes/DebugButtons.tres")
	music_modal.visible = false
	music_modal.z_index = 120
	music_modal.set_anchors_preset(Control.PRESET_CENTER)
	music_modal.offset_left = -230.0
	music_modal.offset_top = -130.0
	music_modal.offset_right = 230.0
	music_modal.offset_bottom = 130.0
	ui_layer.add_child(music_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	music_modal.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "MUSIC PLAYER (M)"
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	hdr.add_child(title)

	music_now_lbl = Label.new()
	music_now_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_now_lbl.clip_text = true
	music_now_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	hdr.add_child(music_now_lbl)

	var btn_x := Button.new()
	btn_x.text = "X"
	btn_x.focus_mode = Control.FOCUS_NONE
	btn_x.pressed.connect(func(): music_modal.visible = false)
	hdr.add_child(btn_x)

	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 4)
	vbox.add_child(ctrl_row)

	var b_norm := Button.new()
	b_norm.text = "Next Normal"
	b_norm.focus_mode = Control.FOCUS_NONE
	b_norm.pressed.connect(func(): _play_music_pool(MusicController.MusicType.NORMAL))
	ctrl_row.add_child(b_norm)

	var b_boss := Button.new()
	b_boss.text = "Next Boss"
	b_boss.focus_mode = Control.FOCUS_NONE
	b_boss.pressed.connect(func(): _play_music_pool(MusicController.MusicType.BOSS))
	ctrl_row.add_child(b_boss)

	var b_title := Button.new()
	b_title.text = "Title Track"
	b_title.focus_mode = Control.FOCUS_NONE
	b_title.pressed.connect(func(): _play_specific_track(MusicController.titleMusic))
	ctrl_row.add_child(b_title)

	var b_mute := Button.new()
	b_mute.text = "Mute/Unmute"
	b_mute.focus_mode = Control.FOCUS_NONE
	b_mute.pressed.connect(func():
		if MusicController.isMusicMuted:
			MusicController.fadeInFromSilence()
		else:
			MusicController.fadeOutToSilence()
		_refresh_music_status()
	)
	ctrl_row.add_child(b_mute)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	music_list_vbox = VBoxContainer.new()
	music_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(music_list_vbox)

	_populate_music_tracks()

func _populate_music_tracks() -> void:
	if music_list_vbox == null:
		return
	for ch in music_list_vbox.get_children():
		ch.queue_free()

	var pools := [
		["NORMAL TRACKS", MusicController.normalTracks],
		["BOSS TRACKS", MusicController.bossTracks],
		["EXTRA TRACKS", MusicController.extraTracks],
	]
	for p in pools:
		var lbl := Label.new()
		lbl.text = "— %s —" % p[0]
		lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		music_list_vbox.add_child(lbl)

		var tracks: Array = p[1]
		for track_path in tracks:
			var tp := str(track_path)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			music_list_vbox.add_child(row)

			var b_play := Button.new()
			b_play.text = "Play"
			b_play.focus_mode = Control.FOCUS_NONE
			b_play.pressed.connect(func(): _play_specific_track(tp))
			row.add_child(b_play)

			var t_lbl := Label.new()
			t_lbl.text = tp.get_file()
			t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t_lbl.clip_text = true
			row.add_child(t_lbl)

func _toggle_music_modal() -> void:
	if music_modal == null:
		return
	music_modal.visible = not music_modal.visible
	if music_modal.visible:
		_refresh_music_status()

func _play_specific_track(track_path: String) -> void:
	if MusicController.is_audio_functional:
		MusicController.unlockMusic()
		if MusicController.isMusicMuted:
			MusicController.fadeInFromSilence()
		MusicController.playSpecificTrack(track_path)
	_refresh_music_status(track_path.get_file())

func _play_music_pool(mtype: int) -> void:
	if MusicController.is_audio_functional:
		MusicController.unlockMusic()
		if MusicController.isMusicMuted:
			MusicController.fadeInFromSilence()
		MusicController.playNext(mtype)
	_refresh_music_status()

func _refresh_music_status(fallback_name: String = "") -> void:
	var track_name := fallback_name
	if track_name == "" and MusicController.activePlayer and MusicController.activePlayer.stream:
		track_name = MusicController.activePlayer.stream.resource_path.get_file()
	if track_name == "":
		track_name = "(none)"
	var mute_txt := " [MUTED]" if MusicController.isMusicMuted else ""
	if music_now_lbl:
		music_now_lbl.text = "Now: %s%s" % [track_name, mute_txt]
	if audio_status_lbl:
		audio_status_lbl.text = "Music: %s%s" % [track_name.left(18), mute_txt]

func _cycle_music() -> void:
	music_mode_idx = (music_mode_idx + 1) % 3
	match music_mode_idx:
		0:
			_play_music_pool(MusicController.MusicType.NORMAL)
		1:
			_play_music_pool(MusicController.MusicType.BOSS)
		2:
			_play_specific_track(MusicController.titleMusic)

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

func _has_open_modal() -> bool:
	if super._has_open_modal():
		return true
	if music_modal and music_modal.visible:
		return true
	return false

func _close_room_modals() -> void:
	if music_modal and music_modal.visible:
		music_modal.visible = false

func _handle_room_key(event: InputEventKey) -> bool:
	match DebugController.get_effective_keycode(event):
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
			_toggle_music_modal()
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

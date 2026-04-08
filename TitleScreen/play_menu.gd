extends PanelContainer

signal play_menu_closed
signal start_run_requested
signal edit_custom_requested

@onready var btn_difficulty = %btn_difficulty
@onready var btn_custom_difficulty = %btn_custom_difficulty

@onready var character_grid = %CharacterGrid
@onready var label_char_details = %LabelCharDetails

var character_buttons: Dictionary = {}

func _ready():
	_update_difficulty_buttons()
	_setup_character_grid()

func _setup_character_grid() -> void:
	if not character_grid: return
	for child in character_grid.get_children():
		child.queue_free()
		
	for char_id in GlobalEvents.CHARACTERS.keys():
		var char_data = GlobalEvents.CHARACTERS[char_id]
		
		var style_btn = Button.new()
		style_btn.custom_minimum_size = Vector2(40, 40)
		
		if char_data.has("icon"):
			var base_tex = load(char_data["icon"]) as Texture2D
			if base_tex:
				var atlas = AtlasTexture.new()
				atlas.atlas = base_tex
				# hframes = 2, frame = 1
				var frame_width = base_tex.get_width() / 2
				atlas.region = Rect2(frame_width, 0, frame_width, base_tex.get_height())
				style_btn.icon = atlas
				
		style_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		style_btn.expand_icon = true
		style_btn.modulate = char_data.get("icon_color", Color(1, 1, 1))
		
		style_btn.pressed.connect(_on_character_button_pressed.bind(char_id))
		style_btn.mouse_entered.connect(_on_character_hovered.bind(char_id))
		style_btn.mouse_exited.connect(_on_character_hover_exited)
		
		character_grid.add_child(style_btn)
		character_buttons[char_id] = style_btn
		
	# Select starting character visually
	var start_char = GlobalEvents.selected_character
	if not character_buttons.has(start_char) and character_buttons.size() > 0:
		start_char = GlobalEvents.CHARACTERS.keys()[0]
		GlobalEvents.selected_character = start_char
		
	_update_selected_character_visuals(start_char)

func _on_character_button_pressed(char_id: String) -> void:
	GlobalEvents.selected_character = char_id
	_update_selected_character_visuals(char_id)

func _on_character_hovered(char_id: String) -> void:
	_show_char_details(char_id)

func _on_character_hover_exited() -> void:
	_show_char_details(GlobalEvents.selected_character)

func _show_char_details(char_id: String) -> void:
	if label_char_details and GlobalEvents.CHARACTERS.has(char_id):
		var data = GlobalEvents.CHARACTERS[char_id]
		var text = tr(data["displayname"])
		if data.has("details") and data["details"] != "":
			text += "\n" + tr(data["details"])
		label_char_details.text = text

func _update_selected_character_visuals(selected_id: String) -> void:
	for char_id in character_buttons:
		var btn: Button = character_buttons[char_id]
		if char_id == selected_id:
			btn.self_modulate = Color(1.5, 1.5, 1.5) # Highlight selected with brighter color
		else:
			btn.self_modulate = Color(0.6, 0.6, 0.6) # Dim unselected
			
	_show_char_details(selected_id)

func _update_difficulty_buttons() -> void:
	if btn_difficulty:
		btn_difficulty.text = GlobalEvents.get_difficulty_name()
	if btn_custom_difficulty:
		if GlobalEvents.current_difficulty == GlobalEvents.Difficulty.CUSTOM:
			btn_custom_difficulty.show()
		else:
			btn_custom_difficulty.hide()

func update_menu_state() -> void:
	_update_difficulty_buttons()

func _on_close_play_menu_button_pressed() -> void:
	emit_signal("play_menu_closed")

func _on_btn_difficulty_click_end() -> void:
	GlobalEvents.next_difficulty()
	_update_difficulty_buttons()

func _on_btn_custom_difficulty_click_end() -> void:
	emit_signal("edit_custom_requested")

func _on_btn_start_run_click_end() -> void:
	emit_signal("start_run_requested")

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
		
		style_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		style_btn.expand_icon = true
		style_btn.theme = preload("res://Themes/Buttons.tres")

		# Use a child TextureRect for the icon so we can apply the recolor shader 
		# without affecting the button's background/border.
		if char_data.has("icon"):
			var icon_rect = TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			
			var base_tex = load(char_data["icon"]) as Texture2D
			if base_tex:
				var atlas = AtlasTexture.new()
				atlas.atlas = base_tex
				var frame_width = base_tex.get_width() / 2
				atlas.region = Rect2(frame_width, 0, frame_width, base_tex.get_height())
				icon_rect.texture = atlas
				
			var mat = ShaderMaterial.new()
			mat.shader = load("res://Utility/recolor.gdshader")
			
			var target_color = char_data.get("icon_color", Color(1, 1, 1))
			mat.set_shader_parameter("target_color", target_color)
			
			# Apply character-specific shader configs
			if char_data.has("shader_config"):
				var config = char_data["shader_config"]
				for key in config:
					mat.set_shader_parameter(key, config[key])
					
			icon_rect.material = mat
			style_btn.add_child(icon_rect)
			
			# Clear the standard icon
			style_btn.icon = null
		
		style_btn.pressed.connect(_on_character_button_pressed.bind(char_id))
		style_btn.mouse_entered.connect(_on_character_hovered.bind(char_id))
		style_btn.mouse_exited.connect(_on_character_hover_exited)
		style_btn.focus_entered.connect(_on_character_hovered.bind(char_id))
		style_btn.focus_exited.connect(_on_character_hover_exited)
		
		character_grid.add_child(style_btn)
		character_buttons[char_id] = style_btn
		
	# Select starting character visually
	var start_char = GlobalEvents.selected_character
	if not character_buttons.has(start_char) and character_buttons.size() > 0:
		start_char = GlobalEvents.CHARACTERS.keys()[0]
		GlobalEvents.selected_character = start_char
		
	_update_selected_character_visuals(start_char)
	
	# Explicitly wire Left/Right internally to bypass overlap/spatial issues inside the grid
	var chars = character_grid.get_children()
	for i in range(chars.size()):
		var btn = chars[i]
		if i > 0:
			btn.focus_neighbor_left = btn.get_path_to(chars[i - 1])
		if i < chars.size() - 1:
			btn.focus_neighbor_right = btn.get_path_to(chars[i + 1])

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

func grab_initial_focus() -> void:
	if %btn_start_run:
		%btn_start_run.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
	   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		if get_viewport().gui_get_focus_owner() == null:
			grab_initial_focus()
			get_viewport().set_input_as_handled()
			return

	var focus_owner = get_viewport().gui_get_focus_owner()
	
	if focus_owner and character_grid and character_grid.is_ancestor_of(focus_owner):
		if event.is_action_pressed("ui_left"):
			var idx = focus_owner.get_index()
			if idx > 0:
				character_grid.get_child(idx - 1).grab_focus()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			var idx = focus_owner.get_index()
			if idx < character_grid.get_child_count() - 1:
				character_grid.get_child(idx + 1).grab_focus()
				get_viewport().set_input_as_handled()
			else:
				if btn_difficulty:
					btn_difficulty.grab_focus()
					get_viewport().set_input_as_handled()

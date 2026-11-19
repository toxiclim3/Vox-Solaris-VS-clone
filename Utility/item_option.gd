extends PanelContainer

const TARGETING_BADGES: Dictionary = {
	"target_closest": "res://Textures/GUI/Badges/badge_target_closest.png",
	"target_frontal": "res://Textures/GUI/Badges/badge_target_frontal.png",
	"target_crowd": "res://Textures/GUI/Badges/badge_target_crowd.png",
	"target_strongest": "res://Textures/GUI/Badges/badge_target_strongest.png",
	"target_direction": "res://Textures/GUI/Badges/badge_target_direction.png",
	"target_random": "res://Textures/GUI/Badges/badge_target_random.png",
}

@onready var lblName: Label = $MarginContainer/VBoxContainer/lbl_name
@onready var lblLevel: Label = $MarginContainer/VBoxContainer/lbl_level
@onready var lblDescription: Label = $MarginContainer/VBoxContainer/lbl_description
@onready var iconPanel: PanelContainer = $MarginContainer/VBoxContainer/IconPanel
@onready var itemIcon: TextureRect = $MarginContainer/VBoxContainer/IconPanel/ItemIcon
@onready var divider: ColorRect = $MarginContainer/VBoxContainer/Divider
@onready var badgeRow: HBoxContainer = $MarginContainer/VBoxContainer/BadgeRow
@onready var targetingBadge: TextureRect = $MarginContainer/VBoxContainer/BadgeRow/TargetingBadge
@onready var lblTargeting: Label = $MarginContainer/VBoxContainer/BadgeRow/lbl_targeting
@onready var focusFrame: Panel = $FocusFrame
@onready var sndHover: AudioStreamPlayer = get_node_or_null("snd_hover")
@onready var sndClick: AudioStreamPlayer = get_node_or_null("snd_click")

@export var default_style: ItemCardStyle
@export var category_styles: Dictionary = {}
@export var endless_level_color: Color = Color(0.86, 0.72, 1.0, 1.0)
@export var endless_border_color: Color = Color(0.76, 0.58, 1.0, 0.92)

var mouse_over: bool = false
var _is_selected: bool = false
var item = null
var card_category: String = ""
var is_endless_card: bool = false
@onready var player = get_tree().get_first_node_in_group("player")

signal selected_upgrade(upgrade)

@export var padding: int = 8
var original_name_font_size: int = -1

func _ready():
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("focus_entered", _on_focus_entered)
	connect("focus_exited", _on_focus_exited)
	connect("resized", scale_name_to_fit)
	if targetingBadge:
		targetingBadge.mouse_exited.connect(_on_mouse_exited)
	if player:
		connect("selected_upgrade", Callable(player, "upgrade_character"))
	
	focus_mode = FOCUS_ALL
	if item == null:
		item = "food"
	lblName.text = tr(UpgradeDb.UPGRADES[item]["displayname"])
	
	if item.ends_with("_endless"):
		var base_name = item.trim_suffix("_endless")
		var count = (player.collected_endless.get(base_name, 0) if player else 0) + 1
		lblLevel.text = "∞ (+" + str(count) + ")"
		
		# Display specific scaling info
		var scaling_info = _get_stat_description(UpgradeDb.UPGRADES[item].get("stat_modifiers", {}))
		if scaling_info != "":
			lblDescription.text = tr("ui_scaling_prefix") + " " + scaling_info
		else:
			lblDescription.text = tr(UpgradeDb.UPGRADES[item]["details"])
	else:
		lblDescription.text = tr(UpgradeDb.UPGRADES[item]["details"])
		lblLevel.text = tr(UpgradeDb.UPGRADES[item]["level"])

	_update_targeting_badge()
	_apply_card_style()
	itemIcon.texture = load(UpgradeDb.UPGRADES[item]["icon"])
	
	original_name_font_size = lblName.get_theme_font_size("font_size")
	if original_name_font_size <= 0:
		original_name_font_size = 14
			
	scale_name_to_fit()
	call_deferred("scale_name_to_fit")

func _update_targeting_badge() -> void:
	if not lblTargeting or not targetingBadge or not badgeRow:
		return
	var targeting_key: String = UpgradeDb.UPGRADES.get(item, {}).get("targeting", "")
	if targeting_key != "":
		var localized_target := tr(targeting_key)
		lblTargeting.text = "[" + localized_target + "]"
		lblTargeting.visible = true
		var badge_path: String = TARGETING_BADGES.get(targeting_key, "")
		if badge_path != "" and ResourceLoader.exists(badge_path):
			targetingBadge.texture = load(badge_path)
			targetingBadge.tooltip_text = localized_target
			targetingBadge.visible = true
		else:
			targetingBadge.texture = null
			targetingBadge.tooltip_text = ""
			targetingBadge.visible = false
		badgeRow.visible = true
	else:
		lblTargeting.text = ""
		lblTargeting.visible = false
		targetingBadge.texture = null
		targetingBadge.tooltip_text = ""
		targetingBadge.visible = false
		badgeRow.visible = false

func on_font_size_bumped(amount: int) -> void:
	if original_name_font_size > 0:
		original_name_font_size += amount
	call_deferred("scale_name_to_fit")

func is_item_endless(item_id: String) -> bool:
	return item_id.ends_with("_endless") or str(UpgradeDb.UPGRADES.get(item_id, {}).get("type", "")) == "endless"

func _walk_prerequisite_chain(item_id: String) -> Array[Dictionary]:
	var chain: Array[Dictionary] = []
	var visited: Dictionary = {}
	var current_id := item_id
	while current_id != "" and not visited.has(current_id) and UpgradeDb.UPGRADES.has(current_id):
		visited[current_id] = true
		var entry: Dictionary = UpgradeDb.UPGRADES[current_id]
		chain.append(entry)
		var prereqs: Array = entry.get("prerequisite", [])
		current_id = str(prereqs[0]) if not prereqs.is_empty() else ""
	return chain

func resolve_base_category(item_id: String) -> String:
	for entry in _walk_prerequisite_chain(item_id):
		var entry_type := str(entry.get("type", ""))
		if entry_type == "" or entry_type == "endless":
			continue
		if entry_type == "bossitem":
			return "boss_weapon" if str(entry.get("targeting", "")) != "" else "boss_accessory"
		return entry_type
	return ""

func resolve_card_category(item_id: String) -> String:
	for entry in _walk_prerequisite_chain(item_id):
		var custom_cat := str(entry.get("category", ""))
		if custom_cat != "":
			return custom_cat
	return resolve_base_category(item_id)

func resolve_card_style(item_id: String) -> ItemCardStyle:
	var card_cat := resolve_card_category(item_id)
	var custom_style = category_styles.get(card_cat)
	if custom_style is ItemCardStyle:
		return custom_style
	var base_cat := resolve_base_category(item_id)
	var base_style = category_styles.get(base_cat)
	if base_style is ItemCardStyle:
		return base_style
	if base_cat.begins_with("boss_"):
		var boss_style = category_styles.get("bossitem")
		if boss_style is ItemCardStyle:
			return boss_style
	return default_style

func _apply_card_style() -> void:
	var item_id := str(item) if item != null else ""
	card_category = resolve_card_category(item_id)
	is_endless_card = is_item_endless(item_id)
	var style := resolve_card_style(item_id)
	var endless_divider_color := Color(endless_border_color.r, endless_border_color.g, endless_border_color.b, 0.55)

	if style == null:
		if is_endless_card:
			lblLevel.add_theme_color_override("font_color", endless_level_color)
			if divider:
				divider.color = endless_divider_color
		return

	if style.card_panel != null:
		if is_endless_card and style.card_panel is StyleBoxFlat:
			var endless_panel := style.card_panel.duplicate() as StyleBoxFlat
			endless_panel.border_color = endless_border_color
			var endless_width := maxi(endless_panel.border_width_left, 2)
			endless_panel.border_width_left = endless_width
			endless_panel.border_width_top = endless_width
			endless_panel.border_width_right = endless_width
			endless_panel.border_width_bottom = endless_width
			add_theme_stylebox_override("panel", endless_panel)
		else:
			add_theme_stylebox_override("panel", style.card_panel)

	if focusFrame and style.focus_panel != null:
		focusFrame.add_theme_stylebox_override("panel", style.focus_panel)

	if iconPanel:
		if style.icon_frame_theme != null:
			iconPanel.theme = style.icon_frame_theme
		iconPanel.self_modulate = style.icon_frame_modulate

	lblName.add_theme_color_override("font_color", style.name_color)
	lblLevel.add_theme_color_override("font_color", endless_level_color if is_endless_card else style.level_color)
	if divider:
		divider.color = endless_divider_color if is_endless_card else style.divider_color
	lblDescription.add_theme_color_override("font_color", style.description_color)
	lblTargeting.add_theme_color_override("font_color", style.targeting_color)

func _get_stat_description(stat_modifiers: Dictionary) -> String:
	var descriptions = []
	for stat_name in stat_modifiers:
		var val = stat_modifiers[stat_name]
		# Normalize stat name for translation keys
		var clean_name = stat_name.replace("_percent", "")
		var label = tr("stat_" + clean_name)
		var val_str = ""
		
		# Detect percentages (anything between -1.0 and 1.0 that isn't 0 and is float)
		if typeof(val) == TYPE_FLOAT and abs(val) < 1.0 and val != 0:
			val_str = "+" + str(int(val * 100)) + "%"
		else:
			val_str = "+" + str(val)
			
		descriptions.append(val_str + " " + label)
	
	var result = ""
	for i in range(descriptions.size()):
		result += descriptions[i]
		if i < descriptions.size() - 1:
			result += ", "
	return result

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready() and item != null and UpgradeDb.UPGRADES.has(item):
			lblName.text = tr(UpgradeDb.UPGRADES[item]["displayname"])
			_update_targeting_badge()
		call_deferred("scale_name_to_fit")

func scale_name_to_fit():
	if original_name_font_size <= 0:
		return
		
	var font = lblName.get_theme_font("font")
	if not font: return
	
	var text_to_check = lblName.text
	var parent_ctrl = lblName.get_parent() as Control
	var available_width: float
	if parent_ctrl and parent_ctrl.size.x > 0.0:
		available_width = parent_ctrl.size.x - padding
	else:
		available_width = custom_minimum_size.x - 12.0 - padding
	if available_width <= 0:
		return
	
	var current_size = original_name_font_size
	var text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
	
	while text_size.x > available_width and current_size > 8:
		current_size -= 1
		text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
		
	lblName.add_theme_font_size_override("font_size", current_size)

func _update_highlight() -> void:
	if focusFrame:
		focusFrame.visible = has_focus() or mouse_over

func _on_mouse_entered():
	var was_highlighted := focusFrame.visible if focusFrame else false
	mouse_over = true
	_update_highlight()
	if not was_highlighted and sndHover:
		sndHover.play()

func _on_mouse_exited():
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	mouse_over = false
	_update_highlight()

func _on_focus_entered():
	var was_highlighted := focusFrame.visible if focusFrame else false
	_update_highlight()
	if not was_highlighted and sndHover:
		sndHover.play()

func _on_focus_exited():
	_update_highlight()

func _gui_input(event):
	if _is_selected:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
		_is_selected = true
		if sndClick:
			sndClick.play()
		accept_event()
		emit_signal("selected_upgrade", item)

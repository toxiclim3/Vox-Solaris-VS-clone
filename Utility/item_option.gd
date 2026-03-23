extends PanelContainer

@onready var lblName = $MarginContainer/VBoxContainer/HBoxContainer/lbl_name
@onready var lblDescription = $MarginContainer/VBoxContainer/HBoxContainer2/lbl_description
@onready var lblLevel = $MarginContainer/VBoxContainer/HBoxContainer/lbl_level
@onready var itemIcon = $MarginContainer/VBoxContainer/HBoxContainer/ColorRect/ItemIcon

var mouse_over = false
var item = null
@onready var player = get_tree().get_first_node_in_group("player")

signal selected_upgrade(upgrade)

@export var padding: int = 8
var original_name_font_size: int = -1

func _ready():
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("selected_upgrade",Callable(player,"upgrade_character"))
	if item == null:
		item = "food"
	lblName.text = tr(UpgradeDb.UPGRADES[item]["displayname"])
	lblDescription.text = tr(UpgradeDb.UPGRADES[item]["details"])
	lblLevel.text = tr(UpgradeDb.UPGRADES[item]["level"])
	itemIcon.texture = load(UpgradeDb.UPGRADES[item]["icon"])
	
	if lblName.has_theme_font_size_override("font_size"):
		original_name_font_size = lblName.get_theme_font_size("font_size")
	else:
		if lblName.theme:
			original_name_font_size = lblName.theme.get_font_size("font_size", "Label")
		if original_name_font_size <= 0:
			original_name_font_size = 16
			
	scale_name_to_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		scale_name_to_fit()

func scale_name_to_fit():
	if original_name_font_size <= 0:
		return
		
	var font = lblName.get_theme_font("font")
	if not font: return
	
	var text_to_check = lblName.text
	var available_width = lblName.size.x - padding
	
	var current_size = original_name_font_size
	var text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
	
	while text_size.x > available_width and current_size > 8:
		current_size -= 1
		text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
		
	lblName.add_theme_font_size_override("font_size", current_size)
	
func _input(event):
	if event.is_action("click"):
		if mouse_over:
			emit_signal("selected_upgrade",item)

func _on_mouse_entered():
	mouse_over = true

func _on_mouse_exited():
	mouse_over = false

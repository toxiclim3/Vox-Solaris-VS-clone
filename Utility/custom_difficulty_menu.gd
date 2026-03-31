extends PanelContainer

signal difficulty_custom_closed

@onready var line_edit_spawn_rate = %LineEdit_SpawnRate
@onready var line_edit_enemy_hp = %LineEdit_EnemyHP
@onready var line_edit_boss_hp = %LineEdit_BossHP
@onready var line_edit_player_damage = %LineEdit_PlayerDamage
@onready var line_edit_player_regen = %LineEdit_PlayerRegen
@onready var line_edit_xp_gain = %LineEdit_XPGain

func _ready():
	line_edit_spawn_rate.text = str(GlobalEvents.custom_enemy_spawn_modifier)
	line_edit_enemy_hp.text = str(GlobalEvents.custom_enemy_hp_modifier)
	line_edit_boss_hp.text = str(GlobalEvents.custom_boss_hp_modifier)
	line_edit_player_damage.text = str(GlobalEvents.custom_player_damage_modifier)
	line_edit_player_regen.text = str(GlobalEvents.custom_player_regen_modifier)
	line_edit_xp_gain.text = str(GlobalEvents.custom_xp_gain_modifier)

func _on_close_settings_button_pressed():
	emit_signal("difficulty_custom_closed")

func _on_line_edit_spawn_rate_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_enemy_spawn_modifier = new_text.to_float()

func _on_line_edit_enemy_hp_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_enemy_hp_modifier = new_text.to_float()

func _on_line_edit_boss_hp_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_boss_hp_modifier = new_text.to_float()

func _on_line_edit_player_damage_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_player_damage_modifier = new_text.to_float()

func _on_line_edit_player_regen_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_player_regen_modifier = new_text.to_float()

func _on_line_edit_xp_gain_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		GlobalEvents.custom_xp_gain_modifier = new_text.to_float()

extends Node2D

@export var relic_rocket_scene = preload("res://Player/Attack/RelicDrone/RelicRocket.tscn")

var level = 0
var proc_chance = 0.02 # 2% base
var damage_mult = 2.0 # 200% base

@onready var player = get_tree().get_first_node_in_group("player")
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer

var follow_offset = Vector2(-15, -15)
var follow_speed = 5.0

func _ready():
	# Make drone independent of player transform for smoother follow logic
	top_level = true
	GlobalEvents.player_dealt_damage.connect(_on_player_dealt_damage)
	
	if player:
		global_position = player.global_position + follow_offset

	# Drone idle animation
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _process(delta):
	if not is_instance_valid(player): return
	
	# Determine target position (floats behind/beside player)
	var target_pos = player.global_position + follow_offset * player.sprite.scale.x
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Flip sprite based on player direction
	if player.velocity.x > 1:
		sprite.flip_h = false
	elif player.velocity.x < -1:
		sprite.flip_h = true

func _on_player_dealt_damage(amount, target_node, coefficient):
	# Check if player has the drone (managed by player.gd upgrade system)
	if level <= 0: return
	
	# Proc Chance calculation
	var effective_chance = proc_chance * coefficient
	if randf() <= effective_chance:
		spawn_rocket(amount * damage_mult, target_node)

func spawn_rocket(damage_to_deal, target):
	var rocket = relic_rocket_scene.instantiate()
	rocket.global_position = global_position
	rocket.damage = damage_to_deal
	rocket.target_node = target
	
	# Add to world/level root so it's independent of the drone/player
	get_tree().root.add_child(rocket)

func update_stats():
	# Sync stats from Level
	match level:
		1:
			proc_chance = 0.02
			damage_mult = 2.0
		2:
			proc_chance = 0.04
			damage_mult = 3.0

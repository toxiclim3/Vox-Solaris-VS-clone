extends Node2D

class SwarmEnemy:
	var position: Vector2
	var global_position: Vector2:
		get:
			return position
		set(val):
			position = val
	var max_hp: float
	var hp: float
	var speed: float
	var knockback: Vector2 = Vector2.ZERO
	var experience: int = 1
	var damage: int = 1
	var type_id: int
	var death_timer: float = 0.0
	var is_dead: bool = false
	var swarm_manager_ref = null
	var separation: Vector2 = Vector2.ZERO
	var anim_offset: float = 0.0
	var active_debuffs: Dictionary = {}

	func is_alive() -> bool:
		return not is_dead

	func apply_debuff(debuff_name: String, value: float, duration: float):
		active_debuffs[debuff_name] = {"value": value, "duration": duration}

	func get_debuff_value(debuff_name: String) -> float:
		if active_debuffs.has(debuff_name):
			return active_debuffs[debuff_name]["value"]
		return 0.0

	func has_debuff(debuff_name: String) -> bool:
		return active_debuffs.has(debuff_name)


	func _on_hurt_box_hurt(_dmg, _angle, _kb, _source = "", _attacker_node = null):
		hp -= _dmg
		if hp <= 0 and not is_dead:
			if swarm_manager_ref:
				swarm_manager_ref._handle_death(self, _source)

var swarm_data: Array[SwarmEnemy] = []
var spatial_grid: Dictionary = {}
var max_enemy_radius: float = 24.0

# Map of type_id to cache structures
# cache: { texture: Texture2D, multimesh_idx: int, radius_sq: float }
var enemy_type_cache = {}
var next_type_id: int = 0

var multimeshes: Array[MultiMeshInstance2D] = []

@onready var player = get_tree().get_first_node_in_group("player")
@onready var loot_base = get_tree().get_first_node_in_group("loot")

var update_timer = 0.0
var player_damage_cooldown = 0.0

var exp_gem_scene = preload("res://Objects/experience_gem.tscn")
var xp_orb_scene = preload("res://Objects/xp_orb.tscn")
var death_anim = preload("res://Enemy/Base/explosion.tscn")
@export var explosion_chance: float = 0.5
# Sound might need a pool, but for now we skip hit sounds for swarms to save audio channels, or play them globally rarely.

var screen_size = Vector2(640, 360)

func _ready():
	add_to_group("swarm_manager")
	screen_size = get_viewport_rect().size

func register_enemy_type(texture: Texture2D, radius: float, hframes: int = 1, vframes: int = 1, anim_fps: float = 3) -> int:
	for id in enemy_type_cache.keys():
		if enemy_type_cache[id].texture == texture:
			return id
			
	var id = next_type_id
	next_type_id += 1
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	
	var quad_mesh = QuadMesh.new()
	var w = 24.0
	var h = 24.0
	if texture:
		w = texture.get_width() / float(hframes)
		h = texture.get_height() / float(vframes)
		
	quad_mesh.size = Vector2(w, h)
	mm.mesh = quad_mesh
	
	mm.instance_count = 0
	
	var mmi = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.texture = texture
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mmi)
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	# This shader tightly controls animation by hardcoding the generated sizes, bypassing uniform caching issues
	shader.code = """
	shader_type canvas_item;
	const int HFRAMES = %d;
	const int VFRAMES = %d;
	const float FPS = %f;
	uniform float time = 0.0;
	
	void vertex() {
		// INSTANCE_CUSTOM is reliably available in the vertex pipeline across all Godot 4 renderers
		// even OpenGL Compatibility mode on old machines.
		
		int current_frame = int(mod((time + INSTANCE_CUSTOM.r) * FPS, float(HFRAMES))); 
		
		vec2 frame_size = vec2(1.0 / float(HFRAMES), 1.0 / float(VFRAMES));
		vec2 uv_offset = vec2(float(current_frame) * frame_size.x, 0.0);
		
		// Let the GPU natively scale the Quad's UV vertices instead of fragment-hacking.
		// Native nearest-neighbor sampling works perfectly with this approach.
		UV = (UV * frame_size) + uv_offset;
	}
	""" % [hframes, vframes, anim_fps]
	
	mat.shader = shader
	mmi.material = mat
	
	multimeshes.append(mmi)
	
	enemy_type_cache[id] = {
		"texture": texture,
		"multimesh_idx": multimeshes.size() - 1,
		"radius": radius,
		"radius_sq": radius * radius
	}
	
	if radius > max_enemy_radius:
		max_enemy_radius = radius

	return id

func add_enemy(pos: Vector2, max_hp: float, hp: float, speed: float, experience: int, damage: int, type_id: int):
	var enemy = SwarmEnemy.new()
	enemy.position = pos
	enemy.max_hp = max_hp
	enemy.hp = hp
	enemy.speed = speed
	enemy.experience = experience
	enemy.damage = damage
	enemy.type_id = type_id
	enemy.swarm_manager_ref = self
	enemy.anim_offset = randf() * 100.0
	swarm_data.append(enemy)

func _physics_process(delta):
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		
	var p_pos = player.global_position
	var frame = Engine.get_physics_frames()
	
	if player_damage_cooldown > 0:
		player_damage_cooldown -= delta
		
	var current_time = float(Time.get_ticks_msec()) / 1000.0
	for mmi in multimeshes:
		var mat = mmi.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("time", current_time)
		
	# Build O(N) spatial grid for perfect physical separation checks regardless of spawn index
	spatial_grid.clear()
	for enemy in swarm_data:
		if not enemy.is_dead:
			# Cell size of 40px ensures we easily cover the 20px repulsion radius by checking adjacent cells
			var cell = Vector2(floor(enemy.position.x / 40.0), floor(enemy.position.y / 40.0))
			if not spatial_grid.has(cell):
				spatial_grid[cell] = [enemy]
			else:
				spatial_grid[cell].append(enemy)
	
	var attacks = get_tree().get_nodes_in_group("attack")
	var attack_data = [] # caches sizes to prevent recalculating each loop
	for atk in attacks:
		if atk == null or not is_instance_valid(atk):
			continue
		
		# Look for a collision shape
		var cs = atk.get_node_or_null("CollisionShape2D")
		if cs == null or cs.shape == null or cs.disabled:
			continue
			
		# Filter: ONLY player-side attacks should hit swarms.
		# Layer 3 (Value 4) is for Enemies, so player weapons are on this layer to hit them.
		# Enemy contact HitBoxes are on Layer 2 (Value 2).
		if not (atk.collision_layer & 4):
			continue
				
		var shape_type = 0 # 1 = circle, 2 = rect
		var radius = 0.0
		var extents = Vector2.ZERO
		
		if cs.shape is CircleShape2D:
			shape_type = 1
			radius = cs.shape.radius * max(abs(atk.scale.x), abs(atk.scale.y))
		elif cs.shape is RectangleShape2D:
			shape_type = 2
			extents = cs.shape.size / 2.0
				
		var dmg = atk.get("damage")
		if dmg == null: dmg = 0
		var kb = atk.get("knockback_amount")
		if kb == null: kb = 0
		
		var hit_list = atk.get("hit_once_array")
		if hit_list == null:
			# Fallback to checking the parent if the hitbox doesn't have the array itself
			hit_list = atk.owner.get("hit_once_array") if atk.owner else null
		
		var killer_source = ""
		if atk.get("killer_source") != null:
			killer_source = str(atk.killer_source)
		elif atk.owner != null and atk.owner.get("killer_source") != null:
			killer_source = str(atk.owner.killer_source)

		attack_data.append({
			"node": atk,
			"cs_node": cs,
			"shape_type": shape_type,
			"radius": radius,
			"extents": extents,
			"damage": dmg,
			"knockback_amount": kb,
			"hit_enemies": hit_list if hit_list != null else [],
			"has_enemy_hit": atk.has_method("enemy_hit"),
			"has_on_hit_enemy": atk.has_method("on_hit_enemy"),
			"killer_source": killer_source
		})

	# Process attack collisions against nearby swarm enemies
	for atk in attack_data:
		if atk.node == null or not is_instance_valid(atk.node):
			continue
		if atk.node.is_queued_for_deletion():
			continue
		if atk.node.get("hp") != null and atk.node.hp <= 0:
			continue

		var cs_pos = atk.cs_node.global_position
		var candidate_enemies: Array = []
		var search_r = 0.0
		if atk.shape_type == 1:
			search_r = atk.radius + max_enemy_radius
		elif atk.shape_type == 2:
			search_r = atk.extents.length() * max(abs(atk.node.scale.x), abs(atk.node.scale.y)) + max_enemy_radius

		if search_r > 0.0 and not spatial_grid.is_empty():
			var min_cx = int(floor((cs_pos.x - search_r) / 40.0))
			var max_cx = int(floor((cs_pos.x + search_r) / 40.0))
			var min_cy = int(floor((cs_pos.y - search_r) / 40.0))
			var max_cy = int(floor((cs_pos.y + search_r) / 40.0))
			var cell_count = (max_cx - min_cx + 1) * (max_cy - min_cy + 1)

			if cell_count < swarm_data.size():
				for cx in range(min_cx, max_cx + 1):
					for cy in range(min_cy, max_cy + 1):
						var cell = Vector2(cx, cy)
						if spatial_grid.has(cell):
							candidate_enemies.append_array(spatial_grid[cell])
			else:
				candidate_enemies = swarm_data
		else:
			candidate_enemies = swarm_data

		for enemy in candidate_enemies:
			if enemy.is_dead:
				continue
			if atk.hit_enemies.has(enemy):
				continue

			var hit = false
			var enemy_radius = enemy_type_cache[enemy.type_id].radius
			if atk.shape_type == 2: # Rect
				var local_p = atk.cs_node.global_transform.affine_inverse() * enemy.position
				if abs(local_p.x) <= atk.extents.x + enemy_radius and abs(local_p.y) <= atk.extents.y + enemy_radius:
					hit = true
			elif atk.shape_type == 1: # Circle
				var dist_sq = enemy.position.distance_squared_to(cs_pos)
				if dist_sq <= (atk.radius + enemy_radius) ** 2:
					hit = true

			if hit:
				# Apply damage
				var damage_multiplier = 1.0 + enemy.get_debuff_value("curse")
				var p_dmg_mod = GlobalEvents.get_player_damage_modifier()
				if player != null and player.has_method("get_damage_modifier"):
					p_dmg_mod *= player.get_damage_modifier()
				enemy.hp -= (atk.damage * damage_multiplier * p_dmg_mod)

				# Knockback
				var angle = Vector2.ZERO
				if atk.node.get("angle"):
					angle = atk.node.angle
				else:
					angle = cs_pos.direction_to(enemy.position)
				enemy.knockback = angle * atk.knockback_amount

				# Proc coefficient and stats
				var proc_co = atk.node.get("proc_coefficient")
				if proc_co == null: proc_co = 1.0
				GlobalEvents.player_dealt_damage.emit(atk.damage, enemy, proc_co)

				if atk.has_on_hit_enemy:
					atk.node.on_hit_enemy(enemy)

				if atk.has_enemy_hit and not atk.node.is_queued_for_deletion():
					atk.node.enemy_hit(1)

				if not atk.hit_enemies.has(enemy):
					atk.hit_enemies.append(enemy)
				if atk.node.get("hit_once_array") != null and typeof(atk.node.hit_once_array) == TYPE_ARRAY:
					if not atk.node.hit_once_array.has(enemy):
						atk.node.hit_once_array.append(enemy)
				elif atk.node.owner != null and atk.node.owner.get("hit_once_array") != null and typeof(atk.node.owner.hit_once_array) == TYPE_ARRAY:
					if not atk.node.owner.hit_once_array.has(enemy):
						atk.node.owner.hit_once_array.append(enemy)

				if enemy.hp <= 0:
					_handle_death(enemy, atk.killer_source)

				# Immediately halt processing for an attack once queued for deletion or depleted HP
				if atk.node.is_queued_for_deletion() or (atk.node.get("hp") != null and atk.node.hp <= 0):
					break
	
	var i = 0
	var player_push_sum = Vector2.ZERO
	while i < swarm_data.size():
		var enemy = swarm_data[i]
		
		if enemy.is_dead:
			enemy.death_timer -= delta
			if enemy.death_timer <= 0:
				swarm_data.remove_at(i)
				continue
			i += 1
			continue
			
		# Process debuffs
		var keys_to_remove = []
		for debuff_name in enemy.active_debuffs.keys():
			var data = enemy.active_debuffs[debuff_name]
			data["duration"] -= delta
			if data["duration"] <= 0:
				keys_to_remove.append(debuff_name)
		for k in keys_to_remove:
			enemy.active_debuffs.erase(k)

		var velocity = Vector2.ZERO
		if enemy.knockback.length_squared() > 0.1:
			enemy.knockback = enemy.knockback.move_toward(Vector2.ZERO, 3.5)
			velocity += enemy.knockback
			
		var pursuit_dir = enemy.position.direction_to(p_pos)
		var pursuit = pursuit_dir * enemy.speed
		
		# Separation (evaluate every 3 frames for neighbors)
		if frame % 3 == (i % 3):
			var push_vector = Vector2.ZERO
			var cell_x = int(floor(enemy.position.x / 40.0))
			var cell_y = int(floor(enemy.position.y / 40.0))
			
			for cx in range(cell_x - 1, cell_x + 2):
				for cy in range(cell_y - 1, cell_y + 2):
					var c = Vector2(cx, cy)
					if spatial_grid.has(c):
						for neighbor in spatial_grid[c]:
							if enemy == neighbor or neighbor.is_dead: continue
							var dist_sq = enemy.position.distance_squared_to(neighbor.position)
							if dist_sq < 324.0: # 18px radius 
								push_vector += neighbor.position.direction_to(enemy.position) * (1.0 - (dist_sq/324.0))
			
			# Interpolate separation using un-normalized vector so small overlaps = gentle pushes
			enemy.separation = enemy.separation.lerp(push_vector * enemy.speed * 4.0, 0.5)
				
		var movement = pursuit + enemy.separation
		
		# Cap only the forward velocity to prevent slingshotting, but allow lateral/backward blasts
		var forward_speed = movement.dot(pursuit_dir)
		if forward_speed > enemy.speed:
			movement -= pursuit_dir * (forward_speed - enemy.speed)
			
		velocity += movement
			
		enemy.position += velocity * delta
		
		# Player Soft Collision and Damage
		var type_info = enemy_type_cache[enemy.type_id]
		var contact_dist = type_info.radius + 10.0 # 10.0 is approx player radius
		var contact_dist_sq = contact_dist * contact_dist
		
		var dist_to_p_sq = enemy.position.distance_squared_to(p_pos)
		if dist_to_p_sq < contact_dist_sq:
			var push_dir = enemy.position.direction_to(p_pos)
			if dist_to_p_sq > 0.1:
				var overlap = 1.0 - (dist_to_p_sq / contact_dist_sq)
				# Accumulate push on player to moderate forces
				player_push_sum += push_dir * 180.0 * overlap
				
				# Push the enemy backward so they cluster slightly instead of overlapping player perfectly
				enemy.position -= push_dir * 40.0 * overlap * delta
				
			if player_damage_cooldown <= 0.0:
				if player.has_method("_on_hurt_box_hurt"):
					player._on_hurt_box_hurt(enemy.damage, -push_dir, 0, "Swarm", enemy)
					player_damage_cooldown = 0.4 # Slightly reduced for better threat feel
				
		i += 1 # Critical: Increment the loop!

	# Apply accumulated and capped push to the player to allow blocking without "force fields"
	if player_push_sum.length_squared() > 1.0:
		var max_push = 300.0 # Enough to strongly block player (spd 75) but not launch them
		if player_push_sum.length() > max_push:
			player_push_sum = player_push_sum.normalized() * max_push
		player.global_position += player_push_sum * delta

	_update_multimeshes()

func _handle_death(enemy: SwarmEnemy, killer_source: String = "Swarm"):
	if enemy.is_dead:
		return
	enemy.is_dead = true
	enemy.death_timer = 0.2 # Brief flash or disappear time
	
	var current_loot_base = get_tree().get_first_node_in_group("loot") if get_tree() else null
	if current_loot_base:
		var new_gem = exp_gem_scene.instantiate()
		new_gem.global_position = enemy.position
		new_gem.experience = enemy.experience
		current_loot_base.call_deferred("add_child", new_gem)
		
		if GlobalEvents.roll_magnet_drop():
			var new_xp_orb = xp_orb_scene.instantiate()
			new_xp_orb.global_position = enemy.position
			current_loot_base.call_deferred("add_child", new_xp_orb)
		
	var final_source = killer_source if killer_source != "" else "Swarm"
	GlobalEvents.enemy_died.emit(enemy.position, enemy.max_hp, final_source)
		
	# Death Animation (too many will lag, so we only spawn explicitly if we are below a threshold, or just rely on hit flashes)
	var parent = get_parent()
	if parent and randf() <= explosion_chance: 
		var d = death_anim.instantiate()
		d.global_position = enemy.position
		parent.call_deferred("add_child", d)
		
	StatsManager.register_kill(0)

func _update_multimeshes():
	var instance_counts = []
	instance_counts.resize(multimeshes.size())
	instance_counts.fill(0)
	
	for enemy in swarm_data:
		var type_info = enemy_type_cache[enemy.type_id]
		instance_counts[type_info.multimesh_idx] += 1
	
	for i in range(multimeshes.size()):
		var mm = multimeshes[i].multimesh
		if mm.instance_count != instance_counts[i] and instance_counts[i] > mm.instance_count:
			mm.instance_count = instance_counts[i]
		elif mm.instance_count > instance_counts[i]:
			mm.visible_instance_count = instance_counts[i]
		else:
			mm.visible_instance_count = -1
	
	var current_idx = []
	current_idx.resize(multimeshes.size())
	current_idx.fill(0)
	
	for enemy in swarm_data:
		var type_info = enemy_type_cache[enemy.type_id]
		var idx = type_info.multimesh_idx
		var mm = multimeshes[idx].multimesh
		
		# Death flash effect using colors if use_colors=true is set
		var color = Color(1,1,1,1)
		if enemy.is_dead:
			color = Color(1,0,0,0.5)
		elif enemy.has_debuff("curse"):
			color = Color(0.8, 0.4, 1.0)
		
		var p_pos = player.global_position
		var flip = -1.0 if enemy.position.x < p_pos.x else 1.0
		
		# Smooth float transforms paired with snapped-UV shader achieves perfect pixel art swarms.
		# Multiply Y-scale by -1.0 because Godot 3D QuadMeshes project upside-down in the 2D space.
		var t = Transform2D(0, enemy.position).scaled_local(Vector2(flip, -1.0))
		
		mm.set_instance_transform_2d(current_idx[idx], t)
		mm.set_instance_color(current_idx[idx], color)
		mm.set_instance_custom_data(current_idx[idx], Color(enemy.anim_offset, 0, 0, 0))
		current_idx[idx] += 1

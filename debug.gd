extends SceneTree

func _init():
	var enemy_scene = load("res://Enemy/Minions/enemy_kobold_weak.tscn")
	if enemy_scene:
		var template = enemy_scene.instantiate()
		var p_sprite = template.get_node_or_null("EnemyBase/Sprite2D")
		if p_sprite:
			print("Texture: ", p_sprite.texture.resource_path)
			print("HFrames: ", p_sprite.hframes)
			print("VFrames: ", p_sprite.vframes)
		else:
			print("No Sprite2D found")
	else:
		print("Failed to load scene")
	quit()

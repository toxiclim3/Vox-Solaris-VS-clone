extends SceneTree

func _init():
	var textures = [
		"res://Textures/Items/Weapons/tornado.png",
		"res://Textures/Items/Weapons/poison_gas.png",
		"res://Textures/Items/Weapons/sword.png"
	]
	for t_path in textures:
		var tex = load(t_path)
		if tex:
			print(t_path, ": ", tex.get_size())
		else:
			print("Failed to load: ", t_path)
	quit()

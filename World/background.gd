# BackgroundManager.gd
extends Parallax2D

@export_dir var folder_path: String = "res://Textures/Backgrounds/"
@export var transition_duration: float = 1.0
@export var pixel_scale: float = 1.0 # Можно поставить 2.0 или 4.0, если 32x32 слишком мелко

@onready var current_sprite: Sprite2D = $CurrentBackground
@onready var fade_sprite: Sprite2D = $FadeBackground

var backgrounds: Array[Texture2D] = []
var current_index: int = -1

func _ready() -> void:
	scroll_scale = Vector2(1, 1)
	
	# Настраиваем спрайты для правильного отображения пикселей
	for s in [current_sprite, fade_sprite]:
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.centered = false # Начинаем отрисовку от угла для точности региона
	
	load_backgrounds_from_folder()
	GlobalEvents.advanceBackground.connect(advance_background)
	
	if backgrounds.size() > 0:
		advance_background()

func load_backgrounds_from_folder() -> void:
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.trim_suffix(".remap").trim_suffix(".import")
				if clean_name.ends_with(".png") or clean_name.ends_with(".jpg") or clean_name.ends_with(".webp"):
					var tex = load(folder_path + "/" + clean_name) as Texture2D
					if tex and not backgrounds.has(tex):
						backgrounds.append(tex)
			file_name = dir.get_next()
		backgrounds.shuffle()
	print("Загружено фонов для Parallax: ", backgrounds.size())

func advance_background() -> void:
	if backgrounds.is_empty(): return
	current_index = (current_index + 1) % backgrounds.size()
	var new_tex = backgrounds[current_index]
	
	_setup_tiling_region(new_tex) # Настраиваем "плитку"
	
	if current_sprite.texture == null:
		current_sprite.texture = new_tex
	else:
		_start_transition(new_tex)

func _start_transition(new_tex: Texture2D) -> void:
	fade_sprite.texture = new_tex
	fade_sprite.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(fade_sprite, "modulate:a", 1.0, transition_duration)
	
	await tween.finished
	
	current_sprite.texture = new_tex
	fade_sprite.modulate.a = 0.0

## Новая логика для тайлинга (замощения)
func _setup_tiling_region(_tex: Texture2D) -> void:
	var view_size = get_viewport_rect().size
	
	# Учитываем масштаб (если хочешь сделать пиксели крупнее)
	var final_view_size = view_size / pixel_scale
	
	# Заставляем спрайт думать, что он огромного размера
	# RegionRect говорит: "рисуй текстуру от 0,0 до границ экрана"
	# А так как Repeat включен, он просто заполнит это пространство тайлами 32x32
	var region_rect = Rect2(Vector2.ZERO, final_view_size)
	
	current_sprite.region_rect = region_rect
	fade_sprite.region_rect = region_rect
	
	current_sprite.scale = Vector2(pixel_scale, pixel_scale)
	fade_sprite.scale = Vector2(pixel_scale, pixel_scale)
	
	# Важно для Parallax2D: repeat_size теперь равен размеру экрана, 
	# так как спрайт уже заполняет весь экран.
	repeat_size = view_size

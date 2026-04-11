extends Node

signal warming_started
signal progress_updated(current, total)
signal warming_finished

@export var materials: Array[Material] = []
@export var frames_per_material: int = 2

var _current_index: int = 0
var _viewport: SubViewport
var _rect: ColorRect

func _ready() -> void:
	# Create a hidden viewport to force rendering
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2, 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	add_child(_viewport)
	
	_rect = ColorRect.new()
	_rect.size = Vector2(2, 2)
	_viewport.add_child(_rect)
	
	# We don't want to see the 2x2 buffer, but it will still render to GPU

func start_warming(mats: Array[Material] = []) -> void:
	if mats.size() > 0:
		materials = mats
	
	if materials.size() == 0:
		warming_finished.emit()
		return
	
	_current_index = 0
	warming_started.emit()
	_process_next()

func _process_next() -> void:
	if _current_index >= materials.size():
		warming_finished.emit()
		return
	
	var mat = materials[_current_index]
	_rect.material = mat
	
	# Update progress
	progress_updated.emit(_current_index + 1, materials.size())
	
	# Wait for a few frames to ensure GPU has compiled the shader
	for i in range(frames_per_material):
		await get_tree().process_frame
	
	_current_index += 1
	_process_next()

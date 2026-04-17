extends CanvasLayer

signal finished

@onready var toast_panel = %ToastPanel
@onready var status_label = %StatusLabel
@onready var progress_bar = %ProgressBar

var _prewarmer: Node
var _original_pos: Vector2

func _ready() -> void:
	# Hide initially
	toast_panel.modulate.a = 0
	_original_pos = toast_panel.position
	toast_panel.position.x -= 20 # Small offset for slide-in
	
	# Instantiate logic
	_prewarmer = load("res://Utility/shader_prewarmer.gd").new()
	add_child(_prewarmer)
	
	_prewarmer.progress_updated.connect(_on_progress_updated)
	_prewarmer.warming_finished.connect(_on_warming_finished)
	
	# Initial text
	status_label.text = tr("ui_preheating_shaders")

func start(materials: Array[Material]) -> void:
	# Slide and Fade in
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(toast_panel, "position:x", _original_pos.x, 0.5)
	
	_prewarmer.start_warming(materials)

func _on_progress_updated(current: int, total: int) -> void:
	progress_bar.max_value = total
	progress_bar.value = current
	status_label.text = tr("ui_preheating_shaders") + " (" + str(current) + "/" + str(total) + ")"

func _on_warming_finished() -> void:
	finished.emit()
	# Fade out
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.8)
	tween.tween_property(toast_panel, "position:x", _original_pos.x - 20, 0.8)
	tween.chain().tween_callback(queue_free)

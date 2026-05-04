extends CanvasLayer

signal how_to_play_closed

# ── Slide definitions ─────────────────────────────────────────────────────────
const SLIDES: Array[Dictionary] = [
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_movement.tscn",
		"title_key": "ui_htp_movement_title",
		"desc_key":  "ui_htp_movement_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_attacks.tscn",
		"title_key": "ui_htp_attacks_title",
		"desc_key":  "ui_htp_attacks_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_xp.tscn",
		"title_key": "ui_htp_xp_title",
		"desc_key":  "ui_htp_xp_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_levelup.tscn",
		"title_key": "ui_htp_levelup_title",
		"desc_key":  "ui_htp_levelup_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_bosses.tscn",
		"title_key": "ui_htp_bosses_title",
		"desc_key":  "ui_htp_bosses_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_characters.tscn",
		"title_key": "ui_htp_characters_title",
		"desc_key":  "ui_htp_characters_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_difficulty.tscn",
		"title_key": "ui_htp_difficulty_title",
		"desc_key":  "ui_htp_difficulty_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_protips_splash.tscn",
		"title_key": "",   # diorama carries the text itself
		"desc_key":  ""
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_tip_circles.tscn",
		"title_key": "ui_htp_tip1_title",
		"desc_key":  "ui_htp_tip1_desc"
	},
	{
		"scene":     "res://TitleScreen/HowToPlay/slide_tip_xporb.tscn",
		"title_key": "ui_htp_tip2_title",
		"desc_key":  "ui_htp_tip2_desc"
	},
]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _viewport:        SubViewport   = %SlideViewport
@onready var _display:         TextureRect   = %SlideDisplay
@onready var _lbl_title:       Label         = %LabelSlideTitle
@onready var _lbl_desc:        Label         = %LabelSlideDesc
@onready var _btn_prev:        Button        = %BtnPrev
@onready var _btn_next:        Button        = %BtnNext
@onready var _dots_container:  HBoxContainer = %PageDots

var _current: int = 0
var _dots: Array[Panel] = []
var _current_scene: Node = null

# ── Dot style boxes ───────────────────────────────────────────────────────────
var _style_on:  StyleBoxFlat
var _style_off: StyleBoxFlat

func _ready() -> void:
	_display.texture = _viewport.get_texture()
	_build_dot_styles()
	_build_dots()
	_load_slide(0)

func _build_dot_styles() -> void:
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	_style_on.set_corner_radius_all(3)

	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0.4, 0.4, 0.4, 0.6)
	_style_off.set_corner_radius_all(3)

func _build_dots() -> void:
	for child in _dots_container.get_children():
		child.queue_free()
	_dots.clear()

	for i in SLIDES.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", _style_off)
		_dots_container.add_child(dot)
		_dots.append(dot)

func _load_slide(index: int) -> void:
	# Free previous scene
	if _current_scene:
		if _current_scene.has_method("stop_loop"):
			_current_scene.stop_loop()
		_current_scene.queue_free()
		_current_scene = null

	_current = clamp(index, 0, SLIDES.size() - 1)
	var data: Dictionary = SLIDES[_current]

	# Load & instance slide scene
	var packed: PackedScene = load(data["scene"])
	if packed:
		_current_scene = packed.instantiate()
		_viewport.add_child(_current_scene)
		if _current_scene.has_method("start_loop"):
			_current_scene.start_loop()

	# Text — hide on Pro Tips splash
	var has_text: bool = data["title_key"] != ""
	_lbl_title.visible = has_text
	_lbl_desc.visible  = has_text
	if has_text:
		_lbl_title.text = tr(data["title_key"])
		_lbl_desc.text  = tr(data["desc_key"])

	# Nav state
	_btn_prev.disabled = (_current == 0)
	_btn_next.text     = "→" if _current < SLIDES.size() - 1 else tr("ui_close")

	_update_dots()

func _update_dots() -> void:
	for i in _dots.size():
		_dots[i].add_theme_stylebox_override(
			"panel",
			_style_on if i == _current else _style_off
		)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_go_prev()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_go_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _go_prev() -> void:
	if _current > 0:
		_load_slide(_current - 1)

func _go_next() -> void:
	if _current < SLIDES.size() - 1:
		_load_slide(_current + 1)
	else:
		_close()

func _close() -> void:
	how_to_play_closed.emit()

func grab_initial_focus() -> void:
	_btn_next.grab_focus()

# ── Button callbacks ──────────────────────────────────────────────────────────
func _on_btn_prev_pressed() -> void:
	_go_prev()

func _on_btn_next_pressed() -> void:
	_go_next()

func _on_btn_close_pressed() -> void:
	_close()

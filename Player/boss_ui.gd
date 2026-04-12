extends Control

@onready var boss_warning_panel = get_node("%BossWarning")
@onready var boss_warning_label = get_node("%lbl_boss_warning")
@onready var snd_boss_warning = get_node("%snd_boss_warning")

# Boss Bar
@onready var boss_bar_progress = get_node("%BossBarProgress")
@onready var boss_name_label = get_node("%BossNameLabel")
@onready var boss_bar_particles = get_node("%BossBarParticles")

var current_boss = null
var boss_warning_tween: Tween
var boss_bar_tween: Tween

func _ready() -> void:
	GlobalEvents.show_boss_warning.connect(_on_show_boss_warning)
	GlobalEvents.boss_spawned.connect(_on_boss_spawned)
	GlobalEvents.boss_defeated.connect(_on_boss_defeated)
	
	_setup_boss_particles()

func _process(_delta: float) -> void:
	if current_boss and is_instance_valid(current_boss):
		boss_bar_progress.value = current_boss.hp

func _on_show_boss_warning(warning_key: String) -> void:
	boss_warning_label.text = tr(warning_key)
	boss_warning_panel.show()
	snd_boss_warning.play()
	
	if boss_warning_tween:
		boss_warning_tween.kill()
		
	boss_warning_tween = create_tween()
	boss_warning_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	boss_warning_tween.tween_property(boss_warning_panel, "position:y", 0.0, 0.5)
	
	get_tree().create_timer(5.0).timeout.connect(hide_boss_warning)

func hide_boss_warning() -> void:
	if not boss_warning_panel.visible:
		return
	if boss_warning_tween:
		boss_warning_tween.kill()
		
	boss_warning_tween = create_tween()
	boss_warning_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	boss_warning_tween.tween_property(boss_warning_panel, "position:y", -32.0, 0.5)
	boss_warning_tween.tween_callback(boss_warning_panel.hide)

func _on_btn_warning_dismiss_pressed() -> void:
	hide_boss_warning()

func _setup_boss_particles() -> void:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.gravity = Vector3(0, 40, 0)
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.76, 0.65, 0.5, 0.8)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(320, 2, 0)
	boss_bar_particles.process_material = mat
	boss_bar_particles.position = Vector2(size.x / 2.0 if size.x > 0 else 320, 20)

func _on_boss_spawned(boss) -> void:
	current_boss = boss
	boss_bar_progress.max_value = boss.max_hp
	boss_bar_progress.value = boss.hp
	
	# Get the boss name via translation key
	var scene_path = boss.scene_file_path
	var name_key = GlobalEvents.boss_names.get(scene_path, "boss_name_generic")
	boss_name_label.text = tr(name_key)
	
	# Show and animate
	show()
	offset_top = -40.0
	offset_bottom = -17.0
	
	# Configure dust particles for entrance
	var dust_mat = boss_bar_particles.process_material as ParticleProcessMaterial
	if dust_mat:
		dust_mat.direction = Vector3(0, 1, 0)
		dust_mat.gravity = Vector3(0, 40, 0)
		dust_mat.initial_velocity_min = 15.0
		dust_mat.initial_velocity_max = 35.0
		dust_mat.scale_min = 1.5
		dust_mat.scale_max = 3.0
		dust_mat.color = Color(0.76, 0.65, 0.5, 0.8)
	boss_bar_particles.emitting = true
	
	if boss_bar_tween:
		boss_bar_tween.kill()
	
	# Get timer label reference
	var timer_label = get_tree().get_first_node_in_group("player")
	if timer_label:
		timer_label = timer_label.get_node_or_null("%lblTimer")
	
	boss_bar_tween = create_tween().set_parallel(true)
	boss_bar_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	boss_bar_tween.tween_property(self, "offset_top", 20.0, 0.8)
	boss_bar_tween.tween_property(self, "offset_bottom", 43.0, 0.8)
	if timer_label:
		boss_bar_tween.tween_property(timer_label, "self_modulate:a", 0.0, 0.4)

func _on_boss_defeated() -> void:
	# Configure smoke particles for exit
	var smoke_mat = boss_bar_particles.process_material as ParticleProcessMaterial
	if smoke_mat:
		smoke_mat.direction = Vector3(0, -1, 0)
		smoke_mat.gravity = Vector3(0, -10, 0)
		smoke_mat.initial_velocity_min = 8.0
		smoke_mat.initial_velocity_max = 20.0
		smoke_mat.scale_min = 3.0
		smoke_mat.scale_max = 6.0
		smoke_mat.color = Color(0.5, 0.5, 0.5, 0.6)
	boss_bar_particles.emitting = true
	
	if boss_bar_tween:
		boss_bar_tween.kill()
	
	# Get timer label reference
	var timer_label = get_tree().get_first_node_in_group("player")
	if timer_label:
		timer_label = timer_label.get_node_or_null("%lblTimer")
	
	boss_bar_tween = create_tween().set_parallel(true)
	boss_bar_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	boss_bar_tween.tween_property(self, "offset_top", -40.0, 0.6)
	boss_bar_tween.tween_property(self, "offset_bottom", -17.0, 0.6)
	if timer_label:
		boss_bar_tween.tween_property(timer_label, "self_modulate:a", 1.0, 0.5)
	boss_bar_tween.chain().tween_callback(func():
		hide()
		current_boss = null
	)

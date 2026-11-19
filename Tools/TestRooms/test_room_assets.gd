class_name TestRoomAssets
extends TestRoomBase

enum TabMode { SPRITES, WHIP, SHADER, ICONS }

var current_tab: TabMode = TabMode.SPRITES
var active_backdrop_idx: int = 0
const BACKDROP_COLORS := [
	Color(0.08, 0.09, 0.12), # Dark
	Color(0.23, 0.35, 0.25), # Arena Grass Green
	Color(0.92, 0.92, 0.94), # Pure White
	Color(0.15, 0.15, 0.18)  # Checkerboard base
]

var backdrop_rect: ColorRect = null
var backdrop_checker: Node2D = null

# Loupe Camera
var zoom_levels: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
var zoom_idx: int = 0
var is_panning_camera: bool = false

# --- Tab 1: Sprites & PhasedAnimator ---
var sprite_catalog: Array[Dictionary] = [
	{"name": "Poison Gas", "path": "res://Player/Attack/poisonbottle/poison_gas.tscn", "is_scene": true},
	{"name": "Ritual Circle", "path": "res://Player/Attack/ritualcircle/ritualcircle.tscn", "is_scene": true},
	{"name": "Wisp Explosion", "path": "res://Player/Attack/willowisp/willowisp_explosion.tscn", "is_scene": true},
	{"name": "Buckler Shockwave", "path": "res://Player/Attack/impact_buckler/impact_buckler_shockwave.tscn", "is_scene": true},
	{"name": "Player Sprite", "path": "res://Textures/Player/player_sprite.png", "is_scene": false, "hframes": 2, "vframes": 1},
	{"name": "Cyclops", "path": "res://Textures/Enemy/cyclops.png", "is_scene": false, "hframes": 2, "vframes": 1},
	{"name": "Ancient Amoeba", "path": "res://Textures/Enemy/giant_amoeba_new.png", "is_scene": false, "hframes": 1, "vframes": 1},
	{"name": "Dr. Franklin", "path": "res://Textures/Enemy/franklin-v0.png", "is_scene": false, "hframes": 1, "vframes": 1}
]
var sprite_cat_idx: int = 0
var active_sprite_node: Node = null
var active_phased_anim: PhasedAnimator = null
var is_anim_playing: bool = true
var anim_tick_timer: float = 0.0
var anim_fps: float = 12.0
var sprite_info_lbl: Label = null

# --- Tab 2: Whip 3-Slice Rig ---
var whip_catalog: Array[Dictionary] = [
	{
		"name": "Leather Whip",
		"path": "res://Textures/Items/Weapons/Leather_Whip_(projectile).webp",
		"start_margin": 30.0,
		"end_margin": 26.0,
		"texture_size": Vector2(92.0, 10.0),
		"width": 14.0
	},
	{
		"name": "Glass Lash",
		"path": "res://Textures/Items/Weapons/Kaleidoscope_(projectile).webp",
		"start_margin": 22.0,
		"end_margin": 30.0,
		"texture_size": Vector2(148.0, 14.0),
		"width": 14.0
	}
]
var whip_cat_idx: int = 0
var whip_tile_middle: bool = true
var whip_hide_caps: bool = false
var whip_line: Line2D = null
var whip_material: ShaderMaterial = null
var whip_handles: Node2D = null
var whip_points: Array[Vector2] = [
	Vector2(-120, 0),
	Vector2(-40, -40),
	Vector2(40, -30),
	Vector2(120, 0)
]
var dragged_point_idx: int = -1
var whip_info_lbl: Label = null

# --- Tab 3: Shader Lab ---
var shader_preview_sprite: Sprite2D = null
var elite_preview_sprite: Sprite2D = null
var tab3_swarm_mgr = null
var elite_material: ShaderMaterial = null
var recolor_material: ShaderMaterial = null
var trail_mode_idx: int = 2
var shader_oscillator_time: float = 0.0
var shader_info_lbl: Label = null

# --- Tab 4: Rule 12 Icon Trim Auditor ---
var audit_panel: PanelContainer = null
var audit_scroll: ScrollContainer = null
var audit_grid: GridContainer = null
var audit_summary_lbl: Label = null

# Gizmo Overlay (G)
var show_gizmos: bool = true
var gizmo_overlay: Node2D = null

# Root containers for tabs
var tab_containers: Dictionary = {}

func _get_room_title() -> String:
	return "TEXTURE, ANIMATION & SHADER GALLERY"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "1 - 4", "desc": "Switch Tab: 1 Sprites | 2 Whip Rig | 3 Shaders | 4 Icon Audit"},
		{"key": "[ / ]", "desc": "Cycle Catalog (Sprites in Tab 1, Whip Asset in Tab 2)"},
		{"key": "Space", "desc": "Play / Pause Animation & Shader Oscillator"},
		{"key": ", / .", "desc": "Step Frame (-1 / +1) When Paused"},
		{"key": "P", "desc": "Advance PhasedAnimator (Triggers FINISH Expiration)"},
		{"key": "T / C", "desc": "Toggle tile_middle / hide_caps (Tab 2 Whip Rig)"},
		{"key": "Up / Down", "desc": "Cycle row_index or Shader trail_mode"},
		{"key": "B", "desc": "Cycle Backdrop (Dark -> Grass -> White -> Checker)"},
		{"key": "G", "desc": "Toggle Gizmos (Pivot Crosshair +, Bounds, UV Grid)"},
		{"key": "+ / -", "desc": "Step Pixel Loupe Zoom (1x..16x) | Wheel: Zoom to Cursor"},
		{"key": "RMB / MMB", "desc": "Drag to Pan Camera | 0: Reset Camera"},
		{"key": "A", "desc": "Re-run Rule 12 Transparent Padding Audit"}
	]

func _setup_room() -> void:
	_setup_camera()
	_setup_backdrop()
	_setup_tab_roots()
	_setup_tab_1_sprites()
	_setup_tab_2_whip_rig()
	_setup_tab_3_shader_lab()
	_setup_tab_4_icon_audit()
	_setup_gizmo_overlay()
	_setup_extra_topbar_buttons()

	_switch_tab(TabMode.SPRITES)

func _setup_camera() -> void:
	if camera == null:
		super._setup_camera()
	camera.zoom = Vector2.ONE

func _setup_backdrop() -> void:
	backdrop_rect = ColorRect.new()
	backdrop_rect.z_index = -30
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_rect.position = Vector2(-2000, -2000)
	backdrop_rect.size = Vector2(4000, 4000)
	backdrop_rect.color = BACKDROP_COLORS[active_backdrop_idx]
	add_child(backdrop_rect)

	backdrop_checker = Node2D.new()
	backdrop_checker.z_index = -25
	backdrop_checker.visible = false
	add_child(backdrop_checker)
	backdrop_checker.draw.connect(_on_draw_checkerboard)

func _on_draw_checkerboard() -> void:
	if not backdrop_checker: return
	var size := 16.0
	var extent := 600.0
	var c1 := Color(0.12, 0.13, 0.16)
	var c2 := Color(0.20, 0.22, 0.26)
	for x in range(-int(extent), int(extent), int(size)):
		for y in range(-int(extent), int(extent), int(size)):
			var col := c1 if (int(x / size) + int(y / size)) % 2 == 0 else c2
			backdrop_checker.draw_rect(Rect2(x, y, size, size), col)

func _setup_tab_roots() -> void:
	for m in [TabMode.SPRITES, TabMode.WHIP, TabMode.SHADER, TabMode.ICONS]:
		var n := Node2D.new()
		n.name = "Tab_%d" % m
		add_child(n)
		tab_containers[m] = n

func _make_hud_info_label() -> Label:
	var lbl := Label.new()
	lbl.theme = load("res://Themes/DebugButtons.tres")
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_left = 10.0
	lbl.offset_bottom = -8.0
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	ui_layer.add_child(lbl)
	return lbl

func _setup_tab_1_sprites() -> void:
	sprite_info_lbl = _make_hud_info_label()
	_load_sprite_catalog_item(0)

func _load_sprite_catalog_item(idx: int) -> void:
	if active_sprite_node and is_instance_valid(active_sprite_node):
		active_sprite_node.queue_free()
		active_sprite_node = null
		active_phased_anim = null

	sprite_cat_idx = posmod(idx, sprite_catalog.size())
	var item: Dictionary = sprite_catalog[sprite_cat_idx]
	var root: Node2D = tab_containers[TabMode.SPRITES]

	if item["is_scene"]:
		var scn: PackedScene = load(item["path"])
		if scn:
			active_sprite_node = scn.instantiate()
			active_sprite_node.position = Vector2.ZERO
			root.add_child(active_sprite_node)
			active_phased_anim = active_sprite_node.get_node_or_null("PhasedAnimator") as PhasedAnimator
			if active_phased_anim == null:
				for ch in active_sprite_node.get_children():
					if ch is PhasedAnimator:
						active_phased_anim = ch
						break
	else:
		var sp := Sprite2D.new()
		sp.texture = load(item["path"])
		sp.hframes = item.get("hframes", 1)
		sp.vframes = item.get("vframes", 1)
		sp.frame = 0
		sp.position = Vector2.ZERO
		root.add_child(sp)
		active_sprite_node = sp

	_refresh_sprite_info()
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

func _refresh_sprite_info() -> void:
	if not sprite_info_lbl: return
	var item: Dictionary = sprite_catalog[sprite_cat_idx]
	var txt := "Asset: %s" % item["name"]

	if active_phased_anim:
		var p_name := "START"
		match active_phased_anim.current_phase:
			PhasedAnimator.Phase.START: p_name = "START"
			PhasedAnimator.Phase.LOOP: p_name = "LOOP"
			PhasedAnimator.Phase.FINISH: p_name = "FINISH"
		txt += "\nPhase: %s | Frame: %d/%d | Row: %d" % [
			p_name,
			active_phased_anim.local_frame,
			active_phased_anim.total_frames,
			active_phased_anim.row_index
		]
	elif active_sprite_node is Sprite2D:
		var s: Sprite2D = active_sprite_node
		txt += "\nFrame: %d/%d | Dimensions: %s" % [
			s.frame,
			s.hframes * s.vframes,
			str(s.texture.get_size() if s.texture else Vector2.ZERO)
		]

	txt += "\nState: %s (Space to Toggle)" % ("PLAYING" if is_anim_playing else "PAUSED")
	sprite_info_lbl.text = txt

func _setup_tab_2_whip_rig() -> void:
	var root: Node2D = tab_containers[TabMode.WHIP]

	whip_line = Line2D.new()
	whip_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	whip_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	var sh: Shader = load("res://Utility/whip_3slice.gdshader")
	if sh:
		whip_material = ShaderMaterial.new()
		whip_material.shader = sh
		whip_line.material = whip_material

	for p in whip_points:
		whip_line.add_point(p)
	root.add_child(whip_line)

	whip_handles = Node2D.new()
	whip_handles.name = "WhipHandles"
	whip_handles.z_index = 5
	root.add_child(whip_handles)
	whip_handles.draw.connect(_on_draw_whip_handles)

	whip_info_lbl = _make_hud_info_label()

	_load_whip_catalog_item(0)

func _load_whip_catalog_item(idx: int) -> void:
	whip_cat_idx = posmod(idx, whip_catalog.size())
	var entry: Dictionary = whip_catalog[whip_cat_idx]
	if whip_line:
		whip_line.texture = load(entry["path"])
		whip_line.width = entry.get("width", 14.0)
	if whip_material:
		whip_material.set_shader_parameter("start_margin", entry.get("start_margin", 20.0))
		whip_material.set_shader_parameter("end_margin", entry.get("end_margin", 20.0))
		whip_material.set_shader_parameter("texture_size", entry.get("texture_size", Vector2(64.0, 16.0)))
		whip_material.set_shader_parameter("texture_scale", 1.0)
		whip_material.set_shader_parameter("tile_middle", whip_tile_middle)
		whip_material.set_shader_parameter("hide_caps", whip_hide_caps)
	_update_whip_length()
	_refresh_whip_info()

func _refresh_whip_info() -> void:
	if not whip_info_lbl: return
	var entry: Dictionary = whip_catalog[whip_cat_idx]
	whip_info_lbl.text = "Whip 3-Slice Rig: %s [Press [ / ] to switch]\nDrag points with mouse | +/- or Wheel: Zoom\nT: tile_middle (%s) | C: hide_caps (%s)" % [
		entry["name"],
		str(whip_tile_middle),
		str(whip_hide_caps)
	]

func _on_draw_whip_handles() -> void:
	if not whip_handles:
		return
	for i in range(whip_points.size()):
		var p: Vector2 = whip_points[i]
		var is_dragged: bool = (i == dragged_point_idx)
		var fill_col := Color(1.0, 0.85, 0.25, 0.95) if is_dragged else Color(0.2, 0.75, 1.0, 0.85)
		whip_handles.draw_circle(p, 5.0, fill_col)
		whip_handles.draw_arc(p, 6.0, 0.0, TAU, 16, Color.WHITE, 1.2)

func _setup_tab_3_shader_lab() -> void:
	var root: Node2D = tab_containers[TabMode.SHADER]

	# Station 1 (Left): Recolor Shader
	var recolor_col := Node2D.new()
	recolor_col.position = Vector2(-120, 0)
	root.add_child(recolor_col)

	shader_preview_sprite = Sprite2D.new()
	shader_preview_sprite.texture = load("res://Textures/Enemy/kolbold_strong.png")
	shader_preview_sprite.hframes = 2
	shader_preview_sprite.frame = 0
	shader_preview_sprite.scale = Vector2(2.0, 2.0)
	recolor_col.add_child(shader_preview_sprite)

	var sh_recolor: Shader = load("res://Utility/recolor.gdshader")
	if sh_recolor:
		recolor_material = ShaderMaterial.new()
		recolor_material.shader = sh_recolor
		recolor_material.set_shader_parameter("target_color", Color(0.9, 0.2, 0.4, 1.0))
		recolor_material.set_shader_parameter("mix_hue", true)
		shader_preview_sprite.material = recolor_material

	var lbl_recolor := Label.new()
	lbl_recolor.text = "Recolor"
	lbl_recolor.position = Vector2(-24, 30)
	lbl_recolor.add_theme_color_override("font_color", Color(0.9, 0.4, 0.6))
	recolor_col.add_child(lbl_recolor)

	# Station 2 (Center): Elite Graphics Shader
	var elite_col := Node2D.new()
	elite_col.position = Vector2(0, 0)
	root.add_child(elite_col)

	elite_preview_sprite = Sprite2D.new()
	elite_preview_sprite.texture = load("res://Textures/Enemy/kolbold_strong.png")
	elite_preview_sprite.hframes = 2
	elite_preview_sprite.frame = 0
	elite_preview_sprite.scale = Vector2(2.0, 2.0)
	elite_col.add_child(elite_preview_sprite)

	var sh_elite: Shader = load("res://Utility/elite_graphics.gdshader")
	if sh_elite:
		elite_material = ShaderMaterial.new()
		elite_material.shader = sh_elite
		elite_material.set_shader_parameter("ghosting_strength", 0.6)
		elite_material.set_shader_parameter("blur_strength", 1.2)
		elite_material.set_shader_parameter("trail_mode", trail_mode_idx)
		elite_preview_sprite.material = elite_material

	var lbl_elite := Label.new()
	lbl_elite.text = "Elite Ghosting"
	lbl_elite.position = Vector2(-40, 30)
	lbl_elite.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	elite_col.add_child(lbl_elite)

	# Station 3 (Right): Live SwarmManager MultiMesh (3x3 tile)
	var swarm_col := Node2D.new()
	swarm_col.position = Vector2(120, 0)
	root.add_child(swarm_col)

	var sm_scene := preload("res://Utility/swarm_manager.tscn")
	tab3_swarm_mgr = sm_scene.instantiate()
	tab3_swarm_mgr.player = swarm_col
	swarm_col.add_child(tab3_swarm_mgr)

	var swarm_tex: Texture2D = load("res://Textures/Enemy/kolbold_weak.png")
	if swarm_tex:
		var type_id: int = tab3_swarm_mgr.register_enemy_type(swarm_tex, 16.0, 2, 1)
		for gx in range(-1, 2):
			for gy in range(-1, 2):
				var pos := Vector2(gx * 28.0, gy * 28.0)
				tab3_swarm_mgr.add_enemy(pos, 50.0, 50.0, 0.0, 1, 1, type_id)

	var lbl_swarm := Label.new()
	lbl_swarm.text = "Swarm MultiMesh (3x3)"
	lbl_swarm.position = Vector2(-65, 36)
	lbl_swarm.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	swarm_col.add_child(lbl_swarm)

	shader_info_lbl = _make_hud_info_label()

	_refresh_shader_info()

func _refresh_shader_info() -> void:
	if not shader_info_lbl: return
	shader_info_lbl.text = "Shader Lab: [Left] Recolor | [Mid] Elite Ghosting | [Right] Swarm MultiMesh\nUp/Down: trail_mode (%d) | Space: toggle motion osc (%s)" % [
		trail_mode_idx,
		"PLAYING" if is_anim_playing else "PAUSED"
	]

func _setup_tab_4_icon_audit() -> void:
	audit_panel = PanelContainer.new()
	audit_panel.theme = load("res://Themes/DebugButtons.tres")
	audit_panel.set_anchors_preset(Control.PRESET_CENTER)
	audit_panel.offset_left = -280.0
	audit_panel.offset_top = -135.0
	audit_panel.offset_right = 280.0
	audit_panel.offset_bottom = 155.0
	audit_panel.visible = false
	ui_layer.add_child(audit_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	audit_panel.add_child(vbox)

	audit_summary_lbl = Label.new()
	audit_summary_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vbox.add_child(audit_summary_lbl)

	audit_scroll = ScrollContainer.new()
	audit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(audit_scroll)

	audit_grid = GridContainer.new()
	audit_grid.columns = 6
	audit_grid.add_theme_constant_override("h_separation", 6)
	audit_grid.add_theme_constant_override("v_separation", 6)
	audit_scroll.add_child(audit_grid)

	_run_icon_audit()

func _run_icon_audit() -> void:
	for c in audit_grid.get_children():
		c.queue_free()

	var total_checked := 0
	var padded_count := 0
	var inspected_paths: Dictionary = {}

	for up_id in UpgradeDb.UPGRADES:
		var data: Dictionary = UpgradeDb.UPGRADES[up_id]
		var icon_path: String = data.get("icon", "")
		if icon_path == "" or inspected_paths.has(icon_path):
			continue
		inspected_paths[icon_path] = true
		total_checked += 1

		var tex: Texture2D = load(icon_path)
		if not tex:
			continue
		var img: Image = tex.get_image()
		if not img:
			continue

		var full_rect := Rect2i(Vector2i.ZERO, img.get_size())
		var used_rect := img.get_used_rect()
		var is_padded := (used_rect != full_rect)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(80, 50)
		var sb := StyleBoxFlat.new()
		sb.set_border_width_all(1)
		sb.set_content_margin_all(2)

		if is_padded:
			padded_count += 1
			sb.bg_color = Color(0.25, 0.05, 0.05, 0.9)
			sb.border_color = Color(1.0, 0.3, 0.3, 1.0) # Red warning border
		else:
			sb.bg_color = Color(0.08, 0.12, 0.08, 0.9)
			sb.border_color = Color(0.3, 0.8, 0.4, 0.8) # Green pass border

		card.add_theme_stylebox_override("panel", sb)

		var c_vbox := VBoxContainer.new()
		card.add_child(c_vbox)

		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(24, 24)
		c_vbox.add_child(tr)

		var l := Label.new()
		l.text = "%dx%d" % [full_rect.size.x, full_rect.size.y]
		if is_padded:
			l.text += "\nPad: %s" % str(used_rect.size)
			l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		else:
			l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		c_vbox.add_child(l)

		audit_grid.add_child(card)

	audit_summary_lbl.text = "Rule 12 Icon Audit: %d Icons Checked | %d Padded (Red) | %d Compliant (Green) | Press A to Refresh" % [
		total_checked, padded_count, total_checked - padded_count
	]

func _setup_extra_topbar_buttons() -> void:
	for m in [TabMode.SPRITES, TabMode.WHIP, TabMode.SHADER, TabMode.ICONS]:
		var b := Button.new()
		match m:
			TabMode.SPRITES: b.text = "1 Sprites"
			TabMode.WHIP: b.text = "2 Whip Rig"
			TabMode.SHADER: b.text = "3 Shaders"
			TabMode.ICONS: b.text = "4 Icon Audit"
		var t_idx: TabMode = m
		b.pressed.connect(func(): _switch_tab(t_idx))
		extra_buttons_bar.add_child(b)

	var b_back := Button.new()
	b_back.text = "B Backdrop"
	b_back.pressed.connect(_cycle_backdrop)
	extra_buttons_bar.add_child(b_back)

	var b_gizmo := Button.new()
	b_gizmo.text = "G Gizmos"
	b_gizmo.pressed.connect(func():
		show_gizmos = not show_gizmos
		if gizmo_overlay: gizmo_overlay.queue_redraw()
	)
	extra_buttons_bar.add_child(b_gizmo)

	var b_zoom := Button.new()
	b_zoom.text = "Zoom"
	b_zoom.pressed.connect(_cycle_zoom)
	extra_buttons_bar.add_child(b_zoom)

	var b_cam_reset := Button.new()
	b_cam_reset.text = "0 Cam"
	b_cam_reset.pressed.connect(_reset_camera)
	extra_buttons_bar.add_child(b_cam_reset)

func _setup_gizmo_overlay() -> void:
	gizmo_overlay = Node2D.new()
	gizmo_overlay.name = "GizmoOverlay"
	gizmo_overlay.z_index = 60
	add_child(gizmo_overlay)
	gizmo_overlay.draw.connect(_on_draw_gizmos)

func _on_draw_gizmos() -> void:
	if not show_gizmos or not gizmo_overlay:
		return

	var z := camera.zoom.x if camera and camera.zoom.x > 0.0 else 1.0
	var line_w := maxf(1.0, 1.0 / z)

	# Universal Pivot Crosshair (+) at origin
	var cross_sz := 14.0
	var cross_col := Color(1.0, 0.85, 0.25, 0.95)
	gizmo_overlay.draw_line(Vector2(-cross_sz, 0), Vector2(cross_sz, 0), cross_col, line_w)
	gizmo_overlay.draw_line(Vector2(0, -cross_sz), Vector2(0, cross_sz), cross_col, line_w)

	match current_tab:
		TabMode.SPRITES:
			_draw_sprite_gizmos(line_w)
		TabMode.WHIP:
			_draw_whip_gizmos(line_w)
		TabMode.SHADER:
			_draw_shader_gizmos(line_w)

func _draw_sprite_gizmos(line_w: float) -> void:
	var target: Sprite2D = null
	if active_sprite_node is Sprite2D:
		target = active_sprite_node
	elif active_sprite_node:
		target = active_sprite_node.get_node_or_null("PhasedAnimator/Sprite2D") as Sprite2D
		if target == null:
			for ch in active_sprite_node.get_children():
				if ch is Sprite2D:
					target = ch
					break
				for gch in ch.get_children():
					if gch is Sprite2D:
						target = gch
						break

	if target and target.texture:
		var tex: Texture2D = target.texture
		var hf: int = maxi(1, target.hframes)
		var vf: int = maxi(1, target.vframes)
		var frame_w: float = tex.get_width() / float(hf)
		var frame_h: float = tex.get_height() / float(vf)
		var frame_size := Vector2(frame_w, frame_h)
		var frame_rect := Rect2(target.global_position - frame_size / 2.0, frame_size)

		# Cyan frame bounding box
		gizmo_overlay.draw_rect(frame_rect, Color(0.2, 0.8, 1.0, 0.8), false, line_w)

		# Subtle 16px UV grid lines inside frame
		var step_sz := 16.0
		var gx := frame_rect.position.x + step_sz
		while gx < frame_rect.position.x + frame_rect.size.x:
			gizmo_overlay.draw_line(Vector2(gx, frame_rect.position.y), Vector2(gx, frame_rect.position.y + frame_rect.size.y), Color(0.3, 0.6, 0.9, 0.25), line_w)
			gx += step_sz
		var gy := frame_rect.position.y + step_sz
		while gy < frame_rect.position.y + frame_rect.size.y:
			gizmo_overlay.draw_line(Vector2(frame_rect.position.x, gy), Vector2(frame_rect.position.x + frame_rect.size.x, gy), Color(0.3, 0.6, 0.9, 0.25), line_w)
			gy += step_sz

		# Green UsedRect (sliced to active frame)
		var img: Image = tex.get_image()
		if img:
			var f_col: int = target.frame % hf
			var f_row: int = int(target.frame / hf)
			var frame_region := Rect2i(f_col * int(frame_w), f_row * int(frame_h), int(frame_w), int(frame_h))
			var used_rect := img.get_region(frame_region).get_used_rect()
			if used_rect.size != Vector2i.ZERO:
				var frame_top_left := target.global_position - frame_size / 2.0
				var used_draw_rect := Rect2(frame_top_left + Vector2(used_rect.position), Vector2(used_rect.size))
				gizmo_overlay.draw_rect(used_draw_rect, Color(0.3, 1.0, 0.4, 0.85), false, line_w)

func _draw_whip_gizmos(line_w: float) -> void:
	if whip_points.is_empty():
		return
	var min_p := whip_points[0]
	var max_p := whip_points[0]
	for p in whip_points:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	var bounds := Rect2(min_p, max_p - min_p)
	gizmo_overlay.draw_rect(bounds, Color(0.9, 0.7, 0.2, 0.6), false, line_w)

func _draw_shader_gizmos(line_w: float) -> void:
	for x_pos in [-120.0, 0.0, 120.0]:
		gizmo_overlay.draw_line(Vector2(x_pos - 8, 0), Vector2(x_pos + 8, 0), Color(1.0, 0.85, 0.25, 0.7), line_w)
		gizmo_overlay.draw_line(Vector2(x_pos, -8), Vector2(x_pos, 8), Color(1.0, 0.85, 0.25, 0.7), line_w)

func _switch_tab(mode: TabMode) -> void:
	current_tab = mode
	for m in tab_containers:
		tab_containers[m].visible = (m == current_tab)
	if sprite_info_lbl:
		sprite_info_lbl.visible = (current_tab == TabMode.SPRITES)
	if whip_info_lbl:
		whip_info_lbl.visible = (current_tab == TabMode.WHIP)
	if shader_info_lbl:
		shader_info_lbl.visible = (current_tab == TabMode.SHADER)
	if audit_panel:
		audit_panel.visible = (current_tab == TabMode.ICONS)
	if tab3_swarm_mgr:
		tab3_swarm_mgr.set_physics_process(current_tab == TabMode.SHADER)
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

func _cycle_backdrop() -> void:
	active_backdrop_idx = (active_backdrop_idx + 1) % BACKDROP_COLORS.size()
	if active_backdrop_idx == 3: # Checkerboard
		backdrop_rect.visible = false
		backdrop_checker.visible = true
		backdrop_checker.queue_redraw()
	else:
		backdrop_checker.visible = false
		backdrop_rect.visible = true
		backdrop_rect.color = BACKDROP_COLORS[active_backdrop_idx]

func _cycle_zoom() -> void:
	zoom_idx = (zoom_idx + 1) % zoom_levels.size()
	var z := zoom_levels[zoom_idx]
	if camera:
		camera.zoom = Vector2(z, z)

func _process(delta: float) -> void:
	if is_anim_playing and current_tab == TabMode.SPRITES:
		anim_tick_timer += delta
		if anim_tick_timer >= (1.0 / anim_fps):
			anim_tick_timer = 0.0
			if active_phased_anim:
				active_phased_anim.advance(false)
			elif active_sprite_node is Sprite2D:
				var s: Sprite2D = active_sprite_node
				var total := s.hframes * s.vframes
				if total > 1:
					s.frame = (s.frame + 1) % total
			_refresh_sprite_info()

	if is_anim_playing and current_tab == TabMode.SHADER:
		shader_oscillator_time += delta * 3.0
		var osc := Vector2(sin(shader_oscillator_time) * 10.0, cos(shader_oscillator_time) * 5.0)
		if elite_material:
			elite_material.set_shader_parameter("motion_offset", osc)

func _handle_room_key(event: InputEventKey) -> bool:
	match DebugController.get_effective_keycode(event):
		KEY_1:
			_switch_tab(TabMode.SPRITES)
			return true
		KEY_2:
			_switch_tab(TabMode.WHIP)
			return true
		KEY_3:
			_switch_tab(TabMode.SHADER)
			return true
		KEY_4:
			_switch_tab(TabMode.ICONS)
			return true
		KEY_BRACKETLEFT:
			if current_tab == TabMode.SPRITES:
				_load_sprite_catalog_item(sprite_cat_idx - 1)
			elif current_tab == TabMode.WHIP:
				_load_whip_catalog_item(whip_cat_idx - 1)
			return true
		KEY_BRACKETRIGHT:
			if current_tab == TabMode.SPRITES:
				_load_sprite_catalog_item(sprite_cat_idx + 1)
			elif current_tab == TabMode.WHIP:
				_load_whip_catalog_item(whip_cat_idx + 1)
			return true
		KEY_SPACE:
			is_anim_playing = not is_anim_playing
			_refresh_sprite_info()
			_refresh_shader_info()
			return true
		KEY_COMMA:
			_step_sprite_frame(-1)
			return true
		KEY_PERIOD:
			_step_sprite_frame(1)
			return true
		KEY_P:
			if active_phased_anim:
				active_phased_anim.advance(true)
				_refresh_sprite_info()
			return true
		KEY_T:
			if current_tab == TabMode.WHIP:
				whip_tile_middle = not whip_tile_middle
				if whip_material:
					whip_material.set_shader_parameter("tile_middle", whip_tile_middle)
				_refresh_whip_info()
				return true
		KEY_C:
			if current_tab == TabMode.WHIP:
				whip_hide_caps = not whip_hide_caps
				if whip_material:
					whip_material.set_shader_parameter("hide_caps", whip_hide_caps)
				_refresh_whip_info()
				return true
		KEY_UP:
			if active_phased_anim:
				active_phased_anim.row_index += 1
				active_phased_anim.update_sprite()
				_refresh_sprite_info()
			elif current_tab == TabMode.SHADER:
				trail_mode_idx = (trail_mode_idx + 1) % 3
				if elite_material:
					elite_material.set_shader_parameter("trail_mode", trail_mode_idx)
				_refresh_shader_info()
			return true
		KEY_DOWN:
			if active_phased_anim:
				active_phased_anim.row_index = maxi(0, active_phased_anim.row_index - 1)
				active_phased_anim.update_sprite()
				_refresh_sprite_info()
			elif current_tab == TabMode.SHADER:
				trail_mode_idx = posmod(trail_mode_idx - 1, 3)
				if elite_material:
					elite_material.set_shader_parameter("trail_mode", trail_mode_idx)
				_refresh_shader_info()
			return true
		KEY_B:
			_cycle_backdrop()
			return true
		KEY_G:
			show_gizmos = not show_gizmos
			if gizmo_overlay:
				gizmo_overlay.queue_redraw()
			return true
		KEY_EQUAL, KEY_PLUS:
			zoom_idx = mini(zoom_idx + 1, zoom_levels.size() - 1)
			if camera: camera.zoom = Vector2(zoom_levels[zoom_idx], zoom_levels[zoom_idx])
			if gizmo_overlay: gizmo_overlay.queue_redraw()
			return true
		KEY_MINUS:
			zoom_idx = maxi(zoom_idx - 1, 0)
			if camera: camera.zoom = Vector2(zoom_levels[zoom_idx], zoom_levels[zoom_idx])
			if gizmo_overlay: gizmo_overlay.queue_redraw()
			return true
		KEY_0:
			_reset_camera()
			return true
		KEY_A:
			_run_icon_audit()
			return true

	return false

func _step_sprite_frame(dir: int) -> void:
	is_anim_playing = false
	if active_phased_anim:
		active_phased_anim.local_frame = posmod(active_phased_anim.local_frame + dir, active_phased_anim.total_frames)
		active_phased_anim.update_sprite()
	elif active_sprite_node is Sprite2D:
		var s: Sprite2D = active_sprite_node
		var total := s.hframes * s.vframes
		if total > 1:
			s.frame = posmod(s.frame + dir, total)
	_refresh_sprite_info()
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

func _update_whip_length() -> void:
	if not whip_line:
		return
	whip_line.clear_points()
	var total_len := 0.0
	for i in range(whip_points.size()):
		whip_line.add_point(whip_points[i])
		if i > 0:
			total_len += whip_points[i - 1].distance_to(whip_points[i])
	if whip_material:
		whip_material.set_shader_parameter("total_length", maxf(1.0, total_len))
	if whip_handles:
		whip_handles.queue_redraw()
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

# Whip point dragging, Camera Panning & Mouse Wheel Zoom
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mev := event as InputEventMouseButton
		if mev.pressed and mev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_zoom_to(mini(zoom_idx + 1, zoom_levels.size() - 1), true)
			get_viewport().set_input_as_handled()
			return
		elif mev.pressed and mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_zoom_to(maxi(zoom_idx - 1, 0), true)
			get_viewport().set_input_as_handled()
			return
		elif mev.button_index == MOUSE_BUTTON_MIDDLE or mev.button_index == MOUSE_BUTTON_RIGHT:
			is_panning_camera = mev.pressed
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and is_panning_camera and camera:
		var mm := event as InputEventMouseMotion
		camera.position -= mm.relative / maxf(0.01, camera.zoom.x)
		get_viewport().set_input_as_handled()
		return

	if current_tab == TabMode.WHIP and event is InputEventMouseButton:
		var mev := event as InputEventMouseButton
		if mev.button_index == MOUSE_BUTTON_LEFT:
			if mev.pressed:
				var m_pos := get_global_mouse_position()
				for i in range(whip_points.size()):
					if m_pos.distance_to(whip_points[i]) < 18.0:
						dragged_point_idx = i
						if whip_handles: whip_handles.queue_redraw()
						break
			else:
				dragged_point_idx = -1
				if whip_handles: whip_handles.queue_redraw()

	elif current_tab == TabMode.WHIP and event is InputEventMouseMotion and dragged_point_idx != -1:
		whip_points[dragged_point_idx] = get_global_mouse_position()
		_update_whip_length()

	super._unhandled_input(event)

func _cycle_zoom_to(idx: int, toward_mouse: bool = false) -> void:
	var before_world := get_global_mouse_position() if toward_mouse and is_inside_tree() else Vector2.ZERO
	zoom_idx = clamp(idx, 0, zoom_levels.size() - 1)
	var z := zoom_levels[zoom_idx]
	if camera:
		camera.zoom = Vector2(z, z)
		if toward_mouse and is_inside_tree():
			var after_world := get_global_mouse_position()
			camera.position += before_world - after_world
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

func _reset_camera() -> void:
	zoom_idx = 0
	if camera:
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE
	if gizmo_overlay:
		gizmo_overlay.queue_redraw()

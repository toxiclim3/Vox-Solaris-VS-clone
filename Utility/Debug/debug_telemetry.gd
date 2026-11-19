class_name DebugTelemetry
extends PanelContainer

const DPS_WINDOW_SEC: float = 5.0
const REFRESH_INTERVAL: float = 0.2

var total_damage_by_source: Dictionary = {}
var rolling_hits: Array[Dictionary] = []

var header_label: Label
var world_label: Label
var stats_label: Label
var movement_label: Label
var items_label: Label
var dps_label: Label

var _refresh_timer: float = 0.0

func _init() -> void:
	name = "DebugTelemetry"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	theme = load("res://Themes/DebugButtons.tres")
	z_index = 90

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -216.0
	offset_right = -4.0
	offset_top = 24.0
	offset_bottom = 24.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	header_label = _make_label(Color(0.95, 0.95, 0.65))
	world_label = _make_label(Color(0.80, 0.92, 1.0))
	stats_label = _make_label(Color(0.85, 1.0, 0.85))
	movement_label = _make_label(Color(0.70, 0.95, 1.0))
	items_label = _make_label(Color(1.0, 0.82, 0.60))
	dps_label = _make_label(Color(0.95, 0.95, 0.95))

	vbox.add_child(header_label)
	vbox.add_child(world_label)
	vbox.add_child(stats_label)
	vbox.add_child(movement_label)
	vbox.add_child(items_label)
	vbox.add_child(dps_label)

func _make_label(col: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl

func _ready() -> void:
	if not GlobalEvents.weapon_damage_dealt.is_connected(_on_weapon_damage_dealt):
		GlobalEvents.weapon_damage_dealt.connect(_on_weapon_damage_dealt)
	refresh_now()

func _exit_tree() -> void:
	if GlobalEvents.weapon_damage_dealt.is_connected(_on_weapon_damage_dealt):
		GlobalEvents.weapon_damage_dealt.disconnect(_on_weapon_damage_dealt)

func _on_weapon_damage_dealt(source: String, amount: float, _target_node: Object) -> void:
	if amount <= 0.0:
		return
	var norm := GlobalEvents.normalize_damage_source(source)
	total_damage_by_source[norm] = float(total_damage_by_source.get(norm, 0.0)) + amount
	rolling_hits.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"source": norm,
		"amount": amount,
	})

func reset_meter() -> void:
	total_damage_by_source.clear()
	rolling_hits.clear()
	refresh_now()

func _prune_rolling_hits(window_sec: float = DPS_WINDOW_SEC) -> void:
	var cutoff := (Time.get_ticks_msec() / 1000.0) - window_sec
	while rolling_hits.size() > 0 and float(rolling_hits[0].get("time", 0.0)) < cutoff:
		rolling_hits.remove_at(0)

func get_source_dps(source: String, window_sec: float = DPS_WINDOW_SEC) -> float:
	_prune_rolling_hits(window_sec)
	if window_sec <= 0.0:
		return 0.0
	var norm := GlobalEvents.normalize_damage_source(source)
	var sum := 0.0
	for hit in rolling_hits:
		if hit["source"] == norm:
			sum += float(hit["amount"])
	return sum / window_sec

func get_total_dps(window_sec: float = DPS_WINDOW_SEC) -> float:
	_prune_rolling_hits(window_sec)
	if window_sec <= 0.0:
		return 0.0
	var sum := 0.0
	for hit in rolling_hits:
		sum += float(hit["amount"])
	return sum / window_sec

func get_ranked_sources(window_sec: float = DPS_WINDOW_SEC) -> Array[Dictionary]:
	_prune_rolling_hits(window_sec)
	var rolling_by_source: Dictionary = {}
	for hit in rolling_hits:
		var src: String = hit["source"]
		rolling_by_source[src] = float(rolling_by_source.get(src, 0.0)) + float(hit["amount"])

	var grand_total := 0.0
	for src in total_damage_by_source.keys():
		grand_total += float(total_damage_by_source[src])

	var rows: Array[Dictionary] = []
	for src in total_damage_by_source.keys():
		var tot := float(total_damage_by_source[src])
		var dps := float(rolling_by_source.get(src, 0.0)) / maxf(0.001, window_sec)
		var share := (tot / grand_total * 100.0) if grand_total > 0.0 else 0.0
		rows.append({
			"source": str(src),
			"dps": dps,
			"total": tot,
			"share": share,
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["dps"]), float(b["dps"])):
			return float(a["dps"]) > float(b["dps"])
		return float(a["total"]) > float(b["total"])
	)
	return rows

func export_csv(save_path: String = "user://debug_dps_export.csv") -> String:
	var lines: PackedStringArray = ["source,dps_5s,total_damage,share_percent"]
	for row in get_ranked_sources():
		lines.append("%s,%.2f,%.2f,%.2f" % [row["source"], row["dps"], row["total"], row["share"]])
	var csv_text := "\n".join(lines)
	if save_path != "":
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_string(csv_text)
	return csv_text

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		refresh_now()

func refresh_now() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / float(max(1, fps))
	var taint_badge := ""
	if StatsManager.is_run_tainted:
		taint_badge = " [TAINT+STATS]" if StatsManager.allow_tainted_stats else " [TAINTED]"
	var pause_badge := " [PAUSED]" if get_tree() and get_tree().paused else ""
	header_label.text = "FPS:%d (%.1fms) | %.2fx%s%s" % [fps, frame_ms, Engine.time_scale, taint_badge, pause_badge]

	var swarm_count := 0
	var enemy_nodes := 0
	var dummy_count := 0
	var boss_count := 0
	var gem_count := 0
	if get_tree():
		var sm := get_tree().get_first_node_in_group("swarm_manager")
		if sm and sm.get("swarm_data") != null:
			swarm_count = sm.swarm_data.size()
		dummy_count = get_tree().get_node_count_in_group("target_dummy")
		boss_count = get_tree().get_node_count_in_group("boss")
		enemy_nodes = max(0, get_tree().get_node_count_in_group("enemy") - dummy_count)
		gem_count = get_tree().get_node_count_in_group("loot")
	var mag_chance := GlobalEvents.MAGNET_MAX_CHANCE * clampf(float(gem_count) / float(GlobalEvents.MAGNET_FULL_CHANCE_GEMS), 0.0, 1.0) * 100.0
	world_label.text = "Swarm:%d Node:%d Boss:%d Dum:%d\nGems:%d (Magnet:%.2f%%)" % [swarm_count, enemy_nodes, boss_count, dummy_count, gem_count, mag_chance]

	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if p and is_instance_valid(p) and p.get("hp") != null:
		var cur_hp := float(p.get("hp"))
		var cur_maxhp := maxf(1.0, float(p.get("maxhp") if p.get("maxhp") != null else 1.0))
		var hp_pct := int(round(cur_hp / cur_maxhp * 100.0))
		var arm := float(p.get("armor") if p.get("armor") != null else 0.0)
		var dr_pct := (arm / (arm + 10.0)) * 100.0 if arm > 0.0 else 0.0
		var spd := float(p.get("movement_speed") if p.get("movement_speed") != null else 0.0)
		var cdr_pct := int(round(float(p.get("spell_cooldown") if p.get("spell_cooldown") != null else 0.0) * 100.0))
		var sz_pct := int(round(float(p.get("spell_size") if p.get("spell_size") != null else 0.0) * 100.0))
		var extra := int(p.get("additional_attacks") if p.get("additional_attacks") != null else 0)
		var dmg_mult := float(p.get("damage_multiplier") if p.get("damage_multiplier") != null else 1.0)
		var ls_pct := float(p.get("lifesteal") if p.get("lifesteal") != null else 0.0) * 100.0
		var refl := int(round(float(p.get("reflected_damage") if p.get("reflected_damage") != null else 0.0)))
		stats_label.text = "HP:%.0f/%.0f (%d%%) Arm:%d (DR %.0f%%)\nSpd:%.0f CDR:%d%% Size:+%d%% +Atk:%d\nDMG:x%.2f LS:%.1f%% Refl:%d" % [
			cur_hp, cur_maxhp, hp_pct, int(arm), dr_pct, spd, cdr_pct, sz_pct, extra, dmg_mult, ls_pct, refl
		]

		var mode_str := "COUPLED" if GlobalEvents.is_movement_coupled() else "VANILLA"
		var mob_type := str(p.get("mobility_type") if p.get("mobility_type") != null else "none")
		var mob_cd := float(p.get("mobility_cooldown") if p.get("mobility_cooldown") != null else 0.0)
		var cd_str := "RDY" if mob_cd <= 0.0 else "%.1fs" % mob_cd
		var rock_str := " [ROCK]" if bool(p.get("rock_stance_active")) else ""
		var anc_str := " [ANC]" if bool(p.get("is_anchored")) else ""
		var stride_px := float(p.get("stride_distance_total") if p.get("stride_distance_total") != null else 0.0)
		var bast_pct := float(p.get("bastion_charge") if p.get("bastion_charge") != null else 0.0) * 100.0
		movement_label.text = "Move:%s | %s:%s%s\nStride:%.0fpx | Bastion:%.0f%%%s" % [
			mode_str, mob_type, cd_str, rock_str, stride_px, bast_pct, anc_str
		]

		var item_parts: PackedStringArray = []
		if int(p.get("warding_brooch_level") if p.get("warding_brooch_level") != null else 0) > 0:
			var b_txt := "READY" if bool(p.get("warding_brooch_charge")) else "%.1fs" % float(p.get("warding_brooch_timer") if p.get("warding_brooch_timer") != null else 0.0)
			item_parts.append("Brooch:" + b_txt)
		if int(p.get("impact_buckler_level") if p.get("impact_buckler_level") != null else 0) > 0:
			var ib_cd := float(p.get("impact_buckler_cooldown") if p.get("impact_buckler_cooldown") != null else 0.0)
			item_parts.append("Buckler:" + ("READY" if ib_cd <= 0.0 else "%.1fs" % ib_cd))
		if int(p.get("frenzy_charm_level") if p.get("frenzy_charm_level") != null else 0) > 0:
			var f_act := bool(p.get("frenzy_charm_active"))
			item_parts.append("Frenzy:" + ("ON" if f_act else "off"))
		if int(p.get("glass_talisman_level") if p.get("glass_talisman_level") != null else 0) > 0:
			var g_pct := int(round(float(p.get("glass_talisman_damage_bonus") if p.get("glass_talisman_damage_bonus") != null else 0.0) * 100.0))
			item_parts.append("Talisman:+%d%%" % g_pct)
		if item_parts.size() > 0:
			items_label.visible = true
			items_label.text = " | ".join(item_parts)
		else:
			items_label.visible = false
	else:
		stats_label.text = "Player: N/A"
		var mode_str := "COUPLED" if GlobalEvents.is_movement_coupled() else "VANILLA"
		movement_label.text = "Move:%s | Player: N/A" % mode_str
		items_label.visible = false

	var ranked := get_ranked_sources()
	var total_dps := get_total_dps()
	var dps_lines: PackedStringArray = ["5s DPS (Total %.1f):" % total_dps]
	var max_rows := mini(8, ranked.size())
	if max_rows == 0:
		dps_lines.append("  (no damage recorded)")
	else:
		for i in range(max_rows):
			var r: Dictionary = ranked[i]
			dps_lines.append("  %-13s %6.1f/s | %6.0f (%2.0f%%)" % [
				str(r["source"]).left(13), float(r["dps"]), float(r["total"]), float(r["share"])
			])
	dps_label.text = "\n".join(dps_lines)

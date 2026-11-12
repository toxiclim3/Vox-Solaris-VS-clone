#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2024-2026 SurvivorsClone Contributors
"""
Weapon Scaffolder CLI for SurvivorsClone (Godot 4.6).

Generates boilerplate for game-compliant weapons adhering strictly to:
- Layer 3 (bit 2, value 4) player attack collision
- CollisionShape2D named child node (SwarmManager requirement)
- Dynamic Spawner Pattern (res://Player/Attack/<weapon>/<weapon>_spawner.gd)
- PhasedAnimator lifecycle for AOE weapons (Rule 11)
- 5-Tier UpgradeDb registration snippet (Levels 1-4 + Endless)
- 3-Language localization snippet (EN, RU, UA)
"""

import argparse
import os
import sys
from pathlib import Path


SPAWNER_TEMPLATE = """extends Node2D

# Dynamic Spawner for {weapon_title} ({weapon_id})
# Manages cooldown timers, burst queues, and player stat scaling.

var {weapon_id} = preload("res://Player/Attack/{weapon_id}/{weapon_id}.tscn")

@onready var player = get_tree().get_first_node_in_group("player")

var baseammo = {base_ammo}
var ammo = {base_ammo}
var attackspeed = {attack_speed}
var level = 0

# Cooldown and burst timers
var timer: Timer
var attackTimer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = attackspeed * (1.0 - player.spell_cooldown)
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	attackTimer = Timer.new()
	attackTimer.wait_time = 0.075
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	add_child(attackTimer)

func _on_timer_timeout() -> void:
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
	ammo = baseammo + extra_attacks
	attackTimer.start()

func _on_attack_timer_timeout() -> void:
	if ammo > 0:
		spawn_attack()
		ammo -= 1
		if ammo > 0:
			attackTimer.start()
		else:
			attackTimer.stop()

func spawn_attack() -> void:
	var proj = {weapon_id}.instantiate()
	proj.position = player.position
	proj.target = player.get_random_target()
	proj.level = level
	# Add to world space, not player space
	player.get_parent().add_child(proj)

func upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"{weapon_id}1":
			level = 1
			baseammo = {base_ammo}
		"{weapon_id}2":
			level = 2
			baseammo = {base_ammo} + 1
		"{weapon_id}3":
			level = 3
			attackspeed = max(0.2, attackspeed * 0.85)
		"{weapon_id}4":
			level = 4
			baseammo = {base_ammo} + 2
		"{weapon_id}_endless":
			level += 1
			baseammo += 1

	if timer:
		timer.wait_time = attackspeed * (1.0 - player.spell_cooldown)
"""

PROJECTILE_SCRIPT_TEMPLATE = """extends Area2D

# Projectile behavior for {weapon_title} ({weapon_id})
# Layer 3 / Value 4 collision for SwarmManager compatibility.

var level: int = 1
var hp: int = {hp}
var speed: float = {speed}
var damage: float = {damage}
var knockback_amount: float = {knockback}
var attack_size: float = 1.0

var target: Vector2 = Vector2.ZERO
var angle: Vector2 = Vector2.ZERO

@onready var player = get_tree().get_first_node_in_group("player")
var hit_once_array: Array = []

signal remove_from_array(object)

func _ready() -> void:
	top_level = true
	# Ensure group and collision layer 4 (Layer 3)
	add_to_group("attack")
	collision_layer = 4
	collision_mask = 0

	if target != Vector2.ZERO:
		angle = global_position.direction_to(target)
		rotation = angle.angle()
	else:
		angle = Vector2.RIGHT.rotated(rotation)

	attack_size = 1.0 * (1.0 + player.spell_size)
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(attack_size, attack_size), 0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	position += angle * speed * delta

func enemy_hit(charge: int = 1) -> void:
	hp -= charge
	if hp <= 0:
		emit_signal("remove_from_array", self)
		queue_free()

func _on_timer_timeout() -> void:
	emit_signal("remove_from_array", self)
	queue_free()
"""

AOE_SCRIPT_TEMPLATE = """extends Area2D

# Timed Persistent AOE for {weapon_title} ({weapon_id})
# Adheres to PhasedAnimator standard (Start -> Loop -> End) to prevent popping.

var level: int = 1
var damage: float = {damage}
var knockback_amount: float = {knockback}
var attack_size: float = 1.0
var target: Vector2 = Vector2.ZERO

@onready var player = get_tree().get_first_node_in_group("player")
@onready var duration_timer: Timer = $DurationTimer

var animator: PhasedAnimator
var hit_once_array: Array = []

signal remove_from_array(object)

func _ready() -> void:
	top_level = true
	add_to_group("attack")
	collision_layer = 4
	collision_mask = 0

	attack_size = 1.0 * (1.0 + player.spell_size)
	scale = Vector2(attack_size, attack_size)

	# Initialize PhasedAnimator for smooth lifecycle
	animator = PhasedAnimator.new()
	animator.setup_phases(3, 4, 3) # start, loop, end frames
	add_child(animator)

	duration_timer.timeout.connect(_on_duration_timeout)
	duration_timer.start({duration})

func _process(delta: float) -> void:
	var is_expiring = duration_timer.time_left < (duration_timer.wait_time * 0.25)
	if animator:
		animator.advance(is_expiring)

func _on_duration_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
"""

TSCN_TEMPLATE = """[gd_scene load_steps=3 format=3 uid="uid://{uid_hash}"]

[ext_resource type="Script" path="res://Player/Attack/{weapon_id}/{weapon_id}.gd" id="1_{weapon_id}"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = {radius}

[node name="{weapon_id}" type="Area2D" groups=["attack"]]
top_level = true
collision_layer = 4
collision_mask = 0
script = ExtResource("1_{weapon_id}")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[node name="Timer" type="Timer" parent="."]
wait_time = {lifetime}
one_shot = true
autostart = true

[connection signal="timeout" from="Timer" to="." method="_on_timer_timeout"]
"""


def generate_upgrade_db_snippet(weapon_id: str, title: str) -> str:
    return f"""\t# --- {title} ({weapon_id}) Registration ---
\t"{weapon_id}1": {{
\t\t"icon": ICON_PATH + "{weapon_id}.png",
\t\t"displayname": "item_{weapon_id}",
\t\t"details": "ItemDesc_{weapon_id}1",
\t\t"level": "item_level1",
\t\t"prerequisite": [],
\t\t"type": "weapon"
\t}},
\t"{weapon_id}2": {{
\t\t"icon": ICON_PATH + "{weapon_id}.png",
\t\t"displayname": "item_{weapon_id}",
\t\t"details": "ItemDesc_{weapon_id}2",
\t\t"level": "item_level2",
\t\t"prerequisite": ["{weapon_id}1"],
\t\t"type": "weapon"
\t}},
\t"{weapon_id}3": {{
\t\t"icon": ICON_PATH + "{weapon_id}.png",
\t\t"displayname": "item_{weapon_id}",
\t\t"details": "ItemDesc_{weapon_id}3",
\t\t"level": "item_level3",
\t\t"prerequisite": ["{weapon_id}2"],
\t\t"type": "weapon"
\t}},
\t"{weapon_id}4": {{
\t\t"icon": ICON_PATH + "{weapon_id}.png",
\t\t"displayname": "item_{weapon_id}",
\t\t"details": "ItemDesc_{weapon_id}4",
\t\t"level": "item_level4",
\t\t"prerequisite": ["{weapon_id}3"],
\t\t"type": "weapon"
\t}},
\t"{weapon_id}_endless": {{
\t\t"icon": ICON_PATH + "{weapon_id}.png",
\t\t"displayname": "item_{weapon_id}",
\t\t"details": "item_level_endless_details",
\t\t"level": "item_level_endless",
\t\t"prerequisite": ["{weapon_id}4"],
\t\t"type": "endless",
\t\t"stat_modifiers": {{"damage": 1}}
\t}},"""


def generate_translations_snippet(weapon_id: str, title: str) -> str:
    return f'''"item_{weapon_id}","{title}","{title}","{title}"
"ItemDesc_{weapon_id}1","Fires {title} at enemies.","Стреляет {title} во врагов.","Стріляє {title} у ворогів."
"ItemDesc_{weapon_id}2","Fires an additional projectile.","Выпускает дополнительный снаряд.","Випускає додатковий снаряд."
"ItemDesc_{weapon_id}3","Reduces attack cooldown.","Уменьшает перезарядку атаки.","Зменшує перезарядку атаки."
"ItemDesc_{weapon_id}4","Fires 2 additional projectiles.","Выпускает еще 2 дополнительных снаряда.","Випускає ще 2 додаткових снаряди."'''


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Scaffold Godot 4.6 compliant weapon for SurvivorsClone.")
    parser.add_argument("weapon_id", help="Internal identifier (lowercase, e.g. sunstrike, frostnova)")
    parser.add_argument("--title", help="Human-readable title (e.g. 'Sun Strike')", default=None)
    parser.add_argument("--type", choices=["projectile", "aoe"], default="projectile", help="Weapon archetype")
    parser.add_argument("--damage", type=float, default=15.0, help="Base damage")
    parser.add_argument("--knockback", type=float, default=50.0, help="Knockback amount")
    parser.add_argument("--speed", type=float, default=240.0, help="Projectile speed")
    parser.add_argument("--cooldown", type=float, default=1.5, help="Base cooldown (seconds)")
    parser.add_argument("--ammo", type=int, default=1, help="Base projectile count")
    parser.add_argument("--out-dir", type=str, default=None, help="Output directory (defaults to res://Player/Attack/<weapon_id>)")
    parser.add_argument("--dry-run", action="store_true", help="Print generated files to stdout without writing")

    args = parser.parse_args()

    weapon_id = args.weapon_id.strip().lower()
    title = args.title or weapon_id.replace("_", " ").title()

    # Calculate deterministic dummy UID hash for tscn
    uid_hash = f"weapon_{weapon_id}_v1"

    spawner_code = SPAWNER_TEMPLATE.format(
        weapon_id=weapon_id,
        weapon_title=title,
        base_ammo=args.ammo,
        attack_speed=args.cooldown,
    )

    if args.type == "aoe":
        weapon_code = AOE_SCRIPT_TEMPLATE.format(
            weapon_id=weapon_id,
            weapon_title=title,
            damage=args.damage,
            knockback=args.knockback,
            duration=3.0,
        )
    else:
        weapon_code = PROJECTILE_SCRIPT_TEMPLATE.format(
            weapon_id=weapon_id,
            weapon_title=title,
            damage=args.damage,
            knockback=args.knockback,
            speed=args.speed,
            hp=2,
        )

    tscn_code = TSCN_TEMPLATE.format(
        weapon_id=weapon_id,
        uid_hash=uid_hash,
        radius=12.0 if args.type == "projectile" else 32.0,
        lifetime=4.0 if args.type == "projectile" else 3.0,
    )

    upgrade_db_snippet = generate_upgrade_db_snippet(weapon_id, title)
    translations_snippet = generate_translations_snippet(weapon_id, title)

    if args.dry_run:
        print(f"=== Spawner: {weapon_id}_spawner.gd ===")
        print(spawner_code)
        print(f"\n=== Projectile/AOE Script: {weapon_id}.gd ===")
        print(weapon_code)
        print(f"\n=== Scene: {weapon_id}.tscn ===")
        print(tscn_code)
        print(f"\n=== UpgradeDb.UPGRADES Snippet ===")
        print(upgrade_db_snippet)
        print(f"\n=== translations.csv Snippet ===")
        print(translations_snippet)
        return

    # Target directory resolution
    if args.out_dir:
        out_path = Path(args.out_dir)
    else:
        script_dir = Path(__file__).resolve().parent
        repo_root = script_dir.parents[2]
        out_path = repo_root / "Player" / "Attack" / weapon_id

    out_path.mkdir(parents=True, exist_ok=True)

    spawner_file = out_path / f"{weapon_id}_spawner.gd"
    script_file = out_path / f"{weapon_id}.gd"
    tscn_file = out_path / f"{weapon_id}.tscn"
    snippets_file = out_path / f"{weapon_id}_registration_snippets.txt"

    spawner_file.write_text(spawner_code, encoding="utf-8")
    script_file.write_text(weapon_code, encoding="utf-8")
    tscn_file.write_text(tscn_code, encoding="utf-8")

    all_snippets = f"--- UpgradeDb Snippet ---\n{upgrade_db_snippet}\n\n--- Translations Snippet ---\n{translations_snippet}\n"
    snippets_file.write_text(all_snippets, encoding="utf-8")

    print(f"Successfully scaffolded weapon '{title}' ({weapon_id}):")
    print(f"  - Spawner: {spawner_file}")
    print(f"  - Script:  {script_file}")
    print(f"  - Scene:   {tscn_file}")
    print(f"  - Config:  {snippets_file}")


if __name__ == "__main__":
    main()

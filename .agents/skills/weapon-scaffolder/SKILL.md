---
name: weapon-scaffolder
description: Guides and automates the creation of game-compliant weapons for SurvivorsClone, enforcing Layer 3 collision, CollisionShape2D SwarmManager compatibility, PhasedAnimator AOE lifecycles, and 5-tier UpgradeDb registration.
---

# Weapon Scaffolder Skill

## Overview
The `weapon-scaffolder` skill guides and streamlines the addition of new weapons to the SurvivorsClone Godot 4.6 project. Creating a weapon requires satisfying multiple interrelated architectural contracts across player stat scaling, collision detection with mass swarms, dynamic scene spawning, database registration, and localization.

## Architectural Contracts & Rules

### 1. Dynamic Spawner Pattern
Weapons are loaded dynamically when acquired or upgraded in `res://Player/player.gd` lines 548–563.
- Directory convention: `res://Player/Attack/<weapon_name>/`
- Spawner filename: `<weapon_name>_spawner.gd`
- Spawner root node: `Node2D`
- Must implement `upgrade(upgrade_id: String)` handling tiers 1 through 4 and `<weapon>_endless`.
- Spawner attaches directly under `%Weapons` node of the player.
- Spawned projectiles must be added to `player.get_parent().add_child(proj)` (world space), NEVER as children of the player.
- Cooldown formula: `timer.wait_time = attackspeed * (1.0 - player.spell_cooldown)`.
- Burst projectile count formula:
  ```gdscript
  var extra_attacks = int(player.additional_attacks)
  if randf() < (player.additional_attacks - extra_attacks):
      extra_attacks += 1
  ammo = baseammo + extra_attacks
  ```

### 2. SwarmManager & Physics Collision Contracts (Rules 16 & 17)
The high-performance `SwarmManager` (`res://Utility/swarm_manager.gd`) manages thousands of swarm enemies without physics ticks. For attacks to hit swarm enemies:
- **Layer 3 (Bit 2, Value 4)**: Attack root `Area2D` must have `collision_layer = 4` and `collision_mask = 0`. Swarms completely ignore any node in the `"attack"` group that is not on Layer 3.
- **Node Group**: The root `Area2D` MUST belong to the `"attack"` group (`groups=["attack"]`).
- **Child Node Naming**: The `Area2D` MUST contain a child node explicitly named `"CollisionShape2D"`.
- **Exposed Properties**: The `Area2D` must expose `damage: float` and `knockback_amount: float`.

### 3. Persistent & Timed AOE Standard (Rule 11)
Any weapon creating a persistent or lingering AOE area (e.g., gas clouds, ground seals) must implement `PhasedAnimator` (`res://Utility/phased_animator.gd`) with:
- Phased lifecycle: `Start -> Loop -> End`.
- Smooth fade out via `Tween` on termination to prevent visual popping.

### 4. Flexible Asset Rendering (Rule 13)
Whips, chains, or flexible Line2D weapons must use the 3-slice shader `res://Utility/whip_3slice.gdshader` to preserve handle and tip aspect ratios while stretching the body.

### 5. UpgradeDb 5-Tier Registration
Every weapon must register exactly 5 entries in `res://Utility/upgrade_db.gd` (`UPGRADES` dictionary):
- `<weapon>1` to `<weapon>4`: Levels 1 through 4 with prerequisites sequentially chained (`<weapon>1` -> `[]`, `<weapon>2` -> `["<weapon>1"]`, etc.).
- `<weapon>_endless`: Endless tier with prerequisite `["<weapon>4"]`, `type: "endless"`, and `stat_modifiers: {"damage": 1}`.

## Step-by-Step Execution Workflow

### Step 1: Run the Generator Script
Use the companion CLI tool to scaffold the complete weapon package:
```bash
# For a standard projectile weapon:
python .agents/skills/weapon-scaffolder/scaffold_weapon.py <weapon_id> --title "<Display Title>" --damage 15.0 --speed 240.0 --cooldown 1.5

# For an AOE weapon:
python .agents/skills/weapon-scaffolder/scaffold_weapon.py <weapon_id> --title "<Display Title>" --type aoe --damage 20.0 --cooldown 3.0
```
To review generated code without writing files, append `--dry-run`.

### Step 2: Register in `UpgradeDb.gd`
Open `res://Utility/upgrade_db.gd` and paste the generated 5-tier registration snippet from `<weapon_id>_registration_snippets.txt` into the `UPGRADES` dictionary.

### Step 3: Register in `translations.csv`
Open `res://translations/translations.csv` and append the generated localization keys for `item_<weapon_id>` and `ItemDesc_<weapon_id>1` through `4`.
Validate formatting with:
```bash
python .agents/skills/localization-validator/validate_translations.py
```

### Step 4: Add Visual Assets
Place a 32x32 transparently trimmed icon into `res://Textures/Items/Weapons/<weapon_id>.png` (Rule 12).

## Verification & Acceptance Checklist
- [ ] `<weapon>_spawner.gd` exists under `res://Player/Attack/<weapon_id>/`.
- [ ] `<weapon>.tscn` has root `Area2D` with `collision_layer = 4`, `collision_mask = 0`, and group `"attack"`.
- [ ] `<weapon>.tscn` contains a child node named `"CollisionShape2D"`.
- [ ] `UpgradeDb.gd` contains keys `<weapon>1`, `<weapon>2`, `<weapon>3`, `<weapon>4`, and `<weapon>_endless`.
- [ ] `validate_translations.py` reports clean status with return code `0`.

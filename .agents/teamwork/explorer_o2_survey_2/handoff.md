# Handoff Report: Health-Based Items Implementation Survey (R2 & R3)

**Author:** Explorer Subagent (`explorer_o2_survey_2`)  
**Target Audience:** Orchestrator & Implementation Subagents  
**Working Directory:** `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\explorer_o2_survey_2`  
**Date:** 2026-10-08T20:06:00Z  

---

## 1. Observation

### 1.1 Item Database Architecture (`res://Utility/upgrade_db.gd`)
- **Upgrade dictionary format:** All upgrades are stored in constant dictionary `UPGRADES: Dictionary` (`Utility/upgrade_db.gd:6-871`).
- **Entry schema contract:** Every item requires 6 mandatory keys verified by `Tests/Unit/test_upgrade_db.gd:18`:
  `["icon", "displayname", "details", "level", "prerequisite", "type"]`.
  - Allowed types: `["weapon", "upgrade", "bossitem", "item", "endless"]` (`test_upgrade_db.gd:39`).
  - Allowed levels: `["item_level1", "item_level2", "item_level3", "item_level4", "item_levelNA", "item_level_endless"]` (`test_upgrade_db.gd:47`).
  - Prerequisite DAG: Tier 1 items must have `[]` (`test_upgrade_db.gd:93`). Tier $K$ ($K > 1$) must have `["<basename>" + str(K - 1)]` (`test_upgrade_db.gd:101-115`).
  - Endless tier: Type must be `"endless"`, prerequisite must be the maximum tier of that item (e.g. `["glasstalisman4"]`), cannot be another endless entry (`test_upgrade_db.gd:117-127`).
- **Existing passive upgrades:** E.g. `armor1..4` (`lines 115-154`), `speed1..4` (`lines 155-194`), `ringofrejuvenation1..2` (`lines 295-314`, 2 tiers only), `ringofaffinity1..2` (`lines 315-334`, 2 tiers only), `thornring1..4` (`lines 525-564`), `occult_medallion1..4` (`lines 565-600`), `willowisp1..4` (`lines 601-636`).

### 1.2 Player Stats & Upgrades (`res://Player/player.gd`)
- **HP and Max HP representation:**
  - `maxhp: int = 80`, `base_maxhp: int = 80`, `hp: int = maxhp` (`player.gd:3-5`).
  - `healthBar: ProgressBar` updated whenever HP changes (`player.gd:87, 224, 258, 524, 572, 817`).
- **HP Modification Points:**
  1. Taking damage in `_on_hurt_box_hurt()` (`player.gd:231-260`): `hp -= actual_damage`.
  2. Health regen in `_on_regen_timer_timeout()` (`player.gd:219-228`): `hp = clamp(hp + actual_regen * maxhp, 0, maxhp)`.
  3. Lifesteal in `_on_player_dealt_damage()` (`player.gd:812-818`): `hp = clamp(hp + heal_amount, 0, maxhp)`.
  4. Consumable heal in `upgrade_character()` for food (`player.gd:569-572`): `hp = clamp(hp + 20, 0, maxhp)`.
  5. Max HP stat modifier recalculation in `apply_stat_modifiers()` (`player.gd:518-525`): clamps and preserves HP ratio.
- **Weapon Attack Cooldowns & Timers:**
  - `spell_cooldown: float = 0.0` represents cooldown reduction (`player.gd:41, 429, 445`).
  - In all 12 weapon spawners, `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)` (`whip_spawner.gd:44`, `tornado_spawner.gd:44`, `icespear_spawner.gd:43`, etc.).
  - Calling `player.attack()` (`player.gd:214-217`) iterates through all child nodes of `%Weapons` and invokes `.attack()`, resetting their `wait_time`.
- **Armor DR Formula:**
  - `dr = float(armor) / (armor + 40.0)` (`player.gd:241`).
  - `actual_damage = clamp(damage * (1.0 - dr), 0.0, 999.0)` (`player.gd:242, 245`).
- **Endless Stacking Tracking:**
  - `collected_endless: Dictionary` (`player.gd:33`), incremented in `upgrade_character` (`player.gd:576-587`), iterated in `apply_stat_modifiers()` (`player.gd:497-509`).

### 1.3 Collision & Swarm Mechanics (`res://Utility/swarm_manager.gd` & `res://Enemy/Base/enemy_body.gd`)
- **Swarm Collision Convention (Rules 16 & 17, `GEMINI.md`):**
  - Swarm attack detection (`swarm_manager.gd:175-224`): Scans group `"attack"` on Layer 3 (`collision_layer & 4`), looks for child `CollisionShape2D` (`CircleShape2D` or `RectangleShape2D`), reads properties `damage` and `knockback_amount`.
  - Swarm knockback application (`swarm_manager.gd:273`):
    `enemy.knockback = angle * atk.knockback_amount`. Swarm enemies decay knockback at `3.5` units/frame (`swarm_manager.gd:298`).
- **Standard Enemy & Boss Displacement:**
  - In `enemy_body.gd:165`: `knockback = angle * knockback_amount`.
  - `EnemyBody` defines `@export var isBoss = 0` (`enemy_body.gd:10`), and adds bosses to group `"boss"` (`enemy_body.gd:51`).
  - Currently `enemy_body.gd:165` does NOT guard boss displacement: `knockback = angle * knockback_amount` runs unconditionally. Boss immunity requires guarding this line.

### 1.4 Asset Dimensions & Bounding Boxes (`res://Textures/Items/Upgrades/`)
- Checked existing upgrade icons with Python PIL:
  - `boots_4_green.png`: (32, 29), bbox=(0, 0, 32, 29)
  - `helmet_1.png`: (22, 23), bbox=(0, 0, 22, 23)
  - `icon25.png`: (19, 19), bbox=(0, 0, 19, 19)
  - `icon26.png`: (18, 20), bbox=(0, 0, 18, 20)
  - `relic_drone.png`: (28, 30), bbox=(0, 0, 28, 30)
  - `scroll_old.png`: (31, 31), bbox=(0, 0, 31, 31)
  - `thick_new.png`: (32, 31), bbox=(0, 0, 32, 31)
- Rule 12 specifies that icons in `ItemOption` and `ItemContainer` assume tight bounding boxes with 0 transparent margins.

### 1.5 Translations (`translations/translations.csv`)
- Validated via `python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv`:
  - 293 total entries, 0 errors, 0 warnings.
  - Strict 4-column RFC 4180 format: `"keys","en","ru","ua"`.
  - Naming conventions: item display names use `"item_<base_name>"`; tier descriptions use `"ItemDesc_<Name><tier>"`.

---

## 2. Logic Chain

### 2.1 Health Signal Architecture & YAGNI Compliance
1. **Direct Signal Implementation:** Rather than introducing complex state machines or new manager singletons, `player.gd` should declare:
   ```gdscript
   signal health_ratio_changed(current_ratio: float, previous_ratio: float)
   ```
2. **Centralized HP Mutator (`_set_hp`):**
   Wrapping HP updates in a single private helper ensures that:
   - Any change to HP computes `previous_ratio` and `current_ratio`.
   - `health_ratio_changed.emit(current_ratio, previous_ratio)` fires if `not is_equal_approx(current_ratio, previous_ratio)`.
   - Health bar UI (`healthBar.value`) stays synchronized.
   - Death trigger (`death()`) is evaluated consistently.
3. **Decentralized Item Handlers:**
   Each item connects or reacts directly to `health_ratio_changed`:
   - **Glass Talisman:** Tracks `cur_ratio >= 0.95`.
   - **Warding Brooch:** Checks `cur_ratio >= 0.90` for out-of-combat charging.
   - **Frenzy Charm:** Tracks `cur_ratio < 0.30`.
   - **Impact Buckler:** Checks transition `previous_ratio >= 0.20 and current_ratio < 0.20`.

### 2.2 Glass Talisman Specification
- **Tiers:** 4 tiers (`glasstalisman1`..`4`) + endless (`glasstalisman_endless`).
- **Bonuses:**
  - Tier 1: +5% damage (`0.05`)
  - Tier 2: +10% damage (`0.10`)
  - Tier 3: +15% damage (`0.15`)
  - Tier 4: +25% damage (`0.25`)
  - Endless: +2% damage per stack (`0.02 * collected_endless["glasstalisman"]`)
- **Player damage integration:**
  - Add `var damage_multiplier: float = 1.0` and `var glass_talisman_damage_bonus: float = 0.0` in `player.gd`.
  - When `cur_ratio >= 0.95`, `glass_talisman_damage_bonus = [0, 0.05, 0.10, 0.15, 0.25][tier] + (0.02 * endless)`.
  - When `cur_ratio < 0.95`, `glass_talisman_damage_bonus = 0.0`.
  - `damage_multiplier = 1.0 + glass_talisman_damage_bonus`.
  - In `GlobalEvents.get_player_damage_modifier()`:
    Multiply difficulty modifier by `player.damage_multiplier` when a player node is present in the tree. Because both `enemy_body.gd:164` and `swarm_manager.gd:265` multiply all damage by `GlobalEvents.get_player_damage_modifier()`, every weapon damage source automatically inherits this damage multiplier without modifying 12 weapon scripts!

### 2.3 Warding Brooch Specification
- **Tiers:** 2 tiers (`wardingbrooch1`..`2`). No endless tier.
- **Mechanics:**
  - `var warding_brooch_charge: bool = false`
  - `var time_since_last_hit: float = 0.0`
  - In `_physics_process(delta)`:
    If `warding_brooch_level > 0 and not warding_brooch_charge`:
      `time_since_last_hit += delta`
      If `time_since_last_hit >= 10.0 and (float(hp) / float(maxhp)) >= 0.90`:
        `warding_brooch_charge = true`
  - In `_on_hurt_box_hurt(damage, ...)`:
    When `actual_damage > 0` and `warding_brooch_charge`:
      `var max_absorb = maxhp * 0.05`
      If `actual_damage <= max_absorb`:
        `actual_damage = 0.0`
      Else:
        `actual_damage -= max_absorb` # excess spills over
      `warding_brooch_charge = false`
      `time_since_last_hit = 0.0`
      If `warding_brooch_level >= 2`:
        Trigger +15% movement speed boost for 3.0 seconds (`warding_speed_boost_active = true`, reset after 3s via timer).

### 2.4 Frenzy Charm Specification
- **Tiers:** 3 tiers (`frenzycharm1`..`3`). No endless tier.
- **Bonuses:**
  - Tier 1: +10% attack speed (`0.10`)
  - Tier 2: +20% attack speed (`0.20`)
  - Tier 3: +30% attack speed (`0.30`)
- **Mechanics:**
  - Active strictly when `float(hp) / float(maxhp) < 0.30`.
  - In `apply_stat_modifiers()`:
    If `frenzy_charm_active and frenzy_charm_level > 0`:
      `spell_cooldown += [0, 0.10, 0.20, 0.30][frenzy_charm_level]`
  - Whenever frenzy state toggles, call `apply_stat_modifiers()` and `attack()`.
  - Cooldown safety floor: Ensure weapon timer wait times obey $t_{\text{wait}} \ge 0.05\text{s}$ (`max(0.05, wait_time)`).

### 2.5 Impact Buckler & Crowd Control Specification
- **Tiers:** 3 tiers (`impactbuckler1`..`3`). No endless tier.
- **Cooldowns:**
  - Tier 1: 60s
  - Tier 2: 40s
  - Tier 3: 20s
- **Trigger:**
  - Triggered in `_on_health_ratio_changed` when `current_ratio < 0.20 and previous_ratio >= 0.20`.
  - Only fires if `impact_buckler_cooldown <= 0.0`.
  - Sets `impact_buckler_cooldown = [0, 60.0, 40.0, 20.0][impact_buckler_level]`.
- **Shockwave Scene (`impact_buckler_shockwave.tscn`):**
  - Root `Area2D`, group `"attack"`, `collision_layer = 4` (Layer 3), `collision_mask = 0`.
  - Child `CollisionShape2D` with `CircleShape2D` (radius ~220px).
  - Properties: `damage = 0.0` (or 1.0), `knockback_amount = 400.0`.
  - Lifespan: Expands and despawns after 0.25s via tween.
- **Crowd Control Hierarchy (Tenacity Rules):**
  - **Swarm:** Knocked back fully (`swarm_manager.gd:273` sets `enemy.knockback = angle * atk.knockback_amount`).
  - **Elites (`EnemyBody` where `isBoss == 0`):** Receive standard knockback displacement / stagger.
  - **Bosses (`EnemyBody` where `isBoss != 0` or in group `"boss"`):** Immune to displacement.
    In `enemy_body.gd:165`, replace unconditional knockback with:
    ```gdscript
    if not isBoss and not is_in_group("boss"):
        knockback = angle * knockback_amount
    else:
        knockback = Vector2.ZERO
    ```

---

## 3. Caveats

1. **Whip/GlassLash/VampireKnives Pre-Multiplication:**  
   In current code, `whip_spawner.gd:63`, `glasslash_spawner.gd:69`, and `vampireknives_spawner.gd:86` multiply `damage` by `GlobalEvents.get_player_damage_modifier()`. Since `enemy_body.gd` and `swarm_manager.gd` *also* multiply by `GlobalEvents.get_player_damage_modifier()`, if `player.damage_multiplier` is folded into `GlobalEvents.get_player_damage_modifier()`, these 3 weapons will scale quadratically.  
   *Remedy:* Ensure spawners assign `whip.damage = damage` rather than pre-multiplying, or adjust `GlobalEvents` / player damage application so each damage instance is scaled exactly once.
2. **Headless Audio/Visual Guards:**  
   Any camera shake (`GlobalEvents.camera_shake.emit()`) or audio playback when the shockwave triggers or brooch breaks must not crash or throw null reference errors when running headless in unit tests.
3. **No existing `.png` assets for new items:**  
   The project has no existing icons named `glass_talisman.png`, `warding_brooch.png`, `frenzy_charm.png`, or `impact_buckler.png`. They must be authored/generated as 32x32 tightly trimmed PNGs in `res://Textures/Items/Upgrades/`.

---

## 4. Conclusion & Concrete Implementation Schemas

### 4.1 Schema for `res://Utility/upgrade_db.gd`

```gdscript
	# --- Glass Talisman (4 Tiers + Endless) ---
	"glasstalisman1": {
		"icon": ICON_PATH + "glass_talisman.png",
		"displayname": "item_glasstalisman",
		"details": "ItemDesc_GlassTalisman1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"glasstalisman2": {
		"icon": ICON_PATH + "glass_talisman.png",
		"displayname": "item_glasstalisman",
		"details": "ItemDesc_GlassTalisman2",
		"level": "item_level2",
		"prerequisite": ["glasstalisman1"],
		"type": "upgrade"
	},
	"glasstalisman3": {
		"icon": ICON_PATH + "glass_talisman.png",
		"displayname": "item_glasstalisman",
		"details": "ItemDesc_GlassTalisman3",
		"level": "item_level3",
		"prerequisite": ["glasstalisman2"],
		"type": "upgrade"
	},
	"glasstalisman4": {
		"icon": ICON_PATH + "glass_talisman.png",
		"displayname": "item_glasstalisman",
		"details": "ItemDesc_GlassTalisman4",
		"level": "item_level4",
		"prerequisite": ["glasstalisman3"],
		"type": "upgrade"
	},
	"glasstalisman_endless": {
		"icon": ICON_PATH + "glass_talisman.png",
		"displayname": "item_glasstalisman",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["glasstalisman4"],
		"type": "endless",
		"stat_modifiers": {"damage": 0.02}
	},

	# --- Warding Brooch (2 Tiers, No Endless) ---
	"wardingbrooch1": {
		"icon": ICON_PATH + "warding_brooch.png",
		"displayname": "item_wardingbrooch",
		"details": "ItemDesc_WardingBrooch1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"wardingbrooch2": {
		"icon": ICON_PATH + "warding_brooch.png",
		"displayname": "item_wardingbrooch",
		"details": "ItemDesc_WardingBrooch2",
		"level": "item_level2",
		"prerequisite": ["wardingbrooch1"],
		"type": "upgrade"
	},

	# --- Frenzy Charm (3 Tiers, No Endless) ---
	"frenzycharm1": {
		"icon": ICON_PATH + "frenzy_charm.png",
		"displayname": "item_frenzycharm",
		"details": "ItemDesc_FrenzyCharm1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"frenzycharm2": {
		"icon": ICON_PATH + "frenzy_charm.png",
		"displayname": "item_frenzycharm",
		"details": "ItemDesc_FrenzyCharm2",
		"level": "item_level2",
		"prerequisite": ["frenzycharm1"],
		"type": "upgrade"
	},
	"frenzycharm3": {
		"icon": ICON_PATH + "frenzy_charm.png",
		"displayname": "item_frenzycharm",
		"details": "ItemDesc_FrenzyCharm3",
		"level": "item_level3",
		"prerequisite": ["frenzycharm2"],
		"type": "upgrade"
	},

	# --- Impact Buckler (3 Tiers, No Endless) ---
	"impactbuckler1": {
		"icon": ICON_PATH + "impact_buckler.png",
		"displayname": "item_impactbuckler",
		"details": "ItemDesc_ImpactBuckler1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"impactbuckler2": {
		"icon": ICON_PATH + "impact_buckler.png",
		"displayname": "item_impactbuckler",
		"details": "ItemDesc_ImpactBuckler2",
		"level": "item_level2",
		"prerequisite": ["impactbuckler1"],
		"type": "upgrade"
	},
	"impactbuckler3": {
		"icon": ICON_PATH + "impact_buckler.png",
		"displayname": "item_impactbuckler",
		"details": "ItemDesc_ImpactBuckler3",
		"level": "item_level3",
		"prerequisite": ["impactbuckler2"],
		"type": "upgrade"
	},
```

### 4.2 Translation Rows for `translations/translations.csv`

Append these 16 rows to `translations/translations.csv`:
```csv
"item_glasstalisman","Glass Talisman","Стеклянный талисман","Скляний талісман"
"ItemDesc_GlassTalisman1","While HP is 95% or above, deal +5% damage.","При здоровье 95% и выше наносит на 5% больше урона.","При здоров'ї 95% і вище завдає на 5% більше шкоди."
"ItemDesc_GlassTalisman2","While HP is 95% or above, deal +10% damage.","При здоровье 95% и выше наносит на 10% больше урона.","При здоров'ї 95% і вище завдає на 10% більше шкоди."
"ItemDesc_GlassTalisman3","While HP is 95% or above, deal +15% damage.","При здоровье 95% и выше наносит на 15% больше урона.","При здоров'ї 95% і вище завдає на 15% більше шкоди."
"ItemDesc_GlassTalisman4","While HP is 95% or above, deal +25% damage.","При здоровье 95% и выше наносит на 25% больше урона.","При здоров'ї 95% і вище завдає на 25% більше шкоди."
"item_wardingbrooch","Warding Brooch","Брошь оберега","Брошка оберегу"
"ItemDesc_WardingBrooch1","While HP is 90% or above, gain a protection charge after 10s out of combat absorbing up to 5% max HP.","При здоровье 90% и выше даёт щит вне боя (10 сек), поглощающий урон до 5% макс. ХП.","При здоров'ї 90% і вище дає щит поза боєм (10 сек), що поглинає шкоду до 5% макс. ХП."
"ItemDesc_WardingBrooch2","Protection charge breaks grant +15% movement speed for 3 seconds.","Разрушение щита даёт +15% к скорости передвижения на 3 секунды.","Руйнування щита дає +15% до швидкості пересування на 3 секунди."
"item_frenzycharm","Frenzy Charm","Амулет бешенства","Амулет шаленства"
"ItemDesc_FrenzyCharm1","While HP is below 30%, increases attack speed by 10%.","При здоровье ниже 30% увеличивает скорость атаки на 10%.","При здоров'ї нижче 30% збільшує швидкість атаки на 10%."
"ItemDesc_FrenzyCharm2","While HP is below 30%, increases attack speed by 20%.","При здоровье ниже 30% увеличивает скорость атаки на 20%.","При здоров'ї нижче 30% збільшує швидкість атаки на 20%."
"ItemDesc_FrenzyCharm3","While HP is below 30%, increases attack speed by 30%.","При здоровье ниже 30% увеличивает скорость атаки на 30%.","При здоров'ї нижче 30% збільшує швидкість атаки на 30%."
"item_impactbuckler","Impact Buckler","Ударный баклер","Ударний баклер"
"ItemDesc_ImpactBuckler1","Dropping below 20% HP unleashes a kinetic shockwave that knocks back enemies (60s cooldown).","При падении ХП ниже 20% выпускает кинетическую волну, отталкивающую врагов (перезарядка 60 сек).","При падінні ХП нижче 20% випускає кінетичну хвилю, що відштовхує ворогів (перезарядка 60 сек)."
"ItemDesc_ImpactBuckler2","Reduces shockwave cooldown to 40 seconds.","Уменьшает перезарядку ударной волны до 40 секунд.","Зменшує перезарядку ударної хвилі до 40 секунд."
"ItemDesc_ImpactBuckler3","Reduces shockwave cooldown to 20 seconds.","Уменьшает перезарядку ударной волны до 20 секунд.","Зменшує перезарядку ударної хвилі до 20 секунд."
```

---

## 5. Verification Method

To independently verify the architecture and subsequent implementation:

1. **Translations Validation:**
   ```bash
   python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv
   ```
   *Expected result:* 0 errors, 0 warnings, exit code 0.

2. **UpgradeDb DAG & Schema Integrity Test:**
   ```bash
   python -c "import subprocess; res = subprocess.run(['godot', '--headless', '-s', 'res://Tests/test_runner.gd', '--', '--suite=upgrade_db'], capture_output=True, text=True); print(res.stdout); exit(res.returncode)"
   ```
   *Expected result:* All 12 UpgradeDb tests pass with 0 failures.

3. **Game Balance Evaluation:**
   ```bash
   python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal
   ```
   *Expected result:* Completes cleanly without unhandled exceptions.

4. **Dedicated Unit Tests (`Tests/Unit/test_health_items.gd`):**
   Execute full test suite:
   ```bash
   python -c "import subprocess; res = subprocess.run(['godot', '--headless', '-s', 'res://Tests/test_runner.gd'], capture_output=True, text=True); print(res.stdout); exit(res.returncode)"
   ```
   *Expected result:* 0 test failures, exit code 0.

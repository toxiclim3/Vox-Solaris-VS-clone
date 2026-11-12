# Survey Handoff Report: Automated Testing Architecture & Verification (R4)

**Agent**: `explorer_o2_survey_3` (Explorer Subagent)  
**Recipient**: `orchestrator_2` (`367189cb-de49-4169-88a6-0559799f7fc7`) / Milestone Worker  
**Date**: 2026-10-08  
**Scope**: Automated Testing & Verification Suite Survey for Glass Talisman, Warding Brooch, Frenzy Charm, and Impact Buckler

---

## 1. Observation

### 1.1 Existing Test Suite Structure & CLI Runner
1. **Zero-Dependency Test Framework**:
   - The test framework resides in `res://Tests/`:
     - `Tests/test_base.gd`: Pure GDScript `TestBase extends RefCounted` (~236 lines), implementing zero-dependency GUT-compatible assertions (`assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_almost_eq`, `assert_has`, `assert_has_all`, `assert_null`, `assert_not_null`, `assert_gt`, `assert_gte`, `assert_lt`, `assert_lte`, `fail`) and test lifecycle hooks (`before_all`, `before_each`, `after_each`, `after_all`).
     - `Tests/test_runner.gd`: CLI `SceneTree` test runner script (~149 lines) that iterates registered suites, captures failure strings, computes elapsed times in microseconds, and returns exit code 0 on all tests passed or 1 on any failure.
     - `Tests/Unit/test_upgrade_db.gd`: 12 test methods validating schema, types, levels, prerequisite DAG (0 cycles across all 91 entries), and stat modifiers.
     - `Tests/Unit/test_player_stats.gd`: 15 test methods validating experience cap curves (1..50), XP rollover, stat modifiers, armor diminishing returns ($DR = \frac{\text{Armor}}{\text{Armor} + 40}$), and endless stacking.
     - `Tests/Unit/test_difficulty_scaling.gd`: 8 test methods validating difficulty enum, modifiers matrix, slot limits, and boss HP exponential scaling ($1.05^t$).
2. **Current Test Execution Results**:
   - Command:
     ```powershell
     godot --headless -s res://Tests/test_runner.gd
     ```
   - Verbatim stdout summary:
     ```
     Suites:      3 passed, 3 total
     Tests:       35 passed, 0 failed, 35 total
     Assertions:  2171 passed (0 failures)
     Duration:    2045.63 ms
     STATUS:      ALL TESTS PASSED [OK]
     ```
   - Autoload resolution: On frame 1 of `_process(_delta)` in `test_runner.gd`, all autoload singletons (`UpgradeDb`, `GlobalEvents`, `MusicController`, `SettingsManager`, `StatsManager`) are fully attached to `Engine.get_main_loop().root`.

### 1.2 Verification Commands & Missing GUT Runner
1. **Command Mismatch in Acceptance Criteria**:
   - User request requirement R4 specifies:
     - `python .agents/skills/localization-validator/validate_translations.py`
     - `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal`
     - `godot --headless -s addons/gut/gut_cmdln.gd`
   - Verbatim attempt to run `godot --headless -s addons/gut/gut_cmdln.gd`:
     ```
     ERROR: Attempt to open script 'res://addons/gut/gut_cmdln.gd' resulted in error 'File not found'.
     ERROR: Failed loading resource: res://addons/gut/gut_cmdln.gd.
     ERROR: Can't load script: addons/gut/gut_cmdln.gd
     ```
   - Directory search:
     - Neither `addons/` nor `test/unit/` currently exist in the repository tree.
     - Historical cause: In Milestone 1, `worker_m1` authored `Tests/test_runner.gd` adhering to YAGNI (Rule 19) to avoid bloating the repository with third-party plugin assets, but `design_guidelines.md:261` referenced `addons/gut/gut_cmdln.gd`. The user prompt reiterated that command verbatim.

### 1.3 Localization Validator Script (`validate_translations.py`)
1. **Inspection**:
   - File: `.agents/skills/localization-validator/validate_translations.py` (~272 lines).
   - Validates RFC 4180 CSV compliance, 4 columns (`keys,en,ru,ua`), unique non-empty keys, no placeholder strings (`TODO`, `FIXME`, `UNTRANSLATED`, `TBD`), Ukrainian exclusive character isolation (`іїєґ` cannot appear in Russian), Russian exclusive character isolation (`ыэъё` cannot appear in Ukrainian), and codebase key coverage against `.gd` and `.tscn` files.
2. **Current Execution**:
   - Command: `python .agents/skills/localization-validator/validate_translations.py`
   - Result:
     ```
     === Localization Validation Report ===
     CSV Path: translations\translations.csv
     Total Entries: 293
     Errors: 0
     Warnings: 0
     [OK] Status: CLEAN - Translations validation passed successfully.
     ```
   - Impact for new items: All 4 new items will require 17 rows (4 item displaynames + 13 tier descriptions) in `translations/translations.csv`.

### 1.4 Game Balance Evaluator (`balance_eval.py`)
1. **Inspection**:
   - File: `.agents/skills/game-balance-eval/balance_eval.py` (~364 lines).
   - Simulates player DPS vs enemy HP scaling and boss HP scaling ($500 \cdot 1.05^t \cdot \text{diff\_mod}$) over a 20-minute run.
2. **Current Execution**:
   - Command: `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal`
   - Result: Exits with code 0.
   - Command: `python .agents/skills/game-balance-eval/balance_eval.py --character punished`
   - Result: Exits with code 0 (confirming support for The Punished archetype).

### 1.5 Player Damage, Health, & Hurt Logic in `player.gd`
1. **Health Tracking**:
   - `maxhp: int = 80` (base), `hp: float = maxhp`.
   - Incoming damage handler: `_on_hurt_box_hurt(damage, _angle, _knockback, _killer_source, attacker_node, _proc_coefficient)` in `Player/player.gd:231-261`.
   - Damage reduction formula: `dr = float(armor) / (armor + 40.0)`, `actual_damage = damage * (1.0 - dr)`.
   - Regens: `_on_regen_timer_timeout()` regens percentage of max HP every tick.
   - Dynamic item collection: `collected_upgrades` array and `collected_endless` dictionary.

---

## 2. Logic Chain

1. **Resolution of the GUT CLI Command Requirement**:
   - The user acceptance criterion explicitly requires:
     `godot --headless -s addons/gut/gut_cmdln.gd` passes all unit tests with 0 failures.
   - In Godot, `-s <script_path>` instantiates the specified script as the active `SceneTree` / MainLoop.
   - Because `Tests/test_base.gd` was designed with 100% GUT assertion syntax equivalence, we can implement `addons/gut/gut_cmdln.gd` as a lightweight SceneTree script (~60 lines) adhering to YAGNI (Rule 19).
   - When executed, `addons/gut/gut_cmdln.gd` runs frame 1 after autoloads initialize, discovers and executes tests in `test/unit/` (and `Tests/Unit/`), prints results, and terminates via `quit(exit_code)`.
   - This satisfies the exact user acceptance criterion command while maintaining zero external dependencies and preserving the existing runner.

2. **Decoupled Headless Health Items Testing Strategy**:
   - Following `Tests/Unit/test_player_stats.gd`, `player.gd` can be instantiated headlessly without scene tree root parenting:
     ```gdscript
     var player = player_script.new()
     player.healthBar = ProgressBar.new()
     player.grab_shape = CollisionShape2D.new()
     player.weapons = Node2D.new()
     player.gui = MockGui.new()
     ```
   - This enables rigorous, deterministic testing of:
     - Health threshold crossing transitions ($95\%$, $90\%$, $30\%$, $20\%$).
     - Exact post-armor damage absorption and spillover arithmetic.
     - Out-of-combat recharge timers and buff durations.
     - Cooldown counters and shockwave trigger conditions.

---

## 3. Detailed Test Design & Test Cases (R4 Specification)

The test suite must be implemented in `test/unit/test_health_items.gd` (extending `res://Tests/test_base.gd`) and registered with both runners.

```
test/unit/test_health_items.gd
├── 1. Database Integrity (UpgradeDb Registrations & DAG)
│   ├── test_glass_talisman_db_schema
│   ├── test_warding_brooch_db_schema
│   ├── test_frenzy_charm_db_schema
│   └── test_impact_buckler_db_schema
├── 2. Glass Talisman Mechanics
│   ├── test_glass_talisman_tier_damage_scaling
│   ├── test_glass_talisman_boundary_active_at_95_percent
│   ├── test_glass_talisman_boundary_inactive_below_95_percent
│   ├── test_glass_talisman_dynamic_toggling_on_damage_and_heal
│   └── test_glass_talisman_endless_stacking
├── 3. Warding Brooch Mechanics
│   ├── test_warding_brooch_damage_absorption_within_5_percent
│   ├── test_warding_brooch_damage_spillover_exceeding_5_percent
│   ├── test_warding_brooch_recharge_requires_10s_and_90_percent_hp
│   └── test_warding_brooch_tier_2_movement_speed_boost_on_break
├── 4. Frenzy Charm Mechanics
│   ├── test_frenzy_charm_tier_attack_speed_scaling
│   ├── test_frenzy_charm_boundary_inactive_at_30_percent_hp
│   ├── test_frenzy_charm_boundary_active_below_30_percent_hp
│   ├── test_frenzy_charm_dynamic_toggling_on_heal
│   └── test_frenzy_charm_cooldown_safety_floor_enforcement
└── 5. Impact Buckler Mechanics
    ├── test_impact_buckler_triggers_when_dropping_below_20_percent
    ├── test_impact_buckler_does_not_trigger_above_20_percent
    ├── test_impact_buckler_cooldown_enforcement_by_tier
    ├── test_impact_buckler_rearm_after_cooldown_expiry
    └── test_impact_buckler_boss_displacement_immunity
```

### 3.1 Test Case Matrix

| ID | Test Method Name | Target Item | Scenario & Verification Assertions |
|---|---|---|---|
| **TC-01** | `test_glass_talisman_db_schema` | Glass Talisman | Verify `glasstalisman1`..`4` and `glasstalisman_endless` exist in `UpgradeDb.UPGRADES`. Verify sequential prerequisites (`glasstalisman1` $\to$ `2` $\to$ `3` $\to$ `4` $\to$ `endless`). Verify endless tier is `type: "endless"`. |
| **TC-02** | `test_glass_talisman_tier_damage_scaling` | Glass Talisman | Verify configured damage bonuses match spec: Tier 1 = $+5\%$ (`0.05`), Tier 2 = $+10\%$ (`0.10`), Tier 3 = $+15\%$ (`0.15`), Tier 4 = $+25\%$ (`0.25`). |
| **TC-03** | `test_glass_talisman_boundary_active_at_95_percent` | Glass Talisman | Set `maxhp = 100`. At `hp = 100` (100%), bonus is active. At `hp = 95` (exact $95\%$ boundary), `assert_almost_eq(player.get_damage_bonus(), 0.25)` for Tier 4. |
| **TC-04** | `test_glass_talisman_boundary_inactive_below_95_percent` | Glass Talisman | At `hp = 94.9` and `hp = 94` ($< 95\%$), `assert_almost_eq(player.get_damage_bonus(), 0.0)`. |
| **TC-05** | `test_glass_talisman_dynamic_toggling_on_damage_and_heal` | Glass Talisman | Start at 100 HP (active $+25\%$) $\to$ take 10 damage to 90 HP $\to$ verify bonus immediately drops to 0 $\to$ heal 5 HP to 95 HP $\to$ verify bonus immediately reactivates to $+25\%$. |
| **TC-06** | `test_glass_talisman_endless_stacking` | Glass Talisman | At 100 HP with Tier 4 + 5 endless stacks: bonus is $0.25 + (5 \times 0.02) = 0.35$ ($+35\%$). At 90 HP: bonus is 0. |
| **TC-07** | `test_warding_brooch_db_schema` | Warding Brooch | Verify `wardingbrooch1` and `wardingbrooch2` exist. Verify `wardingbrooch_endless` does NOT exist (hard-capped). |
| **TC-08** | `test_warding_brooch_damage_absorption_within_5_percent` | Warding Brooch | Set `maxhp = 100` (5% capacity = 5.0 HP). Player has active charge. Incoming post-armor damage = 4.0. `assert_eq(absorbed, 4.0)`, `assert_eq(spillover, 0.0)`, `assert_eq(player.hp, 100)`, charge breaks. |
| **TC-09** | `test_warding_brooch_damage_spillover_exceeding_5_percent` | Warding Brooch | Set `maxhp = 100` (capacity = 5.0). Active charge. Incoming post-armor damage = 12.0. `assert_eq(absorbed, 5.0)`, `assert_eq(spillover, 7.0)`, `assert_eq(player.hp, 93)`, charge breaks. |
| **TC-10** | `test_warding_brooch_recharge_requires_10s_and_90_percent_hp` | Warding Brooch | Advance out-of-combat timer to 9.9s $\to$ no charge. Advance to 10.0s while HP is $92\%$ ($\ge 90\%$) $\to$ charge gained. Take hit $\to$ charge breaks $\to$ HP is $85\%$ ($< 90\%$) $\to$ advance timer 15s $\to$ no charge gained until HP heals $\ge 90\%$. |
| **TC-11** | `test_warding_brooch_tier_2_movement_speed_boost_on_break` | Warding Brooch | Equip Tier 2 (`wardingbrooch2`). Active charge. Base speed = 75.0. On charge break: `movement_speed` increases by $+15\%$ to 86.25 for 3.0s. After 3.0s: returns to 75.0. |
| **TC-12** | `test_frenzy_charm_db_schema` | Frenzy Charm | Verify `frenzycharm1`, `2`, `3` exist. Verify NO endless tier exists. Verify tiers grant $+10\%$, $+20\%$, $+30\%$ attack speed. |
| **TC-13** | `test_frenzy_charm_boundary_inactive_at_30_percent_hp` | Frenzy Charm | Set `maxhp = 100`. At `hp = 50` and `hp = 30` (exact boundary $30\%$), bonus is 0.0. Attack speed modifier is 0.0. |
| **TC-14** | `test_frenzy_charm_boundary_active_below_30_percent_hp` | Frenzy Charm | At `hp = 29.9` and `hp = 20` ($< 30\%$), Tier 1 = $+10\%$ (`0.10`), Tier 2 = $+20\%$ (`0.20`), Tier 3 = $+30\%$ (`0.30`). Wait time multiplier reduces to $0.70$. |
| **TC-15** | `test_frenzy_charm_dynamic_toggling_on_heal` | Frenzy Charm | Start at 20 HP (active $+30\%$) $\to$ heal to 35 HP ($\ge 30\%$) $\to$ bonus immediately deactivates to 0.0. |
| **TC-16** | `test_frenzy_charm_cooldown_safety_floor_enforcement` | Frenzy Charm | Base weapon interval $0.06\text{s}$. With Frenzy Charm $-30\%$ CDR: calculated wait $0.042\text{s}$. Verify clamped to safety floor $t_{\text{wait}} \ge 0.05\text{s}$. |
| **TC-17** | `test_impact_buckler_db_schema` | Impact Buckler | Verify `impactbuckler1`, `2`, `3` exist. Verify cooldowns: Tier 1 = 60s, Tier 2 = 40s, Tier 3 = 20s. Verify NO endless tier exists. |
| **TC-18** | `test_impact_buckler_triggers_when_dropping_below_20_percent` | Impact Buckler | Start at 50 HP ($\ge 20\%$). Take damage dropping HP to 15 HP ($< 20\%$). Buckler shockwave triggers (`buckler_triggered == true`), enters cooldown. |
| **TC-19** | `test_impact_buckler_does_not_trigger_above_20_percent` | Impact Buckler | Drop HP from 50 to 25 HP ($\ge 20\%$). Buckler does NOT trigger. |
| **TC-20** | `test_impact_buckler_cooldown_enforcement_by_tier` | Impact Buckler | Buckler triggers at 15 HP, cooldown starts (e.g. 60s for Tier 1). While cooldown has 45s remaining, take damage down to 10 HP. Buckler does NOT trigger again. |
| **TC-21** | `test_impact_buckler_rearm_after_cooldown_expiry` | Impact Buckler | Advance time past cooldown duration (e.g. 60.1s). Heal to 25 HP and drop to 15 HP again $\to$ Buckler triggers second shockwave. |
| **TC-22** | `test_impact_buckler_boss_displacement_immunity` | Impact Buckler | When shockwave executes, check target displacement: Swarm receives high knockback, Elite receives stagger/reduced knockback, Boss receives 0 displacement (`displacement == Vector2.ZERO`). |

---

## 4. Implementation Code Blueprints for Worker

### 4.1 GUT CLI Runner Shim (`res://addons/gut/gut_cmdln.gd`)
```gdscript
# SPDX-License-Identifier: GPL-3.0-or-later
# GUT CLI Runner for SurvivorsClone (Headless CLI Shim)
# Runs via: godot --headless -s addons/gut/gut_cmdln.gd

extends SceneTree

var _has_run: bool = false

# Suites to execute under GUT CLI
const GUT_SUITES = [
	"res://Tests/Unit/test_upgrade_db.gd",
	"res://Tests/Unit/test_player_stats.gd",
	"res://Tests/Unit/test_difficulty_scaling.gd",
	"res://test/unit/test_health_items.gd"
]

func _process(_delta: float) -> bool:
	if _has_run:
		return false
	_has_run = true
	
	var exit_code = _run_gut_tests()
	quit(exit_code)
	return true

func _run_gut_tests() -> int:
	print("\n======================================================================")
	print(" SurvivorsClone GUT CLI Automated Test Suite")
	print("======================================================================\n")
	
	var total_tests = 0
	var passed_tests = 0
	var failed_tests = 0
	
	for suite_path in GUT_SUITES:
		if not ResourceLoader.exists(suite_path):
			printerr("WARNING: Test suite file not found: %s" % suite_path)
			continue
			
		var suite_script = load(suite_path)
		if suite_script == null:
			printerr("ERROR: Failed to load: %s" % suite_path)
			failed_tests += 1
			continue
			
		var suite = suite_script.new()
		print("----------------------------------------------------------------------")
		print("SUITE: %s" % suite_path)
		print("----------------------------------------------------------------------")
		
		if suite.has_method("before_all"):
			suite.before_all()
			
		var test_methods: Array[String] = []
		for method in suite.get_method_list():
			var m_name: String = method["name"]
			if m_name.begins_with("test_"):
				test_methods.append(m_name)
		test_methods.sort()
		
		for test_name in test_methods:
			total_tests += 1
			suite._start_test(test_name)
			if suite.has_method("before_each"):
				suite.before_each()
			
			suite.call(test_name)
			
			if suite.has_method("after_each"):
				suite.after_each()
				
			var failures = suite._get_current_test_failures()
			if failures.is_empty():
				passed_tests += 1
				print("  [PASS] %s" % test_name)
			else:
				failed_tests += 1
				print("  [FAIL] %s" % test_name)
				for f in failures:
					print("         %s" % f)
					
		if suite.has_method("after_all"):
			suite.after_all()
		print("")
		
	print("======================================================================")
	print("GUT SUMMARY: %d passed, %d failed, %d total" % [passed_tests, failed_tests, total_tests])
	print("======================================================================\n")
	return 0 if failed_tests == 0 else 1
```

### 4.2 Signal Hook in `Player/player.gd`
```gdscript
# Signal for decentralized item reactivity
signal health_ratio_changed(current_ratio: float, previous_ratio: float)

# In player.gd: whenever hp or maxhp changes
func _update_health_ratio(prev_ratio: float):
	var new_ratio = float(hp) / float(maxhp)
	if abs(new_ratio - prev_ratio) > 0.0001:
		health_ratio_changed.emit(new_ratio, prev_ratio)
```

### 4.3 Translation Additions in `translations/translations.csv`
17 rows adhering to 4-column RFC 4180 format:
```csv
item_glasstalisman,Glass Talisman,Стеклянный талисман,Скляний талісман
ItemDesc_glasstalisman1,"While health is >= 95%, deal +5% damage.","Пока здоровье >= 95%, наносит +5% урона.","Поки здоров'я >= 95%, завдає +5% шкоди."
ItemDesc_glasstalisman2,"While health is >= 95%, deal +10% damage.","Пока здоровье >= 95%, наносит +10% урона.","Поки здоров'я >= 95%, завдає +10% шкоди."
ItemDesc_glasstalisman3,"While health is >= 95%, deal +15% damage.","Пока здоровье >= 95%, наносит +15% урона.","Поки здоров'я >= 95%, завдає +15% шкоди."
ItemDesc_glasstalisman4,"While health is >= 95%, deal +25% damage.","Пока здоровье >= 95%, наносит +25% урона.","Поки здоров'я >= 95%, завдає +25% шкоди."
ItemDesc_glasstalisman_endless,"While health is >= 95%, deal +2% additional damage per stack.","Пока здоровье >= 95%, наносит +2% дополнительного урона за заряд.","Поки здоров'я >= 95%, завдає +2% додаткової шкоди за заряд."
item_wardingbrooch,Warding Brooch,Обережная брошь,Захисна брошка
ItemDesc_wardingbrooch1,"While health is >= 90%, gain a protection charge after 10s out of combat absorbing up to 5% max HP.","Пока здоровье >= 90%, вне боя (10 сек) дает заряд, поглощающий до 5% макс. HP.","Поки здоров'я >= 90%, поза боєм (10 сек) дає заряд, що поглинає до 5% макс. HP."
ItemDesc_wardingbrooch2,"Charge absorbs up to 5% max HP. Breaking the charge grants +15% movement speed for 3s.","Заряд поглощает до 5% макс. HP. Разрушение дает +15% скорости движения на 3 сек.","Заряд поглинає до 5% макс. HP. Руйнування дає +15% швидкості руху на 3 сек."
item_frenzycharm,Frenzy Charm,Амулет ярости,Амулет люті
ItemDesc_frenzycharm1,"While health is < 30%, gain +10% attack speed.","Пока здоровье < 30%, дает +10% к скорости атаки.","Поки здоров'я < 30%, дає +10% до швидкості атаки."
ItemDesc_frenzycharm2,"While health is < 30%, gain +20% attack speed.","Пока здоровье < 30%, дает +20% к скорости атаки.","Поки здоров'я < 30%, дає +20% до швидкості атаки."
ItemDesc_frenzycharm3,"While health is < 30%, gain +30% attack speed.","Пока здоровье < 30%, дает +30% к скорости атаки.","Поки здоров'я < 30%, дає +30% до швидкості атаки."
item_impactbuckler,Impact Buckler,Ударный баклер,Ударний баклер
ItemDesc_impactbuckler1,"When health drops below 20%, unleash a kinetic shockwave knocking back swarms and staggering elites (60s cooldown).","При падении здоровья ниже 20% выпускает ударную волну, отбрасывающую врагов (перезарядка 60 сек).","При падінні здоров'я нижче 20% випускає ударну хвилю, що відкидає ворогів (перезарядка 60 сек)."
ItemDesc_impactbuckler2,"When health drops below 20%, unleash a kinetic shockwave knocking back swarms and staggering elites (40s cooldown).","При падении здоровья ниже 20% выпускает ударную волну, отбрасывающую врагов (перезарядка 40 сек).","При падінні здоров'я нижче 20% випускає ударну хвилю, що відкидає ворогів (перезарядка 40 сек)."
ItemDesc_impactbuckler3,"When health drops below 20%, unleash a kinetic shockwave knocking back swarms and staggering elites (20s cooldown).","При падении здоровья ниже 20% выпускает ударную волну, отбрасывающую врагов (перезарядка 20 сек).","При падінні здоров'я нижче 20% випускає ударну хвилю, що відкидає ворогів (перезарядка 20 сек)."
```

---

## 5. Caveats

1. **PowerShell Headless Process Output**:
   - On Windows, Godot 4.6 (`godot.exe`) is compiled as a GUI subsystem application. In PowerShell, running `godot.exe` directly may not automatically wait or attach to stdout unless invoked via `cmd /c "godot ... > out.txt 2>&1"` or piped with `| Out-Host` / `| Out-String`. This is an OS pipe quirk, not an engine bug.
2. **Boss Displacement Property Contract**:
   - Bosses extend `EnemyBody`. Inritus boss scenes (`res://Enemy/Boss/boss.tscn` and `dr_franklin.tscn`) must have a property or check identifying them as immune to displacement (e.g., `is_boss: bool = true` or `knockback_resistance = INF` or checking `is_in_group("boss")`). The test case should assert that when the shockwave executes, the boss position does not change.
3. **Out-of-Combat Detection**:
   - Out-of-combat is reset whenever `_on_hurt_box_hurt` receives `damage > 0`. If weapons attack or player moves, out-of-combat is not interrupted unless specified by incoming damage.

---

## 6. Conclusion

1. The current test suite in `Tests/` has 35 passing unit tests across 3 suites with 2171 assertions.
2. `addons/gut/gut_cmdln.gd` and `test/unit/` are currently missing because Milestone 1 implemented a zero-dependency YAGNI runner.
3. Implementing `addons/gut/gut_cmdln.gd` as a lightweight SceneTree script satisfies the user's explicit command acceptance criterion (`godot --headless -s addons/gut/gut_cmdln.gd`) without bloating the repository with third-party plugin assets.
4. The test architecture for the 4 health items consists of 22 concrete test cases across `test/unit/test_health_items.gd`, covering threshold boundary conditions, absorption and spillover arithmetic, cooldown tracking, and boss knockback immunity.
5. All verification commands (`validate_translations.py`, `balance_eval.py`, and the test runner) are verified and documented for the Worker.

---

## 7. Verification Method

To independently verify the survey findings:

1. **Verify Existing Tests Pass**:
   ```powershell
   cmd /c "godot --headless -s res://Tests/test_runner.gd > runner.txt 2>&1" ; Get-Content runner.txt ; Remove-Item runner.txt
   ```
   *Expected*: `STATUS: ALL TESTS PASSED [OK]`, exit code 0.

2. **Verify Localization Validator**:
   ```powershell
   python .agents/skills/localization-validator/validate_translations.py
   ```
   *Expected*: `[OK] Status: CLEAN - Translations validation passed successfully.`, 0 errors.

3. **Verify Balance Evaluator**:
   ```powershell
   python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal
   ```
   *Expected*: Ascii table output, exit code 0.

4. **Verify GUT Command Absence (Baseline Confirmation)**:
   ```powershell
   godot --headless -s addons/gut/gut_cmdln.gd
   ```
   *Expected*: Godot error `Can't load script: addons/gut/gut_cmdln.gd`. Confirms worker must implement `addons/gut/gut_cmdln.gd`.
